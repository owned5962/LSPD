local playerChips = {}

RegisterNetEvent("rp_casino:requestPlayerData")
AddEventHandler("rp_casino:requestPlayerData", function()
    local src = source
    local chips = playerChips[src] or 1500
    playerChips[src] = chips
    TriggerClientEvent("rp_casino:openMenu", src, chips, true)
end)

RegisterNetEvent("rp_casino:exchangeCashToChips")
AddEventHandler("rp_casino:exchangeCashToChips", function(amount)
    local src = source
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local cash = exports['rp_economy']:getCash(src) or 0
    if cash < amount then
        TriggerClientEvent("rp_core:showNotification", src, "~r~Fonds insuffisants en espèces !")
        return
    end

    exports['rp_economy']:removeCash(src, amount)
    playerChips[src] = (playerChips[src] or 0) + amount
    TriggerClientEvent("rp_casino:updateChips", src, playerChips[src])
    TriggerClientEvent("rp_core:showNotification", src, "~g~Achat effectué : " .. amount .. " jetons crédités.")
end)

RegisterNetEvent("rp_casino:exchangeChipsToCash")
AddEventHandler("rp_casino:exchangeChipsToCash", function(amount)
    local src = source
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    local current = playerChips[src] or 0
    if current < amount then
        TriggerClientEvent("rp_core:showNotification", src, "~r~Vous n'avez pas assez de jetons !")
        return
    end

    playerChips[src] = current - amount
    exports['rp_economy']:addCash(src, amount)
    TriggerClientEvent("rp_casino:updateChips", src, playerChips[src])
    TriggerClientEvent("rp_core:showNotification", src, "~g~Encaissement réussi : $" .. amount .. " en espèces remis.")
end)

RegisterNetEvent("rp_casino:spinSlots")
AddEventHandler("rp_casino:spinSlots", function(bet)
    local src = source
    bet = tonumber(bet) or 100
    local current = playerChips[src] or 0
    if current < bet then
        TriggerClientEvent("rp_core:showNotification", src, "~r~Jetons insuffisants !")
        return
    end

    playerChips[src] = current - bet
    local symbols = {"🍒", "🔔", "🍇", "💎", "7️⃣"}
    local r1 = symbols[math.random(1, #symbols)]
    local r2 = symbols[math.random(1, #symbols)]
    local r3 = symbols[math.random(1, #symbols)]
    local win = 0

    if r1 == r2 and r2 == r3 then
        if r1 == "7️⃣" then win = bet * 50
        elseif r1 == "💎" then win = bet * 20
        else win = bet * 5 end
    elseif r1 == r2 or r2 == r3 or r1 == r3 then
        win = math.floor(bet * 1.5)
    end

    if win > 0 then
        playerChips[src] = playerChips[src] + win
    end

    TriggerClientEvent("rp_casino:slotsResult", src, win, {r1, r2, r3})
    TriggerClientEvent("rp_casino:updateChips", src, playerChips[src])
end)
