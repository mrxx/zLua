local util = loadMod("core.util")
local daoBase = loadMod("core.base.dyncDao")
local cacheConf = loadMod("config.cache")

local UserHero = {
    --- 数据库表名
    TABLE_NAME = "game_user_hero",

    --- 主键
    PRIMARY_KEY = { "id" },

    --- 自增索引键
    AUTOINCR_KEY = "id",

    --- JSON类型键集合
    JSON_KEYSET = { fates = true },

    --- 是否缓存
    CACHE_ENABLE = true,

    --- 缓存库索引
    CACHE_INDEX = cacheConf.INDEX_HERO,

    --- 记录变化键名
    logChangeKey = "heros",
}

--- 获取指定ID序列的用户英雄信息
--
-- @param table ids ID序列
-- @return table 用户英雄信息序列
function UserHero:getByIds(ids)
    return self.dbHelper:fetchRows("`id` IN (" .. self:createFields(#ids) .. ")", ids)
end

--- 获取指定用户的所有英雄信息
--
-- @param number userId 用户ID
-- @return table 用户英雄信息序列
function UserHero:getByUser(userId)
    return self.dbHelper:fetchRows("`userId`={1}", { userId })
end

--- 获取指定用户的装备数量
--
-- @param number userId 用户ID
-- @return number 装备数量
function UserHero:countByUser(userId)
    return tonumber(self.dbHelper:fetchValue("`userId`={1}", { userId }, "COUNT(*)")) or 0
end

--- 分页获取所有用户英雄信息
--
-- @param number offset 起始位置
-- @param number length 获取数量
-- @param string sortBy 排序字段
-- @param string sortDir 排序方法
-- @return table 用户英雄信息序列
function UserHero:getAll(offset, length, sortBy, sortDir)
    sortBy = sortBy or "id"
    sortDir = sortDir or "ASC"

    local where = "1 ORDER BY `" .. sortBy .. "` " .. sortDir

    if offset and length then
        where = where .. " LIMIT " .. offset .. "," .. length
    end

    return self.dbHelper:fetchRows(where)
end

return util:inherit(UserHero, daoBase):init()
