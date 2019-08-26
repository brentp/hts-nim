 {.deadCodeElim: on.}
when defined(windows):
  const
    libname* = "libhts.dll"
elif defined(macosx):
  const
    libname* = "libhts.dylib"
else:
  const
    libname* = "libhts.so"
##
## enum hts_fmt_option {
##     // CRAM specific
##     CRAM_OPT_DECODE_MD,
##     CRAM_OPT_PREFIX,
##     CRAM_OPT_VERBOSITY,  // obsolete, use hts_set_log_level() instead
##     CRAM_OPT_SEQS_PER_SLICE,
##     CRAM_OPT_SLICES_PER_CONTAINER,
##     CRAM_OPT_RANGE,
##     CRAM_OPT_VERSION,    // rename to cram_version?
##     CRAM_OPT_EMBED_REF,
##     CRAM_OPT_IGNORE_MD5,
##     CRAM_OPT_REFERENCE,  // make general
##     CRAM_OPT_MULTI_SEQ_PER_SLICE,
##     CRAM_OPT_NO_REF,
##     CRAM_OPT_USE_BZIP2,
##     CRAM_OPT_SHARED_REF,
##     CRAM_OPT_NTHREADS,   // deprecated, use HTS_OPT_NTHREADS
##     CRAM_OPT_THREAD_POOL,// make general
##     CRAM_OPT_USE_LZMA,
##     CRAM_OPT_USE_RANS,
##     CRAM_OPT_REQUIRED_FIELDS,
##     CRAM_OPT_LOSSY_NAMES,
##     CRAM_OPT_BASES_PER_SLICE,
##
##     // General purpose
##     HTS_OPT_COMPRESSION_LEVEL = 100,
##     HTS_OPT_NTHREADS,
##     HTS_OPT_THREAD_POOL,
##     HTS_OPT_CACHE_SIZE,
##     HTS_OPT_BLOCK_SIZE,
## };
##

const
  BAM_FPAIRED* = 1

## ! @abstract the read is mapped in a proper pair

const
  BAM_FPROPER_PAIR* = 2

## ! @abstract the read itself is unmapped; conflictive with BAM_FPROPER_PAIR

const
  BAM_FUNMAP* = 4

## ! @abstract the mate is unmapped

const
  BAM_FMUNMAP* = 8

## ! @abstract the read is mapped to the reverse strand

const
  BAM_FREVERSE* = 16

## ! @abstract the mate is mapped to the reverse strand

const
  BAM_FMREVERSE* = 32

## ! @abstract this is read1

const
  BAM_FREAD1* = 64

## ! @abstract this is read2

const
  BAM_FREAD2* = 128

## ! @abstract not primary alignment

const
  BAM_FSECONDARY* = 256

## ! @abstract QC failure

const
  BAM_FQCFAIL* = 512

## ! @abstract optical or PCR duplicate

const
  BAM_FDUP* = 1024

## ! @abstract supplementary alignment

const
  BAM_FSUPPLEMENTARY* = 2048
  HTS_FMT_CSI* = 0
  HTS_FMT_BAI* = 1
  HTS_FMT_TBI* = 2
  HTS_FMT_CRAI* = 3
  BCF_HT_FLAG* = 0
  BCF_HT_INT* = 1
  BCF_HT_REAL* = 2
  BCF_HT_STR* = 3
  HTS_IDX_NOCOOR* = (-2)
  HTS_IDX_START* = (-3)
  HTS_IDX_REST* = (-4)
  HTS_IDX_NONE* = (-5)

proc malloc*(size: csize): pointer {.cdecl, importc: "malloc", dynlib: libname.}
proc free*(a1: pointer) {.cdecl, importc: "free", dynlib: libname.}
proc strncpy*(dst: cstring; src: cstring; size: csize): cstring {.cdecl,
    importc: "strncpy", dynlib: libname.}
proc strtol*(str: cstring; endptr: cstringArray; base: cint): clong {.cdecl,
    importc: "strtol", dynlib: libname.}
const
  BCF_DT_ID* = 0
  BCF_DT_CTG* = 1
  BCF_DT_SAMPLE* = 2

type
  hFILE* {.bycopy.} = object


## ############################
## # kstring
## ############################

type
  kstring_t* {.bycopy.} = object
    l*: csize
    m*: csize
    s*: cstring


proc ks_release*(s: ptr kstring_t): cstring {.inline, cdecl, importc: "ks_release",
    dynlib: libname.}
proc kputsn*(a1: cstring; a2: cint; a3: ptr kstring_t) {.cdecl, importc: "kputsn",
    dynlib: libname.}
## ##########################
## # BGZF
## ##########################

type
  bgzidx_t* {.bycopy.} = object

  bgzf_mtaux_t* {.bycopy.} = object

  z_stream* {.bycopy.} = object

  BGZF* {.bycopy.} = object
    errcode* {.bitsize: 16.}: cuint ##  Reserved bits should be written as 0; read as "don't care"
    reserved* {.bitsize: 1.}: cuint
    is_write* {.bitsize: 1.}: cuint
    no_eof_block* {.bitsize: 1.}: cuint
    is_be* {.bitsize: 1.}: cuint
    compress_level* {.bitsize: 9.}: cint
    last_block_eof* {.bitsize: 1.}: cuint
    is_compressed* {.bitsize: 1.}: cuint
    is_gzip* {.bitsize: 1.}: cuint
    cache_size*: cint
    block_length*: cint
    block_clength*: cint
    block_offset*: cint
    block_address*: int64
    uncompressed_address*: int64
    uncompressed_block*: pointer
    compressed_block*: pointer
    cache*: pointer            ##  a pointer to a hash table
    fp*: ptr hFILE              ##  actual file handle
    mt*: ptr bgzf_mtaux_t       ##  only used for multi-threading
    idx*: ptr bgzidx_t          ##  BGZF index
    idx_build_otf*: cint       ##  build index on the fly, set by bgzf_index_build_init()
    gz_stream*: ptr z_stream    ##  for gzip-compressed files


