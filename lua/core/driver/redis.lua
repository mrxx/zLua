local json = require("cjson")
local redis = require("resty.redis")
local util = loadMod("core.util")
local exception = loadMod("core.exception")
local counter = loadMod("core.counter")
local dbConf = loadMod("config.redis")

local Redis = {}

--- 初始化连接
--
-- @return resty.redis Redis连接
local function initClient()
    -- 新建连接
    local client = exception:assert("core.connectFailed", {}, redis:new())

    -- 设置超时
    client:set_timeout(dbConf.TIMEOUT)

    -- 连接服务器
    if dbConf.SOCK then
        exception:assert("core.connectFailed", {}, client:connect("unix:" .. dbConf.SOCK))
    else
        exception:assert("core.connectFailed", {}, client:connect(dbConf.HOST, dbConf.PORT))
    end

    ngx.ctx[Redis] = client
    return ngx.ctx[Redis]
end

--- 获取连接
--
-- @return resty.redis Redis连接
local function getClient()
    return ngx.ctx[Redis] or initClient()
end

--- 关闭连接
local function closeClient()
    if ngx.ctx[Redis] then
        ngx.ctx[Redis]:set_keepalive(dbConf.TIMEOUT, dbConf.POOL_SIZE)
        ngx.ctx[Redis] = nil
    end
end

--- 转化null为nil
--
-- @param mixed value
-- @return mixed
local function nul2nil(value)
    if value == ngx.null then
        return nil
    end

    return value
end

--- 将任意值编码为格式字符串
--
-- @param mixed value
-- @return string
local function encode(value)
    if util:isNumber(value) then
        return value
    else
        return "*" .. json.encode(value)
    end
end

--- 将格式字符串解码为值
--
-- @param string value
-- @return mixed
local function decode(value)
    if nul2nil(value) == nil then
        return nil
    end

    local flag = value:sub(1, 1)

    if flag == "*" then
        return json.decode(value:sub(2))
    end

    return value
end

--- 执行命令
--
-- @param string cmd 命令
-- @param mixed ... 命令参数
-- @return mixed 命令结果
function Redis:execute(cmd, ...)
    local client = getClient()

    if cmd == "select" or not client[cmd] then
        exception:raise("core.badCall", { cmd = cmd, args = { ... } })
    end

    counter:set(counter.COUNTER_REDIS)

    client:init_pipeline()
    client:select(self.dbIndex)
    client[cmd](client, ...)

    local results, errmsg = client:commit_pipeline()

    if not results or not util:isTable(results) or #results ~= 2 then
        exception:raise("core.queryFailed", { args = { ... }, message = errmsg })
    end

    local selectRet, cmdRet = unpack(results)

    if not selectRet or (util:isTable(selectRet) and not selectRet[1]) then
        exception:raise("core.queryFailed", { cmd = "select", args = { self.dbIndex }, message = selectRet[2] })
    end

    if not cmdRet then
        exception:raise("core.queryFailed", { cmd = cmd, args = { ... }, message = cmdRet[2] })
    end

    return cmdRet
end

--- 获取符合匹配模式的键名序列
--
-- @param string pattern 匹配模式
-- @return table 键名序列(Array模式)
function Redis:keys(pattern)
    return self:execute("keys", pattern)
end

--- 获取键名的值
--
-- @param string key 键名
-- @return mixed 值
function Redis:get(key)
    return decode(self:execute("get", key))
end

--- 获取键名序列的键值表
--
-- @param table keys 键名序列(Array模式)
-- @param boolean retRaw 值模式，为True时返回值序列(Array模式)，否则返回键值表(Hash模式)
-- @return table 值序列(Array模式)或键值表(Hash模式)
function Redis:gets(keys, retRaw)
    local values = self:execute("mget", unpack(keys))
    local result = {}

    for index, value in ipairs(values) do
        if retRaw then
            result[index] = decode(value)
        else
            result[keys[index]] = decode(value)
        end
    end

    return result
end

