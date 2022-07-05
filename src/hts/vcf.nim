import ./private/hts_concat
import ./utils
import strformat
import strutils
import system
import sequtils


when defined(nimUncheckedArrayTyp):
  type CArray[T] = UncheckedArray[T]
else:
  type CArray[T]{.unchecked.} = array[0..0, T]

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
    fname*: string

  Variant* = ref object
    ## Variant is a single line from a VCF
    c*: ptr bcf1_t
    p: pointer
    vcf*: VCF
    own: bool # this seems to protect against a bug in the gc

  INFO* = ref object
    ## INFO of a variant
    v: Variant
    i: int32

  FORMAT* = ref object
    ## FORMAT exposes access to the sample format fields in the VCF
    v*: Variant
    p*: pointer


  CPtr*[T] = ptr CArray[T]

  Status* {.pure.} = enum
    ## contains the values returned from the INFO for FORMAT fields.
    IncorrectNumberOfValues = -10 ## when setting a FORMAT field, the number of values must be a multiple of the number of samples
    NotFound = -3 ## Tag is not present in the Record
    UnexpectedType = -2  ## E.g. user requested int when type was float.
    UndefinedTag = -1 ## Tag is not present in the Header
    OK = 0 ## Tag was found

  BCF_HEADER_TYPE* {.pure.} = enum
    BCF_HL_FLT  #0 // header line
    BCF_HL_INFO #1
    BCF_HL_FMT  #2
    BCF_HL_CTG  #3
    BCF_HL_STR  #4 // structured header line TAG=<A=..,B=..>
    BCF_HL_GEN  #5 // generic header line

  BCF_TYPE* {.pure.} = enum
    NULL = 0
    INT8 = 1
    INT16 = 2
    INT32 = 3
    FLOAT = 5
    CHAR = 7

var empty_samples: seq[string]

converter toInt(b:BCF_HEADER_TYPE): int = b.int
converter toCint(b:BCF_HEADER_TYPE): cint = b.cint

proc destroy_variant(v:Variant) =
  if v != nil and v.c != nil and v.own:
    bcf_destroy(v.c)
    v.c = nil
  if v.p != nil:
    free(v.p)

proc destroy_format(f:Format) =
  if f != nil and f.p != nil:
    free(f.p)

proc n_samples*(v:VCF): int {.inline.} =
  bcf_hdr_nsamples(v.header.hdr).int

proc set_samples*(v:VCF, samples:seq[string]) =
  ## set the samples that will be decoded
  ## use v.set_samples(@["^"]) to exclude all samples.
  var isamples = samples
  if isamples.len == 0:
    isamples = @["-"]
  var sample_str = join(isamples, ",").cstring 
  if isamples.len == 1 and (samples.len == 0 or samples[0] == "^"):
    sample_str = nil
  var ret = bcf_hdr_set_samples(v.header.hdr, sample_str, 0)
  doAssert ret >= 0, ("[hts-nim/vcf]: error setting samples in " & v.fname)
  doAssert bcf_hdr_sync(v.header.hdr) == 0, "[hts/nim-vcf] error in vcf.set_samples"

proc samples*(v:VCF): seq[string] =
  ## get the list of samples
  result = new_seq[string](v.n_samples)
  for i in 0..<v.n_samples:
    result[i] = $v.header.hdr.samples[i]

proc add_sample*(v:VCF, sample:string) =
  ## add a sample to the VCF
  doAssert bcf_hdr_add_sample(v.header.hdr, sample.cstring) == 0, "error adding sample to header"
  doAssert bcf_hdr_sync(v.header.hdr) == 0, "error adding sample to header"

proc add_string*(h:Header, header:string): Status {.inline.} =
  ## add the full string header to the VCF.
  var ret = bcf_hdr_append(h.hdr, header.cstring)
  if ret != 0:
    return Status(ret)
  return Status(bcf_hdr_sync(h.hdr))

proc `$`*(h:Header): string =
  ## return the string header
  var str = kstring_t(s:nil, l:0, m:0)
  if bcf_hdr_format(h.hdr, 0, str.addr) != 0:
    raise newException(ValueError, "hts-nim/Header/$: error in bcf_hdr_format:")
  result = $str.s
  free(str.s)

type
  HeaderRecord* = object
    ## HeaderRecord represents a row from the VCF header (hrec from htslib)
    name*: string
    # TODO: val
    c: ptr bcf_hrec_t