proc bgzf_open*(path: cstring; mode: cstring): ptr BGZF {.cdecl, importc: "bgzf_open",
    dynlib: libname.}
proc bgzf_close*(fp: ptr BGZF): cint {.cdecl, importc: "bgzf_close", dynlib: libname.}
proc bgzf_hopen*(fp: ptr hFILE; mode: cstring): ptr BGZF {.cdecl, importc: "bgzf_hopen",
    dynlib: libname.}
proc bgzf_flush*(fp: ptr BGZF): cint {.cdecl, importc: "bgzf_flush", dynlib: libname.}
## *
##  Write _length_ bytes from _data_ to the file.  If no I/O errors occur,
##  the complete _length_ bytes will be written (or queued for writing).
##
##  @param fp     BGZF file handler
##  @param data   data array to write
##  @param length size of data to write
##  @return       number of bytes written (i.e., _length_); negative on error
##

proc bgzf_write*(fp: ptr BGZF; data: pointer; length: csize): int64 {.cdecl,
    importc: "bgzf_write", dynlib: libname.}
template bgzf_tell*(fp: untyped): untyped =
  (((fp).block_address shl 16) or ((fp).block_offset and 0x0000FFFF))

proc bgzf_getline*(fp: ptr BGZF; delim: cint; str: ptr kstring_t): cint {.cdecl,
    importc: "bgzf_getline", dynlib: libname.}
proc bgzf_mt*(fp: ptr BGZF; n_threads: cint; n_sub_blks: cint): cint {.cdecl,
    importc: "bgzf_mt", dynlib: libname.}
type
  htsFormatCategory* {.size: sizeof(cint).} = enum
    unknown_category, sequence_data, ##  Sequence data -- SAM, BAM, CRAM, etc
    variant_data,             ##  Variant calling data -- VCF, BCF, etc
    index_file,               ##  Index file associated with some data file
    region_list,              ##  Coordinate intervals or regions -- BED, etc
    category_maximum = 32767


type
  htsExactFormat* {.size: sizeof(cint).} = enum
    unknown_format, binary_format, text_format, sam, bam, bai, cram, crai, vcf, bcf, csi,
    gzi, tbi, bed, json, format_maximum = 32767


type
  htsCompression* {.size: sizeof(cint).} = enum
    no_compression, gzip, bgzf, custom, compression_maximum = 32767


type
  INNER_C_STRUCT_hts_concat_193* {.bycopy.} = object
    major*: cshort
    minor*: cshort

  htsFormat* {.bycopy.} = object
    category*: htsFormatCategory
    format*: htsExactFormat
    version*: INNER_C_STRUCT_hts_concat_193
    compression*: htsCompression
    compression_level*: cshort ##  currently unused
    specific*: pointer         ##  format specific options; see struct hts_opt.


## ###########################
## # hts
## ###########################

type
  INNER_C_UNION_hts_concat_212* {.bycopy, union.} = object
    bgzf*: ptr BGZF
    cram*: ptr cram_fd
    hfile*: ptr hFILE

  cram_fd* {.bycopy.} = object

  hts_idx_t* {.bycopy.} = object

  htsFile* {.bycopy.} = object
    is_bin* {.bitsize: 1.}: uint32
    is_write* {.bitsize: 1.}: uint32
    is_be* {.bitsize: 1.}: uint32
    is_cram* {.bitsize: 1.}: uint32
    is_bgzf* {.bitsize: 1.}: uint32
    dummy* {.bitsize: 27.}: uint32
    lineno*: int64
    line*: kstring_t
    fn*: cstring
    fn_aux*: cstring
    fp*: INNER_C_UNION_hts_concat_212
    format*: htsFormat


proc hts_open*(fn: cstring; mode: cstring): ptr htsFile {.cdecl, importc: "hts_open",
    dynlib: libname.}
proc hts_close*(fp: ptr htsFile): cint {.cdecl, importc: "hts_close", dynlib: libname.}
proc hts_check_EOF*(fp: ptr htsFile): cint {.cdecl, importc: "hts_check_EOF",
                                        dynlib: libname.}
proc hts_getline*(fp: ptr htsFile; delimiter: cint; str: ptr kstring_t): cint {.cdecl,
    importc: "hts_getline", dynlib: libname.}
proc hts_set_threads*(fp: ptr htsFile; n: cint): cint {.cdecl,
    importc: "hts_set_threads", dynlib: libname.}
proc hts_set_fai_filename*(fp: ptr htsFile; fn_aux: cstring): cint {.cdecl,
    importc: "hts_set_fai_filename", dynlib: libname.}
type
  hts_readrec_func* = proc (fp: ptr BGZF; data: pointer; r: pointer; tid: ptr cint;
                         beg: ptr cint; `end`: ptr cint): cint {.cdecl.}
  hts_id2name_f* = proc (a1: pointer; a2: cint): cstring {.cdecl.}
  hts_itr_t* {.bycopy.} = object


proc hts_idx_init*(n: cint; fmt: cint; offset0: uint64; min_shift: cint; n_lvls: cint): ptr hts_idx_t {.
    cdecl, importc: "hts_idx_init", dynlib: libname.}
proc hts_idx_destroy*(idx: ptr hts_idx_t) {.cdecl, importc: "hts_idx_destroy",
                                        dynlib: libname.}
proc hts_idx_push*(idx: ptr hts_idx_t; tid: cint; beg: cint; `end`: cint; offset: uint64;
                  is_mapped: cint): cint {.cdecl, importc: "hts_idx_push",
                                        dynlib: libname.}
proc hts_idx_finish*(idx: ptr hts_idx_t; final_offset: uint64) {.cdecl,
    importc: "hts_idx_finish", dynlib: libname.}
proc hts_idx_save*(idx: ptr hts_idx_t; fn: cstring; fmt: cint) {.cdecl,
    importc: "hts_idx_save", dynlib: libname.}
