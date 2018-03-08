import unittest, hts, strutils


var global_vcf:VCF
if not open(global_vcf, "tests/test.vcf.gz"):
  quit "error opening vcf"


var global_variant:Variant

for v in global_vcf:
  global_variant = v.copy()
  break


suite "vcf suite":
  test "test writer":

    var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
    var v:VCF
    var wtr:VCF
    check open(v, "tests/test.vcf.gz", samples=tsamples)
    check open(wtr, "tests/out.vcf", mode="w")
    wtr.header = v.header
    check wtr.write_header()
    var variant:Variant
    var i = 0

    for variant in v:
      var val = @[0.6789'f32]
      check variant.info.set("VQSLOD", val) == Status.OK
      # or for a single value:
      var val1 = 0.77
      check variant.info.set("VQSLOD", val1) == Status.OK

      check variant.info.delete("CSQ") == Status.OK

      var mq0 = @[10000'i32]
      check variant.info.set("MQ0", mq0) == Status.OK

      var found = variant.tostring().contains("culprint")
      check (not found)

      var culprit = "Test"
      check variant.info.set("culprit", culprit) == Status.OK
      check wtr.write_variant(variant)

      check ("culprit" in variant.tostring())

      if i == 0:
        try:
          discard variant.info.delete("XXX")
          check false
        except KeyError:
          check true
      i += 1


    wtr.close()


  test "test format setting":
    var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz", samples=tsamples)

    var val = @[2'i32, 2, 2, 2, 2]
    var vout = new_seq[int32](5)
    for variant in vcf:
      check variant.format.set("MIN_DP", val) == Status.OK

      check variant.format.ints("MIN_DP", vout) == Status.OK

      check vout == val


      var val2 = @[2'i32, 2, 2, 2]
      check variant.format.set("MIN_DP", val2) == Status.IncorrectNumberOfValues

  test "add string to header":
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz")
    check vcf.header.add_string("##contig=<ID=8,length=146364022,assembly=b37>") == Status.OK

  test "add info to header":
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz")
    check vcf.header.add_info("hello", "1", "String", "New string field") == Status.OK

    var val = "world"
    for variant in vcf:
      check variant.info.set("hello", val) == Status.OK

  test "add format to header":
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz")
    check vcf.header.add_format("hello", "1", "Integer", "New int format field") == Status.OK
    var val = new_seq[int32](vcf.n_samples)
    for variant in vcf:
      check variant.format.set("hello", val) == Status.OK

      # note that we can't set the INFO with this new field.
      check variant.info.set("hello", val) == Status.UndefinedTag

  test "set qual":

    global_variant.QUAL = 55
    check global_variant.QUAL == 55


suite "genotypes suite":
  test "test alts":

    var v:VCF
    check open(v, "tests/decomposed.vcf")
    var x :seq[int32]

    # 0/.	./0	1/.	./1	./.
    for variant in v:
      var a = variant.format.genotypes(x).alts
      check a[0] == 0
      check a[1] == 0
      check a[2] == 1
      check a[3] == 1
      check a[4] == -1

  test "unknown alts":
    var v:VCF
    check open(v, "tests/unknown-alts.vcf")
    var x :seq[int32]

  
    
    # GT:DP:RO:QR:AO:QA:GL	.:.:.:.:.:.:.	0/0:3:3:96:0:0:0,-0.90309,-8.96	0/1:5:3:88:2:59:-5.09985,0,-7.70818	0/1:8:7:215:1:33:-1.79485,0,-10	0/1:3:2:67:1:34:-2.97403,0,-5.93903	0/0:3:3:89:0:0:0,-0.90309,-8.30667	1/1:2:0:0:2:53:-5.035,-0.60206,0	1/1:2:0:0:2:62:-5.89,-0.60206,0	1/1:2:0:0:2:54:-5.13,-0.60206,0	1/1:1:0:0:1:23:-2.3,-0.30103,0	1/1:2:0:0:2:42:-3.99,-0.60206,0	1/1:1:0:0:1:30:-3,-0.30103,0	.:.:.:.:.:.:.	0/0:6:6:207:0:0:0,-1.80618,-10	1/1:2:0:0:2:53:-5.035,-0.60206,0	0/1:4:3:86:1:30:-2.39794,0,-7.42461	1/1:1:0:0:1:37:-3.7,-0.30103,0
    for variant in v:
      var gts = variant.format.genotypes(x)
      echo gts
      var a = gts.alts
      check a[0] == -1
      check a[1] == 0
      check a[2] == 1
      check a[3] == 1
      check a[4] == 1
      check a[12] == -1
      check a[13] == 0
