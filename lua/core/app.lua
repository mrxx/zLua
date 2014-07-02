local exception = loadMod("core.exception")
local request = loadMod("core.request")
local response = loadMod("core.response")
local mysql = loadMod("core.driver.mysql")
local redis = loadMod("core.driver.redis")
local memcached = loadMod("core.driver.memcached")
local session = loadMod("core.session")
local sysConf = loadMod("config.system")

local App = {}

--- 初始化
function App:init()
    if not ngx.var.LUA_PATH then
        exception:raise("core.badConfig", { LUA_PATH = ngx.var.LUA_PATH })
    end

    sysConf.ROOT_PATH = ngx.var.LUA_PATH

    -- 初始化随机数种子
    math.randomseed(tostring(ngx.now() * 1000):reverse():sub(1, 6))
end

--- 清理
function App:clean()
    session:unlock()
    redis:close()
    memcached:close()
    mysql:close()
end

--- 请求路由分发
function App:route()
    local module, method = unpack(request:getAction())

    if not module or not method then
        exception:raise("core.badAction", { module = module, method = method })
    end

    local retry = response:checkRetry()

    if not retry then
        local path = "code.ctrl." .. module
        local _, ctrl = exception:assert("core.badCall", { command = "loadMod", args = { path } }, pcall(loadMod, path))

        if not ctrl or not ctrl[method] or not ctrl.filter or not ctrl.cleaner then
            exception:raise("core.badCall", { module = module, method = method })
        end

        ctrl:filter()
        ctrl[method](ctrl)
        ctrl:cleaner()
    end
end

--- 执行应用
function App:run()
    local status, err = pcall(function()
        self:init()
        self:route()
    end)

    if not status then
        response:error(err)
    end

    self:clean()
end

return App
