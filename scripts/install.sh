#!/bin/bash

echo $(pwd)

export BRANCH=${BRANCH:-devel}
export base=$(pwd)

sudo apt-get -qy install bwa make build-essential cmake libncurses-dev ncurses-dev libbz2-dev lzma-dev liblzma-dev \
     curl  libssl-dev libtool autoconf automake libcurl4-openssl-dev

cd

if [ ! -x  nim-$BRANCH/bin/nim ]; then
  git clone -b $BRANCH --depth 1 git://github.com/nim-lang/nim nim-$BRANCH/
  cd nim-$BRANCH
  sh build_all.sh
else
  cd nim-$BRANCH
  git fetch origin
  if ! git merge FETCH_HEAD | grep "Already up-to-date"; then
    sh build_all.sh
  fi
fi

export PATH=$PATH:$HOME/nim-$BRANCH/bin/
echo $PATH
cd
set -x
nimble refresh

git clone --recursive https://github.com/samtools/htslib.git
cd htslib && git checkout 1.9 && autoheader && autoconf && ./configure --enable-libcurl

cd
make -j 4 -C htslib
export LD_LIBRARY_PATH=$HOME/htslib
ls -lh $HOME/htslib/*.so

cd $base
