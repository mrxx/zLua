local util = loadMod("core.util")
local daoBase = loadMod("core.base.staticDao")

local Hero = {
    --- 数据库表名
    TABLE_NAME = "data_hero",

    --- 主键
    PRIMARY_KEY = { "id" },

    --- 缓存策略
    CACHE_RULES = {},
}

return util:inherit(Hero, daoBase):init()
