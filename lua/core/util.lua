local json = require("cjson")
local bit = require("bit")
local exception = loadMod("core.exception")
local serviceBase = loadMod("core.base.service")

local Util = {
    table = loadMod("core.util.table"),
    string = loadMod("core.util.string"),
}

--- 值是否为表
--
-- @param mixed value 值
-- @return boolean 是否为表
function Util:isTable(value)
    return type(value) == "table"
end

--- 值是否为字符串
--
-- @param mixed value 值
-- @return boolean 是否为字符串
function Util:isString(value)
    return type(value) == "string"
end

--- 值是否为数字
--
-- @param mixed value 值
-- @return boolean 是否为数字
function Util:isNumber(value)
    return type(value) == "number"
end

--- 值是否为布尔值
--
-- @param mixed value 值
-- @return boolean 是否为布尔值
function Util:isBoolean(value)
    return type(value) == "boolean"
end

--- 数值是否包含位值
--
-- @param number value 数值
-- @param number flag 位值
-- @return boolean 是否包含
function Util:hasBit(value, flag)
    return bit.band(value, flag) == flag
end

--- 数值添加位值
--
-- @param number value 数值
-- @param number flag 位值
-- @return number 添加后的数值
function Util:addBit(value, flag)
    return bit.bor(value, flag)
end

--- 数值移除位值
--
-- @param number value 数值
-- @param number flag 位值
-- @return number 移除后的数值
function Util:removeBit(value, flag)
    return bit.bxor(value, bit.band(value, flag))
end

--- 转化任意类型的值为字符串
--
-- @param mixed value 任意类型的值
-- @param boolean forSql 是否需要SQL转义(转义关键字符并在两端加单引号)
-- @return string 转化后的字符串
function Util:strval(value, forSql)
    local str = ""

    if value then
        str = self:isTable(value) and json.encode(value) or tostring(value)
    end

    if forSql then
        return ngx.quote_sql_str(str)
    end

    return str
end

--- 转化任意类型的值为数字
--
-- @param mixed value 任意类型的值
-- @param boolean abs 是否取绝对值
-- @return number 转化后的数字
function Util:numval(value, abs)
    local num = 0

    if value then
        num = tonumber(value) or 0
    end

    if num ~= 0 and abs then
        num = math.abs(num)
    end

    return num
end

--- 对数字四舍五入
--
-- @param number num 数字
-- @return number 四舍五入后的数字
function Util:round(num)
    return math.floor(num + 0.5)
end

--- 获取数字在限制内的值
--
-- @param number num 数字
-- @param number min 下限
-- @param number max 上限
-- @return number 限制内的数值
function Util:between(num, min, max)
    return math.max(min, math.min(max, num))
end

--- 返回用参数替代格式字符串中占位符后的字符串
--
-- @param string format 格式字符串(占位符为{n}或{key})
-- @param table params 参数表(Hash或Array模式)
-- @param boolean forSql 是否需要SQL转义(转义关键字符并在两端加单引号)
-- @return string 格式化后的字符串
function Util:format(format, params, forSql)
    if not self:isTable(params) then
        return format
    end

    return (format:gsub("{(%w+)}", function(key)
        if key:match("^%d+$") then
            key = tonumber(key)
        end

        return self:strval(params[key], forSql)
    end))
end

--- 获取当前时间
--
-- @param boolean isDate 是否返回日期格式
-- @return string|number 日期(yyyy-mm-dd hh:mm:ss)或时间戳(integer)
function Util:now(isDate)
    return isDate and ngx.localtime() or ngx.time()
end

