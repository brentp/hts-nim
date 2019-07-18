FROM alpine:3.9

RUN apk add wget git xz bzip2 musl m4 autoconf tar xz-dev bzip2-dev build-base libpthread-stubs # gcc abuild binutils binutils-doc gcc-doc

RUN  \
    mkdir -p /usr/local/include && \
    git clone --depth 1 https://github.com/ebiggers/libdeflate.git && \
    cd libdeflate && make -j 2 CFLAGS='-fPIC -O3' libdeflate.a && \
    cp libdeflate.a /usr/local/lib && cp libdeflate.h /usr/local/include && \
    cd .. && rm -rf libdeflate && \
    git clone https://github.com/cloudflare/zlib cloudflare-zlib && \
    cd cloudflare-zlib && ./configure && make install && \
    cd .. && \
    rm -rf cloudflare-zlib


RUN \
    git clone https://github.com/samtools/htslib && \
    cd htslib && git checkout 1.9 && autoheader && autoconf && \
    ./configure --disable-s3 --disable-libcurl --with-libdeflate && \
    make -j4 CFLAGS="-fPIC -O3" install && \
    cd ../ && rm -rf htslib

RUN cd / && \
    git clone -b v0.20.0 git://github.com/nim-lang/nim nim && \
    cd nim && sh ./build_all.sh && \
    echo 'PATH=/nim/bin:$PATH' >> ~/.bashrc && \
    echo 'PATH=/nim/bin:$PATH' >> ~/.bash_profile && \
    echo 'PATH=/nim/bin:$PATH' >> /etc/environment 

ENV PATH=:/root/.nimble/bin:/nim/bin/:$PATH

ADD . /src/
RUN cat /src/docker/docker.nim.cfg >> /nim/config/nim.cfg && \
    source ~/.bashrc && cd /src/ && nimble install -y && \
    nimble install -y docopt && \
    nimble install -y c2nim@#3ec45c24585ebaed && \
    nim c -o:/usr/local/bin/nsb /src/docker/nsb.nim && \
    rm -rf /src/