proc hts_idx_load*(fn: cstring; fmt: cint): ptr hts_idx_t {.cdecl,
    importc: "hts_idx_load", dynlib: libname.}
proc hts_idx_load2*(fn: cstring; fnidx: cstring): ptr hts_idx_t {.cdecl,
    importc: "hts_idx_load2", dynlib: libname.}
proc hts_idx_get_meta*(idx: ptr hts_idx_t; l_meta: ptr cint): ptr uint8 {.cdecl,
    importc: "hts_idx_get_meta", dynlib: libname.}
proc hts_idx_set_meta*(idx: ptr hts_idx_t; l_meta: uint32; meta: ptr uint8; is_copy: cint): cint {.
    cdecl, importc: "hts_idx_set_meta", dynlib: libname.}
proc hts_idx_get_stat*(idx: ptr hts_idx_t; tid: cint; mapped: ptr uint64;
                      unmapped: ptr uint64): cint {.cdecl,
    importc: "hts_idx_get_stat", dynlib: libname.}
proc hts_idx_get_n_no_coor*(idx: ptr hts_idx_t): uint64 {.cdecl,
    importc: "hts_idx_get_n_no_coor", dynlib: libname.}
proc hts_parse_reg*(s: cstring; beg: ptr cint; `end`: ptr cint): cstring {.cdecl,
    importc: "hts_parse_reg", dynlib: libname.}
proc hts_itr_query*(idx: ptr hts_idx_t; tid: cint; beg: cint; stop: cint;
                   readrec: hts_readrec_func): ptr hts_itr_t {.cdecl,
    importc: "hts_itr_query", dynlib: libname.}
proc hts_itr_destroy*(iter: ptr hts_itr_t) {.cdecl, importc: "hts_itr_destroy",
    dynlib: libname.}
proc hts_itr_next*(fp: ptr BGZF; iter: ptr hts_itr_t; r: pointer; data: pointer): cint {.
    cdecl, importc: "hts_itr_next", dynlib: libname.}
proc hts_idx_seqnames*(idx: ptr hts_idx_t; n: ptr cint; getid: hts_id2name_f;
                      hdr: pointer): cstringArray {.cdecl,
    importc: "hts_idx_seqnames", dynlib: libname.}
type
  hts_itr_query_func* = proc (idx: ptr hts_idx_t; tid: cint; beg: cint; `end`: cint;
                           readrec: ptr hts_readrec_func): ptr hts_itr_t {.cdecl.}
  hts_name2id_f* = proc (a1: pointer; a2: cstring): cint {.cdecl.}

proc hts_itr_querys*(idx: ptr hts_idx_t; reg: cstring; getid: hts_name2id_f;
                    hdr: pointer; itr_query: ptr hts_itr_query_func;
                    readrec: ptr hts_readrec_func): ptr hts_itr_t {.cdecl,
    importc: "hts_itr_querys", dynlib: libname.}
## ###########################
## # tbx
## ###########################

type
  tbx_conf_t* {.bycopy.} = object
    preset*: int32
    sc*: int32
    bc*: int32
    ec*: int32                 ##  seq col., beg col. and end col.
    meta_char*: int32
    line_skip*: int32

  tbx_t* {.bycopy.} = object
    conf*: tbx_conf_t
    idx*: ptr hts_idx_t
    dict*: pointer


proc tbx_name2id*(tbx: ptr tbx_t; ss: cstring): cint {.cdecl, importc: "tbx_name2id",
    dynlib: libname.}
proc tbx_index_build*(fn: cstring; min_shift: cint; conf: ptr tbx_conf_t): cint {.cdecl,
    importc: "tbx_index_build", dynlib: libname.}
proc tbx_index_load*(fn: cstring): ptr tbx_t {.cdecl, importc: "tbx_index_load",
    dynlib: libname.}
proc tbx_index_load2*(fn: cstring; fnidx: cstring): ptr tbx_t {.cdecl,
    importc: "tbx_index_load2", dynlib: libname.}
template tbx_itr_querys*(tbx, s: untyped): untyped =
  hts_itr_querys((tbx).idx, (s), (hts_name2id_f)(tbx_name2id), (tbx), hts_itr_query,
                 tbx_readrec)

proc tbx_seqnames*(tbx: ptr tbx_t; n: ptr cint): cstringArray {.cdecl,
    importc: "tbx_seqnames", dynlib: libname.}
##  free the array but not the values

proc tbx_destroy*(tbx: ptr tbx_t) {.cdecl, importc: "tbx_destroy", dynlib: libname.}
proc tbx_readrec*(fp: ptr BGZF; tbxv: pointer; sv: pointer; tid: ptr cint; beg: ptr cint;
                 `end`: ptr cint): cint {.cdecl, importc: "tbx_readrec",
                                      dynlib: libname.}
template tbx_itr_queryx*(idx, tid, beg, `end`: untyped): untyped =
  hts_itr_query(idx, (tid), (beg), (stop), tbx_readrec)

template tbx_itr_queryi*(tbx, tid, beg, `end`: untyped): untyped =
  hts_itr_query((tbx).idx, (tid), (beg), (stop), tbx_readrec)

## #####################################
## # sam.h
## #####################################

type
  samFile* = htsFile
  bam_hdr_t* {.bycopy.} = object
    n_targets*: int32
    ignore_sam_err*: int32
    l_text*: uint32
    target_len*: ptr uint32
    cigar_tab*: ptr int8
    target_name*: cstringArray
    text*: cstring
    sdict*: pointer

  bam1_core_t* {.bycopy.} = object
    tid*: int32
    pos*: int32
    bin*: uint16
    qual*: uint8
    l_qname*: uint8
    flag*: uint16
    unused1*: uint8
    l_extranul*: uint8
    n_cigar*: uint32
    l_qseq*: int32
    mtid*: int32
    mpos*: int32
    isize*: int32

  bam1_t* {.bycopy.} = object
    core*: bam1_core_t
    l_data*: cint
    m_data*: cint
    data*: ptr uint8
    id*: uint64


