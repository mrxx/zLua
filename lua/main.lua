--- 定义NULL常量
_G.NULL = ngx.null

--- 置换系统 Require 函数
_G.loadMod = function(namespace)
    ngx.log(ngx.WARN, "load " .. namespace .. " model")
    return require(ngx.var.SERVER_DIR .. ".lua." .. namespace)
end

_G.saveMod = function(namespace, model)
    package.loaded[ngx.var.SERVER_DIR .. ".lua." .. namespace] = model
end

--- 加载主模块
_G.loadMod("core.app"):run()


