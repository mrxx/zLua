local mysql = require("resty.mysql")
local util = loadMod("core.util")
local exception = loadMod("core.exception")
local counter = loadMod("core.counter")
local dbConf = loadMod("config.mysql")
local sysConf = loadMod("config.system")

local MySQL = {}

--- 初始化连接
--
-- @return resty.mysql MySQL连接
local function initClient()
    local client = exception:assert("core.connectFailed", {}, mysql:new())
    client:set_timeout(dbConf.TIMEOUT)

    local options = {
        user = dbConf.USER,
        password = dbConf.PASSWORD,
        database = dbConf.DATABASE
    }

    if dbConf.SOCK then
        options.path = dbConf.SOCK
    else
        options.host = dbConf.HOST
        options.port = dbConf.PORT
    end

    local result, errmsg, errno, sqlstate = client:connect(options)

    if not result then
        exception:raise("core.connectFailed", {
            message = errmsg,
            code = errno,
            state = sqlstate
        })
    end

    local query = "SET NAMES " .. sysConf.DEFAULT_CHARSET
    local result, errmsg, errno, sqlstate = client:query(query)

    if not result then
        exception:raise("core.queryFailed", {
            query = query,
            message = errmsg,
            code = errno,
            state = sqlstate
        })
    end

    ngx.ctx[MySQL] = client
    return ngx.ctx[MySQL]
end

--- 获取连接
--
-- @return resty.mysql MySQL连接
local function getClient()
    return ngx.ctx[MySQL] or initClient()
end

--- 关闭连接
local function closeClient()
    if ngx.ctx[MySQL] then
        ngx.ctx[MySQL]:set_keepalive(dbConf.TIMEOUT, dbConf.POOL_SIZE)
        ngx.ctx[MySQL] = nil
    end
end

--- 获取字段和值的Set模式字符串(value被转化为字符串)
--
-- @param string field 字段
-- @param mixed value 值
-- @return string 模式字符串
local function setFields(field, value)
    return "`" .. field .. "`" .. "=" .. util:strval(value, true)
end

--- 获取字段和值的Increase模式字符串(value被转化为数字)
--
-- @param string field 字段
-- @param mixed value 值
-- @return string 模式字符串
local function incrFields(field, value)
    return "`" .. field .. "`" .. "=`" .. field .. "`+" .. (tonumber(value) or 0)
end

--- 执行查询
--
-- 有结果数据集时返回结果数据集
-- 无数据数据集时返回查询影响，如：
-- { insert_id = 0, server_status = 2, warning_count = 1, affected_rows = 32, message = nil}
--
-- @param string query 查询语句
-- @return table 查询结果
function MySQL:query(query)
    counter:set(counter.COUNTER_MYSQL)

    local result, errmsg, errno, sqlstate = getClient():query(query, self.jsonColSet)

    if not result then
        exception:raise("core.queryFailed", {
            query = query,
            message = errmsg,
            code = errno,
            state = sqlstate
        })
    end

    return result
end

