import ./private/hts_concat
include "./bam/enums"
import strformat
import strutils
include "./bam/flag"
include "./bam/cigar"

type
  Header* = ref object of RootObj
    ## Header wraps the bam header info.
    hdr*: ptr bam_hdr_t

  Record* = ref object of RootObj
    ## Record is a single alignment object.
    b*: ptr bam1_t
    hdr: Header

  Bam* = ref object of RootObj
    ## Bam wraps a BAM/CRAM/SAM reader object from htslib.
    hts*: ptr hts_file
    hdr*: Header
    rec: Record
    idx*: ptr hts_idx_t
    path: cstring ## path the the alignment file.

  Target* = object
    ## Target is a chromosome or contig from the bam header.
    name*: string
    length*: uint32
    tid*: int

  IndexStats* = tuple[mapped: uint64, unmapped: uint64]

  BamError* = ref object of ValueError

proc finalize_header(h: Header) =
  sam_hdr_destroy(h.hdr)

proc `$`*(h:Header): string =
    return $h.hdr.text

proc stats*(idx: ptr hts_idx_t, tid: int): IndexStats =
  ## get the stats from the index.
  var v: IndexStats = (0'u64, 0'u64)
  discard hts_idx_get_stat(idx, cint(tid), v.mapped.addr, v.unmapped.addr)
  return v

proc copy*(h: Header): Header =
  ## make a copy of the bam Header and underlying pointer.
  var hdr: Header
  new(hdr, finalize_header)
  hdr.hdr = sam_hdr_dup(h.hdr)
  return hdr

proc xam_index*(fn:string, fnidx:string="", min_shift:int=14, nthreads:int=1) =
  ## index the file
  var min_shift = min_shift
  var fnidx = if fnidx == "":
      if fn.endswith(".bam"):
        if min_shift == 14:
          fn & ".bai"
        else:
          fn & ".csi"
      elif fn.endswith(".cram"):
        fn & ".crai"
      else:
        raise newException(ValueError, "hts-nim/xam_index: specify fnidx for file with unknown format")
    else:
      fnidx
  if fnidx.endswith(".bai"):
    min_shift = 0

  let ret = sam_index_build3(fn.cstring, fnidx.cstring, min_shift.cint, nthreads.cint)
  if ret == 0: return
  if ret == -2.cint:
    raise newException(OSError, "hts-nim/xam_index: error creating index for:" & fn)
  elif ret == -2.cint:
    raise newException(OSError, "hts-nim/xam_index: failed to open file:" & fn)
  elif ret == -3.cint:
    raise newException(OSError, "hts-nim/xam_index: format not indexable:" & fn)
  elif ret == -4.cint:
    raise newException(OSError, "hts-nim/xam_index: failed to create or save index:" & fn)


proc from_string*(h:Header, header_string:string) =
    ## create a new header from a string
    var header_string = header_string
    h.hdr = sam_hdr_parse(header_string.len.cint, header_string.cstring)
    if h.hdr == nil:
        raise newException(ValueError, "error parsing header string:" & header_string)

proc from_string*(r:Record, record_string:string) =
    ## update the record with the given SAM record. note that this does
    ## not make a copy of `record_string` and will modify the string in-place.
    var record_string = record_string
    if r.hdr == nil:
      raise newException(ValueError, "must set header for record before calling from_string")
    if r.b == nil:
      raise newException(ValueError, "must create record with NewRecord before calling from_string")


    var kstr = kstring_t(s:record_string.cstring, m:record_string.len.csize_t, l:record_string.len.csize_t)
    var ret = sam_parse1(kstr.addr, r.hdr.hdr, r.b)
    if ret != 0:
      raise newException(ValueError, "error:" & $ret & " in from_string parsing record: " & record_string)

template bam_get_seq(b: untyped): untyped =
  cast[CPtr[uint8]](cast[uint]((b).data) + uint(((b).core.n_cigar shl 2) + (b).core.l_qname))

proc sequence*(r: Record, s: var string): string {.discardable.} =
  ## fill the given string with the read sequence
  if len(s) != r.b.core.l_qseq:
    s.set_len(r.b.core.l_qseq)
  var bseq = bam_get_seq(r.b)
  for i in 0..<int(r.b.core.l_qseq):
      s[i] = "=ACMGRSVTWYHKDBN"[int(uint8(bseq[i shr 1]) shr uint8((not (i) and 1) shl 2) and uint8(0xF))]
  result = s

