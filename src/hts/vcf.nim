import ./private/hts_concat
import strutils
import system
import sequtils

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
    p: pointer
    vcf: VCF
    own: bool # this seems to protect against a bug in the gc

  INFO* = ref object
    ## INFO of a variant
    v: Variant
    i: int

  FORMAT* = ref object
    ## FORMAT exposes access to the sample format fields in the VCF
    v*: Variant
    p*: pointer

  CArray{.unchecked.}[T] = array[0..0, T]
  CPtr*[T] = ptr CArray[T]

  SafeCPtr*[T] =
    object
      size: int
      mem: CPtr[T]

  Status* {.pure.} = enum
    ## contains the values returned from the INFO for FORMAT fields.
    IncorrectNumberOfValues = -10 ## when setting a FORMAT field, the number of values must be a multiple of the number of samples
    NotFound = -3 ## Tag is not present in the Record
    UnexpectedType = -2  ## E.g. user requested int when type was float.
    UndefinedTag = -1 ## Tag is not present in the Header
    OK = 0 ## Tag was found

  BCF_HEADER_LINE* {.pure.} = enum
    BCF_HL_FLT  #0 // header line
    BCF_HL_INFO #1
    BCF_HL_FMT  #2
    BCF_HL_CTG  #3
    BCF_HL_STR  #4 // structured header line TAG=<A=..,B=..>
    BCF_HL_GEN  #5 // generic header line

proc `[]`*[T](p: SafeCPtr[T], k: int): T {.inline.} =
  when not defined(release):
    assert k < p.size
  result = p.mem[k]

proc `[]=`*[T](p: SafeCPtr[T], k: int, val: T) {.inline.} =
  when not defined(release):
    assert k < p.size
  p.mem[k] = val

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

proc add_string*(h:Header, header:string): Status =
  ## add the full string header to the VCF.
  var ret = bcf_hdr_append(h.hdr, header.cstring)
  if ret != 0:
    return Status(ret)
  return Status(bcf_hdr_sync(h.hdr))

proc add_info*(h:Header, ID:string, Number:string, Type:string, Description: string): Status =
  ## add an INFO field to the header with the given values
  return h.add_string(format("##INFO=<ID=$#,Number=$#,Type=$#,Description=\"$#\">", ID, Number, Type, Description))

proc add_format*(h:Header, ID:string, Number:string, Type:string, Description: string): Status =
  ## add a FORMAT field to the header with the given values
  return h.add_string(format("##FORMAT=<ID=$#,Number=$#,Type=$#,Description=\"$#\">", ID, Number, Type, Description))

proc info*(v:Variant): INFO {.inline.} =
  return INFO(i:0, v:v)

proc destroy_format(f:Format) =
  if f != nil and f.p != nil:
    free(f.p)

proc format*(v:Variant): FORMAT {.inline.} =
  var f:FORMAT
  new(f, destroy_format)
  f.v = v
  return f

proc c_memcpy(a, b: pointer, size: csize) {.importc: "memcpy", header: "<string.h>", inline.}

proc toSeq[T](data: var seq[T], p:pointer, n:int): Status {.inline.} =
  ## helper function to fill a sequence with data from a pointer
  ## `n` is number of elements.
  # this makes a copy but the cost of this over using the underlying directly is only ~10% for 2500 samples and
  # < 2% for 3 samples.
  if data.len != n:
    data.set_len(n)
  c_memcpy(data[0].addr.pointer, p, (n * sizeof(T)).csize)
  return Status.OK

proc ints*(f:FORMAT, key:string, data:var seq[int32]): Status =
  ## fill data with integer values for each sample with the given key
  var n:cint = 0
  var ret = bcf_get_format_values(f.v.vcf.header.hdr, f.v.c, key.cstring,
     f.p.addr, n.addr, BCF_HT_INT.cint)
  if ret < 0: return Status(ret.int)
  return toSeq[int32](data, f.p, ret.int)

proc floats*(f:FORMAT, key:string, data:var seq[float32]): Status =
  ## fill data with integer values for each sample with the given key
  var n:cint = 0
  var ret = bcf_get_format_values(f.v.vcf.header.hdr, f.v.c, key.cstring,
     f.p.addr, n.addr, BCF_HT_REAL.cint)
  if ret < 0: return Status(ret.int)
  return toSeq[float32](data, f.p, ret.int)

