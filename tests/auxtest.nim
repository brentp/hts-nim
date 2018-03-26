import unittest, hts/bam

suite "aux-test":
  test "test aux":
    var b: Bam
    open(b, "tests/HG02002.bam")

    for rec in b:

      var v = rec.aux("SM")
      check v.asint.get == 37

      check v.asfloat.get == 37.float64

      check v.asstring.isNone

      var rg = rec.aux("RG")
      check rg.asstring.get == "SRR741410"
      check rg.asint.isNone
      check rg.asfloat.isNone

      var missing = rec.aux("UA")
      check missing == nil
      break
    b.close()

  test "tag":
    var b: Bam
    open(b, "tests/HG02002.bam")
    for rec in b:

      var v = tag[int](rec, "SM")
      check v.get == 37

      # SM exists, but it's a float.
      var f = tag[float](rec, "SM")
      check f.isNone

      var rg = tag[string](rec, "RG")
      check rg.get == "SRR741410"

      check tag[int](rec, "XXX").isNone

      break
    b.close()
