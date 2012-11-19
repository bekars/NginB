/*
 * =====================================================================================
 *
 *    Description:  nginx javascript minify module
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

void
ngx_minify_js_strip_comment(ngx_minify_ctx_t *ctx)
{
    int jump_loop = 0;

    while (ctx->count) 
    {
        switch (CTX_STATE(ctx))
        {
            case js_state_comment:
                if ('*' == *ctx->rpos) { 
                    if (ctx->count >= 2) {
                        if (!memcmp(ctx->rpos, "*/", strlen("*/"))) {
                            /* strip *[slash] */
                            ngx_minify_inc_rpos(ctx);
                            ngx_minify_inc_rpos(ctx);
                            /* jump to text */
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

            case js_state_comment_line:
                if ('\n' == *ctx->rpos) { 
                    /* copy '\n', add ' ' to split two lines */
                    ngx_minify_copy_char(ctx, ' ');
                    /* jump to text */
                    CTX_POP_STATE(ctx);
                    
                    ctx->pre_char = '\n';
                    ctx->pre_char2 = '\0';
                    break;
                } else {
                    ngx_minify_inc_rpos(ctx);
                    break;
                }
                break;

            case minify_state_text:
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
ngx_minify_js_strip_quote(ngx_minify_ctx_t *ctx)
{
    int jump_loop = 0;

    while (ctx->count) 
    {
        switch (CTX_STATE(ctx))
        {
            case js_state_quote:
                /* escape char preceded by '\', etc '\'', '\"' */
                if ('\\' == *ctx->rpos) { 
                    if (ctx->count > 1) {
                        /* eat \x */
                        ngx_minify_copy_rpos(ctx);
                        ngx_minify_copy_rpos(ctx);
                    } else if (1 == ctx->count) {
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
            default:
                jump_loop = 1;
                break;
        }
        
        /* small state machine deal finish, back to main big loop */
        if (jump_loop)
            break;
    }
}

void
ngx_minify_js_strip_buffer(const u_char *src, off_t srclen, u_char *dst, ngx_minify_ctx_t *ctx)
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

                /* strip line head space */
                if (((' ' == *ctx->rpos) && ('\n' == ctx->pre_char)) || 
                    (('\t' == *ctx->rpos) &&  ('\n' == ctx->pre_char)) ||
                    ((0 == ctx->dstlen) && ((' ' == *ctx->rpos) || ('\t' == *ctx->rpos)))
                   ) 
                {
                    ctx->nochange_pre = 1;
                    ngx_minify_inc_rpos(ctx);
                    break;
                }
                /* strip multi space */
                else if (((' ' == *ctx->rpos) || ('\t' == *ctx->rpos)) && 
                         ((' ' == ctx->pre_char) || ('\t' == ctx->pre_char)))
                {
                    ctx->nochange_pre = 1;
                    ngx_minify_inc_rpos(ctx);
                    break;
                }
                /* deal slash */
                else if ('/' == *ctx->rpos) { 
                    if (ctx->count >= 2) {
                        if (!memcmp(ctx->rpos, "/*", strlen("/*"))) {
                            /* strip [slash]* */
                            ngx_minify_inc_rpos(ctx);
                            ngx_minify_inc_rpos(ctx);
                            /* jump into js comment state machine */
                            CTX_PUSH_STATE(ctx, js_state_comment);
                            break;
                        }
                        else if (!memcmp(ctx->rpos, "//", strlen("//"))) {
                            /* strip '//' */
                            ngx_minify_inc_rpos(ctx);
                            ngx_minify_inc_rpos(ctx);
                            /* jump into js comment state machine */
                            CTX_PUSH_STATE(ctx, js_state_comment_line);
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
                /* deal quote */
                else if (('"' == *ctx->rpos) || ('\'' == *ctx->rpos) || ('[' == *ctx->rpos)) {
                    ctx->nochange_pre = 1;
                    if ('[' == *ctx->rpos) {
                        ctx->quote_char = ']';
                    } else {
                        ctx->quote_char = *ctx->rpos;
                    }
                    ngx_minify_copy_rpos(ctx);
                    /* jump into js quote state machine */
                    CTX_PUSH_STATE(ctx, js_state_quote);
                    break;
                }
                else if ('\n' == *ctx->rpos) {
                    if ((ctx->pre_char != '\0') && (ctx->pre_char != '\n') && 
                        (ctx->pre_char != ';') && (ctx->pre_char != ':') && 
                        (ctx->pre_char != '{') && (ctx->pre_char != '}')) 
                    {
                        ngx_minify_copy_rpos(ctx);
                    } else {
                        /* strip '\n' */
                        ngx_minify_inc_rpos(ctx);
                        ctx->pre_char = '\n';
                        ctx->pre_char2 = '\0';
                        ctx->nochange_pre = 1;
                    }
                    break;
                }
                else if ('\r' == *ctx->rpos) {
                    /* strip '\r' */
                    ngx_minify_inc_rpos(ctx);
                    ctx->nochange_pre = 1;
                    break;
                }
                else {
                    ngx_minify_copy_rpos(ctx);
                }
                break;

            case js_state_comment:
            case js_state_comment_line:
                ctx->nochange_pre = 1;
                ngx_minify_js_strip_comment(ctx);
                break;
                    
            case js_state_quote:
                ctx->nochange_pre = 1;
                ngx_minify_js_strip_quote(ctx);
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
ngx_minify_js_process(ngx_buf_t *b, ngx_minify_ctx_t *ctx)
{
    ctx->dstlen = 0;
    ngx_minify_js_strip_buffer(b->pos, ngx_buf_size(b), b->pos, ctx);
    b->last = b->pos + ctx->dstlen;
}