proc `$`*(h:HeaderRecord): string =
  result.add('{')
  for i in 0..<h.c.nkeys:
    result.add($h.c.keys[i] & ':' & $h.c.vals[i])
    if i < h.c.nkeys - 1:
      result.add(", ")
  result.add('}')

proc `[]`*(h:HeaderRecord, key: string): string =
  ## get the value from the recode, key can be, for example
  ## ID or Description or Number or Type
  for i in 0..<h.c.nkeys:
    if $h.c.keys[i] == key:
      return $h.c.vals[i]
  raise newException(KeyError, key & " not found in description")

proc get*(h:Header, name: string, typ:BCF_HEADER_TYPE): HeaderRecord =
  ## get the HeaderRecord for the given name.
  var hrec: ptr bcf_hrec_t
  if typ == BCF_HEADER_TYPE.BCF_HL_GEN:
    hrec = h.hdr.bcf_hdr_get_hrec(BCF_HL_GEN, name, nil, nil)
  else:
    hrec = h.hdr.bcf_hdr_get_hrec(typ, "ID", name, nil)
  if hrec == nil:
    raise newException(KeyError, name & " not found in header")
  return HeaderRecord(name: name, c: hrec)

proc from_string*(h: var Header, s:string) =
  ## create a new header from a VCF header string.
  if h == nil:
      h = Header()
  if h.hdr == nil:
      h.hdr = bcf_hdr_init("w".cstring);
  if bcf_hdr_parse(h.hdr, s.cstring) != 0:
   raise newException(ValueError, "hts-nim/Header/from_string: error setting header with:" & s)
  if bcf_hdr_sync(h.hdr) != 0:
   raise newException(ValueError, "hts-nim/Header/from_string: error setting header with:" & s)

proc add_info*(h:Header, ID:string, Number:string, Type:string, Description: string): Status =
  ## add an INFO field to the header with the given values
  return h.add_string(format("##INFO=<ID=$#,Number=$#,Type=$#,Description=\"$#\">", ID, Number, Type, Description))

proc remove_info*(h:Header, ID:string): Status =
  ## remove an INFO field from the header
  bcf_hdr_remove(h.hdr, BCF_HEADER_TYPE.BCF_HL_INFO.cint, ID.cstring)
  return Status(bcf_hdr_sync(h.hdr))

proc add_format*(h:Header, ID:string, Number:string, Type:string, Description: string): Status =
  ## add a FORMAT field to the header with the given values
  return h.add_string(format("##FORMAT=<ID=$#,Number=$#,Type=$#,Description=\"$#\">", ID, Number, Type, Description))

proc remove_format*(h:Header, ID:string): Status =
  ## remove a FORMAT field from the header
  bcf_hdr_remove(h.hdr, BCF_HEADER_TYPE.BCF_HL_FMT.cint, ID.cstring)
  return Status(bcf_hdr_sync(h.hdr))

proc destroy_vcf(v:VCF) =
  if v.header != nil and v.header.hdr != nil:
    bcf_hdr_destroy(v.header.hdr)
    v.header.hdr = nil
  if v.tidx != nil:
    tbx_destroy(v.tidx)
  if v.bidx != nil:
    hts_idx_destroy(v.bidx)
  if v.c != nil:
    bcf_destroy(v.c)
  if v.fname != "-" and v.fname != "/dev/stdin":
    if v.hts != nil:
      if hts_close(v.hts) != 0:
        stderr.write_line "[hts-nim] underlying error closing vcf file"
      v.hts = nil
  else:
    flushFile(stdout)

var
  errno* {.importc, header: "<errno.h>".}: cint

proc strerror(errnum:cint): cstring {.importc, header: "<errno.h>", cdecl.}


proc open*(v:var VCF, fname:string, mode:string="r", samples:seq[string]=empty_samples, threads:int=0): bool =
  ## open a VCF at the given path
  new(v, destroy_vcf)
  var vmode = mode
  if vmode[0] == 'w' and vmode.len == 1:
    if fname.endswith(".gz"): vmode &= "z"
    elif fname.endswith(".bcf"): vmode &= "b"

  v.hts = hts_open(fname.cstring, vmode.cstring)
  v.fname = fname
  if v.hts == nil:
    stderr.write_line "hts-nim/vcf: error opening file:" & fname & ". " & $strerror(errno)
    return false

  if mode[0] == 'w': return true

  if mode[0] == 'r' and 0 != threads and 0 != hts_set_threads(v.hts, cint(threads)):
    raise newException(ValueError, "error setting number of threads")


  v.header = Header(hdr:bcf_hdr_read(v.hts))
  if v.header.hdr == nil:
    raise newException(OSError, &"[hts-nim/vcf] error reading VCF header from '{fname}'")
  if samples.len != 0:
    v.set_samples(samples)

  v.c = bcf_init()

  if v.c == nil:
    stderr.write_line "hts-nim/vcf: error opening file:" & fname
    return false

  return true

