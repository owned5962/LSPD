                ped = PlayerPedId()
            end
            collisionLoaded = HasCollisionLoadedAroundEntity(ped)
            if not collisionLoaded then
                print('[rp_characters] Spawn collision streaming timed out; recovering with a visible player.')
            end
        end, debug.traceback)

        -- Mandatory finalizer: execute each recovery action independently so
        -- one failed native cannot prevent the remaining display/control fixes.
        local function recover(label, callback)
            local ok, err = pcall(callback)
            if not ok then
                print(('[rp_characters] Spawn recovery step "%s" failed: %s'):format(label, tostring(err)))
            end
        end

        ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            recover('position', function()
                SetEntityCoordsNoOffset(ped, spawnX, spawnY, spawnZ, false, false, false)
                SetEntityHeading(ped, spawnHeading)
            end)
            recover('visibility', function()
                SetEntityVisible(ped, true, false)
                ResetEntityAlpha(ped)
