import ../simpleoption
export simpleoption
from strformat import `&`

proc delete_tag*(r:Record, itag:string): bool {.inline.} =
  ## remove the tag from the record return a bool indicating success.
  var c: array[2, char]
  c[0]= itag[0]
  c[1] = itag[1]
  var b = bam_aux_get(r.b, c)
  if b == nil: return false
  return bam_aux_del(r.b, b) == 0

proc set_tag*[T: int|float|string|char](r:Record, itag:string, value:T) =
  ## set the aux tag to `value`.
  doAssert itag.len == 2, "[hts/bam set_tag] tag must of length 2. got " & itag
  var c: array[2, char]
  c[0] = itag[0]
  c[1] = itag[1]

  when T is int:
    if bam_aux_update_int(r.b, c, value.int64) != 0:
      # TODO: get errno
      quit(&"[hts/bam error in set_tag for key: {itag} value: {value}")
  elif T is float:
    if bam_aux_update_float(r.b, c, value.cfloat) != 0:
      # TODO: get errno
      quit(&"[hts/bam error in set_tag for key: {itag} value: {value}")
  elif T is string:
    if bam_aux_update_str(r.b, c, value.len.cint + 1, value.cstring) != 0:
      quit(&"[hts/bam error in set_tag for key: {itag} value: {value}")
  elif T is char:
    if bam_aux_update_str(r.b, c, 1, value.cstring) != 0:
      quit(&"[hts/bam error in set_tag for key: {itag} value: {value}")

proc tag*[T: int|float|float32|float64|string|char|cstring](r:Record, itag:string): Option[T] =
  ## Get the aux tag from the record.
  ## Due to `nim` language limitations, this must be used as, e.g.:
  ## `tag[int](rec, "NM")`. This returns an Option type that is either `Some` result
  ## or `none` if the tag does not exist or if it is not of the requested type.
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
      when T is float or T is float64 or T is float32:
        let f = bam_aux2f(b)
        return some(f.T)
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
