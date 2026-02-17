local function make_plate_tier(tier, order_suffix, size_tiles, texture_size, max_health, ingredients)
    local plate_name = "logistic_plate_tier" .. tier
    local half_size = size_tiles / 2
    local sprite_scale = (size_tiles * 32) / texture_size

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
            stack_size = 50
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
})

make_plate_tier(2, "tier2", 2, 192, 300, {
    {type = "item", name = "logistic_plate_tier1", amount = 2},
    {type = "item", name = "steel-plate", amount = 20},
    {type = "item", name = "advanced-circuit", amount = 10}
})

make_plate_tier(3, "tier3", 3, 256, 400, {
    {type = "item", name = "logistic_plate_tier2", amount = 2},
    {type = "item", name = "processing-unit", amount = 15},
    {type = "item", name = "low-density-structure", amount = 10}
})