--- 新增键名的值（键名已存在则失败）
--
-- @param string key 键名
-- @param mixed value 值
-- @param number expiration 有效期(不设置或为0则永不过期)
-- @return boolean 是否成功
function Redis:add(key, value, expiration)
    value = encode(value)
    expiration = util:numval(expiration, true)

    if expiration > 0 then
        return self:execute("set", key, value, "NX", "EX", expiration) and true or false
    else
        return self:execute("set", key, value, "NX") and true or false
    end
end

--- 设置键名的值
--
-- @param string key 键名
-- @param mixed value 值
-- @param number expiration 有效期(不设置或为0则永不过期)
-- @return boolean 是否成功
function Redis:set(key, value, expiration)
    value = encode(value)
    expiration = util:numval(expiration, true)

    if expiration > 0 then
        return self:execute("set", key, value, "EX", expiration) and true or false
    else
        return self:execute("set", key, value) and true or false
    end
end

--- 设置键值表
--
-- @param table items 键值表(Hash模式)
-- @return boolean 是否成功
function Redis:sets(items)
    local args = {}

    for key, value in pairs(items) do
        local length = #args

        args[length + 1] = key
        args[length + 2] = encode(value)
    end

    return self:execute("mset", unpack(args)) and true or false
end

--- 设置键名的值并获取原值
--
-- @param string key 键名
-- @param mixed value 值
-- @return mixed 原值
function Redis:getSet(key, value)
    return decode(self:execute("getset", key, encode(value)))
end

--- 获取键名的值按步长增长后的值
--
-- @param string key 键名
-- @param number step 步长
-- @return number 增长后的值
function Redis:increase(key, step)
    return tonumber(self:execute("incrby", key, step)) or 0
end

--- 删除键名
--
-- @param string key 键名
-- @return boolean 是否成功
function Redis:del(key)
    return self:execute("del", key) == 1
end

--- 删除键名序列
--
-- @param table keys 键名序列(Array模式)
-- @return number 删除数量
function Redis:dels(keys)
    return self:execute("del", unpack(keys))
end

--- 键名是否存在
--
-- @param string key 键名
-- @return boolean 是否存在
function Redis:exists(key)
    return self:execute("exists", key) == 1
end

--- 设置键名的过期时间
--
-- @param string key 键名
-- @param number timestamp 过期的时间戳
-- @return boolean 是否成功
function Redis:expire(key, timestamp)
    return self:execute("expireat", key, timestamp) == 1
end

--- 设置哈希的属性的值
--
-- @param string key 键名
-- @param string prop 属性名
-- @param mixed value 属性值
-- @return boolean 是否成功
function Redis:hashSet(key, prop, value)
    return self:execute("hset", key, prop, encode(value)) == 1
end

--- 设置哈希的属性表
--
-- @param string key 键名
-- @param table items 属性表(Hash模式)
-- @return boolean 是否成功
function Redis:hashSets(key, items)
    local oItems = util.table:map(items, function(value, index)
        return encode(value), index
    end)

    return self:execute("hmset", key, oItems) and true or false
end

--- 获取哈希的属性的值
--
-- @param string key 键名
-- @param string prop 属性名
-- @return mixed 属性值
function Redis:hashGet(key, prop)
    return decode(self:execute("hget", key, prop))
end

--- 获取哈希的属性序列的属性表
--
-- @param string key 键名
-- @param table props 属性序列(Array模式)
-- @return table 属性表(Hash模式)
function Redis:hashGets(key, props)
    local values = self:execute("hmget", key, unpack(props))
    local result = {}

    for index, value in ipairs(values) do
        result[props[index]] = decode(value)
    end

    return result
end

--- 删除哈希的属性
--
-- @param string key 键名
-- @param string prop 属性名
-- @return boolean 是否成功
function Redis:hashDel(key, prop)
    return self:execute("hdel", key, prop) == 1
end

--- 删除哈希的属性序列
--
-- @param string key 键名
-- @param table props 属性序列(Array模式)
-- @return number 删除数量
function Redis:hashDels(key, props)
    return self:execute("hdel", key, unpack(props))
end

--- 获取哈希的属性数量
--
-- @param string key 键名
-- @return number 长度
function Redis:hashLen(key)
    return self:execute("hlen", key)
end

