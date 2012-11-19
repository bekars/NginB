
ifndef top_srcdir
	top_srcdir := $(shell pwd)/..
endif

include $(top_srcdir)/Rules.mak

COMPILE   = $(CC) $(CFLAGS) $(INCLUDE) $(DEFS) $(LDFLAGS_EX) $(LDFLAGS)
COMPILE_C = $(CC) $(CFLAGS) $(INCLUDE) $(DEFS)

TARGET  := cache_info
SOURCE  := $(wildcard *.c)
HEADER  := $(wildcard *.h)
OBJS    := $(SOURCE:.c=.o)

$(TARGET): $(OBJS) $(HEADER)
	$(call now_make_it) 
	$(COMPILE) -o $@ $(OBJS)

%.o : %.c
	$(COMPILE_C) -c $<

PHONY += install
install:

PHONY += clean
clean:
	-$(RM_F) $(TARGET) $(OBJS)

.PHONY: $(PHONY)

