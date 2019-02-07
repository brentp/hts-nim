import ./private/hts_concat
include "./bam/enums"
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

  Target* = ref object
    ## Target is a chromosome or contig from the bam header.
    name*: string
    length*: uint32
    tid*: int

  IndexStats* = tuple[mapped: uint64, unmapped: uint64]

  BamError* = ref object of ValueError

proc finalize_header(h: Header) =
  bam_hdr_destroy(h.hdr)

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
  hdr.hdr = bam_hdr_dup(h.hdr)
  return hdr

proc from_string*(h:Header, header_string:string) =
    ## create a new header from a string
    h.hdr = sam_hdr_parse(header_string.len.cint, header_string.cstring)
    if h.hdr == nil:
        raise newException(ValueError, "error parsing header string:" & header_string)

proc from_string*(r:Record, record_string:string) =
    ## update the record with the given SAM record. note that this does
    ## not make a copy of `record_string` and will modify the string in-place.
    if r.hdr == nil:
      raise newException(ValueError, "must set header for record before calling from_string")
    if r.b == nil:
      raise newException(ValueError, "must create record with NewRecord before calling from_string")


    var kstr = kstring_t(s:record_string.cstring, m:record_string.len, l:record_string.len)
    var ret = sam_parse1(kstr.addr, r.hdr.hdr, r.b)
    if ret != 0:
      raise newException(ValueError, "error:" & $ret & " in from_string parsing record: " & record_string)

template bam_get_seq(b: untyped): untyped =
  cast[CPtr[uint8]](cast[uint]((b).data) + uint(((b).core.n_cigar shl 2) + (b).core.l_qname))

proc sequence*(r: Record, s: var string): string =
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
  var arr = safe(cast[CPtr[uint32]](h.hdr.target_len), n)
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

proc mate_tid*(r: Record): int {.inline.} =
  ## `mate_tid` returns the tid of the mate or -1 if not mapped.
  result = r.b.core.mtid

proc tid*(r: Record): int {.inline.} =
  ## `tid` returns the tid of the alignment or -1 if not mapped.
  result = r.b.core.tid

proc start*(r: Record): int {.inline.} =
  ## `start` returns 0-based start position.
  return r.b.core.pos

proc stop*(r: Record): int {.inline.} =
  ## `stop` returns end position of the read.
  return bam_endpos(r.b)

proc copy*(r: Record): Record =
  ## `copy` makes a copy of the record.
  return Record(b: bam_dup1(r.b), hdr: r.hdr)

proc qname*(r: Record): string {. inline .} =
  ## `qname` returns the query name.
  return $(bam_get_qname(r.b))

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
      stderr.write_line("[hts-nim] error in bam.query:" & $slen)

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
      stderr.write_line("[hts-nim] error in bam.queryi:" & $slen)

proc `$`*(r: Record): string =
    return format("Record($1:$2-$3):$4", [r.chrom, intToStr(r.start), intToStr(r.stop), r.qname])

proc mapping_quality*(r: Record): uint8 {.inline.} =
  ## mapping quality
  return r.b.core.qual

proc isize*(r: Record): int32 {.inline.} =
  ## insert size
  return r.b.core.isize

proc mate_pos*(r: Record): int32 {.inline.} =
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

proc finalize_bam(bam: Bam) =
  if bam.idx != nil:
    hts_idx_destroy(bam.idx)
  if bam.hts != nil:
    discard hts_close(bam.hts)
    bam.hts = nil

proc finalize_record(rec: Record) =
  bam_destroy1(rec.b)

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
  var hts = hts_open(path, mode)
  if hts == nil:
      stderr.write_line "[hts-nim] could not open '" & $path & "'. " & $strerror(errno)
      return false
  new(bam, finalize_bam)
  bam.hts = hts

  if fai != nil:
    if 0 != hts_set_fai_filename(hts, fai):
      stderr.write_line "[hts-nim] could not load '" & $fai & "' as fasta index. " & $strerror(errno)
      return false

  if mode[0] == 'r' and 0 != threads and 0 != hts_set_threads(hts, cint(threads)):
      raise newException(ValueError, "error setting number of threads")

  if mode[0] == 'r' and bam.hts.format.format != hts_concat.sam and hts_check_EOF(hts) != 1:
    raise newException(ValueError, "invalid bgzf file")

  if mode[0] == 'w':
    return true

  var hdr: Header
  new(hdr, finalize_header)
  hdr.hdr = sam_hdr_read(hts)

  var rec = NewRecord(hdr)

  bam.hdr = hdr
  bam.rec = rec

  if index:
    var idx = sam_index_load(bam.hts, path)
    if idx != nil:
        bam.idx = idx
    else:
      stderr.write_line "index not found for:", $path & ". " & $strerror(errno)
      return false
  return true

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

type Splitter* = ref object
    ## A splitter represents one item from an SA tag
    aln*: Record
    chrom*: string
    start*: int
    cigar*: string
    qual*: uint8
    NM*: uint16

let consumes_ref = {'M', 'D', 'N', '=', 'X'}

proc stop*(s: Splitter): int {.inline.} =
  ## calculate the stop value for the splitter
  result = s.start
  var last_i = 0
  for i, c in s.cigar:
    if not c.isDigit:
      if c in consumes_ref:
        var num = s.cigar[last_i..<i]
        result += parseInt(num)
      last_i = i + 1

proc `$`*(s: Splitter): string =
  return format("Splitter($# $#..$# ($#))" % [s.chrom, $s.start, $s.stop, s.cigar])

iterator splitters*(r: Record, atag:string="SA"): Splitter =
  ## generate splitters from SA tag.
  var aux = tag[string](r, atag)
  if aux.isSome:
    var spls = aux.get
    for s in spls[0..<len(spls)-1].split(";"):
      var toks = s.split(",")
      if len(toks) == 4: # XA == chr,[strand]pos,CIGAR,NM
        yield Splitter(aln:r, chrom: toks[0], start: -1 + parseInt(toks[1][1..<len(toks[1])]), cigar: toks[2], NM:uint16(parseInt(toks[3])))
      else:
        yield Splitter(aln:r, chrom:toks[0], start: -1 + parseInt(toks[1]), cigar: toks[3],
                           qual: uint8(parseInt(toks[4])),
                           NM: uint16(parseInt(toks[5])))


proc main() =

  var bam: Bam
  open(bam, "tests/HG02002.bam", index=true)
  #var bam = open_hts("/tmp/t.cram", fai="/data/human/g1k_v37_decoy.fa", index=true)

  var recs = newSeq[Record]()

  for b in bam:
    if len(recs) < 10:
        recs.add(b.copy())
    discard b.qname
  for b in recs:
      echo b, " ", b.flag.dup, " ", b.cigar
      for op in b.cigar:
          echo op, " ", op.op, " ", op.consumes.query, " ", op.consumes.reference
  for b in bam.query("6", 328, 32816675):
    discard b

when isMainModule:
  for i in 1..3000:
      echo i
      main()
