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

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

#include "ngx_capcache_module.h"

static u_char ngx_capcache_body[] = { '<', 'C', 'A', 'P', 'C', 'A', 'C', 'H', 'E', '>', LF };

/* capcache config data */
typedef struct ngx_capcache_loc_conf 
{
    ngx_flag_t capcache_enable;
    ngx_shm_zone_t *cache;
} ngx_capcache_loc_conf_t, *ngx_capcache_loc_conf_p;

typedef struct ngx_capcache_ctx 
{
    ngx_uint_t http_status;
    ngx_uint_t is_cached;
} ngx_capcache_ctx_t, *ngx_capcache_ctx_p;

static ngx_http_output_header_filter_pt  ngx_http_next_header_filter;
static ngx_http_output_body_filter_pt    ngx_http_next_body_filter;

static void *ngx_capcache_create_loc_conf(ngx_conf_t *cf);
static char *ngx_capcache_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child);
static ngx_int_t ngx_capcache_postconfig(ngx_conf_t *cf);
static char *ngx_capcache_path_conf_slot(ngx_conf_t *cf, ngx_command_t *cmd, void *conf);


static ngx_command_t ngx_capcache_commands[] = {
    { 
        ngx_string("capcache"),
        NGX_HTTP_LOC_CONF|NGX_CONF_FLAG,
        ngx_conf_set_flag_slot,
        NGX_HTTP_LOC_CONF_OFFSET,
        offsetof(ngx_capcache_loc_conf_t, capcache_enable),
        NULL 
    },
 
    { 
        ngx_string("capcache_path"),
        NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
        ngx_capcache_path_conf_slot,
        NGX_HTTP_LOC_CONF_OFFSET,
        0,
        NULL 
    },
 
    ngx_null_command
};

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


extern ngx_module_t ngx_http_proxy_module;

#if 0
static ngx_int_t
ngx_http_proxy_handler_my(ngx_http_request_t *r)
{
    ngx_int_t                   rc;
    ngx_http_upstream_t        *u;
    ngx_http_proxy_ctx_t       *ctx;
    //ngx_http_proxy_loc_conf_t  *plcf;

    if (ngx_http_upstream_create(r) != NGX_OK) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    /*
    ctx = ngx_pcalloc(r->pool, sizeof(ngx_http_proxy_ctx_t));
    if (ctx == NULL) {
        return NGX_ERROR;
    }

    ngx_http_set_ctx(r, ctx, ngx_http_proxy_module);
    */

    plcf = ngx_http_get_module_loc_conf(r, ngx_http_proxy_module);

    u = r->upstream;

    if (plcf->proxy_lengths == NULL) {
        ctx->vars = plcf->vars;
        u->schema = plcf->vars.schema;
#if (NGX_HTTP_SSL)
        u->ssl = (plcf->upstream.ssl != NULL);
#endif

    } else {
        if (ngx_http_proxy_eval(r, ctx, plcf) != NGX_OK) {
            return NGX_HTTP_INTERNAL_SERVER_ERROR;
        }
    }

    u->output.tag = (ngx_buf_tag_t) &ngx_http_proxy_module;

    u->conf = &plcf->upstream;

#if (NGX_HTTP_CACHE)
    u->create_key = ngx_http_proxy_create_key;
#endif
    u->create_request = ngx_http_proxy_create_request;
    u->reinit_request = ngx_http_proxy_reinit_request;
    u->process_header = ngx_http_proxy_process_status_line;
    u->abort_request = ngx_http_proxy_abort_request;
    u->finalize_request = ngx_http_proxy_finalize_request;
    r->state = 0;

    if (plcf->redirects) {
        u->rewrite_redirect = ngx_http_proxy_rewrite_redirect;
    }

    if (plcf->cookie_domains || plcf->cookie_paths) {
        u->rewrite_cookie = ngx_http_proxy_rewrite_cookie;
    }

    u->buffering = plcf->upstream.buffering;

    u->pipe = ngx_pcalloc(r->pool, sizeof(ngx_event_pipe_t));
    if (u->pipe == NULL) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    u->pipe->input_filter = ngx_http_proxy_copy_filter;
    u->pipe->input_ctx = r;

    u->input_filter_init = ngx_http_proxy_input_filter_init;
    u->input_filter = ngx_http_proxy_non_buffered_copy_filter;
    u->input_filter_ctx = r;

    u->accel = 1;

    rc = ngx_http_read_client_request_body(r, ngx_http_upstream_init);

    if (rc >= NGX_HTTP_SPECIAL_RESPONSE) {
        return rc;
    }

    return NGX_DONE;
}
#endif

static char *
ngx_capcache_path_conf_slot(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_capcache_loc_conf_t *cclcf = conf;
    ngx_http_core_loc_conf_t *clcf;

    ngx_str_t *value;

    value = cf->args->elts;

    if (cclcf->cache != NGX_CONF_UNSET_PTR) {
        return "shm cache is exist";
    }

    if (ngx_strcmp(value[1].data, "off") == 0) {
        cclcf->cache = NULL;
        return NGX_CONF_OK;
    }

    cclcf->cache = ngx_shared_memory_add(cf, &value[1], 0, &ngx_http_proxy_module);
    if (cclcf->cache == NULL) {
        return NGX_CONF_ERROR;
    }

    clcf = ngx_http_conf_get_module_loc_conf(cf, ngx_http_core_module);
    //clcf->handler = ngx_http_proxy_handler_my;
    clcf->handler = NULL;

    return NGX_CONF_OK;
}

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

