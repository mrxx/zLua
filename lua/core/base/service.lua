local exception = loadMod("core.exception")

local ServiceBase = {
    --- 数据访问模块名
    DAO_NAME = nil,

    --- 数据访问模块实例
    dao = nil,
}

--- 业务逻辑模块初始化
--
-- @return table 业务逻辑模块
function ServiceBase:init()
    if not self.DAO_NAME then
        exception:raise("core.badConfig", { DAO_NAME = self.DAO_NAME })
    end

    self.dao = loadMod("code.dao." .. self.DAO_NAME)

    return self
end

--- 建立模块与业务逻辑基类的继承关系(模块Dao属性的全部方法将会暴露，可以像调用模块本身的方法一样调用)
--
-- @param table module 模块
-- @return table 模块
function ServiceBase:inherit(module)
    module.__super = self

    return setmetatable(module, {
        __index = function(self, key)
            if self.__super[key] then
                return self.__super[key]
            end

            if type(self.dao[key]) == "function" then
                return function(...)
                    local args = { ... }
                    args[1] = self.dao

                    return self.dao[key](unpack(args))
                end
            end

            return nil
        end
    })
end

return ServiceBase
