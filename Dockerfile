## this docker file is based on a relatively old setup so that libc dependencies
## should not be a problem. It:
# 1. builds htslib and all dependencies currently without libcurl
# 2. installs nim
# 3. sets up a nim binary (nsb) that is expected to be called from an external binary (static_builder)
# These facilitate building static binaries for projects using hts-nim.

# docker build -t brentp/hts-nim:latest -f Dockerfile .
FROM centos:centos6

RUN yum install -y git curl wget xz-devel bzip2-devel libcurl-devel && \
    wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtools-2.repo && \
    yum install -y devtoolset-2-gcc devtoolset-2-binutils devtoolset-2-gcc-c++ lzma-devel glibc-static && \
    source scl_source enable devtoolset-2 && \
    echo "source scl_source enable devtoolset-2" >> ~/.bashrc && \
    echo "source scl_source enable devtoolset-2" >> ~/.bash_profile && \
    wget --quiet https://ftp.gnu.org/gnu/m4/m4-1.4.18.tar.gz && \
    tar xzf m4-1.4.18.tar.gz && cd m4* && ./configure && make && make install && cd .. && \
    rm -rf m4* && \
    wget --quiet http://ftp.gnu.org/gnu/autoconf/autoconf-2.69.tar.gz && \
    tar xzf autoconf-2.69.tar.gz && \
    cd autoconf* && ./configure && make && make install && cd .. && rm -rf autoconf* && \
    git clone --depth 1 https://github.com/ebiggers/libdeflate.git && \
    cd libdeflate && make -j 2 CFLAGS='-fPIC -O3' libdeflate.a && \
    cp libdeflate.a /usr/local/lib && cp libdeflate.h /usr/local/include && \
    cd .. && rm -rf libdeflate && \
    wget --quiet http://http.debian.net/debian/pool/main/b/bzip2/bzip2_1.0.6.orig.tar.bz2 && \
    tar xjvf bzip2_1.0.6.orig.tar.bz2 && \
    cd bzip2-1.0.6 && \
    make -j2 install && \
    cd ../ && \
    rm -rf bzip2-* && \
    git clone https://github.com/cloudflare/zlib cloudflare-zlib && \
    cd cloudflare-zlib && ./configure && make install && \
    cd .. && \
    rm -rf cloudflare-zlib && \
    wget --quiet https://tukaani.org/xz/xz-5.2.4.tar.bz2 && \
    tar xjf xz-5.2.4.tar.bz2 && \
    cd xz-5.2.4 && \
    ./configure && \
    make -j4 install && \
    cd .. && \
    rm -r xz*


RUN source scl_source enable devtoolset-2 && \
    cd / && \
    wget --quiet http://www.musl-libc.org/releases/musl-1.1.21.tar.gz && \
    tar xvf musl-1.1.21.tar.gz && \ 
    cd musl-1.1.21 && \ 
    ./configure && \
    make -j4 install && \
    rm -rf musl-*


RUN source scl_source enable devtoolset-2 && \
    cd / && \
    wget --quiet https://www.openssl.org/source/openssl-1.1.1b.tar.gz && \
    tar xzvf openssl-1.1.1b.tar.gz && \
    cd openssl-1.1.1b && \
    ./config && \
    make install && cd ../ && rm -rf openssl-1.1.1b


RUN cd / && \
    git clone -b devel --depth 10 git://github.com/nim-lang/nim nim && \
    cd nim && \
    chmod +x ./build_all.sh && \
    scl enable devtoolset-2 ./build_all.sh && \
    echo 'PATH=/nim/bin:$PATH' >> ~/.bashrc && \
    echo 'PATH=/nim/bin:$PATH' >> ~/.bash_profile && \
    echo 'PATH=/nim/bin:$PATH' >> /etc/environment

RUN source scl_source enable devtoolset-2 && \
    wget --quiet https://c-ares.haxx.se/download/c-ares-1.15.0.tar.gz && \
    tar xzf c-ares-1.15.0.tar.gz && \
    cd c-ares-1.15.0 && \
    LIBS="-lrt"  LDFLAGS="-Wl,--no-as-needed -static" ./configure --enable-static && \
    make LDFLAGS="-Wl,--no-as-needed -all-static -lrt -lssl -lcrypto -lc" -j4 install && \
    cd .. && \
    rm -rf c-ares-1.15.0* && \
    wget --quiet https://curl.haxx.se/download/curl-7.64.0.tar.gz && \
    tar xzf curl-7.64.0.tar.gz && \
    cd curl-7.64.0 && \
    LIBS="-ldl -lpthread -lrt -lssl -lcrypto -lcares -ldl -lc" LDFLAGS="-Wl,--no-as-needed -static" PKG_CONFIG="pkg-config --static" ./configure --disable-shared --enable-static --disable-ldap --with-ssl=/usr/local/ --disable-sspi --without-librtmp --disable-ftp --disable-file --disable-dict --disable-telnet --disable-tftp --disable-rtsp --disable-pop3 --disable-imap --disable-smtp --disable-gopher --disable-smb --without-libidn --enable-ares && \
    make curl_LDFLAGS=-all-static LDFLAGS="-Wl,--no-as-needed -all-static -lrt -lssl -lcrypto -lcares -ldl -lc" -j4 install && \
    cd ../ && \
    rm -rf curl-7.64.0*


RUN source scl_source enable devtoolset-2 && \
    git clone https://github.com/samtools/htslib && \
    cd htslib && git checkout 1.9 && autoheader && autoconf && \
    ./configure --enable-s3 --enable-libcurl --with-libdeflate && \
    make LDFLAGS="-Wl,--no-as-needed -lrt -lssl -lcrypto -ldl -lcares -lc" -j4 CFLAGS="-fPIC -O3 -lcrypto" install && \
    echo "/usr/local/lib" >> /etc/ld.so.conf && \
    ldconfig && \
    cd ../ && rm -rf htslib


ENV PATH=:/root/.nimble/bin:/nim/bin/:$PATH:/opt/rh/devtoolset-2/root/usr/bin/

ADD . /src/
RUN cat /src/docker/docker.nim.cfg >> /nim/config/nim.cfg && \
    echo "source scl_source enable devtoolset-2" >> /etc/environment && \
    source ~/.bashrc && cd /src/ && nimble install -y && \
    nimble install -y docopt && \
    nimble install -y c2nim@#3ec45c24585ebaed && \
    nim c -o:/usr/local/bin/nsb /src/docker/nsb.nim && \
    rm -rf /src/
