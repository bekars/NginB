/*
 * =====================================================================================
 *
 *    Description:  nginx css minify module
 *
 *        Version:  1.0
 *        Created:  08/16/2012 11:15:00 AM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  baiyu <yu.bai@unlun.com>
 *        Company:  http://www.anquanbao.com/
 *
 * =====================================================================================
 */

#include "ngx_http_minify_filter_module.h"


/* strip [slash]* ... *[slash] */
void
ngx_minify_css_strip_comment(ngx_minify_ctx_t *ctx)
{
    int jump_loop = 0;

    while (ctx->count) 
    {
        switch (CTX_STATE(ctx))
        {
            case css_state_comment:
                if ('*' == *ctx->rpos) {
                    if (ctx->count >= 2) {
                        if (!memcmp(ctx->rpos, "*/", strlen("*/"))) {
                            /* strip *[slash] */
                            ngx_minify_inc_rpos(ctx);
                            ngx_minify_inc_rpos(ctx);
                            CTX_POP_STATE(ctx);
                        } else {
                            /* strip '*' */
                            ngx_minify_inc_rpos(ctx);
                        }
                        break;
                    } else {
                        /* cache '*', check in next buf */
                        ngx_minify_cache("*", ctx);
                        ngx_minify_inc_rpos(ctx);
                        break;
                    }
                } else {
                    ngx_minify_inc_rpos(ctx);
                    break;
                }
                break;

            case minify_state_text:
            case css_state_brace:
            default:
                jump_loop = 1;
                break;
        }

        /* small state machine deal finish, back to main big loop */
        if (jump_loop)
            break;
    }
}

/* skip quote text */
void
ngx_minify_css_strip_quote(ngx_minify_ctx_t *ctx)
{
    int jump_loop = 0;

    while (ctx->count) 
    {
        switch (CTX_STATE(ctx))
        {
            case css_state_quote:
                /* escape char preceded by '\', etc '\'', '\"' */
                if ('\\' == *ctx->rpos) { 
                    if (ctx->count > 1) {
                        /* eat \x */
                        ngx_minify_copy_rpos(ctx);
                        ngx_minify_copy_rpos(ctx);
                    } else if (1 == ctx->count) {
                        /* cache '\\' */
                        ngx_minify_cache("\\", ctx);
                        ngx_minify_inc_rpos(ctx);
                    }
                    break;
                } else if (ctx->quote_char == *ctx->rpos) {
                    /* eat quote char */
                    ngx_minify_copy_rpos(ctx);
                    CTX_POP_STATE(ctx);
                    break;
                } else {
                    ngx_minify_copy_rpos(ctx);
                }
                break;
            
            case minify_state_text:
            case css_state_brace:
            default:
                jump_loop = 1;
                break;
        }
        
        /* small state machine deal finish, back to main big loop */
        if (jump_loop)
            break;
    }
}

/* strip brace text */
void
ngx_minify_css_strip_brace(ngx_minify_ctx_t *ctx)
{
    int jump_loop = 0;
    
    while (ctx->count) 
    {
        switch (CTX_STATE(ctx))
        {
            case css_state_brace:
                if ('}' == *ctx->rpos) {
                    /* eat '}' */
                    ngx_minify_copy_rpos(ctx);
                    CTX_SET_STATE(ctx, minify_state_text);
                    break;
                }
                /* remove ' ' and \n \t \r */
                else if (((' ' == *ctx->rpos) && (' ' == ctx->pre_char))|| 
                         '\n' == *ctx->rpos ||
                         '\r' == *ctx->rpos ||
                         '\t' == *ctx->rpos) {
                    ngx_minify_inc_rpos(ctx);
                    break;
                }
                /* remove comment */
                else if ('/' == *ctx->rpos) {
                    if (ctx->count >= (off_t)strlen("/*")) {
                        if (!memcmp(ctx->rpos, "/*", strlen("/*"))) {
                            /* strip [slash]* */
                            ngx_minify_inc_rpos(ctx);
                            ngx_minify_inc_rpos(ctx);

                            /* jump into css comment state machine */
                            CTX_PUSH_STATE(ctx, css_state_comment);
                            break;
                        } else {
                            /* eat [slash]x */
                            ngx_minify_copy_rpos(ctx);
                            ngx_minify_copy_rpos(ctx);
                            break;
                        }
                    } else if (1 == ctx->count) {
                        /* cache it '/', check in next buf */
                        ngx_minify_cache("/", ctx);
                        ngx_minify_inc_rpos(ctx);
                        break;
                    }
                }
                /* skip quoted text */ 
                else if ('"' == *ctx->rpos || '\'' == *ctx->rpos) { 
                    ctx->quote_char = *ctx->rpos;
                    /* eat quote char */
                    ngx_minify_copy_rpos(ctx);
                    /* jump into css quote state machine */
                    CTX_PUSH_STATE(ctx, css_state_quote);
                    break;
                }
                else {
                    ngx_minify_copy_rpos(ctx);
                }
                break;
                    
            case css_state_quote:
                ngx_minify_css_strip_quote(ctx);
                break;
                            
            case css_state_comment:
                ctx->nochange_pre = 1;
                ngx_minify_css_strip_comment(ctx);
                break;

            case minify_state_text:
            default:
                jump_loop = 1;
                break;
        }
        
        /* small state machine deal finish, back to main big loop */
        if (jump_loop)
            break;
        
        if (!ctx->nochange_pre) {
            if (ctx->dstlen >= 2) {
                ctx->pre_char = *(ctx->wpos - 1);
                ctx->pre_char2 = *(ctx->wpos - 2);
            } else if (1 == ctx->dstlen) {
                ctx->pre_char = *(ctx->wpos - 1);
                ctx->pre_char2 = '\0';
            }
        }
    }
}

