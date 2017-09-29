import unittest, hts as hts

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

  test "write-with-index":

    var bx = wopen_bgzi("ti.txt.gz", 1, 2, 3, true)
    check bx.write_interval("aaa\t4\t10", "aaa", 4, 10) > 0
    check bx.write_interval("bbbbb\t2\t20", "bbbbb", 2, 20) > 0
    check bx.write_interval("c\t2\t20", "c", 2, 20) > 0
    check bx.close() == 0

  test "read-new-index":
    var csi: CSI
    check open(csi, "ti.txt.gz")

    check csi.chroms[0] == "aaa"
    check csi.chroms[1] == "bbbbb"
    check csi.chroms[2] == "c"
    check len(csi.chroms) == 3

    check csi.cnf.sc == 1
    check csi.cnf.bc == 2
    check csi.cnf.ec == 3
    check csi.cnf.metachar == 35
