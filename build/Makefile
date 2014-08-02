TOP_PATH          = /home/baiyu/Git/NginB
NGX_PATH          = $(TOP_PATH)/nginx-1.2.4
NGX_MOD_PATH      = $(TOP_PATH)/modules
NGX_MOD_MORE_PATH = $(NGX_PATH)/src/nginx_mods
NGX_PAGESPEED     = src/nginx_mods

NGX_MOD_CONFIG    = \
	--error-log-path=/var/log/error.log \
	--pid-path=/var/run/nginx.pid \
	--with-debug \
	--with-pcre \
	--with-poll_module \
	--http-fastcgi-temp-path=/data/nginx/fcgi/ \
	--with-http_ssl_module \
	--with-http_sub_module \
	--with-http_stub_status_module \
	--http-proxy-temp-path=/data/nginx/cache_tmp \
	--add-module=${NGX_MOD_MORE_PATH}/echo-nginx-module \
	--add-module=${NGX_MOD_MORE_PATH}/ngx_devel_kit \
	--add-module=${NGX_MOD_MORE_PATH}/lua-nginx-module \
	--add-module=${NGX_MOD_MORE_PATH}/headers-more-nginx-module \
	--add-module=${NGX_PAGESPEED}/ngx_pagespeed \
	--add-module=${NGX_MOD_MORE_PATH}/srcache-nginx-module \
	--add-module=${NGX_MOD_PATH}/mod_breakpoint \
	--add-module=${NGX_MOD_PATH}/mod_minify \
	--add-module=${NGX_MOD_PATH}/mod_capcache \
	--add-module=${NGX_MOD_PATH}/mod_aqb


all: config build

PHONY += config
config:
	cd ${NGX_PATH}; \
	./configure ${NGX_MOD_CONFIG}

PHONY += build
build:
	cd ${NGX_PATH} && make -j2

PHONY += clean
clean:
	cd ${NGX_PATH} && make clean

PHONY += install
install:
	cd ${NGX_PATH} && make install

.PHONY: $(PHONY)

