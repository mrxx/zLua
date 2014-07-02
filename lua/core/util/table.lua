local exception = loadMod("core.exception")

local function checkTable(t)
    if type(t) ~= "table" then
        exception:raise("core.badParams", { t = t })
    end
end

local Table = {}

--- 获取表的所有键
--
-- @param table t 源表
-- @return table 键名表
function Table:keys(t)
    checkTable(t)

    local keys = {}

    for k in pairs(t) do
        keys[#keys + 1] = k
    end

    return keys
end

--- 获取表的所有值
--
-- @param table t 源表
-- @return table 值表
function Table:values(t)
    checkTable(t)

    local values = {}

    for _, v in pairs(t) do
        values[#values + 1] = v
    end

    return values
end

--- 表中是否有指定值
--
-- @param table t 源表
-- @param mixed value 查找值
-- @param mixed cmpKey 比较键名
-- @return boolean 是否存在
function Table:hasValue(t, value, cmpKey)
    checkTable(t)

    for _, v in pairs(t) do
        if cmpKey then
            if v[cmpKey] == value then
                return true
            end
        else
            if v == value then
                return true
            end
        end
    end

    return false
end

--- 返回指定值在表中的键名
--
-- @param table t 源表
-- @param mixed value 查找值
-- @param mixed cmpKey 比较键名
-- @return mixed 键名
function Table:indexof(t, value, cmpKey)
    checkTable(t)

    for k, v in pairs(t) do
        if cmpKey then
            if v[cmpKey] == value then
                return k
            end
        else
            if v == value then
                return k
            end
        end
    end

    return nil
end

--- 获取表头部元素的键名和值
--
-- @param table t 源表
-- @return mixed 头部元素键名
-- @return mixed 头部元素值
function Table:head(t)
    checkTable(t)

    for k, v in pairs(t) do
        return k, v
    end

    return nil
end

--- 获取Array模式表尾部元素的键名和值
--
-- @param table t 源表
-- @return mixed 尾部元素键名
-- @return mixed 尾部元素值
function Table:tail(t)
    checkTable(t)

    local length = #t
    return length, t[length]
end

--- 判断表是否为空
--
-- @param table t 源表
-- @return boolean 是否为空
function Table:isEmpty(t)
    checkTable(t)

    if (self:head(t)) then
        return false
    else
        return true
    end
end

--- 获取表的长度
--
-- @param table t 源表
-- @return number 源表长度
function Table:length(t)
    checkTable(t)

    local length = 0

    for _ in pairs(t) do
        length = length + 1
    end

    return length
end

--- 根据上下界生成数值表
--
-- @param number min 下界
-- @param number max 上界
-- @return table 数值表
function Table:range(min, max)
    local t = {}

    for i = min, max do
        t[#t + 1] = i
    end

    return t
end

--- 扩展Array模式的表
--
-- @param table t 源表
-- @param mixed ... 扩展值
-- @return table 扩展后的表
function Table:extend(t, ...)
    checkTable(t)

    local length = #t

    for i = 1, select("#", ...) do
        t[length + i] = select(i, ...)
    end

    return t
end

--- 将表连接到Array模式源表尾部
--
-- @param table t 源表
-- @param table t1 待连接表
-- @return table 连接后的表
function Table:concat(t, t1)
    checkTable(t)
    checkTable(t1)

    local length = #t

    for i, v in ipairs(t1) do
        t[length + i] = v
    end

    return t
end

--- 将Array模式表用指定值填充到指定长度
--
-- @param table t 源表
-- @param number length 填充长度
-- @param mixed value 填充值
-- @return table 填充后的表
function Table:fill(t, length, value)
    checkTable(t)

    for i = 1, length do
        t[i] = value
    end

    return t
end

--- 获取表中符合检查函数的首个元素的键名和值
--
-- @param table t 源表
-- @param function func 检查函数
-- @return mixed 符合条件键名
-- @return mixed 符合条件值
function Table:find(t, func)
    checkTable(t)

    for k, v in pairs(t) do
        if func(v, k, t) then
            return k, v
        end
    end

    return nil
end

--- 获取表中符合检查函数的所有元素的值组成的新Array模式表
--
-- @param table t 源表
-- @param function func 检查函数
-- @return tablex 符合条件元素表
function Table:filter(t, func)
    checkTable(t)

    local result = {}

    for _, v in pairs(t) do
        if func(v, k, t) then
            result[#result + 1] = v
        end
    end

    return result
end

--- 用处理函数遍历表中元素
--
-- @param table t 源表
-- @param function func 处理函数
function Table:walk(t, func)
    checkTable(t)

    for k, v in pairs(t) do
        func(v, k, t)
    end
end

--- 用处理函数遍历表中元素并生成新表
--
-- @param table t 源表
-- @param function func 处理函数
-- @return table 新表
function Table:map(t, func)
    checkTable(t)

    local result = {}
    for k, v in pairs(t) do
        local nv, nk = func(v, k, t)

        if nk then
            result[nk] = nv
        else
            result[#result + 1] = nv
        end
    end

    return result
end

--- 将源表内容复制到目标表
--- * 指定键序列，则仅复制键序列的值
--
-- @param table srcT 源表
-- @param table desT 目标表
-- @param table keys 限制复制的键序列
-- @return table 复制源表后的目标表
function Table:copy(srcT, desT, keys)
    checkTable(srcT)
    desT = desT or {}
    checkTable(desT)

    if keys then
        for _, key in ipairs(keys) do
            desT[key] = srcT[key]
        end
    else
        for key, value in pairs(srcT) do
            desT[key] = value
        end
    end

    return desT
end

--- 获取源表从指定位置开始制定长度的切片
--
-- @param table t 源表
-- @param number start 起始索引
-- @param number length 切片长度
-- @return table 源表的切片
function Table:slice(t, start, length)
    checkTable(t)

    local result = {}

    if #t >= start then
        length = math.min(#t - start + 1, length)

        for i = 1, length do
            result[i] = t[start + i - 1]
        end
    end

    return result
end

--- 获取源表排重后的表
--
-- @param table t 源表
-- @return table 排重后的表
function Table:unique(t)
    checkTable(t)

    local result, set = {}, {}

    for _, value in ipairs(t) do
        if not set[value] then
            set[value] = true
            result[#result + 1] = value
        end
    end

    return result
end

--- 获取表中所有元素值的和
--- * 指定求和键名，则使用元素指定键名的值求和
--
-- @param table t 源表
-- @param mixed key 求和键名
-- @return number 和
function Table:sum(t, key)
    checkTable(t)

    local sum = 0

    for _, v in pairs(t) do
        sum = sum + ((key and v[key] or v) or 0)
    end

    return sum
end

--- 获取表中最大元素的键名和值
--- * 指定比较键名，则使用元素指定键名的值比较
--
-- @param table t 源表
-- @param mixed key 比较键名
-- @return mixed 最大元素键名
-- @return mixed 最大值
function Table:max(t, key)
    checkTable(t)

    local maxKey, maxValue

    for k, v in pairs(t) do
        local value = key and v[key] or v

        if not maxValue or value > maxValue then
            maxKey, maxValue = k, value
        end
    end

    return maxKey, maxValue
end

--- 获取表中最小元素的键名和值
--- * 指定比较键名，则使用元素指定键名的值比较
--
-- @param table t 源表
-- @param mixed key 比较键名
-- @return mixed 最小元素键名
-- @return mixed 最小值
function Table:min(t, key)
    checkTable(t)

    local minKey, minValue


    for k, v in pairs(t) do
        local value = key and v[key] or v

        if not minValue or value < minValue then
            minKey, minValue = k, value
        end
    end

    return minKey, minValue
end

--- 获取Array模式表中的随机元素的值
--
-- @param table t 源表
-- @return mixed 随机元素值
function Table:random(t)
    checkTable(t)

    return #t > 0 and t[math.random(1, #t)] or nil
end

--- 获取Array模式表中的指定数量随机元素的新表
--
-- @param table t 源表
-- @param number num 随机元素数量
-- @return table 随机元素新表
function Table:randoms(t, num)
    checkTable(t)

    local keys = self:keys(t)
    local num = math.min(num, #keys)
    local selects = {}

    for _ = 1, num do
        local index = math.random(1, #keys)
        selects[#selects + 1] = t[keys[index]]
        table.remove(keys, index)
    end

    return selects
end

--- 按权重从权重表中随机获取一个元素的值
--- * 元素需含有数字类型的weight属性
--- * 指定返回值键名，则返回元素指定键名的值
--- * 指定权重随机范围，则按指定范围随机，否则使用权重表总权重随机
--
-- @param table t 权重表
-- @param mixed key 返回值键名
-- @param number range 权重随机范围
-- @return mixed 随机元素的值
function Table:weightRandom(t, key, range)
    checkTable(t)

    local totalWeight = self:sum(t, "weight")
    local randValue = math.random(1, range or totalWeight)

    if randValue <= totalWeight then
        local limitValue = 0

        for _, v in pairs(t) do
            limitValue = limitValue + v.weight

            if randValue <= limitValue then
                return key and v[key] or v
            end
        end
    end

    return nil
end

--- 比较两个表是否相同
--
-- @param table t1 源表
-- @param table t2 目标表
-- @return boolean 是否相同
function Table:isSame(t1, t2)
    checkTable(t1)
    checkTable(t2)

    if #t1 ~= #t2 then
        return false
    end

    for k, v in pairs(t1) do
        if v ~= t2[k] then
            return false
        end
    end

    return true
end

--- 比较两个表
--- * 表2相对于表1的差别
--
-- @param table t1 表1
-- @param table t2 表2
-- @return table 公共的元素集合
-- @return table 移除的元素集合
-- @return table 新增的元素集合
function Table:diff(t1, t2)
    checkTable(t1)
    checkTable(t2)

    local key, commons, removes, adds = 1, {}, self:values(t1), self:values(t2)

    while key <= #removes do
        local value = removes[key]
        local index = self:indexof(adds, value)

        if index then
            commons[#commons + 1] = value
            table.remove(adds, index)
            table.remove(removes, key)
        else
            key = key + 1
        end
    end

    return commons, removes, adds
end

--- 对表进行序列化
--
-- @param mixed t 表
-- @param string prefix 定义前缀
-- @param string indentStr 缩进字符
-- @param number indentLevel 缩进级别
-- @param table marks 已标记列表
-- @param table quotes 引用列表
-- @return string 定义字符串
-- @return table 引用列表
function Table:serialize(t, prefix, indentStr, indentLevel, marks, quotes)
    checkTable(t)

    marks = marks or {}
    quotes = quotes or {}
    marks[t] = prefix

    local items = {}
    local equal, brace, backbrace, comma = "=", "{", "}", ","

    if indentStr then
        local space = indentStr:rep(indentLevel)
        local preSpace = indentLevel > 1 and indentStr:rep(indentLevel - 1) or ""

        equal, brace, backbrace, comma = " = ", "{\n" .. space, "\n" .. preSpace .. "}", ",\n" .. space
    end

    for key, value in pairs(t) do
        local kType = type(key)
        local name

        if kType == "string" then
            name = "[" .. string.format("%q", key) .. "]"
        elseif kType == "number" or kType == "boolean" then
            name = "[" .. tostring(key) .. "]"
        end

        if name then
            local prefix = prefix .. name
            local vType = type(value)

            if vType == "table" then
                if marks[value] then
                    quotes[#quotes + 1] = prefix .. equal .. marks[value]
                else
                    items[#items + 1] = name .. equal .. (self:serialize(value, prefix, indentStr, indentLevel + 1, marks, quotes))
                end
            elseif vType == "string" then
                items[#items + 1] = name .. equal .. string.format('%q', value)
            elseif vType == "number" or vType == "boolean" then
                items[#items + 1] = name .. equal .. tostring(value)
            end
        end
    end

    return brace .. table.concat(items, comma) .. backbrace, quotes
end

--- 获取表数据的定义字符串
--
-- @param table t 表
-- @param string name 定义名称
-- @param string indentStr 缩进字符
-- @param number indentLevel 缩进级别
-- @param boolean notLocal 非局部定义
-- @return string 定义字符串
function Table:getDefine(t, name, indentStr, indentLevel, notLocal)
    checkTable(t)

    name = name or "data"
    indentLevel = indentLevel or 0

    local str, quotes = self:serialize(t, name, indentStr, indentLevel + 1)

    if not notLocal then
        name = "local " .. name
    end

    if indentStr then
        local space = string.rep(indentStr, indentLevel)
        return space .. name .. " = " .. str .. "\n" .. space .. table.concat(quotes, "\n" .. space)
    else
        return name .. "=" .. str .. "\n" .. table.concat(quotes, "\n")
    end
end

--- 将表转化为可打印的字符串
--
-- @param table t 表
-- @param string indentStr 缩进字符
-- @param number indentLevel 缩进级别
-- @param table marks 已标记列表
-- @return string 可打印的字符串
function Table:toString(t, indentStr, indentLevel, marks)
    checkTable(t)

    indentStr = indentStr or "\t"
    indentLevel = indentLevel or 1
    marks = marks or {}

    local items = {}
    local tName = "<" .. tostring(t) .. ">"

    marks[t] = tName

    local space = indentStr:rep(indentLevel)
    local preSpace = indentLevel > 1 and indentStr:rep(indentLevel - 1) or ""

    for key, value in pairs(t) do
        local kType = type(key)
        local name

        if kType == "string" then
            name = string.format("%q", key)
        elseif kType == "number" or kType == "boolean" then
            name = tostring(key)
        else
            name = "<" .. tostring(key) .. ">"
        end

        local vType = type(value)

        if vType == "string" then
            items[#items + 1] = name .. " = " .. string.format('%q', value)
        elseif vType == "number" or vType == "boolean" then
            items[#items + 1] = name .. " = " .. tostring(value)
        elseif vType == "table" then
            if marks[value] then
                items[#items + 1] = name .. " = " .. marks[value]
            else
                items[#items + 1] = name .. " = " .. self:toString(value, indentStr, indentLevel + 1, marks)
            end
        else
            items[#items + 1] = name .. " = " .. "<" .. tostring(value) .. ">"
        end
    end

    return tName .. ":{\n" .. space .. table.concat(items, ",\n" .. space) .. "\n" .. preSpace .. "}"
end

return Table
