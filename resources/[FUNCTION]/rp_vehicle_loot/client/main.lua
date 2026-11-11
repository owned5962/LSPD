local activeVehicle, activeWheel = 0, nil
local function nearestWheel(vehicle, coords)
    local wheels = { 0, 1, 2, 3 }
    local best, distance
    for _, index in ipairs(wheels) do
        local wheel = GetWorldPositionOfEntityBone(vehicle, GetEntityBoneIndexByName(vehicle, ({'wheel_lf','wheel_rf','wheel_lr','wheel_rr'})[index + 1]))
        local d = #(coords - wheel)
        if not distance or d < distance then best, distance = index, d end
    end
    return best, distance
end

CreateThread(function()
    local prompted = false
    while true do
        local waitTime = 800
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) and IsPedArmed(ped, 1) then
            local coords = GetEntityCoords(ped)
            local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 3.0, 0, 70)
            if vehicle ~= 0 and DoesEntityExist(vehicle) and GetEntitySpeed(vehicle) < 0.5 then
                local wheel, distance = nearestWheel(vehicle, coords)
                if wheel ~= nil and distance and distance < 1.6 then
                    waitTime = 0
                    exports['rp_ui']:ShowTextUI('[E] Démonter le pneu et récupérer des pièces')
                    prompted = true
                    if IsControlJustReleased(0, 38) then
                        activeVehicle, activeWheel = vehicle, wheel
                        exports['rp_ui']:ProgressBar({ duration = 6500, label = 'Démontage du pneu...', canCancel = true }, function(completed)
                            if completed and activeVehicle ~= 0 and DoesEntityExist(activeVehicle) then
                                TriggerServerEvent('rp_vehicle_loot:server:stealTire', NetworkGetNetworkIdFromEntity(activeVehicle), activeWheel)
                            end
                            activeVehicle, activeWheel = 0, nil
                        end)
                    end
                elseif prompted then exports['rp_ui']:HideTextUI(); prompted = false end
            elseif prompted then exports['rp_ui']:HideTextUI(); prompted = false end
        elseif prompted then exports['rp_ui']:HideTextUI(); prompted = false end
        Wait(waitTime)
    end
end)

RegisterNetEvent('rp_vehicle_loot:client:success', function(netId, wheel, message)
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(netId) or 0)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then SetVehicleTyreBurst(vehicle, tonumber(wheel) or 0, true, 1000.0) end
    -- The server notifies only the player who completed the theft.
end)
