#!/usr/bin/env bash
export KUDU_DIR="$(cd "$(dirname "$0")" && pwd)"
export KUDU_TP_DIR=$KUDU_DIR/kudu/thirdparty
export KUDU_GCC_VERSION=4.9.3
export KUDU_GCC_DIR=
export CMAKE_VERSION=3.6.1
export CMAKE_BIN=$KUDU_TP_DIR/build/cmake-$CMAKE_VERSION/bin
export PATH=$CMAKE_BIN:$PATH
