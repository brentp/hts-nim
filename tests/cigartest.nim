import unittest, cigar

suite "flag cigar-suite":
  test "test op":
    check Op(2048).tostring() == "128M"
    check Op(2049).tostring() == "128I"
    check Op(2050).tostring() == "128D"
    check Op(2051).tostring() == "128N"
    check Op(2052).tostring() == "128S"
    check Op(2053).tostring() == "128H"
    check Op(2054).tostring() == "128P"
    check Op(2055).tostring() == "128="
    check Op(2056).tostring() == "128X"
    check Op(2057).tostring() == "128B"
    check Op(4096).tostring() == "256M"
