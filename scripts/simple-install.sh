#!/bin/bash

export BRANCH=master
export base=$(pwd)

set -x

# for ubuntu these are needed for htslib
#sudo apt-get -qy install bwa make build-essential cmake libncurses-dev ncurses-dev libbz2-dev lzma-dev liblzma-dev \
#     curl  libssl-dev libtool autoconf automake libcurl4-openssl-dev

git clone -b $BRANCH --depth 1 git://github.com/nim-lang/nim nim-$BRANCH/
cd nim-$BRANCH
sh build_all.sh

cd $base
set -x
nimble refresh

echo "set PATH=$base/nim-$BRANCH/bin/":'$PATH' to have this in your path.
