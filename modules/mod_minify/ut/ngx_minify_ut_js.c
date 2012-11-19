
#include "ngx_minify_ut.h"

ngx_minify_ut_data_s js_ut_data[] = 
{
    {
        .ut_name = "测试压缩行前的空格和制表符",
        .ut_data = {"\tvar me = this;\n     var me = that;\n \t \tvar me = this;\n", NULL},
        .ut_result = "var me = this;var me = that;var me = this;\n",
    },

    {
        .ut_name = "测试压缩多余空格和制表符",
        .ut_data = {"\tvar me  \t  = this;\n", NULL},
        .ut_result = "var me = this;",
    },

    {
        .ut_name = "测试压缩多余空格和制表符，跨buf",
        .ut_data = {"\tvar me", "  ", "\t", "  = this;\n", NULL},
        .ut_result = "var me= this;",
    },

    {
        .ut_name = "测试压缩单行注释",
        .ut_data = {"var me = this; // comment\n", NULL},
        .ut_result = "var me = this;  ",
    },

    {
        .ut_name = "测试压缩单行注释，跨buf",
        .ut_data = {"var me = this; ", "/", "/", " comment\n", NULL},
        .ut_result = "var me = this;  ",
    },

    {
        .ut_name = "测试压缩注释",
        .ut_data = {"var me/* comment */ = this;", NULL},
        .ut_result = "var me = this;",
    },

    {
        .ut_name = "测试压缩注释，跨buf",
        .ut_data = {"var me ", "/", "*", " comment ", "*", "/", "= this;", NULL},
        .ut_result = "var me = this;",
    },

    {
        .ut_name = "测试压缩注释，注释中有*字符",
        .ut_data = {"var me/*\n /* \n * comment */ = this;", NULL},
        .ut_result = "var me = this;",
    },

    {
        .ut_name = "测试双引号",
        .ut_data = {"var me =  \"  quote  \"", NULL},
        .ut_result = "var me = \"  quote  \"",
    },

    {
        .ut_name = "测试双引号，跨buf",
        .ut_data = {"var me = ", "\"", "  quote  ", "\"", NULL},
        .ut_result = "var me = \"  quote  \"",
    },

    {
        .ut_name = "测试双引号内包含引号",
        .ut_data = {"var me =  \"  \\\"quote\\\"  \"", NULL},
        .ut_result = "var me = \"  \\\"quote\\\"  \"",
    },

    {
        .ut_name = "测试单引号",
        .ut_data = {"var me =  \'  quote  \'", NULL},
        .ut_result = "var me = \'  quote  \'",
    },

    {
        .ut_name = "测试单引号，跨buf",
        .ut_data = {"var me = ", "\'", "  quote  ", "\'", NULL},
        .ut_result = "var me = \'  quote  \'",
    },

    {
        .ut_name = "测试单引号内包含引号",
        .ut_data = {"var me =  \'  \\\'quote\\\'  \'", NULL},
        .ut_result = "var me = \'  \\\'quote\\\'  \'",
    },

    {
        .ut_name = "测试中括号",
        .ut_data = {"var me [a =  b];", NULL},
        .ut_result = "var me [a =  b];",
    },

    {
        .ut_name = "测试压缩换行符",
        .ut_data = {"\nline1;\nline2:\nline3{\nline4}\nline5", NULL},
        .ut_result = "line1;line2:line3{line4}line5",
    },

    {
        .ut_name = "测试压缩换行符1",
        .ut_data = {"for(var i=nodes.length-1;i>=0;i--)" \
"                {" \
"                            var element=nodes[i];" \
"        " \
"        " \
"                                    news[i]={};", NULL},
        .ut_result = "for(var i=nodes.length-1;i>=0;i--) { var element=nodes[i]; news[i]={};",
    },

    {
        .ut_name = "测试压缩换行符2",
        .ut_data = {"for(var i=nodes.length-1;i>=0;i--)\r\n\t{\r\n\t}", NULL},
        .ut_result = "for(var i=nodes.length-1;i>=0;i--)\n{}",
    },

    {
        .ut_name = NULL,
        .ut_data = NULL,
        .ut_result = NULL,
    }
};

