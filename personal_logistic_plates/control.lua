-- control.lua

-- Define a debug flag
local DEBUG = false

-- Function to print debug messages
local function debug_print(player, message)
    if DEBUG then
        player.print(message)
    end
end

script.on_event(defines.events.on_player_changed_position, function(event)
    local player = game.players[event.player_index]
    local position = player.position
    local surface = player.surface

    -- Get the tile position of the player
    local tile_position = {x = math.floor(position.x), y = math.floor(position.y)}
    
    -- Check if the player is standing on the plate
    local plate = surface.find_entity("logistic_plate_tier1", tile_position)
    
    if plate then
        debug_print(player, "You stepped on the entity!")

        -- Ensure the player has a character before accessing logistic slots
        if player.character then
            -- Create a dictionary of player logistic requests
            local logistic_requests = {}
            for i = 1, player.character.request_slot_count do
                local request = player.get_personal_logistic_slot(i)
                if request and request.name then
                    logistic_requests[request.name] = {
                        min = request.min,
                        max = request.max,
                        remaining = request.min - player.get_item_count(request.name)
                    }
                end
            end

            -- Get the configurable range
            local range = settings.global["logistic_plate_range"].value

            -- Find nearby container-type entities within the configurable range
            local containers = surface.find_entities_filtered{
                type = "container",
                position = position,
                radius = range
            }

            -- Transfer items from containers to player's inventory
            for _, container in pairs(containers) do
                local inventory = container.get_inventory(defines.inventory.chest)
                -- Inventory nil check
                if not inventory then
                    debug_print(player, "No inventory found.")
                    return
                end
                for item_name, item_count in pairs(inventory.get_contents()) do
                    if logistic_requests[item_name] and logistic_requests[item_name].remaining > 0 then
                        local transfer_count = math.min(item_count, logistic_requests[item_name].remaining)
                        local inserted_count = player.insert{name = item_name, count = transfer_count}
                        inventory.remove{name = item_name, count = inserted_count}
                        logistic_requests[item_name].remaining = logistic_requests[item_name].remaining - inserted_count
                    end
                end
            end

            -- List remaining logistic requests
            debug_print(player, "Remaining Logistic Requests:")
            for item_name, request in pairs(logistic_requests) do
                if request.remaining > 0 then
                    debug_print(player, item_name .. ": " .. request.remaining)
                end
            end
        else
            debug_print(player, "No character associated with the player.")
        end
    end
end)