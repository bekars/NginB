/*
 * =====================================================================================
 *
 *    Description:  nginx minify unit test
 *
 *        Version:  1.0
 *        Created:  08/17/2012 05:18:44 PM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  baiyu <yu.bai@unlun.com>
 *        Company:  nevel
 *
 * =====================================================================================
 */

#include <math.h>
#include <fcntl.h>
#include <unistd.h>
#include "ngx_minify_ut.h"

typedef void (*minify_process_fn)(ngx_buf_t *b, ngx_minify_ctx_t *ctx);

static char dstbuf[4096];
static char case_num = 0;
static char case_success_num = 0;

typedef enum
{
    minify_html = 0,
    minify_css,
    minify_js,
    minify_none,
} minify_type;

typedef struct ngx_minify_entry
{
    char *name;
    char *suffix;
    ngx_minify_ut_data_p p;
    minify_process_fn fn;
} ngx_minify_entry_s, *ngx_minify_entry_p;

ngx_minify_entry_s case_entry[] = 
{
    { "html", "html", &html_ut_data[0], ngx_minify_html_process },
    { "css",  "css",  &css_ut_data[0],  ngx_minify_css_process },
    { "js",   "js",   &js_ut_data[0],   ngx_minify_js_process },
    { NULL,   NULL,   NULL,             NULL },
};

minify_type
ngx_minify_ut_get_type(const char * const file)
{
    int i;
    char *p = strrchr(file, '.');

    for (i = 0; ; ++i) {
        if (!case_entry[i].name)
            break;

        if (!strncmp((p+1), case_entry[i].name, strlen(case_entry[i].name)))
            return i;
    }

    return minify_none;
}

void
ngx_minify_ut_copy_buf(ngx_buf_t *buf, const char *data, int len)
{
    memcpy(buf->start, data, len);
    buf->pos = buf->start;
    buf->last = buf->start + len;
    buf->end = buf->last;
}

ngx_buf_t *
ngx_minify_ut_create_buf(int len)
{
    ngx_buf_t *b = (ngx_buf_t *)malloc(sizeof(ngx_buf_t));
    memset(b, 0, sizeof(ngx_buf_t));

    b->start = (char *)malloc(len + 1);
    memset(b->start, 0, len + 1);

    return b;
}

void
ngx_minify_ut_free_buf(ngx_buf_t **buf)
{
    free((*buf)->start);
    free(*buf);
    *buf = NULL;
}

ngx_buf_t *
ngx_minify_ut_append_cache(ngx_buf_t **buf, ngx_minify_ctx_t *ctx)
{
    ngx_buf_t *newbuf = *buf;

    if (ctx->cachelen) {
        /* pcalloc new buf */
        newbuf = ngx_minify_ut_create_buf(ctx->cachelen + ngx_buf_size(*buf));

        memcpy(newbuf->start, ctx->cache, ctx->cachelen);
        memcpy(newbuf->start + ctx->cachelen, (*buf)->pos, ngx_buf_size(*buf));

        /* assign new buf pointer */
        newbuf->pos = newbuf->start;
        newbuf->last = newbuf->start + ctx->cachelen + ngx_buf_size(*buf);
        newbuf->end = newbuf->last;
            
        ngx_minify_ut_free_buf(buf);
        ctx->cachelen = 0;
    }

    return newbuf;
}


