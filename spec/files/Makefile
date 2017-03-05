BIT ?= 64 # 64bit or 32bit

flags =
ifeq ($(BIT), 32)
flags += -m32
endif

check_options:
ifndef LIB_VER
	exit 1
endif
ifndef OUTFILE
	exit 1
endif
rpath = $(PWD)/libraries/libc-$(LIB_VER)/$(BIT)bit
flags += -L$(rpath)
flags += -Wl,-rpath=$(rpath)
flags += -Wl,-dynamic-linker,$(rpath)/ld.so.2

victim: check_options
	g++ victim.cpp -o $(OUTFILE) $(flags) $(CFLAGS)

