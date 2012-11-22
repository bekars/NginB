TOP_PATH=/home/baiyu/GitHub/NginB
NGX_PATH=$(TOP_PATH)/nginx-1.2.4
NGX_MOD_PATH=$(TOP_PATH)/modules

all: config build

PHONY += config
config:
	cd ${NGX_PATH}; \
	./configure --with-debug \
		--with-http_stub_status_module \
		--add-module=${NGX_MOD_PATH}/mod_minify \
		--add-module=${NGX_MOD_PATH}/mod_capcache

PHONY += build
build:
	cd ${NGX_PATH} && make

PHONY += clean
clean:
	cd ${NGX_PATH} && make clean

.PHONY: $(PHONY)

