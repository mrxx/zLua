--- 聊天相关常量
return {
    --- 推送聊天的OP
    OP_PUSH_CHAT = 2,

    --- 推送Ping的OP
    OP_PUSH_PING = 3,

    --- 频道：用户
    CHANNEL_USER = 0,

    --- 频道：世界
    CHANNEL_WORLD = 1,

    --- 频道：Ping
    CHANNEL_PING = 2,

    --- 频道信息
    CHANNEL_INFO = {
        [0] = { prefix = "user", interval = 1 },
        [1] = { prefix = "world", interval = 10 },
        [2] = { prefix = "ping", interval = 1 },
    },
}

