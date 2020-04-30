local args = nil
local request_method = ngx.var.request_method
--获取参数的值
if "GET" == request_method then
    args = ngx.req.get_uri_args()
elseif "POST" == request_method then
    ngx.req.read_body()
    args = ngx.req.get_post_args()
end

local mId = args["id"] or "0"
local sportId = args["sportId"] or "0"
if mId == "0" or sportId == "0" then
    ngx.log( ngx.ERR," id和sportId 是必传项" )
    ngx.exit(ngx.HTTP_NOT_FOUND)
end
ngx.header['Content-Type']="text/html;charset=UTF-8"
local includeCss = '';
local includeJs = '';
local res = ngx.location.capture("/plans/video.php?type="..sportId.."&id="..mId)
if res and res.body and string.sub(res.body,1,1) == '{' then
    local cjson = require "cjson" 
    local jsonD  = cjson.decode(res.body)
    if jsonD["visitingTeamInfo"] then
        local playTime = jsonD["aTime"]
        local awayName = jsonD["visitingTeamInfo"]["nameZh"]
        local homeName = jsonD["homeTeamInfo"]["nameZh"]
        local leagueName = jsonD["matcheventInfo"]["shortNameZh"]
        local kTime = jsonD["k_time"]
        local video = jsonD["video"]
        local homeScore = jsonD["homeScore"] or "0"
        local awayScore = jsonD["visitingScore"] or "0"
        -- ngx.log(ngx.ERR,video)
        local vSrc = string.gsub(video,".*videourl=(.*)","%1")
        local playDate = string.sub(playTime,1,10)
        --萨拉基利斯 VS 特彻哈萨斯|立陶杯|02月15日|【在线直播】-925直播
        local title = string.format( "%s VS %s|%s|%s|【在线直播】-UC直播",homeName,awayName,leagueName, playDate)
        --萨拉基利斯 VS 特彻哈萨斯
        local keywords = string.format( "%s VS %s",homeName,awayName)
        -- 02月15日《萨拉基利斯 VS 特彻哈萨斯》 立陶杯直播将在02月15日准时在线直播，敬请关注。
        local description = string.format( "%s《%s VS %s》 %s直播将在%s准时在线直播，敬请关注。",playDate,homeName,awayName,leagueName,playTime)
        --正在直播： 15:05 鹿岛鹿角 45 vs 52 长崎成功丸（天皇杯）
        local biaoti = string.format( "正在直播： %s %s %s vs %s %s（%s）",kTime,homeName,homeScore,awayScore,awayName,leagueName)
        --videSrc
        local videoSrc = "https://live.iixxix.cn/player.php?stream_name="..mId
        local playHtml = ' <iframe  id="frame" width="100%" src="'..videoSrc..'" style="height: 540px;" allowfullscreen="true" webkitallowfullscreen="true" mozallowfullscreen="true" scrolling="no" ></iframe> '
        local mPlayerUrlRes = ngx.location.capture("/api/list?mId="..mId)
        if mPlayerUrlRes and mPlayerUrlRes.body and string.sub(mPlayerUrlRes.body,1,1) == '[' then
            jsonMatch  = cjson.decode(mPlayerUrlRes.body)[1]
            videoArr = jsonMatch["videoArr"]
            videoSrc = videoArr[1]
            if #videoArr > 2 then
                videoSrc = videoArr[2]
            end
            videoSrc = string.match(videoSrc,"'(.-)'")
            playHtml = '<div id="playerbox"  width="100%" data-src="'..videoSrc..'" style="height: 200px;"></div>'
        end
        local filepath = ngx.var.request_filename
        local file = io.open(filepath,'r')
        if(file) then
            local body = file:read("*all")
            io.close(file)
            -- ngx.log(ngx.ERR,body)
            body = string.format(body,title,keywords,description,playTime,biaoti,playHtml,sportId,mId )
            body = string.gsub( body,"/%*includeCss%*/", includeCss);
            body = string.gsub( body,"/%*includeJs%*/", includeJs);
            ngx.say(body)
        else
            ngx.log(ngx.ERR," file:"..filepath .."找不到")
            ngx.exit(ngx.HTTP_NOT_FOUND)
        end
        ngx.exit(ngx.HTTP_OK)
    else
        ngx.exit(ngx.HTTP_NOT_FOUND)
    end
end
