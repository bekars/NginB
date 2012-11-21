/*
 * =====================================================================================
 *
 *    Description:  nginx capture cache module main routine
 *
 *        Version:  1.0
 *        Created:  11/21/2012 09:19:09 AM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  bekars <bekars@gmail.com>
 *        Company:  
 *
 * =====================================================================================
 */

#include "ngx_capcache_module.h"

/* capcache config data */
typedef struct ngx_capcache_loc_conf 
{
    ngx_flag_t capcache_enable;
} ngx_capcache_loc_conf_t, *ngx_capcache_loc_conf_p;

typedef struct ngx_capcache_ctx 
{
    ngx_uint_t http_status;
} ngx_capcache_ctx_t, *ngx_capcache_ctx_p;


static ngx_command_t ngx_capcache_commands[] = {
    { 
        ngx_string("capcache"),
        NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_FLAG,
        ngx_conf_set_flag_slot,
        NGX_HTTP_LOC_CONF_OFFSET,
        offsetof(ngx_capcache_conf_t, capcache_enable),
        NULL 
    },
 
    ngx_null_command
};

static void *ngx_capcache_create_loc_conf(ngx_conf_t *cf);
static char *ngx_capcache_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child);
static ngx_int_t ngx_capcache_postconfig(ngx_conf_t *cf);

/* define config init & merge cb function */
static ngx_http_module_t ngx_capcache_module_ctx = {
    NULL,                         /* preconfiguration */
    ngx_capcache_postconfig,      /* postconfiguration */

    NULL,                         /* create main configuration */
    NULL,                         /* init main configuration */

    NULL,                         /* create server configuration */
    NULL,                         /* merge server configuration */

    ngx_capcache_create_loc_conf, /* create location configuration */
    ngx_capcache_merge_loc_conf   /* merge location configuration */
};

/* connect config and cb dirctives */
ngx_module_t  ngx_http_minify_filter_module = {
    NGX_MODULE_V1,
    &ngx_capcache_module_ctx,              /* module context */
    ngx_capcache_commands,                 /* module directives */
    NGX_HTTP_MODULE,                       /* module type */
    NULL,                                  /* init master */
    NULL,                                  /* init module */
    NULL,                                  /* init process */
    NULL,                                  /* init thread */
    NULL,                                  /* exit thread */
    NULL,                                  /* exit process */
    NULL,                                  /* exit master */
    NGX_MODULE_V1_PADDING
};

static ngx_http_output_header_filter_pt  ngx_http_next_header_filter;
static ngx_http_output_body_filter_pt    ngx_http_next_body_filter;

static ngx_int_t
ngx_capcache_header_filter(ngx_http_request_t *r)
{
    ngx_minify_conf_t  *conf;
    ngx_minify_ctx_t   *ctx;
    ngx_minify_type_e type = MINIFY_FILE_TYPE_NONE;

    conf = ngx_http_get_module_loc_conf(r, ngx_http_minify_filter_module);

    if ((!conf->html_enable && !conf->css_enable && !conf->js_enable)
        || (r->headers_out.status != NGX_HTTP_OK
            && r->headers_out.status != NGX_HTTP_FORBIDDEN
            && r->headers_out.status != NGX_HTTP_NOT_FOUND)
        || r->header_only
        || r->headers_out.content_type.len == 0
        || (r->headers_out.content_encoding
            && r->headers_out.content_encoding->value.len))
    {
        return ngx_http_next_header_filter(r);
    }

    if (conf->html_enable && (ngx_http_test_content_type(r, &conf->html_types) != NULL))
    {
        type = MINIFY_FILE_TYPE_HTML;
    } else if (conf->js_enable && (ngx_http_test_content_type(r, &conf->js_types) != NULL)) 
    {
        type = MINIFY_FILE_TYPE_JS;
    } else if (conf->css_enable && (ngx_http_test_content_type(r, &conf->css_types) != NULL))
    {
        type = MINIFY_FILE_TYPE_CSS;
    } else
    {
        return ngx_http_next_header_filter(r);
    }

    ctx = ngx_pcalloc(r->pool, sizeof(ngx_minify_ctx_t));
    if (ctx == NULL) {
        return NGX_ERROR;
    }
    
    ctx->type = type;

    ngx_http_set_ctx(r, ctx, ngx_http_minify_filter_module);

    ngx_http_clear_content_length(r);
    ngx_http_clear_accept_ranges(r);

    r->filter_need_in_memory = 1;
    r->main_filter_need_in_memory = 1;

    return ngx_http_next_header_filter(r);
}

static ngx_int_t
ngx_http_minify_body_filter(ngx_http_request_t *r, ngx_chain_t *in)
{
    ngx_minify_ctx_t *ctx;
    ngx_chain_t *chain_link;
    ngx_minify_process_f pf = NULL;
    u_char *newbuf = NULL;
    int buflen = 0;
    
    if (in == NULL || r->header_only) {
        goto out;
    }

    ctx = ngx_http_get_module_ctx(r, ngx_http_minify_filter_module);
    if (ctx == NULL) {
        goto out;
    }

    pf = ngx_http_minify_process[ctx->type];
    if (!pf) {
        goto out;
    }

    for (chain_link = in; chain_link; chain_link = chain_link->next) {
        
        buflen = ngx_buf_size(chain_link->buf);

        /* if cache exist, malloc new buf */
        if (ctx->cachelen) {
            /* pcalloc new buf */
            newbuf = ngx_palloc(r->pool, ctx->cachelen + buflen);
            if (newbuf == NULL){
                goto out;
            }
                
            ngx_memcpy(newbuf, ctx->cache, ctx->cachelen);
            ngx_memcpy(newbuf + ctx->cachelen, chain_link->buf->pos, buflen);

            /* TODO: need ngx_pfree old buf? */

            /* assign new buf pointer */
            chain_link->buf->start = newbuf;
            chain_link->buf->pos = newbuf;
            chain_link->buf->end = newbuf + ctx->cachelen + buflen;
            chain_link->buf->last = chain_link->buf->end;

            /* clear ctx cache */
            ctx->cachelen = 0;
        }

        (*pf)(chain_link->buf, ctx);
        
        /* send buf from memory */
        chain_link->buf->in_file = 0;
    }

out:
    return ngx_http_next_body_filter(r, in);
}


static ngx_int_t 
ngx_capcache_postconfig(ngx_conf_t *cf)
{
    ngx_http_next_header_filter = ngx_http_top_header_filter;
    ngx_http_top_header_filter = ngx_capcache_header_filter;

    ngx_http_next_body_filter = ngx_http_top_body_filter;
    ngx_http_top_body_filter = ngx_capcache_body_filter;

    return NGX_OK;
}

static void *
ngx_capcache_create_loc_conf(ngx_conf_t *cf)
{
    ngx_capcache_loc_conf_t *conf = NULL;

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_capcache_loc_conf_t));
    if (conf == NULL) {
        return NGX_CONF_ERROR;
    }

    conf->capcache_enable = NGX_CONF_UNSET;
    return conf;
}

static char *
ngx_capcache_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_capcache_loc_conf_t *prev = parent;
    ngx_capcache_loc_conf_t *conf = child;

    ngx_conf_merge_value(conf->capcache_enable, prev->capcache_enable, 0);

    ngx_conf_log_error(NGX_LOG_EMERG, cf, 0,
                       "capcache is %d", conf->capcache_enable);

    return NGX_CONF_OK;
}

