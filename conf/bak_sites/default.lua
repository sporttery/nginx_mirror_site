require("tools")
local default_sub_filter_file = ngx.var.default_sub_filter_file
local cache_dynamic_link  = 'true' == ngx.var.cache_dynamic_link
local cache_minutes = tonumber(ngx.var.cache_minutes) or 3
local use_curl = 'true' == ngx.var.use_curl
local is_https = "true" == ngx.var.is_https


local args = nil
local request_method = ngx.var.request_method
--获取参数的值
if "GET" == request_method then
    args = ngx.req.get_uri_args()
elseif "POST" == request_method then
    ngx.req.read_body()
    args = ngx.req.get_post_args()
end
local url = ngx.var.uri


local paramTable = {}
for key, val in pairs(args) do
    if type(val) == "table" then
        local tmpTable = {}
        for keySub, valSub in pairs(val) do
            table.insert( tmpTable, key .."="..valSub)
        end
        local p = table.concat(tmpTable, "&")
        table.insert( paramTable, p)
    else
        table.insert( paramTable, key .."="..val)
    end
end

local params = table.concat(paramTable, "&")

local request_time = ngx.now() - ngx.req.start_time()
ngx.header["X-Server-By"] = 'server by david.chang'
ngx.header["Server"] = 'nginx'
ngx.header["X-Server-End"] = request_time


function getRes(url,param,cache_file) 
    local res ;
    if use_curl then
        local newUrl
        if is_https then
            newUrl = "https://"..ngx.var.proxy_host..ngx.var.uri
        else
            newUrl = "http://"..ngx.var.proxy_host..ngx.var.uri
        end
        if "POST" == request_method then
            mycurl(newUrl,cache_file,params)
        else
            mycurl(newUrl,cache_file,nil)
        end

        
        -- if ngx.var.content_type then
        --     ngx.header['Content-Type']= ngx.var.content_type 
        -- else
        --     ngx.header['Content-Type']=getContentType(url)
        -- end 
        local file = io.open(cache_file,'rb')
        res = {}
        res.status = ngx.HTTP_OK
        if file then 
            local body = file:read("*all")
            io.close(file)
            res.body = body
        else
            res.body = "error"
        end
    else
        res = ngx.location.capture(url,param)
    end
    return res
end

function main()
    --如果是post请求，直接代理，并替换内容
    if "POST" == request_method then
        ngx.log(ngx.ERR,"post 请求，直接走代理，并替换内容");
        local res = getRes("/myproxy"..url,{ method = ngx.HTTP_POST, args = args ,host = ngx.var.proxy_host},ngx.var.request_filename.."?"..params)
        if res and res.body and string.len(res.body) > 0 then
            local body = mySubFilterContent(res.body,default_sub_filter_file);
            if string.sub(body,1,1) == "{"  then
                ngx.header['Content-Type']="application/json"
            else
                ngx.header['Content-Type']="text/plain;charset=UTF-8"
            end
            ngx.say(body)
        else
            ngx.header['Content-Type']="text/plain;charset=UTF-8"
            ngx.say("error")
        end
        ngx.exit(ngx.HTTP_OK)
    end
    if ngx.var.content_type then
        ngx.header['Content-Type']= ngx.var.content_type 
    else
        ngx.header['Content-Type']=getContentType(url)
    end 
    --如果是样式表，脚本，html 等文本类型
    if(isTextPlan(url)) then
        ngx.log(ngx.ERR,"静态文本资源:"..ngx.var.request_filename);
        local res = getRes("/myproxy"..url,{ args = args ,host = ngx.var.proxy_host},ngx.var.request_filename)
        if res and res.body and string.len(res.body) > 0 then
            local body = mySubFilterContent(res.body,default_sub_filter_file);
            saveToFile(ngx.var.request_filename,body)
            ngx.say(body)
            -- ngx.exec(url)
        else
            ngx.header['Content-Type']="text/plain;charset=UTF-8"
            ngx.say("error")
        end
        ngx.exit(ngx.HTTP_OK)
    end

    --如果是图片

    if(isImage(url) or isFont(url)) then
        ngx.log(ngx.ERR,"静态图片,字体资源:"..ngx.var.request_filename);
        local res = getRes("/myproxy"..url,{ args = args ,host = ngx.var.proxy_host},ngx.var.request_filename)
        if res then
            local body = res.body;
            saveToFile(ngx.var.request_filename,body)
            ngx.say(body)
            -- ngx.exec(url)
        else
            ngx.header['Content-Type']="text/plain;charset=UTF-8"
            ngx.say("error")
        end
        ngx.exit(ngx.HTTP_OK)
    end
    --如果没有后缀，看看是否有缓存文件，缓存文件可以保持3分钟
    local newUrl = url..".html"
    local cache_file = ngx.var.request_filename .. ".html"
    if  ngx.var.args and string.len( ngx.var.args ) >0 then
        cache_file = cache_file .. "?" ..ngx.var.args 
    end
    -- if  not ngx.var.args or  string.len( ngx.var.args ) == 0 then
        --如果是动态接口 
    ngx.log(ngx.ERR,"动态接口："..url..",缓存路径："..cache_file)
    if (cache_dynamic_link and file_exists(cache_file))then
        local cmd = "expr $(date +%s) - $(stat -c \"%Z\" '"..cache_file.."')"
        ngx.log(ngx.ERR,cmd)
        local t= io.popen(cmd)
        local a = t:read("*all")
        io.close(t)
        local time = tonumber(a)
        if (time < 60 * cache_minutes)  then
            ngx.log(ngx.ERR,"文件较新，读取缓存文件："..cache_file .. ",路径 " ..newUrl)
            t= io.open(cache_file,'r')
            local body = t:read("*all")
            io.close(t)
            ngx.say(body)
            ngx.exit(ngx.HTTP_OK)
        end
    end
    -- end

    local res 

    if  ngx.var.args and string.len( ngx.var.args ) >0 then
        res = getRes("/myproxy"..url.."?"..ngx.var.args,{ args = args ,host = ngx.var.proxy_host},cache_file)
    else
        res = getRes("/myproxy"..url,{ args = args ,host = ngx.var.proxy_host},cache_file)
    end
    if res and res.body and string.len(res.body) > 0 then
        local body = mySubFilterContent(res.body,default_sub_filter_file);
        if cache_dynamic_link then
            saveToFile(cache_file,body)
        end
        ngx.say(body)
        -- ngx.exec(newUrl)
    else
        ngx.header['Content-Type']="text/plain;charset=UTF-8"
        ngx.say("error")
    end
end



main()