proc base_at*(r:Record, i:int): char {.inline.} =
  ## return just the base at the requsted index 'i' into the query sequence.
  when defined(debug):
    assert i >= 0
  if i >= r.b.core.l_qseq:
    return '.'
  var bseq = bam_get_seq(r.b)
  return "=ACMGRSVTWYHKDBN"[int(uint8(bseq[i shr 1]) shr uint8((not (i) and 1) shl 2) and uint8(0xF))]

template bam_get_qual*(b: untyped): untyped =
  cast[CPtr[uint8]](cast[uint]((b).data) + uint(uint((b).core.n_cigar shl 2) + uint((b).core.l_qname) + uint((b.core.l_qseq + 1) shr 1)))

proc base_qualities*(r: Record, q: var seq[uint8]): seq[uint8] =
  ## fill the given seq with the base-qualities.
  if len(q) != r.b.core.l_qseq:
    q.set_len(r.b.core.l_qseq)

  var bqual = bam_get_qual(r.b)
  for i in 0..<int(r.b.core.l_qseq):
    q[i] = bqual[i]
  return q

proc base_quality_at*(r:Record, i:int): uint8 {.inline.} =
  if i >= r.b.core.l_qseq:
    return 0
  return bam_get_qual(r.b)[i]

proc targets*(h: Header): seq[Target] =
  ## The targets (chromosomes) from the header.
  var n = int(h.hdr.n_targets)
  var ts = newSeq[Target](n)
  var arr = cast[CPtr[uint32]](h.hdr.target_len)
  for tid in 0..<n:
    ts[tid] = Target(name: $h.hdr.target_name[tid], length: arr[tid], tid: tid)
  return ts

proc `$`*(t: Target): string =
  return format("Target($1:$2)", t.name, t.length)

proc chrom*(r: Record): string {.inline.} =
  ## `chrom` returns the chromosome or '' if not mapped.
  let tid = r.b.core.tid
  if tid == -1:
    return ""
  return $r.hdr.hdr.target_name[tid]

proc mate_chrom*(r: Record): string {.inline.} =
  ## `mate_chrom` returns the chromosome of the mate or '' if not mapped.
  let tid = r.b.core.mtid
  if tid == -1:
    return ""
  return $r.hdr.hdr.target_name[tid]

proc tid*(r: Record): int {.inline.} =
  ## `tid` returns the tid of the alignment or -1 if not mapped.
  result = r.b.core.tid

proc mate_tid*(r: Record): int {.inline.} =
  ## `mate_tid` returns the tid of the mate or -1 if not mapped.
  result = r.b.core.mtid

proc start*(r: Record): int64 {.inline.} =
  ## `start` returns 0-based start position.
  return r.b.core.pos

proc stop*(r: Record): int {.inline.} =
  ## `stop` returns end position of the read.
  return bam_endpos(r.b)

proc qname*(r: Record): string {. inline .} =
  ## `qname` returns the query name.
  return $(bam_get_qname(r.b))

proc c_realloc(p: pointer, newsize: csize_t): pointer {.
  importc: "realloc", header: "<stdlib.h>".}

proc set_qname*(r: Record, qname: string) =
  ## set a new qname for the record
  doAssert qname.len < uint8.high.int, "[hts-nim/bam/set_qname]: maximum qname length is 255 bases"

  var l = qname.len + 1
  var l_extranul = 0
  if l mod 4 != 0:
    l_extranul = 4 - l mod 4
  l += l_extranul

  var old_ld = r.b.l_data

  r.b.l_data = r.b.l_data - r.b.core.l_qname.cint + l.cint
  if r.b.m_data < r.b.l_data.uint32:
    when defined(qname_debug):
      echo ">>>>>>>>>>>realloc:", r.b.l_data, " m:", r.b.m_data
    r.b.m_data = r.b.l_data.uint32
    # 4-byte align
    r.b.m_data += 32'u32 - (r.b.m_data mod 32'u32)
    r.b.data = cast[ptr uint8](c_realloc(r.b.data.pointer, r.b.m_data.csize_t))
  when defined(qname_debug):
    echo "old:", r.qname
    echo "new:", qname
    echo "source offset:", r.b.core.l_qname.int - 1
    echo "dest offset:", l
    echo "extranul:", l_extranul
    echo "copy size:", old_ld - r.b.core.l_qname.int
    echo "old_size:", old_ld
    echo "new_size:", r.b.l_data

  # first move the data that follows the qname to its correct location
  if r.b.core.l_qname != l.uint8:
    moveMem(cast[pointer](cast[int](r.b.data.pointer) + l),
            cast[pointer](cast[int](r.b.data.pointer) + r.b.core.l_qname.int),
            old_ld - r.b.core.l_qname.int)

  r.b.core.l_extranul = l_extranul.uint8
  r.b.core.l_qname = l.uint8

  # use loop instead of copyMem to avoid problems with older nim versions
  for i in 0..qname.high:
    (cast[CPtr[cchar]](r.b.data))[i] = qname[i]

  var tmp = cast[cstring](r.b.data)
  for i in 0..l_extranul:
    tmp[qname.len+i] = '\0'

