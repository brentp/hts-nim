
type 
  AuxKind = enum akString, akFloat, akInt
  Aux* = ref object
    case kind: AuxKind
    of akString: strVal: string
    of akFloat: floatVal: float64
    of akInt: intval: int

proc float*(a:Aux): float64 =
  case a.kind
  of akFloat:
    return a.floatVal
  of akInt:
    return a.intVal.float64
  else:
    return 0

proc integer*(a:Aux): int =
  case a.kind
  of akInt:
    return a.intVal
  else:
    return 0

proc tostring*(a:Aux): string =
  case a.kind
  of akString:
    return a.strval
  else:
    return ""

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
      return Aux(kind: akInt, intVal: int(i))
    of 'f', 'd':
      var f = bam_aux2f(b)
      return Aux(kind: akFloat, floatVal: float64(f))
    of 'A', 'Z', 'H':
      var z = bam_aux2Z(b).cstring
      return Aux(kind:akString, strVal: $(z))
    else:
      return nil
