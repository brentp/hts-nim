import unittest, hts/bam

suite "aux-test":
  test "test aux":
    var b: Bam
    open(b, "tests/HG02002.bam")

    for rec in b:

      var v = tag[int](rec, "SM")
      check v.get == 37

      var xt = tag[char](rec, "XT")
      check xt.get == 'U'


      var rg = tag[string](rec, "RG")
      check rg.get == "SRR741410"

      var missing = tag[int](rec, "RG")
      check missing.isNone
      break
    b.close()

  test "tag":
    var b: Bam
    open(b, "tests/HG02002.bam")
    for rec in b:

      var v = tag[int](rec, "SM")
      check v.get == 37

      var xt = tag[char](rec, "XT")
      check xt.get == 'U'

      var xts = tag[string](rec, "XT")
      check xts.get == "U"

      # SM exists, but it's a float.
      var f = tag[float](rec, "SM")
      check f.isNone

      var rg = tag[string](rec, "RG")
      check rg.get == "SRR741410"

      check tag[int](rec, "XXX").isNone

      break
    b.close()

  test "drop tag":
    var b: Bam
    open(b, "tests/HG02002.bam")
    for rec in b:

      var v = tag[int](rec, "SM")
      check v.get == 37

      check rec.delete_tag("SM")
      v = tag[int](rec, "SM")
      check v.isNone

      break
