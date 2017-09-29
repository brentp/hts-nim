import endians

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
