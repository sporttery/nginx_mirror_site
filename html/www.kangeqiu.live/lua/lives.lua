local type= ngx.var.arg_type or "1"
local hot= ngx.var.arg_hot or "0"
local channel_id= ngx.var.arg_channel_id or "0"
local page= ngx.var.arg_page or "1"
local date= ngx.var.arg_date or ""


local cache_dynamic_link = ngx.var.cache_dynamic_link == "true"
local cache_minutes = tonumber(ngx.var.cache_minutes or 0)
local no_log = ngx.var.no_log == "true"
local site_name = ngx.var.site_name or '免费看球神器【官网】'

local function print(msg)
    if not no_log then
        ngx.log(ngx.ERR,msg)
    end
end

if channel_id == "-1" then
    channel_id = "0"
end
local liveApi = "/api/web/live?type="..type.."&channel_id="..channel_id.."&hot="..hot.."&page="..page




require("tools")
local cjson = require("cjson")
local livesRes 
local cache_lives = cache_dynamic_link
local lives_api_filename = ngx.var.document_root.."/cache/lives-type_"..type.."-channel_id_"..channel_id.."-hot_"..hot.."-page_"..page

if data ~= "" then
    liveApi = liveApi.."&date="..date;
    lives_api_filename = lives_api_filename.."&date="..date;
end

lives_api_filename = lives_api_filename ..".json"

--如果有缓存文件，且满足缓存时间 ，直接返回
--当带参数refresh 时强制刷新
if (cache_dynamic_link and file_exists(lives_api_filename)) and not ngx.var.arg_refresh then
    local cmd = "expr $(date +%s) - $(stat -c \"%Y\" '"..lives_api_filename.."')"
    local t= io.popen(cmd)
    local a = t:read("*all")
    io.close(t)
    local time = tonumber(a)
    if (time < 60 * cache_minutes)  then
        print("文件较新，读取缓存文件："..lives_api_filename .. ",路径 " ..liveApi)
        t= io.open(lives_api_filename,'r')
        local body = t:read("*all")
        io.close(t)
        livesRes={}
        livesRes.body=body
        cache_lives=false
    end
end


local t= io.open(ngx.var.document_root.."/lives.html",'r')
local body = t:read("*all")
io.close(t)
body=body:gsub("<!%-%-.-%-%->","")
body = string.gsub( body,"#title#",site_name)

if not livesRes or not livesRes.body then
    livesRes = ngx.location.capture(liveApi)
end

-- ngx.say(livesRes.body)

if livesRes and string.len(livesRes.body) > 10  then
    if cache_lives  then
        livesRes.body = livesRes.body:gsub("null","\"\"")
        saveToFile(lives_api_filename,livesRes.body)
    end
   
    livesJson = cjson.decode(livesRes.body);
    if (livesJson["code"] == 200 ) then
        local html=""
        local dateTitle=""
        for i, match in ipairs(livesJson.data) do
            local match_date = os.date('%Y-%m-%d', match.match_time)
            local match_time= os.date('%H:%M', match.match_time)
            if dateTitle ~= match_date then
                dateTitle = match_date
                html = html..'<p class="list_title">'..dateTitle..'</p>'
            end
            local home_logo = match.home.logo ;
            local visiting_logo = match.visiting.logo ;

            if  home_logo == "" then
                home_logo="/images/icon_team_80_default.png"
            end

            if  visiting_logo == "" then
                visiting_logo="/images/icon_team_80_default.png"
            end

            html=html..'<div class="item" data-mid="'..match.mid..'" data-match_time="'..match.match_time..'" data-match_id="'..match.match_id..'"><div class="right">'..match_time..'</div> <div class="center"><p class="p right">'..match.home.name..'</p> <div class="img_wapper"><img class="img lazy_brand lazy" data-src="'..home_logo..'" ></div> <p class="point right">'..match.home.score..'</p> <div class="detail"><p class="small"><span data-id="'..match.event_id..'">'..match.event_name..'</span> <span></span></p> <p class="big">'..match.statusInfo..'</p></div> <p class="point left">'..match.visiting.score..'</p> <div class="img_wapper"><img class="img lazy_brand lazy" data-src="'..visiting_logo..'" ></div> <p class="p left">'..match.visiting.name..'</p></div> <div class="right"><a href="javascript:void(0);" class="link b_gray"><span class="web_front data"></span>数据</a></div></div>'
        end
        html = html.."<div class=\"fetching\"></div>"
        body = string.gsub( body,"列表加载中...",html)
        body = body:gsub("initDataValue",type..","..channel_id..","..hot..","..date)
    end
end

ngx.say(body)