proc sam_hdr_parse*(l_text: cint; text: cstring): ptr bam_hdr_t {.cdecl,
    importc: "sam_hdr_parse", dynlib: libname.}
proc sam_hdr_read*(fp: ptr samFile): ptr bam_hdr_t {.cdecl, importc: "sam_hdr_read",
    dynlib: libname.}
proc bam_name2id*(h: ptr bam_hdr_t; `ref`: cstring): cint {.cdecl,
    importc: "bam_name2id", dynlib: libname.}
proc bam_hdr_dup*(h0: ptr bam_hdr_t): ptr bam_hdr_t {.cdecl, importc: "bam_hdr_dup",
    dynlib: libname.}
proc bam_hdr_write*(fp: ptr BGZF; h: ptr bam_hdr_t): cint {.cdecl,
    importc: "bam_hdr_write", dynlib: libname.}
proc sam_hdr_write*(fp: ptr htsFile; h: ptr bam_hdr_t): cint {.cdecl,
    importc: "sam_hdr_write", dynlib: libname.}
proc sam_write1*(fp: ptr htsFile; h: ptr bam_hdr_t; b: ptr bam1_t): cint {.cdecl,
    importc: "sam_write1", dynlib: libname.}
proc bam_hdr_destroy*(h: ptr bam_hdr_t) {.cdecl, importc: "bam_hdr_destroy",
                                      dynlib: libname.}
## static inline void bam_hdr_destroy(sam_hdr_t *h) { sam_hdr_destroy(h); }

proc sam_format1*(h: ptr bam_hdr_t; b: ptr bam1_t; str: ptr kstring_t): cint {.cdecl,
    importc: "sam_format1", dynlib: libname.}
proc sam_read1*(fp: ptr samFile; h: ptr bam_hdr_t; b: ptr bam1_t): cint {.cdecl,
    importc: "sam_read1", dynlib: libname.}
proc bam_read1*(fp: ptr BGZF; b: ptr bam1_t): cint {.cdecl, importc: "bam_read1",
    dynlib: libname.}
proc bam_init1*(): ptr bam1_t {.cdecl, importc: "bam_init1", dynlib: libname.}
proc bam_destroy1*(b: ptr bam1_t) {.cdecl, importc: "bam_destroy1", dynlib: libname.}
template bam_is_mrev*(b: untyped): untyped =
  (((b).core.flag and BAM_FMREVERSE) != 0)

template bam_get_qname*(b: untyped): untyped =
  (cast[cstring]((b).data))

proc bam_get_aux*(b: ptr bam1_t): ptr uint8 {.cdecl, importc: "bam_get_aux",
                                        dynlib: libname.}
proc bam_get_l_aux*(b: ptr bam1_t): cint {.cdecl, importc: "bam_get_l_aux",
                                      dynlib: libname.}
proc bam_aux_get*(b: ptr bam1_t; tag: array[2, char]): ptr uint8 {.cdecl,
    importc: "bam_aux_get", dynlib: libname.}
proc bam_aux2i*(s: ptr uint8): int64 {.cdecl, importc: "bam_aux2i", dynlib: libname.}
proc bam_aux2f*(s: ptr uint8): cdouble {.cdecl, importc: "bam_aux2f", dynlib: libname.}
proc bam_aux2Z*(s: ptr uint8): cstring {.cdecl, importc: "bam_aux2Z", dynlib: libname.}
proc bam_aux2A*(s: ptr uint8): char {.cdecl, importc: "bam_aux2A", dynlib: libname.}
proc bam_aux_del*(b: ptr bam1_t; s: ptr uint8): cint {.cdecl, importc: "bam_aux_del",
    dynlib: libname.}
proc bam_aux_update_str*(b: ptr bam1_t; tag: array[2, char]; len: cint; data: cstring): cint {.
    cdecl, importc: "bam_aux_update_str", dynlib: libname.}
proc bam_aux_update_int*(b: ptr bam1_t; tag: array[2, char]; val: int64): cint {.cdecl,
    importc: "bam_aux_update_int", dynlib: libname.}
proc bam_aux_update_float*(b: ptr bam1_t; tag: array[2, char]; val: cfloat): cint {.cdecl,
    importc: "bam_aux_update_float", dynlib: libname.}
proc bam_copy1*(bdst: ptr bam1_t; bsrc: ptr bam1_t): ptr bam1_t {.cdecl,
    importc: "bam_copy1", dynlib: libname.}
proc bam_dup1*(bsrc: ptr bam1_t): ptr bam1_t {.cdecl, importc: "bam_dup1",
    dynlib: libname.}
proc bam_cigar2qlen*(n_cigar: cint; cigar: ptr uint32): cint {.cdecl,
    importc: "bam_cigar2qlen", dynlib: libname.}
proc bam_cigar2rlen*(n_cigar: cint; cigar: ptr uint32): cint {.cdecl,
    importc: "bam_cigar2rlen", dynlib: libname.}
proc bam_endpos*(b: ptr bam1_t): int32 {.cdecl, importc: "bam_endpos", dynlib: libname.}
proc bam_str2flag*(str: cstring): cint {.cdecl, importc: "bam_str2flag",
                                     dynlib: libname.}
## * returns negative value on error

proc bam_flag2str*(flag: cint): cstring {.cdecl, importc: "bam_flag2str",
                                      dynlib: libname.}
## * The string must be freed by the user

proc sam_parse1*(s: ptr kstring_t; h: ptr bam_hdr_t; b: ptr bam1_t): cint {.cdecl,
    importc: "sam_parse1", dynlib: libname.}
proc sam_index_load*(`in`: ptr samFile; a2: cstring): ptr hts_idx_t {.cdecl,
    importc: "sam_index_load", dynlib: libname.}
##  load index

proc sam_index_load2*(fp: ptr htsFile; fn: cstring; fnidx: cstring): ptr hts_idx_t {.
    cdecl, importc: "sam_index_load2", dynlib: libname.}
proc bam_index_build*(fn: cstring; min_shift: cint): cint {.cdecl,
    importc: "bam_index_build", dynlib: libname.}
