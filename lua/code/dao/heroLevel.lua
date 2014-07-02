local util = loadMod("core.util")
local daoBase = loadMod("core.base.staticDao")

local HeroLevel = {
    --- 数据库表名
    TABLE_NAME = "data_hero_level",

    --- 主键
    PRIMARY_KEY = { "level" },

    --- 缓存策略
    CACHE_RULES = {},
}

return util:inherit(HeroLevel, daoBase):init()
