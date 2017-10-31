import unittest, hts

suite "aux-test":
  test "test aux":
    var b: Bam
    open(b, "tests/HG02002.bam")

    for rec in b:

      var v = rec.aux("SM")
      check v.integer() == 37

      var rg = rec.aux("RG")
      check rg.tostring() == "SRR741410"

      var missing = rec.aux("UA")
      check missing == nil
      break
