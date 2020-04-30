-- package.path=package.path .. ";./?.lua;sites/?.lua;lua/?.lua;"
require("tools")
if (not arg ) then
	arg = {}
end
local filepath = arg[1]

local default_sub_filter_file = '/usr/local/nginx/conf/sites/huoli_sub_filter.conf'
local default_www_root =  ngx.var.document_root or '/var/www/huolisport.cn'
local default_proxy_host = ngx.var.proxy_host or 'www.huolisport.cn'



if(filepath == nil and ngx.var.uri ~= nil) then
    --拼接完整的源地址
    filepath = 'http://' ..default_proxy_host..ngx.var.uri
    if(ngx.var.is_args and ngx.var.args ) then
        filepath = filepath .."?" ..ngx.var.args 
    end
    ngx.log(ngx.ERR,"未传参数，获取ngx里的url拼接出完成url " ..filepath);
else
    ngx.log(ngx.ERR,"有传参数进来 " .. filepath)
end

--如果shell直接运行，可以带一个
--如果参数是网址，则从网址获取内容并保存到本地，如果是文本类型的网址，则调用替换并返回
--如果参数是文件，如果是文本类型，则调用替换并返回
if(filepath) then
    local resource;
    if(startsWith(filepath,"http")) then
        resource = mycurl(filepath,default_www_root,default_sub_filter_file)
    elseif(isTextPlan(filepath)) then
        resource = mySubFilter(filepath,default_sub_filter_file)
    end
    if(string.sub(resource,1,1)=="/") then
        ngx.exec(resource);
    else
        ngx.say(resource)
    end
end





