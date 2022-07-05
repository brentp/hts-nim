#ifdef C2NIM
#  dynlib libname
#  cdecl
#  if defined(windows)
#    define libname "libhts.dll"
#  elif defined(macosx)
#    define libname "libhts.dylib"
#  else
#    define libname "libhts.so"
#  endif
#mangle uint8_t uint8
#mangle uint16_t uint16
#mangle uint64_t uint64
#mangle uint32_t uint32
#mangle int8_t int8
#mangle int32_t int32
#mangle int64_t int64
#mangle ssize_t int64
#mangle hts_pos_t int64
#endif

/*
enum hts_fmt_option {
    // CRAM specific
    CRAM_OPT_DECODE_MD,
    CRAM_OPT_PREFIX,
    CRAM_OPT_VERBOSITY,  // obsolete, use hts_set_log_level() instead
    CRAM_OPT_SEQS_PER_SLICE,
    CRAM_OPT_SLICES_PER_CONTAINER,
    CRAM_OPT_RANGE,
    CRAM_OPT_VERSION,    // rename to cram_version?
    CRAM_OPT_EMBED_REF,
    CRAM_OPT_IGNORE_MD5,
    CRAM_OPT_REFERENCE,  // make general
    CRAM_OPT_MULTI_SEQ_PER_SLICE,
    CRAM_OPT_NO_REF,
    CRAM_OPT_USE_BZIP2,
    CRAM_OPT_SHARED_REF,
    CRAM_OPT_NTHREADS,   // deprecated, use HTS_OPT_NTHREADS
    CRAM_OPT_THREAD_POOL,// make general
    CRAM_OPT_USE_LZMA,
    CRAM_OPT_USE_RANS,
    CRAM_OPT_REQUIRED_FIELDS,
    CRAM_OPT_LOSSY_NAMES,
    CRAM_OPT_BASES_PER_SLICE,

    // General purpose
    HTS_OPT_COMPRESSION_LEVEL = 100,
    HTS_OPT_NTHREADS,
    HTS_OPT_THREAD_POOL,
    HTS_OPT_CACHE_SIZE,
    HTS_OPT_BLOCK_SIZE,
};
*/

#define BAM_FPAIRED        1
/*! @abstract the read is mapped in a proper pair */
#define BAM_FPROPER_PAIR   2
/*! @abstract the read itself is unmapped; conflictive with BAM_FPROPER_PAIR */
#define BAM_FUNMAP         4
/*! @abstract the mate is unmapped */
#define BAM_FMUNMAP        8
/*! @abstract the read is mapped to the reverse strand */
#define BAM_FREVERSE      16
/*! @abstract the mate is mapped to the reverse strand */
#define BAM_FMREVERSE     32
/*! @abstract this is read1 */
#define BAM_FREAD1        64
/*! @abstract this is read2 */
#define BAM_FREAD2       128
/*! @abstract not primary alignment */
#define BAM_FSECONDARY   256
/*! @abstract QC failure */
#define BAM_FQCFAIL      512
/*! @abstract optical or PCR duplicate */
#define BAM_FDUP        1024
/*! @abstract supplementary alignment */
#define BAM_FSUPPLEMENTARY 2048

#define HTS_FMT_CSI 0
#define HTS_FMT_BAI 1
#define HTS_FMT_TBI 2
#define HTS_FMT_CRAI 3

#define BCF_HT_FLAG 0 // header type
#define BCF_HT_INT  1
#define BCF_HT_REAL 2
#define BCF_HT_STR  3

#define HTS_IDX_NOCOOR (-2)
#define HTS_IDX_START  (-3)
#define HTS_IDX_REST   (-4)
#define HTS_IDX_NONE   (-5)


#define BCF_DT_ID       0 // dictionary type
#define BCF_DT_CTG      1
#define BCF_DT_SAMPLE   2

struct hFILE;


//############################
//# kstring
//############################

typedef struct __kstring_t {
  size_t l, m;
  char *s;
} kstring_t;

static inline char *ks_release(kstring_t *s);
void kputsn(char *, int, kstring_t *);


//##########################
//# BGZF
//##########################
typedef struct __bgzidx_t {} bgzidx_t;
struct bgzf_mtaux_t;

struct z_stream_s;
typedef struct bgzf_cache_t {} bgzf_cache_t;

