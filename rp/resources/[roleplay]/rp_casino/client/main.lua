local isCasinoOpen = false

Citizen.CreateThread(function()
    local blip = AddBlipForCoord(Config.Entrance.x, Config.Entrance.y, Config.Entrance.z)
    SetBlipSprite(blip, 679) -- Casino icon
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, 60)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("The Diamond Casino & Resort")
    EndTextCommandSetBlipName(blip)

    while true do
        local sleep = 1000
        local pCoords = GetEntityCoords(PlayerPedId())
        local dist = #(pCoords - Config.Entrance)

        if dist < 10.0 then
            sleep = 0
            DrawMarker(29, Config.Entrance.x, Config.Entrance.y, Config.Entrance.z, 0,0,0, 0,0,0, 1.2, 1.2, 1.2, 218, 165, 32, 200, false, true, 2, false, nil, nil, false)
            if dist < 2.0 and not isCasinoOpen then
                SetTextComponentFormat("STRING")
                AddTextComponentString("Appuyez sur ~INPUT_CONTEXT~ pour entrer au ~y~Diamond Casino")
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)

                if IsControlJustReleased(0, 38) then
                    TriggerServerEvent("rp_casino:requestPlayerData")
                end
            end
        end

        Citizen.Wait(sleep)
    end
end)

RegisterNetEvent("rp_casino:openMenu")
AddEventHandler("rp_casino:openMenu", function(chips, isVip)
    isCasinoOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openCasino",
        chips = chips or 0,
        isVip = isVip or false
    })
end)

RegisterNUICallback("close", function(data, cb)
    SetNuiFocus(false, false)
    isCasinoOpen = false
    cb("ok")
end)

RegisterNUICallback("buyChips", function(data, cb)
    TriggerServerEvent("rp_casino:exchangeCashToChips", data.amount)
    cb("ok")
end)

RegisterNUICallback("sellChips", function(data, cb)
    TriggerServerEvent("rp_casino:exchangeChipsToCash", data.amount)
    cb("ok")
end)

RegisterNUICallback("spinWheel", function(data, cb)
    TriggerServerEvent("rp_casino:playLuckyWheel")
    cb("ok")
end)

RegisterNUICallback("playSlots", function(data, cb)
    TriggerServerEvent("rp_casino:spinSlots", data.bet)
    cb("ok")
end)

RegisterNetEvent("rp_casino:updateChips")
AddEventHandler("rp_casino:updateChips", function(chips)
    SendNUIMessage({
        action = "updateChips",
        chips = chips
    })
end)

RegisterNetEvent("rp_casino:slotsResult")
AddEventHandler("rp_casino:slotsResult", function(winAmount, reels)
    SendNUIMessage({
        action = "slotsOutcome",
        win = winAmount,
        reels = reels
    })
end)
