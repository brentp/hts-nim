import unittest, hts/bam as hts

suite "bam-suite":
  test "test sa sam":
    var b: Bam
    open(b, "tests/sa.sam")
    for rec in b:
      var found = false
      for s in rec.splitters("SA"):
        found = true
        check s.start > 0
        check s.stop > s.start
      check found

  test "test sa bam":
    var b: Bam
    open(b, "tests/sa.bam")
    for rec in b:
      var found = false
      for s in rec.splitters("SA"):
        found = true
        check s.start > 0
        check s.stop > s.start
