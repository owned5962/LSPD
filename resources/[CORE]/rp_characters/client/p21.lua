    local fallback = { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 }
    if type(coords) ~= 'table' then return fallback end

    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    local heading = tonumber(coords.heading)
    local function finite(value)
        return value ~= nil and value == value and value ~= math.huge and value ~= -math.huge
    end
    if not finite(x) or not finite(y) or not finite(z)
        or x < -6000 or x > 6000 or y < -6000 or y > 6000
        or z < -500 or z > 2000 then
        return fallback
    end
    if not finite(heading) then heading = fallback.heading end
    return { x = x, y = y, z = z, heading = heading % 360 }
end

RegisterNetEvent('rp_characters:client:spawnPlayer', function(coords, gender, skin)
    -- Run the entire transition in a protected thread. A Lua/native error during
    -- skin application, camera teardown or streaming must never strand the
    -- player in a faded-out, frozen state.
    CreateThread(function()
        print('[rp_characters] Spawn pipeline received from server.')
        creationSubmissionPending = false
        characterSessionReady = true
