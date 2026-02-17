-- control.lua

local LOG_PREFIX = "[personal_logistic_plates]"
local DEBUG_LOGGING = false
local UPDATE_INTERVAL_TICKS = 6
local UPDATES_PER_SECOND = 60 / UPDATE_INTERVAL_TICKS
local CONTAINER_CACHE_REFRESH_TICKS = 60
local MAX_ACTIVE_EFFECTS = 96
local EFFECT_DURATION_TICKS = 16

local TIER_CONFIG = {
    logistic_plate_tier1 = {range_multiplier = 1.0, items_per_second = 30},
    logistic_plate_tier2 = {range_multiplier = 2.0, items_per_second = 90},
    logistic_plate_tier3 = {range_multiplier = 3.0, items_per_second = 180}
}

local PLATE_NAMES = {
    "logistic_plate_tier1",
    "logistic_plate_tier2",
    "logistic_plate_tier3"
}

local PLATE_NAME_SET = {
    logistic_plate_tier1 = true,
    logistic_plate_tier2 = true,
    logistic_plate_tier3 = true
}

local CONTAINER_TYPES = {
    "container",
    "logistic-container",
    "infinity-container",
    "linked-container",
    "cargo-wagon"
}

local function mod_log(message)
    if DEBUG_LOGGING then
        log(LOG_PREFIX .. " " .. tostring(message))
    end
end

local function ensure_storage()
    storage.player_plate_state = storage.player_plate_state or {}
    storage.plate_container_cache = storage.plate_container_cache or {}
    storage.transfer_effects = storage.transfer_effects or {}
end

local function collect_logistic_requests(player)
    local requester_point = player.get_requester_point()
    if not requester_point then
        return {}
    end

    local filters = requester_point.filters
    if not filters then
        return {}
    end

    local requests_by_item = {}

    for _, filter in ipairs(filters) do
        if filter.name and filter.count and filter.count > 0 then
            local requested_item = {name = filter.name}
            if filter.quality then
                requested_item.quality = filter.quality
            end

            local current_count = player.get_item_count(requested_item)
            local remaining = filter.count - current_count

            if remaining > 0 then
                if not requests_by_item[filter.name] then
                    requests_by_item[filter.name] = {}
                end

                requests_by_item[filter.name][#requests_by_item[filter.name] + 1] = {
                    quality = filter.quality,
                    min = filter.count,
                    max = filter.max_count,
                    remaining = remaining
                }
            end
        end
    end

    return requests_by_item
end

local function read_content_entry(key, value)
    if type(value) == "table" then
        if value.name and value.count then
            return value.name, value.quality, value.count
        end
    elseif type(key) == "table" and type(value) == "number" then
        if key.name then
            return key.name, key.quality, value
        end
    elseif type(key) == "string" and type(value) == "number" then
        return key, nil, value
    end

    return nil, nil, nil
end

local function count_pending_requests(logistic_requests)
    local pending = 0

    for _, requests_for_item in pairs(logistic_requests) do
        for _, request in ipairs(requests_for_item) do
            if request.remaining > 0 then
                pending = pending + 1
            end
        end
    end

    return pending
end

local function is_position_in_plate(position, plate)
    local box = plate.bounding_box
    return
        position.x >= box.left_top.x and
        position.x <= box.right_bottom.x and
        position.y >= box.left_top.y and
        position.y <= box.right_bottom.y
end

local function get_plate_under_player(surface, position)
    local plates = surface.find_entities_filtered{
        name = PLATE_NAMES,
        position = position,
        radius = 1.8
    }

    local nearest_plate = nil
    local nearest_distance_sq = nil

    for _, plate in ipairs(plates) do
        if is_position_in_plate(position, plate) then
            local dx = plate.position.x - position.x
            local dy = plate.position.y - position.y
            local distance_sq = dx * dx + dy * dy

            if not nearest_distance_sq or distance_sq < nearest_distance_sq then
                nearest_distance_sq = distance_sq
                nearest_plate = plate
            end
        end
    end

    return nearest_plate
end

local function update_player_plate_state(player)
    if not player or not player.valid then
        return
    end

    local state = storage.player_plate_state[player.index]
    if state and state.plate and state.plate.valid then
        if is_position_in_plate(player.physical_position, state.plate) then
            return
        end
    end

    local plate = get_plate_under_player(player.physical_surface, player.physical_position)
    if plate then
        storage.player_plate_state[player.index] = {plate = plate}
    else
        storage.player_plate_state[player.index] = nil
    end