proc newVariant*(): Variant {.noInit.} =
  ## make an empty variant.
  new(result, destroy_variant)
  result.c = bcf_init()
  result.own = true

proc format*(v:Variant): FORMAT {.inline.} =
  discard bcf_unpack(v.c, BCF_UN_ALL)
  new(result, destroy_format)
  result.v = v
  result.p = nil

proc n_samples*(v:Variant): int {.inline.} =
  return v.c.n_sample.int

proc toSeq[T](data: var seq[T], p:pointer, n:int) {.inline.} =
  ## helper function to fill a sequence with data from a pointer
  ## `n` is number of elements.
  # this makes a copy but the cost of this over using the underlying directly is only ~10% for 2500 samples and
  # < 2% for 3 samples.
  if data.len != n:
    data.set_len(n)
  if n == 0: return
  copyMem(data[0].addr, p, csize_t(n * sizeof(T)))

proc bcf_hdr_id2type(hdr:ptr bcf_hdr_t, htype:int, int_id:int): int {.inline.}=
  # translation of htslib macro.
  var d = cast[CPtr[bcf_idpair_t]](hdr.id[0])
  var v = d[int_id.cint].val.info[htype].int
  return (v shr 4) and 0xf

proc delete*(f:FORMAT, key:string): Status {.inline.} =
  ## delete the value from the FORMAT field for all samples
  var fmt = bcf_get_fmt(f.v.vcf.header.hdr, f.v.c, key.cstring)
  if fmt == nil:
    raise newException(KeyError, "hts-nim/format field not found:" & key)

  var htype = bcf_hdr_id2type(f.v.vcf.header.hdr, BCF_HEADER_TYPE.BCF_HL_FMT.cint, fmt.id)
  result = Status(bcf_update_format(f.v.vcf.header.hdr, f.v.c, key.cstring, nil, 0, htype.cint).int)


proc get*(f:FORMAT, key:string, data:var seq[int32]): Status {.inline.} =
  ## fill data with integer values for each sample with the given key
  var n:cint = 0
  var ret = bcf_get_format_values(f.v.vcf.header.hdr, f.v.c, key.cstring,
     f.p.addr, n.addr, BCF_HT_INT.cint)
  if unlikely(ret < 0):
    result = Status(ret.int)
    return
  result = Status.OK
  toSeq[int32](data, f.p, ret.int)


proc get*(f:FORMAT, key:string, data:var seq[float32]): Status {.inline.} =
  ## fill data with float values for each sample with the given key
  var n:cint = 0
  var ret = bcf_get_format_values(f.v.vcf.header.hdr, f.v.c, key.cstring,
     f.p.addr, n.addr, BCF_HT_REAL.cint)
  if unlikely(ret < 0):
      result = Status(ret.int)
      return
  result = Status.OK
  toSeq[float32](data, f.p, ret.int)

proc get*(f:FORMAT, key:string, data:var seq[string]): Status {.inline.} =
  ## fill data with string values for each sample with the given key
  var n:cint = 0
  var ret = bcf_get_format_values(f.v.vcf.header.hdr, f.v.c, key.cstring, f.p.addr, n.addr, BCF_HT_STR.cint)
  # now f.p is a single char* with values from all samples.
  if ret < 0:
      result = Status(ret.int)
      return
  # extract the per-sample strings which are fixed-length.
  var cs = cast[cstring](f.p)
  var n_per = int(n / f.v.n_samples)
  if data.len != f.v.n_samples:
      data.set_len(f.v.n_samples)

  for isample in 0..<data.len:
    data[isample] = $(cast[cstring](cs[isample * n_per].addr))
  result = Status.OK

