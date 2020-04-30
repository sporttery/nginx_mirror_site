local args = nil
local request_method = ngx.var.request_method
local cjson = require 'cjson'
--获取参数的值
if 'GET' == request_method then
    args = ngx.req.get_uri_args()
elseif 'POST' == request_method then
    ngx.req.read_body()
    args = ngx.req.get_post_args()
end

local response = {}
local filename = ngx.var.document_root .. '/ad_config.json'
ngx.header['Content-Type'] = 'application/json;charset=UTF-8'
if request_method == 'POST' and args then
    local downloadQrcode = args['downloadQrcode']
    local wxQrcode = args['wxQrcode']
    local downloadAddr = args['downloadAddr']
    local wxText = args['downloadAddr'] or ""
    if downloadQrcode and wxQrcode and downloadAddr then
        local file = io.open(filename, 'w')
        if file then
            local conf = {}
            conf['downloadQrcode'] = downloadQrcode
            conf['wxQrcode'] = wxQrcode
            conf['downloadAddr'] = downloadAddr
            conf['wxText'] = wxText
            local data = cjson.encode(conf)
            file:write(data)
            file:flush()
            file:close()
            response.code = 200
            response.msg = '保存成功'
        else
            response.code = 201
            response.msg = '保存失败,创建文件出错'
        end
    end
else
    response.code = 202
    response.msg = '非法请求'
end
ngx.say(cjson.encode(response))