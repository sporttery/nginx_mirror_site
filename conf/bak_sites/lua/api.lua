local cjson = require "cjson" 
local args = nil
local request_method = ngx.var.request_method
local no_log = 'true' == ngx.var.no_log
--获取参数的值
if "GET" == request_method then
    args = ngx.req.get_uri_args()
elseif "POST" == request_method then
    ngx.req.read_body()
    args = ngx.req.get_post_args()
end
local api = ngx.var.api;

if api == "list" then
    api = "App.Site.Stream_list";
end

local cache_minutes = tonumber(ngx.var.cache_minutes) or 5;
function getLiveAddr(match)
    local url = match["play_url"]
    local cmd = 'curl -s -L '..url
    local t = io.popen(cmd)
    local a = t:read("*all")
    io.close(t)
    match.videoArr = {}
    for w in string.gmatch(a, "%['.-%]") do
        table.insert(match.videoArr,w)
    end
end
if api and string.len(api) > 0 then
    local cache_file = "/var/www/"..api
    -- local cmd = "if [ -f '"..cache_file.."' ] ; then  expr $(date +%s) - $(stat -c \"%Z\" '"..cache_file.."') ;else echo 100000 ;fi;"
    -- if not no_log then
    --     ngx.log(ngx.ERR,"cmd:"..cmd)
    -- end
    -- local t= io.popen(cmd)
    -- local a = t:read("*all")
    -- io.close(t)
    -- local time = tonumber(a)
    local body = nil
    local liveAddr = args["liveAddr"] == "1"
    local live = args["live"] == "1"
    local matchStatus = tonumber(args["matchStatus"])
    local mId = tonumber(args["mId"])
    local sportId = tonumber(args["sportId"]) or 0
    
    --只有是直播中才需要采地址
    if liveAddr then
        live = true
        matchStatus = nil
    end
    local getNewApi = false;
    -- 不要读缓存
    -- if (time < 60 * cache_minutes)  then
        if not no_log then
            ngx.log(ngx.ERR,"文件较新，读取缓存文件："..cache_file )
        end
        t= io.open(cache_file,'r')
        body = t:read("*all")
        io.close(t)
    --     if(liveAddr and string.find(body,"videoArr") ~= nil ) then --文件里有获取过视频地址了
    --         liveAddr = false
    --     end
        if ( string.sub(body,1,1) ~= "{" and string.sub(body,1,1) ~= "[" ) or string.len(body) < 30 then
            getNewApi = true
        end
    -- end
    if getNewApi then
        cmd = 'curl -s -L "http://www.skrsport.live/?service='..api..'" -H "Connection: keep-alive" -H "Accept: */*" -H "X-Requested-With: XMLHttpRequest" -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.130 Safari/537.36" -H "Origin: http://www.skrsport.live" -H "Referer: http://www.skrsport.live/docs.php?service=App.Site.Stream_list&detail=1&type=expand" -H "Accept-Encoding: gzip, deflate" -H "Accept-Language: zh-CN,zh;q=0.9" -H "Cookie: username=sport_api; secret=0gclkqzK" --data "username=sport_api&secret=0gclkqzK" --compressed --insecure | sed \'s/play_url /play_url/g\' | tee ' ..cache_file
        if not no_log then
            ngx.log(ngx.ERR,"cmd:"..cmd)
        end
        t = io.popen(cmd)
        body = t:read("*all")
        io.close(t)
    end
    if api == "App.Site.Stream_list"  then
        local jsonD  = cjson.decode(body)
        local data = {}
        if ( jsonD and type(jsonD) == "table" ) then
            if   jsonD.data and type(jsonD.data) == "table" then
                data = jsonD.data
            else 
                data = jsonD
            end
        end
        
        local nt = {}
        
        -- ngx.log(ngx.ERR,string.format( "live=%s,matchStatus=%s,liveAddr=%s",live,matchStatus,liveAddr ))
        for key, val in pairs(data) do
            if type(val) == "table" then
                local sport_id = tonumber(val.sport_id)
                local match_status = tonumber(val.match_status)
                local live_status = tonumber(val.live_status)
                local match_id = tonumber(val.match_id)
                
                -- ngx.log(ngx.ERR,string.format( "live=%s,matchStatus=%s,liveAddr=%s,match_status=%s",live,matchStatus,liveAddr,match_status ))
                local matched = false;
                if ( sport_id == 1 and  live_status == 1 ) then --足球
                    if live  then --直播中的
                        matched = match_status >= 2 and match_status <= 7
                    elseif matchStatus then --指定状态的
                        matched = match_status == matchStatus
                    else --未开始，直播中，赛场的
                        matched = match_status >= 1 and  match_status <= 8  
                    end
                    
                elseif (  sport_id == 2  and live_status == 1 ) then --篮球
                    if live  then --直播中的
                        matched = match_status >= 2 and match_status <= 9
                    elseif matchStatus then --指定状态的
                        matched = match_status == matchStatus
                    else --未开始，直播中，赛场的
                        matched = match_status >= 1 and  match_status <= 10  
                    end
                end
                
                if mId then  --如果有传id，则必须匹配ID才行，且抓取直播地址 ,
                    if mId == match_id then
                        matched = true
                        liveAddr = true
                    else
                        matched = false
                    end
                elseif  sportId > 0 and sportId ~= sport_id then --如果有传sportId，则需要匹配
                    matched = false
                end
                if matched then
                    if liveAddr then
                        getLiveAddr(val)
                    end
                    table.insert(nt,val)
                end
            else
                ngx.say("body:"..body)
                ngx.exit(ngx.HTTP_OK)
            end
        
        end
        body = cjson.encode(nt)
    end
    ngx.say(body)
else
    ngx.say("{ret:200,msg:'api err'}");
end