proc set*(f:FORMAT, key:string, data:var seq[string]): Status {.inline.} =
  ## set the format field with the given strings.
  if data.len != f.v.vcf.n_samples:
    # TODO: support Number other than 1.
    return Status.IncorrectNumberOfValues

  ## with char*, we have a single string that's \0 padded to make all
  ## samples have the same length. so we calc the max length.
  var lmax = data[0].len
  for d in data:
    lmax = max(lmax, d.len)

  # then fill the cstr with the data from each sample.
  var cstr = newString(lmax * data.len)
  for i, d in data:
    var off = i * lmax
    for k, c in d:
        cstr[off + k] = c

  var ret = bcf_update_format(f.v.vcf.header.hdr, f.v.c, key.cstring, cstr[0].addr.pointer, cstr.len.cint, BCF_HT_STR.cint)
  return Status(ret.int)

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

proc get*(i:INFO, key:string, data:var seq[int32]): Status {.inline.} =
  ## fills the given data with ints associated with the key.
  result = Status.OK
  var n:cint = 0

  var ret = bcf_get_info_values(i.v.vcf.header.hdr, i.v.c, key.cstring,
     i.v.p.addr, n.addr, BCF_HT_INT.cint)
  if ret < 0:
    result = Status(ret.int)
    return

  toSeq[int32](data, i.v.p, ret.int)

proc get*(i:INFO, key:string, data:var seq[float32]): Status {.inline.} =
  ## fills the given data with ints associated with the key.
  ## in many cases, the user will want only a single value; in that case
  ## data will have length 1 with the single value.
  var n:cint = 0
  result = Status.OK

  var ret = bcf_get_info_values(i.v.vcf.header.hdr, i.v.c, key.cstring,
     i.v.p.addr, n.addr, BCF_HT_REAL.cint)
  if ret < 0:
    result = Status(ret.int)
    return

  toSeq[float32](data, i.v.p, ret.int)

proc get*(i:INFO, key:string, data:var string): Status {.inline.} =
  ## fills the data with the value for the key and returns a Status indicating success
  var n:cint = 0
  result = Status.OK

  let ret = bcf_get_info_values(i.v.vcf.header.hdr, i.v.c, key.cstring,
     i.v.p.addr, n.addr, BCF_HT_STR.cint)
  if ret < 0:
    if data.len != 0: data.set_len(0)
    result = Status(ret.int)
    return
  data.set_len(ret.int)
  copyMem(data[0].addr.pointer, i.v.p, ret.int)


proc has_flag*(i:INFO, key:string): bool {.inline.} =
  ## return indicates whether the flag is found in the INFO.
  var info = bcf_get_info(i.v.vcf.header.hdr, i.v.c, key.cstring)
  if info == nil or info.len != 0:
    return false
  return true

proc bcf_hdr_id2number(hdr:ptr bcf_hdr_t, htype:int, int_id:int): int {.inline.}=
  # translation of htslib macro.
  var d = cast[CPtr[bcf_idpair_t]](hdr.id[0])
  var v = d[int_id.cint].val.info[htype].int
  return (v shr 12)

proc delete*(i:INFO, key:string): Status {.inline.} =
  ## delete the value from the INFO field
  var info = bcf_get_info(i.v.vcf.header.hdr, i.v.c, key.cstring)
  if info == nil:
    raise newException(KeyError, "hts-nim/info: key not found:" & key)

  var htype = bcf_hdr_id2type(i.v.vcf.header.hdr, BCF_HEADER_TYPE.BCF_HL_INFO.cint, info.key)
  var ret = bcf_update_info(i.v.vcf.header.hdr, i.v.c, key.cstring,nil,0,htype.cint)
  return Status(ret.int)

proc set*(i:INFO, key:string, value:var string): Status {.inline.} =
  var ret = bcf_update_info(i.v.vcf.header.hdr, i.v.c, key.cstring, value.cstring, 1, BCF_HT_STR.cint)
  return Status(ret.int)

proc set*(i:INFO, key:string, value:bool): Status {.inline.} =
  ## set a flag (when value is true) and remove it (when value is false)
  var ret = bcf_update_info(i.v.vcf.header.hdr, i.v.c, key.cstring, nil, value.int.cint, BCF_HT_FLAG.cint)
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

proc close*(v:VCF) =
  if v.fname != "-" and v.fname != "/dev/stdin" and v.hts != nil:
    if hts_close(v.hts) != 0:
        when defined(debug):
            stderr.write_line "[hts-nim] error closing vcf"
    v.hts = nil
  if v.fname in ["/dev/stdout", "-"]:
    flushFile(stdout)