--- 获取哈希的属性名序列
--
-- @param string key 键名
-- @return table 属性序列(Array模式)
function Redis:hashProps(key)
    return self:execute("hkeys", key)
end

--- 获取哈希的属性值序列
--
-- @param string key 键名
-- @return table 属性值序列(Array模式)
function Redis:hashVals(key)
    local values = self:execute("hvals", key)
    local result = {}

    for index, value in ipairs(values) do
        result[index] = decode(value)
    end

    return result
end

--- 获取哈希的全部属性表
--
-- @param string key 键名
-- @return table 属性表(Hash模式)
function Redis:hashGetAll(key)
    local values = self:execute("hgetall", key)
    local result = {}

    for i = 1, #values, 2 do
        result[values[i]] = decode(values[i + 1])
    end

    return result
end

--- 设置(更新)排序集合的成员分数
--
-- @param string key 键名
-- @param string member 成员名
-- @param number score 分数
-- @return boolean 是否为新增(false表示更新)
function Redis:zsetAdd(key, member, score)
    return self:execute("zadd", key, score, member) == 1
end

--- 增加排序集合的成员分数
--
-- @param string key 键名
-- @param string member 成员名
-- @param number score 分数
-- @return number 增加后的分数
function Redis:zsetIncr(key, member, score)
    return tonumber(self:execute("zincrby", key, score, member))
end

--- 删除排序集合的成员
--
-- @param string key 键名
-- @param string member 成员名
-- @return boolean 是否成功
function Redis:zsetDel(key, member)
    return self:execute("zrem", key, member) == 1
end

--- 删除排序集合的成员序列
--
-- @param string key 键名
-- @param table members 成员名序列(Array模式)
-- @return number 删除数量
function Redis:zsetDels(key, members)
    return self:execute("zrem", key, unpack(members))
end

--- 获取排序集合的成员数量
--
-- @param string key 键名
-- @return number 成员数量
function Redis:zsetLen(key)
    return self:execute("zcard", key)
end

--- 获取排序集合按分数排序的片段
--
-- @param string key 键名
-- @param number minRank 开始名次
-- @param number maxRank 结束名次
-- @param boolean desc 是否降序排列(省略时使用升序)
-- @return table 成员名序列(Array模式)
function Redis:zsetRange(key, minRank, maxRank, desc)
    return self:execute(desc and "zrevrange" or "zrange", key, minRank, maxRank)
end

--- 获取排序集合按分数排序的片段
--
-- @param string key 键名
-- @param number minScore 开始分数
-- @param number maxScore 结束分数
-- @param boolean desc 是否降序排列(省略时使用升序)
-- @return table 成员名序列(Array模式)
function Redis:zsetScoreRange(key, minScore, maxScore, desc)
    if desc then
        return self:execute("zrevrangebyscore", key, maxScore, minScore)
    else
        return self:execute("zrangebyscore", key, minScore, maxScore)
    end
end

--- 获取排序集合的成员分数
--
-- @param string key 键名
-- @param string member 成员名
-- @return number 分数
function Redis:zsetScore(key, member)
    return tonumber(self:execute("zscore", key, member))
end

--- 获取排序集合的成员排名
--
-- @param string key 键名
-- @param string member 成员名
-- @param boolean desc 是否降序排列(省略时使用升序)
-- @return number 名次
function Redis:zsetRank(key, member, desc)
    return nul2nil(self:execute(desc and "zrevrank" or "zrank", key, member))
end

--- 将成员加入集合
--
-- @param string key 键名
-- @param string member 成员名
-- @return boolean 是否成功
function Redis:setAdd(key, member)
    return self:execute("sadd", key, member) == 1
end

--- 删除集合的成员
--
-- @param string key 键名
-- @param string member 成员名
-- @return boolean 是否成功
function Redis:setDel(key, member)
    return self:execute("srem", key, member) == 1
end

--- 删除集合的成员序列
--
-- @param string key 键名
-- @param table members 成员名序列(Array模式)
-- @return number 删除数量
function Redis:setDels(key, members)
    return self:execute("srem", key, unpack(members))
end

