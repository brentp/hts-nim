import hts/hts_concat
import strutils

type
  Header* = ref object of RootObj
    ## Header wraps the bam header info.
    hdr*: ptr bcf_hdr_t
  VCF* = ref object of RootObj
    ## VCF is a VCF/BCF object
    hts: ptr htsFile
    header*: Header
    c: ptr bcf1_t
    idx: ptr hts_idx_t
    n_samples*: int ## number of samples in the VCF
    fname: string

  INFO* = ref object of RootObj
    ## INFO of the VCF
    c_info: ptr bcf_info_t
    c_hdr: ptr bcf_hdr_t
    i: int

  Variant* = ref object of RootObj
    ## Variant is a single line from a VCF
    c: ptr bcf1_t
    info*: INFO
    vcf: VCF

var empty_samples:seq[string]

proc set_samples*(v:VCF, samples:seq[string]) =
  ## set the samples that will be decoded
  var isamples = samples
  if isamples == nil:
    isamples = @["-"]
  var sample_str = join(isamples, ",")
  var ret = bcf_hdr_set_samples(v.header.hdr, sample_str.cstring, 0)
  if ret < 0:
    stderr.write_line("hts-nim/vcf: error setting samples in " & v.fname)
    quit(1)

proc samples*(v:VCF): seq[string] =
  result = new_seq[string](v.n_samples)
  for i in 0..<v.n_samples:
    result[i] = $v.header.hdr.samples[i]

proc open*(v:var VCF, fname:string, mode:string="r", samples:seq[string]=empty_samples, threads:int=0): bool =
  if v == nil:
    v = VCF()
  v.hts = hts_open(fname.cstring, mode.cstring)
  if v.hts == nil:
    stderr.write_line "hts-nim/vcf: error opening file:" & fname
    return false
  
  v.header = Header(hdr:bcf_hdr_read(v.hts))
  if samples != nil:
    v.set_samples(samples)

  v.n_samples = bcf_hdr_nsamples(v.header.hdr)
  v.c = bcf_init()

  v.fname = fname

  return true

type CArray{.unchecked.}[T] = array[0..0, T]
type CPtr*[T] = ptr CArray[T]

proc bcf_hdr_id2name(hdr: ptr bcf_hdr_t, rid: cint): cstring {.inline.} =
  var v = cast[CPtr[bcf_idpair_t]](hdr.id[1])
  return v[rid.int].key

#define bcf_hdr_int2id(hdr,type,int_id) ((hdr)->id[type][int_id].key)

proc bcf_hdr_int2id(hdr: ptr bcf_hdr_t, typ: int, rid:int): cstring {.inline.} =
  var v = cast[CPtr[bcf_idpair_t]](hdr.id[typ])
  return v[rid].key

proc CHROM*(v:Variant): cstring {.inline.} =
  ## return the chromosome associated with the variant
  return bcf_hdr_id2name(v.vcf.header.hdr, v.c.rid)

iterator items*(v:VCF): Variant =
  ## note that each item yielded is only valid for that iteration.
  var ret = 0
  while true:
    ret = bcf_read(v.hts, v.header.hdr, v.c)
    if ret ==  -1:
      break
    #discard bcf_unpack(v.c, 1 or 2 or 4)
    discard bcf_unpack(v.c, BCF_UN_ALL)
    yield Variant(c:v.c, vcf:v)
  if v.c.errcode != 0:
    stderr.write_line "hts-nim/vcf bcf_read error:" & $v.c.errcode
    quit(2)

iterator at*(v:VCF, region: string): Variant =
  # TODO: index
  v.idx = hts_idx_load(v.fname, v.hts.format.format.cint)
  if v.idx == nil:
    stderr.write_line("hts-nim no index found for " & v.fname)
    quit(2)

  var
    itr = tbx_itr_querys(v.idx, region.cstring)
    slen: int
    ret: int
    s = kstring_t()
  while true:
    slen = hts_itr_next(v.hts, v.idx, itr, s.addr)
    if slen < 0:
      break
    ret = vcf_parse(s.addr, v.hdr, v.c)
    if ret > 0:
      break

    yield Variant(c:v.c, vcf:v)

  free(s.s)
  hts_itr_destroy(itr)
  if ret > 0:
    raise "hts-nim/vcf: error parsing "


proc POS*(v:Variant): int {.inline.} =
  ## return the 1-based position of the start of the variant
  return v.c.pos + 1

proc start*(v:Variant): int {.inline.} =
  ## return the 0-based position of the start of the variant
  return v.c.pos

proc stop*(v:Variant): int {.inline.} =
  ## return the 0-based position of the start of the variant
  return v.c.pos + v.c.rlen

proc ID*(v:Variant): cstring {.inline.} =
  ## the VCF ID field
  return v.c.d.id

proc FILTER*(v:Variant): string {.inline.} =
  ## Return a string representation of the FILTER will be ';' delimited for multiple values
  if v.c.d.n_flt == 0: return "PASS"
  var tmp = cast[CPtr[cint]](v.c.d.flt)
  if v.c.d.n_flt == 1:
    return $bcf_hdr_int2id(v.vcf.header.hdr, BCF_DT_ID, tmp[0].cint)

  var s = new_seq[string](v.c.d.n_flt)
  for i in 0..<v.c.d.n_flt.int:
    var v = bcf_hdr_int2id(v.vcf.header.hdr, BCF_DT_ID, tmp[i].cint)
    s[i] = $v
  return join(s, ";")

proc QUAL*(v:Variant, default:float=0): float {.inline.} =
  ## variant quality; returns default if it was unspecified in the VCF
  result = v.c.qual
  if 0 != bcf_float_is_missing(result): return default

proc REF*(v:Variant): string {.inline.} =
  ## the reference allele
  assert v.c != nil
  return $v.c.d.allele[0]

proc ALT*(v:Variant): seq[string] {.inline.} =
  ## a seq of alternate alleles
  result = new_seq[string](v.c.n_allele-1)
  for i in 1..<v.c.n_allele.int:
    result[i-1] = $(v.c.d.allele[i])

proc `$`*(v:Variant): string =
  return format("Variant($#:$# $#/$#)" % [$v.CHROM, $v.POS, $v.REF, join(v.ALT, ",")])

when isMainModule:

  var v:VCF
  var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]
  assert open(v, "tests/test.vcf", samples=tsamples)

  for rec in v:
    echo rec, " qual:", rec.QUAL, " filter:", rec.FILTER

  echo v.samples
