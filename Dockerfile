## this docker file is based on a relatively old setup so that libc dependencies
## should not be a problem. It:
# 1. builds htslib and all dependencies currently without libcurl
# 2. installs nim
# 3. sets up a nim binary (nsb) that is expected to be called from an external binary (static_builder)
# These facilitate building static binaries for projects using hts-nim.

FROM alpine:3.9

RUN apk add curl musl build-base git autoconf \
      zlib-dev bzip2-dev xz-dev curl-dev

RUN cd / && \
    git clone -b devel --depth 10 git://github.com/nim-lang/nim nim && \
    cd nim && sh ./build_all.sh

RUN git clone https://github.com/samtools/htslib && \
    cd htslib && git checkout 1.9 && autoheader && autoconf && \
   ./configure --enable-s3 --enable-libcurl && \
   make -j4 install && \
   cd ../ && rm -rf htslib

ADD . /src/

ENV PATH=/root/.nimble/bin:/nim/bin/:$PATH
ENV curl_LDFLAGS=-all-static

RUN cat /src/docker/docker.nim.cfg >> /nim/config/nim.cfg && \
    cd /src/ && nimble install -y && \
    nimble install -y docopt && \
    nimble install -y c2nim@#3ec45c24585ebaed && \
    nim c -o:/usr/local/bin/nsb /src/docker/nsb.nim && \
    rm -rf /src/
