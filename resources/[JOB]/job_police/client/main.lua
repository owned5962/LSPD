local onDuty = false
local currentVehicle = nil

Citizen.CreateThread(function()
    -- Blip commissariat Mission Row
    local blip = AddBlipForCoord(Config.DutyCoords.x, Config.DutyCoords.y, Config.DutyCoords.z)
    SetBlipSprite(blip, 60)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, 38)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Poste de Police LSPD - Mission Row")
    EndTextCommandSetBlipName(blip)

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        -- Prise de service
        local distDuty = #(coords - Config.DutyCoords)
        if distDuty < 10.0 then
            sleep = 0
            DrawMarker(1, Config.DutyCoords.x, Config.DutyCoords.y, Config.DutyCoords.z - 1.0, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.6, 56, 189, 248, 150, false, true, 2, false, nil, nil, false)
            if distDuty < 1.5 then
                local label = onDuty and "[E] Terminer son service LSPD" or "[E] Prendre son service LSPD"
                exports['rp_ui']:ShowTextUI(label)
                if IsControlJustPressed(0, 38) then
                    TriggerServerEvent('job_police:setDuty', not onDuty)
                end
            end
        end

        -- Armurerie LSPD
        if onDuty and Config.ArmoryCoords then
            local distArmory = #(coords - Config.ArmoryCoords)
            if distArmory < 10.0 then
                sleep = 0
                DrawMarker(1, Config.ArmoryCoords.x, Config.ArmoryCoords.y, Config.ArmoryCoords.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 0.6, 234, 179, 8, 150, false, true, 2, false, nil, nil, false)
                if distArmory < 1.5 then
                    exports['rp_ui']:ShowTextUI("[E] Ouvrir l'Armurerie LSPD")
                    if IsControlJustPressed(0, 38) then
                        TriggerServerEvent('job_police:getArmoryWeapons')
                    end
                end
            end
        end

        -- Garage LSPD
        if onDuty and Config.VehicleSpawner then
            local distGarage = #(coords - Config.VehicleSpawner)
            if distGarage < 10.0 then
                sleep = 0
                DrawMarker(36, Config.VehicleSpawner.x, Config.VehicleSpawner.y, Config.VehicleSpawner.z, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 1.0, 59, 130, 246, 180, false, true, 2, false, nil, nil, false)
                if distGarage < 2.0 then
                    exports['rp_ui']:ShowTextUI("[E] Garage Flotte LSPD / [G] Ranger véhicule")
                    if IsControlJustPressed(0, 38) then
                        SpawnPoliceVehicle('police')
                    elseif IsControlJustPressed(0, 47) then
                        DeletePoliceVehicle()
                    end
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

function SpawnPoliceVehicle(modelName)
    local hash = GetHashKey(modelName)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Citizen.Wait(10) end

    local spawn = Config.VehicleSpawnPoint
    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleNumberPlateText(veh, "LSPD" .. math.random(100, 999))
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    currentVehicle = veh
    TriggerEvent('rp_core:notify', 'success', 'Véhicule d\'intervention LSPD déployé.')
end

function DeletePoliceVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        DeleteVehicle(veh)
        TriggerEvent('rp_core:notify', 'info', 'Véhicule de patrouille LSPD rangé.')
    elseif currentVehicle and DoesEntityExist(currentVehicle) then
        DeleteVehicle(currentVehicle)
        currentVehicle = nil
        TriggerEvent('rp_core:notify', 'info', 'Véhicule de patrouille LSPD rangé.')
    end
end

RegisterNetEvent('job_police:dutyUpdated', function(status)
    onDuty = status
    if onDuty then
        TriggerEvent('rp_core:notify', 'success', 'Prise de service validée : LSPD Mission Row')
    else
        TriggerEvent('rp_core:notify', 'info', 'Fin de service : LSPD')
    end
end)
