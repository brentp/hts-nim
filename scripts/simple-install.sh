#!/bin/bash

export BRANCH=master
export base=$(pwd)

set -x

# for ubuntu these are needed for htslib
#sudo apt-get -qy install bwa make build-essential cmake libncurses-dev ncurses-dev libbz2-dev lzma-dev liblzma-dev \
#     curl  libssl-dev libtool autoconf automake libcurl4-openssl-dev

git clone -b $BRANCH --depth 1 git://github.com/nim-lang/nim nim-$BRANCH/
cd nim-$BRANCH
git clone --depth 1 git://github.com/nim-lang/csources csources/
cd csources
sh build.sh
cd ..
rm -rf csources
bin/nim c koch
./koch boot -d:release

export PATH=$PATH:$base/nim-$BRANCH/bin/:$PATH:$base/nimble/src
echo $PATH

cd $base
git clone --depth 1 https://github.com/nim-lang/nimble.git
cd nimble
nim c src/nimble
src/nimble install -y

cd $base
set -x
nimble refresh

echo "set PATH=$base/nim-$BRANCH/bin/:$base/nimble/src:"'$PATH' to have this in your path.