--- 插入数据
--
-- @param table entity 数据
-- @param table fields 字段表(Array模式)
-- @param boolean replace 是否为替换模式
-- @return number 自增索引值
function MySQL:add(entity, fields, replace)
    local values = {}

    for _, field in ipairs(fields) do
        values[#values + 1] = util:strval(entity[field], true)
    end

    local templet = (replace and "REPLACE" or "INSERT") .. " INTO `%s` (`%s`) VALUES (%s)"
    local query = templet:format(self.tableName, table.concat(fields, "`,`"), table.concat(values, ","))

    return self:query(query).insert_id
end

--- 插入数据序列
--
-- @param table entities 数据序列(Array模式)
-- @param table fields 字段表(Array模式)
-- @param boolean replace 是否为替换模式
-- @return number 影响的行数
function MySQL:addMulti(entities, fields, replace)
    local items = {}

    for _, entity in pairs(entities) do
        local values = {}

        for _, field in ipairs(fields) do
            values[#values + 1] = util:strval(entity[field], true)
        end

        items[#items + 1] = table.concat(values, ",")
    end

    local templet = (replace and "REPLACE" or "INSERT") .. " INTO `%s` (`%s`) VALUES (%s)"
    local query = templet:format(self.tableName, table.concat(fields, "`,`"), table.concat(items, "),("))

    return self:query(query).affected_rows
end

--- 替换模式插入数据
--
-- @param table entity 数据
-- @param table fields 字段表(Array模式)
-- @return number 自增索引值
function MySQL:replace(entity, fields)
    return self:add(entity, fields, true)
end

--- 更新数据
--
-- @param table fields 字段表(Array模式)
-- @param table params 参数表(Hash模式)
-- @param string where 更新条件
-- @param boolean increase 是否为增加模式
-- @return number 影响的行数
function MySQL:update(fields, params, where, increase)
    local items = {}

    for _, field in ipairs(fields) do
        local filter = increase and incrFields or setFields
        items[#items + 1] = filter(field, params[field])
    end

    local templet = "UPDATE `%s` SET %s WHERE %s"
    local query = templet:format(self.tableName, table.concat(items, ","), util:format(where, params, true))

    return self:query(query).affected_rows
end

--- 获取多行数据
--
-- @param string where 查询条件
-- @param table params 参数表(Hash或Array模式)
-- @param table fields 字段表(Array模式)
-- @return table 结果集(Array模式)
function MySQL:fetchRows(where, params, fields)
    where = where or "1"
    params = params or nil
    fields = fields or "*"

    if util:isTable(fields) then
        fields = "`" .. table.concat(fields, "`,`") .. "`"
    end

    local templet = "SELECT %s FROM `%s` WHERE %s"
    local query = templet:format(fields, self.tableName, util:format(where, params, true))

    return self:query(query)
end

--- 获取哈希模式多行数据
--
-- @param string where 查询条件
-- @param table params 参数表(Hash或Array模式)
-- @param table fields 字段表(Array模式)
-- @param string key 索引键名
-- @return table 结果集(Array模式)
function MySQL:fetchHashRows(where, params, fields, key)
    return util.table:A2H(self:fetchRows(where, params, fields), key or "id")
end

--- 获取首行首个数值
--
-- @param string where 查询条件
-- @param table params 参数表(Hash或Array模式)
-- @param table fields 字段表(Array模式)
-- @return string|number 结果值
function MySQL:fetchValue(where, params, fields)
    local row = self:fetchRows(where .. "  LIMIT 1", params, fields)[1]

    if row then
        for _, val in pairs(row) do
            return val
        end
    end

    return nil
end

--- 获取首列数据
--
-- @param string where 查询条件
-- @param table params 参数表(Hash或Array模式)
-- @param table fields 字段表(Array模式)
-- @return table 结果列(Array模式)
function MySQL:fetchCol(where, params, fields)
    local rows = self:fetchRows(where, params, fields)
    local col = {}

    for _, row in ipairs(rows) do
        for _, val in pairs(row) do
            col[#col + 1] = val
            break
        end
    end

    return col
end

--- 获取首行数据
--
-- @param string where 查询条件
-- @param table params 参数表(Hash或Array模式)
-- @param table fields 字段表(Array模式)
-- @return table 结果行(Hash模式)
function MySQL:fetchRow(where, params, fields)
    where = where or "1"
    params = params or nil

    return self:fetchRows(where .. "  LIMIT 1", params, fields)[1]
end

--- 删除数据
--
-- @param string where 查询条件
-- @param table params 参数表(Hash或Array模式)
-- @return number 影响的行数
function MySQL:remove(where, params)
    where = where or "1"
    params = params or nil

    local templet = "DELETE FROM `%s` WHERE %s"
    local query = templet:format(self.tableName, util:format(where, params, true))

    return self:query(query).affected_rows
end

local Module = { instances = {} }

--- 获取查询对象实例
--
-- @param string tableName 数据表名
-- @param table jsonColSet JSON类型列集合（{col1:true,col2:true,...}）
-- @return table 查询对象
function Module:getInstance(tableName, jsonColSet)
    if not self.instances[tableName] then
        self.instances[tableName] = util:inherit({ tableName = tableName, jsonColSet = jsonColSet }, MySQL)
    end

    return self.instances[tableName]
end

--- 关闭连接
function Module:close()
    closeClient()
end

return Module

