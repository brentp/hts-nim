import "hts_concat"
import strutils

type
  BGZ* = ref object of RootObj
    cptr*: ptr BGZF

  BGZI* = ref object of RootObj
    bgz*: BGZ
    csi*: CSI
    path: string
    last_start: int

proc open*(b: var BGZ, path: string, mode: string) =
  if b == nil:
    b = BGZ()
  b.cptr = bgzf_open(cstring(path), cstring(mode))

proc close*(b: BGZ): int =
  return int(bgzf_close(b.cptr))

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

proc wopen_bgzi*(path: string, seq_col: int, start_col: int, end_col: int, zero_based: bool, compression_level:int=1): BGZI =
  var b: BGZ
  b.open(path, "w" & $compression_level)
  var bgzi = BGZI(bgz:b, csi: new_csi(seq_col, start_col, end_col, zero_based), path:path)
  bgzi.last_start = -100000
  return bgzi

proc write_interval*(b: BGZI, line: string, chrom: string, start: int, stop: int): int =
  if b.last_start < 0:
    b.csi.chroms.add(chrom)
  if chrom != b.csi.chroms[len(b.csi.chroms)-1]:
    b.csi.chroms.add(chrom)
  elif start < b.last_start:
    stderr.write_line("[hts-nim] starts out of order for:", b.path, " in:", line)
  b.last_start = start
  var r = b.bgz.write_line(line)
  if b.csi.add(len(b.csi.chroms) - 1, start, stop, b.bgz.tell()) < 0:
    stderr.write_line("[hts-nim] error adding to csi index")
    quit(1)
  return r

proc close*(b: BGZI): int =
   discard b.bgz.flush()
   b.csi.finish(b.bgz.tell())
   if b.csi.set_meta() != 0:
     stderr.write_line("[hts-nim] error writing CSI meta")
     quit(1)
   if b.bgz.close() < 0:
     stderr.write_line("[hts-nim] error closing bgzf")
     quit(1)
 
   b.csi.save(b.path)
