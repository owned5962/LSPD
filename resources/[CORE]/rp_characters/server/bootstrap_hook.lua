-- Recovery when rp_core has no in-memory session.
-- Invokes the same path as the client net event without needing a global function.
AddEventHandler('rp_characters:server:forceBootstrap', function(src)
    src = tonumber(src)
    if not src or src < 1 or not GetPlayerName(src) then return end
    -- Re-enter the public bootstrap entrypoint used by clients.
    local ok, err = pcall(function()
        -- Temporarily bind source for event-style handlers is not possible;
        -- call checkPlayer logic via TriggerEvent is unreliable.
        -- Instead: ask the client to re-request checkPlayer (source is preserved).
        TriggerClientEvent('rp_core:client:requestCharacterBootstrap', src)
    end)
    if not ok then
        print(('[rp_characters] forceBootstrap failed for %s: %s'):format(tostring(src), tostring(err)))
    else
        print(('[rp_characters] forceBootstrap: asked client %s to re-check account'):format(tostring(src)))
    end
end)
