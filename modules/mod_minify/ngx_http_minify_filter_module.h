/*
 * =====================================================================================
 *
 *    Description:  nginx minify module main routine
 *
 *        Version:  1.0
 *        Created:  08/16/2012 09:55:40 AM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  baiyu <yu.bai@unlun.com>
 *        Company:  http://www.anquanbao.com/
 *
 * =====================================================================================
 */

#ifndef __NGX_HTTP_MINIFY_FILTER_MODULE_H__
#define __NGX_HTTP_MINIFY_FILTER_MODULE_H__

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

#include <ctype.h>

//#define MINIFY_DEBUG

typedef enum 
{
    MINIFY_FILE_TYPE_NONE = 0,
    MINIFY_FILE_TYPE_HTML,
    MINIFY_FILE_TYPE_CSS,
    MINIFY_FILE_TYPE_JS,
    MINIFY_FILE_TYPE_MAX,
} ngx_minify_type_e;

typedef enum 
{ 
    minify_state_text = 0,
    minify_state_abort,

    html_state_skip,
    html_state_tag,
    html_state_tag_bang,
    html_state_comment,
    html_state_comment_ie,
    html_state_comment_skip,
    html_state_tagname,
    html_state_tagatt,
    html_state_tagname_end,
    html_state_cdata,

    css_state_comment,
    css_state_quote,
    css_state_brace,

    js_state_skip,
    js_state_comment,
    js_state_comment_line,
    js_state_quote,

} ngx_minify_state_e;

typedef unsigned int u_int;

#define CTX_CACHE_BUFLEN 64
#define CTX_STATE_STACK  8
typedef struct ngx_minify_ctx
{
    ngx_minify_type_e type;
    ngx_minify_state_e state[CTX_STATE_STACK];  /* state stack, not over 16 */
    int sspos;                                  /* state stack pos */
    
    int dstlen;
    int count;

    const u_char *rpos;
    u_char       *wpos;

    u_char quote_char;
    u_char pre_char;
    u_char pre_char2;
    u_char nochange_pre;

    int cachelen;
    char cache[CTX_CACHE_BUFLEN];
    
    int tagcachelen;
    char tagcache[CTX_CACHE_BUFLEN];
    
    int tagendcachelen;
    char tagendcache[CTX_CACHE_BUFLEN];
 
} ngx_minify_ctx_t, *ngx_minify_ctx_p;

#define CTX_CLEAR_STATE(c)      (c)->sspos = -1;
#define CTX_STATE(c)            (c)->state[(c)->sspos]
#define CTX_UP_STATE(c)         (c)->state[(c)->sspos - 1]

#ifdef MINIFY_DEBUG
#define CTX_PUSH_STATE(c, s)    do { \
                                    ++(c)->sspos; \
                                    if ((c)->sspos >= CTX_STATE_STACK) printf("ERROR: ctx state stack top over!\n"); \
                                    (c)->state[(c)->sspos] = (s); \
                                } while (0)

#define CTX_POP_STATE(c)        do { \
                                    --(c)->sspos; \
                                    if ((c)->sspos < 0) printf("ERROR: ctx state stack bottom over!\n"); \
                                } while (0)
#else
#define CTX_PUSH_STATE(c, s)    (c)->state[++(c)->sspos] = (s)
#define CTX_POP_STATE(c)        --(c)->sspos
#endif

#define CTX_SET_STATE(c, s)     do {CTX_CLEAR_STATE((c)); CTX_PUSH_STATE((c), (s));} while(0)

#define CTX_TAGCACHE_CLEAR(c)   (c)->tagcachelen = 0

#ifdef MINIFY_DEBUG
#define CTX_TAGCACHE_ADD(c, a)  do { \
                                    (c)->tagcache[(c)->tagcachelen++] = (a); \
                                    if ((c)->tagcachelen >= CTX_CACHE_BUFLEN) printf("ERROR: ctx tag name cache overflow!\n"); \
                                } while (0)
#else
#define CTX_TAGCACHE_ADD(c, a)  (c)->tagcache[(c)->tagcachelen++] = (a)
#endif

#define CTX_TAGCACHE_LEN(c)     (c)->tagcachelen
#define CTX_TAGCACHE_GET(c)     (c)->tagcache
#define CTX_TAGCACHE_CLOSE(c)   (c)->tagcache[(c)->tagcachelen] = '\0'

#define CTX_TAGENDCACHE_CLEAR(c)    (c)->tagendcachelen = 0

#ifdef MINIFY_DEBUG
#define CTX_TAGENDCACHE_ADD(c, a)   do { \
                                        (c)->tagendcache[(c)->tagendcachelen++] = (a); \
                                        if ((c)->tagendcachelen >= CTX_CACHE_BUFLEN) printf("ERROR: ctx tag end name cache overflow!\n"); \
                                } while (0)
#else
#define CTX_TAGENDCACHE_ADD(c, a)   (c)->tagendcache[(c)->tagendcachelen++] = (a)
#endif

#define CTX_TAGENDCACHE_LEN(c)      (c)->tagendcachelen
#define CTX_TAGENDCACHE_GET(c)      (c)->tagendcache
#define CTX_TAGENDCACHE_CLOSE(c)    (c)->tagendcache[(c)->tagendcachelen] = '\0'

static inline void
ngx_minify_inc_rpos(ngx_minify_ctx_t *ctx)
{
    ++ctx->rpos;
    --ctx->count;
}

static inline void
ngx_minify_copy_char(ngx_minify_ctx_t *ctx, char c)
{
    *ctx->wpos++ = c;
    ++ctx->dstlen;
    ngx_minify_inc_rpos(ctx);
}

static inline void
ngx_minify_copy_rpos(ngx_minify_ctx_t *ctx)
{
    *ctx->wpos++ = *ctx->rpos;
    ++ctx->dstlen;
    ngx_minify_inc_rpos(ctx);
}

static inline void
ngx_minify_dec_wpos(ngx_minify_ctx_t *ctx)
{
    if (ctx->dstlen) {
        --ctx->dstlen;
        --ctx->wpos;
    }
}

/* ctx->count must <= strlen(c) */
static inline int
ngx_minify_cache(const char *c, ngx_minify_ctx_t *ctx)
{
    int i;

    for (i = 0; i < ctx->count; ++i) {
        if (tolower(*(c + i)) == tolower(*(ctx->rpos + i))) {
            ctx->cache[ctx->cachelen++] = *(ctx->rpos + i);
        } else {
            ctx->cachelen -= i;
            return -1;
        }

        if (ctx->cachelen >= CTX_CACHE_BUFLEN)
            return -2;
    }

    return i;
}


typedef void (*ngx_minify_process_f)(ngx_buf_t *b, ngx_minify_ctx_t *ctx);

void ngx_minify_html_process(ngx_buf_t *b, ngx_minify_ctx_t *ctx);
void ngx_minify_css_process(ngx_buf_t *b, ngx_minify_ctx_t *ctx);
void ngx_minify_js_process(ngx_buf_t *b, ngx_minify_ctx_t *ctx);

#endif /* __NGX_HTTP_MINIFY_FILTER_MODULE_H__ */

