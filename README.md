hts-nim
=======

[![badge](https://img.shields.io/badge/docs-latest-blue.svg)](https://brentp.github.io/hts-nim/)

[![Build Status](https://travis-ci.org/brentp/hts-nim.svg?branch=master)](https://travis-ci.org/brentp/hts-nim)


This is a wrapper for [htslib](https://github.com/samtools/htslib) in [nim](https://nim-lang.org). 

Nim is a fast, garbage-collected language that compiles to C and has a syntax that's not
too different to python.

This library is under active development. Though it's been in use for some time and I have
been using it nearly every day for script-like tasks, the API may change. If it does, old
methods will be deprecated so users have time to update.

## Installation

See Section Below

# Usage

Examples of `hts-nim` tools are available in the [hts-nim-tools repo](https://github.com/brentp/hts-nim-tools)

below are examples of the syntax in this library see the [docs](https://brentp.github.io/hts-nim/) for more info:

## BAM / CRAM / SAM

```nim
import hts

# open a bam and look for the index.
var b:Bam
open(b, "tests/HG02002.bam", index=true)

for record in b:
  if record.qual > 10u:
    echo record.chrom, record.start, record.stop

# regional queries:
for record in b.query("6", 30816675, 32816675):
  if record.flag.proper_pair and record.flag.reverse:
    # cigar is an iterable of operations:
    for op in record.cigar:
      # $op gives the string repr of the operation, e.g. '151M'
      echo $op, op.consumes.reference, op.consumes.query

    # tags are pulled with `aux`
    var mismatches = rec.aux("NM")
    if mismatches != nil and mismatches.asInt.get < 3:
      var rg = rec.aux("RG")
      echo rg.asString

# cram requires an fasta to decode:
var cram:Bam
open(cram, "/tmp/t.cram", fai="/data/human/g1k_v37_decoy.fa")
for record in cram:
  # now record is same as from bam above
  echo record.qname, record.isize
```

## VCF / BCF

```nim
import hts

var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]

# VCF and BCF supported
var v:VCF
assert open(v, "tests/test.bcf", samples=tsamples)

var afs = new_seq[float32](5) # size doesn't matter. this will be re-sized as needed
var acs = new_seq[int32](5) # size doesn't matter. this will be re-sized as needed
var csq = new_string_of_cap(20)
for rec in v:
  echo rec, " qual:", rec.QUAL, " filter:", rec.FILTER
  var info = rec.info
  # accessing stuff from the INFO field is meant to be as fast as possible, allowing
  # the user to re-use memory as needed.
  info.strings("CSQ", csq)
  info.ints("AC", acs)
  info.floats("AF", afs)
  echo acs, afs, csq, info.has_flag("IN_EXAC")

  # accessing format fields is similar
  var format = ref.format
  var dps = new_seq[int32](len(v.samples))
  assert format.ints("DP", dps)
  echo dps

echo v.samples

# open a VCF for writing
var wtr:VCF
open(wtr, "tests/outv.vcf", mode="w")
# set and write the header.
wtr.header = v.header
assert wtr.write_header()

# regional queries look for index. works for VCF and BCF
for rec in v.query("1:15600-18250"):
  echo rec.CHROM, ":", $rec.POS
  # adjust some values in the INFO
  var val = 22.3
  check rec.info.set("VQSLOD", val) == Status.OK
  assert wtr.write_variant(rec)

  check rec.info.delete("CSQ") == Status.OK

wtr.close()
```

## bgzip with csi

A nice thing that is facilitated with this library is creating a .csi index while writing sorted
intervals to a file.  This can be done as:

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


## Setup / Installation

`hts-nim` requires that [htslib](https://github.com/samtools/htslib) is installed and the shared library is available
(use `LD_LIBRARY_PATH` if it is not in a standard location).


If you use docker, you can use one of [these images](https://hub.docker.com/r/nimlang/nim/) to get Nim installed.

Or you can copy the [Dockerfile from this repo](https://github.com/brentp/hts-nim/blob/master/Dockerfile)

If you don't use docker, you can use [choosenim](https://github.com/dom96/choosenim) to quickly install Nim and nimble.

Users can also either follow or run [scripts/simple-install.sh](https://github.com/brentp/hts-nim/blob/master/scripts/simple-install.sh) which sets up Nim and nimble ready for use and shows the needed adjustments to `$PATH`.

Once Nim is set up, `hts-nim` can be installed with `nimble install -y` from the root of this repository.

In all cases, it's recommended to use **nim version 0.17.2** which is the latest release.

Then, from this repo you can run `nimble test` and `nimble install` and then you can save the above snippets into `some.nim`
and run them with `nim c -d:release -r some.nim`. This will run them and save an executable named `some`.
