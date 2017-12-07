
type 
  AuxKind = enum akString, akFloat, akInt
  Aux* = ref object
    case kind: AuxKind
    of akString: asString*: string
    of akFloat: asFloat*: float64
    of akInt: asInt*: int

proc aux*(r:Record, tag: string): Aux =
  ## get the aux tag from the record.
  var c: array[2, char]
  c[0]= tag[0]
  c[1] = tag[1]
  var b = bam_aux_get(r.b, c)
  if b == nil: return nil
  
  case safe(cast[CPtr[char]](b), 1)[0]:
    of 'c', 'C', 's', 'S', 'i', 'I':
      var i = bam_aux2i(b)
      return Aux(kind: akInt, asInt: int(i))
    of 'f', 'd':
      var f = bam_aux2f(b)
      return Aux(kind: akFloat, asFloat: float64(f))
    of 'A', 'Z', 'H':
      var z = bam_aux2Z(b).cstring
      return Aux(kind:akString, asString: $(z))
    else:
      return nil