proc sam_itr_querys*(a1: ptr hts_idx_t; h: ptr bam_hdr_t; region: cstring): ptr hts_itr_t {.
    cdecl, importc: "sam_itr_querys", dynlib: libname.}
proc sam_itr_queryi*(idx: ptr hts_idx_t; tid: cint; beg: cint; `end`: cint): ptr hts_itr_t {.
    cdecl, importc: "sam_itr_queryi", dynlib: libname.}
proc hts_detect_format*(fp: ptr hFILE; fmt: ptr htsFormat): cint {.cdecl,
    importc: "hts_detect_format", dynlib: libname.}
proc hts_format_description*(format: ptr htsFormat): cstring {.cdecl,
    importc: "hts_format_description", dynlib: libname.}
template sam_itr_next*(htsfp, itr, r: untyped): untyped =
  hts_itr_next((htsfp).fp.bgzf, (itr), (r), (htsfp))

const
  BAM_CMATCH* = 0
  BAM_CINS* = 1
  BAM_CDEL* = 2
  BAM_CREF_SKIP* = 3
  BAM_CSOFT_CLIP* = 4
  BAM_CHARD_CLIP* = 5
  BAM_CPAD* = 6
  BAM_CEQUAL* = 7
  BAM_CDIFF* = 8
  BAM_CBACK* = 9
  BAM_CIGAR_STR* = "MIDNSHP=XB"
  BAM_CIGAR_SHIFT* = 4
  BAM_CIGAR_MASK* = 0x0000000F
  BAM_CIGAR_TYPE* = 0x0003C1A7

template bam_cigar_op*(c: untyped): untyped =
  ((c) and BAM_CIGAR_MASK)

template bam_cigar_oplen*(c: untyped): untyped =
  ((c) shr BAM_CIGAR_SHIFT)

##  Note that BAM_CIGAR_STR is padded to length 16 bytes below so that
##  the array look-up will not fall off the end.  '?' is chosen as the
##  padding character so it's easy to spot if one is emitted, and will
##  result in a parsing failure (in sam_parse1(), at least) if read.

template bam_cigar_opchr*(c: untyped): untyped =
  ("MIDNSHP=XB??????"[bam_cigar_op(c)])

template bam_cigar_gen*(l, o: untyped): untyped =
  ((l) shl BAM_CIGAR_SHIFT or (o))

type
  bam_pileup_cd* {.bycopy, union.} = object
    p*: pointer
    i*: int64
    f*: cdouble

  bam_pileup1_t* {.bycopy.} = object
    b*: ptr bam1_t
    qpos*: int32
    indel*: cint
    level*: cint
    is_del* {.bitsize: 1.}: uint32
    is_head* {.bitsize: 1.}: uint32
    is_tail* {.bitsize: 1.}: uint32
    is_refskip* {.bitsize: 1.}: uint32
    aux* {.bitsize: 28.}: uint32
    cd*: bam_pileup_cd         ##  generic per-struct data, owned by caller.

  bam_plp_auto_f* = proc (data: pointer; b: ptr bam1_t): cint {.cdecl.}
  bam_plp_t* {.bycopy.} = object

  bam_mplp_t* {.bycopy.} = object


proc bam_plp_init*(`func`: bam_plp_auto_f; data: pointer): bam_plp_t {.cdecl,
    importc: "bam_plp_init", dynlib: libname.}
proc bam_plp_destroy*(iter: bam_plp_t) {.cdecl, importc: "bam_plp_destroy",
                                      dynlib: libname.}
proc bam_plp_push*(iter: bam_plp_t; b: ptr bam1_t): cint {.cdecl,
    importc: "bam_plp_push", dynlib: libname.}
proc bam_plp_next*(iter: bam_plp_t; tid: ptr cint; pos: ptr cint; n_plp: ptr cint): ptr bam_pileup1_t {.
    cdecl, importc: "bam_plp_next", dynlib: libname.}
proc bam_plp_auto*(iter: bam_plp_t; tid: ptr cint; pos: ptr cint; n_plp: ptr cint): ptr bam_pileup1_t {.
    cdecl, importc: "bam_plp_auto", dynlib: libname.}
proc bam_plp_set_maxcnt*(iter: bam_plp_t; maxcnt: cint) {.cdecl,
    importc: "bam_plp_set_maxcnt", dynlib: libname.}
proc bam_plp_reset*(iter: bam_plp_t) {.cdecl, importc: "bam_plp_reset",
                                    dynlib: libname.}
proc bam_mplp_init*(n: cint; `func`: bam_plp_auto_f; data: ptr pointer): bam_mplp_t {.
    cdecl, importc: "bam_mplp_init", dynlib: libname.}
proc bam_mplp_init_overlaps*(iter: bam_mplp_t) {.cdecl,
    importc: "bam_mplp_init_overlaps", dynlib: libname.}
proc bam_mplp_destroy*(iter: bam_mplp_t) {.cdecl, importc: "bam_mplp_destroy",
                                        dynlib: libname.}
proc bam_mplp_set_maxcnt*(iter: bam_mplp_t; maxcnt: cint) {.cdecl,
    importc: "bam_mplp_set_maxcnt", dynlib: libname.}
proc bam_mplp_auto*(iter: bam_mplp_t; tid: ptr cint; pos: ptr cint; n_plp: ptr cint;
                   plp: ptr ptr bam_pileup1_t): cint {.cdecl,
    importc: "bam_mplp_auto", dynlib: libname.}
## ##############################################
## # kfunc
## ##############################################

proc kf_betai*(a: cdouble; b: cdouble; x: cdouble): cdouble {.cdecl, importc: "kf_betai",
    dynlib: libname.}
proc kt_fisher_exact*(n11: cint; n12: cint; n21: cint; n22: cint; left: ptr cdouble;
                     right: ptr cdouble; two: ptr cdouble): cdouble {.cdecl,
    importc: "kt_fisher_exact", dynlib: libname.}
