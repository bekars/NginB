/*
 * =====================================================================================
 *
 *       Filename:  cache_info.c
 *
 *    Description:  
 *
 *        Version:  1.0
 *        Created:  11/19/2012 10:56:22 AM
 *       Revision:  none
 *       Compiler:  gcc
 *
 *         Author:  baiyu (bekars), bekars@gmail.com
 *        Company:  BW
 *
 * =====================================================================================
 */


#include "pubinc.h"
#include "ngx_http_cache.h"
    
ngx_http_file_cache_header_t cache_header;

void
cache_header_dump(ngx_http_file_cache_header_t *cache_header)
{
    printf("valid: %s", ctime(&cache_header->valid_sec));
    printf("last_modify: %s", ctime(&cache_header->last_modified));
    printf("date: %s", ctime(&cache_header->date));
    printf("crc32: %x\n", cache_header->crc32);
    printf("msec: %d\n", cache_header->valid_msec);
    printf("header: %d\n", cache_header->header_start);
    printf("body: %d\n", cache_header->body_start);
}

void
cache_header_show(char *fname, int isshow)
{
    FILE *fp = NULL;
    fp = fopen(fname, "rb");
    if (!fp) {
        printf("file %s open error!\n", fname);
        return;
    }

    memset(&cache_header, 0, sizeof(ngx_http_file_cache_header_t));
    if (fread(&cache_header, sizeof(ngx_http_file_cache_header_t), 1, fp) <= 0) {
        printf("read %s error!\n", fname);
    } else if (isshow) {
        cache_header_dump(&cache_header);
    }

    fclose(fp);
}

int
cache_header_bodyoffset_modify(char *bodyoffset, ngx_http_file_cache_header_t *cache_header)
{
    cache_header->body_start = atoi(bodyoffset);

    return 0;
}

int
cache_header_expired_modify(char *expired, ngx_http_file_cache_header_t *cache_header)
{
    int secs;
    char ope;
//    char new_file[1024];

    if (sscanf(expired, "%c%d", &ope, &secs) != 2) {
        printf("arg %s error!\n", expired);
        return -1;
    }

    printf("add %c%d secs to expired...\n", ope, secs);
    if (ope == '+') {
        cache_header->valid_sec += secs;
    } else {
        cache_header->valid_sec -= secs;
    }

//    sprintf(new_file, "%s.new", fname);
    return 0;
}

int
update_cache_file(char *fname, ngx_http_file_cache_header_t *cache_header)
{
    FILE *fp = NULL;
    fp = fopen(fname, "rb+");
    if (!fp) {
        printf("file %s open error!\n", fname);
        return -2;
    }
    
    if (fwrite(cache_header, sizeof(ngx_http_file_cache_header_t), 1, fp) <= 0) {
        printf("write %s error!\n", fname);
        fclose(fp);
        return -3;
    }
    fclose(fp);

    return 0;
}

int
main(int argc, char **argv)
{
    if ((argc < 2) || (argc > 4)) {
        printf("Usage: %s <cache_file_name> +<expired_seconds(optinal)> <body_offset>\n", argv[0]);
        exit(-1);
    }

    if (argc == 3) {
        cache_header_show(argv[1], 0);
        cache_header_expired_modify(argv[2], &cache_header);
        update_cache_file(argv[1], &cache_header);
    }

    if (argc == 4) {
        cache_header_show(argv[1], 0);
        cache_header_expired_modify(argv[2], &cache_header);
        cache_header_bodyoffset_modify(argv[3], &cache_header);
        update_cache_file(argv[1], &cache_header);
    }
 
    cache_header_show(argv[1], 1);

    exit(0);
}

