import hts/files

import unittest



suite "test files":
  test "that iteration works":
    var n = 0
    for line in hts_lines("tests/test_files.nim"):
      n += 1
    check n > 10


  test "file types":

    check "tests/sa.bam".file_type() == FileType.BAM
    check "tests/decomposed.vcf".file_type() == FileType.VCF
    check "tests/test.vcf.gz".file_type() == FileType.VCF

    check "tests/test.bcf".file_type() == FileType.BCF
    # non-existent
    expect OSError:
      check "tests/txxxxz".file_type() == FileType.VCF

  test "that bad path gives reasonable error message":

    expect OSError:
      for line in hts_lines("tests/sadfasdfasdfasdf"):
        discard

  test "readLine":
    var htf: HTSFile
    htf.open("tests/test_files.nim")

    var line = newStringOfCap(80)
    check htf.readLine(line)
    check line == "import hts/files"
    check htf.readLine(line)
    check line == ""
    check htf.readLine(line)
    check line == "import unittest"