proc copy_header*(v: var VCF, hdr: Header) =
  v.header = Header(hdr:bcf_hdr_dup(hdr.hdr))

proc bcf_hdr_id2name(hdr: ptr bcf_hdr_t, rid: cint): cstring {.inline.} =
  ## for looking up contigs
  var v = cast[CPtr[bcf_idpair_t]](hdr.id[1])
  return v[rid.int].key

let bcf_hdr_id2namep = proc(hdr: pointer, rid: cint): cstring {.cdecl.} =
  ## for looking up contigs
  result = bcf_hdr_id2name(cast[ptr bcf_hdr_t](hdr), rid)

proc write_header*(v: VCF): bool =
  ## write a the header to the file (must have been opened in write mode) and return a bool for success.
  return bcf_hdr_write(v.hts, v.header.hdr) == 0

proc write_variant*(v:VCF, variant:Variant): bool =
  ## write a variant to the VCF opened in write mode and return a bool indicating success.
  if variant.c.errcode == BCF_ERR_CTG_UNDEF:
      # if the input VCF did not have contigs defined, we have to manually add
      # them to the VCF that we are about to write. This happens once per chromosome.
      var chrom = bcf_hdr_id2name(variant.vcf.header.hdr, variant.c.rid)
      doAssert v.header.add_string("##contig=<ID=" & $chrom & '>') == Status.OK
      doAssert bcf_hdr_sync(variant.vcf.header.hdr) == 0
  return bcf_write(v.hts, v.header.hdr, variant.c) == 0

proc info*(v:Variant): INFO {.inline, noInit.} =
  discard bcf_unpack(v.c, BCF_UN_STR or BCF_UN_FLT or BCF_UN_INFO)
  result = INFO(i:0, v:v)

proc bcf_hdr_int2id(hdr: ptr bcf_hdr_t, typ: int, rid:int): cstring {.inline.} =
  var v = cast[CPtr[bcf_idpair_t]](hdr.id[typ])
  return v[rid].key


type FormatField* = object
    ## FormatField represents the name (e.g. AD or DP), the number of values per sample, and the type (BCF_BT_\*) of a FORMAT field.
    name*: string
    n_per_sample*: int
    ## number of entries per sample
    vtype*: BCF_TYPE
    ## variable type is one of the BCF_BT_* types.
    i*: int

iterator fields*(f:FORMAT): FormatField {.inline.} =
  for i in 0..<f.v.c.n_fmt.int:
    var fmt = cast[CPtr[bcf_fmt_t]](f.v.c.d.fmt)[i]
    var t = FormatField()
    t.name = $bcf_hdr_int2id(f.v.vcf.header.hdr, BCF_DT_ID, fmt.id)
    t.vtype = BCF_TYPE(fmt.`type`)
    t.n_per_sample = fmt.n
    t.i = fmt.id
    yield t

type InfoField* = object
    name*: string
    n*: int
    ## number of values. 1048575 means variable-length (Number=A)
    vtype*: BCF_TYPE
    i*: int

iterator fields*(info:INFO): InfoField =
  for i in 0..<info.v.c.n_info.int:
    var fld = cast[CPtr[bcf_info_t]](info.v.c.d.info)[i]
    var typ = BCF_TYPE(fld.`type`)
    var r = InfoField(name: $bcf_hdr_int2id(info.v.vcf.header.hdr, BCF_DT_ID, fld.key),
                      n: bcf_hdr_id2number(info.v.vcf.header.hdr, BCF_HEADER_TYPE.BCF_HL_INFO.cint, fld.key),
                      vtype: typ, i: fld.key)
    yield r

proc CHROM*(v:Variant): cstring {.inline.} =
  ## return the chromosome associated with the variant
  return bcf_hdr_id2name(v.vcf.header.hdr, v.c.rid)

proc rid*(v:Variant): int32 {.inline.} =
  ## return the reference id of the variant.
  return v.c.rid

proc tostring*(v:Variant): string =
  ## return the full variant string including new-line from vcf_format.
  var s = kstring_t(s:nil, l:0, m:0)
  if vcf_format(v.vcf.header.hdr, v.c, s.addr) != 0:
    raise newException(ValueError, "hts-nim/format error for variant")
  result = $s.s
  free(s.s)