proc ints*(i:INFO, key:string, data:var seq[int32]): Status {.inline.} =
  ## ints fills the given data with ints associated with the key.
  var n:cint = 0

  var ret = bcf_get_info_values(i.v.vcf.header.hdr, i.v.c, key.cstring,
     i.v.p.addr, n.addr, BCF_HT_INT.cint)
  if ret < 0:
    return Status(ret.int)

  return toSeq[int32](data, i.v.p, ret.int)

proc set*(f:FORMAT, key:string, values: var seq[int32]): Status {.inline.} =
  ## set the sample fields. values must be a multiple of number of samples.
  if values.len mod f.v.vcf.n_samples != 0:
    return Status.IncorrectNumberOfValues
  var ret = bcf_update_format(f.v.vcf.header.hdr, f.v.c, key.cstring, values[0].addr.pointer, values.len.cint, BCF_HT_INT.cint)
  return Status(ret.int)

proc set*(f:FORMAT, key:string, values: var seq[float32]): Status {.inline.} =
  ## set the sample fields. values must be a multiple of number of samples.
  if values.len mod f.v.vcf.n_samples != 0:
    return Status.IncorrectNumberOfValues
  var ret = bcf_update_format(f.v.vcf.header.hdr, f.v.c, key.cstring, values[0].addr.pointer, values.len.cint, BCF_HT_REAL.cint)
  return Status(ret.int)

proc floats*(i:INFO, key:string, data:var seq[float32]): Status {.inline.} =
  ## floats fills the given data with ints associated with the key.
  ## in many cases, the user will want only a single value; in that case
  ## data will have length 1 with the single value.
  var n:cint = 0

  var ret = bcf_get_info_values(i.v.vcf.header.hdr, i.v.c, key.cstring,
     i.v.p.addr, n.addr, BCF_HT_REAL.cint)
  if ret < 0:
    return Status(ret.int)

  return toSeq[float32](data, i.v.p, ret.int)

proc strings*(i:INFO, key:string, data:var string): Status {.inline.} =
  ## strings fills the data with the value for the key and returns a bool indicating if the key was found.
  var n:cint = 0

  var ret = bcf_get_info_values(i.v.vcf.header.hdr, i.v.c, key.cstring,
     i.v.p.addr, n.addr, BCF_HT_STR.cint)
  if ret < 0:
    if data.len != 0: data.set_len(0)
    return Status(ret.int)
  data.set_len(ret.int)
  #var tmp = cast[ptr CArray[char]](i.v.p)
  #for i in 0..<ret.int:
  #  data[i] = tmp[i]
  copyMem(data[0].addr.pointer, i.v.p, ret.int)
  return Status.OK

proc has_flag*(i:INFO, key:string): bool {.inline.} =
  ## return indicates whether the flag is found in the INFO.
  var info = bcf_get_info(i.v.vcf.header.hdr, i.v.c, key.cstring)
  if info == nil or info.len != 0:
    return false
  return true

proc bcf_hdr_id2type(hdr:ptr bcf_hdr_t, htype:int, int_id:int): int {.inline.}=
  # translation of htslib macro.
  var d = cast[CPtr[bcf_idpair_t]](hdr.id[0])
  var v = d[int_id.cint].val.info[htype].int
  return (v shr 4) and 0xf

proc delete*(i:INFO, key:string): Status {.inline.} =
  ## delete the value from the INFO field  
  var info = bcf_get_info(i.v.vcf.header.hdr, i.v.c, key.cstring)
  if info == nil:
    raise newException(KeyError, "hts-nim/info: key not found:" & key)

  var htype = bcf_hdr_id2type(i.v.vcf.header.hdr, BCF_HEADER_LINE.BCF_HL_INFO.cint, info.key)
  var ret = bcf_update_info(i.v.vcf.header.hdr, i.v.c, key.cstring,nil,0,htype.cint)
  return Status(ret.int)

