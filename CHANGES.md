v0.3.19
=======
+ [vcf] allow using `vcf.set_samples(@["^"])` to remove all samples

v0.3.18
=======
+ [vcf] fix for #77 for to avoid double-free of header when it's re-used.

v0.3.17
=======
+ turn quits into exceptions

v0.3.16
=======
+ expose VCF.fname
+ change rendering of unknown alleles to fix './.'

v0.3.15
=======
+ vcf: expose a couple more functions from htslib

v0.3.14
=======
+ add close method to fai for consistency (continues to also occur automatically upon garbage collection) #70

v0.3.13
=======
+ changes for nim ORC/ARC GCs

v0.3.11
=======
+ add bgzi.open which allows opening for reading and writing without quit() and replaces
  `wopen_bgzi` and `ropen_bgzi`

v0.3.9
======
+ add `newCigar(els: seq[CigarElement]): Cigar` (#9)

v0.3.8
======
+ flush stdout on destroy_vcf

v0.3.7
======
+ fix bai creation in `xam_index`

v0.3.6
======
+ automatically set cram or bam file-type for file opened in write mode based
  on file extension (#64)

v0.3.5
======
+ add `xam_index` to index bam and cram files.

v0.3.4
======
+ hts/vcf Variant.alts will report sum of known alt alleles for ploidy greater than 2.

v0.3.3
======
+ report contig length if available in vcf.contigs (#51)

v0.3.2
======
+ allow specifying `"*"` or `"-3"` for the chromosome in vcf.query to iterator over   entire file.

v0.3.1
======
+ fix off-by-one error. (brentp/mosdepth#98)

v0.3.0
======
+ **breaking change** update to htslib 1.10. this is a breaking change and will
  require htslib 1.10 or higher. if hts-nim detects a version of < 1.10, it will generate an error
+ add htslibVersion() function which returns a string of the version reported by htslib
+ bam/Target is no longer a ref object (this will affect almost noone)


v0.2.23
=======
+ hts/bam fix from_string for bam record and header. See quinlan-lab/STRling#10
+ hts/files add fname.file_type to get the file type given a path

v0.2.22
=======
+ changes for latest nim
+ fix several memory leaks in rarely-used functions

v0.2.21
=======
+ hts/vcf allow setting id.
+ hts/vcf flush stdout on close.
+ hts/bam correct check for EOF (#48)
+ hts/bam better error message for error in interation

v0.2.20
=======
+ hts/files (iterate over bgzipped or text files identically)

v0.2.16
=======
+ [bam] add `set_qname`

v0.2.14
=======
+ [vcf] add format.delete to delete format (sample) fields from vcf records.
v0.2.12
=======
+ [bam] optimize cigar. had extra calls and memory-use.

v0.2.11
=======
+ [vcf] more lazy about unpack; gives some performance improvement
+ [vcf] use pointer size to allow better memory re-use.

0.2.9
=====
+ [vcf] unpack after copy. this was causing hard-to-diagnose problems whenever Variant.copy was used.

0.2.8
=====
+ [vcf] allow writing from a VCF that does not contain contigs (in htslib this is an error)
+ [vcf] fix bug in getting (absent) string arguments from INFO.

v0.2.7
======
+ [vcf] remove deprecated FORMAT (ints, floats) and INFO (ints, floats, strings)
+ [vcf] add FORMAT.get, set(field, strings) to get and set string fields from FORMAT fields
+ [vcf] add FORMAT.fields to iterate for the FORMAT field of a VCF, the returned FormatField
        type tells the name, (v)type and number of values per sample of each field.

v0.2.5
======
+ [vcf] deprecate ints, strings, floats in favor of dispatch to `get` for both INFO and FORMAT.
