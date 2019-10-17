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
