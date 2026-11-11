local function ShowFallbackNotification(message, kind)
    SetNotificationTextEntry('STRING')
    AddTextComponentSubstringPlayerName(tostring(message or ''))
    DrawNotification(false, false)
end

RegisterNetEvent('rp_core:client:notify', function(message, kind, duration)
    kind = kind or 'info'
    if GetResourceState('rp_ui') == 'started' then
        TriggerEvent('rp_ui:notify', message, kind, duration)
    else
        ShowFallbackNotification(message, kind)
    end
end)

-- Compatibility bridge for legacy resources using rp_core:notify(type, message).
RegisterNetEvent('rp_core:notify', function(notificationType, message, duration)
    if type(notificationType) == 'string' and type(message) == 'string' then
        TriggerEvent('rp_core:client:notify', message, notificationType, duration)
    elseif type(notificationType) == 'string' then
        TriggerEvent('rp_core:client:notify', notificationType, 'info', duration)
    end
end)
