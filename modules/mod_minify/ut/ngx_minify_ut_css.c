
#include "ngx_minify_ut.h"

ngx_minify_ut_data_s css_ut_data[] = 
{
#if 0

#else
    {
        .ut_name = "测试去除多余空格和制表符",
        .ut_data = {"td,   ", "    tr,th{  \tfont-size: \t \t 12px;}", NULL},
        .ut_result = "td, tr,th{ font-size: 12px;}",
    },

    {
        .ut_name = "测试压缩注释",
        .ut_data = {"/* comment */\nbody{ background:#ffffff;}", NULL},
        .ut_result = "body{ background:#ffffff;}",
    },

    {
        .ut_name = "测试压缩注释，跨buf",
        .ut_data = {"bo", "/", "*", " comment ", "*", "/", "\ndy{ background:#ffffff;}", NULL},
        .ut_result = "body{ background:#ffffff;}",
    },

    {
        .ut_name = "测试压缩注释，注释中有*字符",
        .ut_data = {"body\n/*\n *line1\n /* line2\n*/\n{ background:#ffffff;}", NULL},
        .ut_result = "body{ background:#ffffff;}",
    },

    {
        .ut_name = "测试双引号",
        .ut_data = {"body  \"  quote  \"", NULL},
        .ut_result = "body \"  quote  \"",
    },

    {
        .ut_name = "测试双引号，跨buf",
        .ut_data = {"body ", "\"", "  quote  ", "\"", NULL},
        .ut_result = "body \"  quote  \"",
    },

    {
        .ut_name = "测试双引号内包含引号",
        .ut_data = {"body  \"  \\\"quote\\\"  \"", NULL},
        .ut_result = "body \"  \\\"quote\\\"  \"",
    },

    {
        .ut_name = "测试单引号",
        .ut_data = {"body  \'  quote  \'", NULL},
        .ut_result = "body \'  quote  \'",
    },

    {
        .ut_name = "测试单引号，跨buf",
        .ut_data = {"body ", "\'", "  quote  ", "\'", NULL},
        .ut_result = "body \'  quote  \'",
    },

    {
        .ut_name = "测试单引号内包含引号",
        .ut_data = {"body  \'  \\\'quote\\\'  \'", NULL},
        .ut_result = "body \'  \\\'quote\\\'  \'",
    },

    {
        .ut_name = "测试大括号中删除空格和换行",
        .ut_data = {"body\n{\n \tbackground:    #ffffff;\n}", NULL},
        .ut_result = "body{ background: #ffffff;}",
    },

    {
        .ut_name = "测试大括号中删除注释1",
        .ut_data = {"body\n{\n \tbackground: /* comment */    #ffffff;\n}", NULL},
        .ut_result = "body{ background: #ffffff;}",
    },

    {
        .ut_name = "测试大括号中删除注释2",
        .ut_data = {"body\n{\n \tbackground: /**/    #ffffff;\n}", NULL},
        .ut_result = "body{ background: #ffffff;}",
    },

    {
        .ut_name = "测试大括号中删除注释，跨buf",
        .ut_data = {"body\n{\n \tbackground: ", "/", "*", " comment ", "*", "/", "     #ffffff;\n}", NULL},
        .ut_result = "body{ background: #ffffff;}",
    },

    {
        .ut_name = "测试大括号中删除注释，跨buf",
        .ut_data = {"body\n{\n \tbackground: ", "/", "*", " comment ", "*", "/", "     #ffffff;\n}", NULL},
        .ut_result = "body{ background: #ffffff;}",
    },

    {
        .ut_name = "测试大括号中包含双引号",
        .ut_data = {"body\n{\n \tbackground: \"#ffffff\";\n}", NULL},
        .ut_result = "body{ background: \"#ffffff\";}",
    },

    {
        .ut_name = "测试大括号中包含单引号",
        .ut_data = {"body\n{\n \tbackground: \'#ffffff\';\n}", NULL},
        .ut_result = "body{ background: \'#ffffff\';}",
    },

    {
        .ut_name = "测试多行样式表",
        .ut_data = {"body\n{\n \tbackground: \'#ffffff\';\n}\n", "foot\n{\n \tcolor: \'#ffffff\';\n}", NULL},
        .ut_result = "body{ background: \'#ffffff\';}foot{ color: \'#ffffff\';}",
    },

#endif
    {
        .ut_name = NULL,
        .ut_data = NULL,
        .ut_result = NULL,
    }
};

