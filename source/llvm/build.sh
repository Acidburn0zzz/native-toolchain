#!/bin/bash
# Copyright 2012 Cloudera Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -eu

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then

  if [[ $PACKAGE_VERSION = "trunk" ]]; then
    . $SOURCE_DIR/source/llvm/build-trunk.sh
    cd $SOURCE_DIR/source/llvm
    build_trunk
  else
    header $PACKAGE $PACKAGE_VERSION
    LLVM=llvm-$LLVM_VERSION

    # Cleanup possible leftovers
    rm -Rf build-$LLVM
    rm -Rf $LLVM.src

    # Crappy CentOS 5.6 doesnt like us to build Clang, so skip it
    RELEASE_NAME=`lsb_release -r -i`
    cd tools
    # CLANG
    tar zxf ../../cfe-$LLVM_VERSION.src.tar.gz
    mv cfe-$LLVM_VERSION.src clang

    # CLANG Extras
    cd clang/tools
    tar zxf ../../../../clang-tools-extra-$LLVM_VERSION.src.tar.gz
    mv clang-tools-extra-$LLVM_VERSION.src extra
    cd ../../

    # COMPILER RT
    cd ../projects
    tar zxf ../../compiler-rt-$LLVM_VERSION.src.tar.gz
    mv compiler-rt-$LLVM_VERSION.src compiler-rt
    cd ../../

    mkdir -p build-$LLVM
    cd build-$LLVM

    # Some ancient systems have another python installed
    PY_VERSION=`python -V 2>&1`
    EXTRA_CONFIG_ARG=
    if [[ "$PY_VERSION" =~ "Python 2\.4\.." ]]; then
      # Typically on the systems having Python 2.4, they have a separate install
      # of Python 2.6 wiht a python26 executable. However, this is not generally
      # true for all platforms.
      EXTRA_CONFIG_ARG=--with-python=`which python26`
    fi

    wrap ../$LLVM.src/configure $EXTRA_CONFIG_ARG --enable-targets=x86_64,cpp --enable-optimized --enable-terminfo=no --prefix=$LOCAL_INSTALL --with-pic --with-gcc-toolchain=$BUILD_DIR/gcc-$GCC_VERSION --with-extra-ld-options="$LDFLAGS"

    wrap make -j${BUILD_THREADS:-4} REQUIRES_RTTI=1 install

    # Do not forget to install clang as well
    cd tools/clang
    wrap make -j${BUILD_THREADS:-4} REQUIRES_RTTI=1 install

    footer $PACKAGE $PACKAGE_VERSION
  fi
fi
