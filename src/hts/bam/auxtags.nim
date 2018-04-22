import ../simpleoption
export simpleoption

type 
  AuxKind = enum akString, akChar, akFloat, akInt
  Aux* = ref object
    case kind: AuxKind
    of akString: xString*: string
    of akChar: xChar*: char
    of akFloat: xFloat*: float64
    of akInt: xInt*: int

proc asChar*(a: Aux): Option[char] {.inline.} =
  ## get the value as a char. return none if not found.
  if a.kind == akChar:
    return some(a.xChar)

proc asString*(a: Aux): Option[string] {.inline.} =
  ## get the value as a string. return none if not found.
  if a.kind == akString:
    return some(a.xString)
  if a.kind == akChar:
    return some($a.xChar)

proc asInt*(a:Aux): Option[int] {.inline.} =
  ## get the value as an int. return none if not found.
  if a.kind == akInt:
    return some(a.xInt)
  
proc asFloat*(a:Aux): Option[float64] {.inline.} =
  ## get the value as a float. return none if not found.
  if a.kind == akFloat:
    return some(a.xFloat)
  if a.kind == akInt:
    return some(float64(a.xInt))

proc tag*[T: int|float|string|char](r:Record, itag:string): Option[T] =
  ## Get the aux tag from the record.
  ## Due to `nim` language limitations, this must be used as, e.g.:
  ## `tag[int](rec, "NM")`. It will return `none` if the tag does
  ## not exist or if it is not of the requested type.
  ## This can be a shorter alternative to rec.aux() which requires
  ## first checking if the value is nil and then getting the return type.
  var c: array[2, char]
  c[0]= itag[0]
  c[1] = itag[1]
  var b = bam_aux_get(r.b, c)
  if b == nil:
    return none(T)

  case safe(cast[CPtr[char]](b), 1)[0]:
    of 'i', 'I', 'c', 'C', 's', 'S':
      when T is int:
        var i = bam_aux2i(b)
        return some(T(i))
      return none(T)
    of 'f', 'd':
      when T is float:
        var f = bam_aux2f(b)
        return some(T(f))
      return none(T)
    of 'Z', 'H':
      when T is string:
        var z = $bam_aux2Z(b)
        return some(z)
      return none(T)
    of 'A':
      when T is char:
        var a = bam_aux2A(b)
        return some(a)
      return none(T)
    else:
      return none(T)

proc aux*(r:Record, tag: string): Aux {.inline.} =
  ## get the aux tag from the record.
  ## if the tag is not found, this will return nil.
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
    of 'Z', 'H':
      var z = bam_aux2Z(b)
      return Aux(kind:akString, xString: $(z))
    of 'A':
      var a = bam_aux2A(b)
      return Aux(kind: akChar, xChar: a)
    else:
      return nil