proc set*(i:INFO, key:string, value:var string): Status {.inline.} =
    var ret = bcf_update_info(i.v.vcf.header.hdr, i.v.c, key.cstring, value.cstring, 1, BCF_HT_STR.cint)
    return Status(ret.int)

proc set*[T: float32|float|float64](i:INFO, key:string, value:var T): Status {.inline.} =
  ## set the info key with the given float value).
  var tmp = float32(value)
  var ret = bcf_update_info(i.v.vcf.header.hdr, i.v.c, key.cstring,
      tmp.addr.pointer, 1.cint, BCF_HT_REAL.cint)
  return Status(ret.int)

proc set*[T: int32|int|int64](i:INFO, key:string, value:var T): Status {.inline.} =
  ## set the info key with the given int value).
  var tmp = int32(value)
  var ret = bcf_update_info(i.v.vcf.header.hdr, i.v.c, key.cstring,
      tmp.addr.pointer, 1.cint, BCF_HT_INT.cint)
  return Status(ret.int)

proc set*(i:INFO, key:string, values:var seq[float32]): Status {.inline.} =
  ## set the info key with the given float value(s).
  var ret = bcf_update_info(i.v.vcf.header.hdr, i.v.c, key.cstring,
      values[0].addr.pointer, len(values).cint, BCF_HT_REAL.cint)
  return Status(ret.int)

proc set*(i:INFO, key:string, values:var seq[int32]): Status {.inline.} =
  ## set the info key with the given int values.
  var ret = bcf_update_info(i.v.vcf.header.hdr, i.v.c, key.cstring,
      values[0].addr.pointer, len(values).cint, BCF_HT_INT.cint)
  return Status(ret.int)

proc n_samples*(v:Variant): int {.inline.} =
  return v.c.n_sample.int

proc destroy_variant(v:Variant) =
  if v != nil and v.c != nil and v.own:
    bcf_destroy(v.c)
    v.c = nil
  if v.p != nil:
    free(v.p)

proc destroy_vcf(v:VCF) =
  bcf_hdr_destroy(v.header.hdr)
  if v.tidx != nil:
    tbx_destroy(v.tidx)
  if v.bidx != nil:
    hts_idx_destroy(v.bidx)
  if v.fname != "-" and v.fname != "/dev/stdin" and v.hts != nil:
    discard hts_close(v.hts)
  bcf_destroy(v.c)

proc close*(v:VCF) =
  discard hts_close(v.hts)
  v.hts = nil

proc `header=`*(v: var VCF, hdr: Header) =
  v.header = Header(hdr:bcf_hdr_dup(hdr.hdr))

proc write_header*(v: VCF): bool =
  ## write a the header to the file (must have been opened in write mode) and return a bool for success.
  return bcf_hdr_write(v.hts, v.header.hdr) == 0

proc write_variant*(v:VCF, variant:Variant): bool =
  ## write a variant to the VCF opened in write mode and return a bool indicating success.
  return bcf_write(v.hts, v.header.hdr, variant.c) == 0

proc open*(v:var VCF, fname:string, mode:string="r", samples:seq[string]=empty_samples, threads:int=0): bool =
  ## open a VCF at the given path
  new(v, destroy_vcf)
  v.hts = hts_open(fname.cstring, mode.cstring)
  v.fname = fname
  if v.hts == nil:
    stderr.write_line "hts-nim/vcf: error opening file:" & fname
    return false

  if mode == "w": return true
  
  v.header = Header(hdr:bcf_hdr_read(v.hts))
  if samples != nil and samples != empty_samples:
    v.set_samples(samples)

  v.n_samples = bcf_hdr_nsamples(v.header.hdr)
  v.c = bcf_init()

  if v.c == nil:
    stderr.write_line "hts-nim/vcf: error opening file:" & fname
    return false
    
  return true

