local util = loadMod("core.util")
local exception = loadMod("core.exception")
local serviceBase = loadMod("core.base.service")
local consts = loadMod("code.const.user")
local sysConf = loadMod("config.system")
local userLevelService = util:getService("userLevel")

local User = {
    --- 数据访问模块名
    DAO_NAME = "user",
}

--- 混淆密码
--
-- @param string passwd 用户密码
-- @return string 混淆后的密码
function User:mixPwd(passwd)
    return util.string:sha1(passwd .. sysConf.PASSWD_MIX_KEY)
end

--- 是否被封禁登陆
--
-- @param table user 用户信息
-- @return boolean 是否被封禁登陆
function User:isBanLogin(user)
    return util:hasBit(user.status, consts.STATUS_BAN_LOGIN)
end

--- 是否被封禁聊天
--
-- @param table user 用户信息
-- @return boolean 是否被封禁聊天
function User:isBanChat(user)
    return util:hasBit(user.status, consts.STATUS_BAN_CHAT)
end

--- 创建新用户
--
-- @param string name 用户名称
-- @param string passwd 用户密码
-- @param number icon 用户头像
-- @param number heroId 初始英雄ID
-- @param string clientIp 用户IP
-- @return table 用户信息
function User:create(name, passwd, icon, heroId, clientIp)
    local nowTime = util:now()

    --- 初始化用户
    local user = self:add({
        name = name,
        passwd = self:mixPwd(passwd),
        icon = icon,
        level = consts.INIT_LEVEL,
        exp = consts.INIT_EXP,
        lastEnergy = consts.INIT_ENERGY,
        lastModify = util:now(),
        maxEnergy = consts.INIT_MAXENERGY,
        gold = consts.INIT_GOLD,
        regTime = nowTime,
        regIp = clientIp,
        loginTime = nowTime,
        loginIp = clientIp,
    })

    --- 初始化英雄
    util:getService("userHero"):create(user.id, heroId)

    return user
end

--- 更新用户信息
--
-- @param table user 用户信息
-- @param table props 变更属性序列
-- @return number 更新用户信息数量
function User:update(user, props)
    if util.table:hasValue(props, "exp") then
        local levels = userLevelService:getOne()
        local oLevel = user.level

        for i = user.level + 1, #levels do
            local level = levels[i]

            if user.exp < level.exp then
                break
            end

            user.level = i
            user.lastEnergy = user.lastEnergy + level.energy
        end

        if user.level > oLevel then
            util.table:extend(props, "level", "lastEnergy")
        end
    end

    return self.dao:update(user, props)
end

--- 花费金币
--
-- @param table user 用户信息
-- @param number num 花费数量
-- @param boolean doUpdate 是否更新
function User:spentGold(user, num, doUpdate)
    if user.gold < num then
        exception:raise("user.lessGold", { userId = user.id, needGold = num, hasGold = user.gold })
    end

    user.gold = user.gold - num
    if doUpdate then
        self:update(user, { "gold" })
    end
end

--- 花费活力
--
-- @param table user 用户信息
-- @param number num 花费数量
-- @param boolean doUpdate 是否更新
function User:spentEnergy(user, num, doUpdate)
    local period = math.floor((util:now() - user.lastModify + consts.ENERGY_FIX_TIME) / consts.ENERGY_GROW_PERIOD)
    local energy = math.min(user.maxEnergy, user.lastEnergy + period * consts.ENERGY_GROW_STEP)

    if energy < num then
        exception:raise("user.lessEnergy", { userId = user.id, needEnemy = num, hasEnemy = energy })
    end

    user.lastEnergy = energy - num
    user.lastModify = user.lastModify + period * consts.ENERGY_GROW_PERIOD

    if doUpdate then
        self:update(user, { "lastEnergy", "lastModify" })
    end
end

--- 获取用户相关信息
--
-- @param table user 用户信息
-- @return table 用户相关信息
function User:getUserData(user)
    return {
        user = user,
        heros = util:getService("userHero"):getByUser(user.id),
        equips = util:getService("userEquip"):getByUser(user.id)
    }
end

return serviceBase:inherit(User):init()