--- 获取集合的成员数量
--
-- @param string key 键名
-- @return number 成员数量
function Redis:setLen(key)
    return self:execute("scard", key)
end

--- 随机弹出集合的某个成员
--
-- @param string key 键名
-- @return string 成员名
function Redis:setPop(key)
    return nul2nil(self:execute("spop", key))
end

--- 随机获取集合指定数量的成员序列
--
-- @param string key 键名
-- @param number num 成员数量
-- @return table 成员名序列(Array模式)
function Redis:setRand(key, num)
    return self:execute("srandmember", key, num or 1)
end

--- 获取集合的全部成员序列
--
-- @param string key 键名
-- @return table 成员名序列(Array模式)
function Redis:setMembers(key)
    return self:execute("smembers", key)
end

--- 成员是否在集合内
--
-- @param string key 键名
-- @param string member 成员名
-- @return boolean 是否属于
function Redis:setIsMember(key, member)
    return self:execute("sismember", key, member) == 1
end

--- 将值压入列表头部
--
-- @param string key 键名
-- @param mixed value 值
-- @return number 列表长度
function Redis:listShift(key, value)
    return self:execute("lpush", key, encode(value))
end

--- 将值压入列表尾部
--
-- @param string key 键名
-- @param mixed value 值
-- @return number 列表长度
function Redis:listPush(key, value)
    return self:execute("rpush", key, encode(value))
end

--- 设置列表指定位置的值
--
-- @param string key 键名
-- @param number index 索引
-- @param mixed value 值
-- @return boolean 是否成功
function Redis:listSet(key, index, value)
    return self:execute("lset", key, index, encode(value)) and true or false
end

--- 弹出列表头部的值
--
-- @param string key 键名
-- @return mixed 值
function Redis:listUnshift(key)
    return decode(self:execute("lpop", key))
end

--- 弹出列表尾部的值
--
-- @param string key 键名
-- @return mixed 值
function Redis:listPop(key)
    return decode(self:execute("rpop", key))
end

--- 获取列表指定位置的值
--
-- @param string key 键名
-- @param number index 索引
-- @return mixed 值
function Redis:listGet(key, index)
    return decode(self:execute("lindex", key, index))
end

--- 获取列表长度
--
-- @param string key 键名
-- @return number 列表长度
function Redis:listLen(key)
    return self:execute("llen", key)
end

--- 截取并保存列表
--
-- @param string key 键名
-- @param number start 开始索引
-- @param number stop 结束索引
-- @return boolean 是否成功
function Redis:listTrim(key, start, stop)
    return self:execute("ltrim", key, start, stop) and true or false
end

--- 获取列表片段
--
-- @param string key 键名
-- @param number start 开始索引
-- @param number stop 结束索引
-- @return table 值序列(Array模式)
function Redis:listRange(key, start, stop)
    local values = self:execute("lrange", key, start, stop)
    local result = {}

    for index, value in ipairs(values) do
        result[index] = decode(value)
    end

    return result
end

--- 移除列表内指定数值
--
-- @param string key 键名
-- @param string data 删除数值
-- @param number counter 移除数量
function Redis:listRemove(key, data, counter)
    counter = counter or 1
    return self:execute("lrem", key, counter, encode(data))
end

--- 清空当前数据库
--
-- @return boolean 是否成功
function Redis:flush()
    return self:execute("flushdb") and true or false
end

--- 清空所有数据库
--
-- @return boolean 是否成功
function Redis:flushAll()
    return self:execute("flushall") and true or false
end

--- 获取统计信息
--
-- @return table 统计信息
function Redis:stat()
    local info = self:execute("info")
    local result = {}

    for key, value in info:gmatch("([%w_]+):([^\r\n]+)") do
        result[key] = value
    end

    return result
end

local Module = { instances = {} }

--- 获取查询对象实例
--
-- @param number dbIndex 数据库索引
-- @return table 查询对象
function Module:getInstance(dbIndex)
    if not self.instances[dbIndex] then
        self.instances[dbIndex] = util:inherit({ dbIndex = dbIndex }, Redis)
    end

    return self.instances[dbIndex]
end

--- 关闭连接
function Module:close()
    closeClient()
end

return Module