hts-nim
=======

[![badge](https://img.shields.io/badge/docs-latest-blue.svg)](https://brentp.github.io/hts-nim/)


This is a wrapper for [htslib](https://github.com/samtools/htslib) in [nim](https://nim-lang.org). 

Nim is a fast, garbage collected language that compiles to C and has a syntax that's not
too different to python.

Here is an example of the syntax in this library:

```nim
import hts

# open a bam and look for the index.
var bam = Open("test/HG02002.bam", index=true)

# iterate over the bam:

for record in bam:
  if record.qual > 10:
    echo record.chrom, record.start, record.stop

# regional queries:
for record in bam.query('6', 30816675, 32816675):
  if record.flag.proper_pair and record.flag.reverse:
    # cigar is an iterable of operations:
    for op in record.cigar:
      # $op gives the string repr of the operation, e.g. '151M'
      echo $op, op.consumes_reference, op.consumes_query

# cram requires an fasta to decode:
var cram = Open("/tmp/t.cram", fai="/data/human/g1k_v37_decoy.fa")
for record in cram:
  echo record.qname, record.isize
```
