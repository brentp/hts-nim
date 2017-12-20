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

  Status {.pure.} = enum
    ## contains the values returned from the INFO for FORMAT fields.
    NotFound = -3 ## Tag is not present in the Record
    UnexpectedType = -2  ## E.g. user requested int when type was float.
    UndefinedTag = -1 ## Tag is not present in the Header
    OK = 0 ## Tag was found

proc safe*[T](p: CPtr[T], k: int): SafeCPtr[T] {.inline.} =
    SafeCPtr[T](mem: p, size: k)

proc `[]`*[T](p: SafeCPtr[T], k: int): T {.inline.} =
  when not defined(release):
    assert k < p.size
  result = p.mem[k]

proc `[]=`*[T](p: SafeCPtr[T], k: int, val: T) {.inline.} =
  when not defined(release):
    assert k < p.size
  p.mem[k] = val

proc `$`*[T](p: SafeCPtr[T]): string =
  result = new_string_of_cap(40)
  result.add("[")
  for i in 0..<p.size:
    result.add(intToStr(int(p[i])) & ", ")
  result[result.len - 2] = ']'
  result.set_len(result.len-1)

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

proc toseq[T](data: var seq[T], p:pointer, n:int): Status {.inline.} =
  ## helper function to fill a sequence with data from a pointer
  if data == nil:
    data = new_seq[T](n)
  elif data.len != n:
    data.set_len(n)

  var tmp = cast[ptr CArray[T]](p)
  for i in 0..<n:
    data[i] = tmp[i]
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

proc has_flag(i:INFO, key:string): bool {.inline.} =
  ## return if the flag is found in the INFO.
  var info = bcf_get_info(i.v.vcf.header.hdr, i.v.c, key.cstring)
  if info == nil or info.len != 0:
    return false
  return true

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

  if v.c == nil:
    stderr.write_line "hts-nim/vcf: error opening file:" & fname
    return false
    
  v.fname = fname

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
    var itr = hts_itr_query(v.bidx, tid.cint, start, stop, fn)
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

  var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]

  for k in 0..2000:
    var v:VCF
    stderr.write_line $k
    discard open(v, "tests/test.vcf.gz", samples=tsamples)
    var ac = new_seq[int32](10)
    var af = new_seq[float32](10)
    var dps = new_seq[int32](20)
    var ads = new_seq[int32](20)
    var bad = new_seq[float32](20)
    var csq = new_string_of_cap(1000)
    for rec in v:
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

    echo v.samples

    echo "QUERY"
    for rec in v.query("1:15600-18250"):
      echo rec.CHROM, ":", $rec.POS
      var info = rec.info()
      discard info.ints("AC", ac)
      echo ac
