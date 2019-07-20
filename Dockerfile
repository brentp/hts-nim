FROM alpine:3.10

ENV CFLAGS="-DCURL_STATICLIB -fPIC -O3"

RUN apk add wget git xz bzip2 musl m4 autoconf tar xz-dev bzip2-dev \
	    build-base libpthread-stubs libssh2-dev \
            openssl-dev nghttp2-static \
	    curl-dev curl-static libssh2-static && \
    mkdir -p /usr/local/include && \
    git clone --depth 1 https://github.com/ebiggers/libdeflate.git && \
    cd libdeflate && make -j 2 libdeflate.a && \
    cp libdeflate.a /usr/local/lib && cp libdeflate.h /usr/local/include && \
    cd .. && rm -rf libdeflate && \
    git clone https://github.com/cloudflare/zlib cloudflare-zlib && \
    cd cloudflare-zlib && ./configure && make install && \
    cd .. && \
    rm -rf cloudflare-zlib

RUN cd / && \
    git clone -b v0.20.2 git://github.com/nim-lang/nim nim && \
    cd nim && sh ./build_all.sh && \
    rm -rf csources && \
    echo 'PATH=/nim/bin:$PATH' >> ~/.bashrc && \
    echo 'PATH=/nim/bin:$PATH' >> ~/.bash_profile && \
    echo 'PATH=/nim/bin:$PATH' >> /etc/environment 

ENV PATH=/nim/bin:/root/.nimble/bin:$PATH

RUN \
    git clone https://github.com/samtools/htslib && \
    cd htslib && git checkout 1.9 && autoheader && autoconf && \
    CFLAGS="-fPIC -O3 -DCURL_STATICLIB" ./configure --enable-libcurl --with-libdeflate CFLAGS="-fPIC -O3 -DCURL_STATICLIB" && \
    make -j4 CFLAGS="-fPIC -O3 -DCURL_STATICLIB" install && \
    cd ../ && rm -rf htslib

#nimble install -y c2nim@#3ec45c24585ebaed && \
ADD . /src/
RUN cat /src/docker/docker.nim.cfg >> /nim/config/nim.cfg && \
    source ~/.bashrc && cd /src/ && nimble install -y && \
    nimble install -y docopt && \
    nimble install -y c2nim && \
    nimble install -y websocket@#head && \
    nim c -o:/usr/local/bin/nsb /src/docker/nsb.nim && \
    rm -rf /src/