proc flag*(r: Record): Flag {.inline.} =
  ## `flag` returns a `Flag` object.
  return Flag(r.b.core.flag)

proc cigar*(r: Record): Cigar {.inline.} =
  ## `cigar` returns a `Cigar` object.
  result = newCigar(bam_get_cigar(r.b), r.b.core.n_cigar)

iterator query*(bam: Bam, chrom:string, start:int=0, stop:int=0): Record =
  ## query iterates over the given region. A single element is used and
  ## overwritten on each iteration so use `Record.copy` to retain.
  if bam.idx == nil:
    quit "must open index before querying"
  var region: string
  if start >= 0 and stop > 0:
    region = format("$1:$2-$3", chrom, intToStr(start+1), intToStr(stop))
  elif start > 0:
    region = format("$1:$2", chrom, intToStr(start+1))
  else:
    region = chrom
  var qiter = sam_itr_querys(bam.idx, bam.hdr.hdr, region);
  if qiter != nil:
    var slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
    while slen > 0:
      yield bam.rec
      slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
    hts_itr_destroy(qiter)
    if slen < -1:
      stderr.write_line(&"[hts-nim] error:{slen} in bam.query for tid:{chrom} {start}..{stop}")


iterator query*(bam: Bam, tid:int, start:int=0, stop:int=(-1)): Record =
  ## query iterates over the given region. A single element is used and
  ## overwritten on each iteration so use `Record.copy` to retain.
  var stop = stop
  if stop == -1:
    stop = bam.hdr.targets[tid].length.int
  var qiter = sam_itr_queryi(bam.idx, cint(tid), cint(start), cint(stop));
  if qiter != nil:
    var slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
    while slen >= 0:
      yield bam.rec
      slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
    hts_itr_destroy(qiter)
    if slen < -1:
      stderr.write_line(&"[hts-nim] error:{slen} in bam.queryi for tid:{tid} {start}..{stop}")

proc `$`*(r: Record): string =
    return format("Record($1:$2-$3):$4", [r.chrom, $r.start, $r.stop, r.qname])

proc mapping_quality*(r: Record): uint8 {.inline.} =
  ## mapping quality
  return r.b.core.qual

proc isize*(r: Record): int64 {.inline.} =
  ## insert size
  return r.b.core.isize

proc mate_pos*(r: Record): int64 {.inline.} =
  ## mate position
  return r.b.core.mpos

proc tostring*(r: Record): string =
  var kstr : kstring_t
  kstr.l = 0
  kstr.m = 0
  kstr.s = nil

  if sam_format1(r.hdr.hdr, r.b, kstr.addr) < cint(0):
    raise newException(ValueError, "error for sam formatting")
  var s = $(kstr.s)
  free(kstr.s)
  return s

proc finalize_bam(ibam: Bam) =
  if ibam == nil: return
  if ibam.idx != nil:
    hts_idx_destroy(ibam.idx)
    ibam.idx = nil
  if ibam.hts != nil:
    discard hts_close(ibam.hts)
    ibam.hts = nil

proc finalize_record(rec: Record) =
  bam_destroy1(rec.b)

proc copy*(r: Record): Record {.noInit.} =
  ## `copy` makes a copy of the record.
  new(result, finalize_record)
  result.b = bam_dup1(r.b)
  result.hdr = r.hdr

proc write_header*(bam: var Bam, header: Header) =
  ## write the bam the the bam stream. useful when a bam is opened in write mode.
  ## this also sets the header.
  bam.hdr = header.copy()
  if sam_hdr_write(bam.hts, bam.hdr.hdr) != 0:
    raise newException(ValueError, "[hts-nim/bam] error writing new header")

proc write*(bam: var Bam, rec: Record) {.inline.} =
  ## write the record to the bam which must be writeable.
  # @return >= 0 on successfully reading a new record, -1 on end of stream, < -1 on error
  if sam_write1(bam.hts, bam.hdr.hdr, rec.b) < -1:
    raise newException(ValueError, "error writing to file:")

