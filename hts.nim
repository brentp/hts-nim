import "hts_concat"
import strutils

proc sprintf(formatstr: cstring): cstring {.importc: "sprintf", varargs,
                                  header: "<stdio.h>".}

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

proc hts_finalize(hts: ptr htsFile) =
  var ret = htsClose(hts)
  echo ret

proc NewBam(path: cstring): Bam =
  # HELP: hwo to do finalizer here?
  # var hts: ptr htsFile
  # hts = new(hts, hts_finalize)
  var hts = htsOpen(path, "r")
  var hdr = samHdrRead(hts)
  # TODO: see https://nim-lang.org/docs/system.html (finalizer)
  var b   = bamInit1()
  return Bam(hts: hts, hdr:hdr, b: b)

iterator items(bam: Bam): Record =
  var ret = 1
  while ret > 0:
    ret = samRead1(bam.hts, bam.hdr, bam.b)
    yield Record(b: bam.b, hdr: bam.hdr)

var bam = NewBam("/home/brentp/src/svv/test/HG02002.bam")

for b in bam:
  echo b

