local fleet = nil
local selected = 1
local promptShown = false
local menuShown = false
local jobGarage = nil

local function notify(message, kind)
    TriggerEvent('rp_core:client:notify', message, kind or 'info')
end

local function hidePrompt()
    if promptShown then
        exports['rp_ui']:HideTextUI()
        promptShown = false
    end
end

local function showPrompt(message)
    if not promptShown then
        exports['rp_ui']:ShowTextUI(message)
        promptShown = true
    end
end

local function showSelection()
    if not fleet or #fleet.vehicles == 0 then return end
    local vehicle = fleet.vehicles[selected]
    exports['rp_ui']:ShowTextUI(('[←/→] %s (%d/%d)  [ENTRÉE] Sortir  [ÉCHAP] Fermer'):format(
        vehicle.label, selected, #fleet.vehicles))
    promptShown = true
    menuShown = true
end

RegisterNetEvent('rp_garages:client:setJobGarage', function(data)
    if type(data) ~= 'table' or type(data.coords) ~= 'table' then
        jobGarage = nil
        return
    end
    jobGarage = {
        coords = vector3(tonumber(data.coords.x), tonumber(data.coords.y), tonumber(data.coords.z)),
        spawn = data.spawn
    }
end)

RegisterNetEvent('rp_garages:client:jobFleet', function(data)
    if type(data) ~= 'table' or type(data.vehicles) ~= 'table' or #data.vehicles == 0 then return end
    fleet = data
    selected = 1
    showSelection()
end)

RegisterNetEvent('rp_garages:client:jobVehicleSpawned', function(netId)
    local vehicle = NetToVeh(tonumber(netId) or 0)
    local deadline = GetGameTimer() + 5000
    while vehicle == 0 and GetGameTimer() < deadline do
        Wait(50)
        vehicle = NetToVeh(tonumber(netId) or 0)
    end
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        SetVehicleEngineOn(vehicle, true, true, false)
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    else
        notify('Véhicule créé mais introuvable côté client. Contacte un administrateur.', 'error')
    end
    fleet = nil
    menuShown = false
    hidePrompt()
end)

RegisterNetEvent('rp_garages:client:jobVehicleStored', function()
    fleet = nil
    menuShown = false
    hidePrompt()
end)

CreateThread(function()
    Wait(2500)
    while true do
        TriggerServerEvent('rp_garages:server:requestJobGarageMarker')
        Wait(15000)
    end
end)

CreateThread(function()
    while true do
        local sleep = 650
        if menuShown and fleet then
            sleep = 0
            if IsControlJustReleased(0, 174) then
                selected = selected > 1 and selected - 1 or #fleet.vehicles
                showSelection()
            elseif IsControlJustReleased(0, 175) then
                selected = selected < #fleet.vehicles and selected + 1 or 1
                showSelection()
            elseif IsControlJustReleased(0, 191) then
                local model = fleet.vehicles[selected].model
                menuShown = false
                hidePrompt()
                TriggerServerEvent('rp_garages:server:spawnJobVehicle', model)
            elseif IsControlJustReleased(0, 200) or IsControlJustReleased(0, 177) then
                fleet = nil
                menuShown = false
                hidePrompt()
            end
        elseif jobGarage and not IsPauseMenuActive() then
            local coords = GetEntityCoords(PlayerPedId())
            local distance = #(coords - jobGarage.coords)
            if distance <= 2.5 then
                sleep = 0
                local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
                if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == PlayerPedId() then
                    showPrompt('[E] Garage métier  ·  [G] Ranger véhicule de service')
                    if IsControlJustReleased(0, 47) then
                        TriggerServerEvent('rp_garages:server:storeJobVehicle')
                    elseif IsControlJustReleased(0, 38) then
                        TriggerServerEvent('rp_garages:server:requestJobFleet')
                    end
                else
                    showPrompt('[E] Sortir un véhicule de service')
                    if IsControlJustReleased(0, 38) then
                        TriggerServerEvent('rp_garages:server:requestJobFleet')
                    end
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

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    hidePrompt()
end)
