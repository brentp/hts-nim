import hts/hts_concat
type
  Fai* = ref object of RootObj
    ## Header wraps the bam header info.
    cptr*: ptr faidx_t

proc destroy_fai(fai: Fai) =
  if fai.cptr != nil:
    fai_destroy(fai.cptr)

proc open_fai*(path: string): Fai =
  var fai : Fai
  new(fai, destroy_fai)
  fai.cptr = fai_load(cstring(path))
  if fai.cptr == nil:
    stderr.write_line("[hts-nim] error loading fai file for:", path)
    quit(1)
  return fai

proc len*(fai: Fai): int =
  return int(faidx_nseq(fai.cptr))

proc get*(fai: Fai, region: string, start:int=0, stop:int=0): string =
  var rlen: cint
  var res: cstring
  if start == 0 and stop == 0:
    res = fai_fetch(fai.cptr, cstring(region), rlen.addr)
  else:
    res = faidx_fetch_seq(fai.cptr, cstring(region), cint(start), cint(stop), rlen.addr)

  if int(rlen) == -2:
    stderr.write_line("[hts-nim] sequence ", region, " not found in fasta")
    quit(1)
  if int(rlen) == -1:
    stderr.write_line("[hts-nim] error reading sequence ", region)
  result = $res
  free(res)