static void
ngx_http_file_cache_cleanup_my(void *data)
{
    ngx_http_cache_t  *c = data;

    if (c->updated) {
        return;
    }

    ngx_log_debug0(NGX_LOG_DEBUG_HTTP, c->file.log, 0,
                   "http file cache cleanup");

    if (c->updating) {
        ngx_log_error(NGX_LOG_ALERT, c->file.log, 0,
                      "stalled cache updating, error:%ui", c->error);
    }

    ngx_http_file_cache_free(c, NULL);
}

static ngx_int_t
ngx_http_file_cache_name_my(ngx_http_request_t *r, ngx_path_t *path)
{
    u_char            *p;
    ngx_http_cache_t  *c;

    c = r->cache;

    if (c->file.name.len) {
        return NGX_OK;
    }

    c->file.name.len = path->name.len + 1 + path->len
                       + 2 * NGX_HTTP_CACHE_KEY_LEN;

    c->file.name.data = ngx_pnalloc(r->pool, c->file.name.len + 1);
    if (c->file.name.data == NULL) {
        return NGX_ERROR;
    }

    ngx_memcpy(c->file.name.data, path->name.data, path->name.len);

    p = c->file.name.data + path->name.len + 1 + path->len;
    p = ngx_hex_dump(p, c->key, NGX_HTTP_CACHE_KEY_LEN);
    *p = '\0';

    ngx_create_hashed_filename(path, c->file.name.data, c->file.name.len);

    ngx_log_debug1(NGX_LOG_DEBUG_HTTP, r->connection->log, 0,
                   "cache file: \"%s\"", c->file.name.data);

    return NGX_OK;
}

static ngx_int_t
ngx_capcache_body_filter(ngx_http_request_t *r, ngx_chain_t *in)
{
    ngx_int_t rc;
    ngx_http_cache_t *c;
    ngx_http_upstream_t *u;
    ngx_capcache_ctx_t *ctx;
    u_char *pbuf = NULL;
    u_char *buf = NULL;
    size_t len;
    ngx_buf_t buf_to_file;
    ngx_chain_t chain;
    ngx_temp_file_t tf;
    ngx_ext_rename_file_t ext;
    ngx_file_info_t fi;
    ngx_pool_cleanup_t *cln;
    ngx_capcache_loc_conf_t *conf;

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

    conf = ngx_http_get_module_loc_conf(r, ngx_capcache_module);

    /**
     * 1. create buf chain
     */
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
        c->file_cache = conf->cache->data;
    }

    len = c->header_start + sizeof(ngx_capcache_body);
    buf = ngx_pcalloc(r->pool, len);
    if (buf == NULL) {
        goto out;
    }

    /* set file header */
    /* timeout when next request */
    c->valid_sec = ngx_time() - 1;
    ngx_http_file_cache_set_header(r, buf);
    pbuf = buf + c->header_start;
    pbuf = ngx_cpymem(pbuf, ngx_capcache_body, sizeof(ngx_capcache_body));

    /**
     * 2. write cache file
     */
    ngx_memzero(&buf_to_file, sizeof(ngx_buf_t));
    buf_to_file.pos = buf;
    buf_to_file.start = buf;
    buf_to_file.last = pbuf;
    buf_to_file.end = pbuf;
    buf_to_file.memory = 1;
    buf_to_file.last_buf = 1;
    chain.buf = &buf_to_file;
    chain.next = NULL;

    ngx_memzero(&tf, sizeof(ngx_temp_file_t));
    tf.file.fd = NGX_INVALID_FILE;
    tf.file.log = r->connection->log;
    tf.path = u->conf->temp_path;
    tf.pool = r->pool;
    tf.persistent = 1;
    if (ngx_write_chain_to_temp_file(&tf, &chain) == NGX_ERROR) {
        goto out;
    }
 
    /**
     * 3. move cache file
     */
    ngx_memzero(&ext, sizeof(ngx_ext_rename_file_t));
    ext.access = NGX_FILE_OWNER_ACCESS;
    ext.path_access = NGX_FILE_OWNER_ACCESS;
    ext.time = -1;
    ext.create_path = 1;
    ext.delete_file = 1;
    ext.log = r->connection->log;

    ngx_http_file_cache_name_my(r, c->file_cache->path); 
    rc = ngx_ext_rename_file(&tf.file.name, &c->file.name, &ext);
    if (rc == NGX_OK) {
        if (ngx_fd_info(tf.file.fd, &fi) == NGX_FILE_ERROR) {
            ngx_log_error(NGX_LOG_CRIT, r->connection->log, ngx_errno,
                          ngx_fd_info_n " \"%s\" failed", tf.file.name.data);
            rc = NGX_ERROR;
        }
    }
    
    /**
     * 4. insert into rbtree
     */
    //ngx_http_file_cache_add_file(ngx_tree_ctx_t *ctx, ngx_str_t *name)
    

    /**
     * 5. clean cache file
     */
    cln = ngx_pool_cleanup_add(r->pool, 0);
    if (cln == NULL) {
        goto out;
    }

    cln->handler = ngx_http_file_cache_cleanup_my;
    cln->data = c;

    //ngx_http_file_cache_free(r->cache, tf);

      
    /* 打开缓存文件 */
    //if (ngx_open_cached_file(clcf->open_file_cache, &path, &of, r->pool)

    /* flag already done */
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
    conf->cache = NGX_CONF_UNSET_PTR;
    return conf;
}

static char *
ngx_capcache_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_capcache_loc_conf_t *prev = parent;
    ngx_capcache_loc_conf_t *conf = child;

    ngx_conf_merge_value(conf->capcache_enable, prev->capcache_enable, 0);

    //ngx_conf_log_error(NGX_LOG_EMERG, cf, 0, "capcache is %d", conf->capcache_enable);

    return NGX_CONF_OK;
}

