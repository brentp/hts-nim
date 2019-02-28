hts-nim
=======

[![badge](https://img.shields.io/badge/docs-latest-blue.svg)](https://brentp.github.io/hts-nim/)

[![Build Status](https://travis-ci.org/brentp/hts-nim.svg?branch=master)](https://travis-ci.org/brentp/hts-nim)


This is a wrapper for [htslib](https://github.com/samtools/htslib) in [nim](https://nim-lang.org). 

Nim is a fast, garbage-collected language that compiles to C and has a syntax that's not
too different to python.

If you use this library, please cite [the paper](https://academic.oup.com/bioinformatics/advance-article-abstract/doi/10.1093/bioinformatics/bty358/4990493)

This library is under active development. Though it's been in use for some time and I have
been using it nearly every day for script-like tasks, the API may change. If it does, old
methods will be deprecated so users have time to update.

## Installation

See Section Below

# Usage

Examples of `hts-nim` tools are available in the [hts-nim-tools repo](https://github.com/brentp/hts-nim-tools)

below are examples of the syntax in this library see the [docs](https://brentp.github.io/hts-nim/) for more info:

Also see examples and other repos using hts-nim in the [wiki](https://github.com/brentp/hts-nim/wiki/Examples)

## BAM / CRAM / SAM

```nim
import hts

# open a bam and look for the index.
var b:Bam
open(b, "tests/HG02002.bam", index=true)

for record in b:
  if record.mapping_quality > 10u:
    echo record.chrom, record.start, record.stop

# regional queries:
for record in b.query("6", 30816675, 32816675):
  if record.flag.proper_pair and record.flag.reverse:
    # cigar is an iterable of operations:
    for op in record.cigar:
      # $op gives the string repr of the operation, e.g. '151M'
      echo $op, " ", op.consumes.reference, " ", op.consumes.query

    # tags are pulled by type `ta`
    var mismatches = tag[int](record, "NM")
    if mismatches.isNone: continue
    if mismatches.get < 3:
      var rg = tag[string](record, "RG")
      if rg.isNone: continue
      echo rg.get

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
import unittest  # Enable the check statement

var tsamples = @["101976-101976", "100920-100920", "100231-100231", "100232-100232", "100919-100919"]

# VCF and BCF supported
var v:VCF
doAssert(open(v, "tests/test.bcf", samples=tsamples))

var afs = new_seq[float32](5) # size doesn't matter. this will be re-sized as needed
var acs = new_seq[int32](5) # size doesn't matter. this will be re-sized as needed
var csq = new_string_of_cap(20)
for rec in v:
  echo rec, " qual:", rec.QUAL, " filter:", rec.FILTER
  var info = rec.info
  # accessing stuff from the INFO field is meant to be as fast as possible, allowing
  # the user to re-use memory as needed.
  info.get("CSQ", csq) # string
  info.get("AC", acs) # ints
  info.get("AF", afs) # floats
  echo acs, afs, csq, info.has_flag("IN_EXAC")

  # accessing format fields is similar
  var format = rec.format
  var dps = new_seq[int32](len(v.samples))
  doAssert(format.ints("DP", dps))
  echo dps

echo v.samples

# open a VCF for writing
var wtr:VCF
doAssert(open(wtr, "tests/outv.vcf", mode="w"))
# set and write the header.
wtr.header = v.header
doAssert(wtr.write_header())

# regional queries look for index. works for VCF and BCF
for rec in v.query("1:15600-18250"):
  echo rec.CHROM, ":", $rec.POS
  # adjust some values in the INFO
  var val = 22.3
  check rec.info.set("VQSLOD", val) == Status.OK
  doAssert(wtr.write_variant(rec))

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

In all cases, it's recommended to use nim version 0.18.0 or more recent.

Then, from this repo you can run `nimble test` and `nimble install` and then you can save the above snippets into `some.nim`
and run them with `nim c -d:release -r some.nim`. This will run them and save an executable named `some`.

## Static Builds

`hts-nim` is meant to simplify and speed development and distribution. To that end, there is some machinery to help create
truly static binaries for linux from nim-projects and for simple nim scripts. This means that there is no dependency on libhts.so. These builds only require docker and [this static binary XXX TODO](https://github.com/brentp/slivar/releases).

For a single file application that does not have a nimble file we can specify the dependencies using `--deps`:

```
hts_nim_static_builder -s vcf_cleaner.nim --deps "hts@>=0.2.7" --deps "binaryheap"
```

This will create a static binary at `./vcf_cleaner`.



Projects with `.nimble` files can use that directly to indicate dependencies.
For example, to build [slivar](https://github.com/brentp/slivar), we can do:

```
hts_nim_static_builder -s ../slivar/src/slivar.nim -n ../slivar/slivar.nimble
```

After this finishes, a static `slivar` binary will appear in the current working directory.

We can verify that it is static using:

```
$ file ./slivar 
./slivar: ELF 64-bit LSB executable, x86-64, version 1 (GNU/Linux), statically linked, for GNU/Linux 2.6.18, BuildID[sha1]=c2b5b52cb7be7f81bf90355a4e44a08a08df91d8, not stripped
```

The [docker image](https://hub.docker.com/r/brentp/musl-hts-nim) is based on alpine linux and uses musl to create truly static binaries.
At this time, libcurl is not supported so only binaries built using this method will only be able to access local files (no http/https/s3/gcs).

The docker images does use [libdeflate](https://github.com/ebiggers/libdeflate) by default. That provides,
for example, a 20% speed improvement when used to build [mosdepth](https://github.com/brentp/mosdepth).
