            DoScreenFadeOut(500)
            local fadeStartedAt = GetGameTimer() % SPAWN_TIMER_MODULUS
            while not IsScreenFadedOut() and not SpawnWaitExpired(fadeStartedAt, 5000) do
                Wait(10)
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
                and not SpawnWaitExpired(collisionStartedAt, 10000) do
                RequestCollisionAtCoord(spawnX, spawnY, spawnZ)
                Wait(50)
