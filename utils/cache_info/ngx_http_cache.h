
#ifndef __NGX_HTTP_CACHE_H__
#define __NGX_HTTP_CACHE_H__

typedef struct {
    time_t                           valid_sec;
    time_t                           last_modified;
    time_t                           date;
    uint32_t                         crc32;
    u_short                          valid_msec;
    u_short                          header_start;
    u_short                          body_start;
} ngx_http_file_cache_header_t;

#endif /* __NGX_HTTP_CACHE_H__ */