struct BGZF {
    // Reserved bits should be written as 0; read as "don't care"
    unsigned errcode:16, reserved:1, is_write:1, no_eof_block:1, is_be:1;
    signed compress_level:9;
    unsigned last_block_eof:1, is_compressed:1, is_gzip:1;
    int cache_size;
    int block_length, block_clength, block_offset;
    int64_t block_address, uncompressed_address;
    void *uncompressed_block, *compressed_block;
    bgzf_cache_t *cache;
    struct hFILE *fp; // actual file handle
    struct bgzf_mtaux_t *mt; // only used for multi-threading
    bgzidx_t *idx;      // BGZF index
    int idx_build_otf;  // build index on the fly, set by bgzf_index_build_init()
    struct z_stream_s *gz_stream; // for gzip-compressed files
    int64_t seeked;     // virtual offset of last seek
};


BGZF* bgzf_open(const char* path, const char *mode);
int bgzf_close(BGZF *fp);
BGZF* bgzf_hopen(struct hFILE *fp, const char *mode);
int bgzf_flush(BGZF *fp);

hFILE *hopen(const char *filename, const char *mode, ...);
int hclose(hFILE *fp);


    /**
     * Write _length_ bytes from _data_ to the file.  If no I/O errors occur,
     * the complete _length_ bytes will be written (or queued for writing).
     *
     * @param fp     BGZF file handler
     * @param data   data array to write
     * @param length size of data to write
     * @return       number of bytes written (i.e., _length_); negative on error
     */
ssize_t bgzf_write(BGZF *fp, const void *data, size_t length);

#define bgzf_tell(fp) (((fp)->block_address << 16) | ((fp)->block_offset & 0xFFFF))

int bgzf_getline(BGZF *fp, int delim, kstring_t *str);
int bgzf_mt(BGZF *fp, int n_threads, int n_sub_blks);


enum htsFormatCategory {
    unknown_category,
    sequence_data,    // Sequence data -- SAM, BAM, CRAM, etc
    variant_data,     // Variant calling data -- VCF, BCF, etc
    index_file,       // Index file associated with some data file
    region_list,      // Coordinate intervals or regions -- BED, etc
    category_maximum = 32767
};

enum htsExactFormat {
    unknown_format,
    binary_format, text_format,
    sam, bam, bai, cram, crai, vcf, bcf, csi, gzi, tbi, bed,
    htsget,
    json,
    empty_format,  // File is empty (or empty after decompression)
    fasta_format, fastq_format, fai_format, fqi_format,
    format_maximum = 32767
};

enum htsCompression {
    no_compression, gzip, bgzf, custom, bzip2_compression,
    compression_maximum = 32767
};

typedef struct htsFormat {
    enum htsFormatCategory category;
    enum htsExactFormat format;
    struct { short major, minor; } version;
    enum htsCompression compression;
    short compression_level;  // currently unused
    void *specific;  // format specific options; see struct hts_opt.
} htsFormat;



//###########################
//# hts
//###########################
typedef struct cram_fd {} cram_fd;
typedef htsFile samFile;
typedef struct sam_hrecs_t {} sam_hrecs_t;

typedef struct sam_hdr_t {
    int32_t n_targets, ignore_sam_err;
    size_t l_text;
    uint32_t *target_len;
    const int8_t *cigar_tab; //HTS_DEPRECATED("Use bam_cigar_table[] instead");
    char **target_name;
    char *text;
    void *sdict;
    sam_hrecs_t *hrecs;
    uint32_t ref_count;
} sam_hdr_t;

typedef struct __hts_idx_t {} hts_idx_t;
typedef struct {
    uint32_t is_bin:1, is_write:1, is_be:1, is_cram:1, is_bgzf:1, dummy:27;
    int64_t lineno;
    kstring_t line;
    char *fn, *fn_aux;
    union {
        BGZF *bgzf;
        struct cram_fd *cram;
        struct hFILE *hfile;
    } fp;
    void *state;  // format specific state information
    htsFormat format;
    hts_idx_t *idx;
    const char *fnidx;
    struct sam_hdr_t *bam_header;
} htsFile;



htsFile *hts_open(const char *fn, const char *mode);
int hts_close(htsFile *fp);
int hts_check_EOF(htsFile *fp);

int hts_getline(htsFile *fp, int delimiter, kstring_t *str);
int hts_set_threads(htsFile *fp, int n);
int hts_set_fai_filename(htsFile *fp, const char *fn_aux);

