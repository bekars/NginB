#
# mojo app config
#

upstream mojo_app {
    server 127.0.0.1:3000;
}

server {
    listen 8183;

    location / {
        proxy_read_timeout 600;
        proxy_pass http://mojo_app;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-HTTPS 0;
    }
}

