import hts

var ivcf:VCF
if not ivcf.open("/path/to/my.bcf"):
  quit "couldnt open vcf"

for variant in ivcf:
  if v.QUAL < 25:
    echo "bad"
