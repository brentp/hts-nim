import unittest, hts, strutils
import hts/vcf
import os
import hts/private/hts_concat
import math


var global_vcf:VCF
if not open(global_vcf, "tests/test.vcf.gz"):
  quit "error opening vcf"


var global_variant:Variant

for v in global_vcf:
  global_variant = v.copy()
  break

proc isNan(f:float32): bool =
    return f.classify == fcNaN


suite "vcf suite":

  test "empty file rasies":
    var tfh:File
    var fname = "____t.vcf"
    if not open(tfh, fname, fmWrite):
      quit "couldn't open test vcf"
    tfh.close()
    expect OsError:
      var v:VCF
      if not open(v, fname):
        quit "Bad"
      removeFile(fname)

  test "filter":
    var v:VCF
    var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
    check open(v, "tests/test.vcf.gz", samples=tsamples)
    for variant in v:
        check variant.FILTER != "."
        if variant.POS == 10428:
          check variant.FILTER == "PASS"

  test "test writer":

    var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
    var v:VCF
    var wtr:VCF
    check open(v, "tests/test.vcf.gz", samples=tsamples)
    check open(wtr, "tests/outz.vcf", mode="w")
    wtr.header = v.header
    check wtr.write_header()
    var i = 0

    for variant in v:
      check variant.rid == 0
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
      for f in variant.format.fields:
        if f.name == "GT": continue
        doAssert variant.format.delete(f.name) == Status.OK

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

  test "vcf write missing format values":
    var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
    var vcf:VCF
    var wtr:VCF
    check open(vcf, "tests/test.vcf.gz", samples=tsamples)

    check vcf.header.add_format("xx", "1", "Float", "New float format field") == Status.OK

    check open(wtr, "tests/outmissing.vcf", mode="w")
    wtr.header = vcf.header
    check wtr.write_header()

    var vals = newSeq[float32](tsamples.len)
    for i, v in vals:
        vals[i] = cast[float32](bcf_float_missing)
        #bcf_float_set(vals[i].addr, bcf_float_missing)
        check vals[i].isNaN

    var i:int
    for v in vcf:
      vals[0] = i.float32
      i += 1

      check v.format.set("xx", vals) == Status.OK
      check wtr.write_variant(v)

    wtr.close()

  test "iterating over info fields":
    var vcf:VCF
    var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
    check open(vcf, "tests/test.vcf.gz", samples=tsamples)
    for v in vcf:
        for f in v.info.fields:
            #echo f.name, " -> ", f.n
            check f.n >= 0
            check f.name != ""

  test "that adding a new sample and setting values works.":
    var vcf:VCF
    var wtr:VCF
    var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
    check open(vcf, "tests/test.vcf.gz", samples=tsamples)


    check open(wtr, "tests/newsample.vcf", mode="w")
    wtr.copy_header(vcf.header)
    wtr.add_sample("Totally_New_Sample")

    check wtr.samples == @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919", "Totally_New_Sample"]
    check wtr.n_samples == tsamples.len + 1
    check wtr.write_header

    var ints = newSeq[int32]()
    var floats = newSeq[float32]()
    var strings = newSeq[string]()
    for v in vcf:
      ## NOTE!!! this is required to get this to work.
      v.vcf = wtr
      for field in v.format.fields:
        if field.vtype == BCF_TYPE.FLOAT:
          check v.format.get(field.name, floats) == Status.OK
          check v.format.set(field.name, floats) == Status.OK
        elif field.vtype == BCF_TYPE.CHAR:
          check v.format.get(field.name, strings) == Status.OK
          strings[0] = "hello"
          strings[strings.high] = "XXX" & field.name
          check v.format.set(field.name, strings) == Status.OK
          check v.format.get(field.name, strings) == Status.OK
        else:
          check v.format.get(field.name, ints) == Status.OK

          for i in 1..field.n_per_sample:
              ints[^i] = 14
          check v.format.set(field.name, ints) == Status.OK

      check wtr.write_variant(v)
    wtr.close()
    vcf.close()

    check open(vcf, "tests/newsample.vcf")
    for v in vcf:
      for field in v.format.fields:
        if field.vtype in {BCF_TYPE.INT32, BCF_TYPE.INT16, BCF_TYPE.INT8}:
          check v.format.get(field.name, ints) == Status.OK
          check ints[ints.high] == 14

    vcf.close()

  test "format fields":
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz")
    for v in vcf:
      var fields = newSeq[string]()
      for ff in v.format.fields:
          fields.add(ff.name)
          check ff.vtype in {BCF_TYPE.INT8, BCF_TYPE.INT16, BCF_TYPE.INT32}
      check fields == @["GT", "AD", "DP", "GQ", "PL"] or fields == @["GT", "AD", "DP", "GQ", "PGT", "PID", "PL"]
      break
    vcf.close()


  test "test empty format":
    var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz", samples=tsamples)


  test "test format setting":
    var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz", samples=tsamples)

    var val = @[2'i32, 2, 2, 2, 2]
    var vout = new_seq[int32](5)
    for variant in vcf:
      check variant.format.set("MIN_DP", val) == Status.OK

      check variant.format.get("MIN_DP", vout) == Status.OK

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

  test "add and set Flag":
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz")
    check vcf.header.add_info("myflag", "0", "Flag", "new flag") == Status.OK

    for variant in vcf:
      var val = true
      check variant.info.set("myflag", val) == Status.OK
      check "myflag" in variant.tostring()

      val = false
      check variant.info.set("myflag", val) == Status.OK
      check "myflag" notin variant.tostring()

  test "load index":
    var vcf:VCF
    check open(vcf, "tests/test.bcf")
    vcf.load_index("tests/other-for-test.bcf.csi")

  test "remove info from header":
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz")
    check vcf.header.add_info("toto", "1", "String", "New string field") == Status.OK
    check vcf.header.remove_info("toto") == Status.OK

  test "add format to header":
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz")
    check vcf.header.add_format("hello", "1", "Integer", "New int format field") == Status.OK
    var val = new_seq[int32](vcf.n_samples)
    for variant in vcf:
      check variant.format.set("hello", val) == Status.OK

      # note that we can't set the INFO with this new field.
      check variant.info.set("hello", val) == Status.UndefinedTag

  test "remove format from header":
    var vcf:VCF
    check open(vcf, "tests/test.vcf.gz")
    check vcf.header.add_format("hello", "1", "Integer", "New int format field") == Status.OK
    check vcf.header.remove_format("hello") == Status.OK

  test "set qual":

    global_variant.QUAL = 55
    check global_variant.QUAL == 55


  test "new from string":
    var v:VCF
    check open(v, "tests/test.vcf.gz")
    var s = $v.header

    var h: vcf.Header
    h.from_string(s)

    var o:VCF = VCF()
    o.header = h
    check o.samples == v.samples

    check h.add_string("""##FORMAT=<ID=ASDF,Number=4,Type=Integer,Description="ASDF">""") == Status.OK
    check "ASDF" in $h


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
      #echo gts
      var a = gts.alts
      check a[0] == -1
      check a[1] == 0
      check a[2] == 1
      check a[3] == 1
      check a[4] == 1
      check a[12] == -1
      check a[13] == 0


suite "header record":
  test "info test":
    var ivcf:VCF
    check ivcf.open("tests/test.vcf.gz")
    var h = ivcf.header.get("HWP", BCF_HEADER_TYPE.BCF_HL_INFO)
    check $h == """{ID:HWP, Number:1, Type:Float, Description:"P value from test of Hardy Weinberg Equilibrium", IDX:19}"""
    check h["ID"] == "HWP"
    check h["Number"] == "1"
    check h["Type"] == "Float"

    expect KeyError:
      h = ivcf.header.get("HWP", BCF_HEADER_TYPE.BCF_HL_FMT)

  test "format test":
    var ivcf:VCF
    check ivcf.open("tests/test.vcf.gz")
    var h = ivcf.header.get("AD", BCF_HEADER_TYPE.BCF_HL_FMT)
    check $h == """{ID:AD, Number:R, Type:Integer, Description:"Allelic depths for the ref and alt alleles in the order listed", IDX:80}"""
    check h["Type"] == "Integer"

suite "bug suite":
    test "csq reader":
        var v:VCF
        check open(v, "tests/csq-bug.vcf.gz")

        var anno = ""
        for variant in v:
            var st = variant.info.get("CSQ", anno)
            check st in {Status.OK, Status.NotFound}

import times

suite "speed tests":
  test "standard format getter":
    var t = cpuTime()
    var v:VCF
    var n:int
    for i in 0..2:
      check open(v, "tests/test.vcf.gz")

      var ints:seq[int32]
      var fields = @["DP", "GQ", "AD"]
      for variant in v:
        var f = variant.format
        for i in 0..4000:
          for fld in fields:
            if f.get(fld, ints) != Status.OK:
              quit "bad int field"

            if ints[22] == 0: n += 1
            if ints[12] == 0: n += 1
          var gts = f.genotypes(ints)
          doAssert gts[0][0].value > -2
      v.close()
    echo n, " in .. ", cpuTime() - t, " seconds "
