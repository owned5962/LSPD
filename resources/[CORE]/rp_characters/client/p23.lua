            -- Force fade-out but never wait forever (black-screen hang guard).
            DoScreenFadeOut(300)
            local fadeStartedAt = GetGameTimer() % SPAWN_TIMER_MODULUS
            while not IsScreenFadedOut() and not SpawnWaitExpired(fadeStartedAt, 2500) do
                Wait(10)
            end
            if not IsScreenFadedOut() then
                -- Some clients never report faded-out; continue the pipeline anyway.
                print('[rp_characters] Fade-out did not complete in time; continuing spawn.')
            end

            local appearanceApplied = ApplyCharacterAppearance(gender, skin)
            ped = PlayerPedId()
            if not appearanceApplied then
                print('[rp_characters] Appearance fallback was required; applying GTA default components.')
                SetPedDefaultComponentVariation(ped)
            end

            FreezeEntityPosition(ped, true)
            SetEntityCoordsNoOffset(ped, spawnX, spawnY, spawnZ, false, false, false)
            SetEntityHeading(ped, spawnHeading)
            RequestCollisionAtCoord(spawnX, spawnY, spawnZ)
            SetFocusPosAndVel(spawnX, spawnY, spawnZ, 0.0, 0.0, 0.0)

            local collisionStartedAt = GetGameTimer() % SPAWN_TIMER_MODULUS
            while not HasCollisionLoadedAroundEntity(ped)
                and not SpawnWaitExpired(collisionStartedAt, 8000) do
                RequestCollisionAtCoord(spawnX, spawnY, spawnZ)
                Wait(50)
