import hts/files

import unittest

suite "test files":
  test "that iteration works":
    var n = 0
    for line in hts_lines("tests/test_files.nim"):
      n += 1
    check n > 10

  test "that bad path gives reasonable error message":

    expect OSError:
      for line in hts_lines("tests/sadfasdfasdfasdf"):
        discard
