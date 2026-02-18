local config = require("config")

if not data.raw.quality then return end

for _, tier in ipairs(config.TIERS) do
    local item = data.raw.item[tier.name]
    if item and item.custom_tooltip_fields then
        local rate_field = item.custom_tooltip_fields[2]
        for _, quality in pairs(data.raw.quality) do
            local rate = math.floor(tier.items_per_second * config.quality_multiplier(quality.level or 0) + 0.5)
            rate_field.quality_values[quality.name] = {"plp.tooltip-transfer-rate-value", tostring(rate)}
        end
    end
end
