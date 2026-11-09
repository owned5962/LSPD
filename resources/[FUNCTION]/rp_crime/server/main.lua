local harvestCooldowns, robberyCooldowns, activeHarvests = {}, {}, {}
local dispatches, dispatchCounter = {}, 0

local function notify(src, message, kind)
    TriggerClientEvent('rp_core:client:notify', src, message, kind or 'info')
end

local function getPlayer(src)
    return exports['rp_core']:GetPlayerFromId(tonumber(src))
end

local function alive(src)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and DoesEntityExist(ped) and not IsEntityDead(ped)
end

local function nearPoint(src, point, radius)
    if not alive(src) then return false end
    return #(GetEntityCoords(GetPlayerPed(src)) - point) <= radius
end

local function isPoliceOnDuty(src)
    local player = getPlayer(src)
    return player and player.job == 'police' and exports['job_police']:IsOnDuty(src)
end

RegisterNetEvent('rp_crime:server:harvest', function(itemName)
    local src = source
    local data = Config.Drugs[itemName]
    local player = getPlayer(src)
    if not player or not data or activeHarvests[src] then return end
    if not nearPoint(src, data.zone, 5.0) then
        notify(src, 'Vous n’êtes pas au bon point de récolte.', 'error')
        return
    end
    local now = GetGameTimer()
    if harvestCooldowns[src] and now < harvestCooldowns[src] then
        notify(src, 'Ce point n’est pas encore disponible.', 'warning')
        return
    end
    activeHarvests[src] = true
    local startCoords = GetEntityCoords(GetPlayerPed(src))
    notify(src, 'Récolte en cours… restez sur place.', 'info')
    Wait(data.wait)
    activeHarvests[src] = nil
    if not getPlayer(src) or not alive(src) or #(GetEntityCoords(GetPlayerPed(src)) - startCoords) > 4.0
        or not nearPoint(src, data.zone, 7.0) then
        notify(src, 'Récolte interrompue : vous avez quitté la zone.', 'error')
        return
    end
    local amount = math.random(data.min, data.max)
    if exports['rp_inventory']:AddItem(src, itemName, amount) then
        harvestCooldowns[src] = GetGameTimer() + data.cooldown
        notify(src, ('Récolte terminée : %d x %s.'):format(amount, data.label), 'success')
    else
        notify(src, 'Inventaire plein ou sauvegarde indisponible.', 'error')
    end
end)

RegisterNetEvent('rp_crime:server:sellToNPC', function(itemName, rawAmount)
    local src = source
    local data = Config.Drugs[itemName]
    local amount = tonumber(rawAmount)
    local player = getPlayer(src)
    if not player or not data or not amount or amount % 1 ~= 0 or amount < 1 or amount > 100 then return end
    if not nearPoint(src, Config.SellNPC.coords, Config.SellNPC.radius) then
        notify(src, 'Le contact n’est pas à proximité.', 'error')
        return
    end
    if exports['rp_inventory']:GetItemCount(src, itemName) < amount then
        notify(src, 'Quantité insuffisante.', 'error')
        return
    end
    local unitPrice = math.random(data.priceMin, data.priceMax)
    local total = unitPrice * amount
    if not exports['rp_inventory']:RemoveItem(src, itemName, amount) then
        notify(src, 'La transaction a échoué côté inventaire.', 'error')
        return
    end
    if not player.addCash(total) then
        exports['rp_inventory']:AddItem(src, itemName, amount)
        notify(src, 'Paiement impossible : objets restitués.', 'error')
        return
    end
    notify(src, ('Vente effectuée : %d x %s pour %d $.'):format(amount, data.label, total), 'success')
end)

