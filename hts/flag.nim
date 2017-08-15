import "hts_concat"
const zero = uint16(0)

type
  Flag* = uint16

proc pair*(f: Flag): bool =
    return zero != (f and BAM_FPAIRED)

proc proper_pair*(f: Flag): bool =
    return zero != (f and BAM_FPROPER_PAIR)

proc unmapped*(f: Flag): bool =
    return zero != (f and BAM_FUNMAP)

proc mate_unmapped*(f: Flag): bool =
    return zero != (f and BAM_FMUNMAP)

proc reverse*(f: Flag): bool =
    return zero != (f and BAM_FREVERSE)

proc mate_reverse*(f: Flag): bool =
    return zero != (f and BAM_FMREVERSE)

proc read1*(f: Flag): bool =
    return zero != (f and BAM_FREAD1)

proc read2*(f: Flag): bool =
    return zero != (f and BAM_FREAD2)

proc secondary*(f: Flag): bool =
    return zero != (f and BAM_FSECONDARY)

proc qcfail*(f: Flag): bool =
    return zero != (f and BAM_FQCFAIL)

proc dup*(f: Flag): bool =
    return zero != (f and BAM_FDUP)

proc supplementary*(f: Flag): bool =
    return zero != (f and BAM_FSUPPLEMENTARY)
