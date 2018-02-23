import ../simpleoption
export simpleoption

type 
  AuxKind = enum akString, akFloat, akInt
  Aux* = ref object
    case kind: AuxKind
    of akString: xString*: string
    of akFloat: xFloat*: float64
    of akInt: xInt*: int

proc asString*(a: Aux): Option[string] {.inline.} =
  if a.kind == akString:
    return some(a.xString)

proc asInt*(a:Aux): Option[int] {.inline.} =
  if a.kind == akInt:
    return some(a.xInt)
  
proc asFloat*(a:Aux): Option[float64] {.inline.} =
  if a.kind == akFloat:
    return some(a.xFloat)
  if a.kind == akInt:
    return some(float64(a.xInt))

proc aux*(r:Record, tag: string): Aux {.inline.} =
  ## get the aux tag from the record.
  var c: array[2, char]
  c[0]= tag[0]
  c[1] = tag[1]
  var b = bam_aux_get(r.b, c)
  if b == nil: return nil
  
  case safe(cast[CPtr[char]](b), 1)[0]:
    of 'c', 'C', 's', 'S', 'i', 'I':
      var i = bam_aux2i(b)
      return Aux(kind: akInt, xInt: int(i))
    of 'f', 'd':
      var f = bam_aux2f(b)
      return Aux(kind: akFloat, xFloat: float64(f))
    of 'A', 'Z', 'H':
      var z = bam_aux2Z(b).cstring
      return Aux(kind:akString, xString: $(z))
    else:
      return nil