## ##############################################
## # faidx
## ##############################################

type
  faidx_t* {.bycopy.} = object


proc fai_destroy*(fai: ptr faidx_t) {.cdecl, importc: "fai_destroy", dynlib: libname.}
proc fai_build*(fn: cstring): cint {.cdecl, importc: "fai_build", dynlib: libname.}
proc fai_load*(fn: cstring): ptr faidx_t {.cdecl, importc: "fai_load", dynlib: libname.}
##   @param  len  Length of the region; -2 if seq not present, -1 general error

proc fai_fetch*(fai: ptr faidx_t; reg: cstring; len: ptr cint): cstring {.cdecl,
    importc: "fai_fetch", dynlib: libname.}
proc faidx_nseq*(fai: ptr faidx_t): cint {.cdecl, importc: "faidx_nseq", dynlib: libname.}
proc faidx_fetch_seq*(fai: ptr faidx_t; c_name: cstring; p_beg_i: cint; p_end_i: cint;
                     len: ptr cint): cstring {.cdecl, importc: "faidx_fetch_seq",
    dynlib: libname.}
proc faidx_has_seq*(fai: ptr faidx_t; seq: cstring): cint {.cdecl,
    importc: "faidx_has_seq", dynlib: libname.}
## / Return sequence length, -1 if not present

proc faidx_seq_len*(fai: ptr faidx_t; seq: cstring): cint {.cdecl,
    importc: "faidx_seq_len", dynlib: libname.}
## / Return name of i-th sequence

proc faidx_iseq*(fai: ptr faidx_t; i: cint): cstring {.cdecl, importc: "faidx_iseq",
    dynlib: libname.}
## ##############################################
## # vcf
## ##############################################

const
  BCF_ERR_CTG_UNDEF* = 1
  BCF_ERR_TAG_UNDEF* = 2
  BCF_ERR_NCOLS* = 4
  BCF_ERR_LIMITS* = 8
  BCF_ERR_CHAR* = 16
  BCF_ERR_CTG_INVALID* = 32
  BCF_ERR_TAG_INVALID* = 64

##
## typedef struct {
##     int32_t rid;  // CHROM
##     int32_t pos;  // POS
##     int32_t rlen; // length of REF
##     float qual;   // QUAL
##     uint32_t n_info:16, n_allele:16;
##     uint32_t n_fmt:8, n_sample:24;
##     kstring_t shared, indiv;
##     bcf_dec_t d; // lazy evaluation: $d is not generated by bcf_read(), but by explicitly calling bcf_unpack()
##     int max_unpack;         // Set to BCF_UN_STR, BCF_UN_FLT, or BCF_UN_INFO to boost performance of vcf_parse when some of the fields won't be needed
##     int unpacked;           // remember what has been unpacked to allow calling bcf_unpack() repeatedly without redoing the work
##     int unpack_size[3];     // the original block size of ID, REF+ALT and FILTER
##     int errcode;    // one of BCF_ERR_* codes
## } bcf1_t;
##

type
  INNER_C_UNION_hts_concat_557* {.bycopy, union.} = object
    i*: int32                  ##  integer value
    f*: cfloat                 ##  float value

  variant_t* {.bycopy.} = object
    `type`*: cint
    n*: cint                   ##  variant type and the number of bases affected, negative for deletions

  bcf_hrec_t* {.bycopy.} = object
    `type`*: cint              ##  One of the BCF_HL_* type
    key*: cstring              ##  The part before '=', i.e. FILTER/INFO/FORMAT/contig/fileformat etc.
    value*: cstring            ##  Set only for generic lines, NULL for FILTER/INFO, etc.
    nkeys*: cint               ##  Number of structured fields
    keys*: cstringArray
    vals*: cstringArray        ##  The key=value pairs

  bcf_fmt_t* {.bycopy.} = object
    id*: cint                  ##  id: numeric tag id, the corresponding string is bcf_hdr_t::id[BCF_DT_ID][$id].key
    n*: cint
    size*: cint
    `type`*: cint              ##  n: number of values per-sample; size: number of bytes per-sample; type: one of BCF_BT_* types
    p*: ptr uint8               ##  same as vptr and vptr_* in bcf_info_t below
    p_len*: uint32
    p_off* {.bitsize: 31.}: uint32
    p_free* {.bitsize: 1.}: uint32

  bcf_info_t* {.bycopy.} = object
    key*: cint                 ##  key: numeric tag id, the corresponding string is bcf_hdr_t::id[BCF_DT_ID][$key].key
    `type`*: cint
    len*: cint                 ##  type: one of BCF_BT_* types; len: vector length, 1 for scalars
    v1*: INNER_C_UNION_hts_concat_557 ##  only set if $len==1; for easier access
    vptr*: ptr uint8            ##  pointer to data array in bcf1_t->shared.s, excluding the size+type and tag id bytes
    vptr_len*: uint32          ##  length of the vptr block or, when set, of the vptr_mod block, excluding offset
    vptr_off* {.bitsize: 31.}: uint32 ##  vptr offset, i.e., the size of the INFO key plus size+type bytes
    vptr_free* {.bitsize: 1.}: uint32 ##  indicates that vptr-vptr_off must be freed; set only when modified and the new
                                  ##     data block is bigger than the original

  bcf_idinfo_t* {.bycopy.} = object
    info*: array[3, uint32] ##  stores Number:20, var:4, Type:4, ColType:4 in info[0..2]
                         ##  for BCF_HL_FLT,INFO,FMT and contig length in info[0] for BCF_HL_CTG
    hrec*: array[3, ptr bcf_hrec_t]
    id*: cint

  bcf_idpair_t* {.bycopy.} = object
    key*: cstring
    val*: ptr bcf_idinfo_t

  bcf_hdr_t* {.bycopy.} = object
    n*: array[3, int32]
    id*: array[3, ptr bcf_idpair_t]
    dict*: array[3, pointer]    ##  ID dictionary, contig dict and sample dict
    samples*: cstringArray
    hrec*: ptr ptr bcf_hrec_t
    nhrec*: cint
    dirty*: cint
    ntransl*: cint
    transl*: array[2, ptr cint]  ##  for bcf_translate()
    nsamples_ori*: cint        ##  for bcf_hdr_set_samples()
    keep_samples*: ptr uint8
    mem*: kstring_t
    m*: array[3, int32]

  bcf_dec_t* {.bycopy.} = object
    m_fmt*: cint
    m_info*: cint
    m_id*: cint
    m_als*: cint
    m_allele*: cint
    m_flt*: cint               ##  allocated size (high-water mark); do not change
    n_flt*: cint               ##  Number of FILTER fields
    flt*: ptr cint              ##  FILTER keys in the dictionary
    id*: cstring
    als*: cstring              ##  ID and REF+ALT block (\0-seperated)
    allele*: cstringArray      ##  allele[0] is the REF (allele[] pointers to the als block); all null terminated
    info*: ptr bcf_info_t       ##  INFO
    fmt*: ptr bcf_fmt_t         ##  FORMAT and individual sample
    `var`*: ptr variant_t       ##  $var and $var_type set only when set_variant_types called
    n_var*: cint
    var_type*: cint
    shared_dirty*: cint        ##  if set, shared.s must be recreated on BCF output
    indiv_dirty*: cint         ##  if set, indiv.s must be recreated on BCF output

  bcf1_t* {.bycopy.} = object
    rid*: int32                ##  CHROM
    pos*: int32                ##  POS
    rlen*: int32               ##  length of REF
    qual*: cfloat              ##  QUAL
    n_info* {.bitsize: 16.}: uint32
    n_allele* {.bitsize: 16.}: uint32
    n_fmt* {.bitsize: 8.}: uint32
    n_sample* {.bitsize: 24.}: uint32
    shared*: kstring_t
    indiv*: kstring_t
    d*: bcf_dec_t              ##  lazy evaluation: $d is not generated by bcf_read(), but by explicitly calling bcf_unpack()
    max_unpack*: cint          ##  Set to BCF_UN_STR, BCF_UN_FLT, or BCF_UN_INFO to boost performance of vcf_parse when some of the fields won't be needed
    unpacked*: cint            ##  remember what has been unpacked to allow calling bcf_unpack() repeatedly without redoing the work
    unpack_size*: array[3, cint] ##  the original block size of ID, REF+ALT and FILTER
    errcode*: cint             ##  one of BCF_ERR_* codes