iterator items*(v:VCF): Variant =
  ## Each returned Variant has a pointer in the underlying iterator
  ## that is updated each iteration; use .copy to keep it in memory

  # all iterables share the same variant
  var variant: Variant
  new(variant, destroy_variant)

  while true:
    if bcf_read(v.hts, v.header.hdr, v.c) == -1:
      break
    discard bcf_unpack(v.c, 1 or 2)
    variant.vcf = v
    variant.c = v.c
    yield variant
  # allow an error code of 1 (CTG_UNDEF) because we can have a contig
  # undefined in the reader in the absence of an index or a full header
  # but that's not an error in this library.
  if v.c.errcode > 1:
    stderr.write_line "hts-nim/vcf bcf_read error:" & $v.c.errcode
    stderr.write_line "last read variant:", variant.tostring()
    raise newException(IOError, "Error reading variant")


type Contig* = object
  ## Contig is a chromosome+length from the VCF header
  ## if the length is not found, it is set to -1
  name*: string
  length*: int64

proc `$`*(c:Contig): string =
  return &"Contig(name:\"{c.name}\", length:{c.length}'i64)"

proc load_index*(v: VCF, path: string, force:bool=false) =
  ## load the index at the given path (remote or local).
  if not force and (v.bidx != nil or v.tidx != nil):
    return
  v.bidx = hts_idx_load2(v.fname, path)
  if v.bidx == nil:
    v.tidx = tbx_index_load2(v.fname, path)
  if v.bidx == nil and v.tidx == nil:
    raise newException(OSError, "unable to load index at:" & path)

template get_info(p:ptr bcf_idpair_t, i:int32, j:int): int64 =
  var d = cast[CPtr[bcf_idpair_t]](p)
  if(d[i].val == nil):
    -1'i64
  else:
    d[i].val.info[j].int64

proc contigs*(v:VCF): seq[Contig] =
  var n:cint
  let h:ptr bcf_hdr_t = v.header.hdr
  var cnames = bcf_hdr_seqnames(h, n.addr)

  if n > 0:
    result.setLen(n.int)
    for i in 0..<h.n[BCF_DT_CTG]:
      result[i].name = $cnames[i]
      result[i].length = get_info(h.id[BCF_DT_CTG], i.int32, 0) #.val.info[0]
  else:
    try:
       v.load_index("")
    except OSError:
      raise newException(OSError, "hts-nim/vcf: unable to find contigs in header or index")
    if v.bidx != nil:
      var f:hts_id2name_f = bcf_hdr_id2namep
      cnames = hts_idx_seqnames(v.bidx, n.addr, f, v.header.hdr)
    else:
      cnames = tbx_seqnames(v.tidx, n.addr)
    if n > 0:
      result.setLen(n.int)
      for i in 0..<n:
        result[i].name = $cnames[i]
        result[i].length = -1
  free(cnames)


iterator vquery(v:VCF, region:string): Variant =
  ## internal iterator for VCF regions called from query()
  if v.tidx == nil:
    v.tidx = tbx_index_load(v.fname)
  if v.tidx == nil:
    stderr.write_line("hts-nim/vcf no index found for " & v.fname)
    raise newException(IOError, "No Index found for " & v.fname)

  var
    read_func:ptr hts_readrec_func = cast[ptr hts_readrec_func](tbx_readrec)
    ret = 0
    slen = 0
    s = kstring_t()
    start: int64
    stop: int64
    tid:cint = 0

  discard hts_parse_reg(region.cstring, start.addr, stop.addr)
  var cidx = region.find(':')
  if cidx == -1:
    tid = tbx_name2id(v.tidx, region)
  else:
    tid = tbx_name2id(v.tidx,region[0..<cidx])

  var itr = hts_itr_query(v.tidx.idx, tid.cint, start.int64, stop.int64, read_func)
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
    discard bcf_unpack(v.c, 1 or 2)
    variant.vcf = v
    yield variant

  hts_itr_destroy(itr)
  free(s.s)


