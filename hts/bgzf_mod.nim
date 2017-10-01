import "hts_concat"
import strutils
import os

type
  BGZ* = ref object of RootObj
    cptr*: ptr BGZF

  BGZI* = ref object of RootObj
    bgz*: BGZ
    csi*: CSI
    path: string
    last_start: int

proc close*(b: BGZ): int =
  if b.cptr != nil:
    return int(bgzf_close(b.cptr))

proc open*(b: var BGZ, path: string, mode: string) =
  if b == nil:
    b = BGZ()
  b.cptr = bgzf_open(cstring(path), cstring(mode))

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
  var b : BGZ
  b.open(path, "w" & $compression_level)
  var bgzi = BGZI(bgz:b, csi: new_csi(seq_col, start_col, end_col, zero_based), path:path)
  bgzi.last_start = -100000
  return bgzi

proc ropen_bgzi*(path: string): BGZI =
  var b: BGZ
  b.open(path, "r")
  var c: CSI
  if not c.open(path):
    stderr.write_line("[hts-nim] error opening csi file for:", path)
    quit(1)
  return BGZI(bgz: b, csi:c, path:path)

type
  interval = tuple[chrom: string, start: int, stop: int, line: string]

iterator query*(bi: BGZI, chrom: string, start:int, stop:int): string =
  var tid = -1
  var fn: hts_readrec_func = tbx_readrec
  for i, cchrom in bi.csi.chroms:
    if chrom == cchrom:
      tid = i
      break
  if tid == -1:
    stderr.write_line("[hts-nim] no intervals for ", chrom, " found in ", bi.path)
  var itr = hts_itr_query(bi.csi.tbx.idx, cint(tid), cint(start), cint(stop), fn)

  var kstr = kstring_t(s:nil, m:0, l:0)

  while hts_itr_next(bi.bgz.cptr, itr, kstr.addr, bi.csi.tbx.addr) > 0:
    yield $kstr.s
  hts_itr_destroy(itr)
  assert kstr.l >= 0
  free(kstr.s)
  assert fn.addr != nil

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
