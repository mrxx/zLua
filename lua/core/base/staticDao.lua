local util = loadMod("core.util")
local exception = loadMod("core.exception")
local mysql = loadMod("core.driver.mysql")
local daoBase = loadMod("core.base.dao")

local StaticDaoBase = {
    --- 数据库表名
    TABLE_NAME = nil,

    --- 主键
    PRIMARY_KEY = { "id" },

    --- 自增索引键
    AUTOINCR_KEY = false,

    --- 缓存策略
    CACHE_RULES = {},

    --- 数据处理器实例
    dbHelper = nil,

    --- 缓存数据实例
    cacheData = nil,
}

--- 静态数据访问对象初始化
--
-- @return table 静态数据访问对象
function StaticDaoBase:init()
    if not self.TABLE_NAME then
        exception:raise("core.badConfig", { TABLE_NAME = self.TABLE_NAME })
    end

    self.dbHelper = mysql:getInstance(self.TABLE_NAME)

    if self.PRIMARY_KEY and #self.PRIMARY_KEY > 0 then
        self.CACHE_RULES[#self.CACHE_RULES + 1] = self.PRIMARY_KEY
    end

    return self
end

--- 解析并重整数据（子类实现，用于对特殊格式进行解析）
--
-- @param table entity 数据
function StaticDaoBase:parseEntity(entity) end

--- 自定义扩展缓存（子类实现，用于特殊的扩展缓存需求）
--
-- @param table entitys 数据序列
-- @param table cacheData 缓存数据
function StaticDaoBase:extendCache(entitys, cacheData) end

--- 生成缓存数据
function StaticDaoBase:createCacheData()
    local entitys = self.dbHelper:fetchRows()

    for _, entity in ipairs(entitys) do
        self:parseEntity(entity)
    end

    local cacheData = {}

    for _, rule in ipairs(self.CACHE_RULES) do
        local data = {}
        local len = #rule

        for _, entity in ipairs(entitys) do
            local temp = data

            for i, field in ipairs(rule) do
                local key = entity[field]

                if not key then
                    break
                end

                if i == len then
                    temp[key] = entity
                else
                    if not temp[key] then
                        temp[key] = {}
                    end

                    temp = temp[key]
                end
            end
        end

        cacheData[table.concat(rule, self.KEY_SEPARATOR)] = data
    end

    self:extendCache(entitys, cacheData)
    self.cacheData = cacheData
end

--- 获取缓存数据
--
-- @param table rule 缓存规则
-- @param mixed ... 查询参数(缓存规则对应的值序列)
-- @return table|nil 数据
function StaticDaoBase:getCacheData(rule, ...)
    if not self.cacheData then
        self:createCacheData()
    end

    local data = self.cacheData[table.concat(rule, self.KEY_SEPARATOR)]

    if not data then
        return nil
    end

    local params = { ... }
    local length = #params

    if length == 0 then
        return data
    end

    for i = 1, length do
        local key = params[i]

        if not key then
            return nil
        end

        data = data[key]

        if not data then
            return nil
        end

        if i == length then
            return data
        end
    end

    return nil
end

--- 按主键获取单条数据
--
-- @param mixed ... 主键属性表或主键属性值序列
-- @return table 数据
function StaticDaoBase:getOne(...)
    local _, where, params = self:getPrimaryInfo(...)
    local entity = self:getCacheData(self.PRIMARY_KEY, ...)

    if not entity then
        entity = self.dbHelper:fetchRow(where, params)
    end

    return entity
end

return util:inherit(StaticDaoBase, daoBase)