proc bcf_hdr_id2name(hdr: ptr bcf_hdr_t, rid: cint): cstring {.inline.} =
  var v = cast[CPtr[bcf_idpair_t]](hdr.id[1])
  return v[rid.int].key

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

  # all iterables share the same variant
  var variant: Variant
  new(variant, destroy_variant)

  while true:
    ret = bcf_read(v.hts, v.header.hdr, v.c)
    if ret ==  -1:
      break
    #discard bcf_unpack(v.c, 1 or 2 or 4)
    discard bcf_unpack(v.c, BCF_UN_ALL)
    variant.vcf = v
    variant.c = v.c
    yield variant
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
  tid = tbx_name2id(v.tidx, region)
  var itr = hts_itr_query(v.tidx.idx, tid.cint, start, stop, fn)
    #itr = tbx_itr_querys(v.tidx, region)
  var variant: Variant
  new(variant, destroy_variant)

  while true:
    slen = hts_itr_next(v.hts.fp.bgzf, itr, s.addr, v.tidx)
    if slen <= 0: break
    ret = vcf_parse(s.addr, v.header.hdr, v.c)
    if ret > 0:
      break
    variant.c = v.c
    variant.vcf = v
    yield variant

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
    tid = bcf_hdr_name2id(v.header.hdr, region.split(":")[0].cstring)
    var itr = hts_itr_query(v.bidx, tid, start, stop, fn)
    var ret = 0
    var variant: Variant
    new(variant, destroy_variant)
    while true:
        #ret = bcf_itr_next(v.hts, itr, v.c)
        ret = hts_itr_next(v.hts.fp.bgzf, itr, v.c, nil)
        if ret < 0: break
        variant.c = v.c
        variant.vcf = v
        yield variant

    hts_itr_destroy(itr)
    if ret > 0:
      stderr.write_line "hts-nim/vcf: error parsing "
      quit(2)

  if v.c.errcode != 0:
    stderr.write_line "hts-nim/vcf bcf_read error:" & $v.c.errcode

proc copy*(v:Variant): Variant =
  ## make a copy of the variant and the underlying pointer.
  var v2: Variant
  new(v2, destroy_variant)
  v2.c = bcf_dup(v.c)
  v2.vcf = v.vcf
  v2.own = true
  v2.p = nil
  return v2

proc POS*(v:Variant): int {.inline.} =
  ## return the 1-based position of the start of the variant
  return v.c.pos + 1

proc start*(v:Variant): int {.inline.} =
  ## return the 0-based position of the start of the variant
  return v.c.pos

proc stop*(v:Variant): int {.inline.} =
  ## return the 0-based position of the end of the variant
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

proc `QUAL=`*(v:Variant, value: float) {.inline.} =
  v.c.qual = value

proc REF*(v:Variant): string {.inline.} =
  ## the reference allele
  assert v.c != nil
  return $v.c.d.allele[0]

proc ALT*(v:Variant): seq[string] {.inline.} =
  ## a seq of alternate alleles
  result = new_seq[string](v.c.n_allele-1)
  for i in 1..<v.c.n_allele.int:
    result[i-1] = $(v.c.d.allele[i])

type
  Genotypes* = ref object
    ## Genotypes are the genotype calls for each sample.
    ## These are represented efficiently with the int32 values used in the underlying
    ## representation. However, we are able to efficiently manipulate them by adding
    ## methods to the base type.
    gts: seq[int32]
    ploidy: int

  Allele* = distinct int32
  ## An allele represents each element of a genotype.

  Genotype* = seq[Allele]
  ## A genotype is a sequence of alleles


proc copy*(g: Genotypes): Genotypes =
  ## make a copy of the genotypes
  var gts = new_seq[int32](g.gts.len)
  copyMem(gts[0].addr.pointer, g.gts[0].addr.pointer, gts.len * sizeof(int32))
  return Genotypes(gts:gts, ploidy:g.ploidy)

proc phased*(a:Allele): bool {.inline.} =
  ## is the allele pahsed.
  return (int32(a) and 1) == 1

proc value*(a:Allele): int {.inline.} =
  ## e.g. 0 for REF, 1 for first alt, -1 for unknown.
  return (int32(a) shr 1) - 1

proc `[]`*(g:Genotypes, i:int): seq[Allele] {.inline.} =
  var alleles = new_seq[Allele](g.ploidy)
  for k, v in g.gts[i*g.ploidy..<(i+1)*g.ploidy]:
    alleles[k] = Allele(v)

  return alleles

proc len*(g:Genotypes): int {.inline.} =
  ## this should match the number of samples.
  return int(len(g.gts) / g.ploidy)

