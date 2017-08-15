import unittest, hts

suite "flag hts-suite":
  test "test hts":
    var b = Open("tests/HG02002.bam")
    for rec in b:
      for cig in rec.cigar:
        discard cig.op
        discard cig.len
      check rec.start <= rec.stop
      if rec.flag.pair:
        discard rec.flag.unmapped

      if rec.cigar.len() > 0:
        check rec.copy().cigar[0] == rec.cigar[0]

      discard rec.isize
      discard rec.qual
