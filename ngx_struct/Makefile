CC        = gcc
CCFLAGS  += -g -Wall -Wextra
NGX_ROOT  = ../nginx-1.6.0
TARGETS   = ngx_array_t ngx_str_t ngx_hash_t ngx_pool_t ngx_queue_t
CLEANUP   = rm -f $(TARGETS) *.o
SRC_ARRAY = ngx_array_t.c
SRC_STR   = ngx_str_t.c
SRC_HASH  = ngx_hash_t.c
SRC_POOL  = ngx_pool_t.c
SRC_QUEUE = ngx_queue_t.c

CORE_INCS = -I. \
	-I$(NGX_ROOT)/src/core \
	-I$(NGX_ROOT)/src/event \
	-I$(NGX_ROOT)/src/event/modules \
	-I$(NGX_ROOT)/src/os/unix \
	-I$(NGX_ROOT)/objs

NGX_PALLOC = $(NGX_ROOT)/objs/src/core/ngx_palloc.o
NGX_STRING = $(NGX_ROOT)/objs/src/core/ngx_string.o
NGX_ALLOC  = $(NGX_ROOT)/objs/src/os/unix/ngx_alloc.o
NGX_ARRAY  = $(NGX_ROOT)/objs/src/core/ngx_array.o
NGX_HASH   = $(NGX_ROOT)/objs/src/core/ngx_hash.o
NGX_QUEUE  = $(NGX_ROOT)/objs/src/core/ngx_queue.o

NGX_MODULE = $(NGX_PALLOC) $(NGX_STRING) $(NGX_ALLOC) $(NGX_ARRAY) $(NGX_HASH) $(NGX_QUEUE)

all: $(TARGETS)

clean:
	$(CLEANUP)

ngx_array_t: $(SRC_ARRAY)
	$(CC) $(CCFLAGS) $(CORE_INCS) $(NGX_MODULE) $^ -o $@

ngx_str_t: $(SRC_STR)
	$(CC) $(CCFLAGS) $(CORE_INCS) $(NGX_MODULE) $^ -o $@

ngx_hash_t: $(SRC_HASH)
	$(CC) $(CCFLAGS) $(CORE_INCS) $(NGX_MODULE) $^ -o $@

ngx_pool_t: $(SRC_POOL)
	$(CC) $(CCFLAGS) $(CORE_INCS) $(NGX_MODULE) $^ -o $@

ngx_queue_t: $(SRC_QUEUE)
	$(CC) $(CCFLAGS) $(CORE_INCS) $(NGX_MODULE) $^ -o $@

