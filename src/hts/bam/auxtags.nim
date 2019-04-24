import ../simpleoption
export simpleoption

proc delete_tag*(r:Record, itag:string): bool {.inline.} =
  ## remove the tag from the record return a bool indicating success.
  var c: array[2, char]
  c[0]= itag[0]
  c[1] = itag[1]
  var b = bam_aux_get(r.b, c)
  if b == nil: return false
  return bam_aux_del(r.b, b) == 0


proc tag*[T: int|float|string|char|cstring](r:Record, itag:string): Option[T] =
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

  case (cast[CPtr[char]](b))[0]:
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
      when T is cstring:
        var z = bam_aux2Z(b)
        return some(z)
      return none(T)
    of 'A':
      when T is char:
        var a = bam_aux2A(b)
        return some(a)
      when T is string:
        var a = bam_aux2A(b)
        return some($a)
      return none(T)
    else:
      return none(T)
