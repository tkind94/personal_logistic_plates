-- Single source of truth for plate tier definitions and quality scaling.
-- Safe to require from both data and control stages.

local config = {}

config.QUALITY_SCALE_PER_LEVEL = 0.3

config.TIERS = {
    {
        name = "logistic_plate_tier1",
        tier = 1,
        order = "a[items]-b[logistic_plate_tier1]",
        size_tiles = 1,
        texture_size = 640,
        max_health = 200,
        range_multiplier = 1,
        items_per_second = 30,
        ingredients = {
            {type = "item", name = "iron-plate", amount = 10},
            {type = "item", name = "electronic-circuit", amount = 5}
        }
    },
    {
        name = "logistic_plate_tier2",
        tier = 2,
        order = "a[items]-b[logistic_plate_tier2]",
        size_tiles = 2,
        texture_size = 640,
        max_health = 300,
        range_multiplier = 3,
        items_per_second = 90,
        ingredients = {
            {type = "item", name = "logistic_plate_tier1", amount = 2},
            {type = "item", name = "steel-plate", amount = 20},
            {type = "item", name = "advanced-circuit", amount = 10}
        }
    },
    {
        name = "logistic_plate_tier3",
        tier = 3,
        order = "a[items]-b[logistic_plate_tier3]",
        size_tiles = 3,
        texture_size = 640,
        max_health = 400,
        range_multiplier = 7,
        items_per_second = 210,
        ingredients = {
            {type = "item", name = "logistic_plate_tier2", amount = 2},
            {type = "item", name = "processing-unit", amount = 15},
            {type = "item", name = "low-density-structure", amount = 10}
        }
    }
}

function config.quality_multiplier(level)
    return 1 + config.QUALITY_SCALE_PER_LEVEL * level
end

config.PLATE_NAMES = {}
config.TIER_BY_NAME = {}

for _, tier in ipairs(config.TIERS) do
    config.PLATE_NAMES[#config.PLATE_NAMES + 1] = tier.name
    config.TIER_BY_NAME[tier.name] = tier
end

return config
