local request = loadMod("core.request")
local util = loadMod("core.util")
local session = loadMod("core.session")
local changes = loadMod("core.changes")
local exception = loadMod("core.exception")
local sysConf = loadMod("config.system")

local CtrlBase = {}

--- 过滤器
function CtrlBase:filter()
    local isSuperIp = util:inIpList(request:getIp(), sysConf.SUPER_IPS)

    if not isSuperIp then
        local nowTime = util:now()

        if nowTime < util:parseDTime(sysConf.SERVER_START_TIME) then
            exception:raise("core.serverClose", { serverStartTime = sysConf.SERVER_START_TIME })
        end

        if nowTime < util:parseDTime(sysConf.SERVER_MT_ENDLINE) then
            exception:raise("core.serverClose", { serverMtTime = sysConf.SERVER_MT_ENDLINE })
        end
    end
end

--- 清理器
function CtrlBase:cleaner() end

--- 获取Session信息
--
-- @return table 用户信息
function CtrlBase:getSessionInfo()
    local userInfo = session:check(request:getStrParam(sysConf.SESSION_TOKEN_NAME, true))

    changes:init(userInfo)

    return userInfo
end

return CtrlBase


