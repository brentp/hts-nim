import unittest, hts/bam as hts

suite "bam-suite":
  test "test sa sam":
    var b: Bam
    open(b, "tests/sa.sam")
    check b != nil
    var n = 0
      
    for rec in b:
      n += 1
      var found = false
      for s in rec.splitters("SA"):
        found = true
        check s.start > 0
        check s.stop > s.start
      check found
    check n == 308

  test "test sa bam":
    var b: Bam
    open(b, "tests/sa.bam")
    var n = 0
    for rec in b:
      n += 1
      var found = false
      for s in rec.splitters("SA"):
        found = true
        check s.start > 0
        check s.stop > s.start
    check n == 308
