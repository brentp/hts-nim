import hts/hts_concat
import strutils
import os

type
  BGZ* = ref object of RootObj
    cptr*: ptr BGZF

proc close*(b: BGZ): int =
  if b.cptr != nil:
    return int(bgzf_close(b.cptr))

proc open*(b: var BGZ, path: string, mode: string) =
  if b == nil:
    b = BGZ()
  b.cptr = bgzf_open(cstring(path), cstring(mode))
  if b.cptr == nil:
    stderr.write_line("[hts-nim] error opening file:", path)

proc write*(b: BGZ, line: string): int64 {.inline.} =
  bgzf_write(b.cptr, cstring(line), csize(line.len))

proc write_line*(b: BGZ, line: string): int {.inline.} =
  var r = int(bgzf_write(b.cptr, cstring(line), csize(line.len)))
  if r > 0:
    if int(bgzf_write(b.cptr, cstring("\n"), csize(1))) < 0:
      return -1
  return r + 1

proc set_threads*(b: BGZ, threads: int) =
  discard bgzf_mt(b.cptr, cint(threads), 128)

proc read_line*(b: BGZ, line:var ptr kstring_t): int {.inline.} =
  bgzf_getline(b.cptr, cint(10), line)

proc flush*(b: BGZ): int =
  return int(bgzf_flush(b.cptr))

proc tell*(b: BGZ): uint64 {.inline.} =
  return uint64(bgzf_tell(b.cptr))
