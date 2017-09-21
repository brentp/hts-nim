import "hts_concat"
import strutils

type
  BGZ* = ref object of RootObj
    cptr*: ptr BGZF

  CSI* = ref object of RootObj
    idx*: ptr hts_idx_t
    cnf*: tbx_conf_t
    subtract: int

  BGZI* = ref object of RootObj
    bgz*: BGZ
    csi*: CSI
    path: string
    chroms*: seq[string]
    last_start: int

proc idx_set_meta*(idx: ptr hts_idx_t; tc: ptr tbx_conf_t; chroms: seq[string]): int =
  var x: array[7, uint32]
  x[0] = uint32(tc.preset)
  x[1] = uint32(tc.sc)
  x[2] = uint32(tc.bc)
  x[3] = uint32(tc.ec)
  x[4] = uint32(tc.metachar)
  x[5] = uint32(tc.lineskip)
  var l = 0
  for chrom in chroms:
    l += chrom.len + 1
  x[6] = uint32(l)
  var meta = new_seq[uint8](28 + l)
  copyMem(cast[pointer](meta[0].addr), cast[pointer](x[0].addr), 28)
  var cs: cstring

  var offset = 28
  # copy each chrom, char by char into the meta array and leave the 0 (NULL) at the end of each.
  for chrom in chroms:
    for c in chrom:
      meta[offset] = uint8(c)
      offset += 1
    offset += 1
  return int(hts_idx_set_meta(idx, uint32(len(meta)), cast[ptr uint8](meta[0].addr), cint(1)))

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

# these are all 1-based.
proc new_csi*(seq_col: int, start_col: int, end_col: int, one_based: bool): CSI =
  var c = CSI()
  c.idx = hts_idx_init(0, HTS_FMT_CSI, 0, 14, 5)
  # automatically set the comment char to '#'
  c.cnf = tbx_conf_t(preset: int32(0), sc: int32(seq_col), bc: int32(start_col), ec: int32(end_col), meta_char: int32('#'), line_skip: int32(0))
  if one_based:
    c.subtract = 1
  else:
    c.subtract = 0

  return c

proc add*(c: CSI, tid: int, start: int, stop: int, offset:uint64): int {.inline.} =
  return int(hts_idx_push(c.idx, cint(tid), cint(start - c.subtract), cint(stop), offset, 1))

proc finish*(c: CSI, offset: uint64) =
  hts_idx_finish(c.idx, offset)

proc save*(c: CSI, path: string) =
  hts_idx_save(c.idx, cstring(path), HTS_FMT_CSI)

# int l_meta, uint8_t *meta, int is_copy
proc set_meta*(c: CSI, chroms: seq[string]): int =
  return idx_set_meta(c.idx, c.cnf.addr, chroms)

proc wopen_bgzi*(path: string, seq_col: int, start_col: int, end_col: int, zero_based: bool, compression_level:int=1): BGZI =
  var b: BGZ
  b.open(path, "w" & $compression_level)
  var bgzi = BGZI(bgz:b, csi: new_csi(seq_col, start_col, end_col, zero_based), path:path)
  bgzi.chroms = new_seq[string]()
  bgzi.last_start = -100000
  return bgzi

proc write_interval*(b: BGZI, line: string, chrom: string, start: int, stop: int): int =
  if b.last_start < 0:
    b.chroms.add(chrom)
  if chrom != b.chroms[len(b.chroms)-1]:
    b.chroms.add(chrom)
  elif start < b.last_start:
    stderr.write_line("[hts-nim] starts out of order for:", b.path, " in:", line)
  b.last_start = start
  var r = b.bgz.write_line(line)
  if b.csi.add(len(b.chroms) - 1, start, stop, b.bgz.tell()) < 0:
    stderr.write_line("[hts-nim] error adding to csi index")
    quit()
  return r

proc close*(b: BGZI): int =
   discard b.bgz.flush()
   b.csi.finish(b.bgz.tell())
   if b.csi.set_meta(b.chroms) != 0:
     stderr.write_line("[hts-nim] error writing CSI meta")
     quit()
   if b.bgz.close() < 0:
     stderr.write_line("[hts-nim] error closing bgzf")
     quit()
 
   b.csi.save(b.path)
   hts_idx_destroy(b.csi.idx)