typedef int hts_readrec_func(BGZF *fp, void *data, void *r, int *tid, int64 *beg, int64 *end);

typedef const char *(*hts_id2name_f)(void*, int);



typedef struct _h {} hts_itr_t;

hts_idx_t *hts_idx_init(int n, int fmt, uint64_t offset0, int min_shift, int n_lvls);

void hts_idx_destroy(hts_idx_t *idx);
int hts_idx_push(hts_idx_t *idx, int tid, hts_pos_t beg, hts_pos_t end, uint64_t offset, int is_mapped);
void hts_idx_finish(hts_idx_t *idx, uint64_t final_offset);

void hts_idx_save(const hts_idx_t *idx, const char *fn, int fmt);
hts_idx_t *hts_idx_load(const char *fn, int fmt);
hts_idx_t *hts_idx_load2(const char *fn, const char *fnidx);

const char *hts_version(void);

uint8_t *hts_idx_get_meta(hts_idx_t *idx, int *l_meta);
int hts_idx_set_meta(hts_idx_t *idx, uint32_t l_meta, uint8_t *meta, int is_copy);

int hts_idx_get_stat(const hts_idx_t* idx, int tid, uint64_t* mapped, uint64_t* unmapped);
uint64_t hts_idx_get_n_no_coor(const hts_idx_t* idx);

const char *hts_parse_reg(const char *s, int64_t *beg, int64_t *end);
hts_itr_t *hts_itr_query(const hts_idx_t *idx, int tid, hts_pos_t beg, hts_pos_t end, hts_readrec_func *readrec);

void hts_itr_destroy(hts_itr_t *iter);

int hts_itr_next(BGZF *fp, hts_itr_t *iter, void *r, void *data);

typedef hts_itr_t *hts_itr_query_func(const hts_idx_t *idx, int tid, hts_pos_t beg, hts_pos_t end, hts_readrec_func *readrec);

typedef int (*hts_name2id_f)(void*, const char*);
hts_itr_t *hts_itr_querys(const hts_idx_t *idx, const char *reg, hts_name2id_f getid, void *hdr, hts_itr_query_func *itr_query, hts_readrec_func *readrec);

//###########################
//# tbx
//###########################
typedef struct {
    int32_t preset;
    int32_t sc, bc, ec; // seq col., beg col. and end col.
    int32_t meta_char, line_skip;
} tbx_conf_t;

typedef struct {
    tbx_conf_t conf;
    hts_idx_t *idx;
    void *dict;
} tbx_t;



int tbx_name2id(tbx_t *tbx, const char *ss);
int tbx_index_build(const char *fn, int min_shift, const tbx_conf_t *conf);
tbx_t *tbx_index_load(const char *fn);
tbx_t *tbx_index_load2(const char *fn, const char *fnidx);
 #define tbx_itr_querys(tbx, s) hts_itr_querys((tbx)->idx, (s), (hts_name2id_f)(tbx_name2id), (tbx), hts_itr_query, tbx_readrec)

const char **tbx_seqnames(tbx_t *tbx, int *n);  // free the array but not the values
void tbx_destroy(tbx_t *tbx);

int tbx_readrec(BGZF *fp, void *tbxv, void *sv, int *tid, int64_t *beg, int64_t *end);
#define tbx_itr_queryx(idx, tid, beg, end) hts_itr_query(idx, (tid), (beg), (stop), tbx_readrec)

#define tbx_itr_queryi(tbx, tid, beg, end) hts_itr_query((tbx)->idx, (tid), (beg), (stop), tbx_readrec)



//#####################################
//# sam.h
//#####################################


/*! @typedef
 * @abstract Old name for compatibility with existing code.
 */
typedef sam_hdr_t bam_hdr_t;

typedef struct {
    hts_pos_t pos;
    int32_t tid;
    uint16_t bin; // NB: invalid on 64-bit pos
    uint8_t qual;
    uint8_t l_extranul;
    uint16_t flag;
    uint16_t l_qname;
    uint32_t n_cigar;
    int32_t l_qseq;
    int32_t mtid;
    hts_pos_t mpos;
    hts_pos_t isize;
} bam1_core_t;

typedef struct {
    bam1_core_t core;
    uint64_t id;
    uint8_t *data;
    int l_data;
    uint32_t m_data;
    uint32_t mempolicy:2, reserved:30;
} bam1_t;




