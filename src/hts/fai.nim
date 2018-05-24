import ./private/hts_concat
type
  Fai* = ref object of RootObj
    ## Header wraps the bam header info.
    cptr*: ptr faidx_t

proc destroy_fai(fai: Fai) =
  if fai.cptr != nil:
    fai_destroy(fai.cptr)

proc open*(fai:var Fai, path: string): bool =
  ## open an fai and return a bool indicating success
  new(fai, destroy_fai)
  fai.cptr = fai_load(cstring(path))
  if fai.cptr == nil:
    stderr.write_line("[hts-nim] error loading fai file for:", path)
    return false
  return true

proc len*(fai: Fai): int =
  return int(faidx_nseq(fai.cptr))

proc chrom_len*(fai:Fai, chrom: string): int =
  ## return the length of the requested chromosome.
  result = faidx_seq_len(fai.cptr, chrom.cstring).int
  if result == -1:
    raise newException(ValueError, "chromosome " & chrom & " not found in fasta")

proc get*(fai: Fai, region: string, start:int=0, stop:int=0): string =
  var rlen: cint
  var res: cstring
  if start == 0 and stop == 0:
    res = fai_fetch(fai.cptr, cstring(region), rlen.addr)
  else:
    res = faidx_fetch_seq(fai.cptr, cstring(region), cint(start), cint(stop), rlen.addr)

  if int(rlen) == -2:
    raise newException(ValueError, "sequence " & region & " not found in fasta")
  if int(rlen) == -1:
    stderr.write_line("[hts-nim] error reading sequence ", region)
  result = $res
  free(res)
