import unittest, hts/bam as hts
import strutils
import os


var header_string = """@HD	VN:1.0	SO:coordinate
@SQ	SN:6	LN:171115067	M5:1d3a93a248d92a729ee764823acbbc6b	UR:ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/reference/phase2_reference_assembly_sequence/hs37d5.fa.gz	AS:NCBI37	SP:Human"""

var records = """SRR741410.59076279	99	6	32771448	60	7M1D94M	=	32771594	246	AGGACTTCAGTACTATGTTGAATAGGAGTAATGAGAGGGGGCATTCTTGTCTTCTGCCAGTTTTCAAGGGGAATGCTTCCAGCTTTTGCCCATTCAGTATG	3NOFEHFHHIHEGIFHIHGHGKHFKKIKGEJHJILHLJKKKJJIIKJGIIIIIKKKKKJKGGFFJIMKKGJGEGONOCIJIIJJCCCJJHJIHCHIGFBED	X0:i:1	X1:i:0	MD:Z:7^C75G18	RG:Z:SRR741410	AM:i:37	NM:i:2	SM:i:37	MQ:i:60	XT:A:U	BQ:Z:@@@@@@@d@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
SRR741409.41474140	163	6	32771457	37	101M	=	32771663	241	AGTACTATGTTGAATAGGAGTAATGAGAGGGGGCATTCTTGTCTTCTGCCAGTTTTCAAGGGGAATGCTTCCAGGTTTTGCCCATTCAGTATGATGTTGGC	3MHDFIEGHHGHGKHFKJGKBCIGIHKHLKKKKIIIHJAGIIIIIKIJJKHJEDHHLKLKKMJIKGIJJGHNDLGHMCCGJKJJIDKLHJGIHMHGGALDA	X0:i:1	X1:i:0	MD:Z:101	RG:Z:SRR741409	AM:i:0	NM:i:0	SM:i:37	MQ:i:29	XT:A:U	BQ:Z:@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@""".split("\n")


suite "bam-suite":
  test "xam_index":
    discard tryRemoveFile("tests/HG02002.bam.bai")
    discard tryRemoveFile("tests/HG02002.bam.csi")
    check not fileExists("tests/HG02002.bam.bai")
    check not fileExists("tests/HG02002.bam.csi")
    xam_index("tests/HG02002.bam")
    check fileExists("tests/HG02002.bam.bai")
    xam_index("tests/HG02002.bam", min_shift=12)
    check fileExists("tests/HG02002.bam.csi")

  test "test sa sam":
    var b: Bam
    open(b, "tests/sa.sam")
    check b != nil
    var n = 0
    for rec in b:
      n += 1
    check n == 308

  test "test sa bam":
    var b: Bam
    open(b, "tests/sa.bam")
    var n = 0
    for rec in b:
      n += 1
    check n == 308

  test "cram writing":
    var c:Bam
    doAssert open(c, "_xxx.cram", mode="w")
    var b: Bam
    open(b, "tests/sa.bam")
    doAssert c.hts[].is_cram == 1'u32
    c.close
    b.close
    removeFile("_xxx.cram")


  test "set aux":

    var ibam:Bam
    check open(ibam, "tests/HG02002.bam")
    for a in ibam:
      a.set_tag("AI", 22)
      a.set_tag("GF", 23.3)
      a.set_tag("SS", "asdfa")
      #echo a.tostring()

      check tag[int](a, "AI").get == 22
      check abs(tag[float](a, "GF").get - 23.3) < 1e-5
      check tag[string](a, "SS").get == "asdfa"


  test "set qname":

    var ibam:Bam
    check open(ibam, "tests/HG02002.bam")

    for a in ibam:
      var qn = a.qname
      a.set_qname(a.qname)
      check a.tostring().split("\t")[0] == a.qname

      var before = a.tostring().split("\t")
      for nq in ["a", "x21XXXXXXXXXXXXXXXXXXXXXXXXXXXXxx213423423423423:qwerwqesdfsdf234r23rwsr234we234wr234wef234er2342r234sdfase234", "asdf"]:
        a.set_qname(nq)
        var after = a.tostring().split("\t")
        check a.qname == nq
        check after[0] == nq
        check after[1..<after.high] == before[1..<before.high]

      a.set_qname(qn)
      var after = a.tostring().split("\t")
      check after == before


  #test "load non-standard index":
  #  var b:Bam
  #  open(b, "tests/sa.bam")
  #  check b != nil
  #  expect IoError:
  #    b.load_index("tests/sa.xxxx.bai")

  #  b.load_index("https://github.com/brentp/hts-nim/raw/master/tests/sa.bam.bai")
  #  var n = 0
  #  for r in b.query("1", 10000, 11000):
  #    n += 1
  #  check n == 2

  test "test from string":

    var h = Header()
    var r = NewRecord(h)

    h.from_string(header_string)

    check h.hdr != nil

    r.from_string(records[0])
    check r.start == 32771447

    r.from_string(records[1])
    check r.start == 32771456
