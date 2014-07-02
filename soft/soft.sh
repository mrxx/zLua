#!/bin/bash
export LANG=zh_CN.UTF-8

echo -n ">> Install Redis ... "
tar xvzf ./redis-2.8.12.tar.gz 1>/dev/null

pushd ./redis-2.8.12 >/dev/null
    make 1>/dev/null 2>/dev/null
    make install 1>/dev/null 2>/dev/null
popd >/dev/null

rm -rf ./redis-2.8.12
echo "OK"


echo -n ">> Install PHPRedis ... "
tar xvzf ./phpredis-2.2.5.tar.gz 1>/dev/null

pushd ./phpredis-2.2.5 >/dev/null
    phpize 1>/dev/null 2>/dev/null
    ./configure 1>/dev/null 2>/dev/null
    make 1>/dev/null 2>/dev/null
    make install 1>/dev/null 2>/dev/null
popd >/dev/null

rm -rf ./phpredis-2.2.5
echo "OK"

echo -n ">> Install OpenResty ... "
yum -y install readline-devel pcre-devel openssl-devel 1>/dev/null 2>/dev/null
tar xvzf ./ngx_openresty-1.7.0.1.tar.gz 1>/dev/null
tar xvzf ./nginx-push-stream-module-0.4.0.tar.gz 1>/dev/null

pushd ./ngx_openresty-1.7.0.1 >/dev/null
    ./configure --with-luajit --add-module=../nginx-push-stream-module-0.4.0 1>/dev/null 2>/dev/null
    gmake 1>/dev/null 2>/dev/null
    gmake install 1>/dev/null 2>/dev/null
popd >/dev/null

\cp -f ./mysql.lua /usr/local/openresty/lualib/resty/
rm -rf ./ngx_openresty-1.7.0.1
rm -rf ./nginx-push-stream-module-0.4.0
echo "OK"

echo -n ">> Install Lua-zlib ... "
ln -fs /usr/local/openresty/luajit/lib/libluajit-5.1.so.2 /usr/lib64/liblua.so
tar xvzf ./lua-zlib-0.2.tar.gz 1>/dev/null

pushd ./lua-zlib-0.2 >/dev/null
    make linux 1>/dev/null 2>/dev/null
    \cp -f ./zlib.so /usr/local/openresty/lualib/
popd >/dev/null

rm -rf ./lua-zlib-0.2
echo "OK"

echo ">> All finish!!!"
