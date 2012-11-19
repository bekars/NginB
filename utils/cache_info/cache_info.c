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

int
main(int argc, char **argv)
{
    int n;
    FILE *fp = NULL;
    ngx_http_file_cache_header_t cache_header;

    if (argc != 2) {
        printf("Usage: %s <cache_file_name>\n", argv[0]);
        exit(-1);
    }

    fp = fopen(argv[1], "rb");
    if (!fp) {
        printf("file %s open error!\n", argv[1]);
        return -1;
    }

    memset(&cache_header, 0, sizeof(ngx_http_file_cache_header_t));
    n = fread(&cache_header, sizeof(ngx_http_file_cache_header_t), 1, fp); 

    cache_header_dump(&cache_header);

    fclose(fp);

    exit(0);
}

