        print('[rp_characters] Character selector preview model could not be loaded; keeping current ped visible.')
    end
    ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, true)
    end

    SetupCreatorCamera()
    if IsScreenFadedOut() then DoScreenFadeIn(700) end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCharacterSelection', characters = characters, maxCharacters = maxCharacters or 3 })
end)

RegisterNetEvent('rp_characters:client:bootError', function(message)
    -- A boot/load failure can also occur after the initial menu has opened.
    -- Do not silently discard it just because the first boot timer has ended.
    ShowCharacterBootError(message)
end)

RegisterNetEvent('rp_characters:client:closeMenu', function()
    CloseCharacterUI()
end)

local SPAWN_TIMER_MODULUS = 4294967296

local function SpawnWaitExpired(startedAt, duration)
    return ((GetGameTimer() % SPAWN_TIMER_MODULUS) - startedAt) % SPAWN_TIMER_MODULUS >= duration
end

local function NormalizeClientSpawn(coords)
