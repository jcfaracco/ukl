.PHONY: redis

PARALLEL= -j$(shell nproc)

#PATHS
DIR := ${CURDIR}
GCC_LIB=$(DIR)/gcc-build/x86_64-pc-linux-gnu/libgcc/
LC_DIR=$(DIR)/glibc-build/
CRT_LIB=$(LC_DIR)csu/
C_LIB=$(LC_DIR)libc.a
PTHREAD_LIB=$(LC_DIR)nptl/libpthread.a
RT_LIB=$(LC_DIR)rt/librt.a
MATH_LIB=$(LC_DIR)math/libm.a
CRT_STARTS=$(CRT_LIB)crt1.o $(CRT_LIB)crti.o $(GCC_LIB)crtbeginT.o
CRT_ENDS=$(GCC_LIB)crtend.o $(CRT_LIB)crtn.o
SYS_LIBS=$(GCC_LIB)libgcc.a $(GCC_LIB)libgcc_eh.a
CPP_LIB=$(DIR)/gcc-build-cpp/x86_64-pc-linux-gnu/libstdc++-v3/src/.libs/libstdc++.a

UKL_FLAGS=-ggdb -mno-red-zone -mcmodel=kernel

redis: cloneRepos
	./build_ukl.sh 0 redis

cloneRepos:
	make gcc-dir
	make gpp-dir
	make glibc-dir
	make min-initrd-dir
	make all -C min-initrd/
	make linux-dir
	make new_lebench-dir
	make gapbs-dir

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

#Example Projects
new_lebench-dir:
	if ! test -d new_lebench; then \
	    git clone git@github.com:unikernelLinux/new_lebench.git; \
	fi

gapbs-dir:
	if ! test -d gapbs; then \
	    git clone -b ukl git@github.com:unikernelLinux/gapbs.git; \
	fi

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

#LINUX
linux-dir:
	if ! test -d linux; then \
	    git clone --depth 1 --branch ukl-main-5.14 git@github.com:unikernelLinux/linux.git; \
	fi

linux-clean:
	make distclean -C linux/
	cp saveconfig linux/.config
	make -C linux menuconfig
	cat linux/.config

linux-build:
	- rm -rf linux/vmlinux
	make -C linux $(PARALLEL) WERROR=0

linux-copy:
	cp linux/arch/x86/boot/bzImage /var/lib/tftpboot/ukl/

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

#MIN_INITRD
min-initrd-dir:
	if ! test -d min-initrd; then \
	    git clone git@github.com:unikernelLinux/min-initrd.git; \
	fi

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

#GCC
gcc-dir:
	if ! test -d gcc; then \
	    git clone --depth 1 --branch releases/gcc-9.3.0 'https://github.com/gcc-mirror/gcc.git'; \
	fi
	cd ./gcc; ./contrib/download_prerequisites

gcc-build:
	- mkdir $@
	- mkdir gcc-install
	cd $@; \
	  TARGET=x86_64-elf ../gcc/configure --target=$(TARGET) \
	  --disable-nls --enable-languages=c,c++ --without-headers \
	  --prefix=/home/tommyu/localInstall/gcc-install/ --with-multilib-list=m64 --disable-multilib
	make -C $@ all-gcc $(PARALLEL)
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-ggdb -O2 -mno-red-zone -mcmodel=kernel' $(PARALLEL)
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-ggdb -O2 -mno-red-zone -mcmodel=kernel'
	sed -i 's/PICFLAG/DISABLED_PICFLAG/g' gcc-build/x86_64-pc-linux-gnu/libgcc/Makefile
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-ggdb -O2 -mcmodel=kernel -mno-red-zone'

gpp-dir:
	if ! test -d gpp; then \
	    git clone --depth 1 --branch releases/gcc-9.3.0 'https://github.com/gcc-mirror/gcc.git' gpp; \
	fi
	cd ./gpp; ./contrib/download_prerequisites

gcc-build-cpp:
	- mkdir $@
	- mkdir gcc-install
	cd $@; \
	  TARGET=x86_64-elf ../gpp/configure --target=$(TARGET) \
	  --disable-shared --disable-nls --enable-languages=c,c++ --without-headers \
	  --prefix=/home/tommyu/localInstall/gcc-install/ \
	  --with-multilib-list=m64 --disable-multilib
	make -C $@ all-gcc $(PARALLEL)
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-ggdb -O2 -mno-red-zone -mcmodel=kernel' $(PARALLEL)
	- make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-ggdb -O2 -mno-red-zone -mcmodel=kernel'
	- make -C $@ all-target-libstdc++-v3 CFLAGS_FOR_TARGET='-ggdb -O2 -mcmodel=kernel -mno-red-zone' \
		CXXFLAGS_FOR_TARGET='-ggdb -O2 -mcmodel=kernel -mno-red-zone' $(PARALLEL)
	- make -C $@ all-target-libstdc++-v3 CFLAGS_FOR_TARGET='-ggdb -O2 -mcmodel=kernel -mno-red-zone' \
		CXXFLAGS_FOR_TARGET='-ggdb -O2 -mcmodel=kernel -mno-red-zone'
	sed -i 's/PICFLAG/DISABLED_PICFLAG/g' $@/x86_64-pc-linux-gnu/libgcc/Makefile
	make -C $@ all-target-libgcc CFLAGS_FOR_TARGET='-ggdb -O2 -mcmodel=kernel -mno-red-zone'
	make -C $@ all-target-libstdc++-v3 CFLAGS_FOR_TARGET='-ggdb -O2 -mcmodel=kernel -mno-red-zone' \
		CXXFLAGS_FOR_TARGET='-ggdb -O2 -mcmodel=kernel -mno-red-zone'

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

#GLIBC
glibc-dir:
	if ! test -d glibc; then \
	    git clone --depth 1 --branch ukl git@github.com:unikernelLinux/glibc.git; \
	fi

glibc-build:
	./cleanbuild.sh

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

#RUN
run:
	make runU -C min-initrd

debug:
	make debugU -C min-initrd

#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

#MOUNT/UNMOUNT
mnt:
	mount min-initrd/min-initrd.d/root mntpt

umnt:
	umount mntpt
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

#CLEAN
glibc-clean:
	- rm -rf glibc-build

gcc-clean:
	- rm -rf gcc-build
	- rm -rf gcc-build-cpp

dist-clean: glibc-clean gcc-clean
	- rm -rf gcc glibc 
