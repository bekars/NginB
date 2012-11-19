#!/bin/sh

NGX_PATH=../nginx-1.2.4
NGX_MOD_PATH=../modules

cd ${NGX_PATH}
./configure --with-debug --add-module=${NGX_MOD_PATH}/mod_minify --with-http_stub_status_module
make

