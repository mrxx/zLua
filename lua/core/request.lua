local zlib = require("zlib")
local util = loadMod("core.util")
local exception = loadMod("core.exception")
local sysConf = loadMod("config.system")
local actConf = loadMod("config.action")

local Request = {}

--- 分析参数
--
-- @param table args 源参数表(Hash模式)
-- @param table data 目标参数表(Hash模式)
local function parseArgs(args, data)
    for key, val in pairs(args) do
        if key == "op" then
            val = tonumber(val)

            if val then
                data.op = val
            end
        elseif key == "act" then
            local module, method = val:match("^(%w+)%.(%w+)$")

            if module and method then
                data.action = { module, method }
            end
        else
            data.params[key] = val
        end
    end
end

--- 分析请求参数(根据GET、POST、COOKIE开关分析参数，并根据操作码设置动作)
--
-- @return table 参数表(Hash模式)
local function parseRequestData()
    local data = {
        op = 0,
        action = {},
        params = {},
        cookie = {},
        time = ngx.req.start_time(),
        ip = ngx.var.remote_addr
    }

    if sysConf.GET_ENABLE then
        parseArgs(ngx.req.get_uri_args(), data)
    end

    local headers

    if sysConf.POST_ENABLE then
        ngx.req.read_body()
        local body = ngx.req.get_body_data()

        if body then
            headers = headers or ngx.req.get_headers()

            if headers["Content-Encoding"] == "gzip" then
                body = zlib.inflate()(body)
            end

            if sysConf.ENCRYPT_REQUEST then
                body = util:encrypt(body, sysConf.ENCRYPT_KEY)
            end

            parseArgs(ngx.decode_args(body), data)
        end
    end

    if sysConf.COOKIE_ENABLE then
        local header = headers or ngx.req.get_headers()

        if header.cookie then
            for key, value in header.cookie:gmatch("([%w_]+)=([^;]+)") do
                data.cookie[key] = value
            end
        end
    end

    if #data.action == 0 and data.op ~= 0 then
        local action = actConf[data.op]

        if action and #action == 2 then
            data.action = action
        end
    end

    ngx.ctx[Request] = data
    return ngx.ctx[Request]
end

--- 获取请求数据
--
-- @return table 参数表
local function getRequestData()
    return ngx.ctx[Request] or parseRequestData()
end

--- 获取请求操作码
--
-- @return number 操作码
function Request:getOp()
    return getRequestData().op
end

--- 获取请求动作
--
-- @return table 动作[string 模块, string 方法]
function Request:getAction()
    return getRequestData().action
end

--- 获取Cookie中指定键的值
--
-- @param string key
-- @return string
function Request:getCookie(key)
    return getRequestData().cookie[key]
end

--- 获取请求发起时间
--
-- @return number 带小数(毫秒)的时间戳
function Request:getTime()
    return getRequestData().time
end

--- 获取请求发起IP
--
-- @return string
function Request:getIp()
    return getRequestData().ip
end

--- 是否为本机请求
--
-- @return boolean
function Request:isLocal()
    return getRequestData().ip == ngx.var.server_addr
end

--- 获取请求参数中的数字参数
--
-- @param string name    键名
-- @param boolean abs     是否取绝对值
-- @param boolean nonzero 是否不允许为零
-- @return number 参数值
function Request:getNumParam(name, abs, nonzero)
    local param = getRequestData().params[name]
    local value = util:numval(param, abs)

    if nonzero and value == 0 then
        exception:raise("core.badParams", { name = name, value = param })
    end

    return value
end

--- 获取请求参数中的字符串参数
--
-- @param string name     键名
-- @param boolean nonempty 是否不允许为空
-- @param boolean trim     是否去除首尾空格
-- @return string 参数值
function Request:getStrParam(name, nonempty, trim)
    local param = getRequestData().params[name]
    local value = param or ""

    if trim and value ~= "" then
        value = util.string:trim(value)
    end

    if nonempty and value == "" then
        exception:raise("core.badParams", { name = name, value = param })
    end

    return value
end

--- 获取请求参数中的数字序列参数
--
-- @param string name     键名
-- @param boolean abs      是否取绝对值
-- @param boolean nonempty 是否不允许为空
-- @return table 参数表(Array模式的number表)
function Request:getNumsParam(name, abs, nonempty)
    local param = self:getStrParam(name, nonempty)
    local value = {}

    if param then
        for num in param:gmatch("[+%-]?[%d%.]+") do
            local val = tonumber(num)

            if val then
                if abs then
                    val = math.abs(val)
                end

                value[#value + 1] = val
            end
        end
    end

    if nonempty and #value == 0 then
        exception:raise("core.badParams", { name = name, value = param })
    end

    return value
end

return Request