end

local function get_transfer_range(plate_name)
    local base_range = tonumber(settings.global["logistic_plate_range"].value) or 10
    local multiplier = (TIER_CONFIG[plate_name] and TIER_CONFIG[plate_name].range_multiplier) or 1.0
    return base_range * multiplier
end

local function get_item_budget(plate_name)
    local config = TIER_CONFIG[plate_name]
    if not config then
        return 0
    end

    return math.floor(config.items_per_second / UPDATES_PER_SECOND)
end

local function get_cached_containers(plate, range, tick)
    local unit_number = plate.unit_number
    if not unit_number then
        return {}
    end

    local cache_entry = storage.plate_container_cache[unit_number]
    local must_refresh =
        (not cache_entry) or
        (cache_entry.range ~= range) or
        (tick - cache_entry.last_refresh_tick >= CONTAINER_CACHE_REFRESH_TICKS)

    if must_refresh then
        cache_entry = {
            last_refresh_tick = tick,
            range = range,
            containers = plate.surface.find_entities_filtered{
                type = CONTAINER_TYPES,
                position = plate.position,
                radius = range
            }
        }
        storage.plate_container_cache[unit_number] = cache_entry
    end

    local valid_containers = {}
    for _, container in ipairs(cache_entry.containers) do
        if container.valid then
            valid_containers[#valid_containers + 1] = container
        end
    end

    cache_entry.containers = valid_containers
    return valid_containers
end

local function spawn_transfer_effect(surface, from_position, to_position, item_name, inserted_count)
    if #storage.transfer_effects >= MAX_ACTIVE_EFFECTS then
        return
    end

    local effect_count = math.min(3, math.max(1, math.ceil(inserted_count / 20)))

    for _ = 1, effect_count do
        if #storage.transfer_effects >= MAX_ACTIVE_EFFECTS then
            break
        end

        storage.transfer_effects[#storage.transfer_effects + 1] = {
            surface_index = surface.index,
            sprite = "item/" .. item_name,
            from_x = from_position.x + (math.random() - 0.5) * 0.35,
            from_y = from_position.y + (math.random() - 0.5) * 0.35,
            to_x = to_position.x + (math.random() - 0.5) * 0.12,
            to_y = to_position.y + (math.random() - 0.5) * 0.12,
            offset_x = (math.random() - 0.5) * 0.25,
            offset_y = (math.random() - 0.5) * 0.25,
            age = 0,
            duration = EFFECT_DURATION_TICKS,
            scale = 0.45 + math.random() * 0.12
        }
    end
end

local function update_transfer_effects()
    local effects = storage.transfer_effects
    if #effects == 0 then
        return
    end

    local write_index = 1

    for _, effect in ipairs(effects) do
        effect.age = effect.age + 1

        if effect.age <= effect.duration then
            local surface = game.surfaces[effect.surface_index]
            if surface then
                local t = effect.age / effect.duration
                local inv_t = 1 - t
                local x = effect.from_x + (effect.to_x - effect.from_x) * t + effect.offset_x * inv_t
                local y = effect.from_y + (effect.to_y - effect.from_y) * t + effect.offset_y * inv_t

                rendering.draw_sprite{
                    sprite = effect.sprite,
                    surface = surface,
                    target = {x = x, y = y},
                    x_scale = effect.scale,
                    y_scale = effect.scale,
                    tint = {r = 1, g = 1, b = 1, a = 0.95},
                    render_layer = "air-object",
                    time_to_live = 2
                }

                rendering.draw_light{
                    sprite = "utility/light_medium",
                    surface = surface,
                    target = {x = x, y = y},
                    scale = 0.25,
                    intensity = 0.5,
                    color = {r = 0.3, g = 0.9, b = 1.0},
                    time_to_live = 2
                }
            end

            effects[write_index] = effect
            write_index = write_index + 1
        end
    end

    for index = write_index, #effects do
        effects[index] = nil
    end
end

local function clear_plate_cache(plate)
    if plate and plate.valid and plate.unit_number then
        storage.plate_container_cache[plate.unit_number] = nil
    end
end

local function clear_player_plate_if_matches(plate)
    if not plate or not plate.valid then
        return
    end

    for player_index, state in pairs(storage.player_plate_state) do
        if state.plate == plate then
            storage.player_plate_state[player_index] = nil
        end
    end
end

local function transfer_for_player(player, tick)
    if not player or not player.valid then
        return
    end

    local character = player.character
    if not character then
        return
    end

    local state = storage.player_plate_state[player.index]
    if not state then
        return
    end

    local plate = state.plate
    if not plate or not plate.valid then
        storage.player_plate_state[player.index] = nil
        return
    end

    local position = player.physical_position
    if not is_position_in_plate(position, plate) then
        storage.player_plate_state[player.index] = nil
        return
    end

    mod_log(string.format("plate detected name=%s", plate.name))

    local item_budget = get_item_budget(plate.name)
    if item_budget <= 0 then
        return
    end

    local logistic_requests = collect_logistic_requests(player)
    local pending_before = count_pending_requests(logistic_requests)

    if pending_before == 0 then
        return
    end

    local range = get_transfer_range(plate.name)
    local containers = get_cached_containers(plate, range, tick)

    local total_inserted = 0

    for _, container in ipairs(containers) do
        if item_budget <= 0 then
            break
        end

        local inventory = container.get_inventory(defines.inventory.chest)
        if inventory then
            local contents = inventory.get_contents()

            for key, value in pairs(contents) do
                if item_budget <= 0 then
                    break
                end

                local item_name, item_quality, item_count = read_content_entry(key, value)

                if item_name and item_count and item_count > 0 then
                    local requests_for_item = logistic_requests[item_name]
                    if requests_for_item then
                        for _, request in ipairs(requests_for_item) do
                            if item_budget <= 0 then
                                break
                            end

                            local quality_matches = request.quality == nil or request.quality == item_quality

                            if quality_matches and request.remaining > 0 then
                                local transfer_count = math.min(item_count, request.remaining, item_budget)
                                local inserted_count = player.insert{
                                    name = item_name,
                                    quality = item_quality,
                                    count = transfer_count
                                }

                                if inserted_count > 0 then
                                    inventory.remove{
                                        name = item_name,
                                        quality = item_quality,
                                        count = inserted_count
                                    }

                                    item_count = item_count - inserted_count
                                    request.remaining = request.remaining - inserted_count
                                    total_inserted = total_inserted + inserted_count
                                    item_budget = item_budget - inserted_count

                                    spawn_transfer_effect(plate.surface, container.position, position, item_name, inserted_count)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local pending_after = count_pending_requests(logistic_requests)
    mod_log(string.format("transfer summary plate=%s range=%.2f inserted_total=%d pending_before=%d pending_after=%d", plate.name, range, total_inserted, pending_before, pending_after))
end

local function on_plate_related_removed(entity)
    if not entity or not entity.valid then
        return
    end

    if PLATE_NAME_SET[entity.name] then
        clear_plate_cache(entity)
        clear_player_plate_if_matches(entity)
    end
end

script.on_init(function()
    ensure_storage()
end)

script.on_configuration_changed(function(_)
    ensure_storage()
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    ensure_storage()
    local player = game.get_player(event.player_index)
    if player then
        update_player_plate_state(player)
    end
end)

script.on_event(defines.events.on_player_changed_position, function(event)
    ensure_storage()
    local player = game.get_player(event.player_index)
    if player then
        update_player_plate_state(player)
    end
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    ensure_storage()
    on_plate_related_removed(event.entity)
end)

script.on_event(defines.events.on_robot_mined_entity, function(event)
    ensure_storage()
    on_plate_related_removed(event.entity)
end)

script.on_event(defines.events.on_entity_died, function(event)
    ensure_storage()
    on_plate_related_removed(event.entity)
end)

script.on_event(defines.events.script_raised_destroy, function(event)
    ensure_storage()
    on_plate_related_removed(event.entity)
end)

script.on_event(defines.events.on_player_removed, function(event)
    ensure_storage()
    storage.player_plate_state[event.player_index] = nil
end)

script.on_event(defines.events.on_tick, function(_)
    ensure_storage()
    update_transfer_effects()
end)

script.on_nth_tick(UPDATE_INTERVAL_TICKS, function(event)
    ensure_storage()
    for _, player in pairs(game.connected_players) do
        transfer_for_player(player, event.tick)
    end
end)
