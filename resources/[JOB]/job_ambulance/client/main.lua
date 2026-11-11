local onDuty = false

Citizen.CreateThread(function()
    while true do
        local sleep = 1500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist = #(coords - Config.DutyCoords)

        if dist < 10.0 then
            sleep = 0
            DrawMarker(1, Config.DutyCoords.x, Config.DutyCoords.y, Config.DutyCoords.z - 1.0, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.6, 56, 189, 248, 120, false, true, 2, false, nil, nil, false)
            if dist < 1.5 then
                local label = onDuty and "[E] Fin de service" or "[E] Prise de service"
                exports['rp_ui']:ShowTextUI(label .. ' (' .. Config.Label .. ')')
                if IsControlJustPressed(0, 38) then
                    TriggerServerEvent('job_ambulance:setDuty', not onDuty)
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

RegisterNetEvent('job_ambulance:dutyUpdated', function(status)
    onDuty = status
    if onDuty then
        TriggerEvent('rp_core:notify', 'success', 'Prise de service validée : ' .. Config.Label)
    else
        TriggerEvent('rp_core:notify', 'info', 'Fin de service : ' .. Config.Label)
    end
end)
