local isCreating = false
local charCamera = nil

local function OpenCreator(maxCharacters)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openRegistration', maxCharacters = maxCharacters or 3 })
    isCreating = true
    SetupCreatorCamera()
end

function SetupCreatorCamera()
    local ped = PlayerPedId()
    SetEntityCoords(ped, -1042.0, -2745.0, 21.3, false, false, false, true)
    SetEntityHeading(ped, 330.0)
    FreezeEntityPosition(ped, true)
    charCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(charCamera, -1040.8, -2743.0, 21.6)
    PointCamAtEntity(charCamera, ped, 0.0, 0.0, 0.2, true)
    SetCamActive(charCamera, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function CloseCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeRegistration' })
    SendNUIMessage({ action = 'closeCharacterSelection' })
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
    cb({ status = 'submitted' })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('rp_characters:server:selectCharacter', data.slot)
    cb({ status = 'submitted' })
end)

RegisterNUICallback('updateSkinPreview', function(data, cb)
    local ped = PlayerPedId()
    if data.gender == 'f' then SetPedComponentVariation(ped, 3, 3, 0, 0)
    else SetPedComponentVariation(ped, 3, 0, 0, 0) end
    cb({ status = 'ok' })
end)

RegisterNetEvent('rp_characters:client:openMenu', function(maxCharacters)
    OpenCreator(maxCharacters)
end)

RegisterNetEvent('rp_characters:client:openCharacterSelection', function(characters, maxCharacters)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCharacterSelection', characters = characters, maxCharacters = maxCharacters or 3 })
end)

RegisterNetEvent('rp_characters:client:closeMenu', function()
    CloseCharacterUI()
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

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(2000)
    TriggerServerEvent('rp_characters:server:checkPlayer')
end)
