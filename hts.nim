import "hts_concat"
import strutils

type
  Record = ref object of RootObj
    b: ptr bam1T
    hdr: ptr bamHdrT

  Bam = ref object of RootObj
    hts: ptr htsFile
    hdr: ptr bamHdrT
    rec: Record


proc chrom(r: Record): string =
  let tid = r.b.core.tid
  if tid == -1:
    return ""
  return $r.hdr.target_name[tid]

proc start(r: Record): int =
  return r.b.core.pos

proc stop(r: Record): int =
  return bamEndpos(r.b)

proc `$`(r: Record): string =
  return format("Record($1:$2-$3)", [r.chrom, intToStr(r.start), intToStr(r.stop)])

proc finalizeBam(bam: Bam) =
  discard htsClose(bam.hts)
  bam_hdr_destroy(bam.hdr)

proc finalizeRecord(rec: Record) =
  bam_destroy1(rec.b)

proc NewBam(path: cstring): Bam =
  var hts = htsOpen(path, "r")
  var hdr = samHdrRead(hts)
  var b   = bamInit1()
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
  return bam

iterator items(bam: Bam): Record =
  var ret = samRead1(bam.hts, bam.hdr, bam.rec.b)
  while ret > 0:
    yield bam.rec
    ret = samRead1(bam.hts, bam.hdr, bam.rec.b)


proc main() =

  var bam = NewBam("/home/brentp/src/svv/test/HG02002.bam")

  for b in bam:
    discard b


for i in 1..1000000:
    main()
