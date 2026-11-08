-- rp_housing_business server
RegisterNetEvent('rp_housing:buyProperty')
AddEventHandler('rp_housing:buyProperty', function(propId, price)
    local _source = source
    local bank = exports['rp_economy']:GetBank(_source)
    if bank >= price then
        exports['rp_economy']:RemoveBank(_source, price)
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 16, 185, 129 },
            multiline = true,
            args = { "DYNASTY 8", "Félicitations ! Vous êtes désormais propriétaire de ce bien. Clés remises." }
        })
    else
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 239, 68, 68 },
            multiline = true,
            args = { "DYNASTY 8", "Fonds bancaires insuffisants." }
        })
    end
end)

RegisterNetEvent('rp_housing:rentProperty')
AddEventHandler('rp_housing:rentProperty', function(propId, price)
    local _source = source
    local bank = exports['rp_economy']:GetBank(_source)
    if bank >= price then
        exports['rp_economy']:RemoveBank(_source, price)
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 56, 189, 248 },
            multiline = true,
            args = { "DYNASTY 8", "Contrat de bail signé ! Premier loyer prélevé ($" .. price .. ")." }
        })
    else
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 239, 68, 68 },
            multiline = true,
            args = { "DYNASTY 8", "Fonds insuffisants pour payer la caution et le premier loyer." }
        })
    end
end)

RegisterNetEvent('rp_housing:buyBusiness')
AddEventHandler('rp_housing:buyBusiness', function(bId, price)
    local _source = source
    local bank = exports['rp_economy']:GetBank(_source)
    if bank >= price then
        exports['rp_economy']:RemoveBank(_source, price)
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 16, 185, 129 },
            multiline = true,
            args = { "DYNASTY 8 EXECUTIVE", "Acte d'acquisition validé ! Vous êtes le nouveau PDG de l'entreprise." }
        })
    else
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 239, 68, 68 },
            multiline = true,
            args = { "DYNASTY 8 EXECUTIVE", "Solde bancaire insuffisant." }
        })
    end
end)

RegisterNetEvent('rp_housing:rentBusiness')
AddEventHandler('rp_housing:rentBusiness', function(bId, price)
    local _source = source
    local bank = exports['rp_economy']:GetBank(_source)
    if bank >= price then
        exports['rp_economy']:RemoveBank(_source, price)
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 56, 189, 248 },
            multiline = true,
            args = { "DYNASTY 8 EXECUTIVE", "Bail commercial activé ($" .. price .. "/semaine)." }
        })
    else
        TriggerClientEvent('chat:addMessage', _source, {
            color = { 239, 68, 68 },
            multiline = true,
            args = { "DYNASTY 8 EXECUTIVE", "Fonds insuffisants pour démarrer le bail commercial." }
        })
    end
end)
