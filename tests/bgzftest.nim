import unittest, hts as hts

suite "bgzf-suite":
  test "test-write":
    var b: BGZ
    b.open("t.gz", "w")
    check b.tell() == 0
    check b.write_line("a\t1\t2") > 0
    check b.write("b\t10\t20\n") > 0
    check b.flush() == 0
    check b.tell() > 0
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
    check b.tell() > 0
    free(kstr.s)
    check b.close() == 0
