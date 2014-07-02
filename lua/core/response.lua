local json = require("cjson")
local util = loadMod("core.util")
local exception = loadMod("core.exception")
local request = loadMod("core.request")
local counter = loadMod("core.counter")
local sysConf = loadMod("config.system")
local changeLogger = loadMod("core.changes")
local redis = loadMod("core.driver.redis")
local cacheConf = loadMod("config.cache")

--- 最后一次请求缓存的键名前缀
local LAST_RES_PREFIX = sysConf.SERVER_MARK .. ".lastRes."

local Response = {
    --- Response存储处理器实例
    cacheHelper = nil,
}

--- Response模块初始化
--
-- @return table Response模块
function Response:init()
    self.cacheHelper = redis:getInstance(cacheConf.INDEX_CACHE)
    return self
end

--- 输出应答数据(Json格式，调试模式时会在header中加入调试信息)
--
-- @param table message 消息
-- @param boolean noCache 不缓存
function Response:output(message, noCache, noEncode)
    json.encode_sparse_array(true)
    local content = noEncode and message or json.encode(message)

    ngx.status = ngx.HTTP_OK
    ngx.header.charset = sysConf.DEFAULT_CHARSET
    ngx.header.content_type = "application/json"
    ngx.header.content_length = content:len() + 1

    if sysConf.DEBUG_MODE then
        ngx.header.mysqlQuery = counter:get(counter.COUNTER_MYSQL)
        ngx.header.redisCommand = counter:get(counter.COUNTER_REDIS)
        ngx.header.memcachedCommand = counter:get(counter.COUNTER_MEMCACHED)
        ngx.header.execTime = ngx.now() - request:getTime()
    end

    ngx.say(content)
    ngx.eof()

    if not noCache then
        local op = request:getOp()
        local token = request:getStrParam(sysConf.SESSION_TOKEN_NAME)
        local r = request:getStrParam("r")

        if op > 0 and token ~= "" and r ~= "" then
            self.cacheHelper:set(LAST_RES_PREFIX .. token, { op = op, r = r, content = content }, 3600)
        end
    end
end

--- 添加消息
--
-- @param table data 消息
-- @param number op 操作码(省略时自动从请求中获取)
-- @param boolean noChanges 不添加改变数据
function Response:reply(data, op, noChanges)
    data = data or {}
    util:jsonPrep(data)

    local message = {
        op = op or request:getOp(),
        data = data,
        error = NULL
    }

    if not noChanges then
        local updates, removes = changeLogger:getChanges()
        message.changes = {}

        if not util.table:isEmpty(updates) then
            util:jsonPrep(changes)
            message.changes.updates = updates
        end

        if not util.table:isEmpty(removes) then
            message.changes.removes = removes
        end
    end

    self:output(message)
end

--- 添加错误
--
-- @param table|string err 错误
-- @param number op 操作码(省略时自动从请求中获取)
function Response:error(err, op)
    if util:isString(err) then
        err = exception:pack("core.systemErr", { errmsg = err })
    end

    err.op = op or request:getOp()
    err.data = err.data or {}
    err.error = err.error or "core.systemErr"

    self:output(err)
end

--- 检查重试请求，如果存在缓存则返回缓存
--
-- @return boolean
function Response:checkRetry()
    local op = request:getOp()
    local token = request:getStrParam(sysConf.SESSION_TOKEN_NAME)
    local r = request:getStrParam("r")

    if op > 0 and token ~= "" and r ~= "" then
        local lastRes = self.cacheHelper:get(LAST_RES_PREFIX .. token)

        if lastRes and lastRes.op == op and lastRes.r == r then
            self:output(lastRes.content, true, true)
            return true
        end
    end

    return false
end

return Response:init()

