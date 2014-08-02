TOP_PATH          = /home/baiyu/Git/NginB
NGX_VER 		  = 1.6.0
NGX_PATH          = $(TOP_PATH)/nginx-$(NGX_VER)
NGX_MOD_PATH      = $(TOP_PATH)/modules
NGX_MOD_MORE_PATH = $(TOP_PATH)/ngx_mods

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
	--add-module=${NGX_MOD_MORE_PATH}/headers-more-nginx-module \
	--add-module=${NGX_MOD_MORE_PATH}/echo-nginx-module \
	--add-module=${NGX_MOD_MORE_PATH}/ngx_devel_kit \
	--add-module=${NGX_MOD_MORE_PATH}/lua-nginx-module
#	--add-module=${NGX_MOD_MORE_PATH}/srcache-nginx-module \
#	--add-module=${NGX_MOD_PATH}/mod_breakpoint \
#	--add-module=${NGX_MOD_PATH}/mod_minify \
#	--add-module=${NGX_MOD_PATH}/mod_capcache \
#	--add-module=${NGX_MOD_PATH}/mod_aqb \
#	--add-module=${NGX_MOD_PATH}/ngx_pagespeed \
#	--add-module=${NGX_MOD_PATH}/ngx_http_coolplay_filter_module


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

