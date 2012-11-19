/*
 * =====================================================================================
 *
 *    Description:  nginx html minify module
 *
 *        Version:  1.0
 *        Created:  08/16/2012 09:49:28 AM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  baiyu <yu.bai@unlun.com>
 *        Company:  http://www.anquanbao.com/
 *
 * =====================================================================================
 */

#include "ngx_http_minify_filter_module.h"

static char *html_skip_tag[] = {
    "pre",      /* keep format */
    "script",   /* java script */
    "style",    /* css style */
    NULL,
};

static int
ngx_minify_get_skip_tagname(ngx_minify_ctx_t *ctx)
{
    int i = 0;
    while (html_skip_tag[i]) {
        if ((CTX_TAGCACHE_LEN(ctx) == (int)strlen(html_skip_tag[i])) &&
            (!strncasecmp(CTX_TAGCACHE_GET(ctx), html_skip_tag[i], CTX_TAGCACHE_LEN(ctx))))
        {
            return i;
        }
        ++i;
    }

    return -1;
}

/**
 * deal with:
 * <tag></tag> 
 */
void
ngx_minify_html_strip_tagname(ngx_minify_ctx_t *ctx)
{
    int jump_loop = 0;
                
    ctx->pre_char = '\0';
    ctx->pre_char2 = '\0';

    while (ctx->count) 
    {
        switch (CTX_STATE(ctx))
        {
            case html_state_tagname:
                /* get tagname */
                if ('>' == *ctx->rpos) { 
                    /* eat '>' */
                    ngx_minify_copy_rpos(ctx);

                    /* add '\0' to tag name cache */
                    CTX_TAGCACHE_CLOSE(ctx);

                    /* is skip tag ? */
                    if (ngx_minify_get_skip_tagname(ctx) >= 0) {
                        /* return to html_state_skip */
                        CTX_SET_STATE(ctx, html_state_skip);
                        break;
                    }
                    /* return to text state */
                    else {
                        CTX_TAGCACHE_CLEAR(ctx);
                        CTX_SET_STATE(ctx, minify_state_text);
                        break;
                    }
                } 
                /* need read tag attribute */
                else if (' ' == *ctx->rpos || '/' == *ctx->rpos) {
                    /* eat ' ' or '/' */
                    ngx_minify_copy_rpos(ctx);

                    /* add '\0' to tag name cache */
                    CTX_TAGCACHE_CLOSE(ctx);

                    /* not skip tag clean cache */
                    if (ngx_minify_get_skip_tagname(ctx) < 0) {
                        CTX_TAGCACHE_CLEAR(ctx);
                    }
                        
                    CTX_POP_STATE(ctx);
                    CTX_PUSH_STATE(ctx, html_state_tagatt);
                    break;
                }
                /* copy tag name */
                else {
                    CTX_TAGCACHE_ADD(ctx, *ctx->rpos);
                    ngx_minify_copy_rpos(ctx);
                }
                break;
 
            case html_state_tagatt:
                if ((' ' == *ctx->rpos) && (' ' == ctx->pre_char)) {
                    ngx_minify_inc_rpos(ctx);
                    break;
                } 
                else if ('>' == *ctx->rpos) {
                    ngx_minify_copy_rpos(ctx);
                    if (CTX_TAGCACHE_LEN(ctx)) {
                        CTX_SET_STATE(ctx, html_state_skip);
                    } else {
                        CTX_SET_STATE(ctx, minify_state_text);
                    }
                    break;
                }
                /* deal <tag att/> */
                else if ('/' == *ctx->rpos) {
                    if (ctx->count >= 2) {
                        if ('>' == *(ctx->rpos + 1)) {
                            ngx_minify_copy_rpos(ctx);

                            /* tag finish, goto text state */
                            CTX_TAGCACHE_CLEAR(ctx);
                        } else {
                            /* eat /x */
                            ngx_minify_copy_rpos(ctx);
                            ngx_minify_copy_rpos(ctx);
                        }
                    } else { 
                        ngx_minify_cache("/", ctx);
                        ngx_minify_inc_rpos(ctx);
                    }
                    break;
                }
                /* copy tag attribute */
                else {
                    ngx_minify_copy_rpos(ctx);
                }
                break;

            case html_state_tagname_end:
                if (' ' == *ctx->rpos) { 
                    /* strip ' ' */
                    ngx_minify_inc_rpos(ctx);
                    break;
                }
                else if ('>' == *ctx->rpos) {
                    /* eat '>' */
                    ngx_minify_copy_rpos(ctx);
                    
                    if (CTX_TAGENDCACHE_LEN(ctx)) {
                        /* add '\0' to tag end name cache */
                        CTX_TAGENDCACHE_CLOSE(ctx);

                        if (!memcmp(ctx->tagcache, ctx->tagendcache, ctx->tagcachelen)) {
                            /* find match skip tag name */
                            CTX_SET_STATE(ctx, minify_state_text);
                            /* clear skip tag name cache */
                            CTX_TAGCACHE_CLEAR(ctx);
                        } else {
                            /* no find match skip tag name */
                            CTX_SET_STATE(ctx, html_state_skip);
                        }
                    
                        /* clear tag end name cache */
                        CTX_TAGENDCACHE_CLEAR(ctx);
                    } else {
                        CTX_SET_STATE(ctx, minify_state_text);
                    }
                    break;
                }
                /* eat it */
                else {
                    if (CTX_TAGCACHE_LEN(ctx)) {
                        CTX_TAGENDCACHE_ADD(ctx, *ctx->rpos);
                    }
                    ngx_minify_copy_rpos(ctx);
                }
                break;

            case html_state_skip:
                ctx->nochange_pre = 1;
            case minify_state_text:
            case minify_state_abort:
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

/* deal 
 * 1) <!-- --> 
 * 2) <!--[if IE 9 ]> ... <![endif]-->
 */
void
ngx_minify_html_strip_comment(ngx_minify_ctx_t *ctx)
{
    int i;
    int cached = -1;
    int jump_loop = 0;

    while (ctx->count) 
    {
        switch (CTX_STATE(ctx))
        {
            case html_state_comment:
                /* here ctx->count >=4, need to judge '<!--[if ' */
                if (ctx->count == (off_t)strlen("<!--")) {
                    cached = ngx_minify_cache("<!--", ctx);
                    for (i = 0; i < cached; ++i) {
                        ngx_minify_inc_rpos(ctx);
                    }
                }
                else if ('[' == *(ctx->rpos + 4)) {
                    if (ctx->count >= (off_t)strlen("<!--[if")) {
                        if (!memcmp(ctx->rpos, "<!--[if", strlen("<!--[if"))) {
                            CTX_POP_STATE(ctx);
                            CTX_PUSH_STATE(ctx, html_state_comment_ie);
                            break;
                        }
                        else {
                            /* strip '<!--' */
                            for (i = 0; i < (off_t)strlen("<!--"); ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                            CTX_POP_STATE(ctx);
                            CTX_PUSH_STATE(ctx, html_state_comment_skip);
                            break;
                        }
                    }
                    /* judge cache it or not */
                    else {
                        cached = ngx_minify_cache("<!--[if", ctx);
                        if (-1 == cached) {
                            for (i = 0; i < (off_t)strlen("<!--"); ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                            CTX_POP_STATE(ctx);
                            CTX_PUSH_STATE(ctx, html_state_comment_skip);
                        } else {
                            for (i = 0; i < cached; ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                        }
                        break;
                    }
                    break;
                }
                else {
                    /* skip '<!--' */
                    for (i = 0; i < (off_t)strlen("<!--"); ++i) {
                        ngx_minify_inc_rpos(ctx);
                    }
                    CTX_POP_STATE(ctx);
                    CTX_PUSH_STATE(ctx, html_state_comment_skip);
                    break;
                }
                break;
            
            case html_state_comment_ie:
                if (']' == *ctx->rpos) { 
                    if (ctx->count >= (off_t)strlen("]-->")) {
                        if (!memcmp(ctx->rpos, "]-->", strlen("]-->"))) {
                            for (i = 0; i < (off_t)strlen("]-->"); ++i) {
                                ngx_minify_copy_rpos(ctx);
                            }
                            /* return to text state */
                            CTX_SET_STATE(ctx, minify_state_text);
                            break;
                        } else {
                            /* eat comment */
                            for (i = 0; i < (off_t)strlen("]-->"); ++i) {
                                ngx_minify_copy_rpos(ctx);
                            }
                            break;
                        }
                    }
                    /* judge cache it or not */
                    else {
                        cached = ngx_minify_cache("]-->", ctx);
                        if (-1 == cached) {
                            ngx_minify_inc_rpos(ctx);
                            break;
                        } else {
                            for (i = 0; i < cached; ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                            break;
                        }
                    }
                } else {
                    /* copy ie comment */
                    ngx_minify_copy_rpos(ctx);
                }
                break;

            case html_state_comment_skip:
                if ('-' == *ctx->rpos) { 
                    if (ctx->count >= (off_t)strlen("-->")) {
                        if (!memcmp(ctx->rpos, "-->", strlen("-->"))) {
                            for (i = 0; i < (off_t)strlen("-->"); ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                            /* return to text state */
                            CTX_SET_STATE(ctx, minify_state_text);
                            break;
                        } else {
                            /* strip comment */
                            for (i = 0; i < (off_t)strlen("-->"); ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                            break;
                        }
                    }
                    /* judge cache it or not */
                    else {
                        cached = ngx_minify_cache("-->", ctx);
                        if (-1 == cached) {
                            ngx_minify_inc_rpos(ctx);
                            break;
                        } else {
                            for (i = 0; i < cached; ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                            break;
                        }
                    }
                } else {
                    /* strip comment */
                    ngx_minify_inc_rpos(ctx);
                }
                break;

            case minify_state_text:
            case minify_state_abort:
            default:
                jump_loop = 1;
                break;
        }
        
        /* small state machine deal finish, back to main big loop */
        if (jump_loop)
            break;
    }
}

/**
 * deal them:
 * 1) <!-- ... -->
 * 2) <![CDATA[ ... ]]>
 * 3) <!--[if IE 9 ]> ... <![endif]-->
 * 4) <!DOCTYPE ...>
 */ 
void
ngx_minify_html_strip_tag(ngx_minify_ctx_t *ctx)
{
    int i;
    int cached = -1;
    int jump_loop = 0;

    while (ctx->count) 
    {
        switch (CTX_STATE(ctx))
        {
            case html_state_tag:
                /* strip space */
                if (' ' == *ctx->rpos) {
                    ngx_minify_inc_rpos(ctx);
                    break;
                }
                else if ('/' == *ctx->rpos) {
                    /* eat '/' */
                    ngx_minify_copy_rpos(ctx);
                    CTX_PUSH_STATE(ctx, html_state_tagname_end);
                    break;
                }
                /* tag name text */
                else {
                    /* deal tagname */
                    CTX_PUSH_STATE(ctx, html_state_tagname);
                    CTX_TAGCACHE_CLEAR(ctx);
                    CTX_TAGENDCACHE_CLEAR(ctx);
                    break;
                }
                break;
            
            case html_state_tag_bang:
                /**
                 * here ctx->count must >2 and *ctx->rpos == '<' 
                 */
                if (ctx->count <= 2) {
                    for (i = 0; i < ctx->count; ++i) {
                        ngx_minify_copy_rpos(ctx);
                    }
                    CTX_SET_STATE(ctx, minify_state_text);
                    break;
                }

                /* <!DOCTYPE */
                if (('-' != *(ctx->rpos + 2)) && ('[' != *(ctx->rpos + 2))) {
                    /* eat '<!' */
                    ngx_minify_copy_rpos(ctx);
                    ngx_minify_copy_rpos(ctx);
                    CTX_POP_STATE(ctx);
                    CTX_PUSH_STATE(ctx, html_state_tag);
                    break;
                }
                /* <!-- --> */
                /* <!--[if IE 9 ]> ... <![endif]--> */
                else if ('-' == *(ctx->rpos + 2)) {
                    /* strip html comment */
                    if (ctx->count >= (off_t)strlen("<!--")) {
                        if (!memcmp(ctx->rpos, "<!--", strlen("<!--"))) {
                            CTX_PUSH_STATE(ctx, html_state_comment);
                            ctx->nochange_pre = 1;
                            break;
                        }
                        else {
                            /* eat <!- */
                            ngx_minify_copy_rpos(ctx);
                            ngx_minify_copy_rpos(ctx);
                            ngx_minify_copy_rpos(ctx);
                            CTX_POP_STATE(ctx);
                            CTX_PUSH_STATE(ctx, html_state_tag);
                            break;
                        }
                    }
                    /* judge cache it or not */
                    else {
                        cached = ngx_minify_cache("<!--", ctx);
                        if (-1 == cached) {
                            CTX_SET_STATE(ctx, minify_state_abort);
                        } else {
                            for (i = 0; i < cached; ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                        }
                        break;
                    }
                }
                /* <![CDATA[  ]]> */
                else if ('[' == *(ctx->rpos + 2)) {
                    /* eat cdata */
                    if (ctx->count >= (off_t)strlen("<![CDATA[")) {
                        if (!memcmp(ctx->rpos, "<![CDATA[", strlen("<![CDATA["))) {
                            /* eat <![CDATA[ */
                            for (i = 0; i < (int)strlen("<![CDATA["); ++i) {
                                ngx_minify_copy_rpos(ctx);
                            }
                            CTX_POP_STATE(ctx);
                            CTX_PUSH_STATE(ctx, html_state_cdata);
                            break;
                        }
                        else {
                            /* copy not cmp <!xxxxxxx */
                            for (i = 0; i < (int)strlen("<![CDATA["); ++i) {
                                ngx_minify_copy_rpos(ctx);
                            }
                            CTX_SET_STATE(ctx, minify_state_text);
                            break;
                        }
                    }
                    /* judge cache it or not */
                    else {
                        cached = ngx_minify_cache("<![CDATA[", ctx);
                        if (-1 == cached) {
                            CTX_SET_STATE(ctx, minify_state_abort);
                        } else {
                            for (i = 0; i < cached; ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                        }
                        break;
                    }
                }
                break;

            case html_state_cdata:
                if (']' == *ctx->rpos) { 
                    if (ctx->count >= (off_t)strlen("]]>")) {
                        if (!memcmp(ctx->rpos, "]]>", strlen("]]>"))) {
                            for (i = 0; i < (int)strlen("]]>"); ++i) {
                                ngx_minify_copy_rpos(ctx);
                            }
                            /* return to text state */
                            CTX_SET_STATE(ctx, minify_state_text);
                            break;
                        } else {
                            /* eat not compare ]]> */
                            ngx_minify_copy_rpos(ctx);
                            ngx_minify_copy_rpos(ctx);
                            ngx_minify_copy_rpos(ctx);
                            break;
                        }
                    }
                    /* judge cache it or not */
                    else {
                        cached = ngx_minify_cache("]]>", ctx);
                        if (-1 == cached) {
                            /* eat ] */
                            ngx_minify_copy_rpos(ctx);
                        } else {
                            for (i = 0; i < cached; ++i) {
                                ngx_minify_inc_rpos(ctx);
                            }
                        }
                        break;
                    }
                } else {
                    ngx_minify_copy_rpos(ctx);
                }
                break;

            case html_state_tagname:
            case html_state_tagname_end:
            case html_state_tagatt:
                ngx_minify_html_strip_tagname(ctx);
                break;
                            
            case html_state_comment:
            case html_state_comment_ie:
            case html_state_comment_skip:
                ngx_minify_html_strip_comment(ctx);
                break;

            case html_state_skip:
                ctx->nochange_pre = 1;
            case minify_state_text:
            case minify_state_abort:
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
ngx_minify_html_strip_buffer(const u_char *src, off_t srclen, u_char *dst, ngx_minify_ctx_t *ctx)
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

                /* skip \r \n \t */
                if ('\n' == *ctx->rpos || '\r' == *ctx->rpos || '\t' == *ctx->rpos) {
                    ngx_minify_inc_rpos(ctx);
                    break;
                }
                /* deal tag */
                else if (('<' == *ctx->rpos)) {
                    if (ctx->count >= 2) {
                        /* html tag */
                        if ('!' != *(ctx->rpos + 1)) {
                            /* eat < */
                            ngx_minify_copy_rpos(ctx);
                            /* jump into html tag state machine */
                            CTX_PUSH_STATE(ctx, html_state_tag);
                            break;
                        }
                        /* <! */
                        else {
                            if (ctx->count > 2) {
                                /* jump into html tag state machine, deal <! */
                                CTX_PUSH_STATE(ctx, html_state_tag_bang);
                                break;
                            }
                            else if (2 == ctx->count) {
                                ngx_minify_cache("<!", ctx);
                                ngx_minify_inc_rpos(ctx);
                                ngx_minify_inc_rpos(ctx);
                                break;
                            }
                        }
                    } else {
                        /* cache it, do it in next buf */
                        ngx_minify_cache("<", ctx);
                        ngx_minify_inc_rpos(ctx);
                        break;
                    }
                    break;
                }
                /* strip space */
                else if ((' ' == *ctx->rpos) && (' ' == ctx->pre_char)) {
                    ngx_minify_inc_rpos(ctx);
                    break;
                }
                else if ((' ' == *ctx->rpos) && (' ' != ctx->pre_char)) {
                    ngx_minify_copy_rpos(ctx);
                    break;
                }
                /* others eat it */
                else {
                    ngx_minify_copy_rpos(ctx);
                    break;
                }
                break;

            case html_state_skip:
                /* skip pre, css and js inside html */
                if ('<' == *ctx->rpos) {
                    if (ctx->count >= 2) {
                        if ('/' == *(ctx->rpos + 1)) {
                            CTX_SET_STATE(ctx, minify_state_text);
                        } else {
                            /* eat <x */
                            ngx_minify_copy_rpos(ctx);
                            ngx_minify_copy_rpos(ctx);
                        }
                    } else {
                        ngx_minify_cache("<", ctx);
                        ngx_minify_inc_rpos(ctx);
                    }
                    break;
                } else {
                    ngx_minify_copy_rpos(ctx);
                    break;
                }
                break;

            case html_state_tag:
            case html_state_tag_bang:
            case html_state_cdata:
            case html_state_tagname:
            case html_state_tagatt:
            case html_state_tagname_end:
            case html_state_comment:
            case html_state_comment_ie:
            case html_state_comment_skip:
                ngx_minify_html_strip_tag(ctx);
                break;

            default:
                CTX_SET_STATE(ctx, minify_state_abort);
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
ngx_minify_html_process(ngx_buf_t *b, ngx_minify_ctx_t *ctx)
{
    ctx->dstlen = 0;
    ngx_minify_html_strip_buffer(b->pos, ngx_buf_size(b), b->pos, ctx);
    b->last = b->pos + ctx->dstlen;
}

