import ./private/hts_concat
import ./utils
type
  Fai* = ref object
    ## Fai provides random access to fasta sequences.
    cptr*: ptr faidx_t

proc close*(fai: Fai) =
  ## close the fai
  if fai.cptr != nil:
    fai_destroy(fai.cptr)

proc destroy_fai(fai: Fai) =
  fai.close

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

proc cget*(fai:Fai, region:string, start:int=0, stop:int=0): cstring {.inline.} =
  ## get the sequence for the specified region (chr1:10-20) or
  ## chromosome and start, end, e.g. "chr1", 9, 20
  ## the user is responsible for freeing the result.
  var rlen: cint
  if start == 0 and stop == 0:
    result = fai_fetch(fai.cptr, cstring(region), rlen.addr)
  else:
    result = faidx_fetch_seq(fai.cptr, cstring(region), cint(start), cint(stop), rlen.addr)

  if int(rlen) == -2:
    raise newException(KeyError, "sequence " & region & " not found in fasta")
  if int(rlen) == -1:
    stderr.write_line("[hts-nim] error reading sequence ", region)

proc get*(fai: Fai, region: string, start:int=0, stop:int=0): string =
  ## get the sequence for the specified region (chr1:10-20) or
  ## chromosome and start, end, e.g. "chr1", 9, 20
  var res = fai.cget(region, start, stop)
  result = $res
  free(res)
