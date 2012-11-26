
#user  nobody;
worker_processes  1;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
error_log  logs/error.log  info;

#error_log  logs/error.log  [debug_alloc | debug_mutex | debug_event | debug_http | debug_imap];


pid        logs/nginx.pid;

daemon off;
master_process off;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" ' 
                  '$status $body_bytes_sent "$http_referer" ' 
                  '"$http_user_agent" "$http_x_forwarded_for" "$http_cookie" '
                  '<$upstream_http_expires> <$upstream_http_cache_control> <$upstream_http_etag> <$upstream_http_last_modified> '
                  '$upstream_cache_status $request_time $upstream_response_time "$request_body"';

    access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

#    gzip  on;
#    gzip_proxied any;
#    gzip_types text/plain application/xml application/x-javascript text/javascript text/css;


    resolver 202.106.0.20;

    proxy_set_header X-Forwarded-Server "BNginxProxy";

    client_max_body_size 50m;
    client_body_temp_path  /data/nginx/client_body_temp 1 2;

#perl_modules perl; 
#perl_require JavaScript/Minifier.pm; 
#perl_require Minify.pm; 
 
    proxy_cache_methods GET HEAD;
    proxy_cache_valid 200 302 304 10m;
    proxy_cache_use_stale off;
    proxy_cache_key "$scheme://$host$request_uri";

    proxy_temp_path  /data/nginx/cache_tmp;
    proxy_cache_path /data/nginx/cache/www.baiyu.com levels=1 keys_zone=bcache:1m inactive=10m max_size=5m;

    server {
        listen 8080;
        location / {
            proxy_pass http://$http_host$request_uri;
            access_log logs/bekars_access.log  main;
		    proxy_redirect off;
            proxy_cache bcache;
#            proxy_cache_valid 200 302 304 10m;
#            proxy_cache_use_stale off;

#            capcache off;
#            capcache_path bcache;

#html_minify on;
#css_minify on;
#js_minify on;

#sub_filter  </body> '</body><script language="javascript" src="b.js"></script>';
#sub_filter_once on;

#location ~ \.js$ {
#proxy_pass http://$http_host$request_uri;
#perl Minify::handler;
#}

            location ~* .(gif|jpg|jpeg|png|bmp|swf|js|css)$ {
                proxy_pass http://$http_host$request_uri;
#                proxy_cache bcache;
            }
        }
    }

    server {
        listen       80;
        server_name  localhost;

        #charset koi8-r;

        #access_log  logs/host.access.log  main;

        location / {
            root   html;
            index  index.html index.htm;
#html_minify on;
#js_minify on;
#css_minify on;
            #chunked_transfer_encoding       off;
        }

        location /api/fcgi {
            fastcgi_pass 127.0.0.1:9000;
        }
        include fastcgi_params;

        location /nginx-status {  
            stub_status on;  
            access_log  off;  
        }

#        location ~ \.js$ {
#perl Minify::handler;
#        }

#        location /hello {
#    hello;
#        }

        location /compress/ {
#html_minify on;
#            css_minify on;
#            js_minify on;
        }

        #error_page  404              /404.html;

        # redirect server error pages to the static page /50x.html
        #
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }

        # proxy the PHP scripts to Apache listening on 127.0.0.1:80
        #
        #location ~ \.php$ {
        #    proxy_pass   http://127.0.0.1;
        #}

        # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
        #
        #location ~ \.php$ {
        #    root           html;
        #    fastcgi_pass   127.0.0.1:9000;
        #    fastcgi_index  index.php;
        #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
        #    include        fastcgi_params;
        #}

        # deny access to .htaccess files, if Apache's document root
        # concurs with nginx's one
        #
        #location ~ /\.ht {
        #    deny  all;
        #}
    }


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}


    # HTTPS server
    #
    #server {
    #    listen       443;
    #    server_name  localhost;

    #    ssl                  on;
    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_timeout  5m;

    #    ssl_protocols  SSLv2 SSLv3 TLSv1;
    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers   on;

    #    location / {
    #        root   html;
    #        index  index.html index.htm;
    #    }
    #}

}