RegisterNetEvent('rp_crime:server:sellAllToNPC', function()
    local src = source
    local player = getPlayer(src)
    if not player or not nearPoint(src, Config.SellNPC.coords, Config.SellNPC.radius) then
        notify(src, 'Le receleur n’est pas à proximité.', 'error')
        return
    end
    local sold, total = {}, 0
    for itemName, data in pairs(Config.Drugs) do
        local count = exports['rp_inventory']:GetItemCount(src, itemName)
        if count > 0 then
            local unitPrice = math.random(data.priceMin, data.priceMax)
            local amount = math.min(count, 100)
            if exports['rp_inventory']:RemoveItem(src, itemName, amount) then
                sold[#sold + 1] = { name = itemName, amount = amount, label = data.label }
                total = total + (unitPrice * amount)
            end
        end
    end
    if total <= 0 then
        notify(src, 'Vous n’avez aucun produit accepté à vendre.', 'warning')
        return
    end
    if not player.addCash(total) then
        -- Restitution de chaque pile si le paiement n'a pas pu être sauvegardé.
        for _, entry in ipairs(sold) do
            exports['rp_inventory']:AddItem(src, entry.name, entry.amount)
        end
        notify(src, 'Paiement impossible : produits restitués si la sauvegarde le permet.', 'error')
        return
    end
    local soldLabels = {}
    for _, entry in ipairs(sold) do soldLabels[#soldLabels + 1] = ('%d x %s'):format(entry.amount, entry.label) end
    notify(src, ('Vente au receleur : %s. Total : %d $.'):format(table.concat(soldLabels, ', '), total), 'success')
end)

RegisterNetEvent('rp_crime:server:sellToPlayer', function(rawTarget, itemName, rawAmount, rawPrice)
    local src, targetId = source, tonumber(rawTarget)
    local seller, buyer = getPlayer(src), targetId and getPlayer(targetId)
    local data, amount, price = Config.Drugs[itemName], tonumber(rawAmount), tonumber(rawPrice)
    if not seller or not buyer or targetId == src or not data or not amount or amount % 1 ~= 0
        or amount < 1 or amount > 50 or not price or price % 1 ~= 0 or price < 1 or price > 100000 then return end
    if not alive(src) or not alive(targetId)
        or #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(targetId))) > 3.0 then
        notify(src, 'Le joueur est trop éloigné.', 'error')
        return
    end
    if exports['rp_inventory']:GetItemCount(src, itemName) < amount or buyer.cash < price then
        notify(src, 'Quantité ou argent insuffisant.', 'error')
        return
    end
    if not buyer.removeCash(price) then notify(src, 'Paiement refusé.', 'error'); return end
    if not exports['rp_inventory']:RemoveItem(src, itemName, amount) then
        buyer.addCash(price); notify(src, 'Retrait des objets impossible.', 'error'); return
    end
    if not exports['rp_inventory']:AddItem(targetId, itemName, amount) then
        exports['rp_inventory']:AddItem(src, itemName, amount)
        buyer.addCash(price)
        notify(src, 'Inventaire du destinataire plein : transaction annulée.', 'error')
        return
    end
    if not seller.addCash(price) then
        exports['rp_inventory']:RemoveItem(targetId, itemName, amount)
        exports['rp_inventory']:AddItem(src, itemName, amount)
        buyer.addCash(price)
        notify(src, 'Paiement vendeur impossible : transaction annulée.', 'error')
        return
    end
    notify(src, ('Vente conclue : %d x %s contre %d $.'):format(amount, data.label, price), 'success')
    notify(targetId, ('Achat reçu : %d x %s.'):format(amount, data.label), 'success')
end)

RegisterNetEvent('rp_crime:server:robNPC', function(rawNetId)
    local src = source
    local player = getPlayer(src)
    local netId = tonumber(rawNetId)
    if not player or not netId or netId < 1 or netId % 1 ~= 0 then return end
    local npc = NetworkGetEntityFromNetworkId(netId)
    if npc == 0 or not DoesEntityExist(npc) or GetEntityType(npc) ~= 1 then return end
    for _, playerId in ipairs(GetPlayers()) do
        if GetPlayerPed(tonumber(playerId)) == npc then return end
    end
    local npcCoords = GetEntityCoords(npc)
    if not alive(src) or not nearPoint(src, npcCoords, Config.Robbery.maxDistance) then
        notify(src, 'Approchez-vous d’un passant vivant.', 'error')
        return
    end
    local now = GetGameTimer()
    if robberyCooldowns[src] and now < robberyCooldowns[src] then
        notify(src, 'Vous devez attendre avant de recommencer.', 'warning')
        return
    end
    robberyCooldowns[src] = now + Config.Robbery.cooldown
    local success = math.random(100) <= Config.Robbery.successChance
    local amount = success and math.random(Config.Robbery.minMoney, Config.Robbery.maxMoney) or 0
    if amount > 0 and not player.addCash(amount) then amount = 0 end
    if amount > 0 then notify(src, ('Le passant vous donne %d $.'):format(amount), 'success')
    else notify(src, 'Le passant refuse ou n’a presque rien sur lui.', 'error') end

    if math.random(100) <= Config.Robbery.alertChance then
        dispatchCounter = dispatchCounter + 1
        local id = dispatchCounter
        local coords = GetEntityCoords(GetPlayerPed(src))
        dispatches[id] = { coords = coords, expires = os.time() + Config.Dispatch.expireSeconds, claimed = false }
        local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local street = GetStreetNameFromHashKey(streetHash)
        local call = { id = id, coords = { x = coords.x, y = coords.y, z = coords.z }, street = street or 'Secteur inconnu',
            message = 'Vol avec menace sur un passant' }
        for _, target in ipairs(GetPlayers()) do
            local officer = tonumber(target)
            if isPoliceOnDuty(officer) then TriggerClientEvent('rp_crime:client:dispatch', officer, call) end
        end
    end
end)

RegisterNetEvent('rp_crime:server:acceptDispatch', function(rawId)
    local src, id = source, tonumber(rawId)
    local call = id and dispatches[id]
    if not isPoliceOnDuty(src) or not call or call.claimed or call.expires < os.time() then
        notify(src, 'Intervention indisponible ou déjà prise.', 'error')
        return
    end
    call.claimed = true
    call.officer = src
    TriggerClientEvent('rp_crime:client:dispatchAccepted', src, {
        id = id, coords = { x = call.coords.x, y = call.coords.y, z = call.coords.z },
        street = call.street
    })
    for _, target in ipairs(GetPlayers()) do
        local officer = tonumber(target)
        if officer ~= src and isPoliceOnDuty(officer) then
            TriggerClientEvent('rp_core:client:notify', officer, 'Intervention prise par un autre équipage.', 'info')
        end
    end
end)

CreateThread(function()
    while true do
        Wait(15000)
        for id, call in pairs(dispatches) do
            if call.expires < os.time() then dispatches[id] = nil end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    harvestCooldowns[src], robberyCooldowns[src], activeHarvests[src] = nil, nil, nil
    for id, call in pairs(dispatches) do if call.officer == src then call.claimed, call.officer = false, nil end end
end)
