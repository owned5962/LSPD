local dealerships = {}
local tabletOpen = false
local promptVisible = false
local currentDealer = nil
local pendingSpawn = nil
local dealerBlips = {}

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', message, kind or 'info')
end

local function closeTablet()
    if not tabletOpen then return end
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function hidePrompt()
    if promptVisible then
        exports['rp_ui']:HideTextUI()
        promptVisible = false
    end
end

local function loadVehicleModel(model)
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) or not IsModelAVehicle(hash) then
        return nil
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + 12000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function createDealerBlips()
    for _, dealer in ipairs(Config.Dealerships) do
        if dealer.blip and dealer.blip.enabled then
            local blip = AddBlipForCoord(dealer.coords.x, dealer.coords.y, dealer.coords.z)
            SetBlipSprite(blip, dealer.blip.sprite or 225)
            SetBlipColour(blip, dealer.blip.colour or 5)
            SetBlipScale(blip, dealer.blip.scale or 0.85)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(dealer.label or 'Concessionnaire')
            EndTextCommandSetBlipName(blip)
            dealerBlips[#dealerBlips + 1] = blip
        end
    end
end

RegisterNetEvent('rp_vehicle_dealership:client:open', function(payload)
    if type(payload) ~= 'table' then return end
    hidePrompt()
    tabletOpen = true
    currentDealer = payload.dealer
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        dealer = payload.label or 'Concessionnaire',
        bank = tonumber(payload.bank) or 0,
        vehicles = payload.vehicles or {}
    })
end)

RegisterNetEvent('rp_vehicle_dealership:client:purchaseFailed', function(message)
    if pendingSpawn and DoesEntityExist(pendingSpawn) then DeleteEntity(pendingSpawn) end
    pendingSpawn = nil
    notify(message or 'L’achat n’a pas pu être effectué.', 'error')
    SendNUIMessage({ action = 'purchaseError', message = message or 'Achat impossible.' })
end)

RegisterNetEvent('rp_vehicle_dealership:client:spawnPurchased', function(data)
    if type(data) ~= 'table' or type(data.model) ~= 'string' then
        TriggerServerEvent('rp_vehicle_dealership:server:spawnFailed')
        return
    end

    local hash = loadVehicleModel(data.model)
    if not hash then
        TriggerServerEvent('rp_vehicle_dealership:server:spawnFailed')
        notify('Le modèle du véhicule est introuvable. Le remboursement va être effectué.', 'error')
        return
    end

    local spawn = data.spawn
    if type(spawn) ~= 'table' then
        SetModelAsNoLongerNeeded(hash)
        TriggerServerEvent('rp_vehicle_dealership:server:spawnFailed')
        return
    end

    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, true)
    SetModelAsNoLongerNeeded(hash)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        TriggerServerEvent('rp_vehicle_dealership:server:spawnFailed')
        return
    end

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, data.plate)
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleEngineOn(vehicle, true, true, false)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    pendingSpawn = vehicle
    TriggerServerEvent('rp_vehicle_dealership:server:registerPurchasedVehicle', netId)
end)

RegisterNetEvent('rp_vehicle_dealership:client:purchaseConfirmed', function(plate)
    if not pendingSpawn or not DoesEntityExist(pendingSpawn) then return end
    SetVehicleNumberPlateText(pendingSpawn, plate)
    SetVehicleOnGroundProperly(pendingSpawn)
    TaskWarpPedIntoVehicle(PlayerPedId(), pendingSpawn, -1)
    SetVehicleEngineOn(pendingSpawn, true, true, false)
    pendingSpawn = nil
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    notify('Félicitations ! Votre véhicule est à présent enregistré à votre nom.', 'success')
end)

RegisterNUICallback('close', function(_, cb)
    closeTablet()
    cb({ ok = true })
end)

RegisterNUICallback('buyVehicle', function(data, cb)
    if type(data) == 'table' and type(data.model) == 'string' and currentDealer then
        TriggerServerEvent('rp_vehicle_dealership:server:purchase', currentDealer, data.model)
    end
    cb({ ok = true })
end)

CreateThread(function()
    createDealerBlips()
    while true do
        local sleep = 700
        if not tabletOpen and not IsPauseMenuActive() then
            local coords = GetEntityCoords(PlayerPedId())
            local nearest, distance
            for _, dealer in ipairs(Config.Dealerships) do
                local current = #(coords - dealer.coords)
                if current < (distance or Config.InteractionDistance + 1.0) then
                    nearest, distance = dealer, current
                end
            end

            if nearest and distance <= Config.InteractionDistance then
                sleep = 0
                DrawMarker(2, nearest.coords.x, nearest.coords.y, nearest.coords.z + 0.15,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.22, 0.22, 0.22,
                    201, 164, 93, 190, false, true, 2, false, nil, nil, false)
                if not promptVisible then
                    exports['rp_ui']:ShowTextUI('[E] Ouvrir le catalogue véhicules')
                    promptVisible = true
                end
                if IsControlJustReleased(0, 38) then
                    notify('Connexion au concessionnaire…', 'info')
                    TriggerServerEvent('rp_vehicle_dealership:server:open', nearest.id)
                    Wait(500)
                end
            else
                hidePrompt()
            end
        else
            hidePrompt()
        end
        Wait(sleep)
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    closeTablet()
    hidePrompt()
    for _, blip in ipairs(dealerBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    if pendingSpawn and DoesEntityExist(pendingSpawn) then DeleteEntity(pendingSpawn) end
end)
