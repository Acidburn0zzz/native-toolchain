#!/usr/bin/env bash
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

# cleans and rebuilds thirdparty/. The Impala build environment must be set up
# by bin/impala-config.sh before running this script.

# Exit on non-true return value
set -e
# Exit on reference to uninitialized variable
set -u

set -o pipefail

: ${DEBUG=0}
: ${FAIL_ON_PUBLISH=0}
: ${PUBLISH_DEPENDENCIES=0}

if [[ $DEBUG -eq 1 ]]; then
  set -x
fi
export DEBUG
export FAIL_ON_PUBLISH
export PUBLISH_DEPENDENCIES

export BUILD_THREADS=`grep -c ^processor /proc/cpuinfo`

# SOURCE DIR for the current script
export SOURCE_DIR="$( cd "$( dirname "$0" )" && pwd )"

# Load all common version numbers for the thirdparty dependencies
source $SOURCE_DIR/platform.sh

export TOOLCHAIN_DEST_PATH=/opt/cloudera-bin-toolchain

# Clean the complete build
: ${CLEAN=0}

if [ $CLEAN -eq 1 ]; then
  echo "Cleaning.."
  git clean -fdx $SOURCE_DIR
fi

# Destination directory for build
mkdir -p $SOURCE_DIR/build
export BUILD_DIR=$SOURCE_DIR/build

# Create a check directory containing a sentry file for each package
mkdir -p $SOURCE_DIR/check

# Flag to determine the system compiler is used
: ${SYSTEM_GCC=0}

if [[ $SYSTEM_GCC -eq 0 ]]; then
  export COMPILER="gcc"
  export COMPILER_VERSION=$GCC_VERSION
else
  export COMPILER="gcc"
  export COMPILER_VERSION="system"
fi

# Check Platform
if [[ "$OSTYPE" =~ ^linux ]]; then
  export RELEASE_NAME=`lsb_release -r -i`
elif [[ "$OSTYPE" == "darwin"* ]]; then
  export RELEASE_NAME="OSX-$(sw_vers -productVersion)"
  export DARWIN_VERSION=`sw_vers -productVersion`
  export MACOSX_DEPLOYMENT_TARGET=$(echo $DARWIN_VERSION| sed -E 's/(10.[0-9]+).*/\1/')
fi

# Load functions
source $SOURCE_DIR/functions.sh

# Build the package to $BUILD_DIR directory with the given version
TOOLCHAIN_PREFIX="/opt/bin-toolchain"

# Append compiler and version to toolchain path
export TOOLCHAIN_PREFIX="${TOOLCHAIN_PREFIX}/${COMPILER}-${COMPILER_VERSION}"

if [[ $SYSTEM_GCC -eq 0 ]]; then
  # Now, start building the compilers first
  # Build GCC that is used to build LLVM
  $SOURCE_DIR/source/gcc/build.sh

  # Stage one is done, we can upgrade our compiler
  export CC="$BUILD_DIR/gcc-$GCC_VERSION/bin/gcc"
  export CXX="$BUILD_DIR/gcc-$GCC_VERSION/bin/g++"

  # Update the destination path for the toolchain
  export TOOLCHAIN_DEST_PATH="${TOOLCHAIN_DEST_PATH}/${COMPILER}-${COMPILER_VERSION}"


  # Upgrade rpath variable to catch current library location and possible future location
  if [[ "$OSTYPE" == "darwin"* ]]; then
    FULL_RPATH="-Wl,-rpath,$BUILD_DIR/gcc-$GCC_VERSION/lib,-rpath,'\$ORIGIN/../lib',"
  else
    FULL_RPATH="-Wl,-rpath,$BUILD_DIR/gcc-$GCC_VERSION/lib64,-rpath,'\$ORIGIN/../lib64',"
  fi
  FULL_RPATH="${FULL_RPATH}-rpath,'$TOOLCHAIN_DEST_PATH/gcc-$GCC_VERSION'"
  FULL_RPATH="${FULL_RPATH},-rpath,'\$ORIGIN/../lib'"

  FULL_LPATH="-L$BUILD_DIR/gcc-$GCC_VERSION/lib64"
  export LDFLAGS="$FULL_RPATH $FULL_LPATH"
  export CXXFLAGS="-static-libstdc++ -fPIC -O3 -m64 -mtune=generic"
else
  export LDFLAGS=
  export CXXFLAGS="-fPIC -O3 -m64 -mtune=generic"
fi
  export CFLAGS="-fPIC -O3 -m64 -mtune=generic"



################################################################################
# Build Python
################################################################################
PYTHON_VERSION=2.7.10 $SOURCE_DIR/source/python/build.sh

################################################################################
# Build CMake
################################################################################
if [[ ! "$OSTYPE" == "darwin"* ]]; then
  $SOURCE_DIR/source/cmake/build.sh
fi

################################################################################
# LLVM
################################################################################

# Build Default LLVM
$SOURCE_DIR/source/llvm/build.sh

if [[ ! "$OSTYPE" == "darwin"* ]]; then
  LLVM_VERSION=3.3 $SOURCE_DIR/source/llvm/build.sh
fi

# CentOS 5 can't build trunk LLVM due to missing perf counter
if [[ ! "$RELEASE_NAME" =~ CentOS.*5\.[[:digit:]] ]]; then
  #Build Trunk LLVM
  LLVM_VERSION=trunk $SOURCE_DIR/source/llvm/build.sh
fi

################################################################################
# Once this is done proceed with the regular thirdparty build
cd $SOURCE_DIR

################################################################################
# SASL
################################################################################
$SOURCE_DIR/source/cyrus-sasl/build.sh

################################################################################
# Boost
################################################################################
$SOURCE_DIR/source/boost/build.sh

################################################################################
# Build libevent
################################################################################
$SOURCE_DIR/source/libevent/build.sh

################################################################################
# Thrift
#  * depends on boost
#  * depends on libevent
################################################################################
$SOURCE_DIR/source/thrift/build.sh

################################################################################
# gflags
################################################################################
$SOURCE_DIR/source/gflags/build.sh

################################################################################
# Build pprof
################################################################################
$SOURCE_DIR/source/gperftools/build.sh

################################################################################
# Build glog
################################################################################
$SOURCE_DIR/source/glog/build.sh

################################################################################
# Build gtest
################################################################################
$SOURCE_DIR/source/gtest/build.sh

################################################################################
# Build Snappy
################################################################################
$SOURCE_DIR/source/snappy/build.sh

################################################################################
# Build Lz4
################################################################################
$SOURCE_DIR/source/lz4/build.sh

################################################################################
# Build re2
################################################################################
RE2_VERSION=20130115 $SOURCE_DIR/source/re2/build.sh
RE2_VERSION=20130115-p1 $SOURCE_DIR/source/re2/build.sh

################################################################################
# Build Ldap
################################################################################
$SOURCE_DIR/source/openldap/build.sh

################################################################################
# Build Avro
################################################################################
$SOURCE_DIR/source/avro/build.sh

################################################################################
# Build Rapidjson
################################################################################
$SOURCE_DIR/source/rapidjson/build.sh

################################################################################
# Build ZLib
################################################################################
$SOURCE_DIR/source/zlib/build.sh

################################################################################
# Build BZip2
################################################################################
$SOURCE_DIR/source/bzip2/build.sh

################################################################################
# Build GDB
################################################################################
if [[ ! "$RELEASE_NAME" =~ CentOS.*5\.[[:digit:]] ]]; then
  $SOURCE_DIR/source/gdb/build.sh
fi

################################################################################
# Build Breakpad
################################################################################
$SOURCE_DIR/source/breakpad/build.sh
