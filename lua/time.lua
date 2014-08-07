---[[
-- get now time
---]]]

ngx.header["Access-Control-Allow-Origin"] = "http://ajax.baiyu.org.cn";
ngx.say(ngx.var.arg_s);