void
ngx_minify_css_strip_buffer(const u_char *src, off_t srclen, u_char *dst, ngx_minify_ctx_t *ctx)
{
    ctx->rpos = src;
    ctx->wpos = dst;
    ctx->count = srclen;

    if (ctx->count < 0) {
        CTX_SET_STATE(ctx, minify_state_abort);
        return;
    }

    while (ctx->count > 0) 
    {
        switch (CTX_STATE(ctx))
        {
            case minify_state_abort:
                /* something error, copy remain data */
                ngx_minify_copy_rpos(ctx);
                break;

            case minify_state_text:
                /* text state record pre_char */
                ctx->nochange_pre = 0;

                /* strip connect ' ' and '\t' */
                if ((' ' == *ctx->rpos) || ('\t' == *ctx->rpos)) {
                    if ((' ' == ctx->pre_char) || ('\t' == ctx->pre_char)) {
                        ngx_minify_inc_rpos(ctx);
                    } else {
                        ngx_minify_copy_rpos(ctx);
                    }
                    break;
                }
                /* deal slash */
                else if ('/' == *ctx->rpos) { 
                    if (ctx->count >= 2) {
                        if (!memcmp(ctx->rpos, "/*", strlen("/*"))) {
                            /* strip [slash]* */
                            ngx_minify_inc_rpos(ctx);
                            ngx_minify_inc_rpos(ctx);
                            /* jump into css comment state machine */
                            CTX_PUSH_STATE(ctx, css_state_comment);
                            break;
                        } else {
                            /* eat [slash]x */
                            ngx_minify_copy_rpos(ctx);
                            ngx_minify_copy_rpos(ctx);
                            break;
                        }
                    } else {
                        /* cache it '/', check in next buf */
                        ngx_minify_cache("/", ctx);
                        ngx_minify_inc_rpos(ctx);
                        break;
                    }
                }
                /* skip quoted text */
                else if ('"' == *ctx->rpos || '\'' == *ctx->rpos) {
                    ctx->quote_char = *ctx->rpos;
                    /* eat '"' or '\'' */
                    ngx_minify_copy_rpos(ctx);
                    CTX_PUSH_STATE(ctx, css_state_quote);
                    break;
                }
                /* deal { } */
                else if ('{' == *ctx->rpos) {
                    /* eat '{' */
                    ngx_minify_copy_rpos(ctx);
                    /* jump into css brace state machine */
                    CTX_PUSH_STATE(ctx, css_state_brace);
                    break;
                }
                /* TODO: remove '\n' safe ? */
                else if ('\n' == *ctx->rpos || '\r' == *ctx->rpos) {
                    //if ('\n' == ctx->pre_char || '\r' == *ctx->pre_char) {
                        ngx_minify_inc_rpos(ctx);
                        break;
                    //}
                }
                else {
                    ngx_minify_copy_rpos(ctx);
                }
                break;

            case css_state_comment:
                ctx->nochange_pre = 1;
                ngx_minify_css_strip_comment(ctx);
                break;
                    
            case css_state_quote:
                ctx->nochange_pre = 1;
                ngx_minify_css_strip_quote(ctx);
                break;
                    
            case css_state_brace:
                ngx_minify_css_strip_brace(ctx);
                break;

            default:
                CTX_PUSH_STATE(ctx, minify_state_abort);
                break;
        }

        if (!ctx->nochange_pre) {
            if (ctx->dstlen >= 2) {
                ctx->pre_char = *(ctx->wpos - 1);
                ctx->pre_char2 = *(ctx->wpos - 2);
            } else if (1 == ctx->dstlen) {
                ctx->pre_char = *(ctx->wpos - 1);
                ctx->pre_char2 = '\0';
            }
        }
    }
}

void
ngx_minify_css_process(ngx_buf_t *b, ngx_minify_ctx_t *ctx)
{
    ctx->dstlen = 0;
    ngx_minify_css_strip_buffer(b->pos, ngx_buf_size(b), b->pos, ctx);
    b->last = b->pos + ctx->dstlen;
}

