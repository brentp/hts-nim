import endians

type
  CSI* = ref object of RootObj
    idx*: ptr hts_idx_t
    cnf*: tbx_conf_t
    chroms*: seq[string]
    subtract: int

proc finalize_csi(c: CSI) =
    hts_idx_destroy(c.idx)

proc open*(csi: var CSI, base_path: string): bool =
  if csi == nil:
    new(csi, finalize_csi)
  csi.idx = hts_idx_load(base_path, HTS_FMT_CSI)
  if csi.idx == nil:
    return false

  var l_meta: cint
  var meta = hts_idx_get_meta(csi.idx, l_meta.addr)
  if meta == nil:
    return false

  var ameta = safe(cast[CPtr[uint8]](meta), int(l_meta))
  # probably a better way to do this. just cast directly to a seq[uint8]?
  var bmeta = new_seq[uint8](int(l_meta))
  for i in 0..<int(l_meta):
    bmeta[i] = ameta[i]

  var l_nm: uint32
  littleEndian32(addr csi.cnf.preset, bmeta[0].addr)
  littleEndian32(addr csi.cnf.sc, bmeta[4].addr)
  littleEndian32(addr csi.cnf.bc, bmeta[8].addr)
  littleEndian32(addr csi.cnf.ec, bmeta[12].addr)
  littleEndian32(addr csi.cnf.metachar, bmeta[16].addr)
  littleEndian32(addr csi.cnf.lineskip, bmeta[20].addr)
  littleEndian32(addr l_nm, bmeta[24].addr)

  csi.chroms = new_seq[string]()

  if l_nm < uint32(l_meta) - 28:
    return false

  # chroms are all stored in a single null-separated string
  var i = 28
  while i < int(l_nm + 28):
    var chrom: string = ""

    while ameta[i] != 0:
      chrom.add(ameta[i].char)
      i+=1
    i += 1

    csi.chroms.add(chrom)

  return true

# these are all 1-based.
proc new_csi*(seq_col: int, start_col: int, end_col: int, one_based: bool): CSI =
  var c:CSI
  new(c, finalize_csi)
  c.idx = hts_idx_init(0, HTS_FMT_CSI, 0, 14, 5)
  c.chroms = new_seq[string]()
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
  var do_copy = cint(1)
  return int(hts_idx_set_meta(idx, uint32(len(meta)), cast[ptr uint8](meta[0].addr), do_copy))

proc set_meta*(c: CSI): int =
  return idx_set_meta(c.idx, c.cnf.addr, c.chroms)
