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
