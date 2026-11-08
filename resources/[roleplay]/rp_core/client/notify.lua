RegisterNetEvent('rp_core:client:notify', function(message, type, duration)
    type = type or 'info'
    duration = duration or 4000
    
    SetNotificationTextEntry('STRING')
    AddTextComponentSubstringPlayerName(message)
    local title = "~b~ROLEPLAY"
    if type == 'success' then
        title = "~g~SUCCÈS"
    elseif type == 'error' then
        title = "~r~ERREUR"
    elseif type == 'warning' then
        title = "~y~ATTENTION"
    end
    DrawNotification(false, false)
    
    -- Print to chat as fallback
    TriggerEvent('chat:addMessage', {
        color = type == 'error' and {255, 50, 50} or (type == 'success' and {50, 255, 50} or {80, 180, 255}),
        args = {"[RP]", message}
    })
end)
