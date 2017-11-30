import unittest
import hts/bam/flag

suite "flag test-suite":
  test "test flags":
    check Flag(1).pair
    check Flag(2).proper_pair
    check Flag(4).unmapped
    check Flag(8).mate_unmapped
    check Flag(16).reverse
    check Flag(32).mate_reverse
    check Flag(64).read1
    check Flag(128).read2
    check Flag(256).secondary
    check Flag(512).qcfail
    check Flag(1024).dup
    check Flag(2048).supplementary

    check $Flag(1 or 256) == "PAIRED,SECONDARY"