sam_hdr_t *sam_hdr_parse(int l_text, const char *text);
sam_hdr_t *sam_hdr_read(samFile *fp);
int bam_name2id(bam_hdr_t *h, const char *ref);
sam_hdr_t* sam_hdr_dup(const bam_hdr_t *h0);
int sam_hdr_write(htsFile *fp, const bam_hdr_t *h);
int sam_write1(htsFile *fp, const bam_hdr_t *h, const bam1_t *b);
void sam_hdr_destroy(bam_hdr_t *h);

int sam_format1(const bam_hdr_t *h, const bam1_t *b, kstring_t *str);
int sam_read1(samFile *fp, bam_hdr_t *h, bam1_t *b);
int bam_read1(BGZF *fp, bam1_t *b);


bam1_t *bam_init1();
void bam_destroy1(bam1_t *b);
#define bam_is_mrev(b) (((b)->core.flag&BAM_FMREVERSE) != 0)
#define bam_get_qname(b) ((char*)(b)->data)


uint8_t *bam_get_aux(bam1_t *b);
int bam_get_l_aux(bam1_t *b);
uint8_t *bam_aux_get(const bam1_t *b, const char tag[2]);
int64_t bam_aux2i(const uint8_t *s);
double bam_aux2f(const uint8_t *s);
char *bam_aux2Z(const uint8_t *s);
char bam_aux2A(const uint8_t *s);
int bam_aux_del(bam1_t *b, uint8_t *s);

int bam_aux_update_str(bam1_t *b, const char tag[2], int len, const char *data);
int bam_aux_update_int(bam1_t *b, const char tag[2], int64_t val);
int bam_aux_update_float(bam1_t *b, const char tag[2], float val);


bam1_t *bam_copy1(bam1_t *bdst, const bam1_t *bsrc);
bam1_t *bam_dup1(const bam1_t *bsrc);

int bam_cigar2qlen(int n_cigar, const uint32_t *cigar);
int bam_cigar2rlen(int n_cigar, const uint32_t *cigar);
int32_t bam_endpos(const bam1_t *b);

int   bam_str2flag(const char *str);    /** returns negative value on error */
char *bam_flag2str(int flag);   /** The string must be freed by the user */

int sam_parse1(kstring_t *s, bam_hdr_t *h, bam1_t *b);



hts_idx_t * sam_index_load(samFile *in, char *); // load index
hts_idx_t *sam_index_load2(htsFile *fp, const char *fn, const char *fnidx);
int bam_index_build(const char *fn, int min_shift);
int sam_index_build3(const char *fn, const char *fnidx, int min_shift, int nthreads);


hts_itr_t * sam_itr_querys(hts_idx_t*, bam_hdr_t *h, char * region);
hts_itr_t *sam_itr_queryi(const hts_idx_t *idx, int tid, int beg, int end);

int hts_detect_format(struct hFILE *fp, htsFormat *fmt);
char *hts_format_description(const htsFormat *format);



#define sam_itr_next(htsfp, itr, r) hts_itr_next((htsfp)->fp.bgzf, (itr), (r), (htsfp))


#define BAM_CMATCH      0
#define BAM_CINS        1
#define BAM_CDEL        2
#define BAM_CREF_SKIP   3
#define BAM_CSOFT_CLIP  4
#define BAM_CHARD_CLIP  5
#define BAM_CPAD        6
#define BAM_CEQUAL      7
#define BAM_CDIFF       8
#define BAM_CBACK       9

#define BAM_CIGAR_STR   "MIDNSHP=XB"
#define BAM_CIGAR_SHIFT 4
#define BAM_CIGAR_MASK  0xf
#define BAM_CIGAR_TYPE  0x3C1A7

#define bam_cigar_op(c) ((c)&BAM_CIGAR_MASK)
#define bam_cigar_oplen(c) ((c)>>BAM_CIGAR_SHIFT)
// Note that BAM_CIGAR_STR is padded to length 16 bytes below so that
// the array look-up will not fall off the end.  '?' is chosen as the
// padding character so it's easy to spot if one is emitted, and will
// result in a parsing failure (in sam_parse1(), at least) if read.
#define bam_cigar_opchr(c) ("MIDNSHP=XB??????"[bam_cigar_op(c)])
#define bam_cigar_gen(l, o) ((l)<<BAM_CIGAR_SHIFT|(o))


