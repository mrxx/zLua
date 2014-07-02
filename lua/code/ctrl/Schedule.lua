local json = require("cjson")
local util = loadMod("core.util")
local exception = loadMod("core.exception")
local request = loadMod("core.request")
local response = loadMod("core.response")
local ctrlBase = loadMod("core.base.ctrl")
local sysConf = loadMod("config.system")

--- 数字是否符合许可条件
--
-- @param number|string allows 许可条件
-- @param number num 待检查数字
-- @return boolean 是否符合条件
local function isAllow(allows, num)
    if not allows then
        return true
    end

    if util:isNumber(allows) and num == allows then
        return true
    end

    if util:isString(allows) then
        local period = tonumber(string.match(allows, "*/(%d+)"))

        if period and period > 0 then
            return num % period == 0
        end
    end

    return false
end

--- 任务表
local tasks = {}

--- 计划任务操作
local Schedule = {}

--- 过滤器
function Schedule:filter()
    if not sysConf.DEBUG_MODE and not request:isLocal() then
        exception:raise("core.forbidden", { ip = request:getIp() })
    end
end

--- 初始化计划任务
--
-- @return Schedule
function Schedule:init()
    self:register("ping", nil, nil, nil)

    return self
end

--- 注册计划任务
--
-- @param string task 任务名
-- @param number|string week 执行的周周期(nil则不检查, "*/3"表示每周三)
-- @param number|string hour 执行的小时周期(nil则不检查, "*/3"表示每3小时)
-- @param number|string minute 执行的分钟周期(nil则不检查, "*/3"表示每3分钟)
function Schedule:register(task, week, hour, minute)
    tasks[#tasks + 1] = { task = task, week = week, hour = hour, minute = minute }
end

--- 执行计划任务
function Schedule:run()
    local now = os.date("*t")
    local week, hour, minute = now.wday - 1, now.hour, now.min

    local nowDate = util:now(true)
    local result = {}

    for _, task in ipairs(tasks) do
        if isAllow(task.week, week) and isAllow(task.hour, hour) and isAllow(task.minute, minute) then
            local status, info = pcall(self[task.task], self)

            if status then
                result[#result + 1] = util:format("[{1}] execute <{2}> OK!", { nowDate, task.task })

                if info then
                    result[#result + 1] = json.encode(info)
                end
            else
                if util:isString(info) then
                    info = exception:pack("core.systemErr", { errmsg = info })
                end

                result[#result + 1] = util:format("[{1}] execute <{2}> Error!", { nowDate, task.task })
                result[#result + 1] = json.encode(info)
            end
        end
    end

    response:output(table.concat(result, "\n"), true, true)
end

--- 推送 Ping 消息
function Schedule:ping()
    loadMod("core.push"):toPing()
end

return util:inherit(Schedule, ctrlBase):init()
