local cjson = require "cjson" 
    
local args = nil
local request_method = ngx.var.request_method
--获取参数的值
if "GET" == request_method then
    args = ngx.req.get_uri_args()
elseif "POST" == request_method then
    ngx.req.read_body()
    args = ngx.req.get_post_args()
end
ngx.header['Content-Type']="text/html;charset=UTF-8"
local filepath = ngx.var.request_filename
-- ngx.log(ngx.ERR,"文件："..filepath)
local includeCss = '';
local includeJs = 'function nofind(src){ var img=event.srcElement; if(src && src!="")img.src=src; img.οnerrοr=null; }';
local sportId = args["sportId"] or "0"
local res = ngx.location.capture("/plans/match.php?type="..sportId)
-- ngx.log(ngx.ERR,res.body)
local imageView = ngx.var.imageView;
if not imageView then
    imageView = "imageView2/2/w/200"
end

if res and res.body and (string.sub(res.body,1,1) == '[' or string.sub(res.body,1,1) == '{')
then
    
    local jsonList  = cjson.decode(res.body)
    local dataList ;
    local liveRes = nil 
    if ( sportId == "0" ) then
        liveRes = ngx.location.capture("/api/list?live=1&sportId="..sportId)
    end
    if liveRes and liveRes.body and (string.sub(res.body,1,1) == '[' or string.sub(res.body,1,1) == '{') then
        -- ngx.log(ngx.ERR,liveRes.body)
        local liveList  = cjson.decode(liveRes.body)
        dataList = {}
        if (#liveList > 0) then
            local tmpL = {}
            for k,v in pairs(liveList) do
                tmpL["_"..v.match_id] = v;
            end
            for k,v in pairs(jsonList) do
                if tmpL["_"..v.id] then
                    table.insert( dataList, v )
                end
            end
        end
    else
        dataList = jsonList
    end
    local htmlTemp='<a class="clearfix " href="/video.html?id=%s&sportId=%s"><section class="clearfix"><div class="team"><span><img alt="%s" src="%s" onerror="nofind(\'%s\')" style="display: block;"></span><p>%s</p></div><div class="center"><p class="eventtime"><span class="feleimg"><img src="%s"> </span> <span>%s %s </span></p><p class="vsp">VS</p><p class="video %s"><i class="video-icon"></i><span>视频直播</span></p></div><div class="team"><span><img alt="%s" src="%s" onerror="nofind(\'%s\')" style="display: block;"></span><p>%s</p></div></section></a>'
    local html = ''
    for k,v in pairs(dataList) do
        local pngs =v["nameT"]
        if (tonumber(pngs)~=1) then
            pngs = '/images/fenlei_2.png';
        else
            pngs = '/images/fenlei_1.png';
        end
        local zb_green = 'zb_green'
        if (tonumber(v["state"])==1) then
            zb_green = ""
        end
        local k_time = v["k_time"]
        local dtime = v["dtime"]
        local playTime = os.date("%Y-%m-%d %H:%M:%S",tonumber(v["beginTime"]))
        -- //http://cdn.sportnanoapi.com/football/team/f37322461cfaef4c78a7fdfb31e56c2a.png?imageView/2/w/200
        local homeLogo = v["homeTeamInfo"]["logo"];
        local homeLogoCdn = ""
        if string.len(homeLogo)<80 then
            homeLogo = pngs
        else
            homeLogoCdn = "http://cdn.sportnanoapi.com/football/team/"..string.gsub(homeLogo,"^.+/(.*)$","%1").."?"..imageView;
        end
        local awayLogo = v["visitingTeamInfo"]["logo"];
        local awayLogoCdn = ""
        if string.len(awayLogo)<80 then
            awayLogo = pngs
        else
            awayLogoCdn = "http://cdn.sportnanoapi.com/football/team/"..string.gsub(awayLogo,"^.+/(.*)$","%1").."?"..imageView;
        end
        local matchName = v["matcheventInfo"]["shortNameZh"] ;
        if string.len(matchName) == 0 then
            matchName = v["matcheventInfo"]["nameZh"]
        end

        local homeName = v["homeTeamInfo"]["nameZh"];
        local awayName = v["visitingTeamInfo"]["nameZh"];

        -- html = html..string.format( htmlTemp,v["id"],sportId,homeName,homeLogoCdn,homeLogo,homeName,pngs,matchName,k_time,zb_green,awayName,awayLogoCdn,awayLogo,awayName )
        html = html..string.format( htmlTemp,v["id"],v["nameT"],homeName,homeLogo,pns,homeName,pngs,matchName,k_time,zb_green,awayName,awayLogo,pngs,awayName )

    end

    
    local file = io.open(filepath,'r')
    if(file) then
        local body = file:read("*all")
        io.close(file)
        local class1={"","","",""}
        class1[sportId+1] = "active"
        if (string.len(html)<100) then
            html = '<div style="text-align:center;font-size:30px;"><a href="/bifen.html" style="color:orange;">暂无数据，请到比分页面查看</a></div>';
        end
        body = string.format(body,class1[1],class1[2],class1[3],class1[4],html )
        body = string.gsub( body,"/%*includeCss%*/", includeCss);
        body = string.gsub( body,"/%*includeJs%*/", includeJs);
        ngx.say(body)
        ngx.exit(ngx.HTTP_OK)
    else
        ngx.log(ngx.ERR," file:"..filepath .."找不到")
        ngx.exit(ngx.HTTP_NOT_FOUND)
    end
else
    ngx.log(ngx.ERR,"/plans/match.php?type="..sportId .." 没有数据")
    ngx.exit(ngx.HTTP_NOT_FOUND)
end
