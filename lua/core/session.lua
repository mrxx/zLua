local exception = loadMod("core.exception")
local redis = loadMod("core.driver.redis")
local sysConf = loadMod("config.system")
local cacheConf = loadMod("config.cache")

--- 最后一次请求缓存的键名前缀
local TOKEN_INDEX_PREFIX = sysConf.SERVER_MARK .. ".userToken."

local Session = {
    --- Session存储处理器实例
    cacheHelper = nil,
}

--- Session模块初始化
--
-- @return table Session模块
function Session:init()
    self.cacheHelper = redis:getInstance(cacheConf.INDEX_SESSION)
    return self
end

--- 注册Session信息
--
-- @param table userInfo 用户信息
-- @return string 验证密钥
function Session:register(userInfo)
    if not userInfo or not userInfo.userId then
        exception:raise("core.systemErr", { userInfo = userInfo })
    end

    local index = TOKEN_INDEX_PREFIX .. userInfo.userId
    local token = self.cacheHelper:get(index)

    if token then
        self.cacheHelper:del(token)
    end

    token = ngx.md5(table.concat({ sysConf.SERVER_MARK, ngx.now(), userInfo.userId }, "."))

    exception:assert("core.systemErr", { token = token }, self.cacheHelper:set(index, token, sysConf.SESSION_EXPTIME))
    exception:assert("core.systemErr", { token = token }, self.cacheHelper:set(token, userInfo, sysConf.SESSION_EXPTIME))

    return token
end

--- 获取Session信息(并增加操作锁)
--
-- @param string token 验证密钥
-- @return table 用户信息
function Session:check(token)
    local userInfo = self.cacheHelper:get(token)

    if not userInfo or not userInfo.userId then
        exception:raise("core.needLogin", { token = token })
    end

    while not (self.cacheHelper:add(token .. ".lock", true, sysConf.LOCKER_TIMEOUT)) do
        ngx.sleep(sysConf.LOCKER_RETRY_INTERVAL)
    end

    ngx.ctx[Session] = token
    return userInfo
end

--- 销毁Session信息
--
-- @param string 验证密钥
function Session:destroy(token)
    self.cacheHelper:del(token)
end

--- 解除操作锁
function Session:unlock()
    local token = ngx.ctx[Session]

    if token then
        self.cacheHelper:del(token .. ".lock")
    end
end

return Session:init()