//##############################################
//# kfunc
//##############################################

double kf_betai(double a, double b, double x);
double kt_fisher_exact(int n11, int n12, int n21, int n22, double *left, double *right, double *two);

//##############################################
//# faidx
//##############################################

typedef struct __faidx_t {} faidx_t;



void fai_destroy(faidx_t *fai);
int fai_build(const char *fn);

faidx_t *fai_load(const char *fn);
//  @param  len  Length of the region; -2 if seq not present, -1 general error
char *fai_fetch(const faidx_t *fai, const char *reg, int *len);
int faidx_nseq(const faidx_t *fai);
char *faidx_fetch_seq(const faidx_t *fai, const char *c_name, int p_beg_i, int p_end_i, int *len);
int faidx_has_seq(const faidx_t *fai, const char *seq);

/// Return sequence length, -1 if not present
int faidx_seq_len(const faidx_t *fai, const char *seq);

/// Return name of i-th sequence
const char *faidx_iseq(const faidx_t *fai, int i);


//##############################################
//# vcf
//##############################################

#define BCF_ERR_CTG_UNDEF 1
#define BCF_ERR_TAG_UNDEF 2
#define BCF_ERR_NCOLS     4
#define BCF_ERR_LIMITS    8
#define BCF_ERR_CHAR     16
#define BCF_ERR_CTG_INVALID   32
#define BCF_ERR_TAG_INVALID   64



typedef struct {
    int type, n;    // variant type and the number of bases affected, negative for deletions
} variant_t;


typedef struct {
    int type;       // One of the BCF_HL_* type
    char *key;      // The part before '=', i.e. FILTER/INFO/FORMAT/contig/fileformat etc.
    char *value;    // Set only for generic lines, NULL for FILTER/INFO, etc.
    int nkeys;              // Number of structured fields
    char **keys, **vals;    // The key=value pairs
} bcf_hrec_t;

typedef struct {
    int id;             // id: numeric tag id, the corresponding string is bcf_hdr_t::id[BCF_DT_ID][$id].key
    int n, size, type;  // n: number of values per-sample; size: number of bytes per-sample; type: one of BCF_BT_* types
    uint8_t *p;         // same as vptr and vptr_* in bcf_info_t below
    uint32_t p_len;
    uint32_t p_off:31, p_free:1;
} bcf_fmt_t;



typedef struct {
    int key;        // key: numeric tag id, the corresponding string is bcf_hdr_t::id[BCF_DT_ID][$key].key
    int type;  // type: one of BCF_BT_* types
    union {
        int64_t i; // integer value
        float f;   // float value
    } v1; // only set if $len==1; for easier access
    uint8_t *vptr;          // pointer to data array in bcf1_t->shared.s, excluding the size+type and tag id bytes
    uint32_t vptr_len;      // length of the vptr block or, when set, of the vptr_mod block, excluding offset
    uint32_t vptr_off:31,   // vptr offset, i.e., the size of the INFO key plus size+type bytes
            vptr_free:1;    // indicates that vptr-vptr_off must be freed; set only when modified and the new
                            //    data block is bigger than the original
    int len;                // vector length, 1 for scalars
} bcf_info_t;

typedef struct {
    uint64_t info[3];  // stores Number:20, var:4, Type:4, ColType:4 in info[0..2]
                       // for BCF_HL_FLT,INFO,FMT and contig length in info[0] for BCF_HL_CTG
    bcf_hrec_t *hrec[3];
    int id;
} bcf_idinfo_t;


typedef struct {
    const char *key;
    const bcf_idinfo_t *val;
} bcf_idpair_t;


typedef struct {
    int32_t n[3];           // n:the size of the dictionary block in use, (allocated size, m, is below to preserve ABI)
    bcf_idpair_t *id[3];
    void *dict[3];          // ID dictionary, contig dict and sample dict
    char **samples;
    bcf_hrec_t **hrec;
    int nhrec, dirty;
    int ntransl, *transl[2];    // for bcf_translate()
    int nsamples_ori;           // for bcf_hdr_set_samples()
    uint8_t *keep_samples;
    kstring_t mem;
    int32_t m[3];          // m: allocated size of the dictionary block in use (see n above)
} bcf_hdr_t;


