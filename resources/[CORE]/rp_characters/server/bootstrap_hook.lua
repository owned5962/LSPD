-- Recovery when rp_core has no in-memory session.
-- Prefer a direct server-side bootstrap; never bounce through the client
-- (that path can loop when rp_core keeps requesting bootstrap).

local bootstrapInFlight = {}

AddEventHandler('rp_characters:server:forceBootstrap', function(src)
    src = tonumber(src)
    if not src or src < 1 or not GetPlayerName(src) then return end

    if bootstrapInFlight[src] then
        return
    end

    if type(CheckPlayerBootstrap) ~= 'function' then
        print('[rp_characters] forceBootstrap: CheckPlayerBootstrap not loaded')
        return
    end

    bootstrapInFlight[src] = true
    local ok, err = xpcall(CheckPlayerBootstrap, debug.traceback, src)
    bootstrapInFlight[src] = nil

    if not ok then
        print(('[rp_characters] forceBootstrap crashed for player %s: %s')
            :format(tostring(src), tostring(err)))
    end
end)

AddEventHandler('playerDropped', function()
    bootstrapInFlight[source] = nil
end)
