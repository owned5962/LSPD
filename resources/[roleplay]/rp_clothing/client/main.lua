local isShopOpen = false
local clothingShops = {
    vector3(72.3, -1399.1, 29.4),   -- Binco
    vector3(-703.8, -152.3, 37.4),  -- Ponsonbys
    vector3(-163.2, -303.6, 39.7),  -- Suburban
    vector3(425.6, -806.2, 29.5)    -- Downtown Clothes
}

Citizen.CreateThread(function()
    for _, pos in ipairs(clothingShops) do
        local blip = AddBlipForCoord(pos.x, pos.y, pos.z)
        SetBlipSprite(blip, 73)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 47)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("Magasin de vêtements")
        EndTextCommandSetBlipName(blip)
    end

    while true do
        local sleep = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())

        for _, pos in ipairs(clothingShops) do
            local dist = #(playerCoords - pos)
            if dist < 15.0 then
                sleep = 0
                DrawMarker(20, pos.x, pos.y, pos.z, 0, 0, 0, 0, 0, 0, 0.6, 0.6, 0.6, 56, 189, 248, 150, false, true, 2, false, nil, nil, false)
                if dist < 1.8 then
                    exports['rp_ui']:ShowTextUI("[E] Ouvrir la boutique de vêtements")
                    if IsControlJustPressed(0, 38) then
                        OpenClothingShop()
                    end
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

function OpenClothingShop()
    isShopOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open' })
end

RegisterNUICallback('close', function(data, cb)
    isShopOpen = false
    SetNuiFocus(false, false)
    exports['rp_ui']:HideTextUI()
    cb('ok')
end)

RegisterNUICallback('saveOutfit', function(data, cb)
    TriggerServerEvent('rp_clothing:saveOutfit', data.name, data.skin)
    isShopOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end)
