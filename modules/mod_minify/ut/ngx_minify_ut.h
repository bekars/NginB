/*
 * =====================================================================================
 *
 *    Description:  
 *
 *        Version:  1.0
 *        Created:  08/17/2012 05:38:49 PM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  baiyu (bekars), bekars@gmail.com
 *        Company:  BW
 *
 * =====================================================================================
 */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "ngx_http_minify_filter_module.h"

typedef struct ngx_minify_ut_data
{
    char *ut_name;
    char *ut_data[128];
    char *ut_result;
} ngx_minify_ut_data_s, *ngx_minify_ut_data_p;

ngx_minify_ut_data_s html_ut_data[1024];
ngx_minify_ut_data_s css_ut_data[1024];
ngx_minify_ut_data_s js_ut_data[1024];

