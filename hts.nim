import "hts_concat"
import strutils

type
  Bam = ref object of RootObj
    hts: ptr htsFile
    hdr: ptr bamHdrT
    b: ptr bam1T

  Record = ref object of RootObj
    b: ptr bam1T
    hdr: ptr bamHdrT

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

proc destroyBam(bam: Bam) =
  discard htsClose(bam.hts)
  bam_hdr_destroy(bam.hdr)
  bam_destroy1(bam.b)

proc NewBam(path: cstring): Bam =
  var hts = htsOpen(path, "r")
  var hdr = samHdrRead(hts)
  var b   = bamInit1()
  var bam: Bam
  new(bam, destroyBam)
  bam.hts = hts
  bam.hdr = hdr
  bam.b = b
  return bam

iterator items(bam: Bam): Record =
  var ret = 1
  while ret > 0:
    ret = samRead1(bam.hts, bam.hdr, bam.b)
    yield Record(b: bam.b, hdr: bam.hdr)


proc main() =

  var bam = NewBam("/home/brentp/src/svv/test/HG02002.bam")

  for b in bam:
    echo b
     
main()
