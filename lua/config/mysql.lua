return {
    --- 服务器 unix sock
    SOCK = nil, --"/data/gl/db/mysql-dev/mysql.sock",

    --- 服务器IP
    HOST = "127.0.0.1",

    --- 服务器端口
    PORT = 3306,

    --- 用户名
    USER = "zLua",

    --- 密码
    PASSWORD = "zLuaTest",

    --- 数据库
    DATABASE = "zlua_data",

    --- 连接超时
    TIMEOUT = 10000,

    --- 连接池大小（高峰请求数/worker数量）
    POOL_SIZE = 100,
}