import ./private/hts_concat
import ./utils


type HTSFile* = object
  ## HTSFile allows iterating over regular, gzipped, or bgzipped files
  p : ptr htsFile
  kstr : kstring_t

type FileType* {.pure.} = enum
  UNKNOWN = htsExactFormat.unknown_format
  SAM = htsExactFormat.sam
  BAM = htsExactFormat.bam
  BAI = htsExactFormat.bai
  CRAM = htsExactFormat.cram
  CRAI = htsExactFormat.crai
  VCF = htsExactFormat.vcf
  BCF = htsExactFormat.bcf
  CSI = htsExactFormat.csi
  TBI = htsExactFormat.tbi
  BED = htsExactFormat.bed

  FASTA = htsExactFormat.fasta_format
  FAI = htsExactFormat.fai_format


proc file_type*(fname:string): FileType =
  var h = hopen(fname, "r")
  if h == nil:
    raise newException(OSError, "unable to open file:" & fname)

  defer:
    discard hclose(h)

  var fmt: htsFormat
  doAssert 0 == hts_detect_format(h, fmt.addr), "unable to detect format for:" & fname

  case fmt.format:
    of htsExactFormat.sam:
      return FileType.SAM
    of htsExactFormat.cram:
      return FileType.CRAM
    of htsExactFormat.bam:
      return FileType.BAM
    of htsExactFormat.bcf:
      return FileType.BCF
    of htsExactFormat.vcf:
      return FileType.VCF
    of htsExactFormat.csi:
      return FileType.CSI
    of htsExactFormat.tbi:
      return FileType.TBI
    of htsExactFormat.bai:
      return FileType.BAI
    of htsExactFormat.crai:
      return FileType.CRAI
    else:
      return FileType.Unknown

proc open*(h:var HTSFile, path: string, mode:string="r"): bool {.discardable.} =
  ## open a file.
  h = HTSFile(kstr: kstring_t(l:0, m: 0, s: nil))
  h.p = hts_open(cstring(path), mode)
  if h.p == nil:
    raise newException(OSError, "[hts/files] couldn't open file at:" & path)
  result = true

proc close*(h: var HTSFile) =
  ## close the file. this is required for freeing up resources.
  free(h.kstr.s)
  discard hts_close(h.p)
  h.p = nil

iterator lines*(h: var HTSFile): string {.inline.} =
  ## iterate over lines in the file.
  while hts_getline(h.p, cint(10), h.kstr.addr) >= 0:
    yield $h.kstr.s

proc readLine*(h: var HTSFile, line: var string): bool {.inline.} =
  ## read a line into line. the return value indicates that there is more to read.
  var n = hts_getline(h.p, cint(10), h.kstr.addr)
  if n < 0:
    line.setLen(0)
    return false
  result = true
  line.setLen(n)
  for i in 0..<n:
    line[i] = h.kstr.s[i]

iterator hts_lines*(path:string, threads:int=1): string {.inline.} =
  ## yield lines from a file, it can be gzipped or regular file
  var h: HTSFile
  h.open(path, "r")
  discard hts_set_threads(h.p, cint(threads))

  while hts_getline(h.p, cint(10), h.kstr.addr) >= 0:
    yield $h.kstr.s
  h.close
