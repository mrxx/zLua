--- 错误代码
return {
    --- 【系统错误】 ---
    --- 核心错误
    core = {
        unknowErr = "未知错误",
        debug = "调试中断",
        systemErr = "系统错误",
        forbidden = "不允许",
        badConfig = "配置错误",
        badCall = "错误调用",
        badAction = "动作错误",
        badParams = "参数错误",
        cantOpenFile = "无法打开文件",
        cantReadFile = "无法读取文件",
        cantWriteFile = "无法写入文件",
        proxyFailed = "代理失败",
        serverClose = "服务器维护",
        connectFailed = "连接服务器失败",
        queryFailed = "执行查询失败",
        needLogin = "找不到会话信息，需要重登陆",
    },

    --- 【自定义错误】 ---
    --- 用户系统错误
    user = {
        banLogin = "禁止登陆",
        needInit = "用户未初始化",
        notFound = "找不到指定用户",
        errNameLen = "名字长度不正确",
        errPwdLen = "密码长度不正确",
        invalidIcon = "头像不正确",
        nameExist = "名字已被使用",
        nameForbid = "名字禁止使用",
        wrongPwd = "密码错误",
        lessGold = "用户金币不足",
        lessEnergy = "用户活力不足",
    },
    --- 聊天系统错误
    chat = {
        tooFast = "发送消息间隔过短",
        banChat = "用户已被禁言",
        sendToUnknow = "私聊对象不存在",
    },
    --- 装备系统错误
    equip = {
        typeError = "装备类型错误",
        maxLevel = "已达到等级上限",
        wasEquiped = "装备正在使用中",
    },
    --- 英雄系统错误
    hero = {
        wrongNumHero = "英雄数量错误",
        maxLevel = "已达到等级上限",
    },
}