proc close*(bam: Bam) =
  discard hts_close(bam.hts)
  bam.hts = nil

proc NewRecord*(h:Header): Record =
  ## create a new bam record and associate it with the header
  var b   = bam_init1()
  # the record is attached to the bam, but it takes care of it's own finalizer.
  new(result, finalize_record)
  result.b = b
  result.hdr = h

var
  errno* {.importc, header: "<errno.h>".}: cint

proc strerror(errnum:cint): cstring {.importc, header: "<errno.h>", cdecl.}

proc open*(bam: var Bam, path: cstring, threads: int=0, mode:string="r", fai: cstring=nil, index: bool=false): bool {.discardable.} =
  ## `open_hts` returns a bam object for the given path. If CRAM, then fai must be given.
  ## if index is true, then it will attempt to open an index file for regional queries.
  ## for writing, mode can be, e.g. 'wb7' to indicate bam format with compression level 7 or
  ## 'wc' for cram format with default compression level.
  var mode = mode
  if mode[0] == 'w':
    if ($path).endsWith(".bam") and 'b' notin mode and 'c' notin mode: mode &= 'b'
    elif ($path).endsWith(".cram") and 'b' notin mode and 'c' notin mode: mode &= 'c'
  var hts = hts_open(path, mode)
  if hts == nil:
      stderr.write_line "[hts-nim] could not open '" & $path & "'. " & $strerror(errno)
      return false
  new(bam, finalize_bam)
  bam.hts = hts
  bam.path = path

  if fai != nil and fai.len > 0:
    if 0 != hts_set_fai_filename(hts, fai):
      stderr.write_line "[hts-nim] could not load '" & $fai & "' as fasta index. " & $strerror(errno)
      return false

  if mode[0] == 'r' and 0 != threads and 0 != hts_set_threads(hts, cint(threads)):
      raise newException(ValueError, "error setting number of threads")

  if mode[0] == 'r' and hts_check_EOF(hts) < 1:
    raise newException(ValueError, "invalid bgzf file")

  if mode[0] == 'w':
    return true

  var hdr: Header
  new(hdr, finalize_header)
  hdr.hdr = sam_hdr_read(hts)

  var rec = NewRecord(hdr)

  bam.hdr = hdr
  bam.rec = rec

  if index or ("##idx##" in $path):

    var idx = if "##idx##" in $path:
      let spl = ($path).split("##idx##")
      doAssert spl.len == 2, "mosdepth: expected ##idx## to separate bam from index path"
      sam_index_load2(bam.hts, spl[0], spl[1])
    else:
      sam_index_load(bam.hts, path)
    if idx != nil:
        bam.idx = idx
    else:
      stderr.write_line "index not found for:", $path & ". " & $strerror(errno)
      return false
  return true

proc load_index*(b: Bam, path: string) =
  ## load the bam/cram index at the given path. This can be remote or local.
  if path == "":
    b.idx = sam_index_load(b.hts, b.path)
  else:
    b.idx = sam_index_load2(b.hts, b.path, path.cstring)
  if b.idx == nil:
    raise newException(IoError, &"[bam] load_index error opening index {path} for bam {b.path}. {strerror(errno)}")

proc hts_set_opt*(fp: ptr htsFile; opt: FormatOption): cint {.varargs, cdecl,
    importc: "hts_set_opt", dynlib: libname.}

proc set_fields*(b: Bam, fields: varargs[SamField]): int =
  var opt : int = 0
  for f in fields:
    opt = opt or int(f)
  var ret = int(hts_set_opt(b.hts, CRAM_OPT_REQUIRED_FIELDS, cint(opt)))
  if ret != 0:
    stderr.write_line("couldn't set opts")
  return ret

proc set_option*(b: Bam, f: FormatOption, val: int): int =
  var ret = int(hts_set_opt(b.hts, f, cint(val)))
  if ret != 0:
    stderr.write_line("couldn't set opts")
  return ret

iterator items*(bam: Bam): Record {.raises: [ValueError]}=
  ## items iterates over a bam. A single element is used and overwritten
  ## on each iteration so use `Record.copy` to retain.
  var ret = sam_read1(bam.hts, bam.hdr.hdr, bam.rec.b)
  while ret >= 0:
    yield bam.rec
    ret = sam_read1(bam.hts, bam.hdr.hdr, bam.rec.b)
  if ret < -1:
    raise newException(ValueError, "hts/bam:error in iteration")

include "./bam/auxtags"
