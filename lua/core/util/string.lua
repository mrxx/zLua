local resty_string = require("resty.string")
local filterWords = loadMod("data.filterWords")
local String = {}

--- 去除字符串收尾空格
--
-- @param string str
-- @return string
function String:trim(str)
    return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
end

--- 使用SHA1加密字符串
--
-- @param string str
-- @return string
function String:sha1(str)
    return resty_string.to_hex(ngx.sha1_bin(str))
end

--- 返回首字母大写后的字符串
--
-- @param string str 原始字符串
-- @return string 首字母大写后的字符串
function String:capital(str)
    return (str:gsub("^%a", function(char)
        return char:upper()
    end))
end

--- 获取字符宽度（中文算2个字符）
--
-- @param string str 原始字符串
-- @return number 字符宽度
function String:width(str)
    local bytes = { string.byte(str, 1, #str) }
    local length, begin = 0, false

    for _, byte in ipairs(bytes) do
        if byte < 128 or byte >= 192 then
            begin = false
            length = length + 1
        elseif not begin then
            begin = true
            length = length + 1
        end
    end

    return length
end

--- 将分隔符隔开的数字字符串转化为数字表
--
-- @param string str 原始字符串
-- @param string separator 分隔符
-- @return table 数字表
function String:toNumList(str, separator)
    separator = separator or ";"

    local list, pos = {}, 1

    if str then
        while true do
            local s, e = str:find(separator, pos)

            if not s then
                list[#list + 1] = tonumber(str:sub(pos, str:len()))
                break
            end

            list[#list + 1] = tonumber(str:sub(pos, s - 1))
            pos = e + 1
        end
    end

    return list
end

--- 将分隔符隔开的数字字符串转化为数字矩阵
--
-- @param string str 原始字符串
-- @param string mainSep 主分隔符
-- @param string subSep 子分隔符
-- @return table 数字矩阵
function String:toNumMatrix(str, mainSep, subSep)
    mainSep = mainSep or ";"
    subSep = subSep or "|"

    local matrix, pos = {}, 1

    if str then
        while true do
            local s, e = str:find(mainSep, pos)

            if not s then
                matrix[#matrix + 1] = self:toNumList(str:sub(pos, str:len()), subSep)
                break
            end

            matrix[#matrix + 1] = self:toNumList(str:sub(pos, s - 1), subSep)
            pos = e + 1
        end
    end

    return matrix
end

--- 检查字符串是否含有有过滤词
--
-- @param string str 字符串
-- @return boolean 是否含有过滤词
function String:checkFilter(str)
    local length, invalid = #str, false

    for i = 1, length do
        local node = filterWords

        for j = i, length do
            node = node[str:byte(j)]

            if not node then
                break
            end

            if node[0] then
                invalid = true
                break
            end
        end

        if invalid then
            break
        end
    end

    return invalid
end

--- 替换字符串中的过滤词
--
-- @param string str 字符串
-- @return string 替换后的字符串
function String:replaceFilter(str)
    local mask = ("*"):byte(1)
    local bytes = { str:byte(1, #str) }
    local length, i = #bytes, 1

    while i <= length do
        local node = filterWords
        local invalid = false
        local j = i

        while j <= length do
            node = node[bytes[j]]

            if not node then
                break
            end

            if node[0] then
                invalid = true
                break
            end

            j = j + 1
        end

        if invalid then
            for i = i, j do
                bytes[i] = mask
            end
        else
            i = i + 1
        end
    end

    return string.char(unpack(bytes))
end

return String