proc bcf_init*(): ptr bcf1_t {.cdecl, importc: "bcf_init", dynlib: libname.}
proc bcf_hdr_parse*(hdr: ptr bcf_hdr_t; htxt: cstring): cint {.cdecl,
    importc: "bcf_hdr_parse", dynlib: libname.}
## / Appends formatted header text to _str_.
## * If _is_bcf_ is zero, `IDX` fields are discarded.
##   @return 0 if successful, or negative if an error occurred
##   @since 1.4
##

proc bcf_hdr_format*(hdr: ptr bcf_hdr_t; is_bcf: cint; str: ptr kstring_t): cint {.cdecl,
    importc: "bcf_hdr_format", dynlib: libname.}
proc bcf_hdr_init*(mode: cstring): ptr bcf_hdr_t {.cdecl, importc: "bcf_hdr_init",
    dynlib: libname.}
proc bcf_hdr_printf*(h: ptr bcf_hdr_t; format: cstring): cint {.varargs, cdecl,
    importc: "bcf_hdr_printf", dynlib: libname.}
proc bcf_hdr_remove*(h: ptr bcf_hdr_t; `type`: cint; key: cstring) {.cdecl,
    importc: "bcf_hdr_remove", dynlib: libname.}
proc bcf_hdr_add_sample*(hdr: ptr bcf_hdr_t; sample: cstring): cint {.cdecl,
    importc: "bcf_hdr_add_sample", dynlib: libname.}
template bcf_hdr_nsamples*(hdr: untyped): untyped =
  (hdr).n[BCF_DT_SAMPLE]

proc bcf_hdr_id2int*(hdr: ptr bcf_hdr_t; `type`: cint; id: cstring): cint {.cdecl,
    importc: "bcf_hdr_id2int", dynlib: libname.}
proc bcf_hdr_name2id*(hdr: ptr bcf_hdr_t; id: cstring): cint {.inline, cdecl.} =
  return bcf_hdr_id2int(hdr, BCF_DT_CTG, id)

const
  bcf_float_missing* = 0x7F800001

proc bcf_float_is_missing*(f: cfloat): cint {.inline, cdecl.} =
  var u: tuple[i: uint32, f: cfloat]
  u.f = f
  return if u.i == bcf_float_missing: 1 else: 0

proc bcf_read*(fp: ptr htsFile; h: ptr bcf_hdr_t; v: ptr bcf1_t): cint {.cdecl,
    importc: "bcf_read", dynlib: libname.}
const
  BCF_UN_STR* = 1
  BCF_UN_FLT* = 2
  BCF_UN_INFO* = 4
  BCF_UN_SHR* = (BCF_UN_STR or BCF_UN_FLT or BCF_UN_INFO) ##  all shared       information
  BCF_UN_FMT* = 8
  BCF_UN_IND* = BCF_UN_FMT
  BCF_UN_ALL* = (BCF_UN_SHR or BCF_UN_FMT)
  BCF_BT_NULL* = 0
  BCF_BT_INT8* = 1
  BCF_BT_INT16* = 2
  BCF_BT_INT32* = 3
  BCF_BT_FLOAT* = 5
  BCF_BT_CHAR* = 7
  INT8_MIN* = -128
  INT16_MIN* = -32768
  INT32_MIN* = -2147483648'i64

proc bcf_unpack*(b: ptr bcf1_t; which: cint): cint {.cdecl, importc: "bcf_unpack",
    dynlib: libname.}
proc bcf_hdr_read*(fp: ptr htsFile): ptr bcf_hdr_t {.cdecl, importc: "bcf_hdr_read",
    dynlib: libname.}
