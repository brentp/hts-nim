#!/bin/bash

echo $(pwd)

export BRANCH=${BRANCH:-devel}
export base=$(pwd)

sudo apt-get -qy install bwa make build-essential cmake libncurses-dev ncurses-dev libbz2-dev lzma-dev liblzma-dev \
     curl  libssl-dev libtool autoconf automake libcurl4-openssl-dev

cd

git clone -b $BRANCH --depth 5 https://github.com/nim-lang/nim nim-$BRANCH/
cd nim-$BRANCH
sh build_all.sh

export PATH=$PATH:$HOME/nim-$BRANCH/bin/
echo $PATH
cd
set -x
nimble refresh

git clone --recursive https://github.com/samtools/htslib.git
cd htslib && git checkout 1.10 && autoheader && autoconf && ./configure --enable-libcurl

cd
make -j 4 -C htslib
export LD_LIBRARY_PATH=$HOME/htslib
ls -lh $HOME/htslib/*.so

cd $base
