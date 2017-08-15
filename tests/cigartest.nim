import unittest, cigar

suite "flag cigar-suite":
  test "test op":
    check $Op(2048) == "128M"
    check $Op(2049) == "128I"
    check $Op(2050) == "128D"
    check $Op(2051) == "128N"
    check $Op(2052) == "128S"
    check $Op(2053) == "128H"
    check $Op(2054) == "128P"
    check $Op(2055) == "128="
    check $Op(2056) == "128X"
    check $Op(2057) == "128B"
    check $Op(4096) == "256M"
