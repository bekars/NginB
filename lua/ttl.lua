--[[ 

Usage:
	set $aqb_cache_time    TTL_NUM;
	set $aqb_content_type  0;    # 0 means static file(exclude html), 1 means html
	header_filter_by_lua_file SCRIPT_PATH/aqb_ttl.lua;

Author: yi.chen
Date  : 2012-12-22

--]]


-- read the nginx variable from the conf
local aqb_content_type = tonumber(ngx.var.aqb_content_type)
local aqb_cache_time   = tonumber(ngx.var.aqb_cache_time)
local upstream_cache_status = ngx.var.upstream_cache_status

function set_aqb_ttl(aqb_max_age, aqb_expires)
	ngx.header["Cache-Control"] = "public, max-age=" .. aqb_max_age
	-- use the ngx.time and ngx.http_time, avoid syscal
	ngx.header["Expires"] = ngx.http_time(aqb_expires)
end


--[[
	here comes the filter functions
	all the function should obey the return values rule:
		0 means 'no header' header specified
	   -1 means no set the header
	   >0 the value we want
--]]

-- 0 means don't cache
function filter_set_cookie(set_cookie)
	return set_cookie and 0 or 1
end

-- judge the cache header
-- return 0 means 'no cache' header specified, -1 means no cache control, 1 means ok
function filter_cache_control(cache_control)
	local no_cache_filter = {"^private", "^no%-store", "^no%-cache"};
	local flag = -1, pos

	if cache_control ~= nil then
		flag = 1
		for _, v in ipairs(no_cache_filter) do
			pos = string.find(cache_control, v)
			if pos then
				flag = 0
				break
			end
		end
	end

	return flag
end

-- get the max_age, -1 means no cache_control or no max_age, 0 means max-age <= 0
function get_max_age(cache_control)
	local max_age = -1

	if cache_control ~= nil then
		_, _, max_age = string.find(cache_control, "^.-max%-age=(%-?%d+)")

		local age = tonumber(max_age)
		if age == nil then
			max_age = -1

		elseif age > 0 then
			max_age = tonumber(age)

		else
			max_age = 0
		end
	end

	return max_age
end

-- get the expires time, return the seconds, -1 means no expires, 0 means don't cache
function get_expires_time(expires)
	local expires_time = -1

	if expires ~= nil then
		expires_time = ngx.parse_http_time(expires)
		expires_time = expires_time or 0
	end

	return expires_time
end


local filter_unit = {
	{f = filter_set_cookie   , p = ngx.header["Set-Cookie"]   },
	{f = filter_cache_control, p = ngx.header["Cache-Control"]},
	{f = get_max_age         , p = ngx.header["Cache-Control"]},
	{f = get_expires_time    , p = ngx.header["Expires"]},
	nil
}

-- create the filter iterator
function get_filter(check_type)
	local i = (check_type == 1) and 0 or 1
	
	return function()
		i = i + 1

		if filter_unit[i] == nil then
			return nil
		else
			filter_unit[i].r = filter_unit[i].f(filter_unit[i].p)
			--ngx.header[i] = filter_unit[i].r
			return filter_unit[i].r
		end
	end
end


-- comes the main
if aqb_cache_time > 0 then
	local check_type

	if upstream_cache_status == "HIT" or upstream_cache_status == "EXPIRES" then
		check_type = 0
	else
		check_type = 1
	end

	local fin = 0
	local f   = get_filter(check_type)
	while true do
		local r = f()
		if r == nil then break end
		if r == 0   then 
			fin = 1
			break
		end
	end

	-- here check the expires and the max-age
	if fin ~= 1 then 
		local now_time = ngx.time()
		local aqb_expire_time = now_time + aqb_cache_time
		local r_cc, r_max_age, r_expires_time = filter_unit[2].r, filter_unit[3].r, filter_unit[4].r

		if r_max_age ~= -1 then             -- have max-age
			if r_max_age < aqb_cache_time and aqb_content_type == 0 then
				set_aqb_ttl(aqb_cache_time, aqb_expire_time)
			end

		elseif r_expires_time ~= -1 then    -- have expires
			if r_expires_time < aqb_expire_time and aqb_content_type == 0 then
				set_aqb_ttl(aqb_cache_time, aqb_expire_time)
			end

		elseif r_cc == 1 then               -- have cc
			set_aqb_ttl(aqb_cache_time, aqb_expire_time)

		elseif aqb_content_type == 0 then   -- no cc but is no html
			set_aqb_ttl(aqb_cache_time, aqb_expire_time)
		end
	end
end
