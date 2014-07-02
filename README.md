zLua
====
一个基于Openresty的轻量级web应用框架。  

系统要求
====
## 软件最低版本需求
* [Openresty](http://www.openresty.org/): v1.51    
* [Nginx Push Stream Module](https://github.com/wandenberg/nginx-push-stream-module): v0.4    
* [Redis](http://redis.io/download): v2.6    
* [Lua-zlib](https://github.com/brimworks/lua-zlib): v0.2     

## 软件安装事项
* 实现 MySQL 的 JsonField 支持需替换 OpenResty 的 mysql 驱动。    
  拷贝 soft 中的 mysql.lua 至 OpenResty 对应目录即可。    
  <code>cp -f ./soft/mysql.lua /usr/local/openresty/lualib/resty/</code>   
* 实现推送消息支持，需安装 Nginx Push Stream Module。    
  编译 OpenResty 时需要增加对应编译参数。    
  <code>./configure --with-luajit --add-module=../nginx-push-stream-module-0.4.0</code>    
* 实现上行消息 Gzip 支持，需要安装 Lua-zlib。    
  编译时需要链接 OpenResty 的 libluajit-5.1.so。    
  <code>ln -fs /usr/local/openresty/luajit/lib/libluajit-5.1.so.2 /usr/lib64/liblua.so</code>    
  并修改 Lua-zlib 的 MakeFile 中的 INCDIR。    
  <code>INCDIR   = -I/usr/local/openresty/luajit/include/luajit-2.1</code>  

如果是 64 位 CentOS 系统，可用 soft/soft.sh 安装上述软件。

## Nginx 配置
框架运作需要在 Nginx 的 http 和 server 中增加相关配置。
<code>  
http
{
    # Push Stream 共享内存大小
    push_stream_shared_memory_size 256m;

    # Push Stream 频道无活动后被回收的时间
    push_stream_channel_inactivity_time 30m;

    # Push Stream 消息生存时间
    push_stream_message_ttl 30m;

    # lua 文件包含基础路径
    lua_package_path '/data/web/?.lua;;';

    # lua C扩展包含基础路径
    lua_package_cpath '/data/web/?.so;;';

    server
    {
        listen 80;
        server_name zlua.zivn.me;
        access_log /data/log/nginx.zlua.log;

        # 服务器目录名（不可用 "."，否则包含文件时会被 Lua 替换为目录分隔符）
        set $SERVER_DIR zlua_zivn_me;

        # 项目根目录
        set $ROOT_PATH /data/web/$SERVER_DIR;

        # Lua 文件根目录
        set $LUA_PATH $ROOT_PATH/lua;

        # 定义 Web 目录
        root $ROOT_PATH/webroot;
        index index.html index.htm index.php;

        # lua 请求路径
        location = /lua {
            # 打开代码缓存
            lua_code_cache on;

            # 程序入口
            content_by_lua_file $LUA_PATH/main.lua;
        }

        # 发布推送消息路径
        location /pub {
            internal;

            # 发布者身份
            push_stream_publisher admin;

            # 频道路径参数
            push_stream_channels_path $arg_id;

            # 保存频道消息
            push_stream_store_messages on;

            # 发送消息后不返回频道信息
            push_stream_channel_info_on_publish off;

            # 最近接收频道消息的时间（用于滤除旧消息）
            push_stream_last_received_message_time $arg_time;
        }
        
        # 订阅推送消息路径
        location ~ /sub/(.*) {
            # 消息订阅者
            push_stream_subscriber;

            # 频道路径参数
            push_stream_channels_path $1;
        }
    }
}
</code>  




