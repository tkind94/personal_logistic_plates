local config = require("config")

local UPDATE_INTERVAL_TICKS = 6
local UPDATES_PER_SECOND = 60 / UPDATE_INTERVAL_TICKS
local CONTAINER_CACHE_TTL = 60
local MAX_TRANSFER_EFFECTS = 96
local EFFECT_DURATION_TICKS = 16

local CONTAINER_TYPES = {
    "container", "logistic-container", "infinity-container", "linked-container"
}

local PLATE_SEARCH_RADIUS = 0
for _, tier in ipairs(config.TIERS) do
    local half = tier.size_tiles / 2
    if half > PLATE_SEARCH_RADIUS then PLATE_SEARCH_RADIUS = half end
end
PLATE_SEARCH_RADIUS = PLATE_SEARCH_RADIUS + 0.3

local PLATE_EVENT_FILTER = {}
for _, tier in ipairs(config.TIERS) do
    PLATE_EVENT_FILTER[#PLATE_EVENT_FILTER + 1] = {filter = "name", name = tier.name}
end

local function init_storage()
    storage.plate_state = storage.plate_state or {}
    storage.container_cache = storage.container_cache or {}
    storage.effects = storage.effects or {}
end

local function collect_requests(player)
    local by_item = {}
    local has_any = false

    local function add_point(point, inv)
        for _, f in ipairs(point.filters) do
            if f.name and f.count and f.count > 0 then
                local query = {name = f.name}
                if f.quality then query.quality = f.quality end
                local remaining = f.count - inv.get_item_count(query)
                if remaining > 0 then
                    by_item[f.name] = by_item[f.name] or {}
                    by_item[f.name][#by_item[f.name] + 1] = {
                        quality = f.quality,
                        remaining = remaining,
                        inv = inv
                    }
                    has_any = true
                end
            end
        end
    end

    local player_inv = player.get_inventory(defines.inventory.character_main)
    local point = player.get_requester_point()
    if player_inv and point and point.filters then
        add_point(point, player_inv)
    end

    if player.vehicle then
        local vehicle_inv = player.vehicle.get_inventory(defines.inventory.car_trunk) or player.vehicle.get_inventory(defines.inventory.spider_trunk)
        local vehicle_point = player.vehicle.get_requester_point()
        if vehicle_inv and vehicle_point and vehicle_point.filters then
            add_point(vehicle_point, vehicle_inv)
        end
    end

    return has_any and by_item or nil
end

local function get_trash_inventories(player)
    local invs = {}
    local player_trash = player.get_inventory(defines.inventory.character_trash)
    if player_trash and not player_trash.is_empty() then
        invs[#invs+1] = player_trash
    end
    
    if player.vehicle then
        local vehicle_trash = player.vehicle.get_inventory(defines.inventory.car_trash) or player.vehicle.get_inventory(defines.inventory.spider_trash)
        if vehicle_trash and not vehicle_trash.is_empty() then
            invs[#invs+1] = vehicle_trash
        end
    end
    return invs
end

local function position_in_box(pos, box)
    return pos.x >= box.left_top.x and pos.x <= box.right_bottom.x
       and pos.y >= box.left_top.y and pos.y <= box.right_bottom.y
end

local function find_plate_at(surface, position)
    local plates = surface.find_entities_filtered{
        name = config.PLATE_NAMES,
        position = position,
        radius = PLATE_SEARCH_RADIUS
    }

    local best, best_dist = nil, math.huge
    for _, plate in ipairs(plates) do
        if position_in_box(position, plate.bounding_box) then
            local dx = plate.position.x - position.x
            local dy = plate.position.y - position.y
            local dist = dx * dx + dy * dy
            if dist < best_dist then
                best, best_dist = plate, dist
            end
        end
    end

    return best
end

local function get_containers(plate, range, tick)
    local entry = storage.container_cache[plate.unit_number]
    if not entry or entry.range ~= range or (tick - entry.tick) >= CONTAINER_CACHE_TTL then
        entry = {
            tick = tick,
            range = range,
            list = plate.surface.find_entities_filtered{
                type = CONTAINER_TYPES,
                position = plate.position,
                radius = range
            }
        }
        storage.container_cache[plate.unit_number] = entry
    end

    local write = 1
    for i = 1, #entry.list do
        if entry.list[i].valid then
            entry.list[write] = entry.list[i]
            write = write + 1
        end
    end
    for i = write, #entry.list do entry.list[i] = nil end

    return entry.list
end

local function spawn_effect(surface, from, to, item_name, count)
    local fx = storage.effects
    if #fx >= MAX_TRANSFER_EFFECTS then return end

    local n = math.min(3, math.ceil(count / 20))
    for _ = 1, n do
        if #fx >= MAX_TRANSFER_EFFECTS then return end
        fx[#fx + 1] = {
            surface_index = surface.index,
            sprite = "item/" .. item_name,
            from_x = from.x + (math.random() - 0.5) * 0.35,
            from_y = from.y + (math.random() - 0.5) * 0.35,
            to_x   = to.x   + (math.random() - 0.5) * 0.12,
            to_y   = to.y   + (math.random() - 0.5) * 0.12,
            offset_x = (math.random() - 0.5) * 0.25,
            offset_y = (math.random() - 0.5) * 0.25,
            age = 0,
            duration = EFFECT_DURATION_TICKS,
            scale = 0.45 + math.random() * 0.12
        }
    end
end

local function tick_effects()
    local fx = storage.effects
    if #fx == 0 then return end

    local write = 1
    for _, e in ipairs(fx) do
        e.age = e.age + 1
        if e.age <= e.duration then
            local surface = game.surfaces[e.surface_index]
            if surface then
                local t = e.age / e.duration
                local x = e.from_x + (e.to_x - e.from_x) * t + e.offset_x * (1 - t)
                local y = e.from_y + (e.to_y - e.from_y) * t + e.offset_y * (1 - t)

                rendering.draw_sprite{
                    sprite = e.sprite, surface = surface,
                    target = {x = x, y = y},
                    x_scale = e.scale, y_scale = e.scale,
                    tint = {r = 1, g = 1, b = 1, a = 0.95},
                    render_layer = "air-object", time_to_live = 2
                }
                rendering.draw_light{
                    sprite = "utility/light_medium", surface = surface,
                    target = {x = x, y = y},
                    scale = 0.25, intensity = 0.5,
                    color = {r = 0.3, g = 0.9, b = 1.0},
                    time_to_live = 2
                }
            end
            fx[write] = e
            write = write + 1
        end
    end
    for i = write, #fx do fx[i] = nil end
end

local function process_request(inventory, stack, req, available, budget, container, target_pos)
    if req.remaining <= 0 then return available, budget end
    if req.quality ~= nil and req.quality ~= stack.quality then return available, budget end

    local count = math.min(available, req.remaining, math.ceil(budget))
    if count <= 0 then return available, budget end

    local inserted = req.inv.insert{name = stack.name, quality = stack.quality, count = count}
    if inserted > 0 then
        inventory.remove{name = stack.name, quality = stack.quality, count = inserted}
        req.remaining = req.remaining - inserted
        spawn_effect(container.surface, container.position, target_pos, stack.name, inserted)
        return available - inserted, budget - inserted
    end
    
    return available, budget
end

local function transfer_stack_to_player(inventory, stack, requests, budget, container, target_pos)
    local item_requests = requests[stack.name]
    if not item_requests then return budget end

    local available = stack.count
    for _, req in ipairs(item_requests) do
        if budget <= 0 or available <= 0 then break end
        available, budget = process_request(inventory, stack, req, available, budget, container, target_pos)
    end
    
    return budget
end

local function transfer_to_player(pos, containers, requests, budget)
    for _, container in ipairs(containers) do
        if budget <= 0 then break end
        local inventory = container.get_inventory(defines.inventory.chest) or container.get_inventory(defines.inventory.car_trunk)
        if inventory then
            for _, stack in ipairs(inventory.get_contents()) do
                if budget <= 0 then break end
                budget = transfer_stack_to_player(inventory, stack, requests, budget, container, pos)
            end
        end
    end
    return budget
end

local function deposit_trash_stack(target_inv, source_inv, index, pos, container, budget)
    local stack = source_inv[index]
    if not stack.valid_for_read or stack.count <= 0 then return budget end

    local item_name = stack.name
    local item_quality = stack.quality.name
    local count = math.min(stack.count, math.ceil(budget))
    if count <= 0 then return budget end

    local inserted = target_inv.insert({name = item_name, quality = item_quality, count = count})
    if inserted > 0 then
        source_inv.remove({name = item_name, quality = item_quality, count = inserted})
        spawn_effect(container.surface, pos, container.position, item_name, inserted)
        return budget - inserted
    end
    return budget
end

local function deposit_trash_to_container(container, trash_invs, pos, budget)
    local target_inv = container.get_inventory(defines.inventory.chest)
    if not target_inv then return budget end

    for _, source_inv in ipairs(trash_invs) do
        if budget <= 0 then return budget end
        for i = 1, #source_inv do
            if budget <= 0 then return budget end
            budget = deposit_trash_stack(target_inv, source_inv, i, pos, container, budget)
        end
    end
    return budget
end

local function is_touching(bb1, bb2)
    return bb1.left_top.x <= bb2.right_bottom.x + 0.5 and bb1.right_bottom.x >= bb2.left_top.x - 0.5 and
           bb1.left_top.y <= bb2.right_bottom.y + 0.5 and bb1.right_bottom.y >= bb2.left_top.y - 0.5
end

local function transfer_from_player(pos, plate, containers, trash_invs, budget)
    for _, container in ipairs(containers) do
        if budget <= 0 then return budget end
        if is_touching(container.bounding_box, plate.bounding_box) then
            budget = deposit_trash_to_container(container, trash_invs, pos, budget)
        end
    end

    for _, container in ipairs(containers) do
        if budget <= 0 then return budget end
        if container.prototype.type == "logistic-container" and container.prototype.logistic_mode == "active-provider" then
            budget = deposit_trash_to_container(container, trash_invs, pos, budget)
        end
    end

    return budget
end

local function transfer_for_player(player, tick)
    local state = storage.plate_state[player.index]
    local pos = player.physical_position

    if state and state.plate and state.plate.valid then
        if not position_in_box(pos, state.plate.bounding_box) then
            state = nil
            storage.plate_state[player.index] = nil
        end
    else
        state = nil
        storage.plate_state[player.index] = nil
    end

    if not state then
        local plate = find_plate_at(player.physical_surface, pos)
        if plate then
            state = {plate = plate}
            storage.plate_state[player.index] = state
        end
    end

    if not state then return end

    local tier = config.TIER_BY_NAME[state.plate.name]
    local requests = collect_requests(player)
    local trash_invs = get_trash_inventories(player)
    
    if not requests and #trash_invs == 0 then return end

    local base_range = settings.startup["logistic_plate_range"].value
    local containers = get_containers(state.plate, base_range * tier.range_multiplier, tick)
    local qm = config.quality_multiplier(state.plate.quality.level)
    local budget = (tier.items_per_second / UPDATES_PER_SECOND) * qm

    if requests then
        budget = transfer_to_player(pos, containers, requests, budget)
    end
    if budget > 0 and #trash_invs > 0 then
        budget = transfer_from_player(pos, state.plate, containers, trash_invs, budget)
    end
end

local function on_entity_removed(event)
    local entity = event.entity
    storage.container_cache[entity.unit_number] = nil

    for idx, state in pairs(storage.plate_state) do
        if state.plate == entity then
            storage.plate_state[idx] = nil
        end
    end
end

script.on_init(init_storage)
script.on_configuration_changed(function(e)
    init_storage()
    for _, force in pairs(game.forces) do
        force.reset_recipes()
    end
end)

script.on_event(defines.events.on_player_removed, function(e)
    storage.plate_state[e.player_index] = nil
end)

script.on_event(defines.events.on_player_mined_entity, on_entity_removed, PLATE_EVENT_FILTER)
script.on_event(defines.events.on_robot_mined_entity, on_entity_removed, PLATE_EVENT_FILTER)
script.on_event(defines.events.on_entity_died, on_entity_removed, PLATE_EVENT_FILTER)
script.on_event(defines.events.script_raised_destroy, on_entity_removed, PLATE_EVENT_FILTER)

script.on_event(defines.events.on_tick, tick_effects)

script.on_nth_tick(UPDATE_INTERVAL_TICKS, function(e)
    for _, player in pairs(game.connected_players) do
        if player.character then
            transfer_for_player(player, e.tick)
        end
    end
end)
