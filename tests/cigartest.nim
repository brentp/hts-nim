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

  test "new cigar":
    var els = @[CigarElement(2048), CigarElement(2049), CigarElement(2048)]
    GC_ref(els)

    var cig = newCigar(els)
    var i = 0
    for e in cig:
      check e == els[i]
      i.inc

    GC_unref(els)
