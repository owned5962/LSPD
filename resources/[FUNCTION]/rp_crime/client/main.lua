local harvestBusy = false
local activeDispatchBlips = {}
local sellPed = nil
local sellAllBusy = false

local function drawText3D(coords, text)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.32, 0.32); SetTextFont(4); SetTextProportional(1)
    SetTextColour(255, 255, 255, 215); SetTextCentre(1)
    BeginTextCommandDisplayText('STRING'); AddTextComponentSubstringPlayerName(text); EndTextCommandDisplayText(sx, sy)
end

CreateThread(function()
    local model = joaat(Config.SellNPC.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(20) end
    local c = Config.SellNPC.coords
    sellPed = CreatePed(4, model, c.x, c.y, c.z - 1.0, Config.SellNPC.heading, false, true)
    SetEntityInvincible(sellPed, true); FreezeEntityPosition(sellPed, true); SetBlockingOfNonTemporaryEvents(sellPed, true)

    while true do
        local wait = 1000
        local coords = GetEntityCoords(PlayerPedId())
        for itemName, data in pairs(Config.Drugs) do
            local dist = #(coords - data.zone)
            if dist < 18.0 then
                wait = 0
                DrawMarker(1, data.zone.x, data.zone.y, data.zone.z - 1.0, 0,0,0,0,0,0,1.1,1.1,0.5,180,40,40,150,false,true,2,false,nil,nil,false)
                if dist < 1.8 then
                    drawText3D(data.zone + vector3(0,0,0.8), ('[E] Récolter %s'):format(data.label))
                    if IsControlJustPressed(0, 38) and not harvestBusy then
                        harvestBusy = true
                        TriggerServerEvent('rp_crime:server:harvest', itemName)
                        Wait(data.wait + 1000)
                        harvestBusy = false
                    end
                end
            end
        end
        local sellDist = #(coords - Config.SellNPC.coords)
        if sellDist < 10.0 then
            wait = 0
            if sellDist < 2.0 then
                drawText3D(Config.SellNPC.coords + vector3(0,0,1.0), '[E] Vendre tous les produits au receleur')
                if IsControlJustPressed(0, 38) and not sellAllBusy then
                    sellAllBusy = true
                    TriggerServerEvent('rp_crime:server:sellAllToNPC')
                    Wait(1500)
                    sellAllBusy = false
                end
            end
        end
        Wait(wait)
    end
end)

RegisterCommand('sellcontraband', function(_, args)
    if #args < 2 then
        TriggerEvent('rp_core:notify', 'info', 'Utilisation : /sellcontraband item quantité')
        return
    end
    TriggerServerEvent('rp_crime:server:sellToNPC', tostring(args[1]), tonumber(args[2]))
end, false)

RegisterCommand('sellitem', function(_, args)
    if #args < 4 then
        TriggerEvent('rp_core:notify', 'info', 'Utilisation : /sellitem ID item quantité prix')
        return
    end
    TriggerServerEvent('rp_crime:server:sellToPlayer', tonumber(args[1]), tostring(args[2]), tonumber(args[3]), tonumber(args[4]))
end, false)

RegisterCommand('acceptdispatch', function(_, args)
    local id = tonumber(args[1])
    if id then TriggerServerEvent('rp_crime:server:acceptDispatch', id)
    else TriggerEvent('rp_core:client:notify', 'Utilisation : /acceptdispatch numéro', 'info') end
end, false)

RegisterNetEvent('rp_crime:client:dispatch', function(call)
    TriggerEvent('rp_core:client:notify',
        ('APPEL LSPD #%d : %s — %s. Accepter : /acceptdispatch %d'):format(call.id, call.message, call.street, call.id), 'warning')
end)

RegisterNetEvent('rp_crime:client:dispatchAccepted', function(call)
    local c = call.coords
    SetNewWaypoint(c.x, c.y)
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, Config.Dispatch.blipSprite)
    SetBlipColour(blip, Config.Dispatch.blipColour)
    SetBlipScale(blip, Config.Dispatch.blipScale)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, Config.Dispatch.blipColour)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('Intervention LSPD #%d'):format(call.id))
    EndTextCommandSetBlipName(blip)
    activeDispatchBlips[call.id] = blip
    TriggerEvent('rp_core:client:notify', ('Intervention acceptée : GPS défini vers %s.'):format(call.street), 'success')
end)

RegisterCommand('clearcrimeblips', function()
    for id, blip in pairs(activeDispatchBlips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        activeDispatchBlips[id] = nil
    end
end, false)

RegisterKeyMapping('robnpc', 'Braquer le passant le plus proche', 'keyboard', 'G')
RegisterCommand('robnpc', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPed, closestDist = 0, 3.0
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= playerPed and not IsPedAPlayer(ped) and not IsEntityDead(ped) then
            local dist = #(playerCoords - GetEntityCoords(ped))
            if dist < closestDist then closestPed, closestDist = ped, dist end
        end
    end
    if closestPed == 0 then
        TriggerEvent('rp_core:client:notify', 'Aucun passant à proximité.', 'error')
        return
    end
    if not NetworkGetEntityIsNetworked(closestPed) then NetworkRegisterEntityAsNetworked(closestPed) end
    local netId = NetworkGetNetworkIdFromEntity(closestPed)
    if not netId or netId == 0 then
        TriggerEvent('rp_core:client:notify', 'Ce passant ne peut pas être ciblé.', 'error')
        return
    end
    TaskTurnPedToFaceEntity(closestPed, playerPed, 1000)
    TriggerServerEvent('rp_crime:server:robNPC', netId)
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if sellPed and DoesEntityExist(sellPed) then DeleteEntity(sellPed) end
    for _, blip in pairs(activeDispatchBlips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
end)
