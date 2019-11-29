import ./private/hts_concat
import ./utils

type
  CSI* = ref object
    tbx*: tbx_t
    chroms*: seq[string]
    subtract: int
    meta: seq[uint8] # see: https://github.com/samtools/htslib/issues/936

proc finalize_csi*(c: CSI) =
  if c != nil and c.tbx.idx != nil:
    hts_idx_destroy(c.tbx.idx)

proc open*(csi: var CSI, base_path: string): bool =
  new(csi, finalize_csi)
  var ptbx = tbx_index_load2(base_path, base_path & ".csi")
  if ptbx == nil:
    return false
  csi.tbx = ptbx[]
  #free(ptbx)
  var n: cint
  var names = tbx_seqnames(csi.tbx.addr, n.addr);
  csi.chroms = new_seq[string](int(n))
  for i in 0..<int(n):
    csi.chroms[i] = $names[i]
  if csi.chroms.len > 0:
    if csi.chroms[csi.chroms.high] == "":
      csi.chroms.setLen(csi.chroms.high)
  free(names)
  return true

# these are all 1-based.
proc new_csi*(seq_col: int, start_col: int, end_col: int, one_based: bool, levels:int=5, min_shift:int=14): CSI =
  var c:CSI
  new(c, finalize_csi)
  var tbx: tbx_t
  tbx.idx = hts_idx_init(0, HTS_FMT_CSI, 0, min_shift.cint, levels.cint)
  if tbx.idx == nil:
    stderr.write_line("[hts-nim] error creating index in new_csi")
    quit(1)
  c.chroms = new_seq[string]()
  # automatically set the comment char to '#'
  tbx.conf = tbx_conf_t(preset: int32(0), sc: int32(seq_col), bc: int32(start_col), ec: int32(end_col), meta_char: int32('#'), line_skip: int32(0))
  if one_based:
    c.subtract = 1
  else:
    c.subtract = 0
  c.tbx = tbx
  return c

proc add*(c: CSI, tid: int, start: int, stop: int, offset:uint64): int {.inline.} =
  hts_idx_push(c.tbx.idx, cint(tid), cint(start - c.subtract), cint(stop), offset, 1)

proc finish*(c: CSI, offset: uint64) =
  hts_idx_finish(c.tbx.idx, offset)

proc save*(c: CSI, path: string) =
  hts_idx_save(c.tbx.idx, cstring(path), HTS_FMT_CSI)

proc idx_set_meta*(csi:var CSI, idx: ptr hts_idx_t; tc: ptr tbx_conf_t; chroms: seq[string]): int =
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
  csi.meta = new_seq[uint8](28 + l)
  copyMem(csi.meta[0].addr, x[0].addr, 28)

  var offset = 28
  # copy each chrom, char by char into the meta array and leave the 0 (NULL) at the end of each.
  for chrom in chroms:
    for c in chrom:
      csi.meta[offset] = uint8(c)
      offset += 1
    offset += 1
  doAssert offset == len(csi.meta)
  # https://github.com/samtools/htslib/issues/936
  var do_copy = cint(0)
  return int(hts_idx_set_meta(idx, uint32(len(csi.meta)), csi.meta[0].addr, do_copy))

proc set_meta*(c: var CSI): int =
  return c.idx_set_meta(c.tbx.idx, c.tbx.conf.addr, c.chroms)
