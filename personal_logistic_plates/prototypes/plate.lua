local QUALITY_TRANSFER_MULTIPLIER_TEXT = "Normal 1.0x, Uncommon 1.5x, Rare 2.0x, Epic 2.5x, Legendary 3.0x"

local function make_plate_tier(tier, order_suffix, size_tiles, texture_size, max_health, ingredients, range_multiplier,
                               items_per_second)
    local plate_name = "logistic_plate_tier" .. tier
    local half_size = size_tiles / 2
    local sprite_scale = (size_tiles * 32) / texture_size
  local factoriopedia_description = {
    { "factoriopedia-description.logistic_plate_common_header" },
    { "factoriopedia-description.logistic_plate_common_range", tostring(range_multiplier) },
    { "factoriopedia-description.logistic_plate_common_rate", tostring(items_per_second) },
    { "factoriopedia-description.logistic_plate_common_quality", QUALITY_TRANSFER_MULTIPLIER_TEXT }
  }

    data:extend({
        {
            type = "simple-entity-with-owner",
            name = plate_name,
            icon = "__personal_logistic_plates__/graphics/plates/plate_tier" .. tier .. ".png",
            icon_size = texture_size,
            flags = {"placeable-neutral", "player-creation"},
            minable = {mining_time = 1, result = plate_name},
            max_health = max_health,
            corpse = "small-remnants",
            collision_box = {{-half_size + 0.05, -half_size + 0.05}, {half_size - 0.05, half_size - 0.05}},
            collision_mask = {layers = {object = true}},
            selection_box = {{-half_size, -half_size}, {half_size, half_size}},
            render_layer = "floor",
            picture = {
                filename = "__personal_logistic_plates__/graphics/plates/plate_tier" .. tier .. ".png",
                priority = "high",
                width = texture_size,
                height = texture_size,
                scale = sprite_scale,
                shift = {0, 0}
            }
        }
    })

    data:extend({
        {
            type = "item",
            name = plate_name,
            icon = "__personal_logistic_plates__/graphics/plates/plate_tier" .. tier .. ".png",
            icon_size = texture_size,
            subgroup = "storage",
            order = "a[items]-b[logistic_plate_" .. order_suffix .. "]",
            place_result = plate_name,
      stack_size = 50,
      localised_description = {"factoriopedia-description.logistic_plate_common_header"},
      factoriopedia_description = factoriopedia_description
        }
    })

    data:extend({
        {
            type = "recipe",
            name = plate_name,
            enabled = true,
            ingredients = ingredients,
            results = {
                {type = "item", name = plate_name, amount = 1}
            }
        }
    })
end

make_plate_tier(1, "tier1", 1, 128, 200, {
    {type = "item", name = "iron-plate", amount = 10},
    {type = "item", name = "electronic-circuit", amount = 5}
}, 1, 30)

make_plate_tier(2, "tier2", 2, 192, 300, {
    {type = "item", name = "logistic_plate_tier1", amount = 2},
    {type = "item", name = "steel-plate", amount = 20},
    {type = "item", name = "advanced-circuit", amount = 10}
}, 3, 90)

make_plate_tier(3, "tier3", 3, 256, 400, {
    {type = "item", name = "logistic_plate_tier2", amount = 2},
    {type = "item", name = "processing-unit", amount = 15},
    {type = "item", name = "low-density-structure", amount = 10}
}, 7, 210)
