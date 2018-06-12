import unittest, hts

suite "fisher-suite":
  test "test fisher sam":

    var r = fishers_exact_test(10, 20, 10, 80)
    check r.two > 0.009
    check r.two < 0.01

    check r.left > 0.95
    check r.right < 0.01

    check $r == "fisher_result(left:9.9843e-01, right:7.4046e-03, two:9.1349e-03)"
