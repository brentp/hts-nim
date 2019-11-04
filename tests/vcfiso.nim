import unittest, hts
import hts/vcf


suite "bugs":

  test "vcf/bcf subset alts":
      for path in @["tests/test.vcf.gz", "tests/test.bcf"]:
          var vcf:VCF
          check open(vcf, path, threads=3)
          var sample = "103171-103171"
          vcf.set_samples(@[sample])
          var x = newSeq[int32](2)
          for v in vcf.query("1"):
              if v.format.get("GT", x) != Status.OK:
                  quit "bad gt"

              if v.format.genotypes(x).alts[0] < -1:
                  quit "bad"

              if v.format.get("AD", x) != Status.OK:
                  quit "bad ad"
              check x[0] == 71
              break

