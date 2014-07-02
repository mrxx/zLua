local util = loadMod("core.util")
local daoBase = loadMod("core.base.dyncDao")
local cacheConf = loadMod("config.cache")

local User = {
    --- 数据库表名
    TABLE_NAME = "game_user",

    --- 主键
    PRIMARY_KEY = { "id" },

    --- 自增索引键
    AUTOINCR_KEY = "id",

    --- 是否缓存
    CACHE_ENABLE = true,

    --- 缓存库索引
    CACHE_INDEX = cacheConf.INDEX_USER,

    --- 记录变化键名
    logChangeKey = "user",
}

--- 获取指定名称的用户信息
--
-- @param string name 用户名称
-- @return table|nil 用户信息
function User:getByName(name)
    return self.dbHelper:fetchRow("`name`={1}", { name })
end

--- 获取指定ID序列的用户信息
--
-- @param table ids ID序列
-- @return table 用户信息序列
function User:getByIds(ids)
    return self.dbHelper:fetchRows("`id` IN (" .. self:createFields(#ids) .. ")", ids)
end

--- 判断指定名称是否已存在
--
-- @param string name 用户名称
-- @return boolean 是否已存在
function User:nameExist(name)
    return tonumber(self.dbHelper:fetchValue("`name`={1}", { name }, "COUNT(*)")) > 0
end

--- 获取所有用户数量
--
-- @return number 用户数量
function User:countAll()
    return tonumber(self.dbHelper:fetchValue("1", nil, "COUNT(*)"))
end

--- 分页获取所有用户信息
--
-- @param number offset 起始位置
-- @param number length 获取数量
-- @param string sortBy 排序字段
-- @param string sortDir 排序方法
-- @return table 用户信息序列
function User:getAll(offset, length, sortBy, sortDir)
    sortBy = sortBy or "id"
    sortDir = sortDir or "ASC"

    local where = "1 ORDER BY `" .. sortBy .. "` " .. sortDir

    if offset and length then
        where = where .. " LIMIT " .. offset .. "," .. length
    end

    return self.dbHelper:fetchRows(where)
end

return util:inherit(User, daoBase):init()
