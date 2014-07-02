local util = loadMod("core.util")
local daoBase = loadMod("core.base.staticDao")

local UserLevel = {
    --- 数据库表名
    TABLE_NAME = "data_user_level",

    --- 主键
    PRIMARY_KEY = { "level" },

    --- 缓存策略
    CACHE_RULES = {},
}

return util:inherit(UserLevel, daoBase):init()
