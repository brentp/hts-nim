import unittest, hts/fai

suite "fai-suite":
  test "fai-read":
    var f:Fai
    check open(f, "tests/aa.fa")
    check f.len == 6

    check f.get("20", 1, 3) == "GGA"
    check f.get("20:1-4") == "AGGA"
    check f.get("20", 0, 3) == "AGGA"

    check f.get("2", 0, 3) == "AGCA"
