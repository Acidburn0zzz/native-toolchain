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

function wrap() {
  if [[ $DEBUG -eq 0 ]]; then
    "$@" >> $BUILD_LOG 2>&1
  else
    "$@" 2>&1 | tee $BUILD_LOG
  fi
}

function prepare() {
  PACKAGE="$(basename $1)"; PACKAGE=`echo "${PACKAGE}" | awk '{print toupper($0)}'`
  PACKAGE_VERSION="${PACKAGE}_VERSION"
  # Replace potential - with _
  PACKAGE_VERSION="${PACKAGE_VERSION//-/_}"
  PACKAGE_VERSION="${!PACKAGE_VERSION}"

  # Regex to match patch level
  regex="(.*)-p([[:digit:]]+)$"

  # Extract the patch level
  if [[ $PACKAGE_VERSION =~ $regex ]]; then
    export PATCH_LEVEL="${BASH_REMATCH[2]}"
    export PATCH_VERSION="-p${PATCH_LEVEL}"
    export PACKAGE_VERSION="${BASH_REMATCH[1]}"
  else
    export PATCH_LEVEL=
    export PATCH_VERSION=
  fi

  PACKAGE_STRING="$PACKAGE-$PACKAGE_VERSION"
}

# Build helper function that sets the necessary environment variables
# that can be used per build
function header() {
  echo "#######################################################################"
  echo "# Building: ${1}-${2}"

  # Package name might be upper case
  LPACKAGE=`echo "${1}" | awk '{print tolower($0)}'`
  cd $SOURCE_DIR/source/$LPACKAGE

  # Build name
  LPACKAGE_VERSION=$LPACKAGE-$2

  LOCAL_INSTALL=$BUILD_DIR/$LPACKAGE-$2${PATCH_VERSION}
  BUILD_LOG=$SOURCE_DIR/check/$LPACKAGE-$2.log

  # Extract the sources
  if [ -f $LPACKAGE_VERSION.tar.gz ]; then
    tar zxf $LPACKAGE_VERSION.tar.gz
    DIR=$LPACKAGE_VERSION
  elif [ -f $LPACKAGE_VERSION.tgz ]; then
    tar zxf $LPACKAGE_VERSION.tgz
    DIR=$LPACKAGE_VERSION
  elif [ -f $LPACKAGE_VERSION.src.tar.gz ]; then
    tar zxf $LPACKAGE_VERSION.src.tar.gz
    DIR=$LPACKAGE_VERSION.src
  elif [ -f $LPACKAGE-src-$2.tar.gz ]; then
    tar zxf $LPACKAGE-src-$2.tar.gz
    DIR=$LPACKAGE-src-$2
  elif [ -f $LPACKAGE_VERSION.zip ]; then
    unzip -o $LPACKAGE_VERSION.zip
    DIR=$LPACKAGE_VERSION
  else
    DIR=$LPACKAGE_VERSION
  fi


  # Depending how ugly things are packaged we might have directories that are different
  # from the archive name, looking at you boost
  RDIR="${DIR//-/_}"; RDIR="${RDIR//./_}"
  if [ -d "$DIR" ]; then
    cd $DIR
  elif [ -d "${RDIR}" ]; then
    cd $RDIR
  else
    cd $LPACKAGE
  fi

  # Apply patches for this package
  apply_patches
}

function footer() {

  # Build Package
  build_dist_package >> $BUILD_LOG 2>&1

  # For all binaries of the package symlink to bin
  if [[ -d $BUILD_DIR/${LPACKAGE_VERSION}${PATCH_VERSION}/bin ]]; then
    mkdir -p $BUILD_DIR/bin
    for p in `ls $BUILD_DIR/$LPACKAGE_VERSION$PATCH_VERSION/bin`; do
      ln -f -s $BUILD_DIR/${LPACKAGE_VERSION}${PATCH_VERSION}/bin/$p $BUILD_DIR/bin/$p
    done
  fi

  touch $SOURCE_DIR/check/$1-$2
  echo "# Build Complete ${1}-${2}"
  echo "#######################################################################"
}


# Check if environment variables BUILD_ALL=0 and a variable of the
# name PACKAGE_NAME_VERSION is set indicating that this package needs
# to be build.
function needs_build_package() {

  # First check if the build_all variable is set or not
  : ${BUILD_ALL=1}

  if [ ! -f $SOURCE_DIR/check/$PACKAGE_STRING ] && [ $BUILD_ALL -eq 1 ]; then
    return 0
  fi

  ENV_NAME="BUILD_${PACKAGE}"
  ENV_NAME=${!ENV_NAME=0}

  if [ $BUILD_ALL -eq 0 ] && [ $ENV_NAME -eq 1 ]; then
    return 0 # Build package
  else
    return 1 # Dont build this package
  fi
}

