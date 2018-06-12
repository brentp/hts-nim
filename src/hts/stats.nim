import ./private/hts_concat
import strutils

type fisher_result* = object
  left*: float64
  right*:float64
  two*:float64

proc `$`*(f:fisher_result): string =
  return "fisher_result(left:" & formatFloat(f.left, ffScientific, precision=4) &
         ", right:" & formatFloat(f.right, ffScientific, precision=4) &
         ", two:" & formatFloat(f.two, ffScientific, precision=4) & ")"

# kt_fisher_exact(int n11, int n12, int n21, int n22, double *_left
proc fishers_exact_test*[T:int|int64|int32](n11:T, n12:T, n21:T, n22:T): fisher_result {.inline.} =
  result = fisher_result()
  discard kt_fisher_exact(n11.cint, n12.cint, n21.cint, n22.cint, result.left.cdouble.addr, result.right.cdouble.addr, result.two.cdouble.addr)

proc binom_test*[T:int|int64|int32|uint32|uint64|uint16](successes:T, trials:T): float64 {.inline.} =
  if trials == 0: return 1
  # TODO: fix for p other than 0.5
  var p = 0.5
  var b = trials - successes
  #return min(1, 2 * kf_betai(b.cdouble, (successes + 1).cdouble, p.float64).float64)
  if successes > b:
    return min(1, 2 * kf_betai(successes.cdouble, (b + 1).cdouble, p.float64))
  else:
    return min(1, 2 * kf_betai(b.cdouble, (successes + 1).cdouble, p.float64))


