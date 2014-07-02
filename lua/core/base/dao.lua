local util = loadMod("core.util")
local sysConf = loadMod("config.system")

local DaoBase = {
    --- 键名分隔符
    KEY_SEPARATOR = ".",

    --- 数据库表名
    TABLE_NAME = nil,

    --- 主键
    PRIMARY_KEY = { "id" }
}

--- 获取缓存键名
--
-- @param mixed ... 关键字
-- @return string 缓存键名
function DaoBase:getCacheKey(...)
    return table.concat({ sysConf.SERVER_MARK, self.TABLE_NAME, ... }, self.KEY_SEPARATOR)
end

--- 获取主键相关信息(参数为主键属性表或主键属性值序列)
--
-- @param mixed firstArg 主键属性表(Hash模式)或主键属性值序列首元素
-- @param mixed ... 主键属性值序列其他元素
-- @return string 缓存键名
-- @return string 查询条件
-- @return table 查询参数
function DaoBase:getPrimaryInfo(firstArg, ...)
    local useTable = util:isTable(firstArg)
    local params = useTable and firstArg or { firstArg, ... }

    local queryItems = {}
    local cacheItems = {}

    for index, key in ipairs(self.PRIMARY_KEY) do
        local value

        if useTable then
            value = params[key]
            queryItems[#queryItems + 1] = "`" .. key .. "`={" .. key .. "}"
        else
            value = params[index]
            queryItems[#queryItems + 1] = "`" .. key .. "`={" .. index .. "}"
        end

        util.table:extend(cacheItems, key, value)
    end

    local cacheKey = self:getCacheKey(unpack(cacheItems))
    local queryWhere = table.concat(queryItems, " AND ")

    return cacheKey, queryWhere, params
end

--- 获取主键缓存键名
--
-- @param mixed firstArg 主键属性表(Hash模式)或主键属性值序列首元素
-- @param mixed ... 主键属性值序列其他元素
-- @return string 缓存键名
function DaoBase:getPrimaryCacheKey(firstArg, ...)
    local useTable = util:isTable(firstArg)
    local params = useTable and firstArg or { firstArg, ... }
    local cacheItems = { self.TABLE_NAME }

    for index, key in ipairs(self.PRIMARY_KEY) do
        local value

        if useTable then
            value = params[key]
        else
            value = params[index]
        end

        util.table:extend(cacheItems, key, value)
    end

    return table.concat(cacheItems, self.KEY_SEPARATOR)
end

--- 获取指定数量的字段查询格式
--
-- @param number num 字段数量
-- @param number start 起始索引
-- @return string 字段查询格式
function DaoBase:createFields(num, start)
    start = start or 1
    local items = {}

    for i = start, start + num - 1 do
        items[#items + 1] = "{" .. i .. "}"
    end

    return table.concat(items, ",")
end

return DaoBase