typedef struct {
    int m_fmt, m_info, m_id, m_als, m_allele, m_flt; // allocated size (high-water mark); do not change
    int n_flt;  // Number of FILTER fields
    int *flt;   // FILTER keys in the dictionary
    char *id, *als;     // ID and REF+ALT block (\0-seperated)
    char **allele;      // allele[0] is the REF (allele[] pointers to the als block); all null terminated
    bcf_info_t *info;   // INFO
    bcf_fmt_t *fmt;     // FORMAT and individual sample
    variant_t *var;     // $var and $var_type set only when set_variant_types called
    int n_var, var_type;
    int shared_dirty;   // if set, shared.s must be recreated on BCF output
    int indiv_dirty;    // if set, indiv.s must be recreated on BCF output
} bcf_dec_t;

typedef struct {
    hts_pos_t pos;  // POS
    hts_pos_t rlen; // length of REF
    int32_t rid;  // CHROM
    float qual;   // QUAL
    uint32_t n_info:16, n_allele:16;
    uint32_t n_fmt:8, n_sample:24;
    kstring_t shared, indiv;
    bcf_dec_t d; // lazy evaluation: $d is not generated by bcf_read(), but by explicitly calling bcf_unpack()
    int max_unpack;         // Set to BCF_UN_STR, BCF_UN_FLT, or BCF_UN_INFO to boost performance of vcf_parse when some of the fields won't be needed
    int unpacked;           // remember what has been unpacked to allow calling bcf_unpack() repeatedly without redoing the work
    int unpack_size[3];     // the original block size of ID, REF+ALT and FILTER
    int errcode;    // one of BCF_ERR_* codes
} bcf1_t;



bcf1_t *bcf_init(void);

int bcf_hdr_parse(bcf_hdr_t *hdr, char *htxt);
/// Appends formatted header text to _str_.
/** If _is_bcf_ is zero, `IDX` fields are discarded.
 *  @return 0 if successful, or negative if an error occurred
 *  @since 1.4
 */
int bcf_hdr_format(const bcf_hdr_t *hdr, int is_bcf, kstring_t *str);
bcf_hdr_t *bcf_hdr_init(const char *mode);

int bcf_hdr_printf(bcf_hdr_t *h, const char *format, ...);
void bcf_hdr_remove(bcf_hdr_t *h, int type, const char *key);

int bcf_hdr_add_sample(bcf_hdr_t *hdr, const char *sample);
bcf_hdr_t *bcf_hdr_merge(bcf_hdr_t *dst, const bcf_hdr_t *src);




#define bcf_hdr_nsamples(hdr) (hdr)->n[BCF_DT_SAMPLE]

int bcf_hdr_id2int(const bcf_hdr_t *hdr, int type, const char *id);
static inline int bcf_hdr_name2id(const bcf_hdr_t *hdr, const char *id) { return bcf_hdr_id2int(hdr, BCF_DT_CTG, id); }


#define bcf_float_missing 0x7F800001

static inline int bcf_float_is_missing(float f) {
     union { uint32_t i; float f; } u;
     u.f = f;
     return u.i==bcf_float_missing ? 1 : 0;
}


int bcf_read(htsFile *fp, const bcf_hdr_t *h, bcf1_t *v);


#define BCF_UN_STR  1       // up to ALT inclusive
#define BCF_UN_FLT  2       // up to FILTER
#define BCF_UN_INFO 4       // up to INFO
#define BCF_UN_SHR  (BCF_UN_STR|BCF_UN_FLT|BCF_UN_INFO) // all shared       information
#define BCF_UN_FMT  8                           // unpack format and        each sample
#define BCF_UN_IND  BCF_UN_FMT                  // a synonymo of            BCF_UN_FMT
#define BCF_UN_ALL  (BCF_UN_SHR|BCF_UN_FMT)

#define BCF_BT_NULL     0
#define BCF_BT_INT8     1
#define BCF_BT_INT16    2
#define BCF_BT_INT32    3
#define BCF_BT_FLOAT    5
#define BCF_BT_CHAR     7

#define INT8_MIN -128
#define INT16_MIN -32768
#define INT32_MIN -2147483648

