# obj-m := ovl.o

# ovl-objs += super.o inode.o dir.o readdir.o file.o balloc.o

# all:
# 	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
# clean:
# 	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

# obj-y := ovl.o

# ovl-objs += super.o inode.o dir.o readdir.o file.o balloc.o

obj-m = p2cache.o

p2cache-objs += stats.o super.o inode.o dir.o \
								readdir.o file.o balloc.o \
								log-index.o cp.o copy.o
# gc.o recovery.o

CFLAGS_copy.o += -mavx512f
# ccflags-y+=-mmmx -msse2 -mavx -mavx512f -mavx512cd -mavx512bw -mavx512dq -mavx512vl -mavx512ifma -mavx512vbmi -mpreferred-stack-boundary=4

# all: ovl install

vm: build_vm

host: build_host


build_vm:
	make -C ../linux-5.4.225 M=$(PWD) modules

clean_vm:
	make -C ../linux-5.4.225 M=$(PWD) clean

build_host:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean_host:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

build_61:
	make -C /lib/modules/6.1.76/build/ M=$(PWD) modules

# install:
# 	cp ovl.ko ../share/
