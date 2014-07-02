local json = require("cjson")
local memcached = require("resty.memcached")
local util = loadMod("core.util")
local exception = loadMod("core.exception")
local counter = loadMod("core.counter")
local dbConf = loadMod("config.memcached")

local Memcached = {}

--- 初始化连接
--
-- @return resty.memcached Memcached连接
local function initClient()
    -- 新建连接
    local client = exception:assert("core.connectFailed", {}, memcached:new())

    -- 设置超时
    client:set_timeout(dbConf.TIMEOUT)

    -- 连接服务器
    exception:assert("core.connectFailed", {}, client:connect(dbConf.HOST, dbConf.PORT))

    ngx.ctx[Memcached] = client
    return ngx.ctx[Memcached]
end

--- 获取连接
--
-- @return resty.memcached Memcached连接
local function getClient()
    return ngx.ctx[Memcached] or initClient()
end

--- 关闭连接
local function closeClient()
    if ngx.ctx[Memcached] then
        ngx.ctx[Memcached]:set_keepalive(dbConf.TIMEOUT, dbConf.POOL_SIZE)
        ngx.ctx[Memcached] = nil
    end
end

--- 转化null为nil
--
-- @param mixed value
-- @return mixed
local function nul2nil(value)
    if value == ngx.null then
        return nil
    end

    return value
end

--- 将任意值编码为格式字符串
--
-- @param mixed value
-- @return string
local function encode(value)
    if util:isNumber(value) then
        return value
    else
        return "*" .. json.encode(value)
    end
end

--- 将格式字符串解码为值
--
-- @param string value
-- @return mixed
local function decode(value)
    if nul2nil(value) == nil then
        return nil
    end

    local flag = value:sub(1, 1)

    if flag == "*" then
        return json.decode(value:sub(2))
    end

    return value
end

--- 执行命令
--
-- @param string cmd 命令
-- @param mixed ... 命令参数
-- @return mixed 命令结果
function Memcached:execute(cmd, ...)
    local client = getClient()

    if not client[cmd] then
        exception:raise("core.badCall", { cmd = cmd, args = { ... } })
    end

    counter:set(counter.COUNTER_MEMCACHED)

    local result, errmsg = client[cmd](client, ...)

    if errmsg and errmsg ~= "NOT_FOUND" and errmsg ~= "NOT_STORED" then
        exception:raise("core.queryFailed", { args = { ... }, message = errmsg })
    end

    return result
end

--- 获取键名的值
--
-- @param string key 键名
-- @return mixed 值
function Memcached:get(key)
    local value = self:execute("get", { key })[key]
    return value and decode(value[1])
end

--- 获取键名序列的键值表
--
-- @param table keys 键名序列(Array模式)
-- @return table 键值表(Hash模式)
function Memcached:gets(keys)
    local values = self:execute("get", keys)
    local result = {}

    for key, value in pairs(values) do
        result[key] = decode(value[1])
    end

    return result
end

--- 新增键名的值（键名已存在则失败）
--
-- @param string key 键名
-- @param mixed value 值
-- @param number expiration 有效期(不设置或为0则永不过期)
-- @return boolean 是否成功
function Memcached:add(key, value, expiration)
    value = encode(value)
    expiration = util:numval(expiration, true)

    return self:execute("add", key, value, expiration) and true or false
end

--- 设置键名的值
--
-- @param string key 键名
-- @param mixed value 值
-- @param number expiration 有效期(不设置或为0则永不过期)
-- @return boolean 是否成功
function Memcached:set(key, value, expiration)
    value = encode(value)
    expiration = util:numval(expiration, true)

    return self:execute("set", key, value, expiration) and true or false
end

--- 替换键名的值（键名不存在则失败）
--
-- @param string key 键名
-- @param mixed value 值
-- @param number expiration 有效期(不设置或为0则永不过期)
-- @return boolean 是否成功
function Memcached:replace(key, value, expiration)
    value = encode(value)
    expiration = util:numval(expiration, true)

    return self:execute("replace", key, value, expiration) and true or false
end

--- 删除键名
--
-- @param string key 键名
-- @return boolean 是否成功
function Memcached:del(key)
    return self:execute("delete", key) and true or false
end

--- 清空所有数据
--
-- @return boolean 是否成功
function Memcached:flushAll()
    return self:execute("flush_all") and true or false
end

--- 获取统计信息
--
-- @return table 统计信息
function Memcached:stat()
    local lines = self:execute("stats")
    local result = {}

    for _, line in ipairs(lines) do
        local key, value = line:match("^STAT ([%w%d_.]+) ([%w%d_.]+)$")

        if key and value then
            result[key] = tonumber(value)
        end
    end

    return result
end

--- 关闭连接
function Memcached:close()
    closeClient()
end

return Memcached