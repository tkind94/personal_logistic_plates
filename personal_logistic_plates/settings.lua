-- settings.lua

data:extend({
    {
        type = "int-setting",
        name = "logistic_plate_range",
        setting_type = "runtime-global",
        default_value = 10,
        minimum_value = 1,
        maximum_value = 100,
        order = "a"
    }
})
