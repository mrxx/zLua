local Counter = {
    --- 统计类型：MySQL查询次数
    COUNTER_MYSQL = 0,

    --- 统计类型：Redis查询次数
    COUNTER_REDIS = 1,

    --- 统计类型：Memcached查询次数
    COUNTER_MEMCACHED = 2,
}

--- 获取计数器数据
--
-- @return table
local function getData()
    if not ngx.ctx[Counter] then
        ngx.ctx[Counter] = {}
    end

    return ngx.ctx[Counter]
end

--- 递增计数器数值
--
-- @param string name 计数器名称
-- @param number value 递增步长(省略则使用1)
function Counter:set(name, value)
    local data = getData()
    data[name] = (data[name] or 0) + (value or 1)
end

--- 获取计数器数值
--
-- @param string name 计数器名称
-- @return number 计数器数值
function Counter:get(name)
    return getData()[name] or 0
end

return Counter


