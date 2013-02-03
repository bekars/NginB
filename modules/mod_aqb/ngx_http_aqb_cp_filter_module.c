#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>


/* minify config data */
typedef struct ngx_http_aqb_cp_conf 
{
	ngx_flag_t      cp_enable;
	ngx_array_t    *plugins;
} ngx_http_aqb_cp_conf_t;


/* the sub ctx data */
typedef struct
{
	int ok;
} ngx_http_aqb_cp_ctx_t;

static char *ngx_http_aqb_cp_load_plugin(ngx_conf_t *cf, ngx_command_t *cmd, void *conf);

/* command */
static ngx_command_t ngx_http_aqb_cp_filter_commands[] = {
    { 
        ngx_string("coolplay"),
        NGX_HTTP_LOC_CONF|NGX_CONF_FLAG|NGX_CONF_TAKE1,
		ngx_conf_set_flag_slot,
        NGX_HTTP_LOC_CONF_OFFSET,
		offsetof(ngx_http_aqb_cp_conf_t, cp_enable),
        NULL 
    },
	{
		ngx_string("cp_plugin"),
		NGX_HTTP_LOC_CONF|NGX_CONF_1MORE,
		ngx_http_aqb_cp_load_plugin,
		NGX_HTTP_LOC_CONF_OFFSET,
		0,
		NULL
	},
    
    ngx_null_command
};


static void *ngx_http_aqb_cp_create_conf(ngx_conf_t *cf);
static char *ngx_http_aqb_cp_merge_conf(ngx_conf_t *cf, void *parent, void *child);
static ngx_int_t ngx_http_aqb_cp_filter_init(ngx_conf_t *cf);

static ngx_http_module_t ngx_http_aqb_cp_filter_module_ctx = {
    NULL,                              /* preconfiguration */
    ngx_http_aqb_cp_filter_init,       /* postconfiguration */

    NULL,                              /* create main configuration */
    NULL,                              /* init main configuration */

    NULL,                              /* create server configuration */
    NULL,                              /* merge server configuration */

    ngx_http_aqb_cp_create_conf,       /* create location configuration */
    ngx_http_aqb_cp_merge_conf         /* merge location configuration */
};


ngx_module_t  ngx_http_aqb_cp_filter_module = {
    NGX_MODULE_V1,
    &ngx_http_aqb_cp_filter_module_ctx,     /* module context */
    ngx_http_aqb_cp_filter_commands,        /* module directives */
    NGX_HTTP_MODULE,                        /* module type */
    NULL,                                   /* init master */
    NULL,                                   /* init module */
    NULL,                                   /* init process */
    NULL,                                   /* init thread */
    NULL,                                   /* exit thread */
    NULL,                                   /* exit process */
    NULL,                                   /* exit master */
    NGX_MODULE_V1_PADDING
};

static ngx_http_output_header_filter_pt  ngx_http_next_header_filter;
static ngx_http_output_body_filter_pt    ngx_http_next_body_filter;

static ngx_int_t ngx_http_aqb_cp_header_filter(ngx_http_request_t *r);
static ngx_int_t ngx_http_aqb_cp_body_filter(ngx_http_request_t *r, ngx_chain_t *in);

#define PN 10

static char *
ngx_http_aqb_cp_load_plugin(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
	/* load the plugin so */
	ngx_http_aqb_cp_conf_t *cpcf = conf;

	//ngx_str_t     *value, *p;
	//ngx_uint_t    i;

	/* init the plugin hash */
	if (cpcf->plugins == NULL) {
		cpcf->plugins = ngx_array_create(cf->temp_pool, PN, sizeof(ngx_str_t));

		if (cpcf->plugins == NULL) {
			return NGX_CONF_ERROR;
		}
	}

/*
	value = cf->args->elts;
	// push each value into plugin array 
    for( i = 1; i < cf->args->nelts && i < PN; i++ ){
		if( value[i].len == 0 ){
			return NGX_CONF_ERROR;
		}

		p  = ngx_array_push(cpcf->plugins);
		if( p == NULL ){
			return NGX_CONF_ERROR;
		}

		memcpy(p, &value[i], sizeof(ngx_str_t));
	}
*/
	return NGX_CONF_OK;
}


