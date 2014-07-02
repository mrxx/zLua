local util = loadMod("core.util")
local exception = loadMod("core.exception")
local serviceBase = loadMod("core.base.service")
local consts = loadMod("code.const.hero")
local heroService = util:getService("hero")
local heroLevelService = util:getService("heroLevel")
local userEquipService = util:getService("userEquip")

local UserHero = {
    --- 数据访问模块名
    DAO_NAME = "userHero",
}

--- 获取吞噬所需的金币消耗
--
-- @param number level 英雄等级
-- @param number devourNum 吞噬个数
-- @return number 所需金币
function UserHero:getDevourCost(level, devourNum)
    return heroLevelService:getOne(level).costRate * devourNum
end

--- 获取英雄出售金币价格
--
-- @param table userHero 用户英雄信息
-- @return number 出售金币价格
function UserHero:getSellPrice(userHero)
    return heroService:getOne(userHero.heroId).price + (userHero.level ^ 2) * consts.PRICE_LEVEL_RATIO
end

--- 执行效果
--
-- @param table userHero 用户英雄信息
-- @param table effect 效果
function UserHero:execEffect(userHero, effect)
    if effect and effect.type > 0 and effect.value > 0 then
        local attrib = consts.EFFECT_MAP[effect.type]

        if attrib then
            userHero[attrib] = userHero[attrib] + effect.value
        end
    end
end

--- 校正英雄属性
--
-- @param table userHero 用户英雄信息
-- @param table props 变更属性序列
-- @return table 变更属性序列
function UserHero:adjust(userHero, props)
    props = props or {}

    local heroInfo = heroService:getOne(userHero.heroId)
    local attribs = {
        hp = math.floor(heroInfo.hp + heroInfo.hpGrow * userHero.level),
        att = math.floor(heroInfo.att + heroInfo.attGrow * userHero.level),
        def = math.floor(heroInfo.def + heroInfo.defGrow * userHero.level),
        hit = heroInfo.hit,
        dodge = heroInfo.dodge,
        crit = heroInfo.crit
    }

    if userHero.id and userHero.id > 0 then
        --- 装备影响
        local equips = userEquipService:getByHero(userHero.id)

        for _, equip in pairs(equips) do
            for _, effect in pairs(equip.effects) do
                self:execEffect(attribs, effect)
            end
        end
    end

    for key, value in pairs(attribs) do
        if userHero[key] ~= value then
            userHero[key] = value
            props[#props + 1] = key
        end
    end

    return props
end

--- 检查用户英雄升级
--
-- @param table userHero 用户英雄信息
-- @return boolean 是否升级
function UserHero:checkUpgrade(userHero)
    local levels = heroLevelService:getOne()

    if userHero.level >= levels[#levels].level then
        exception:raise("hero.maxLevel", { level = userHero.level })
    end

    local oLevel = userHero.level

    for i = userHero.level + 1, #levels do
        local level = levels[i]

        if userHero.exp < level.exp then
            break
        end

        userHero.level = i
    end

    if userHero.level > oLevel then
        userHero.price = self:getSellPrice(userHero)
        return true
    end

    return false
end

--- 更新用户英雄信息
--
-- @param table userHero 用户英雄信息
-- @param table props 变更属性序列
-- @return number 更新用户英雄信息数量
function UserHero:update(userHero, props)
    if util.table:hasValue(props, "exp") and self:checkUpgrade(userHero) then
        util.table:extend(props, "level", "price")
    end

    if util.table:hasValue(props, "level") then
        self:adjust(userHero, props)
    end

    return self.dao:update(userHero, props)
end

--- 创建新英雄
--
-- @param number userId 用户ID
-- @param number heroId 英雄类型ID
-- @param number level 英雄等级
-- @return table 用户英雄信息
function UserHero:create(userId, heroId, level)
    local hero = heroService:getOne(heroId)

    if not hero then
        return nil
    end

    local userHero = {
        userId = userId,
        heroId = hero.id,
        level = level or 1,
    }

    userHero.price = self:getSellPrice(userHero)
    userHero.exp = heroLevelService:getOne(userHero.level).exp

    self:adjust(userHero, {})
    self:add(userHero)

    return userHero
end

--- 卸载指定英雄序列身上的全部装备
--
-- @param table heroIds 用户英雄ID序列
function UserHero:unloadEquips(heroIds)
    local equipIds = userEquipService:getIdsByHeros(heroIds)

    if #equipIds > 0 then
        userEquipService:setHeroByIds(equipIds, 0)
    end
end

--- 购买
--
-- @param table user 用户信息
-- @param number heroId 英雄ID
-- @return table 用户英雄信息
function UserHero:buy(user, heroId)
    local hero = heroService:getOne(heroId)

    if not hero then
        exception:raise("core.forbidden", { heroId = heroId, userId = user.id })
    end

    util:getService("user"):spentGold(user, hero.price, true)

    return self:create(user.id, heroId, 1)
end

--- 卖出
--
-- @param table user 用户信息
-- @param table userHeros 用户英雄信息序列
-- @return number 卖出金币数量
function UserHero:sell(user, userHeros)
    local heroIds, totalGold = {}, 0

    for _, userHero in ipairs(userHeros) do
        if userHero.userId ~= user.id then
            exception:raise("core.forbidden", { heroId = userHero.id, userId = userHero.userId, needUserId = user.id })
        end

        totalGold = totalGold + userHero.price
        heroIds[#heroIds + 1] = userHero.id
    end

    self:unloadEquips(heroIds)
    self:removeByIds(heroIds)

    user.gold = user.gold + totalGold
    util:getService("user"):update(user, { "gold" })

    return totalGold
end

--- 吞噬
--
-- @param table user 用户信息
-- @param table userHero 用户英雄信息
-- @param table devourHeros 被吞噬的英雄序列
function UserHero:devour(user, userHero, devourHeros)
    if #devourHeros > consts.MAX_DEVOUR_NUM then
        exception:raise("hero.wrongNumHero", { needNum = consts.MAX_DEVOUR_NUM, hasNum = #devourHeros })
    end

    local heroIds, totalExp = {}, 0

    for _, devourHero in ipairs(devourHeros) do
        if devourHero.id == userHero.id or devourHero.userId ~= userHero.userId then
            exception:raise("core.forbidden", { heroId = devourHero.id, userId = devourHero.userId, needUserId = userHero.userId })
        end

        totalExp = totalExp + math.floor(devourHero.exp * consts.DEVOUR_EXP_RATE)
        heroIds[#heroIds + 1] = devourHero.id
    end

    local devourCost = self:getDevourCost(userHero.level, #devourHeros)
    util:getService("user"):spentGold(user, devourCost, true)

    self:unloadEquips(heroIds)
    self:removeByIds(heroIds)

    userHero.exp = userHero.exp + totalExp
    self:update(userHero, { "exp" })
end

return serviceBase:inherit(UserHero):init()

