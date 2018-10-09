import unittest, hts, strutils
import hts/vcf


suite "bugs":

  test "bcf subset alts":
      var vcf:VCF
      check open(vcf, "tests/test.bcf", threads=3)
      var sample = "103171-103171"
      vcf.set_samples(@[sample])
      var x = newSeq[int32](2)
      for v in vcf: #.query("1"):
          if v.format.get("GT", x) != Status.OK:
              quit "bad gt"

          if v.format.genotypes(x).alts[0] < -1:
              quit "bad"

