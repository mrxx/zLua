local util = loadMod("core.util")
local daoBase = loadMod("core.base.staticDao")

local Equip = {
    --- 数据库表名
    TABLE_NAME = "data_equip",

    --- 主键
    PRIMARY_KEY = { "id" },

    --- 缓存策略
    CACHE_RULES = {},
}

--- 解析并重整数据
--
-- @param table entity 数据
function Equip:parseEntity(entity)
    entity.effects = {}

    if entity.baseEffectType > 0 and entity.baseEffectValue > 0 then
        entity.effects[#entity.effects + 1] = {
            type = entity.baseEffectType,
            baseValue = entity.baseEffectValue,
            growValue = entity.baseEffectGrow
        }
    end

    entity.baseEffectType = nil
    entity.baseEffectValue = nil
    entity.baseEffectGrow = nil

    if entity.extendEffectType > 0 and entity.extendEffectValue > 0 then
        entity.effects[#entity.effects + 1] = {
            type = entity.extendEffectType,
            baseValue = entity.extendEffectValue,
            growValue = 0
        }
    end

    entity.extendEffectType = nil
    entity.extendEffectValue = nil
end

return util:inherit(Equip, daoBase):init()
