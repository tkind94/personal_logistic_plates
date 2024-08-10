data:extend({
    {
      type = "simple-entity-with-owner",
      name = "logistic_plate_tier1",
      icon = "__base__/graphics/icons/wooden-chest.png",  -- Placeholder icon
      icon_size = 64,
      minable = {mining_time = 1, result = "logistic_plate_tier1"},
      max_health = 200,
      corpse = "small-remnants",
      collision_mask = {},  -- Make the entity completely non-collidable
      selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
      picture = {
        filename = "__base__/graphics/entity/wooden-chest/wooden-chest.png",  -- Placeholder entity graphic
        priority = "high",
        width = 32,
        height = 36
      }
    }
})

data:extend({
  {
    type = "item",
    name = "logistic_plate_tier1",
    icon = "__base__/graphics/icons/wooden-chest.png",  -- Placeholder icon
    icon_size = 64,
    subgroup = "storage",
    order = "a[items]-b[logistic_plate_tier1]",
    place_result = "logistic_plate_tier1",
    stack_size = 50
  }
})

data:extend({
  {
    type = "recipe",
    name = "logistic_plate_tier1",
    enabled = true,
    ingredients = {
      {"iron-plate", 10},
      {"electronic-circuit", 5}
    },
    result = "logistic_plate_tier1"
  }
})