import unittest
import "hts/bam" as hts

suite "flag cigar-suite":
  test "test op":
    check $CigarElement(2048) == "128M"
    check $CigarElement(2049) == "128I"
    check $CigarElement(2050) == "128D"
    check $CigarElement(2051) == "128N"
    check $CigarElement(2052) == "128S"
    check $CigarElement(2053) == "128H"
    check $CigarElement(2054) == "128P"
    check $CigarElement(2055) == "128="
    check $CigarElement(2056) == "128X"
    check $CigarElement(2057) == "128B"
    check $CigarElement(4096) == "256M"

  test "ref coverage":
    var b:hts.Bam
    open(b, "tests/HG02002.bam")
    for rec in b:
      if rec.flag.unmapped: continue
      var pieces = rec.cigar.ref_coverage(ipos=rec.start)
      if len(pieces) == 0:
        check rec.mapping_quality == 0
        continue

      check pieces[0].start >= rec.start
      if pieces[len(pieces)-1].stop > rec.stop:
        echo rec.tostring
      check pieces[len(pieces)-1].stop <= rec.stop
