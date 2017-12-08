import hts/hts_concat
import strutils
import system

type
  Header* = ref object of RootObj
    ## Header wraps the bam header info.
    hdr*: ptr bcf_hdr_t
  VCF* = ref object of RootObj
    ## VCF is a VCF/BCF object
    hts: ptr htsFile
    header*: Header
    c: ptr bcf1_t
    bidx: ptr hts_idx_t
    tidx: ptr tbx_t
    n_samples*: int ## number of samples in the VCF
    fname: string

  Variant* = ref object of RootObj
    ## Variant is a single line from a VCF
    c: ptr bcf1_t
    vcf: VCF
    own: bool # this seems to protect against a bug in the gc

  INFO* = ref object
    ## INFO of a variant
    v: Variant
    i: int

type CArray{.unchecked.}[T] = array[0..0, T]
type CPtr*[T] = ptr CArray[T]

include "hts/value.nim"

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

proc info*(v:Variant): INFO =
  return INFO(v:v, i:0)

proc get*(i:INFO, key:string): Value {.raises: [KeyError], inline.} =
  var info = bcf_get_info(i.v.vcf.header.hdr, i.v.c, key.cstring)
  if info == nil:
    raise newException(KeyError, key)

  if info.len == 1:
    case info.type:
      of BCF_BT_INT8:
        if info.v1.i == INT8_MIN:
          return Value(kind:typNone, xNone: true)
        return Value(kind:typInt, oInt: info.v1.i.int)
      of BCF_BT_INT16:
        if info.v1.i == INT16_MIN:
          return Value(kind:typNone, xNone: true)
        return Value(kind:typInt, oInt: info.v1.i.int)
      of BCF_BT_INT32:
        if info.v1.i == INT32_MIN:
          return Value(kind:typNone, xNone: true)
        return Value(kind:typInt, oInt: info.v1.i.int)
      of BCF_BT_FLOAT:
        if bcf_float_is_missing(info.v1.f) != 0:
          return Value(kind:typNone, xNone: true)
        return Value(kind:typFloat, oFloat: info.v1.f.float64)
      else:
        raise newException(KeyError, "unknown type: " & $int(info.type))

  if info.type == BCF_BT_CHAR:
    var t = cast[CPtr[char]](info.vptr)
    if info.vptr_len.int > 0 and t[0] == char(0x7):
      return Value(kind:typNone, xNone: true)
    # TODO: avoid copy
    var s = new_string(info.vptr_len)
    copyMem(s[0].addr.pointer, t[0].addr.pointer, info.vptr_len)
    return Value(kind:typString, oString:s)

proc destroy_vcf(v:VCF) =
  bcf_hdr_destroy(v.header.hdr)
  if v.tidx != nil:
    tbx_destroy(v.tidx)
  if v.bidx != nil:
    hts_idx_destroy(v.bidx)
  if v.fname != "-" and v.fname != "/dev/stdin":
    discard hts_close(v.hts)
  bcf_destroy(v.c)

proc open*(v:var VCF, fname:string, mode:string="r", samples:seq[string]=empty_samples, threads:int=0): bool =
  new(v, destroy_vcf)
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
  ## Each returned Variant has a pointer in the underlying iterator
  ## that is updated each iteration; use .copy to keep it in memory
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

iterator vquery(v:VCF, region:string): Variant =
  ## internal iterator for VCF regions called from query()
  if v.tidx == nil:
    v.tidx = tbx_index_load(v.fname)
  if v.tidx == nil:
    stderr.write_line("hts-nim/vcf no index found for " & v.fname)
    quit(2)

  var 
    fn:hts_readrec_func = tbx_readrec
    ret = 0
    slen = 0
    s = kstring_t()
    start: cint
    stop: cint
    tid:cint = 0

  discard hts_parse_reg(region.cstring, start.addr, stop.addr)
  var itr = hts_itr_query(v.tidx.idx, tid.cint, start, stop, fn)
    #itr = tbx_itr_querys(v.tidx, region)
  while true:
    slen = hts_itr_next(v.hts.fp.bgzf, itr, s.addr, v.tidx)
    if slen <= 0: break
    ret = vcf_parse(s.addr, v.header.hdr, v.c)
    if ret > 0:
      break
    yield Variant(c:v.c, vcf:v)

  hts_itr_destroy(itr)
  free(s.s)

iterator query*(v:VCF, region: string): Variant =
  ## iterate over variants in a VCF/BCF for the given region.
  ## Each returned Variant has a pointer in the underlying iterator
  ## that is updated each iteration; use .copy to keep it in memory
  if v.hts.format.format == htsExactFormat.vcf:
    for v in v.vquery(region):
      yield v
  else:
    if v.bidx == nil:
      v.bidx = hts_idx_load(v.fname, HTS_FMT_CSI)

    if v.bidx == nil:
      stderr.write_line("hts-nim/vcf no index found for " & v.fname)
      quit(2)
    var
      start: cint
      stop: cint
      tid:cint = 0
      fn:hts_readrec_func = bcf_readrec

    discard hts_parse_reg(region.cstring, start.addr, stop.addr)
    var itr = hts_itr_query(v.bidx, tid.cint, start, stop, fn)
    var ret = 0
    while true:
        #ret = bcf_itr_next(v.hts, itr, v.c)
        ret = hts_itr_next(v.hts.fp.bgzf, itr, v.c, nil)
        if ret < 0: break
        yield Variant(c:v.c, vcf:v)

    hts_itr_destroy(itr)
    if ret > 0:
      stderr.write_line "hts-nim/vcf: error parsing "
      quit(2)

  if v.c.errcode != 0:
    stderr.write_line "hts-nim/vcf bcf_read error:" & $v.c.errcode


proc destroy_variant(v:Variant) =
  if v != nil and v.c != nil and v.own:
    bcf_destroy(v.c)
    v.c = nil

proc copy*(v:Variant): Variant =
  ## make a copy of the variant and the underlying pointer.
  var v2: Variant
  new(v2, destroy_variant)
  v2.c = bcf_dup(v.c)
  v2.vcf = v.vcf
  v2.own = true
  return v2

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
  assert open(v, "tests/test.bcf", samples=tsamples)

  for rec in v:
    echo rec, " qual:", rec.QUAL, " filter:", rec.FILTER, "  AC (int):",  rec.info.get("AC").asints()
    var info = rec.info
    echo info.get("CSQ").asstring()
    echo info.get("AF").asfloat()

  echo v.samples

  echo "QUERY"
  for rec in v.query("1:15600-18250"):
    echo rec.CHROM, ":", $rec.POS
    var info = rec.info()
    echo info.get("AC").asint()

