import hts/hts_concat
import hts/simpleoption
export simpleoption

type
 Kind = enum typString, typFloat, typInt, typStrings, typFloats, typInts, typNone, typBool
 Value* = ref object
    ## a value in the info field
    case kind: Kind
    of typString: oString: string
    of typFloat: oFloat: float64
    of typInt: oInt: int
    of typStrings: nString: seq[string]
    of typFloats: nFloat: seq[float64]
    of typInts: nInt: seq[int]
    of typNone: xNone: bool
    of typBool: xBool: bool

proc asString*(a: Value): Option[string] =
  if a.kind == typString:
    return some(a.oString)

proc asInt*(a: Value): Option[int] =
  if a.kind == typInt:
    return some(a.oInt)
  
proc asFloat*(a: Value): Option[float64] =
  if a.kind == typFloat:
    return some(a.oFloat)
  if a.kind == typInt:
    return some(float64(a.oInt))

proc asBool*(a: Value): Option[bool] =
  if a.kind == typBool:
    return some(a.xBool)

proc asStrings*(a: Value): Option[seq[string]] =
  if a.kind == typStrings:
    return some(a.nString)
  if a.kind == typString:
    return some(@[a.oString])

proc asInts*(a: Value): Option[seq[int]] =
  if a.kind == typInts:
    return some(a.nInt)
  if a.kind == typInt:
    return some(@[a.oInt])
  
proc asFloats*(a: Value): Option[seq[float64]] =
  if a.kind == typFloats:
    return some(a.nFloat)
  if a.kind == typInts:
    var r = new_seq[float64](len(a.nFloat))
    for i, v in a.nFloat:
      r[i] = float64(v)
    return some(r)
  if a.kind == typInt:
    return some(@[a.oInt.float64])
  if a.kind == typFloat:
    return some(@[a.oFloat])

