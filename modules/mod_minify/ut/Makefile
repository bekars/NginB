
UT_SRC := ngx_minify_ut_main.c \
	../ngx_http_minify_filter_module_css.c \
	../ngx_http_minify_filter_module_html.c \
	../ngx_http_minify_filter_module_js.c \
	ngx_minify_ut_html.c \
	ngx_minify_ut_css.c \
	ngx_minify_ut_js.c

UT_EXE := ut


all: $(UT_EXE)

$(UT_EXE): $(UT_SRC)
	gcc -g -o ut -I./ -I../ $(UT_SRC)

clean:
	rm -f $(UT_EXE)

