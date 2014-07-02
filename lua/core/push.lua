local json = require("cjson")
local util = loadMod("core.util")
local request = loadMod("core.request")
local redis = loadMod("core.driver.redis")
local sysConf = loadMod("config.system")
local cacheConf = loadMod("config.cache")
local consts = loadMod("code.const.push")

--- 推送消息版本号键名
local VERSION_KEY = sysConf.SERVER_MARK .. ".pushVer"

local Push = {
    --- Push存储处理器实例
    cacheHelper = nil,
}

--- 推送模块初始化
--
-- @return table 推送模块
function Push:init()
    self.cacheHelper = redis:getInstance(cacheConf.INDEX_CACHE)
    return self
end

--- 推送给频道
--
-- @param table data 消息
-- @param number op 操作码(省略时自动从请求中获取)
-- @param number channelId 频道ID
-- @param number extendId 扩展ID
function Push:toChannel(data, op, channelId, extendId)
    local message = {
        op = op or request:getOp(),
        data = data or {},
        error = ngx.null
    }

    message.data.serverTime = math.floor(ngx.now())
    message.data.zoneOffset = util:getTimeOffset()
    message.data.channel = channelId
    message.data.v = self.cacheHelper:increase(VERSION_KEY, 1)

    local content = json.encode(message)
    local channel = consts.CHANNEL_INFO[channelId].prefix

    if extendId then
        channel = channel .. extendId
    end

    if sysConf.ENCRYPT_REPLY then
        content = util:encrypt(content, sysConf.ENCRYPT_KEY)
    end

    util:proxy(sysConf.PUSH_PUB_URI, { id = sysConf.SERVER_MARK .. channel }, content)
end

--- 推送给用户频道
--
-- @param table data 消息
-- @param number op 操作码(省略时自动从请求中获取)
-- @param number userId 用户ID
function Push:toUser(data, op, userId)
    return self:toChannel(data, op, consts.CHANNEL_USER, userId)
end

--- 推送给世界频道
--
-- @param table data 消息
-- @param number op 操作码(省略时自动从请求中获取)
function Push:toWorld(data, op)
    return self:toChannel(data, op, consts.CHANNEL_WORLD)
end

--- 推送给Ping频道
function Push:toPing()
    return self:toChannel(nil, consts.OP_PUSH_PING, consts.CHANNEL_PING)
end

--- 获取最新的推送消息版本
--
-- @return number
function Push:getVersion()
    return tonumber(self.cacheHelper:get(VERSION_KEY)) or 0
end

return Push:init()

