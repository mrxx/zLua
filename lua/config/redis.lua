return {
    --- 服务器 unix sock
    SOCK = nil, --"/data/gl/db/redis-dev/redis.sock",

    --- 服务器IP
    HOST = "127.0.0.1",

    --- 服务器端口
    PORT = 6379,

    --- 连接超时
    TIMEOUT = 10000,

    --- 连接池大小（高峰请求数/worker数量）
    POOL_SIZE = 100,
}