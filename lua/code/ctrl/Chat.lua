local util = loadMod("core.util")
local exception = loadMod("core.exception")
local request = loadMod("core.request")
local response = loadMod("core.response")
local push = loadMod("core.push")
local ctrlBase = loadMod("core.base.ctrl")
local redis = loadMod("core.driver.redis")
local sysConf = loadMod("config.system")
local cacheConf = loadMod("config.cache")
local consts = loadMod("code.const.push")
local userService = util:getService("user")

--- 最后一次发送聊天消息的键名前缀
local LAST_CHAT_PREFIX = sysConf.SERVER_MARK .. ".lastChat"

--- 聊天操作
local Chat = {
    --- 缓存处理器实例
    cacheHelper = nil,
}

--- 聊天控制器初始化
--
-- @return table 聊天控制器
function Chat:init()
    self.cacheHelper = redis:getInstance(cacheConf.INDEX_CACHE)
    return self
end

--- 发送聊天消息
--
-- @param string token 验证密钥
-- @param int channel 频道ID
-- @param string toName 接收用户名
-- @param string content 聊天内容
-- @return {"ok":true}
function Chat:say()
    local userInfo = self:getSessionInfo()
    local content = request:getStrParam("content", true)
    local channel = request:getNumParam("channel", true, true)
    local toName = request:getStrParam("toName")

    local channelInfo = consts.CHANNEL_INFO[channel]

    if not channelInfo then
        exception:raise("core.badParams", { channel = channel })
    end

    -- 检查发送间隔
    local lastChatKey = table.concat({ LAST_CHAT_PREFIX, channelInfo.prefix, userInfo.userId }, ".")

    if self.cacheHelper:exists(lastChatKey) then
        exception:raise("chat.tooFast", { userId = userInfo.userId, channel = channel })
    end

    -- 获取发送用户信息
    local user = userService:getOne(userInfo.userId)

    if not user then
        exception:raise("user.needInit", { userId = userInfo.userId })
    end

    -- 禁言状态检查
    if userService:isBanChat(user) then
        exception:raise("chat.banChat", { userId = userInfo.userId, userStatus = user.status })
    end

    local message = { fromId = user.id, fromName = user.name, content = util.string:replaceFilter(content) }
    local extendId

    if channel == consts.CHANNEL_USER then
        if toName == "" then
            exception:raise("chat.sendToUnknow", { toName = toName })
        end

        -- 获取接收用户信息
        local toUser = userService:getByName(toName)

        if not toUser then
            exception:raise("chat.sendToUnknow", { toName = toName })
        end

        extendId = toUser.id
        message.toId = toUser.id
        message.toName = toUser.name

        -- 发送消息给自己
        push:toChannel(message, consts.OP_PUSH_CHAT, channel, userInfo.userId)
    end

    -- 发送消息给频道
    push:toChannel(message, consts.OP_PUSH_CHAT, channel, extendId)

    -- 更新发送间隔标识
    self.cacheHelper:set(lastChatKey, true, channelInfo.interval)

    -- 返回结果
    response:reply({ ok = true })
end

--- 推送频道聊天消息（推送）
--
-- @return {"op":2,"data":{"channel":1,"zoneOffset":28800,"serverTime":1403601121,"v":8509,"content":"test","fromId":1,"fromName":"zivn"},"error":null}
function Chat:tell() end

--- Ping消息
--
-- @return {"op":3,"data":{"channel":3,"zoneOffset":28800,"serverTime":1403601121,"v":8509},"error":null}
function Chat:ping() end

return util:inherit(Chat, ctrlBase):init()
