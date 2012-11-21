TOP_PATH=/home/baiyu/GitHub/NginB
NGX_PATH=$(TOP_PATH)/nginx-1.2.4
NGX_MOD_PATH=$(TOP_PATH)/modules

all: config
	cd ${NGX_PATH}; make

config:
	cd ${NGX_PATH}; \
	./configure --with-debug \
		--with-http_stub_status_module \
		--add-module=${NGX_MOD_PATH}/mod_minify \
		--add-module=${NGX_MOD_PATH}/mod_capcache

clean:
	cd ${NGX_PATH}; make clean

