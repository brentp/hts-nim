import ../private/hts_concat
import strutils
# https://forum.nim-lang.org/t/567 (by Jehan)
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
type CArray{.unchecked.}[T] = array[0..0, T]
type CPtr*[T] = ptr CArray[T]

type SafeCPtr*[T] =
  object
    size: int
    mem: CPtr[T]

proc safe*[T](p: CPtr[T], k: int): SafeCPtr[T] =
    SafeCPtr[T](mem: p, size: k)

proc safe[T](a: var openarray[T], k: int): SafeCPtr[T] =
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
  Cigar* = ref object
    ## `Cigar` represents ths SAM Cigar type. It consists of one or more `CigarElement` s.
    cig: SafeCPtr[uint32]
    n: uint32

  CigarElement* = distinct uint32 ## `CigarElement` encodes the operation (length and type) of each element of a `Cigar`.

  Consume* = distinct uint32

type CigarOp* {.pure.} = enum
  match, insert, deletion, ref_skip, soft_clip, hard_clip, pad, equal, diff, back

proc newCigar(p: ptr uint32, n: uint32): Cigar {.inline.} =
  result = Cigar(cig: safe(cast[CPtr[uint32]](p), int(n)), n:n)

proc len*(c: Cigar): int {. inline .} =
  ## returns the number of operations in the cigar.
  result = int(c.n)

proc `[]`*(c:Cigar, i:int): CigarElement {.inline.} =
  return CigarElement(c.cig[i])

iterator items*(c: Cigar): CigarElement =
  ## iterates over the ops in the cigar.
  for i in 0..<c.cig.size:
    yield CigarElement(c.cig[i])

template bam_get_cigar*(b: untyped): untyped =
  (cast[ptr uint32](((cast[int]((b).data)) + cast[int]((b).core.l_qname))))

proc bam_cigar_type(o: CigarOp): uint8 {.inline.} =
  result = uint8(BAM_CIGAR_TYPE shr (uint32(o) shl 1) and 3)

proc op*(o: CigarElement): CigarOp {.inline.} =
  ## `op` gives the operation of the cigar.
  result = CigarOp(uint8(uint32(o) and BAM_CIGAR_MASK))

proc len*(o: CigarElement): int {. inline .} =
  ## `len` gives the length of the cigar op.
  result = int(uint32(o) shr BAM_CIGAR_SHIFT)

proc `$`*(o: CigarElement): string =
  ## shows the string representation of the cigar element.
  var opstr = BAM_CIGAR_STR[int(o.op)]
  var oplen = o.len
  return intToStr(oplen) & $opstr

proc `$`*(c: Cigar): string =
  var s = ""
  for o in c:
    s &= $o
  return s

proc consumes*(o: CigarElement): Consume {. inline .} =
  result = Consume(bam_cigar_type(o.op))

proc query*(c: Consume): bool {. inline .} =
  # returns true if the op consumes bases in the query.
  result = (uint32(c) and uint8(1)) != 0

proc reference*(c: Consume): bool {. inline .} =
  # returns true if the op consumes bases in the reference.
  result = (uint32(c) and uint8(2)) != 0

type
  Range* = tuple[start: int, stop: int]

proc ref_coverage*(c: Cigar, ipos: int = 0): seq[Range] =
  if c.len == 1 and c[0].op == CigarOp.match:
    return @[(ipos, ipos + c[0].len)]

  var pos = ipos
  var posns = newSeq[Range]()
  for op in c:
    var c = op.consumes
    if not c.reference:
      #if op.op == CigarOp(soft_clip):
        # NOTE: need to check this.
      #  pos += op.len
      continue
    var olen = op.len
    if c.query:
      if len(posns) == 0 or pos != posns[len(posns)-1].stop:
        posns.add((pos, pos+olen))
      else:
        posns[len(posns)-1].stop = pos + olen
    pos += olen
  return posns
