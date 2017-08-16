import unittest, hts

suite "flag hts-suite":
  test "test hts":
    var b = open_hts("tests/HG02002.bam")
    for rec in b:
      for cig in rec.cigar:
        discard cig.op
        discard cig.len
      check rec.start <= rec.stop
      if rec.flag.pair:
        discard rec.flag.unmapped

      if rec.cigar.len() > 0:
        check uint32(rec.copy().cigar[0]) == uint32(rec.cigar[0])

      discard rec.isize
      discard rec.qual
    check b.hdr.targets[0].name == "1"
    check b.hdr.targets[0].length == 249250621
    check len(b.hdr.targets) == b.hdr.hdr.n_targets
