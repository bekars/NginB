TOP_PATH=/home/baiyu/GitHub/NginB
NGX_PATH=$(TOP_PATH)/nginx-1.2.4
NGX_MOD_PATH=$(TOP_PATH)/modules
NGX_MOD_MORE_PATH=/home/baiyu/GitHub

all: config build

PHONY += config
config:
	cd ${NGX_PATH}; \
	./configure --with-debug \
		--with-http_stub_status_module \
		--add-module=${NGX_MOD_MORE_PATH}/echo-nginx-module \
		--add-module=${NGX_MOD_MORE_PATH}/ngx_devel_kit \
		--add-module=${NGX_MOD_MORE_PATH}/lua-nginx-module \
		--add-module=${NGX_MOD_MORE_PATH}/headers-more-nginx-module \
		--add-module=${NGX_MOD_PATH}/mod_breakpoint \
		--add-module=${NGX_MOD_PATH}/mod_minify \
		--add-module=${NGX_MOD_PATH}/mod_capcache

PHONY += build
build:
	cd ${NGX_PATH} && make -j2

PHONY += clean
clean:
	cd ${NGX_PATH} && make clean

.PHONY: $(PHONY)

