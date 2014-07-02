local util = loadMod("core.util")
local exception = loadMod("core.exception")
local mysql = loadMod("core.driver.mysql")
local redis = loadMod("core.driver.redis")
local daoBase = loadMod("core.base.dao")
local changeLogger = loadMod("core.changes")

local DyncDaoBase = {
    --- 数据库表名
    TABLE_NAME = nil,

    --- 主键
    PRIMARY_KEY = { "id" },

    --- 自增索引键
    AUTOINCR_KEY = nil,

    --- JSON类型键集合
    JSON_KEYSET = nil,

    --- 是否缓存
    CACHE_ENABLE = false,

    --- 缓存库索引
    CACHE_INDEX = 0,

    --- 缓存有效期(单位：秒，0 永不过期)
    CACHE_EXPIRE = 10800,

    --- 数据处理器实例
    dbHelper = nil,

    --- 缓存处理器实例
    cacheHelper = nil,

    --- 记录变化键名
    logChangeKey = nil,
}

--- 动态数据访问对象初始化
--
-- @return table 动态数据访问对象
function DyncDaoBase:init()
    if not self.TABLE_NAME then
        exception:raise("core.badConfig", { TABLE_NAME = self.TABLE_NAME })
    end

    self.dbHelper = mysql:getInstance(self.TABLE_NAME, self.JSON_KEYSET)

    if self.CACHE_ENABLE then
        self.cacheHelper = redis:getInstance(self.CACHE_INDEX)
    end

    return self
end

--- 按主键获取单条数据
--
-- @param mixed ... 主键属性表或主键属性值序列
-- @return table 数据
function DyncDaoBase:getOne(...)
    local cacheKey, where, params, entity = self:getPrimaryInfo(...)

    if self.CACHE_ENABLE then
        entity = self.cacheHelper:get(cacheKey)
    end

    if not entity then
        entity = self.dbHelper:fetchRow(where, params)

        if self.CACHE_ENABLE and entity then
            self.cacheHelper:set(cacheKey, entity, self.CACHE_EXPIRE)
        end
    end

    return entity
end

--- 插入数据
--
-- @param table entity 数据
-- @param table props 属性列表
-- @return table 数据
function DyncDaoBase:add(entity, props)
    local insertId = self.dbHelper:add(entity, props or util.table:keys(entity))

    if self.AUTOINCR_KEY then
        entity[self.AUTOINCR_KEY] = insertId
    end

    if self.logChangeKey then
        changeLogger:updateOne(self.logChangeKey, entity)
    end

    return entity
end

--- 插入数据
--
-- @param table entity 数据
-- @param table props 属性列表
-- @return table 数据
function DyncDaoBase:replace(entity, props)
    local insertId = self.dbHelper:add(entity, props or util.table:keys(entity), true)

    if self.AUTOINCR_KEY then
        entity[self.AUTOINCR_KEY] = insertId
    end

    if self.CACHE_ENABLE then
        self.cacheHelper:del((self:getPrimaryInfo(entity)))
    end

    if self.logChangeKey then
        changeLogger:updateOne(self.logChangeKey, entity)
    end

    return entity
end

--- 按主键删除数据
--
-- @param mixed ... 主键属性表或主键属性值序列
-- @return number 影响的行数
function DyncDaoBase:remove(...)
    local cacheKey, where, params = self:getPrimaryInfo(...)
    local result = self.dbHelper:remove(where, params) > 0

    if self.CACHE_ENABLE then
        self.cacheHelper:del(cacheKey)
    end

    if self.logChangeKey then
        changeLogger:remove(self.logChangeKey, { params })
    end

    return result
end

--- 删除指定ID序列的数据（仅当id为主键时适用）
--
-- @param table ids ID序列
-- @return number 删除数据数量
function DyncDaoBase:removeByIds(ids)
    local result = self.dbHelper:remove("`id` IN (" .. self:createFields(#ids) .. ")", ids)

    if self.CACHE_ENABLE then
        local keys = {}

        for _, id in ipairs(ids) do
            keys[#keys + 1] = self:getPrimaryCacheKey(id)
        end

        self.cacheHelper:dels(keys)
    end

    if self.logChangeKey then
        local entitys = {}

        for _, id in ipairs(ids) do
            entitys[#entitys + 1] = { id = id }
        end

        changeLogger:remove(self.logChangeKey, entitys)
    end

    return result
end

--- 更新数据
--
-- @param table entity 数据
-- @param table props 属性表(Array模式)
-- @param boolean flushCache 删除而不是更新缓存
-- @return number 影响的行数
function DyncDaoBase:update(entity, props, flushCache)
    if not props then
        return false
    end

    local cacheKey, where = self:getPrimaryInfo(entity)
    local result = self.dbHelper:update(props, entity, where) > 0

    if self.CACHE_ENABLE then
        if flushCache then
            self.cacheHelper:del(cacheKey)
        else
            self.cacheHelper:set(cacheKey, entity, self.CACHE_EXPIRE)
        end
    end

    if self.logChangeKey then
        changeLogger:updateOne(self.logChangeKey, entity, props)
    end

    return result
end

--- 清除缓存
function DyncDaoBase:clearCache()
    if self.CACHE_ENABLE then
        self.cacheHelper:flush()
    end
end

--- 清除所有数据
function DyncDaoBase:truncate()
    self.dbHelper:query("TRUNCATE TABLE  `" .. self.TABLE_NAME .. "`")
    self:clearCache()
end

return util:inherit(DyncDaoBase, daoBase)
