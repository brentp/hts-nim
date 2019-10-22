FROM alpine:3.10

ENV CFLAGS="-fPIC -O3"

RUN apk add wget git xz bzip2 musl m4 autoconf tar xz-dev bzip2-dev build-base libpthread-stubs libzip-dev

RUN mkdir -p /usr/local/include && \
    git clone --depth 1 https://github.com/ebiggers/libdeflate.git && \
    cd libdeflate && make -j4 CFLAGS="-fPIC -O3" install && \
    cd .. && rm -rf libdeflate && \
    git clone https://github.com/cloudflare/zlib cloudflare-zlib && \
    cd cloudflare-zlib && ./configure && make install && \
    cd .. && \
    rm -rf cloudflare-zlib

RUN cd / && \
    git clone -b v1.0.0 git://github.com/nim-lang/nim nim && \
    cd nim && sh ./build_all.sh && \
    rm -rf csources && \
    echo 'PATH=/nim/bin:$PATH' >> ~/.bashrc && \
    echo 'PATH=/nim/bin:$PATH' >> ~/.bash_profile && \
    echo 'PATH=/nim/bin:$PATH' >> /etc/environment 

ENV PATH=:/root/.nimble/bin:/nim/bin/:$PATH	

RUN \
    git clone https://github.com/samtools/htslib && \
    cd htslib && git checkout 1.9 && autoheader && autoconf && \
    ./configure --disable-s3 --disable-libcurl --with-libdeflate && \
    make -j4 CFLAGS="-fPIC -O3" install && \
    cd ../ && rm -rf htslib

ADD . /src/
RUN cat /src/docker/docker.nim.cfg >> /nim/config/nim.cfg && \
    source ~/.bashrc && cd /src/ && nimble install -y && \
    nimble install -y docopt && \
    nimble install -y c2nim && \
    nimble install -y websocket@#head && \
    nim c -o:/usr/local/bin/nsb /src/docker/nsb.nim && \
    rm -rf /src/

