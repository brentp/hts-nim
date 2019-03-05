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
git clone --depth 1 https://github.com/nim-lang/nimble.git
cd nimble
nim c src/nimble
src/nimble install -y

cd
set -x
nimble refresh

echo $(which nimble)
echo $(pwd)


#git clone --depth 1 --recursive https://github.com/nim-lang/c2nim.git
#cd c2nim
#nimble install -y

cd

git clone --recursive https://github.com/samtools/htslib.git
cd htslib && git checkout 1.9 && autoheader && autoconf && ./configure --enable-libcurl

cd
make -j 4 -C htslib
export LD_LIBRARY_PATH=$HOME/htslib
ls -lh $HOME/htslib/*.so

cd $base
