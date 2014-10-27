TOP_PATH     = /home/baiyu/Git/NginB
NGX_VER      = 1.6.0
NGX_PATH     = $(TOP_PATH)/nginx-$(NGX_VER)
MODULES_PATH = $(TOP_PATH)/modules
NGX_MOD_PATH = $(TOP_PATH)/ngx_mods

NGX_MOD_CONFIG = \
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
	--add-module=${NGX_MOD_PATH}/headers-more-nginx-module \
	--add-module=${NGX_MOD_PATH}/echo-nginx-module \
	--add-module=${NGX_MOD_PATH}/nginx-upload-module \
	--add-module=${NGX_MOD_PATH}/ngx_devel_kit \
	--add-module=${NGX_MOD_PATH}/lua-nginx-module
#	--add-module=${NGX_MOD_PATH}/srcache-nginx-module \
#	--add-module=${NGX_MOD_PATH}/mod_breakpoint \
#	--add-module=${NGX_MOD_PATH}/mod_minify \
#	--add-module=${NGX_MOD_PATH}/mod_capcache \
#	--add-module=${NGX_MOD_PATH}/mod_aqb \
#	--add-module=${NGX_MOD_PATH}/ngx_pagespeed \
#	--add-module=${NGX_MOD_PATH}/ngx_http_coolplay_filter_module

#export LUAJIT_LIB=/path/to/luajit/lib
#export LUAJIT_INC=/path/to/luajit/include/luajit-2.1

all: config build

PHONY += config
config:
	cd ${NGX_PATH} && ./configure ${NGX_MOD_CONFIG}

PHONY += build
build:
	cd ${NGX_PATH} && make -j2

PHONY += clean
clean:
	cd ${NGX_PATH} && make clean

PHONY += install
install:
	cd ${NGX_PATH} && make install

PHONY += ngxmod
ngxmod:
	@mkdir -p ${NGX_MOD_PATH}
	cd ${NGX_MOD_PATH} && git clone https://github.com/openresty/echo-nginx-module.git
	cd ${NGX_MOD_PATH} && git clone https://github.com/openresty/headers-more-nginx-module.git
	cd ${NGX_MOD_PATH} && git clone https://github.com/openresty/lua-nginx-module.git
	cd ${NGX_MOD_PATH} && git clone https://github.com/simpl/ngx_devel_kit.git
	cd ${NGX_MOD_PATH} && git clone -b 2.2 https://github.com/vkholodkov/nginx-upload-module.git

.PHONY: $(PHONY)

