import unittest, hts

suite "bgzf-suite":
  test "test-write":
    var b: BGZ
    b.open("t.gz", "w")
    check b.tell() == 0
    check b.write_line("a\t1\t2") > 0
    check b.write("b\t10\t20\n") > 0
    check b.flush() == 0
    check int(b.tell()) > 0
    check b.close() == 0

  test "test-read":
    var b: BGZ
    b.open("t.gz", "r")

    var kstr: kstring_t
    kstr.l = 0
    kstr.m = 0
    kstr.s = nil
    var p = kstr.addr

    check b.read_line(p) >= 0
    check $kstr.s == "a\t1\t2"
    check b.read_line(p) >= 0
    check $kstr.s == "b\t10\t20"
    check b.read_line(p) == -1 # EOF: todo. handle this in a nim-like way.
    check $kstr.s == "b\t10\t20"
    check int(b.tell()) > 0
    free(kstr.s)
    check b.close() == 0

  test "bgzf-iterator":
    var
      b: BGZ
      nb_lines = 0
    b.open("t.gz", "r")

    for line in b:
      nb_lines.inc()
      if nb_lines == 2:
        check line == "b\t10\t20"

    check nb_lines == 2

  test "bgzf-iterator-err":
    var
      b: BGZ
    b.open("tests/gzip-err.gz", "r")

    expect IoError:
      for line in b:
        echo line

  test "write-with-index":
    var bx:BGZI
    check bx.open("ti.txt.gz", fmWrite, 1, 2, 3, true)
    check bx.write_interval("aaa\t4\t10", "aaa", 4, 10) > 0
    check bx.write_interval("aaa\t40\t100", "aaa", 40, 100) > 0
    check bx.write_interval("bbbbb\t2\t20", "bbbbb", 2, 20) > 0
    check bx.write_interval("c\t2\t20", "c", 2, 20) > 0
    check bx.close() == 0

  test "read-new-index":
    var c: CSI
    check open(c, "ti.txt.gz")

    check c.chroms[0] == "aaa"
    check c.chroms[1] == "bbbbb"
    check c.chroms[2] == "c"
    check len(c.chroms) == 3

    var xc = c.tbx.conf
    check xc.sc == 1
    check xc.bc == 2
    check xc.ec == 3
    check xc.metachar == 35

    var t = c
    check t != nil

  test "csi-iterator":
    var rx:BGZI
    check rx.open("ti.txt.gz")

    var found = 0
    for reg in rx.query("aaa", 1, 5):
      found += 1
      check reg == "aaa\t4\t10"
    check found == 1

  test "bgzi-query from VCF rows":
    ## There was a discrepancy between rec.POS (int32) and BGZI.query (int64)
    var db:BGZI
    check db.open("tests/test_files/simple.tsv.gz")
    var v: VCF
    doAssert(v.open("tests/test.vcf.gz"))

    var rows: seq[string] = @[]
    for rec in v:
      for row in db.query($rec.CHROM, rec.POS - 1, rec.POS):
        rows.add row
    check rows.len == 1
    check rows[0] == "1\t10492\tC\tT"
