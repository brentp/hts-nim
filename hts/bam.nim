import strutils

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
    hts: ptr hts_file
    hdr*: Header
    rec: Record
    idx: ptr hts_idx_t

  Target* = ref object of RootObj
    ## Target is a chromosome or contig from the bam header.
    name*: string
    length*: uint32
    tid*: int

proc finalize_header(h: Header) =
  bam_hdr_destroy(h.hdr)

proc copy*(h: Header): Header =
  var hdr: Header
  new(hdr, finalize_header)
  hdr.hdr = bam_hdr_dup(h.hdr)
  return hdr

proc targets*(h: Header): seq[Target] =
  var n = int(h.hdr.n_targets)
  var ts = newSeq[Target](n)
  var arr = safe(cast[CPtr[uint32]](h.hdr.target_len), n)
  for tid in 0..<n:
    ts[tid] = Target(name: $h.hdr.target_name[tid], length: arr[tid], tid: tid)
  return ts

proc `$`*(t: Target): string =
  return format("Target($1:$2)", t.name, t.length)
 
proc chrom*(r: Record): string =
  ## `chrom` returns the chromosome or '' if not mapped.
  let tid = r.b.core.tid
  if tid == -1:
    return ""
  return $r.hdr.hdr.target_name[tid]

proc mate_chrom*(r: Record): string =
  ## `mate_chrom` returns the chromosome of the mate or '' if not mapped.
  let tid = r.b.core.mtid
  if tid == -1:
    return ""
  return $r.hdr.hdr.target_name[tid]

proc start*(r: Record): int =
  ## `start` returns 0-based start position.
  return r.b.core.pos

proc stop*(r: Record): int =
  ## `stop` returns end position of the read.
  return bam_endpos(r.b)

proc copy*(r: Record): Record =
  ## `copy` makes a copy of the record.
  return Record(b: bam_dup1(r.b), hdr: r.hdr)

proc qname*(r: Record): string {. inline .} =
  ## `qname` returns the query name.
  return $(bam_get_qname(r.b))

proc flag*(r: Record): Flag =
  ## `flag` returns a `Flag` object.
  return Flag(r.b.core.flag)

proc cigar*(r: Record): Cigar =
  ## `cigar` returns a `Cigar` object.
  return newCigar(bam_get_cigar(r.b), r.b.core.n_cigar)

iterator querys*(bam: Bam, region: string): Record =
  ## query iterates over the given region. A single element is used and
  ## overwritten on each iteration so use `Record.copy` to retain.
  var qiter = sam_itr_querys(bam.idx, bam.hdr.hdr, region);
  var slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
  while slen > 0:
    yield bam.rec
    slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
  hts_itr_destroy(qiter)

iterator query*(bam: Bam, chrom:string, start:int, stop:int): Record =
  ## query iterates over the given region. A single element is used and
  ## overwritten on each iteration so use `Record.copy` to retain.
  var region = format("$1:$2-$3", chrom, intToStr(start+1), intToStr(stop))
  var qiter = sam_itr_querys(bam.idx, bam.hdr.hdr, region);
  var slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
  while slen > 0:
    yield bam.rec
    slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
  hts_itr_destroy(qiter)

iterator queryi*(bam: Bam, tid:uint32, start:int, stop:int): Record =
  ## query iterates over the given region. A single element is used and
  ## overwritten on each iteration so use `Record.copy` to retain.
  var qiter = sam_itr_queryi(bam.idx, cint(tid), cint(start), cint(stop));
  var slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
  while slen > 0:
    yield bam.rec
    slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
  hts_itr_destroy(qiter)

proc `$`*(r: Record): string =
    return format("Record($1:$2-$3):$4", [r.chrom, intToStr(r.start), intToStr(r.stop), r.qname])

proc qual*(r: Record): uint8 =
  return r.b.core.qual

proc isize*(r: Record): int32 =
  return r.b.core.isize

proc mate_pos*(r: Record): int32 =
  return r.b.core.mpos

proc tostring*(r: Record): string =
  #var kstr: ptr kstring_t
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
  discard htsClose(bam.hts)

proc finalize_record(rec: Record) =
  bam_destroy1(rec.b)

proc open_hts*(path: cstring, threads: int=0, fai: cstring=nil, index: bool=false): Bam =
  ## `open_hts` returns a bam object for the given path. If CRAM, then fai must be given.
  ## if index is true, then it will attempt to open an index file for regional queries.
  var hts = hts_open(path, "r")
  if hts_check_EOF(hts) != 1:
    raise newException(ValueError, "invalid bgzf file")

  if fai != nil:
    discard hts_set_fai_filename(hts, fai);
  if 0 != threads and 0 != hts_set_threads(hts, cint(threads)):
      raise newException(ValueError, "error setting number of threads")
  var hdr: Header
  new(hdr, finalize_header)
  hdr.hdr = sam_hdr_read(hts)
      
  var b   = bam_init1()
  # the record is attached to the bam, but it takes care of it's own finalizer.
  var rec: Record
  new(rec, finalize_record)
  rec.b = b
  rec.hdr = hdr
  var bam: Bam
  new(bam, finalize_bam)
  bam.hts = hts
  bam.hdr = hdr
  bam.rec = rec

  if index:
    var idx = sam_index_load(hts, path)
    if idx != nil:
        bam.idx = idx
    else:
        echo "index not found"

  return bam

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

iterator items*(bam: Bam): Record =
  ## items iterates over a bam. A single element is used and overwritten
  ## on each iteration so use `Record.copy` to retain.
  var ret = sam_read1(bam.hts, bam.hdr.hdr, bam.rec.b)
  while ret > 0:
    yield bam.rec
    ret = sam_read1(bam.hts, bam.hdr.hdr, bam.rec.b)

proc main() =

  var bam = open_hts("tests/HG02002.bam", index=true)
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
