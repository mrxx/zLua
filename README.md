zLua
====
一个基于Openresty的轻量级web应用框架。  

系统要求
====
# 软件最低版本需求
[Openresty](http://www.openresty.org/): v1.51    
[Nginx Push Stream Module](https://github.com/wandenberg/nginx-push-stream-module): v0.4    
[Redis](http://redis.io/download): v2.6    
[Lua-zlib](https://github.com/brimworks/lua-zlib): v0.2     

# 软件安装事项
* 实现 MySQL 的 JsonField 支持需替换 OpenResty 的 mysql 驱动。
** 拷贝 soft 中的 mysql.lua 至 OpenResty 对应目录即可。
> cp -f ./soft/mysql.lua /usr/local/openresty/lualib/resty/
* 实现推送消息支持，需安装 Nginx Push Stream Module。
** 编译 OpenResty 时需要增加对应编译参数。
> ./configure --with-luajit --add-module=../nginx-push-stream-module-0.4.0
* 实现上行消息 Gzip 支持，需要安装 Lua-zlib。
** 编译时需要链接 OpenResty 的 libluajit-5.1.so。
> ln -fs /usr/local/openresty/luajit/lib/libluajit-5.1.so.2 /usr/lib64/liblua.so
** 并修改 Lua-zlib 的 MakeFile 中的 INCDIR。
> INCDIR   = -I/usr/local/openresty/luajit/include/luajit-2.1





