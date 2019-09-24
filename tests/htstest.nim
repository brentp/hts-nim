import unittest, hts/bam as hts

suite "flag hts-suite":
  test "test hts":
    var b: Bam
    open(b, "tests/HG02002.bam")
    var i: int
    var bqs = new_seq[uint8]()
    for rec in b:
      for cig in rec.cigar:
        discard cig.op
        discard cig.len
      check rec.start <= rec.stop
      if rec.flag.pair:
        discard rec.flag.unmapped

      if rec.cigar.len() > 0:
        check uint32(rec.copy().cigar[0]) == uint32(rec.cigar[0])
      check rec.base_qualities(bqs).len != 0
      for v in bqs:
        check v > 0'u8 and v < 100'u8
      if i == 0:
        for k, v in bqs:
          bqs[k] = 33'u8 + v
        check cast[string](bqs) == "3NOFEHFHHIHEGIFHIHGHGKHFKKIKGEJHJILHLJKKKJJIIKJGIIIIIKKKKKJKGGFFJIMKKGJGEGONOCIJIIJJCCCJJHJIHCHIGFBED"
      #for s in rec.splitters("XA"):
      #  echo s

      discard rec.isize
      discard rec.mapping_quality
      var s = ""
      if i == 0:
        check rec.sequence(s) == "AGGACTTCAGTACTATGTTGAATAGGAGTAATGAGAGGGGGCATTCTTGTCTTCTGCCAGTTTTCAAGGGGAATGCTTCCAGCTTTTGCCCATTCAGTATG"
        i += 1
        check rec.tid == 5
        check rec.mate_tid == 5

    check b.hdr.targets[0].name == "1"
    check b.hdr.targets[0].length == 249250621
    check len(b.hdr.targets) == b.hdr.hdr.n_targets

    check b.set_fields(SamField.SAM_POS, SamField.SAM_RNEXT) == 0
    check b.set_option(FormatOption.CRAM_OPT_DECODE_MD, 0) == 0
    b.close


