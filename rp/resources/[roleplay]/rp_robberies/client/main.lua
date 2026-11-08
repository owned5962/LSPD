local isRobbing = false
local currentRobberyType = nil
local currentBankId = nil

-- Recherche de l'ATM le plus proche
function GetClosestATM()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _, model in ipairs(Config.ATMModels) do
        local obj = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 1.8, model, false, false, false)
        if obj ~= 0 and DoesEntityExist(obj) then
            return obj, GetEntityCoords(obj)
        end
    end
    return nil, nil
end

-- Recherche de la banque la plus proche
function GetClosestBank()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    for _, bank in ipairs(Config.Banks) do
        local dist = #(playerCoords - bank.coords)
        if dist < 3.0 then
            return bank, dist
        end
    end
    return nil, 999.0
end

-- Boucle de détection des interactions
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        
        if not isRobbing and not IsPedInAnyVehicle(playerPed, false) then
            -- 1. Test ATM
            local atmObj, atmCoords = GetClosestATM()
            if atmObj then
                sleep = 0
                DrawText3D(atmCoords.x, atmCoords.y, atmCoords.z + 1.0, "[~r~E~w~] Pirater le distributeur (DAB)")
                if IsControlJustPressed(0, 38) then -- E
                    TriggerServerEvent('rp_robberies:requestStartATM', atmCoords)
                end
            end

            -- 2. Test Banques
            local bank, dist = GetClosestBank()
            if bank and dist < 2.5 then
                sleep = 0
                DrawText3D(bank.coords.x, bank.coords.y, bank.coords.z + 0.2, "[~r~E~w~] Braquer " .. bank.name)
                if IsControlJustPressed(0, 38) then -- E
                    TriggerServerEvent('rp_robberies:requestStartBank', bank.id)
                end
            end
        end

        Wait(sleep)
    end
end)

-- Lancer le minigame de piratage NUI
RegisterNetEvent('rp_robberies:startMinigame', function(type, id, duration)
    isRobbing = true
    currentRobberyType = type
    currentBankId = id

    -- Animation de piratage avec tablette / outil
    local ped = PlayerPedId()
    RequestAnimDict("anim@heists@ornate_bank@hack")
    while not HasAnimDictLoaded("anim@heists@ornate_bank@hack") do Wait(10) end
    TaskPlayAnim(ped, "anim@heists@ornate_bank@hack", "hack_loop", 8.0, -8.0, -1, 1, 0, false, false, false)

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'startHack',
        type = type,
        id = id,
        duration = duration or 20
    })
end)

-- Réception du résultat du hack depuis l'interface NUI
RegisterNUICallback('hackResult', function(data, cb)
    SetNuiFocus(false, false)
    ClearPedTasks(PlayerPedId())

    if data.success then
        TriggerServerEvent('rp_robberies:completeRobbery', data.type, data.targetId)
    else
        TriggerEvent('rp_core:notify', "Piratage échoué ! Les forces de l'ordre ont été alertées !", "error")
        TriggerServerEvent('rp_robberies:hackFailed', data.type, data.targetId)
    end
    isRobbing = false
    cb('ok')
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    ClearPedTasks(PlayerPedId())
    isRobbing = false
    cb('ok')
end)

-- Alerte Police / Blip GPS
RegisterNetEvent('rp_robberies:policeAlert', function(coords, title, msg)
    -- Notification d'urgence
    TriggerEvent('rp_core:notify', "[17 ALERTE POLICE] " .. title .. " : " .. msg, "warning")
    
    -- Blip clignotant
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.2)
    SetBlipColour(blip, 1) -- Rouge
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("17 - BRAQUAGE EN COURS")
    EndTextCommandSetBlipName(blip)

    SetTimeout(60000, function()
        RemoveBlip(blip)
    end)
end)

-- Affichage 3D immersif
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end