proc bcf_hdr_dup*(hdr: ptr bcf_hdr_t): ptr bcf_hdr_t {.cdecl, importc: "bcf_hdr_dup",
    dynlib: libname.}
proc bcf_hdr_write*(fp: ptr htsFile; h: ptr bcf_hdr_t): cint {.cdecl,
    importc: "bcf_hdr_write", dynlib: libname.}
proc bcf_write*(fp: ptr htsFile; h: ptr bcf_hdr_t; v: ptr bcf1_t): cint {.cdecl,
    importc: "bcf_write", dynlib: libname.}
proc bcf_hdr_destroy*(h: ptr bcf_hdr_t) {.cdecl, importc: "bcf_hdr_destroy",
                                      dynlib: libname.}
proc bcf_dup*(src: ptr bcf1_t): ptr bcf1_t {.cdecl, importc: "bcf_dup", dynlib: libname.}
proc bcf_destroy*(v: ptr bcf1_t) {.cdecl, importc: "bcf_destroy", dynlib: libname.}
proc bcf_add_filter*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; flt_id: cint): cint {.cdecl,
    importc: "bcf_add_filter", dynlib: libname.}
proc bcf_update_id*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; id: cstring): cint {.cdecl,
    importc: "bcf_update_id", dynlib: libname.}
proc bcf_update_info*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; key: cstring;
                     values: pointer; n: cint; `type`: cint): cint {.cdecl,
    importc: "bcf_update_info", dynlib: libname.}
proc bcf_update_alleles_str*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t;
                            dst: ptr cstringArray): cint {.cdecl,
    importc: "bcf_update_alleles_str", dynlib: libname.}
proc bcf_hdr_set_samples*(hdr: ptr bcf_hdr_t; samples: cstring; is_file: cint): cint {.
    cdecl, importc: "bcf_hdr_set_samples", dynlib: libname.}
proc bcf_subset_format*(hdr: ptr bcf_hdr_t; rec: ptr bcf1_t): cint {.cdecl,
    importc: "bcf_subset_format", dynlib: libname.}
proc bcf_get_genotypes*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; dst: ptr ptr cint;
                       ndst: ptr cint): cint {.cdecl, importc: "bcf_get_genotypes",
    dynlib: libname.}
proc bcf_get_format_values*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; tag: cstring;
                           dst: ptr pointer; ndst: ptr cint; `type`: cint): cint {.cdecl,
    importc: "bcf_get_format_values", dynlib: libname.}
proc bcf_get_format_string*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; tag: cstring;
                           dst: ptr cstringArray; ndst: ptr cint): cint {.cdecl,
    importc: "bcf_get_format_string", dynlib: libname.}
## typedef htsFile vcfFile;

proc bcf_hdr_append*(h: ptr bcf_hdr_t; line: cstring): cint {.cdecl,
    importc: "bcf_hdr_append", dynlib: libname.}
proc bcf_hdr_sync*(h: ptr bcf_hdr_t): cint {.cdecl, importc: "bcf_hdr_sync",
                                        dynlib: libname.}
proc bcf_update_format_string*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; key: cstring;
                              values: cstringArray; n: cint): cint {.cdecl,
    importc: "bcf_update_format_string", dynlib: libname.}
proc bcf_update_format*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; key: cstring;
                       values: pointer; n: cint; `type`: cint): cint {.cdecl,
    importc: "bcf_update_format", dynlib: libname.}
proc vcf_parse*(s: ptr kstring_t; h: ptr bcf_hdr_t; v: ptr bcf1_t): cint {.cdecl,
    importc: "vcf_parse", dynlib: libname.}
proc vcf_format*(h: ptr bcf_hdr_t; v: ptr bcf1_t; s: ptr kstring_t): cint {.cdecl,
    importc: "vcf_format", dynlib: libname.}
proc bcf_index_load*(fn: cstring): ptr hts_idx_t {.cdecl, importc: "bcf_index_load",
    dynlib: libname.}
template bcf_itr_queryi*(idx, tid, beg, `end`: untyped): untyped =
  hts_itr_query((idx), (tid), (beg), (`end`), bcf_readrec)

proc bcf_itr_next*(a1: ptr htsFile; iter: ptr hts_itr_t; a3: ptr bcf1_t): cint {.cdecl,
    importc: "bcf_itr_next", dynlib: libname.}
proc bcf_readrec*(fp: ptr BGZF; null: pointer; v: pointer; tid: ptr cint; beg: ptr cint;
                 `end`: ptr cint): cint {.cdecl, importc: "bcf_readrec",
                                      dynlib: libname.}
proc bcf_get_fmt*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; key: cstring): ptr bcf_fmt_t {.
    cdecl, importc: "bcf_get_fmt", dynlib: libname.}
proc bcf_get_info*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; key: cstring): ptr bcf_info_t {.
    cdecl, importc: "bcf_get_info", dynlib: libname.}
proc bcf_get_info_values*(hdr: ptr bcf_hdr_t; line: ptr bcf1_t; tag: cstring;
                         dst: ptr pointer; ndst: ptr cint; `type`: cint): cint {.cdecl,
    importc: "bcf_get_info_values", dynlib: libname.}
## *
##   bcf_hdr_get_hrec() - get header line info
##   @param type:  one of the BCF_HL_* types: FLT,INFO,FMT,CTG,STR,GEN
##   @param key:   the header key for generic lines (e.g. "fileformat"), any field
##                   for structured lines, typically "ID".
##   @param value: the value which pairs with key. Can be be NULL for BCF_HL_GEN
##   @param str_class: the class of BCF_HL_STR line (e.g. "ALT" or "SAMPLE"), otherwise NULL
##

proc bcf_hdr_get_hrec*(hdr: ptr bcf_hdr_t; `type`: cint; key: cstring; value: cstring;
                      str_class: cstring): ptr bcf_hrec_t {.cdecl,
    importc: "bcf_hdr_get_hrec", dynlib: libname.}
