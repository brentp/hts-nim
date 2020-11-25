import unittest, hts/fai

suite "fai-suite":
  test "fai-read":
    var f:Fai
    check open(f, "tests/aa.fa")
    check f.len == 6

    check f.get("20", 1, 3) == "GGA"
    check f.get("20:1-4") == "AGGA"
    check f.get("20", 0, 3) == "AGGA"

    check f.get("2", 0, 3) == "AGCA"

  test "fai chrom_len":
    var f:Fai
    check open(f, "tests/aa.fa")
    check f.chrom_len("2") == 215
    check f.chrom_len("20") == 301

  test "fai indexing":
    var f:Fai
    check open(f, "tests/aa.fa")
    check f[0] == "20"
    check f[1] == "2"
    check f[5] == "21"

  test "issue26":
      var fai:Fai
      check open(fai, "tests/sample.fa")
      check fai[0] == "ref"
      check fai[0] == "ref"
      check fai[0] == "ref"
      check fai.get(fai[0], 0, 2) == "ACG"

  test "close":
      var fai:Fai
      check open(fai, "tests/sample.fa")
      fai.close()
      check true
