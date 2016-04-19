#!/usr/bin/env bash
# Copyright 2015 Cloudera Inc.
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

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

function download_lz4() {
  # S3 Base URL
  LZ4_URL="https://github.com/Cyan4973/lz4/archive/${LZ4_VERSION}.tar.gz"
  if [[ ! -f "${2}/${1}" ]]; then
    ARGS=
    if [[ $DEBUG -eq 0 ]]; then
      ARGS=-q
    fi
    wget $ARGS -O "${2}/${1}" "${LZ4_URL}"
  fi
}

if needs_build_package ; then
  if [ "${LZ4_VERSION}" != "svn" ]; then
    download_lz4 "${PACKAGE_STRING}.tar.gz" $THIS_DIR
    CFLAGS=-fPIC
    header $PACKAGE $PACKAGE_VERSION
    cd cmake_unofficial
  else
    header $PACKAGE $PACKAGE_VERSION
  fi
  wrap cmake -DCMAKE_INSTALL_PREFIX=$LOCAL_INSTALL .
  wrap make -j${BUILD_THREADS:-4} install
  footer $PACKAGE $PACKAGE_VERSION
fi
