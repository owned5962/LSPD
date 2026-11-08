local isCreating = false
local charCamera = nil

function OpenCharacterRegistration()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openRegistration",
        spawns = {
            { id = "airport", name = "Aéroport International LS", coords = { x = -1037.7, y = -2737.8, z = 20.1, heading = 330.0 } },
            { id = "train", name = "Gare Centrale (Union Station)", coords = { x = 432.2, y = -626.8, z = 28.5, heading = 220.0 } },
            { id = "hospital", name = "Place Pillbox Hill", coords = { x = 298.5, y = -584.5, z = 43.2, heading = 70.0 } },
            { id = "jobcenter", name = "Pôle Emploi Central", coords = { x = -268.3, y = -956.8, z = 31.2, heading = 205.0 } }
        }
    })
    isCreating = true
    SetupCreatorCamera()
end

function SetupCreatorCamera()
    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, -1042.0, -2745.0, 21.3, false, false, false, true)
    SetEntityHeading(playerPed, 330.0)
    FreezeEntityPosition(playerPed, true)

    charCamera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(charCamera, -1040.8, -2743.0, 21.6)
    PointCamAtEntity(charCamera, playerPed, 0.0, 0.0, 0.2, true)
    SetCamActive(charCamera, true)
    RenderScriptCams(true, true, 500, true, true)
end

function CloseRegistration()
    SetNuiFocus(false, false)
    if charCamera then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    FreezeEntityPosition(PlayerPedId(), false)
    isCreating = false
end

RegisterNUICallback('saveCharacter', function(data, cb)
    TriggerServerEvent('rp_characters:server:createCharacter', data)
    CloseRegistration()
    cb({ status = "ok" })
end)

RegisterNUICallback('updateSkinPreview', function(data, cb)
    local ped = PlayerPedId()
    if data.gender == 'f' then
        SetPedComponentVariation(ped, 3, 3, 0, 0)
    else
        SetPedComponentVariation(ped, 3, 0, 0, 0)
    end
    cb({ status = "ok" })
end)

RegisterNetEvent('rp_characters:client:spawnPlayer', function(coords)
    local ped = PlayerPedId()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.heading or 0.0)
    FreezeEntityPosition(ped, false)

    Wait(500)
    DoScreenFadeIn(1000)
end)

RegisterNetEvent('rp_characters:client:openMenu', function()
    OpenCharacterRegistration()
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(2000)
    TriggerServerEvent('rp_characters:server:checkPlayer')
end)
