## hts-nim

`hts-nim` is a [nim](https://nim-lang.org) language wrappper for [htslib](https://htslib.org).
It provides high-level abstractions that enable terse, performantcode. `hts-nim` also provides a means to create static binaries to ease distribution of executables.

[Here](https://github.com/brentp/hts-nim/wiki/Examples) is a list of repositories that utilize hts-nim (https://github.com/brentp/hts-nim/wiki/Examples)

If you use this library, please cite the [paper](https://academic.oup.com/bioinformatics/advance-article-abstract/doi/10.1093/bioinformatics/bty358/4990493)

## Setup / Installation

`hts-nim` requires that [htslib](https://htslib.org) is installed and the shared library is available (use `LD_LIBRARY_PATH` if it is not in a standard location).

If you use docker, you can use one of [these images](https://hub.docker.com/r/nimlang/nim/) for nim.

Or you can copy the [Dockerfile from this repo](https://github.com/brentp/hts-nim/blob/master/Dockerfile)

If you don't use docker, you can use [choosenim](https://github.com/dom96/choosenim) to quickly install Nim and nimble.

Users can also either follow or run [scripts/simple-install.sh](https://github.com/brentp/hts-nim/blob/master/scripts/simple-install.sh)
which sets up Nim and nimble ready for use and shows the needed adjustments to $PATH.

Once Nim is set up, `hts-nim` can be installed with `nimble install -y` from the root of this repository.

In all cases, it's recommended to use nim version 0.20.0 or more recent.

Then, from this repo you can run `nimble test` and `nimble install` and then `hts` will be available for import in your nim environment.


## modules


## Static Builds

`hts-nim` is meant to simplify and speed development and distribution. To that end, there is some machinery to help create
truly static binaries for linux from nim-projects and for simple nim scripts.
This means that there is **no dependency on libhts.so**.
Building a static binary requires docker and [this static binary](https://github.com/brentp/hts-nim/releases/download/v0.2.8/hts_nim_static_builder).

For a single file application that does not have a nimble file we can specify the dependencies using `--deps`:

```
hts_nim_static_builder -s vcf_cleaner.nim --deps "hts@>=0.3.0" --deps "binaryheap"
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

