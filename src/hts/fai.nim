import ./private/hts_concat
type
  Fai* = ref object
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

proc len*(fai: Fai): int {.inline.} =
  ## the number of sequences in the index.
  return int(faidx_nseq(fai.cptr))

proc chrom_len*(fai:Fai, chrom: string): int =
  ## return the length of the requested chromosome.
  result = faidx_seq_len(fai.cptr, chrom.cstring).int
  if result == -1:
    raise newException(ValueError, "chromosome " & chrom & " not found in fasta")

proc `[]`*(fai:Fai, i:int): string {.inline.} =
  ## return the name of the i'th sequence.
  if i < 0 or i >= fai.len:
    raise newException(IndexError, "cant access sequence:" & $i)
  var cname = faidx_iseq(fai.cptr, i.cint)
  result = $cname

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
