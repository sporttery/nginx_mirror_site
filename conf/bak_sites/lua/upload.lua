local upload = require "resty.upload"
local cjson = require "cjson"

-- test.sh 
-- curl -F "filename=@/home/test/test.wav" "http://127.0.0.1/uploadfile.gss?filename=test.wav&&type=wav&&billingcode=87654321"

local response = {["code"] = 200, ["msg"] = "upload success!"} 

local args = ngx.req.get_uri_args()
if not args then
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

local filename = args["filename"] or "noname.file"

ngx.log(ngx.ERR,"upload-filename:"..filename);

-- 判断文件类型
local res, err = ngx.re.match(filename, [[\.(?:xml|wav|png|jpg|jpeg)$]])
if not res then
    response.code = 401
    response.msg = "only xml|wav|ext|png|jpg|jpeg format file can upload"
    ngx.say(cjson.encode(response))
    return
end

if err then
    ngx.log(ngx.ERR, "match err:", err)
    ngx.exit(ngx.HTTP_BAD_REQUEST)
end

-- 保存文件根目录

local save_file_dir = ngx.var.document_root.."/upload/images"



local dfile = io.open(save_file_dir, "rb")
if dfile then
    dfile:close()
else
    local md = "mkdir -p "
    local mdpath = md .. save_file_dir
    os.execute(mdpath)
    ngx.log(ngx.ERR, "create save file first dir: " .. mdpath)
end

save_file_dir = save_file_dir .. "/"
local ext = filename:match(".+%.(%w+)$")
filename = ngx.md5(filename..tostring(os.time()))..'.'..ext

-- 创建各类文件的保存子目录[按billingcode存储]
local save_file_path = save_file_dir..filename

response["path"] = "/upload/images/"..filename


-- 创建上传form
local chunk_size = 8192 -- should be set to 4096 or 8192

local form, err = upload:new(chunk_size)
if not form then
    ngx.log(ngx.ERR, "failed to new upload: ", err)
    ngx.exit(500)
end

form:set_timeout(1000) -- 1 sec

local function close_file(write_file)
    if io.type(write_file) == "file" then  -- write_file处于打开状态，则关闭文件。
        write_file:close()
        write_file = nil
    end
end

-- 上传过程
local write_file -- 文件句柄
while true do
    local typ, recv, err = form:read()
    if not typ then
        response.code = 403
        -- ngx.say("failed to read file: ", err)
        response.msg = "failed to read file"
        break
    end

    if typ == "header" and "file" ~= io.type(write_file) then
        write_file, err = io.open(save_file_path, 'wb+')
        if err then
            ngx.log(ngx.ERR, "failed create hd:", err)
            response.code = 404
            response.msg = "failed create file:" .. err
            break
        end
    elseif typ == "body" and "file" == io.type(write_file) then
        write_file:write(recv)
    elseif typ == "part_end" then
        close_file(write_file)
    elseif typ == "eof" then
        response.code = 200 
        response.msg = "upload success"
        break
    end
end

ngx.say(cjson.encode(response))