iterator items*(g:Genotypes): Genotype =
  for k in 0..<g.len:
    yield g[k]

proc `$`*(a:Allele): string {.inline.} =
  ## string representation of a single allele.
  (if a.value < 0: "." else: intToStr(a.value)) & (if a.phased: '|' else: '/')

proc `$`*(g:Genotype): string {.inline.} =
  ## string representation of a genotype. removes trailing phase value.
  result = join(map(g, proc(a:Allele): string = $a), "")
  if result[result.len - 1] == '/' or result[result.len - 1] == '|':
    result.set_len(result.len - 1)

proc alts*(g:Genotype): int8 {.inline.} =
  ## the number of alternate alleles in the genotype. only makes sense for bi-allelics.
  ## ./1 == 1
  ## 0/. == 0
  ## ./. -> -1
  ## 1/1 -> 2
  if g.len == 2:
    var g0 = g[0].value
    var g1 = g[1].value
    if g0 != -1 and g1 != -1:
      return int8(g0 + g1)
    # only unknown if both are unknown
    if g0 == -1 and g1 == -1:
      return -1

    if g0 == -1:
      return int8(g1)
    if g1 == -1:
      return int8(g0)

  var has_unknown = false
  for a in g:
    if a.value == -1:
      has_unknown = true
      break

  if not has_unknown:
    var nalts = 0
    for a in g:
      nalts += a.value
    return int8(nalts)
  raise newException(OSError, "not implemented for:" & $g)

proc genotypes*(f:FORMAT, gts: var seq[int32]): Genotypes =
  ## give sequence of genotypes (using the underlying array given in gts)
  if f.ints("GT", gts) != Status.OK:
    return nil
  result = Genotypes(gts: gts, ploidy: int(gts.len/f.v.n_samples))

proc `$`*(gs:Genotypes): string =
  var x = new_seq_of_cap[string](gs.len)
  for g in gs:
    x.add($g)
  return '[' & join(x, ", ") & ']'

proc alts*(gs:Genotypes): seq[int8] =
  ## return the number of alternate alleles. Unknown is -1.
  result = new_seq_of_cap[int8](gs.len)
  for g in gs:
    result.add(g.alts)

proc `$`*(v:Variant): string =
  return format("Variant($#:$# $#/$#)" % [$v.CHROM, $v.POS, $v.REF, join(v.ALT, ",")])

proc tostring*(v:Variant): string =
  ## return the full variant string including new-line from vcf_format.
  var s = kstring_t(s:nil, l:0, m:0)
  if vcf_format(v.vcf.header.hdr, v.c, s.addr) != 0:
    raise newException(ValueError, "hts-nim/format error for variant")
  result = $s.s
  free(s.s)

when isMainModule:

  var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]

  for k in 0..2000:
    var v:VCF
    if k mod 200 == 0:
      stderr.write_line $k
    discard open(v, "tests/test.vcf.gz", samples=tsamples)
    var ac = new_seq[int32](10)
    var af = new_seq[float32](10)
    var dps = new_seq[int32](20)
    var ads = new_seq[int32](20)
    var bad = new_seq[float32](20)
    var csq = new_string_of_cap(1000)
    for rec in v:
      if rec.n_samples != tsamples.len:
        quit(2)
      echo rec.tostring()
      discard rec.info.ints("AC", ac)
      discard rec.info.floats("AF", af)
      discard rec.info.strings("CSQ", csq)
      echo rec, " qual:", rec.QUAL, " filter:", rec.FILTER, "  AC (int):",  ac, " AF(float):", af, " CSQ:", csq
      if rec.info.has_flag("in_exac_flag"):
        echo "FOUND"
      var f = rec.format()
      discard f.ints("DP", dps)
      discard f.ints("AD", ads)
      echo dps, " ads:", ads
      if f.floats("BAD", bad) != Status.UndefinedTag:
        quit(2)
      var gts = f.genotypes(ac)
      echo gts
      echo gts.copy()
      echo gts.alts

    echo v.samples

    echo "QUERY"
    for rec in v.query("1:15600-18250"):
      echo rec.CHROM, ":", $rec.POS
      var info = rec.info()
      discard info.ints("AC", ac)
