return {
    --- 调试模式
    DEBUG_MODE = true,

    --- 启用GET参数
    GET_ENABLE = true,

    --- 启用POST参数
    POST_ENABLE = true,

    --- 启用COOKIE参数
    COOKIE_ENABLE = true,

    --- 默认编码
    DEFAULT_CHARSET = "UTF8",

    --- 启用请求数据加密(POST数据)
    ENCRYPT_REQUEST = false,

    --- 启用应答数据加密
    ENCRYPT_REPLY = false,

    --- 应答加密密钥
    ENCRYPT_KEY = "kjhdskfhalkdfioweuwueoiu@#!$!@w2#@%%$^%&*%^(%&",

    --- 会话有效期
    SESSION_EXPTIME = 86400,

    --- 会话密钥名字
    SESSION_TOKEN_NAME = "token",

    --- 操作锁超时(秒)
    LOCKER_TIMEOUT = 3,

    --- 操作锁重试间隔(秒)
    LOCKER_RETRY_INTERVAL = 0.25,


    --- 密码混淆密钥
    PASSWD_MIX_KEY = "zLua is good",



    --- 服务器标志
    SERVER_MARK = "dev",

    --- 推送发布地址
    PUSH_PUB_URI = "/pub",

    --- 超级IP列表（无视维护状态和各种限制）
    SUPER_IPS = { "10.6.*.*", "10.18.*.*", "10.25.*.*", "10.255.*.*", "10.4.*.*" },



    --- 服务器开启时间
    SERVER_START_TIME = "2014-06-01 10:00:00",

    --- 服务器维护结束时间
    SERVER_MT_ENDLINE = "2014-06-10 10:00:00",
}
