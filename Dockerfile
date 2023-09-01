FROM alpine:3.11.5
#FROM alpine:20190925

ARG nim_version=1.6.6


ENV CFLAGS="-fPIC -O3"

RUN apk update && apk upgrade && apk add wget git xz bzip2-static musl m4 autoconf tar xz-dev bzip2-dev build-base libpthread-stubs libzip-dev gfortran \
    openssl-libs-static openblas-static pcre-dev curl llvm-dev curl-static bash curl-dev clang-static nghttp2-static  zlib-static cmake

RUN mkdir -p /usr/local/include && \
    git clone -b v1.18 --depth 1 https://github.com/ebiggers/libdeflate.git && \
    cd libdeflate && cmake -B build && cmake --build build && cmake --install build  && \
    ln -s /usr/local/lib64/* /usr/local/lib && \
    cd .. && rm -rf libdeflate

RUN cd / && \
    wget -q https://nim-lang.org/download/nim-${nim_version}-linux_x64.tar.xz && \
    tar xf nim-${nim_version}-linux_x64.tar.xz && \
    echo 'PATH=/nim-${nim_version}/bin:$PATH' >> ~/.bashrc && \
    echo 'PATH=/nim-${nim_version}/bin:$PATH' >> ~/.bash_profile && \
    echo 'PATH=/nim-${nim_version}/bin:$PATH' >> /etc/environment  && \
    rm -f nim-${nim_version}-linux_x64.tar.xz

RUN apk add cmake openssl-dev && \
	wget https://libzip.org/download/libzip-1.6.1.tar.gz && \
	tar xzvf libzip-1.6.1.tar.gz && \
	cd libzip-1.6.1 && \
	mkdir build && cd build && \
	cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/usr/local/ ../ && \
	make -j4 CFLAGS="-fPIC -O3" install && \
	cd ../../ && rm -rf libzip-1.6.1*


ENV PATH=:/root/.nimble/bin:/nim-${nim_version}/bin/:$PATH	

RUN \
    git clone --depth 1 -b 1.18 --recursive https://github.com/samtools/htslib && \
    cd htslib && autoheader && autoconf && \
    ./configure --enable-s3 --enable-gcs --enable-libcurl --with-libdeflate && \
    make -j4 CFLAGS="-fPIC -O3" install && \
    cd ../ && \
    git clone --depth 1 -b 1.18 --recursive https://github.com/samtools/bcftools && \
    cd bcftools && autoheader && autoconf && \
    ./configure --enable-s3 --enable-libcurl --with-libdeflate && \
    make -j4 CFLAGS="-fPIC -O3" install && \
    cd ../ && rm -rf htslib bcftools

ENV RUSTFLAGS=-Ctarget-feature=-crt-static

RUN sh -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -q -y' \
    && ~/.cargo/bin/rustup target add x86_64-unknown-linux-musl \
	&& git clone https://github.com/38/d4-format \
	&& cd d4-format \
    && ln -s /usr/bin/gcc /usr/bin/musl-gcc \
    && ~/.cargo/bin/cargo build --package=d4binding --release && cd .. \
    && install -m 644 d4-format/target/release/libd4binding.a /usr/lib \
	&& install -m 644 d4-format/d4binding/include/d4.h /usr/include  \
    && rm -rf d4-format/target/  \
    && rm -rf /root/.rustup/  \
    && rm -rf ~/.cargo 
    
ADD . /src/
RUN cat /src/docker/docker.nim.cfg >> /nim-${nim_version}/config/nim.cfg && \
    cd /src/ && nimble install -y && \
    nimble install -y c2nim docopt && \
    nimble install -y websocket@#head && \
    nim c -o:/usr/local/bin/nsb /src/docker/nsb.nim && \
    rm -rf /src/
