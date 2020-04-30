local newsId= ngx.var.arg_id or "0"
local cache_dynamic_link = ngx.var.cache_dynamic_link == "true"
local no_log = ngx.var.no_log == "true"
local site_name = ngx.var.site_name or '免费看球神器【官网】'

local function print(msg)
    if not no_log then
        ngx.log(ngx.ERR,msg)
    end
end

require("tools")
local news_filename = ngx.var.document_root.."/cache/news_"..newsId..".html"

if file_exists(news_filename) and not ngx.var.arg_refresh then
    ngx.exec("/news_"..newsId..".html");
    ngx.eof();
end


local t= io.open(ngx.var.document_root.."/news.html",'r')
local body = t:read("*all")
io.close(t)
body=body:gsub("<!%-%-.-%-%->","")

local newsRes = ngx.location.capture("/myproxy/news?id="..newsId)
-- ngx.say(newsRes.status .. " /myproxy/news?id="..newsId)
-- ngx.print(newsRes.body)

if newsRes and newsRes.status == 200  then
    local newsBodyStart = string.find(newsRes.body,"<div class=\"left\">")
    local newsBodyEnd = string.find(newsRes.body,"</div> <footer class=\"footer\">")
    if (newsBodyStart > 0 and newsBodyEnd > newsBodyStart) then

        local newsBody = string.sub( newsRes.body, newsBodyStart,newsBodyEnd-1 )
        newsBody=newsBody:gsub("<script.-</script>","")
        newsBody=newsBody:gsub("/news%?id=(%d*)","news_%1.html")
        newsBody=newsBody:gsub("<a.-href=\"[^n].-</a>","")

        local title = string.match(newsRes.body,"<p class=\"title\">(.-)</p>")
        if title and string.len(title) > 1 then
            body = string.gsub( body,"#title#",title.."_"..site_name)
        else
            body = string.gsub( body,"#title#",site_name)
        end
        body = string.gsub( body,"内容加载中。。。",newsBody)
        if cache_dynamic_link  then
            saveToFile(news_filename,body)
        end
    end
else
    ngx.say("http_status:"..newsRes.status)
end

ngx.say(body);