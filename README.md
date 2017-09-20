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
var bam = open_hts("test/HG02002.bam", index=true)

for record in bam:
  if record.qual > 10:
    echo record.chrom, record.start, record.stop

# regional queries:
for record in bam.query('6', 30816675, 32816675):
  if record.flag.proper_pair and record.flag.reverse:
    # cigar is an iterable of operations:
    for op in record.cigar:
      # $op gives the string repr of the operation, e.g. '151M'
      echo $op, op.consumes.reference, op.consumes.query

# cram requires an fasta to decode:
var cram = open_hts("/tmp/t.cram", fai="/data/human/g1k_v37_decoy.fa")
for record in cram:
  echo record.qname, record.isize
```

## bgzip with csi

A nice thing that is facilitate through this library is creating a .csi index while writing sorted
intervals to a file.
This can be done as:

```nim
import hts
# arguments are 1-based seq-col, start-col, end-col and whether the intervals are 0-based.
var bx = wopen_bgzi("ti.txt.gz", 1, 2, 3, true)
# some duplication of args to avoid re-parsing. args are line, chrom, start, end
check bx.write_interval("a\t4\t10", "a", 4, 10) > 0
check bx.write_interval("b\t2\t20", "b", 2, 20) > 0
check bx.close() == 0
```

After this, `ti.txt.gz.csi` will be usable by tabix.