#define READ_BUF_LEN 128 
int
ngx_minify_file(const char * const file, const char * const wfile, minify_type type)
{
    int fdr, fdw;
    int nread = 0;
    int orglen = 0;
    int dstlen = 0;
    char rbuf[READ_BUF_LEN];
    ngx_buf_t *buf = NULL;
    ngx_minify_ctx_t ctx;
    ngx_minify_ut_data_p p = NULL;

    mode_t mode = S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH;
    fdr = open(file, O_RDONLY);
    fdw = open(wfile, O_RDWR | O_CREAT | O_TRUNC, mode);
    if (fdr < 0 || fdw < 0) {
        printf("open minify file error!\n");
        return -1;
    }

    memset(&ctx, 0, sizeof(ngx_minify_ctx_t));

    while (1) {
        memset(rbuf, 0, sizeof(rbuf));
        nread = read(fdr, rbuf, sizeof(rbuf));

        if (nread) {
            orglen += nread;
            buf = ngx_minify_ut_create_buf(nread);
            ngx_minify_ut_copy_buf(buf, rbuf, nread);

            buf = ngx_minify_ut_append_cache(&buf, &ctx);

            case_entry[type].fn(buf, &ctx);

            write(fdw, buf->start, ctx.dstlen);

            dstlen += ctx.dstlen;
            ngx_minify_ut_free_buf(&buf);

        } else if (!nread) {
            break;
        }
    }

    close(fdr);
    close(fdw);

    printf(" - OK! orglen: %d, minilen: %d, rate(%%): %.2f%%\n", orglen, dstlen, (float)dstlen*100/orglen);

    return 0;
}

void
ngx_minify_ut(ngx_minify_ut_data_p p, minify_process_fn fn)
{
    char **d = NULL;
    ngx_buf_t *buf = NULL;
    ngx_minify_ctx_t ctx;
    int orglen = 0;
    int dstlen = 0;
    int index = 0;

    while (p->ut_name) {
        printf("[case %d] %s\n", ++index, p->ut_name);

        memset(&ctx, 0, sizeof(ngx_minify_ctx_t));
        memset(dstbuf, 0, sizeof(dstbuf));

        d = &p->ut_data[0];
        while (*d) {
            orglen += strlen(*d);
            if (orglen > 4096) {
                printf("too long!\n");
                exit(-1);
            }

            buf = ngx_minify_ut_create_buf(strlen(*d));
            ngx_minify_ut_copy_buf(buf, *d, strlen(*d));

            buf = ngx_minify_ut_append_cache(&buf, &ctx);

            fn(buf, &ctx);

            memcpy(dstbuf + dstlen, buf->start, ctx.dstlen);

            dstlen += ctx.dstlen;
            ngx_minify_ut_free_buf(&buf);
            ++d;
        }

        ++case_num;
        if (memcmp(dstbuf, p->ut_result, dstlen)) {
            printf(" - FAIL!\nmini:\n[%s]\nexpect:\n[%s]\n", dstbuf, p->ut_result);
        } else {
            ++case_success_num;
            printf(" - OK! orglen: %d, minilen: %d, rate(%%): %.2f%%\n", orglen, dstlen, (float)dstlen*100/orglen);
        }

        if (0 != ctx.sspos) printf("ctx stach pos error!\n");

        orglen = 0;
        dstlen = 0;
        ++p;
    }
}

int
main(int argc, char **argv)
{
    ngx_minify_ut_data_p p = NULL;
    minify_process_fn fn = NULL;
    minify_type type;

    if (argc == 5 && !strcmp(argv[1], "-i") && !strcmp(argv[3], "-o")) {
        type = ngx_minify_ut_get_type(argv[2]);
        printf("read: %s  write: %s  type: %s\n", argv[2], argv[4], case_entry[type].name);
        
        if (minify_none == type)
            exit(-1);

        ngx_minify_file(argv[2], argv[4], type);
        exit(0);
    }

    printf("\n###### html minify test ######\n");
    p = case_entry[minify_html].p;
    fn = case_entry[minify_html].fn;
    ngx_minify_ut(p, fn);

    printf("\n###### css minify test ######\n");
    p = case_entry[minify_css].p;
    fn = case_entry[minify_css].fn;
    ngx_minify_ut(p, fn);

    printf("\n###### javascript minify test ######\n");
    p = case_entry[minify_js].p;
    fn = case_entry[minify_js].fn;
    ngx_minify_ut(p, fn);

    printf("\n###### FINISH OK: %d, TOTAL: %d ######\n", case_success_num, case_num);
    return 0;
}

