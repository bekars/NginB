
#include "ngx_minify_ut.h"

ngx_minify_ut_data_s html_ut_data[1024] = 
{
#if 0
    {
        .ut_name = "测试skip tag标签退出",
        .ut_data = {"<h><script j/>\n<!-- strip comment -->", "\n</h>", NULL},
        .ut_result = "<h><script>  javascript </script></h>",
    },

#else
    {
        .ut_name = "测试DOCTYPE标签",
        .ut_data = {"<!DOCTYPE  html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n<html> </html>\n", NULL},
        .ut_result = "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"><html> </html>",
    },

    {
        .ut_name = "测试DOCTYPE标签跨buf",
        .ut_data = {"<", "!", "D", "OCTYPE  html>\n<html> </html>\n", NULL},
        .ut_result = "<!DOCTYPE html><html> </html>",
    },

    {
        .ut_name = "测试压缩注释1",
        .ut_data = {"<html> <!-- this is comment --> </html>\n", NULL},
        .ut_result = "<html> </html>",
    },

    {
        .ut_name = "测试压缩注释2",
        .ut_data = {"<html> <!----> </html>\n", NULL},
        .ut_result = "<html> </html>",
    },

    {
        .ut_name = "测试压缩注释跨buf",
        .ut_data = {"<html> <", "!", "-", "- this is comment ", "-", "-", "> ", "</html>\n", NULL},
        .ut_result = "<html> </html>",
    },

    {
        .ut_name = "测试压缩注释，注释内包含干扰内容",
        .ut_data = {"<html> <", "!", "-", "- this is comment -a ", "-", "-", "b", " --> ", "</html>\n", NULL},
        .ut_result = "<html> </html>",
    },

    {
        .ut_name = "测试IE注释",
        .ut_data = {"<html> <!--[if IE 9]> IE 9 CSS <![endif]--> </html>\n", NULL},
        .ut_result = "<html> <!--[if IE 9]> IE 9 CSS <![endif]--></html>",
    },

    {
        .ut_name = "测试IE注释，跨buf",
        .ut_data = {"<html> ", "<", "!", "-", "-", "[", "i", "f", " IE 9]> IE 9 CSS <![endi", "f", "]", "-", "-", ">", " </html>\n", NULL},
        .ut_result = "<html> <!--[if IE 9]> IE 9 CSS <![endif]--></html>",
    },

    {
        .ut_name = "测试IE注释，注释内包含干扰内容",
        .ut_data = {"<html> ", "<", "!", "-", "-", "[", "i", "f", " IE 9]> IE 9 CSS ]--a <![endi", "f", "]", "-", "-", ">", " </html>\n", NULL},
        .ut_result = "<html> <!--[if IE 9]> IE 9 CSS ]--a <![endif]--></html>",
    },

    {
        .ut_name = "测试不正确IE注释，跨buf",
        .ut_data = {"<html> ", "<", "!", "-", "-", "[", "i", "p", " IE 9]> IE 9 CSS <![endi", "f", "]", "-", "-", ">", " </html>\n", NULL},
        .ut_result = "<html> </html>",
    },

    {
        .ut_name = "测试CDATA数据",
        .ut_data = {"<html>\n <![CDATA[ a > b ]]>\n </html>\n", NULL},
        .ut_result = "<html> <![CDATA[ a > b ]]> </html>",
    },

    {
        .ut_name = "测试CDATA数据跨buf",
        .ut_data = {"<html>\n <", "!", "[", "C", "D", "A", "T", "A", "[", " a > b ", "]", "]", ">\n", " </html>\n", NULL},
        .ut_result = "<html> <![CDATA[ a > b ]]> </html>",
    },

    {
        .ut_name = "测试CDATA数据，包含干扰数据",
        .ut_data = {"<html>\n <![CDATA[ a > b; ']]' ]]>\n </html>\n", NULL},
        .ut_result = "<html> <![CDATA[ a > b; ']]' ]]> </html>",
    },

    {
        .ut_name = "测试删除文本多余空格和换行",
        .ut_data = {"<h>\n <!-- b -->\n   strip   space   </h>\n", NULL},
        .ut_result = "<h> strip space </h>",
    },

    {
        .ut_name = "测试删除文本多余空格和换行，跨buf",
        .ut_data = {"<h>\n <!-- b -->\n", "   strip ", "  space  ", "   </h>\n", NULL},
        .ut_result = "<h> strip space </h>",
    },

    {
        .ut_name = "测试tag名字压缩",
        .ut_data = {"<h>\n\t<abc>\n\t    test    \n</abc>\n</h>\n", NULL},
        .ut_result = "<h><abc> test </abc></h>",
    },
    
    {
        .ut_name = "测试pre tag名字大小写",
        .ut_data = {"<h>\n\t<PrE>\n\t test \n</PrE>\n</h>\n", NULL},
        .ut_result = "<h><PrE>\n\t test \n</PrE></h>",
    },
    
    {
        .ut_name = "测试pre tag名字跨buf",
        .ut_data = {"<h>", "<", "P", "R", "e", ">", " test ", "<", "/", "P", "R", "e", ">", "\n</h>", NULL},
        .ut_result = "<h><PRe> test </PRe></h>",
    },

    {
        .ut_name = "测试script tag名字大小写",
        .ut_data = {"<h>\n\t<SCript>\n\t if (a == b) \n</SCript>\n</h>\n", NULL},
        .ut_result = "<h><SCript>\n\t if (a == b) \n</SCript></h>",
    },
    
    {
        .ut_name = "测试script tag名字跨buf",
        .ut_data = {"<h>", "<", "s", "c", "r", "i", "p", "t", ">", " test ", "<", "/", "s", "c", "r", "i", "p", "t", ">", "\n</h>", NULL},
        .ut_result = "<h><script> test </script></h>",
    },

    {
        .ut_name = "测试style tag名字大小写",
        .ut_data = {"<h>\n\t<styLE>\n\t body {background-color: yellow} \n</styLE>\n</h>\n", NULL},
        .ut_result = "<h><styLE>\n\t body {background-color: yellow} \n</styLE></h>",
    },
    
    {
        .ut_name = "测试style tag名字跨buf",
        .ut_data = {"<h>", "<", "s", "t", "y", "l", "e", ">", " body ", "<", "/", "s", "t", "y", "l", "e", ">", "\n</h>", NULL},
        .ut_result = "<h><style> body </style></h>",
    },

    {
        .ut_name = "测试skip tag标签干扰，script标签中套标签",
        .ut_data = {"<h><script>", " </a> ", "</script>", "\n</h>", NULL},
        .ut_result = "<h><script> </a> </script></h>",
    },

    {
        .ut_name = "测试skip tag标签退出",
        .ut_data = {"<h><script>  javascript </script>\n<!-- strip comment -->", "\n</h>", NULL},
        .ut_result = "<h><script>  javascript </script></h>",
    },

    {
        .ut_name = "测试skip tag标签退出",
        .ut_data = {"<h><script javascript/>\n<!-- strip comment -->", "\n</h>", NULL},
        .ut_result = "<h><script javascript/></h>",
    },

    {
        .ut_name = "测试skip tag标签退出，跨buf",
        .ut_data = {"<h><script javascript", "/", ">\n", "<!-- strip comment -->", "\n</h>", NULL},
        .ut_result = "<h><script javascript/></h>",
    },

#endif

    {
        .ut_name = NULL,
        .ut_data = NULL,
        .ut_result = NULL,
    }
};

