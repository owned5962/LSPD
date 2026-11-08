local playerInventories = {}

RegisterNetEvent('rp_inventory:requestData', function()
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player then return end

    if not playerInventories[src] then
        -- Default starter items
        playerInventories[src] = {
            { name = 'id_card', count = 1, label = 'Carte d\'identité', weight = 0.1 },
            { name = 'driver_license', count = 1, label = 'Permis de conduire', weight = 0.1 },
            { name = 'phone', count = 1, label = 'Téléphone portable', weight = 0.2 },
            { name = 'bread', count = 3, label = 'Pain', weight = 0.5 },
            { name = 'water', count = 3, label = 'Bouteille d\'eau', weight = 0.5 }
        }
    end

    local currentWeight = 0.0
    for _, item in ipairs(playerInventories[src]) do
        currentWeight = currentWeight + (item.weight * item.count)
    end

    TriggerClientEvent('rp_inventory:receiveData', src, {
        inventory = playerInventories[src],
        currentWeight = currentWeight,
        cash = player.cash or 2500,
        bank = player.bank or 10000
    })
end)

RegisterNetEvent('rp_inventory:useItem', function(itemName)
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player or not playerInventories[src] then return end

    for idx, item in ipairs(playerInventories[src]) do
        if item.name == itemName then
            if item.count > 1 then
                item.count = item.count - 1
            else
                table.remove(playerInventories[src], idx)
            end

            if itemName == 'bread' then
                TriggerClientEvent('rp_core:notify', src, 'success', 'Vous avez mangé un pain.')
            elseif itemName == 'water' then
                TriggerClientEvent('rp_core:notify', src, 'success', 'Vous avez bu une bouteille d\'eau.')
            elseif itemName == 'medikit' then
                TriggerClientEvent('rp_core:notify', src, 'success', 'Vous avez utilisé un kit de secours.')
            else
                TriggerClientEvent('rp_core:notify', src, 'info', 'Objet utilisé : ' .. item.label)
            end
            break
        end
    end
    TriggerClientEvent('rp_inventory:requestData', src)
end)