static ngx_int_t
ngx_http_aqb_cp_header_filter(ngx_http_request_t *r)
{
    ngx_http_aqb_cp_ctx_t   *ctx;
    ngx_http_aqb_cp_conf_t  *cpcf;

    cpcf = ngx_http_get_module_loc_conf(r, ngx_http_aqb_cp_filter_module);

	if( 
		cpcf->cp_enable == 0 
		|| cpcf->plugins == NULL
		|| cpcf->plugins->nelts == 0
		|| r->header_only
		|| (r->method & NGX_HTTP_HEAD)
		|| r != r->main
		|| r->headers_out.status == NGX_HTTP_NO_CONTENT
	){
		return ngx_http_next_header_filter(r);
	}

	ctx = ngx_pcalloc(r->pool, sizeof(ngx_http_aqb_cp_ctx_t));
	if (ctx == NULL) {
		return NGX_ERROR;
	}

	/* changing the length */
	ngx_http_clear_content_length(r);
	ngx_http_clear_accept_ranges(r);

	ngx_http_set_ctx(r, ctx, ngx_http_aqb_cp_filter_module);
	ctx->ok = 0;
    
	if (cpcf)
	{
		cpcf = NULL;
		cpcf = ngx_http_get_module_loc_conf(r, ngx_http_aqb_cp_filter_module);
		if (cpcf)
		{
			ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0, "############## coolplay filter ###############");
		}

	}
    return ngx_http_next_header_filter(r);
}


static void
ngx_http_aqb_cp_userdefine(ngx_buf_t *b, ngx_http_aqb_cp_ctx_t *ctx)
{
	int ret = 0;
	/* 这里应该返回一个通用的结果集 */
    //int ret = aqb_cp_change_title(b->pos, b->last);

	/* the function should be changed by the lib */

	if( ret ){
		ctx->ok = 1;
	}
}


static ngx_int_t
ngx_http_aqb_cp_body_filter(ngx_http_request_t *r, ngx_chain_t *in)
{
    ngx_http_aqb_cp_ctx_t *ctx;
    ngx_chain_t *chain_link, *added_link;
	int contain_last_buf = 0;
	ngx_buf_t *b;
	ngx_uint_t i;

    ngx_http_aqb_cp_conf_t  *cpcf;
	ngx_str_t *p;

	cpcf = r->loc_conf[ngx_http_aqb_cp_filter_module.ctx_index];
	//cpcf = ngx_http_get_module_loc_conf(r, ngx_http_aqb_cp_filter_module);

	//if (cpcf == r->loc_conf[ngx_http_aqb_cp_filter_module.ctx_index])
	//{	
		ngx_log_debug0(NGX_LOG_DEBUG_HTTP, r->connection->log, 0, "############## coolplay filter ###############");
	//}

    if (in == NULL || r->header_only) {
        goto out;
    }

    ctx = ngx_http_get_module_ctx(r, ngx_http_aqb_cp_filter_module);
    if (ctx == NULL ) {
        goto out;
    }

	//cpcf = ngx_http_get_module_loc_conf(r, ngx_http_aqb_cp_filter_module);

	/* begin the handle function */
    for (chain_link = in; chain_link; chain_link = chain_link->next) {
        
		ngx_http_aqb_cp_userdefine(chain_link->buf, ctx);

		if( chain_link->buf->last_buf == 1 ){
		    contain_last_buf = 1;
			break;
		}
    }

	if( contain_last_buf ){
		p = (ngx_str_t *)cpcf->plugins;
		for( i = 0; i < cpcf->plugins->nelts; i++ ){
			b = ngx_calloc_buf(r->pool);
			if (b == NULL) {
				return NGX_ERROR;
			}

			b->pos  = p[i].data;
			b->last = p[i].data + p[i].len;

			b->start = b->pos;
			b->end = b->last;
			b->memory = 1;
			b->last_buf = 1;

			if( ngx_buf_size(chain_link->buf) == 0 ){
				chain_link->buf = b;
			}
			else{
				added_link = ngx_alloc_chain_link(r->pool);
				if (added_link == NULL){
					return NGX_ERROR;
				}

				added_link->buf = b;
				added_link->next = NULL;

				chain_link->next = added_link;
				chain_link->buf->last_buf = 0;

				chain_link = added_link;
			}
		}
	}

out:
	return ngx_http_next_body_filter(r, in);
}



/* filter chain */
static ngx_int_t
ngx_http_aqb_cp_filter_init(ngx_conf_t *cf)
{
    ngx_http_next_header_filter = ngx_http_top_header_filter;
    ngx_http_top_header_filter = ngx_http_aqb_cp_header_filter;

    ngx_http_next_body_filter = ngx_http_top_body_filter;
    ngx_http_top_body_filter = ngx_http_aqb_cp_body_filter;

    return NGX_OK;
}


/* init the conf */
static void *
ngx_http_aqb_cp_create_conf(ngx_conf_t *cf)
{
    ngx_http_aqb_cp_conf_t *cpcf;

    cpcf = ngx_pcalloc(cf->pool, sizeof(ngx_http_aqb_cp_conf_t));
    if (cpcf == NULL) {
        return NGX_CONF_ERROR;
    }

	cpcf->cp_enable = NGX_CONF_UNSET;
    return cpcf;
}

/* set default conf value */
static char *
ngx_http_aqb_cp_merge_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_http_aqb_cp_conf_t *prev = parent;
    ngx_http_aqb_cp_conf_t *conf = child;

	ngx_conf_merge_value(conf->cp_enable, prev->cp_enable, 0);
    
    return NGX_CONF_OK;
}
