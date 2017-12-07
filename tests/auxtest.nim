import unittest, hts/bam

suite "aux-test":
  test "test aux":
    var b: Bam
    open(b, "tests/HG02002.bam")

    for rec in b:

      var v = rec.aux("SM")
      check v.asint == 37

      expect Exception:
        check v.asfloat == 37

      expect Exception:
        check v.asstring == "37"

      var rg = rec.aux("RG")
      check rg.asstring == "SRR741410"

      var missing = rec.aux("UA")
      check missing == nil
      break
