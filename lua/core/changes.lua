local util = loadMod("core.util")
local rules = loadMod("config.changes")
local exception = loadMod("core.exception")

local Changes = {}

--- 初始化改变
--
-- @param table userInfo 用户信息
function Changes:init(userInfo)
    if not userInfo or not userInfo.userId then
        exception:raise("core.systemErr", { userInfo = userInfo })
    end

    ngx.ctx[Changes] = { userInfo = userInfo, updates = {}, removes = {} }
end

--- 获取改变
--
-- @return table 更新信息
-- @return table 删除信息
function Changes:getChanges()
    local changes = ngx.ctx[Changes]
    local updates, removes = {}, {}

    if changes then
        for key, rule in pairs(rules) do
            if rule.single then
                updates[key] = changes.updates[key]
                removes[key] = changes.removes[key]
            else
                updates[key] = changes.updates[key] and util.table:values(changes.updates[key]) or nil
                removes[key] = changes.removes[key] and util.table:keys(changes.removes[key]) or nil
            end
        end
    end

    return updates, removes
end

--- 记录单个信息变化
--
-- @param string key 键名
-- @param table entity 信息实体
-- @param table props 更新属性
function Changes:updateOne(key, entity, props)
    local changes = ngx.ctx[Changes]
    local rule = rules[key]

    if not changes or not changes.updates then
        return
    end

    if not rule or changes.userInfo[rule.matchkey] ~= entity[rule.matchAttr] then
        return
    end

    if changes.updates[key] then
        if rule.single then
            util.table:copy(entity, changes.updates[key], props)
        else
            local primaryKey = entity[rule.primaryKey]
            local item = changes.updates[key][primaryKey]

            if item then
                util.table:copy(entity, item, props)
            else
                changes.updates[key][primaryKey] = util.table:copy(entity, { [rule.primaryKey] = primaryKey }, props)
            end
        end
    else
        local primaryKey = entity[rule.primaryKey]
        local item = util.table:copy(entity, { [rule.primaryKey] = primaryKey }, props)

        changes.updates[key] = rule.single and item or { [primaryKey] = item }
    end
end

--- 记录多个信息变化
--
-- @param string key 键名
-- @param table entitys 信息实体序列
function Changes:updateMany(key, entitys)
    local changes = ngx.ctx[Changes]
    local rule = rules[key]

    if not changes or not changes.updates then
        return
    end

    if not rule or rule.single then
        return
    end

    if not changes.updates[key] then
        changes.updates[key] = {}
    end

    for _, entity in pairs(entitys) do
        local primaryKey = entity[rule.primaryKey]
        local item = changes.updates[key][primaryKey]

        if item then
            util.table:copy(entity, item)
        else
            changes.updates[key][primaryKey] = entity
        end
    end
end

--- 移除多个信息
--
-- @param string key 键名
-- @param table entitys 信息实体序列
function Changes:remove(key, entitys)
    local changes = ngx.ctx[Changes]
    local rule = rules[key]

    if not changes or not changes.removes then
        return
    end

    if not rule or rule.single then
        return
    end

    if not changes.removes[key] then
        changes.removes[key] = {}
    end

    for _, entity in pairs(entitys) do
        local primaryKey = entity[rule.primaryKey] or entity[1]
        changes.removes[key][primaryKey] = true

        if changes.updates[key] and changes.updates[key][primaryKey] then
            changes.updates[key][primaryKey] = nil
        end
    end
end

return Changes
