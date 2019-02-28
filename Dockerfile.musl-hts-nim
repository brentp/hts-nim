## This dockerfile
# 1. builds htslib and all dependencies currently without libcurl
# 2. installs nim
# 3. sets up a nim binary (nsb) that is expected to be called from an external binary (static_builder)
# These facilitate building static binaries for projects using hts-nim.

# docker build -t brentp/musl-hts-nim:latest -f Dockerfile.musl-hts-nim .
FROM alpine:3.9

ENV LDFLAGS=-static PKG_CONFIG='pkg-config --static'
ENV curl_LDFLAGS=-all-static

RUN apk add curl musl build-base git autoconf zlib-dev bzip2-dev xz-dev curl-dev

RUN cd / && \
    git clone -b devel --depth 10 git://github.com/nim-lang/nim nim && \
    cd nim && sh ./build_all.sh

RUN git clone --depth 1 https://github.com/ebiggers/libdeflate.git && \
    cd libdeflate && make -j 2 CFLAGS='-fPIC -O3' libdeflate.a && \
    cp libdeflate.a /usr/local/lib && cp libdeflate.h /usr/include && \
    cd .. && rm -rf libdeflate && \
    git clone https://github.com/samtools/htslib && \
    cd htslib && git checkout 1.9 && autoheader && autoconf && \
   ./configure --enable-plugins --disable-libcurl --with-libdeflate && \
   make -j4 install && \
   cd ../ && rm -rf htslib

ADD . /src/

ENV PATH=/root/.nimble/bin:/nim/bin/:$PATH

RUN cat /src/docker/docker.nim.cfg >> /nim/config/nim.cfg && \
    cd /src/ && nimble install -y && \
    nimble install -y docopt && \
    nimble install -y c2nim@#3ec45c24585ebaed && \
    nim c -o:/usr/local/bin/nsb /src/docker/nsb.nim && \
    rm -rf /src/
