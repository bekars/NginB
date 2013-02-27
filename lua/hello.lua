--[[

set hello header

--]]

ngx.header["X-Hello"] = "Hello bekars"
io.write("Server: ngx.header[\"Server\"] " ..
    ngx.header["Content-Type"] .. "\n")

