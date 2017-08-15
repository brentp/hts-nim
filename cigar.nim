# https://forum.nim-lang.org/t/567 (by Jehan)
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
type CArray*{.unchecked.}[T] = array[0..0, T]
type CPtr*[T] = ptr CArray[T]

type SafeCPtr*[T] =
  object
    size: int
    mem: CPtr[T]

proc safe*[T](p: CPtr[T], k: int): SafeCPtr[T] =
    SafeCPtr[T](mem: p, size: k)

proc safe*[T](a: var openarray[T], k: int): SafeCPtr[T] =
  safe(cast[CPtr[T]](addr(a)), k)

proc `[]`*[T](p: SafeCPtr[T], k: int): T =
  when not defined(release):
    assert k < p.size
  result = p.mem[k]

proc `[]=`*[T](p: SafeCPtr[T], k: int, val: T) =
  when not defined(release):
    assert k < p.size
  p.mem[k] = val

# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

type
  Cigar* = ref object of RootObj
    cig: SafeCPtr[uint32]
    n: uint32
  Op = uint32

proc NewCigar*(p: ptr uint32, n: uint32): Cigar =
  return Cigar(cig: safe(cast[CPtr[uint32]](p), int(n)), n:n)

proc `[]`*(c:Cigar, i:int): Op =
  return Op(c.cig[i])

iterator items*(c: Cigar): Op =
  for i in 0..<c.cig.size:
    yield c.cig[i]

template bam_get_cigar(b: untyped): untyped =
  (cast[ptr uint32](((cast[int]((b).data)) + cast[int]((b).core.l_qname))))

proc bam_cigar_type(o: Op): uint8 =
  return BAM_CIGAR_TYPE shr ((o) shl 1) and 3

proc op*(o: Op): uint8 =
  return uint8(o and BAM_CIGAR_MASK)

proc len*(o: Op): int =
  return int(o shr BAM_CIGAR_SHIFT)

proc `$`*(o: Op): string =
  var opstr = BAM_CIGAR_STR[int(o.op)]
  var oplen = o.len
  return intToStr(oplen) & $opstr

proc consumesQuery*(o: Op): bool =
  return (bam_cigar_type(o.op) and uint8(1)) != 0

proc consumesReference*(o: Op): bool =
  return (bam_cigar_type(o.op) and uint8(2)) != 0

proc `$`*(c: Cigar): string =
  var s: string = ""
  for i in 0..<c.cig.size:
    var cig = c.cig[i]
    s &= $cig
  return s
