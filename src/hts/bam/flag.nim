import ../private/hts_concat
import ../utils
type
  Flag* = distinct uint16

proc `and`*(f: Flag, o: uint16): uint16 {. borrow, inline .}
proc `and`*(f: Flag, o: Flag): uint16 {. borrow, inline .}
proc `or`*(f: Flag, o: uint16): uint16 {. borrow .}
proc `or`*(o: uint16, f: Flag): uint16 {. borrow .}
proc `==`*(f: Flag, o: Flag): bool {. borrow, inline .}
proc `==`*(f: Flag, o: uint16): bool {. borrow, inline .}
proc `==`*(o: uint16, f: Flag): bool {. borrow, inline .}

proc has_flag*(f: Flag, o: uint16): bool {. inline .} =
  return (f and o) != 0

proc pair*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FPAIRED)

proc proper_pair*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FPROPER_PAIR)

proc unmapped*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FUNMAP)

proc mate_unmapped*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FMUNMAP)

proc reverse*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FREVERSE)

proc mate_reverse*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FMREVERSE)

proc read1*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FREAD1)

proc read2*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FREAD2)

proc secondary*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FSECONDARY)

proc qcfail*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FQCFAIL)

proc dup*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FDUP)

proc supplementary*(f: Flag): bool {.inline.} =
  return f.has_flag(BAM_FSUPPLEMENTARY)

proc `$`*(f:Flag): string =
  var cs = bam_flag2str(cint(f))
  result = $cs
  free(cs)
