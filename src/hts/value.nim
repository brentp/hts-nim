import hts/hts_concat
import hts/simpleoption
import sequtils
export simpleoption

type
 Kind = enum typString, typChar, typFloat, typInt, typStrings, typChars, typFloats, typInts, typNone, typBool
 Value* = ref object
    ## a value in the info field
    case kind: Kind
    of typString: oString: string
    of typChar: oChar: char
    of typFloat: oFloat: float64
    of typInt: oInt: int
    of typStrings: nString: seq[string]
    of typChars: nChar: seq[char]
    of typFloats: nFloat: seq[float64]
    of typInts: nInt: seq[int]
    of typNone: xNone: bool
    of typBool: xBool: bool

proc asChar*(a: Value): Option[char] =
  if a.kind == typChar:
    return some(a.oChar)

proc asString*(a: Value): Option[string] =
  if a.kind == typString:
    return some(a.oString)
  if a.kind == typChar:
    return some($a.oChar)

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
  if a.kind == typChars:
    return some(map(a.nChar, proc(x: char): string = $x))

proc asChars*(a: Value): Option[seq[char]] =
  if a.kind == typChars:
    return some(a.nChar)

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