int bcf_unpack(bcf1_t *b, int which);
bcf_hdr_t *bcf_hdr_read(htsFile *fp);
bcf_hdr_t *bcf_hdr_dup(const bcf_hdr_t *hdr);
int bcf_hdr_write(htsFile *fp, bcf_hdr_t *h);
int bcf_write(htsFile *fp, bcf_hdr_t *h, bcf1_t *v);
void bcf_hdr_destroy(bcf_hdr_t *h);
bcf1_t *bcf_dup(bcf1_t *src);
void bcf_destroy(bcf1_t *v);
int bcf_add_filter(const bcf_hdr_t *hdr, bcf1_t *line, int flt_id);
int bcf_update_id(const bcf_hdr_t *hdr, bcf1_t *line, const char *id);
int bcf_update_info(const bcf_hdr_t *hdr, bcf1_t *line, const char *key, const void *values, int n, int type);
int bcf_update_alleles_str(const bcf_hdr_t *hdr, bcf1_t *line, char *alleles_str);
int bcf_update_alleles(const bcf_hdr_t *hdr, bcf1_t *line, char **alleles, int nals);

int bcf_hdr_set_samples(bcf_hdr_t *hdr, const char *samples, int is_file);
int bcf_subset_format(const bcf_hdr_t *hdr, bcf1_t *rec);
int bcf_get_genotypes(const bcf_hdr_t *hdr, bcf1_t *line, int **dst, int *ndst);
int bcf_get_format_values(const bcf_hdr_t *hdr, bcf1_t *line, const char *tag, void **dst, int *ndst, int type);
int bcf_get_format_string(const bcf_hdr_t *hdr, bcf1_t *line, const char *tag, char ***dst, int *ndst);

//typedef htsFile vcfFile;
int bcf_hdr_append(bcf_hdr_t *h, const char *line);
int bcf_hdr_sync(bcf_hdr_t *h);
const char **bcf_hdr_seqnames(const bcf_hdr_t *h, int *nseqs);



int bcf_update_format_string(const bcf_hdr_t *hdr, bcf1_t *line, const char *key, const char **values, int n);
int bcf_update_format(const bcf_hdr_t *hdr, bcf1_t *line, const char *key, const void *values, int n, int type);


int vcf_parse(kstring_t *s, const bcf_hdr_t *h, bcf1_t *v);
int vcf_format(const bcf_hdr_t *h, const bcf1_t *v, kstring_t *s);

hts_idx_t *bcf_index_load(char *fn);
#define bcf_itr_queryi(idx, tid, beg, end) hts_itr_query((idx), (tid), (beg), (end), bcf_readrec)

const char **hts_idx_seqnames(const hts_idx_t *idx, int *n, hts_id2name_f getid, void *hdr); // free only the array, not the values


int bcf_itr_next(htsFile *, hts_itr_t* iter, bcf1_t*);

int bcf_readrec(BGZF *fp, void *null, void *v, int *tid, int64 *beg, int64 *end);


bcf_fmt_t *bcf_get_fmt(const bcf_hdr_t *hdr, bcf1_t *line, const char *key);
bcf_info_t *bcf_get_info(const bcf_hdr_t *hdr, bcf1_t *line, const char *key);
int bcf_get_info_values(const bcf_hdr_t *hdr, bcf1_t *line, const char *tag, void **dst, int *ndst, int type);


/**
*  bcf_hdr_get_hrec() - get header line info
*  @param type:  one of the BCF_HL_* types: FLT,INFO,FMT,CTG,STR,GEN
*  @param key:   the header key for generic lines (e.g. "fileformat"), any field
*                  for structured lines, typically "ID".
*  @param value: the value which pairs with key. Can be be NULL for BCF_HL_GEN
*  @param str_class: the class of BCF_HL_STR line (e.g. "ALT" or "SAMPLE"), otherwise NULL
*/
bcf_hrec_t *bcf_hdr_get_hrec(const bcf_hdr_t *hdr, int type, const char *key, const char *value, const char *str_class);

/**
*  bcf_index_build3() - Generate and save an index to a specific file
*  @fn:         Input VCF/BCF filename
*  @fnidx:      Output filename, or NULL to add .csi/.tbi to @fn
*  @min_shift:  Positive to generate CSI, or 0 to generate TBI
*  @n_threads:  Number of VCF/BCF decoder threads
*
*  Returns 0 if successful, or negative if an error occurred.
*
*  List of error codes:
*      -1 .. indexing failed
*      -2 .. opening @fn failed
*      -3 .. format not indexable
*      -4 .. failed to create and/or save the index
*/

int bcf_index_build3(const char *fn, const char *fnidx, int min_shift, int n_threads);

