local util = loadMod("core.util")
local exception = loadMod("core.exception")
local request = loadMod("core.request")
local response = loadMod("core.response")
local ctrlBase = loadMod("core.base.ctrl")
local userService = util:getService("user")
local userHeroService = util:getService("userHero")
local userEquipService = util:getService("userEquip")

--- 装备操作
local Equip = {}

--- 装备购买
--
-- @param string token 验证密钥
-- @param int equipId 购买装备ID
-- @return {"ok":true}
function Equip:buy()
    local userInfo = self:getSessionInfo()
    local equipId = request:getNumParam("equipId", true, true)
    local user = userService:getOne(userInfo.userId)

    if not user then
        exception:raise("user.needInit", { userId = userInfo.userId })
    end

    userEquipService:buy(user, equipId)
    response:reply({ ok = true })
end

--- 装备出售
--
-- @param string token 验证密钥
-- @param string sellIds 卖出装备ID序列（逗号隔开）
-- @return {"ok":true}
function Equip:sell()
    local userInfo = self:getSessionInfo()
    local sellIds = util.string:toNumList(request:getStrParam("sellIds", true), ",")

    if #sellIds == 0 then
        exception:raise("core.badParams", { sellIds = sellIds })
    end

    local user = userService:getOne(userInfo.userId)

    if not user then
        exception:raise("user.needInit", { userId = userInfo.userId })
    end

    local sellEquips = userEquipService:getByIds(sellIds)

    if #sellEquips ~= #sellIds then
        exception:raise("core.forbidden", { sellIds = sellIds })
    end

    userEquipService:sell(user, sellEquips)
    response:reply({ ok = true })
end

--- 切换装备
--
-- @param string token 验证密钥
-- @param int heroId 英雄ID
-- @param int position 装备位置
-- @param int equipId 装备ID
-- @return {"ok":true}
function Equip:equip()
    local userInfo = self:getSessionInfo()
    local heroId = request:getNumParam("heroId", true, true)
    local position = request:getNumParam("position", true, true)
    local equipId = request:getNumParam("equipId", true, true)

    local userHero = userHeroService:getOne(heroId)

    if not userHero or userHero.userId ~= userInfo.userId then
        exception:raise("core.forbidden", { heroId = heroId })
    end

    local userEquip

    if equipId > 0 then
        userEquip = userEquipService:getOne(equipId)

        if not userEquip or userEquip.userId ~= userInfo.userId then
            exception:raise("core.forbidden", { equipId = equipId })
        end
    end

    userEquipService:equip(userHero, position, userEquip)

    response:reply({ ok = true })
end

--- 强化装备
--
-- @param string token 验证密钥
-- @param int equipId 装备ID
-- @return {"ok":true}
function Equip:refine()
    local userInfo = self:getSessionInfo()
    local equipId = request:getNumParam("equipId", true, true)

    local user = userService:getOne(userInfo.userId)

    if not user then
        exception:raise("user.needInit", { userId = userInfo.userId })
    end

    local userEquip = userEquipService:getOne(equipId)

    if not userEquip or userEquip.userId ~= user.id then
        exception:raise("core.forbidden", { equipId = equipId })
    end

    userEquipService:refine(user, userEquip)
    response:reply({ ok = true })
end

return util:inherit(Equip, ctrlBase)
