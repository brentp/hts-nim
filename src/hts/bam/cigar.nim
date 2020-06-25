import ../private/hts_concat
import strutils
# https://forum.nim-lang.org/t/567 (by Jehan)
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
#
when defined(nimUncheckedArrayTyp):
  type CArray[T] = UncheckedArray[T]
else:
  type CArray[T]{.unchecked.} = array[0..0, T]

type CPtr*[T] = ptr CArray[T]

# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

type
  Cigar* = object
    ## `Cigar` represents ths SAM Cigar type. It consists of one or more `CigarElement` s.
    cig: CPtr[uint32]
    n: uint32

  CigarElement* = distinct uint32 ## `CigarElement` encodes the operation (length and type) of each element of a `Cigar`.

  Consume* = distinct uint32

type CigarOp* {.pure.} = enum
  match = 0'u32, insert, deletion, ref_skip, soft_clip, hard_clip, pad, equal, diff, back

proc `==`*(a, b: CigarElement): bool {.borrow.}


proc `$`*(o:CigarOp): char {.inline.} =
  return "MIDNSHP=XB"[int(o)]

proc newCigar(p: ptr uint32, n: uint32): Cigar {.inline.} =
  result = Cigar(cig: cast[CPtr[uint32]](p), n:n)

proc len*(c: Cigar): int {. inline .} =
  ## returns the number of operations in the cigar.
  result = int(c.n)

proc `[]`*(c:Cigar, i:int): CigarElement {.inline.} =
  when defined(debug):
    if i >= c.n.int: raise newException(IndexError, "error getting " & $i & " element with length " & $c.n)
  return cast[CigarElement](c.cig[i])

iterator items*(c: Cigar): CigarElement =
  ## iterates over the ops in the cigar.
  for i in 0..<c.n.int:
    yield cast[CigarElement](c.cig[i])

template bam_get_cigar*(b: untyped): untyped =
  (cast[ptr uint32](((cast[int]((b).data)) + cast[int]((b).core.l_qname))))

const BAM_CIGAR_TYPEu = BAM_CIGAR_TYPE.uint32

proc bam_cigar_type(o: CigarOp): uint32 {.inline.} =
  result = (BAM_CIGAR_TYPEu shr (cast[uint32](o) shl 1'u32) and 3'u32)

proc op*(o: CigarElement): CigarOp {.inline.} =
  ## `op` gives the operation of the cigar.
  result = cast[CigarOp](cast[uint32](o) and BAM_CIGAR_MASK)

proc len*(o: CigarElement): int {. inline .} =
  ## `len` gives the length of the cigar op.
  result = int(cast[uint32](o) shr BAM_CIGAR_SHIFT)

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

proc newCigar*(els: var seq[CigarElement]): Cigar =
  ## create a new cigar from a sequence of cigar elements.
  ## This uses a pointer to the elements so user is responsible for ensuring that `els` remain
  ## in memory (e.g. with GC_ref) for as long as the  resulting Cigar is available.
  var x = cast[CPtr[uint32]](els[0].addr)
  result = Cigar(cig: x, n: els.len.uint32)

template consumes*(o: CigarElement): Consume =
  cast[Consume](bam_cigar_type(o.op))

template query*(c: Consume): bool =
  ## returns true if the op consumes bases in the query.
  (cast[uint32](c) and 1'u32) != 0

template reference*(c: Consume): bool =
  ## returns true if the op consumes bases in the reference.
  (cast[uint32](c) and 2'u32) != 0

type
  Range* = tuple[start: int, stop: int]

proc ref_coverage*(c: Cigar, ipos: int = 0): seq[Range] {.deprecated.} =
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
