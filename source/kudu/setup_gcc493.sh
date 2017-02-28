#!/usr/bin/env bash

download_gcc493() {
        source $SOURCE_DIR/functions.sh
 	source $SOURCE_DIR/source/kudu/kudu-config.sh
        cd $KUDU_TP_DIR/src
        echo "Downloading gcc-${KUDU_GCC_VERSION} in `pwd`" 
 	wget ftp://gd.tuwien.ac.at/gnu/gcc/releases/gcc-${KUDU_GCC_VERSION}/gcc-${KUDU_GCC_VERSION}.tar.bz2
	tar -xvf gcc-${KUDU_GCC_VERSION}.tar.bz2
       	cd gcc-${KUDU_GCC_VERSION}
        ./contrib/download_prerequisites 
	./configure --prefix=$KUDU_TP_DIR/build/gcc-${KUDU_GCC_VERSION} --enable-bootstrap --enable-shared --enable-threads=posix --enable-checking=release --with-system-zlib --enable-__cxa_atexit --disable-libunwind-exceptions --enable-gnu-unique-object --enable-linker-build-id --with-linker-hash-style=gnu --enable-languages=c,c++,objc,obj-c++ --enable-plugin --enable-initfini-array --disable-libgcj --enable-gnu-indirect-function --enable-secureplt --with-long-double-128 --enable-targets=powerpcle-linux --disable-multilib --with-cpu-64=power8 --with-tune-64=power8 --build=powerpc64le-unknown-linux-gnu
	make -j8
	make install
        echo "Successfully setup gcc-${KUDU_GCC_VERSION}"
}

${1-download_gcc493}
