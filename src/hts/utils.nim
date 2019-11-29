import ./private/hts_concat
proc free*(a1: pointer) {.cdecl, importc: "free", header: "<stdlib.h>".}
export kstring_t, free, hts_open, hts_close
