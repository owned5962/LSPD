local playerInventories = {}

RegisterNetEvent('rp_inventory:requestData', function()
    local src = source
    local player = exports['rp_core']:GetPlayer(src)
    if not player then return end

    if not playerInventories[src] then
        -- Inventaire initial avec nourriture et boisson diversifiées
        playerInventories[src] = {
            { name = 'id_card', count = 1, label = Config.DefaultItems['id_card'].label, weight = Config.DefaultItems['id_card'].weight },
            { name = 'driver_license', count = 1, label = Config.DefaultItems['driver_license'].label, weight = Config.DefaultItems['driver_license'].weight },
            { name = 'phone', count = 1, label = Config.DefaultItems['phone'].label, weight = Config.DefaultItems['phone'].weight },
            { name = 'bread', count = 2, label = Config.DefaultItems['bread'].label, weight = Config.DefaultItems['bread'].weight },
            { name = 'burger_bleeder', count = 2, label = Config.DefaultItems['burger_bleeder'].label, weight = Config.DefaultItems['burger_bleeder'].weight },
            { name = 'water', count = 3, label = Config.DefaultItems['water'].label, weight = Config.DefaultItems['water'].weight },
            { name = 'soda_ecola', count = 2, label = Config.DefaultItems['soda_ecola'].label, weight = Config.DefaultItems['soda_ecola'].weight },
            { name = 'coffee', count = 1, label = Config.DefaultItems['coffee'].label, weight = Config.DefaultItems['coffee'].weight }
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

    local itemDef = Config.DefaultItems[itemName]

    for idx, item in ipairs(playerInventories[src]) do
        if item.name == itemName then
            if item.count > 1 then
                item.count = item.count - 1
            else
                table.remove(playerInventories[src], idx)
            end

            if itemDef then
                if itemDef.type == 'food' then
                    TriggerClientEvent('rp_core:notify', src, 'success', string.format('Vous mangez : %s (+%d faim)', itemDef.label, itemDef.hunger or 20))
                elseif itemDef.type == 'drink' then
                    TriggerClientEvent('rp_core:notify', src, 'success', string.format('Vous buvez : %s (+%d soif)', itemDef.label, itemDef.thirst or 25))
                elseif itemDef.type == 'medical' then
                    TriggerClientEvent('rp_core:notify', src, 'success', string.format('Vous utilisez : %s (+%d PV)', itemDef.label, itemDef.heal or 50))
                else
                    TriggerClientEvent('rp_core:notify', src, 'info', 'Objet utilisé : ' .. itemDef.label)
                end
            else
                TriggerClientEvent('rp_core:notify', src, 'info', 'Objet utilisé : ' .. item.label)
            end
            break
        end
    end
    TriggerClientEvent('rp_inventory:requestData', src)
end)
