import ../private/hts_concat
import ../bgzf
import ../utils
import ../csi

type
  BGZI* = ref object
    bgz*: BGZ
    csi*: CSI
    path: string
    last_start: int

proc wopen_bgzi*(path: string, seq_col: int, start_col: int, end_col: int, zero_based: bool, compression_level:int=1, levels:int=5, min_shift:int=14): BGZI {.deprecated: "open" } =
  ## deprecated means of writing an indexed file
  var b : BGZ
  b.open(path, "w" & $compression_level)
  var bgzi = BGZI(bgz:b, csi: new_csi(seq_col, start_col, end_col, not zero_based, levels, min_shift), path:path)
  bgzi.last_start = -100000
  return bgzi

proc ropen_bgzi*(path: string): BGZI {.deprecated: "open" } =
  ## deprecated means of opening an indexed file
  var b: BGZ
  b.open(path, "r")
  var c: CSI
  if not c.open(path):
    stderr.write_line("[hts-nim] error opening csi file for:", path)
    quit(1)
  return BGZI(bgz: b, csi:c, path:path)

proc open*(b:var BGZI, path:string, mode:FileMode=fmRead, seq_col:int=0, start_col:int=0, end_col:int=0, zero_based:bool=false, compression_level:int=1, levels:int=5, min_shift:int=14): bool =

  if mode == FileMode.fmRead:
    var bg:BGZ
    bg.open(path, "r")
    var c:CSI
    if not c.open(path):
      raise newException(IOError, "hts: error opening index for " & path)
    result = true
    b = BGZI(bgz:bg, csi: c, path:path)

  elif mode == FileMode.fmWrite:
    var bg : BGZ
    bg.open(path, "w" & $compression_level)
    b = BGZI(bgz:bg, csi: new_csi(seq_col, start_col, end_col, not zero_based, levels, min_shift), path:path)
    result = true
    b.last_start = -100000
  else:
    raise newException(IOError, "hts: mode " & $mode & "not supported for bgzi")

proc fastSubStr(dest: var string; src: cstring, a, b: int) {.inline.} =
  # once the stdlib uses TR macros, these things should not be necessary
  template `+!`(src, a): untyped = cast[pointer](cast[int](src) + a)
  setLen(dest, b-a)
  copyMem(addr dest[0], src+!a, b-a)

iterator query*(bi: BGZI, chrom: string, start:int64, stop:int64): string {.inline.} =
  var tid = -1
  var fn: hts_readrec_func = tbx_readrec
  for i, cchrom in bi.csi.chroms:
    if chrom == cchrom:
      tid = i
      break
  if tid == -1:
    stderr.write_line("[hts-nim] no intervals for ", chrom, " found in ", bi.path)
  # TODO: make itr an attribute on BGZI
  var itr = hts_itr_query(bi.csi.tbx.idx, cint(tid), start, stop, cast[ptr hts_readrec_func](fn))

  var kstr = kstring_t(s:nil, m:0, l:0)
  var outstr = newStringOfCap(10000)
  shallow(outstr)

  while hts_itr_next(bi.bgz.cptr, itr, kstr.addr, bi.csi.tbx.addr) > 0:
    fastSubStr(outstr, kstr.s, 0, int(kstr.l))
    yield outstr
  hts_itr_destroy(itr)
  assert int(kstr.l) >= 0
  free(kstr.s)
  assert fn.addr != nil

proc write_interval*(b: BGZI, line: string, chrom: string, start: int, stop: int): int {.inline.} =
  if b.last_start < 0:
    b.csi.chroms.add(chrom)
  if chrom != b.csi.chroms[b.csi.chroms.high]:
    b.csi.chroms.add(chrom)
  elif start < b.last_start:
    stderr.write_line("[hts-nim] starts out of order for:", b.path, " in:", line)
  b.last_start = start
  result = b.bgz.write_line(line)
  if b.csi.add(len(b.csi.chroms) - 1, start, stop, b.bgz.tell()) < 0:
    stderr.write_line("[hts-nim] error adding to csi index")
    quit(1)

proc close*(b: BGZI): int {.discardable.} =
   discard b.bgz.flush()
   b.csi.finish(b.bgz.tell())
   if b.csi.set_meta() != 0:
     stderr.write_line("[hts-nim] error writing CSI meta")
     quit(1)
   if b.bgz.close() < 0:
     stderr.write_line("[hts-nim] error closing bgzf")
     quit(1)
   b.csi.save(b.path)
