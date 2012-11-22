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

static u_char ngx_capcache_body[] = { '<', 'C', 'A', 'P', 'C', 'A', 'C', 'H', 'E', '>' };

/* capcache config data */
typedef struct ngx_capcache_loc_conf 
{
    ngx_flag_t capcache_enable;
} ngx_capcache_loc_conf_t, *ngx_capcache_loc_conf_p;

typedef struct ngx_capcache_ctx 
{
    ngx_uint_t http_status;
    ngx_uint_t is_cached;
} ngx_capcache_ctx_t, *ngx_capcache_ctx_p;


static ngx_command_t ngx_capcache_commands[] = {
    { 
        ngx_string("capcache"),
        NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_FLAG,
        ngx_conf_set_flag_slot,
        NGX_HTTP_LOC_CONF_OFFSET,
        offsetof(ngx_capcache_loc_conf_t, capcache_enable),
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

/* connect config and cb dirctives, must same as module name */
ngx_module_t ngx_capcache_module = {
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
    ngx_capcache_loc_conf_t *conf;
    ngx_capcache_ctx_t *ctx;

    ngx_http_upstream_t *u;
    u = r->upstream;
#if (NGX_HTTP_CACHE)

    if (u->conf->cache) {
        /* DO IT */
    }

#endif

    if ((r->headers_out.status != 304) && 
        (r->headers_out.status != 200)) {
        goto out;
    }

    conf = ngx_http_get_module_loc_conf(r, ngx_capcache_module);

    /* capcache is enable or not */
    if (!conf->capcache_enable) {
        return ngx_http_next_header_filter(r);
    }

    ctx = ngx_pcalloc(r->pool, sizeof(ngx_capcache_ctx_t));
    if (ctx == NULL) {
        return NGX_ERROR;
    }
    
    ngx_http_set_ctx(r, ctx, ngx_capcache_module);
    
    ctx->http_status = r->headers_out.status;
    ctx->is_cached = 0;

out:
    return ngx_http_next_header_filter(r);
}

static ngx_int_t
ngx_capcache_body_filter(ngx_http_request_t *r, ngx_chain_t *in)
{
    ngx_http_cache_t *c;
    ngx_http_upstream_t *u;
    ngx_capcache_ctx_t *ctx;
    u_char *p = NULL;
    u_char *buf = NULL;
    size_t len;
 
    if (in == NULL) {
        goto out;
    }

    ctx = ngx_http_get_module_ctx(r, ngx_capcache_module);
    if (ctx == NULL) {
        goto out;
    }

    if (ctx->is_cached) {
        goto out;
    }

    /* 1. create buf chain */
    c = r->cache;
    u = r->upstream;
    /* get crc32 & key */
    if (c == NULL) {
        if (ngx_http_file_cache_new(r) != NGX_OK) {
            goto out;
        }

        if (u->create_key(r) != NGX_OK) {  /* ngx_http_proxy_create_key */
            goto out;
        }

        ngx_http_file_cache_create_key(r);
    
        c = r->cache;
    }

    len = c->header_start + sizeof(ngx_capcache_body);
    buf = ngx_pcalloc(r->pool, len);
    if (buf == NULL) {
        return NGX_ERROR;
    }

    /* set file header */
    c->valid_sec = ngx_time() - 1;
    ngx_http_file_cache_set_header(r, buf);
    p = buf + c->header_start;
    p = ngx_cpymem(p, ngx_capcache_body, sizeof(ngx_capcache_body));

    p = buf;
    /* 2. write cache file */
    //ngx_write_chain_to_temp_file(ngx_temp_file_t *tf, ngx_chain_t *chain)
    
    /* 3. move cache file */
    
    /* 4. insert into rbtree */

    ctx->is_cached = 1;
    ngx_log_error(NGX_LOG_ERR, r->connection->log, 0,
                  "### http status: %d ###", ctx->http_status);

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

