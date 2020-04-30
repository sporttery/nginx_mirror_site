local subId= ngx.var.arg_subId or "0"
local hot= ngx.var.arg_hot or "1"
local cid= ngx.var.arg_cid or "0"
local page= ngx.var.arg_page or "1"
local cache_dynamic_link = ngx.var.cache_dynamic_link == "true"
local cache_minutes = tonumber(ngx.var.cache_minutes or 0)
local no_log = ngx.var.no_log == "true"
local site_name = ngx.var.site_name or '免费看球神器【官网】'

local function print(msg)
    if not no_log then
        ngx.log(ngx.ERR,msg)
    end
end

-- local url = "/?subId="..subId

-- if cid ~= "0" then
--     url = url .. "&cid="..cid
-- else
--     url = url .."&hot="..hot
-- end

-- local res = ngx.location.capture("/myproxy"..url)
-- if res then
--     ngx.say("status: ", res.status)
--     ngx.say("body:")
--     ngx.print(res.body)
-- end

local newsApi = "/api/web/news?channel_id="..subId.."&page="..page

local scoreApi = "/api/web/data/score?channel_id="

if cid == "0" then
    scoreApi = scoreApi.."19"
else
    scoreApi = scoreApi..cid
end

require("tools")
local cjson = require("cjson")
local newsRes 
local scoreRes 
local cache_news = cache_dynamic_link
local cache_score = cache_dynamic_link
local news_api_filename = ngx.var.document_root.."/cache/news_"..subId.."_page_"..page..".json"
local score_api_filename = ngx.var.document_root.."/cache/score_"..subId..".json"


--如果有缓存文件，且满足缓存时间 ，直接返回
--当带参数refresh 时强制刷新
if (cache_dynamic_link and file_exists(news_api_filename)) and not ngx.var.arg_refresh then
    local cmd = "expr $(date +%s) - $(stat -c \"%Y\" '"..news_api_filename.."')"
    local t= io.popen(cmd)
    local a = t:read("*all")
    io.close(t)
    local time = tonumber(a)
    if (time < 60 * cache_minutes)  then
        print("文件较新，读取缓存文件："..news_api_filename .. ",路径 " ..newsApi)
        t= io.open(news_api_filename,'r')
        local body = t:read("*all")
        io.close(t)
        newsRes={}
        newsRes.body=body
        cache_news=false
    end
end

if (cache_dynamic_link and file_exists(score_api_filename)) and not ngx.var.arg_refresh then
    local cmd = "expr $(date +%s) - $(stat -c \"%Y\" '"..score_api_filename.."')"
    local t= io.popen(cmd)
    local a = t:read("*all")
    io.close(t)
    local time = tonumber(a)
    if (time < 60 * cache_minutes)  then
        print("文件较新，读取缓存文件："..score_api_filename .. ",路径 " ..newsApi)
        t= io.open(score_api_filename,'r')
        local body = t:read("*all")
        io.close(t)
        scoreRes={}
        scoreRes.body=body
        cache_score=false
    end
end

local t= io.open(ngx.var.request_filename,'r')
local body = t:read("*all")
io.close(t)
body=body:gsub("<!%-%-.-%-%->","")
body = string.gsub( body,"#title#",site_name)

if not newsRes or not newsRes.body then
    newsRes = ngx.location.capture(newsApi)
end
if not scoreRes or not scoreRes.body then
    scoreRes = ngx.location.capture(scoreApi)
end

if newsRes and string.len(newsRes.body) > 10  then
    if cache_news  then
        saveToFile(news_api_filename,newsRes.body)
    end
    -- ngx.say(newsRes.body)
    -- body = string.gsub( body,"var newsdata={};","var newsdata="..newsRes.body..";")
    
    newsJson = cjson.decode(newsRes.body);
    if (newsJson["code"] == 200 ) then
        local html=""
        for i, news in ipairs(newsJson.data.list) do
            html=html..'<a href="/news_' .. news.id .. '.html" target="_blank" class="news"><div class="img_wapper"><img class="img lazy_post lazy" data-src="' ..  news.img .. '" ></div> <div class="right"><div class="text">' ..  news.title ..  '</div> <div class="time">' ..  news.time .. '</div></div></a>'
        end
        html = html.."<div></div>"
        body = string.gsub( body,"新闻列表加载中...",html)
        body = body:gsub("initDataValue",newsJson.data.token..","..cid..","..subId..","..hot)
    end
end
if scoreRes  and string.len(scoreRes.body) > 10  then
    if cache_score  then
        saveToFile(score_api_filename,scoreRes.body)
    end
    -- ngx.say(scoreRes.body)
    scoreJson = cjson.decode(scoreRes.body);
    if (scoreJson["code"] == 200 ) then
        local html=""
        for i, score in ipairs(scoreJson.data.score) do
            html= html..'<tr class="tr"><td class="td">' .. score.position ..  '</td> <td class="td"><div class="img_wapper"><img class="img lazy_brand lazy" data-src="' ..  score.logo .. '" ></div>' ..  score.name ..  '</td> <td class="td">'..  score.won ..  '/' ..  score.draw ..  '/' ..  score.lose ..  '</td> <td class="td">' ..  score.score .. '</td></tr>'
        end
        body = string.gsub( body,"积分榜列表加载中...",html)
    end
    -- body = string.gsub( body,"var scoredata={};","var scoredata="..scoreRes.body..";")
end
ngx.say(body)