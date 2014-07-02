local util = loadMod("core.util")
local exception = loadMod("core.exception")
local request = loadMod("core.request")
local response = loadMod("core.response")
local ctrlBase = loadMod("core.base.ctrl")
local userService = util:getService("user")
local userHeroService = util:getService("userHero")

--- 英雄操作
local Hero = {}

--- 英雄购买
--
-- @param string token 验证密钥
-- @param int heroId 购买英雄ID
-- @return {"ok":true}
function Hero:buy()
    local userInfo = self:getSessionInfo()
    local heroId = request:getNumParam("heroId", true, true)
    local user = userService:getOne(userInfo.userId)

    if not user then
        exception:raise("user.needInit", { userId = userInfo.userId })
    end

    userHeroService:buy(user, heroId)
    response:reply({ ok = true })
end

--- 英雄出售
--
-- @param string token 验证密钥
-- @param string sellIds 卖出英雄ID序列（逗号隔开）
-- @return {"ok":true}
function Hero:sell()
    local userInfo = self:getSessionInfo()
    local sellIds = request:getNumsParam("sellIds", true, true)

    if #sellIds == 0 then
        exception:raise("core.badParams", { sellIds = sellIds })
    end

    local user = userService:getOne(userInfo.userId)

    if not user then
        exception:raise("user.needInit", { userId = userInfo.userId })
    end

    local sellHeros = userHeroService:getByIds(sellIds)

    if #sellHeros ~= #sellIds then
        exception:raise("core.forbidden", { sellIds = sellIds })
    end

    userHeroService:sell(user, sellHeros)
    response:reply({ ok = true })
end

--- 吞噬英雄升级
--
-- @param string token 验证密钥
-- @param int heroId 英雄ID
-- @param string devourIds 吞噬英雄ID序列（逗号隔开）
-- @return {"ok":true}
function Hero:devour()
    local userInfo = self:getSessionInfo()
    local heroId = request:getNumParam("heroId", true, true)
    local devourIds = request:getNumsParam("devourIds", true, true)

    if #devourIds == 0 then
        exception:raise("core.badParams", { devourIds = devourIds })
    end

    local user = userService:getOne(userInfo.userId)

    if not user then
        exception:raise("user.needInit", { userId = userInfo.userId })
    end

    local userHero = userHeroService:getOne(heroId)

    if not userHero or userHero.userId ~= user.id then
        exception:raise("core.forbidden", { heroId = heroId })
    end

    local devourHeros = userHeroService:getByIds(devourIds)

    if #devourHeros ~= #devourIds then
        exception:raise("core.forbidden", { devourIds = devourIds })
    end

    userHeroService:devour(user, userHero, devourHeros)
    response:reply({ ok = true })
end

return util:inherit(Hero, ctrlBase)