iterator query*(v:VCF, region: string): Variant =
  if region in ["-3", "*"]:
    for variant in v:
      yield variant
  else:

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
        raise newException(IOError, "No Index found for " & v.fname)
      var
        start: int64
        stop: int64
        tid:cint = 0
        read_fn:ptr hts_readrec_func = cast[ptr hts_readrec_func](bcf_readrec)

      discard hts_parse_reg(region.cstring, start.addr, stop.addr)
      tid = bcf_hdr_name2id(v.header.hdr, region.split({':'}, maxsplit=1)[0].cstring)
      var itr = hts_itr_query(v.bidx, tid, start, stop, read_fn)
      var ret = 0
      var variant: Variant
      new(variant, destroy_variant)
      while true:
          #ret = bcf_itr_next(v.hts, itr, v.c)
          ret = hts_itr_next(v.hts.fp.bgzf, itr, v.c, nil)
          if ret < 0: break
          discard bcf_unpack(v.c, 1 or 2)
          if bcf_subset_format(v.header.hdr, v.c) != 0:
              stderr.write_line "[hts-nim/vcf] error with bcf subset format"
              break
          variant.c = v.c
          variant.vcf = v
          yield variant

      hts_itr_destroy(itr)
      if ret > 0:
        stderr.write_line "hts-nim/vcf: error parsing "
        raise newException(IOError, "error parsing vcf")

    if v.c.errcode != 0:
      stderr.write_line "hts-nim/vcf bcf_read error:" & $v.c.errcode

proc copy*(v:Variant): Variant =
  ## make a copy of the variant and the underlying pointer.
  var v2: Variant
  new(v2, destroy_variant)
  v2.c = bcf_dup(v.c)
  discard bcf_unpack(v2.c, 1 or 2)
  v2.vcf = v.vcf
  v2.own = true
  v2.p = nil
  return v2

proc POS*(v:Variant): int64 {.inline.} =
  ## return the 1-based position of the start of the variant
  return v.c.pos + 1

proc start*(v:Variant): int64 {.inline.} =
  ## return the 0-based position of the start of the variant
  return v.c.pos

proc stop*(v:Variant): int64 {.inline.} =
  ## return the 0-based position of the end of the variant
  return v.c.pos + v.c.rlen

proc ID*(v:Variant): cstring {.inline.} =
  ## the VCF ID field
  return v.c.d.id

proc `ID=`*(v:Variant, value: string) {.inline.} =
  ## Set the ID value, third column in the VCF spec.
  doAssert(bcf_update_id(v.vcf.header.hdr, v.c, value) == 0,
    &"[hts-nim/vcf] error setting variant id to: {value}")

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
  for i in 1..(v.c.n_allele.int - 1):
    result[i-1] = $(v.c.d.allele[i])

proc `REF=`*(v:Variant, allele:string) {.inline.} =
  ## the reference allele
  assert v.c != nil
  var a = @[allele]
  a.add(v.ALT)
  let als = allocCStringArray(a)
  doAssert 0 == bcf_update_alleles(v.vcf.header.hdr, v.c, als, a.len.cint)
  deallocCStringArray(als)

proc `ALT=`*(v:Variant, alleles:string|seq[string]) {.inline.} =
  ## the reference allele
  assert v.c != nil
  var a = @[v.REF]
  a.add(alleles)
  let als = allocCStringArray(a)
  doAssert 0 == bcf_update_alleles(v.vcf.header.hdr, v.c, als, a.len.cint)
  deallocCStringArray(als)

type
  Genotypes* {.shallow.} = object
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
  var gts = newSeqUninitialized[int32](g.gts.len)
  var src = g.gts[0]
  copyMem(gts[0].addr.pointer, src.addr.pointer, gts.len * sizeof(int32))
  return Genotypes(gts:gts, ploidy:g.ploidy)

proc phased*(a:Allele): bool {.inline.} =
  ## is the allele phased.
  return (cast[int32](a) and 1) == 1

proc value*(a:Allele): int {.inline.} =
  ## e.g. 0 for REF, 1 for first alt, -1 for unknown.
  if unlikely(cast[int32](a) < 0):
    return int(a)
  return (cast[int32](a) shr 1) - 1

proc `[]`*(g:Genotypes, i:int): Genotype {.inline.} =
  result = cast[seq[Allele]](g.gts[i*g.ploidy..<(i+1)*g.ploidy])

proc len*(g:Genotypes): int {.inline.} =
  ## this should match the number of samples.
  if g.ploidy == 0: return 0
  return int(len(g.gts) / g.ploidy)

iterator items*(g:Genotypes): Genotype =
  for k in 0..<g.len:
    yield g[k]

proc `$`*(a:Allele): string {.inline.} =
  ## string representation of a single allele.
  if a.value < 0:
    # set end to / so it is removed in '$'
    result = if int32(a) == 0: "./" else: "$"
  else:
    result = intToStr(a.value) & (if a.phased: '|' else: '/')

