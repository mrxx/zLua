local util = loadMod("core.util")
local exception = loadMod("core.exception")
local request = loadMod("core.request")
local response = loadMod("core.response")
local push = loadMod("core.push")
local ctrlBase = loadMod("core.base.ctrl")
local session = loadMod("core.session")
local consts = loadMod("code.const.user")
local userService = util:getService("user")

--- 用户操作
local User = {}

--- 用户注册
--
-- @param string name 用户名称
-- @param string passwd 用户密码
-- @param int icon 头像ID
-- @param int heroId 英雄ID
-- @return {"token":<token>,"zoneOffset":28800,"serverTime":1403601121,"pushVer":8509,"userData":{"user":<user>,"equips":[<userEquip>],"heros":[<userHero>]}}
function User:register()
    local name = request:getStrParam("name", true, true)
    local passwd = request:getStrParam("passwd", true)
    local icon = request:getNumParam("icon", true, true)
    local heroId = request:getNumParam("heroId", true, true)

    local nameWidth = util.string:width(name)

    if nameWidth < 2 or nameWidth > 12 then
        exception:raise("user.errNameLen", { name = name })
    end

    local passwdWidth = util.string:width(passwd)

    if passwdWidth < 6 or nameWidth > 12 then
        exception:raise("user.errPwdLen", { name = name })
    end

    if icon < consts.INIT_MIN_ICON or icon > consts.INIT_MAX_ICON then
        exception:raise("user.invalidIcon", { icon = icon })
    end

    if util.string:checkFilter(name) then
        exception:raise("user.nameForbid", { name = name })
    end

    if userService:nameExist(name) then
        exception:raise("user.nameExist", { name = name })
    end

    if not util.table:hasValue(consts.INIT_HEROS, heroId) then
        exception:raise("core.forbidden", { heroId = heroId })
    end

    local user = userService:create(name, passwd, icon, heroId, request:getIp())
    local token = session:register({ userId = user.id, userName = user.name })
    local userData = userService:getUserData(user)

    response:reply({
        token = token,
        serverTime = util:now(),
        zoneOffset = util:getTimeOffset(),
        pushVer = push:getVersion(),
        userData = userData
    }, nil, true)
end

--- 用户登录
--
-- @param string name 用户名称
-- @param string passwd 用户密码
-- @return {"token":<token>,"zoneOffset":28800,"serverTime":1403601121,"pushVer":8509,"userData":{"user":<user>,"equips":[<userEquip>],"heros":[<userHero>]}}
function User:login()
    local name = request:getStrParam("name", true, true)
    local passwd = request:getStrParam("passwd", true)

    local user = userService:getByName(name)

    if not user then
        exception:raise("user.needInit", { name = name })
    end

    if user.passwd ~= userService:mixPwd(passwd) then
        exception:raise("user.wrongPwd", { name = name, passwd = passwd })
    end

    if userService:isBanLogin(user) then
        exception:raise("user.banLogin", { userId = userInfo.userId, userStatus = user.status })
    end

    user.loginTime = util:now()
    user.loginIp = request:getIp()
    userService:update(user, { "loginTime", "loginIp" })

    local token = session:register({ userId = user.id, userName = user.name })
    local userData = userService:getUserData(user)

    response:reply({
        token = token,
        serverTime = util:now(),
        zoneOffset = util:getTimeOffset(),
        pushVer = push:getVersion(),
        userData = userData
    }, nil, true)
end

--- 更换头像
--
-- @param string token 用户验证token
-- @param int icon 头像ID
-- @return {"ok":true}
function User:changeIcon()
    local userInfo = self:getSessionInfo()
    local icon = request:getNumParam("icon", true, true)

    if icon < consts.INIT_MIN_ICON or icon > consts.INIT_MAX_ICON then
        exception:raise("user.invalidIcon", { icon = icon })
    end

    local user = userService:getOne(userInfo.userId)

    if not user then
        exception:raise("user.needInit", { userId = userId })
    end

    if user.icon ~= icon then
        user.icon = icon
        userService:update(user, { "icon" })
    end

    response:reply({ ok = true })
end

return util:inherit(User, ctrlBase)
