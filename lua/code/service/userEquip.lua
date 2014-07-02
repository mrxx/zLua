local util = loadMod("core.util")
local exception = loadMod("core.exception")
local serviceBase = loadMod("core.base.service")
local consts = loadMod("code.const.equip")
local equipService = util:getService("equip")

local UserEquip = {
    --- 数据访问模块名
    DAO_NAME = "userEquip",
}

--- 重新计算效果和出售价格
--
-- @param table userEquip 用户装备信息
-- @param table equipInfo 装备类型信息
function UserEquip:recalc(userEquip, equipInfo)
    userEquip.price = equipInfo.price + (userEquip.level ^ 2) * consts.PRICE_LEVEL_RATIO
    userEquip.effects = {}

    for index, effect in ipairs(equipInfo.effects) do
        userEquip.effects[index] = {
            type = effect.type,
            value = math.floor(effect.baseValue + (userEquip.level - 1) * effect.growValue)
        }
    end
end

--- 创建新装备
--
-- @param number userId 用户ID
-- @param number equipId 装备类型ID
-- @param number level 强化等级
-- @return table 用户装备
function UserEquip:create(userId, equipId, level)
    local equipInfo = equipService:getOne(equipId)

    if not equipInfo then
        return nil
    end

    local userEquip = {
        userId = userId,
        heroId = 0,
        equipId = equipId,
        position = equipInfo.position,
        level = level or 1,
        effects = {},
        price = equipInfo.price
    }

    self:recalc(userEquip, equipInfo)
    self.dao:add(userEquip)

    return userEquip
end

--- 购买
--
-- @param table user 用户信息
-- @param number equipId 装备类型ID
-- @return table 用户装备信息
function UserEquip:buy(user, equipId)
    local equip = equipService:getOne(equipId)

    if not equip then
        exception:raise("equip.typeError", { equipId = equipId })
    end

    util:getService("user"):spentGold(user, equip.price, true)

    return self:create(user.id, equipId, 1)
end

--- 卖出
--
-- @param table user 用户信息
-- @param table userEquips 用户装备信息序列
-- @return number 卖出金币数量
function UserEquip:sell(user, userEquips)
    local equipIds, totalGold = {}, 0

    for _, userEquip in ipairs(userEquips) do
        if userEquip.userId ~= user.id then
            exception:raise("core.forbidden", { equipId = userEquip.id, userId = userEquip.userId, needUserId = user.id })
        end

        if userEquip.heroId > 0 then
            exception:raise("equip.wasEquiped", { equipId = userEquip.id, heroId = userEquip.heroId })
        end

        totalGold = totalGold + userEquip.price
        equipIds[#equipIds + 1] = userEquip.id
    end

    self:removeByIds(equipIds)

    user.gold = user.gold + totalGold
    util:getService("user"):update(user, { "gold" })

    return totalGold
end

--- 切换装备
--
-- @param table userHero 用户英雄信息
-- @param number position 装备位置
-- @param table userEquip 用户装备信息
function UserEquip:equip(userHero, position, userEquip)
    if userEquip then
        if userEquip.position ~= position then
            exception:raise("core.forbidden", { equipId = userEquip.id, position = position })
        end

        if userEquip.heroId ~= 0 then
            exception:raise("equip.wasEquiped", { heroId = heroId, equipId = equipId })
        end
    end

    local oldEquip = self:getByPos(userHero.id, position)

    if oldEquip then
        oldEquip.heroId = 0
        self:update(oldEquip, { "heroId" })
    end

    if userEquip then
        userEquip.heroId = userHero.id
        self:update(userEquip, { "heroId" })
    end

    local userHeroService = util:getService("userHero")
    local props = userHeroService:adjust(userHero)

    if #props > 0 then
        userHeroService:update(userHero, props)
    end
end

--- 强化装备
--
-- @param table user 用户信息
-- @param table userEquip 用户装备信息
function UserEquip:refine(user, userEquip)
    if userEquip.level >= consts.MAX_LEVEL then
        exception:raise("equip.maxLevel", { level = userEquip.level })
    end

    local equipInfo = equipService:getOne(userEquip.equipId)

    if not equipInfo then
        exception:raise("equip.typeError", { id = userEquip.id, equipId = userEquip.equipId })
    end

    local refineCost = math.floor((userEquip.level ^ 2) * equipInfo.refineRatio)

    util:getService("user"):spentGold(user, refineCost, true)

    userEquip.level = userEquip.level + 1

    self:recalc(userEquip, equipInfo)
    self:update(userEquip, { "level", "effects", "price" })

    if userEquip.heroId > 0 then
        local userHeroService = util:getService("userHero")
        local userHero = userHeroService:getOne(userEquip.heroId)

        if userHero then
            local props = userHeroService:adjust(userHero, {})

            if #props > 0 then
                userHeroService:update(userHero, props)
            end
        end
    end
end

return serviceBase:inherit(UserEquip):init()

