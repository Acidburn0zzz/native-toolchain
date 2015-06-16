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

source $SOURCE_DIR/functions.sh
THIS_DIR="$( cd "$( dirname "$0" )" && pwd )"
prepare $THIS_DIR

if needs_build_package ; then
  header $PACKAGE $PACKAGE_VERSION

  ./configure --prefix=$LOCAL_INSTALL > $BUILD_LOG 2>&1

  # Some build machines might not have makeinfo
  sed -i 's/MAKEINFO = .*missing makeinfo$/MAKEINFO = \/bin\/true/' Makefile
  sed -i 's/MAKEINFO = @MAKEINFO@$/MAKEINFO = \/bin\/true/' gdb/Makefile.in

  wrap make -j${BUILD_THREADS:-4}
  wrap make install

  footer $PACKAGE $PACKAGE_VERSION
fi
