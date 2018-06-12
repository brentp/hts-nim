import unittest, hts

proc closeto(a, b: float64): bool =
  return (a - b).abs < 1e-4

suite "stats suite":
  test "test fisher":

    var r = fishers_exact_test(10, 20, 10, 80)
    check r.two > 0.009
    check r.two < 0.01

    check r.left > 0.95
    check r.right < 0.01

    check $r == "fisher_result(left:9.9843e-01, right:7.4046e-03, two:9.1349e-03)"


  test "binomial":

    discard """
    > binom.test(10, 30, p=0.5)

	Exact binomial test

data:  10 and 30
number of successes = 10, number of trials = 30, p-value = 0.09874
alternative hypothesis: true probability of success is not equal to 0.5
95 percent confidence interval:
 0.1728742 0.5281200
sample estimates:
probability of success
             0.3333333
    """

    var p0 = binom_test(10, 30)
    echo p0
    check p0.closeto(0.09874)


   # R
   # > binom.test(10, 30, p=0.2)$p.value
   # [1] 0.1053 # or 0.06109


    var p = binom_test(10, 40)
    echo p
    check(p.closeto(0.0022))


    var pg = binom_test(30, 40)
    echo pg
    check(pg.closeto(0.0022))