proc `$`*(g:Genotype): string {.inline.} =
  ## string representation of a genotype. removes trailing phase value.
  result = join(map(g, proc(a:Allele): string = $a), "")
  if result.len == 0:
      return "."
  if result[result.len - 1] in {'/', '|', '$'}:
    result.set_len(result.len - 1)

proc alts*(g:Genotype): int8 {.inline.} =
  ## the number of alternate alleles in the genotype. only makes sense for bi-allelics.
  ## ./1 == 1
  ## 0/. == 0
  ## ./. -> -1
  ## 1/1 -> 2
  if likely(g.len == 2):
    let g0 = g[0].value
    let g1 = g[1].value
    if likely(g0 >= 0 and g1 >= 0):
      return int8(g0 + g1)
    # only unknown if both are unknown
    if (g0 == -1 and g1 == -1) or g1 < -1:
      return -1

    if g0 <= -1:
      return int8(g1)
    if g1 <= -1:
      return int8(g0)

  if g.len == 1 and g[0].value <= -1:
    return -1

  # ploidy > 2. return sum of alleles as long as there's at least 1 known
  # genotype
  var n_found = 0
  for i in 0..<g.len:
    if g[i].value >= 0:
      result += g[i].value.int8
      n_found.inc

  if n_found == 0:
    result = -1'i8

  #raise newException(OSError, "not implemented for:" & $g & " should be:" & $result)

proc genotypes*(f:FORMAT, gts: var seq[int32]): Genotypes {.inline.} =
  ## give sequence of genotypes (using the underlying array given in gts)
  if f.get("GT", gts) != Status.OK:
    return
  result = Genotypes(gts: gts, ploidy: int(gts.len/f.v.n_samples))

proc `$`*(gs:Genotypes): string =
  var x = new_seq_of_cap[string](gs.len)
  for g in gs:
    x.add($g)
  return '[' & join(x, ", ") & ']'


proc alts*(gs:Genotypes): seq[int8] {.inline.} =
  ## return the number of alternate alleles. Unknown is -1.
  result = newSeqUninitialized[int8](gs.len)
  var i = 0
  for g in gs:
    result[i] = g.alts
    i += 1

proc `$`*(v:Variant): string =
  return format("Variant($#:$# $#/$#)" % [$v.CHROM, $v.POS, $v.REF, join(v.ALT, ",")])


proc bcfBuildIndex*(fnameIn, fnameOut: string; csi: bool = true, threads: int = 1) = 
  ##  Uses bcf_index_build3() - Generate and save an index to a specific file
  ##  fnameIn: Input VCF/BCF filename
  ##  fnameOut: Output filename
  ##  csi: `true` to generate CSI, or `false` to generate TBI, Note: bcf can't make csi index
  ##  threads: Number of VCF/BCF decoder threads
  let errorCode = bcf_index_build3(fnameIn.cstring, fnameOut.cstring, cast[int](csi).cint, threads.cint).int
  let errorMsg = case errorCode:
  of -1: "indexing failed"
  of -2: "opening @fn failed"
  of -3: "format not indexable"
  of -4: "failed to create and/or save the index"
  else: ""
  if errorMsg != "":
    raise newException(ValueError, errorMsg)

when isMainModule:

  var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]

  for k in 0..2000:
    var v:VCF
    if k mod 200 == 0:
      stderr.write_line $k
    if not open(v, "tests/test.vcf.gz", samples=tsamples):
        quit "couldn't open file"
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
      if rec.info.get("AC", ac) != Status.OK:
          quit "couldn't get AC"
      if rec.info.get("AF", af) != Status.OK:
          quit "couldn't get CSQ"
      if rec.info.get("CSQ", csq) != Status.OK:
          quit "couldn't get AF"
      echo rec, " qual:", rec.QUAL, " filter:", rec.FILTER, "  AC (int):",  ac, " AF(float):", af, " CSQ:", csq
      if rec.info.has_flag("in_exac_flag"):
        echo "FOUND"
      var f = rec.format()
      if f.get("DP", dps) != Status.OK:
          quit "couldn't get DP"
      if f.get("AD", ads) != Status.OK:
          quit "couldn't get DP"
      echo dps, " ads:", ads
      if f.get("BAD", bad) != Status.UndefinedTag:
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
      discard info.get("AC", ac)
