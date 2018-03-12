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

      var v = rec.int_tag("SM")
      check v.get == 37

      var f = rec.float_tag("SM")
      check f.get == 37.float

      var rg = rec.string_tag("RG")
      check rg.get == "SRR741410"


      check rec.int_tag("XXX").isNone

      break
    b.close()
