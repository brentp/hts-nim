import "hts_concat"
import strutils

type
  Record* = ref object of RootObj
    b: ptr bam1_t
    hdr: ptr bam_hdr_t

  Bam* = ref object of RootObj
    hts: ptr hts_file
    hdr: ptr bam_hdr_t
    rec: Record
    idx: ptr hts_idx_t

include flag
include cigar

proc chrom*(r: Record): string =
  let tid = r.b.core.tid
  if tid == -1:
    return ""
  return $r.hdr.target_name[tid]

proc start*(r: Record): int =
  return r.b.core.pos

proc stop*(r: Record): int =
  return bamEndpos(r.b)

proc copy*(r: Record): Record =
  return Record(b: bam_dup1(r.b), hdr: r.hdr)

proc qname*(r: Record): string =
    return $(bam_get_qname(r.b))

proc flag*(r: Record): Flag =
    return Flag(r.b.core.flag)


proc cigar*(r: Record): Cigar =
    return NewCigar(bam_get_cigar(r.b), r.b.core.n_cigar)

iterator query*(bam: Bam, chrom:string, start:int, stop:int): Record =
  var region = format("$1:$2-$3", chrom, intToStr(start+1), intToStr(stop))
  var qiter = sam_itr_querys(bam.idx, bam.hdr, region);
  var slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
  while slen > 0:
    yield bam.rec
    slen = sam_itr_next(bam.hts, qiter, bam.rec.b)
  hts_itr_destroy(qiter)

proc `$`*(r: Record): string =
    return format("Record($1:$2-$3):$4", [r.chrom, intToStr(r.start), intToStr(r.stop), r.qname])

proc tostring*(r: Record): string =
  #var kstr: ptr kstring_t
  var kstr : kstring_t
  kstr.l = 0
  kstr.m = 0
  kstr.s = nil

  if sam_format1(r.hdr, r.b, kstr.addr) < 0:
    raise newException(ValueError, "error for sam formatting")
  var s = $(kstr.s)
  free(kstr.s)
  return s

proc finalizeBam(bam: Bam) =
  if bam.idx != nil:
      hts_idx_destroy(bam.idx)
  discard htsClose(bam.hts)
  bam_hdr_destroy(bam.hdr)

proc finalizeRecord(rec: Record) =
  bam_destroy1(rec.b)

proc NewBam*(path: cstring, threads: cint=2, fai: cstring=nil, index: bool=false): Bam =
  var hts = hts_open(path, "r")
  if hts_check_EOF(hts) != 1:
    raise newException(ValueError, "invalid bgzf file")

  if fai != nil:
    discard hts_set_fai_filename(hts, fai);
  #if 0 != hts_set_threads(hts, threads):
  #    raise newException(ValueError, "error setting number of threads")
      
  var hdr = sam_hdr_read(hts)
  var b   = bam_init1()
  # the record is attached to the bam, but it takes care of it's own finalizer.
  var rec: Record
  new(rec, finalizeRecord)
  rec.b = b
  rec.hdr = hdr
  var bam: Bam
  new(bam, finalizeBam)
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

iterator items*(bam: Bam): Record =
  var ret = samRead1(bam.hts, bam.hdr, bam.rec.b)
  while ret > 0:
    yield bam.rec
    ret = samRead1(bam.hts, bam.hdr, bam.rec.b)

proc main() =

  var bam = NewBam("/home/brentp/src/svv/test/HG02002.bam", index=true)
  #var bam = NewBam("/tmp/t.cram", fai="/data/human/g1k_v37_decoy.fa", index=true)

  var recs = newSeq[Record]()

  for b in bam:
    if len(recs) < 10:
        recs.add(b.copy())
  for b in recs:
      echo b, " ", b.flag.dup, " ", b.cigar
      for op in b.cigar:
          echo op, " ", op.consumesQuery, " ", op.consumesReference
  for b in bam.query("6", 328, 32816675):
    discard b

for i in 1..1000:
    echo i
    main()
