local util = loadMod("core.util")
local daoBase = loadMod("core.base.dyncDao")
local cacheConf = loadMod("config.cache")

local UserEquip = {
    --- 数据库表名
    TABLE_NAME = "game_user_equip",

    --- 主键
    PRIMARY_KEY = { "id" },

    --- 自增索引键
    AUTOINCR_KEY = "id",

    --- JSON类型键集合
    JSON_KEYSET = { effects = true },

    --- 是否缓存
    CACHE_ENABLE = true,

    --- 缓存库索引
    CACHE_INDEX = cacheConf.INDEX_EQUIP,

    --- 记录变化键名
    logChangeKey = "equips",
}

--- 获取指定ID序列的用户装备信息
--
-- @param table ids ID序列
-- @return table 用户装备信息序列
function UserEquip:getByIds(ids)
    return self.dbHelper:fetchRows("`id` IN (" .. self:createFields(#ids) .. ")", ids)
end

--- 获取指定用户的所有装备信息
--
-- @param number userId 用户ID
-- @return table 用户装备信息序列
function UserEquip:getByUser(userId)
    return self.dbHelper:fetchRows("`userId`={1}", { userId })
end

--- 获取指定英雄的所有装备信息
--
-- @param number heroId 英雄ID
-- @return table 用户装备信息序列
function UserEquip:getByHero(heroId)
    return self.dbHelper:fetchRows("`heroId`={1}", { heroId })
end

--- 获取指定英雄指定位置的装备信息
--
-- @param number heroId 英雄ID
-- @param number position 位置
-- @return table 用户装备信息
function UserEquip:getByPos(heroId, position)
    return self.dbHelper:fetchRow("`heroId`={1} AND `position`={2}", { heroId, position })
end

--- 获取指定英雄的所有装备ID序列
--
-- @param number heroId 英雄ID
-- @return table 用户装备ID序列
function UserEquip:getIdsByHero(heroId)
    return self.dbHelper:fetchCol("`heroId`={1}", { heroId }, { "id" })
end

--- 获取指定英雄序列的所有装备ID序列
--
-- @param table heroIds 英雄ID序列
-- @return table 用户装备ID序列
function UserEquip:getIdsByHeros(heroIds)
    return self.dbHelper:fetchCol("`heroId` IN (" .. self:createFields(#heroIds) .. ")", heroIds, { "id" })
end

--- 获取指定用户的装备数量
--
-- @param number userId 用户ID
-- @return number 装备数量
function UserEquip:countByUser(userId)
    return tonumber(self.dbHelper:fetchValue("`userId`={1}", { userId }, "COUNT(*)")) or 0
end

return util:inherit(UserEquip, daoBase):init()
