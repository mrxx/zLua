--- 英雄相关常量
return {
    --- 单次吞噬英雄数量上限
    MAX_DEVOUR_NUM = 5,

    --- 吞噬经验折算系数
    DEVOUR_EXP_RATE = 0.8,

    --- 出售价格等级因数
    PRICE_LEVEL_RATIO = 20,

    --- 效果属性映射表
    EFFECT_MAP = {
        [100] = "hp", -- 血量
        [101] = "att", -- 攻击
        [102] = "def", -- 防御
        [103] = "hit", -- 命中
        [104] = "dodge", -- 闪避
        [105] = "crit", -- 暴击
    }
}

