local config = require("config")

-- Constants
local UPDATE_INTERVAL_TICKS = 6
local UPDATES_PER_SECOND = 60 / UPDATE_INTERVAL_TICKS
local CONTAINER_CACHE_TTL = 60
local MAX_TRANSFER_EFFECTS = 96
local EFFECT_DURATION_TICKS = 16

local CONTAINER_TYPES = {
    "container", "logistic-container", "infinity-container",
    "linked-container", "cargo-wagon"
}

-- Derive plate search radius from largest tier
local PLATE_SEARCH_RADIUS = 0
for _, tier in ipairs(config.TIERS) do
    local half = tier.size_tiles / 2
    if half > PLATE_SEARCH_RADIUS then PLATE_SEARCH_RADIUS = half end
end
PLATE_SEARCH_RADIUS = PLATE_SEARCH_RADIUS + 0.3

-- Build entity event filter from config
local PLATE_EVENT_FILTER = {}
for _, tier in ipairs(config.TIERS) do
    PLATE_EVENT_FILTER[#PLATE_EVENT_FILTER + 1] = {filter = "name", name = tier.name}
end

--------------------------------------------------------------------------------
-- Storage
--------------------------------------------------------------------------------

local function init_storage()
    storage.plate_state = storage.plate_state or {}
    storage.container_cache = storage.container_cache or {}
    storage.effects = storage.effects or {}
end

--------------------------------------------------------------------------------
-- Quality
--------------------------------------------------------------------------------

local function quality_multiplier(quality_name)
    if not quality_name then return 1.0 end
    local proto = prototypes.quality[quality_name]
    return proto and config.quality_multiplier(proto.level or 0) or 1.0
end

--------------------------------------------------------------------------------
-- Logistic requests
--------------------------------------------------------------------------------

local function collect_requests(player)
    local by_item = {}
    local has_any = false

    local function add_point(point, inv)
        if not point or not point.filters then return end
        for _, f in ipairs(point.filters) do
            if f.name and f.count and f.count > 0 then
                local query = {name = f.name}
                if f.quality then query.quality = f.quality end
                local remaining = f.count - inv.get_item_count(query)
                if remaining > 0 then
                    if not by_item[f.name] then by_item[f.name] = {} end
                    by_item[f.name][#by_item[f.name] + 1] = {
                        quality = f.quality,
                        remaining = remaining,
                        inv = inv -- target inventory
                    }
                    has_any = true
                end
            end
        end
    end

    local player_inv = player.get_inventory(defines.inventory.character_main)
    if player_inv then
        add_point(player.get_requester_point(), player_inv)
    end

    if player.vehicle then
        local vehicle_inv = player.vehicle.get_inventory(defines.inventory.car_trunk) or player.vehicle.get_inventory(defines.inventory.spider_trunk)
        if vehicle_inv then
            add_point(player.vehicle.get_requester_point(), vehicle_inv)
        end
    end

    return has_any and by_item or nil
end

--------------------------------------------------------------------------------
-- Plate detection
--------------------------------------------------------------------------------

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

local function update_plate_state(player)
    local state = storage.plate_state[player.index]
    if state and state.plate and state.plate.valid then
        if position_in_box(player.physical_position, state.plate.bounding_box) then
            return
        end
    end

    local plate = find_plate_at(player.physical_surface, player.physical_position)
    storage.plate_state[player.index] = plate and {plate = plate} or nil
end

--------------------------------------------------------------------------------
-- Container cache
--------------------------------------------------------------------------------

local function get_containers(plate, range, tick)
    local id = plate.unit_number
    if not id then return {} end

    local entry = storage.container_cache[id]
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
        storage.container_cache[id] = entry
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

--------------------------------------------------------------------------------
-- Transfer effects
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- Core transfer
--------------------------------------------------------------------------------

local function transfer_to_player(player, pos, containers, requests, budget_ref)
    for _, container in ipairs(containers) do
        if budget_ref.val <= 0 then break end

        local inventory = container.get_inventory(defines.inventory.chest) or container.get_inventory(defines.inventory.car_trunk)
        if not inventory then goto next_container end

        for _, stack in ipairs(inventory.get_contents()) do
            if budget_ref.val <= 0 then break end
            if not stack.name or stack.count <= 0 then goto next_stack end

            local item_requests = requests[stack.name]
            if not item_requests then goto next_stack end

            local available = stack.count
            for _, req in ipairs(item_requests) do
                if budget_ref.val <= 0 or available <= 0 then break end
                if req.remaining <= 0 then goto next_req end
                if req.quality ~= nil and req.quality ~= stack.quality then goto next_req end

                local qm = quality_multiplier(stack.quality)
                local count = math.min(available, req.remaining, math.ceil(budget_ref.val * qm))
                local inserted = req.inv.insert{name = stack.name, quality = stack.quality, count = count}
                if inserted > 0 then
                    inventory.remove{name = stack.name, quality = stack.quality, count = inserted}
                    available = available - inserted
                    req.remaining = req.remaining - inserted
                    budget_ref.val = budget_ref.val - inserted / qm
                    spawn_effect(container.surface, container.position, pos, stack.name, inserted)
                end

                ::next_req::
            end
            ::next_stack::
        end
        ::next_container::
    end
end

local function transfer_from_player(player, pos, plate, containers, requests, budget_ref)
    local invs_to_check = {}
    
    local player_inv = player.get_inventory(defines.inventory.character_main)
    local player_trash = player.get_inventory(defines.inventory.character_trash)
    
    if player_trash and not player_trash.is_empty() then
        invs_to_check[#invs_to_check+1] = player_trash
    end
    
    if player.vehicle then
        local vehicle_trash = player.vehicle.get_inventory(defines.inventory.car_trash) or player.vehicle.get_inventory(defines.inventory.spider_trash)
        if vehicle_trash and not vehicle_trash.is_empty() then
            invs_to_check[#invs_to_check+1] = vehicle_trash
        end
    end
    
    if #invs_to_check == 0 then return end

    for pass = 1, 2 do
        for _, container in ipairs(containers) do
            if budget_ref.val <= 0 then return end
            
            if pass == 1 then
                -- Pass 1: only touching containers
                local bb1 = container.bounding_box
                local bb2 = plate.bounding_box
                -- Add 0.5 padding because collision boxes of adjacent entities have a small gap between them
                local is_touching = (bb1.left_top.x <= bb2.right_bottom.x + 0.5 and bb1.right_bottom.x >= bb2.left_top.x - 0.5 and
                                     bb1.left_top.y <= bb2.right_bottom.y + 0.5 and bb1.right_bottom.y >= bb2.left_top.y - 0.5)
                if not is_touching then goto next_container end
            else
                -- Pass 2: Active Provider chests in full radius
                if container.prototype.type ~= "logistic-container" or container.prototype.logistic_mode ~= "active-provider" then
                    goto next_container
                end
            end
            
            local target_inv = container.get_inventory(defines.inventory.chest) or container.get_inventory(defines.inventory.cargo_wagon)
            if not target_inv then goto next_container end

            for _, source_inv in ipairs(invs_to_check) do
                if budget_ref.val <= 0 then return end
                
                for i = 1, #source_inv do
                    if budget_ref.val <= 0 then return end
                    
                    local stack = source_inv[i]
                    if stack.valid_for_read and stack.count > 0 then
                        local item_name = stack.name
                        local item_quality = stack.quality
                        local inserted = target_inv.insert({name = item_name, quality = item_quality, count = math.min(stack.count, math.ceil(budget_ref.val))})
                        if inserted > 0 then
                            source_inv.remove({name = item_name, quality = item_quality, count = inserted})
                            budget_ref.val = budget_ref.val - inserted
                            spawn_effect(container.surface, pos, container.position, item_name, inserted)
                        end
                    end
                end
            end

            ::next_container::
        end
    end
end

local function transfer_for_player(player, tick)
    if not player.character then return end

    local state = storage.plate_state[player.index]
    if not state then return end

    local plate = state.plate
    if not plate or not plate.valid then
        storage.plate_state[player.index] = nil
        return
    end

    local pos = player.physical_position
    if not position_in_box(pos, plate.bounding_box) then
        storage.plate_state[player.index] = nil
        return
    end

    local tier = config.TIER_BY_NAME[plate.name]
    if not tier then return end

    local requests = collect_requests(player)
    local base_range = tonumber(settings.startup["logistic_plate_range"].value) or 10
    local containers = get_containers(plate, base_range * tier.range_multiplier, tick)
    
    local budget_ref = {val = tier.items_per_second / UPDATES_PER_SECOND}

    if requests then
        transfer_to_player(player, pos, containers, requests, budget_ref)
    end
    if budget_ref.val > 0 then
        transfer_from_player(player, pos, plate, containers, requests, budget_ref)
    end
end

--------------------------------------------------------------------------------
-- Entity removal
--------------------------------------------------------------------------------

local function on_entity_removed(event)
    local entity = event.entity

    if entity.unit_number then
        storage.container_cache[entity.unit_number] = nil
    end

    for idx, state in pairs(storage.plate_state) do
        if state.plate == entity then
            storage.plate_state[idx] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- Event registration
--------------------------------------------------------------------------------

script.on_init(init_storage)
script.on_configuration_changed(function(e)
    init_storage()
    for _, force in pairs(game.forces) do
        force.reset_recipes()
    end
end)

script.on_event(defines.events.on_player_joined_game, function(e)
    local player = game.get_player(e.player_index)
    if player then update_plate_state(player) end
end)

script.on_event(defines.events.on_player_changed_position, function(e)
    local player = game.get_player(e.player_index)
    if player then update_plate_state(player) end
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
        transfer_for_player(player, e.tick)
    end
end)
