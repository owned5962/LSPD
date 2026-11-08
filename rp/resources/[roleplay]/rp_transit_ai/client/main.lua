-- rp_transit_ai client
local isUIOpen = false
local currentTaxi = nil
local taxiDriver = nil
local isTraveling = false

RegisterNetEvent('rp_transit:openMenu')
AddEventHandler('rp_transit:openMenu', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openTransit' })
    isUIOpen = true
end)

RegisterNUICallback('closeUI', function(data, cb)
    SetNuiFocus(false, false)
    isUIOpen = false
    cb('ok')
end)

RegisterNUICallback('requestTaxi', function(data, cb)
    TriggerServerEvent('rp_transit:payAndSpawnTaxi', data.destination, data.drivingStyle)
    cb('ok')
end)

RegisterNUICallback('requestBus', function(data, cb)
    TriggerServerEvent('rp_transit:payAndSpawnBus', data.route)
    cb('ok')
end)

RegisterNetEvent('rp_transit:startTaxiTrip')
AddEventHandler('rp_transit:startTaxiTrip', function(dest, drivingStyle)
    local playerPed = PlayerPedId()
    local pCoords = GetEntityCoords(playerPed)

    -- Spawner le taxi et le chauffeur IA
    local modelHash = GetHashKey('taxi')
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do Wait(50) end

    local pedHash = GetHashKey('a_m_y_stlat_01')
    RequestModel(pedHash)
    while not HasModelLoaded(pedHash) do Wait(50) end

    local spawnCoords = vector3(pCoords.x + 10.0, pCoords.y + 10.0, pCoords.z)
    currentTaxi = CreateVehicle(modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, true, false)
    taxiDriver = CreatePedInsideVehicle(currentTaxi, 26, pedHash, -1, true, false)

    SetBlockingOfNonTemporaryEvents(taxiDriver, true)
    SetPedFleeAttributes(taxiDriver, 0, false)
    
    -- Faire monter le joueur
    TaskEnterVehicle(playerPed, currentTaxi, -1, 2, 2.0, 1, 0)
    Wait(3000)

    -- Style de conduite IA
    local drivingMode = 786603 -- Conduite normale sécurisée
    local speed = 18.0
    if drivingStyle == 'rushed' then
        drivingMode = 1074528293 -- Conduite rapide
        speed = 26.0
    end

    TaskVehicleDriveToCoord(taxiDriver, currentTaxi, dest.coords.x, dest.coords.y, dest.coords.z, speed, 1.0, modelHash, drivingMode, 5.0, true)
    isTraveling = true

    -- Notification
    TriggerEvent('chat:addMessage', {
        color = { 245, 158, 11 },
        multiline = true,
        args = { "LST TAXI IA", "Chauffeur en route vers " .. dest.name .. ". Appuyez sur [X] pour descendre immédiatement." }
    })

    Citizen.CreateThread(function()
        while isTraveling do
            Wait(1000)
            local taxiPos = GetEntityCoords(currentTaxi)
            local dist = #(taxiPos - vector3(dest.coords.x, dest.coords.y, dest.coords.z))
            
            if dist < 12.0 or IsControlJustPressed(0, 73) then -- Touche X
                TaskVehicleTempAction(taxiDriver, currentTaxi, 27, 4000) -- Freiner et s'arrêter
                TaskLeaveVehicle(playerPed, currentTaxi, 0)
                isTraveling = false
                TriggerEvent('chat:addMessage', {
                    color = { 16, 185, 129 },
                    multiline = true,
                    args = { "LST TAXI IA", "Vous êtes arrivé à destination ! Merci de votre visite." }
                })
                Wait(5000)
                DeletePed(taxiDriver)
                DeleteVehicle(currentTaxi)
                break
            end
        end
    end)
end)

-- Commande rapide
RegisterCommand('taxi', function()
    TriggerEvent('rp_transit:openMenu')
end, false)
