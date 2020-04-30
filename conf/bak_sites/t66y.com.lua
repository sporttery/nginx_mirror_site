require("tools")

local default_sub_filter_file = '/usr/local/nginx/conf/sites/t66y_sub_filter.conf'
local cache_dynamic_link = true

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

local request_time = ngx.now() - ngx.req.start_time()
ngx.header["X-Server-By"] = 'server by david.chang'
ngx.header["Server"] = 'nginx'
ngx.header["X-Server-End"] = request_time



function main()
    --如果是post请求，直接代理，并替换内容
    if "POST" == request_method then
        ngx.log(ngx.ERR,"post 请求，直接走代理，并替换内容");
        local res = ngx.location.capture("/myproxy"..url,{ method = ngx.HTTP_POST, args = args })
        if res then
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
        local res = ngx.location.capture("/myproxy"..url)
        if res then
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
        local res = ngx.location.capture("/myproxy"..url)
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
        local cmd = "expr $(date +%s) - $(stat -c \"%Z\" "..cache_file..")"
        ngx.log(ngx.ERR,cmd)
        local t= io.popen(cmd)
        local a = t:read("*all")
        io.close(t)
        local time = tonumber(a)
        if (time < 60 * 3)  then
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
        res = ngx.location.capture("/myproxy"..url.."?"..ngx.var.args)
    else
        res = ngx.location.capture("/myproxy"..url)
    end
    if res then
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