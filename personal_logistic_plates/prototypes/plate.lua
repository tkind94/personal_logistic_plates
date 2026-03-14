local config = require("config")

local base_range = settings.startup["logistic_plate_range"].value

for _, tier in ipairs(config.TIERS) do
    local half = tier.size_tiles / 2
    local icon = "__personal_logistic_plates__/graphics/plates/plate_tier" .. tier.tier .. ".png"

    data:extend({
        {
            type = "simple-entity-with-owner",
            name = tier.name,
            icon = icon,
            icon_size = tier.texture_size,
            flags = { "placeable-neutral", "player-creation" },
            minable = { mining_time = 1, result = tier.name },
            max_health = tier.max_health,
            corpse = "small-remnants",
            collision_box = { { -half + 0.05, -half + 0.05 }, { half - 0.05, half - 0.05 } },
            collision_mask = { layers = { object = true } },
            selection_box = { { -half, -half }, { half, half } },
            selection_priority = 0,
            render_layer = "floor",
            radius_visualisation_specification = {
                sprite = {
                    filename = "__base__/graphics/entity/small-electric-pole/electric-pole-radius-visualization.png",
                    width = 12,
                    height = 12,
                    priority = "extra-high-no-scale"
                },
                distance = base_range * tier.range_multiplier,
                draw_in_cursor = true,
                draw_on_selection = true
            },
            picture = {
                filename = icon,
                priority = "high",
                width = tier.texture_size,
                height = tier.texture_size,
                scale = (tier.size_tiles * 32) / tier.texture_size
            }
        },
        {
            type = "item",
            name = tier.name,
            icon = icon,
            icon_size = tier.texture_size,
            subgroup = "storage",
            order = tier.order,
            place_result = tier.name,
            stack_size = 50,
            localised_description = { "item-description.logistic_plate" },
            factoriopedia_description = { "item-description.logistic_plate" },
            custom_tooltip_fields = {
                {
                    name = { "plp.tooltip-range" },
                    value = { "plp.tooltip-range-value", tostring(base_range * tier.range_multiplier) }
                },
                {
                    name = { "plp.tooltip-transfer-rate" },
                    value = { "plp.tooltip-transfer-rate-value", tostring(tier.items_per_second) },
                    quality_values = {},
                    quality_header = "quality-tooltip.increases"
                }
            }
        },
        {
            type = "recipe",
            name = tier.name,
            enabled = true,
            ingredients = tier.ingredients,
            results = { { type = "item", name = tier.name, amount = 1 } }
        }
    })
end