--- 解析时间日期格式为时间戳
--
-- @param string datetime 日期时间(yyyy-mm-dd hh:mm:ss)
-- @return number 时间戳
function Util:parseDTime(datetime)
    local year, month, day, hour, min, sec = string.match(datetime, "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    return os.time({ sec = sec, min = min, hour = hour, day = day, month = month, year = year })
end

--- 获得时区偏移秒数
--
-- @return number
function Util:getTimeOffset()
    local diffTime = tonumber(os.date("%z"))
    return math.floor(diffTime / 100) * 3600 + (diffTime % 100) * 60
end

--- IP是否在IP列表中
--
-- @param string ip IP地址
-- @param table list IP表(Array模式)
-- @return boolean 是否在列表中
function Util:inIpList(ip, list)
    local bRange = ip:gsub("%.%d+%.%d+$", ".*.*")
    local cRange = ip:gsub("%.%d+$", ".*")

    for _, v in ipairs(list) do
        if v == ip or v == bRange or v == cRange then
            return true
        end
    end

    return false
end

--- 获取唯一键名
--
-- @param string prefix 前缀
-- @return string 唯一键名
function Util:getUniqKey(prefix)
    return string.format((prefix or "") .. "%X", ngx.now() * 100 + math.random(0, 99))
end

--- 使用密钥对字符串进行加密(解密)
--
-- @param string str 原始字符串(加密后的密文)
-- @param string key 密钥
-- @return string 加密后的密文(原始字符串)
function Util:encrypt(str, key)
    local strBytes = { str:byte(1, #str) }
    local keyBytes = { key:byte(1, #key) }
    local n, keyLen = 1, #keyBytes

    for i = 1, #strBytes do
        strBytes[i] = bit.bxor(strBytes[i], keyBytes[n])

        n = n + 1

        if n > keyLen then
            n = n - keyLen
        end
    end

    return string.char(unpack(strBytes))
end

--- 预处理JSON信息（将空表替换成NULL）
--
-- @param mixed data 数据
-- @param number depth 深度
function Util:jsonPrep(data, depth)
    depth = depth or 3

    if self:isTable(data) then
        for k, v in pairs(data) do
            if self:isTable(v) then
                if self.table:isEmpty(v) then
                    data[k] = NULL
                elseif depth > 0 then
                    self:jsonPrep(v, depth - 1)
                end
            end
        end
    end
end

--- 尝试对字符串进行JSON解码
--
-- @param string jsonStr JSON字符串
-- @return mixed 解码数据
function Util:jsonDecode(jsonStr)
    local ok, data = pcall(json.decode, jsonStr)
    return ok and data or nil
end

--- 终止程序运行并返回调试信息
--
-- @param mixed info 调试数据
function Util:debug(info)
    exception:raise("core.debug", info)
end

--- 将数据转化为可打印的字符串
--
-- @param table data 数据
-- @param string indentStr 缩进字符
-- @param number indentLevel 缩进级别
-- @return string 可打印的字符串
function Util:toString(data, indentStr, indentLevel)
    local dataType = type(data)

    if dataType == "string" then
        return string.format('%q', data)
    elseif dataType == "number" or dataType == "boolean" then
        return tostring(data)
    elseif dataType == "table" then
        return self.table:toString(data, indentStr or "\t", indentLevel or 1)
    else
        return "<" .. tostring(data) .. ">"
    end
end

--- 打印数据到日志文件中
--
-- @param table data 数据
-- @param string prefix 描述前缀
-- @param string logFile 日志文件路径
function Util:logData(data, prefix, logFile)
    self:writeFile(logFile or "/tmp/lua.log", (prefix or "") .. self:toString(data) .. "\n", true)
end

--- 文件是否存在
--
-- @param string file 文件路径
-- @return boolen 是否存在
function Util:isFile(file)
    local fd = io.open(file, "r")

    if fd then
        fd:close()
        return true
    end

    return false
end

--- 将字符串内容写入文件
--
-- @param string file 文件路径
-- @param string content 内容
-- @param string append 追加模式(否则为覆盖模式)
function Util:writeFile(file, content, append)
    local fd = exception:assert("core.cantOpenFile", { file = file }, io.open(file, append and "a+" or "w+"))
    local result, err = fd:write(content)
    fd:close()

    if not result then
        exception:raise("core.cantWriteFile", { file = file, errmsg = err })
    end
end

--- 读取文件的全部内容
--
-- @param string file 文件路径
-- @return string 文件内容
function Util:readFile(file)
    local fd = exception:assert("core.cantOpenFile", { file = file }, io.open(file, "r"))
    local result = fd:read("*a")
    fd:close()

    if not result then
        exception:raise("core.cantReadFile", { file = file })
    end

    return result
end

--- 执行系统命令并获得返回结果
--
-- @param string command 系统命令
-- @return string 返回结果
function Util:execute(command)
    local fd = exception:assert("core.cantOpenFile", { command = command }, io.popen(command, 'r'))
    local result = fd:read("*a")
    fd:close()

    if not result then
        exception:raise("core.cantReadFile", { command = command })
    end

    return result
end

--- 建立模块与父模块的继承关系
--
-- @param table module 模块
-- @param table parent 父模块
-- @return table 模块(第一个参数)
function Util:inherit(module, parent)
    module.__super = parent
    return setmetatable(module, { __index = parent })
end

--- 获取指定名字的业务逻辑模块
--
-- @param string name 业务逻辑模块名
-- @return table 业务逻辑模块
function Util:getService(name)
    local path = "code.service." .. name
    local ok, service = pcall(loadMod, path)

    if not ok then
        service = serviceBase:inherit({ DAO_NAME = name }):init()
        saveMod(path, service)
    end

    return service
end

--- 访问nginx定义的内部位置，并返回数据结果
--
-- @param string uri 位置路径
-- @param table args GET参数(GET模式)
-- @param table|string postData Post数据(Post模式)
-- @param boolean stdRet 标准结果({"op":<number>,"data":<table>,"error":<string>},解析成数据并检查错误)
-- @return table 结果数据
function Util:proxy(uri, args, postData, stdRet)
    local params = { args = args }

    if postData then
        params.method = ngx.HTTP_POST

        if self:isTable(postData) then
            params.body = ngx.encode_args(postData)
        else
            params.body = tostring(postData)
        end
    end

    local res = ngx.location.capture(uri, params)

    if res.status ~= ngx.HTTP_OK then
        exception:raise("core.proxyFailed", res)
    end

    if stdRet then
        local ok, data = pcall(json.decode, res.body)

        if not ok then
            exception:raise("core.proxyFailed", res)
        end

        if data.error and data.error ~= ngx.null then
            exception:raise("core.proxyFailed", data)
        end

        return data.data
    end

    return res.body
end

return Util