# Check the package_name-version-patches directory and apply patches
# depending on patch-level. Patches must be prepared that they can be
# applied directly on the extracted source tree from within the source
# (-p2 / -p1).
function apply_patches() {
  if [[ -d $SOURCE_DIR/source/$LPACKAGE/$LPACKAGE_VERSION-patches ]]; then
    echo "Apply patches up to ${PATCH_LEVEL}"
    INIT_VAL=1
    for p in `find $SOURCE_DIR/source/$LPACKAGE/$LPACKAGE_VERSION-patches -type f`; do
      echo "Applying patch ${INIT_VAL}..."
      set +e
      # Check if patch can be applied at -p2 first, then p1
      patch -p2 < $p >> $BUILD_LOG 2>&1
      RET_VAL=$?
      set -e
      if [[ $RET_VAL -ne 0 ]]; then
        patch -p1 < $p >> $BUILD_LOG 2>&1
      fi
      INIT_VAL=$(($INIT_VAL + 1))
      if [[ $INIT_VAL -gt $PATCH_LEVEL ]]; then
        echo "All required patches applied."
        return 0
      fi
    done
  fi
}

# Determines what the platforms packaging type is
function set_target_package_type() {
  set +e
  FPM_CMD=$(which fpm)
  YUM_CMD=$(which yum)
  RPM_CMD=$(which rpm)
  ZYPPER_CMD=$(which zypper)
  APT_CMD=$(which apt-get)
  set -e

  if [[ -z $FPM_CMD ]]; then
    # No FPM installed, will not build packages
    TARGET=
    return 0
  fi

  if [[ "$RELEASE_NAME" =~ Ubuntu ]]; then
    TARGET="deb"
  elif [[ "$RELEASE_NAME" =~ Debian ]]; then
    TARGET="deb"
  elif [[ ! -z $YUM_CMD ]]; then
    TARGET="rpm"
  elif [[ ! -z $RPM_CMD ]]; then
    TARGET="rpm"
  else
    echo "Cannot build package"
    return 1
  fi
}


# Build the RPM or DEB package depending on the operating system
# Depends on the LOCAL_INSTALL variable containing the target
# directory
function build_dist_package() {
  SOURCE_TYPE="dir"
  set_target_package_type

  if [[ -z $TARGET ]]; then
    return 0
  fi

  # System package
  DIST_NAME="${LPACKAGE}${PACKAGE_VERSION}${PATCH_VERSION}-${COMPILER}-${COMPILER_VERSION}"
  fpm -p $BUILD_DIR --prefix $TOOLCHAIN_PREFIX  -s $SOURCE_TYPE -f \
    -t $TARGET -n "${DIST_NAME}" \
    -v "${PACKAGE_VERSION}${PATCH_VERSION}-${COMPILER}-${COMPILER_VERSION}-${PLATFORM_VERSION}" \
    -C $BUILD_DIR \
    ${LPACKAGE_VERSION}${PATCH_VERSION}

  # Produce a tar.gz for the binary product for easier bootstrapping
  FULL_TAR_NAME="${LPACKAGE_VERSION}${PATCH_VERSION}-${COMPILER}"
  FULL_TAR_NAME+="-${COMPILER_VERSION}"
  tar zcf ${BUILD_DIR}/${FULL_TAR_NAME}.tar.gz \
    --directory=${BUILD_DIR} \
    ${LPACKAGE_VERSION}${PATCH_VERSION}
}

# Given the assumption that all other build steps completed successfully, generate a meta
# package that pulls in all dependencies.
function build_meta_package() {
  NAME=$1
  shift
  PACKAGES=("${@}")
  SOURCE_TYPE="empty"

  set_target_package_type

  if [[ -z $TARGET ]]; then
    return 0
  fi

  DEPENDENCIES=""
  for dep in ${PACKAGES[@]}; do
    DEPENDENCIES="${DEPENDENCIES} -d ${dep}"
  done

  # Build the package
  fpm -f -p $BUILD_DIR --prefix $TOOLCHAIN_PREFIX -s $SOURCE_TYPE \
    ${DEPENDENCIES} -t $TARGET -n "${NAME}" \
    -v "${NAME}-${PLATFORM_VERSION}"
}
