-- Lightweight recovery path when rp_core loses the in-memory session.
AddEventHandler('rp_characters:server:forceBootstrap', function(src)
    src = tonumber(src)
    if not src or src < 1 or not GetPlayerName(src) then return end
    if type(CheckPlayerBootstrap) ~= 'function' then
        print('[rp_characters] forceBootstrap: CheckPlayerBootstrap not available yet')
        return
    end
    local ok, err = xpcall(CheckPlayerBootstrap, debug.traceback, src)
    if not ok then
        print(('[rp_characters] forceBootstrap crashed for player %s: %s')
            :format(tostring(src), tostring(err)))
    end
end)
