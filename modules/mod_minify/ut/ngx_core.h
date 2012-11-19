

#include <stdio.h>
#include <string.h>

typedef unsigned char u_char;

typedef struct ngx_buf_s  ngx_buf_t;

struct ngx_buf_s {
    u_char          *pos;
    u_char          *last;
    off_t            file_pos; 
    off_t            file_last; 

    u_char          *start;         /* start of buffer */
    u_char          *end;           /* end of buffer */
    //ngx_buf_tag_t    tag;
    //ngx_file_t      *file;
    //ngx_buf_t       *shadow;


    /* the buf's content could be changed */
    unsigned         temporary:1;

    /*
     *      * the buf's content is in a memory cache or in a read only memory
     *           * and must not be changed
     *                */
    unsigned         memory:1;

    /* the buf's content is mmap()ed and must not be changed */
    unsigned         mmap:1;

    unsigned         recycled:1;
    unsigned         in_file:1;
    unsigned         flush:1;
    unsigned         sync:1;
    unsigned         last_buf:1;
    unsigned         last_in_chain:1;

    unsigned         last_shadow:1;
    unsigned         temp_file:1;

    /* STUB */ int   num;
};

#define ngx_buf_size(b) (off_t)((b)->last - (b)->pos)

