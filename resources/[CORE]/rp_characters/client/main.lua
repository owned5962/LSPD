local isCreating = false
local charCamera = nil

-- First-login onboarding. Controls are intentionally simple and do not depend on
-- external UI resources: E = next, Q = previous, Backspace = finish/skip.
local tutorialActive = false
local tutorialStep = 1
local tutorialPages = {
    {
        title = 'BIENVENUE À LOS SANTOS',
        lines = {
            'Bienvenue dans la ville ! Ton personnage commence une nouvelle histoire.',
            'Prends le temps de découvrir la ville et de rencontrer les autres habitants.',
            'Le plus important : joue ton personnage et laisse vivre les scènes RP.'
        }
    },
    {
        title = 'TON INVENTAIRE',
        lines = {
            'Appuie sur F2 pour ouvrir ton inventaire.',
            'Tu peux consulter tes objets et utiliser les objets autorisés.',
            'Tu peux donner ou déposer certains objets depuis cette interface.'
        }
    },
    {
        title = 'TON ARGENT',
        lines = {
            'Tu commences avec 2 500 $ en poche et 10 000 $ en banque.',
            'Utilise /bank pour accéder à ton compte bancaire.',
            'Les principales banques sont indiquées sur ta carte.'
        }
    },
    {
        title = 'TROUVER UN MÉTIER',
        lines = {
            'Rends-toi au Pôle Emploi ou utilise /jobcenter pour découvrir les métiers.',
            'Le serveur propose de nombreux métiers civils et services publics.',
            'Une fois ton métier choisi, rends-toi sur son lieu de travail pour découvrir les interactions disponibles.'
        }
    },
    {
        title = 'INTERAGIR AVEC LES AUTRES',
        lines = {
            'Approche-toi des autres citoyens pour échanger et créer des scènes RP.',
            'Certaines actions nécessitent d’être proche de la personne concernée.',
            'Respecte les scènes en cours et privilégie toujours le dialogue.'
        }
    },
    {
        title = 'LES RÈGLES ESSENTIELLES',
        lines = {
            'Pas de méta-gaming : ne te sers pas d’informations obtenues hors RP.',
            'Pas de power-gaming : laisse aux autres la possibilité de réagir.',
            'Pas de free-kill : toute action doit avoir un contexte RP cohérent.'
        }
    },
    {
        title = 'TU ES PRÊT !',
        lines = {
            'Tu connais maintenant les premières bases pour commencer ton aventure.',
            'Explore la ville, trouve ton activité et construis ton histoire.',
            'Bon jeu et bienvenue sur Los Santos Roleplay !'
        }
    }
}

local function DrawTutorialText(value, x, y, scale, r, g, b, centered)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(r or 245, g or 247, b or 250, 255)
    SetTextCentre(centered == true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(value)
    EndTextCommandDisplayText(x, y)
end

local function FinishTutorial()
    tutorialActive = false
    TriggerServerEvent('rp_characters:server:completeTutorial')
end

RegisterNetEvent('rp_characters:client:startTutorial', function()
    if tutorialActive then return end
    tutorialStep = 1
    tutorialActive = true

    CreateThread(function()
        while tutorialActive and IsPauseMenuActive() do Wait(250) end
        while tutorialActive do
            Wait(0)
            local page = tutorialPages[tutorialStep]
            if not page then
                FinishTutorial()
                break
            end

            DrawRect(0.5, 0.815, 0.68, 0.265, 8, 12, 20, 235)
            DrawRect(0.5, 0.69, 0.68, 0.012, 35, 145, 210, 255)
            DrawTutorialText('LOS SANTOS ROLEPLAY  •  GUIDE DU NOUVEAU', 0.5, 0.705, 0.30, 95, 185, 235, true)
            DrawTutorialText(page.title, 0.5, 0.745, 0.43, 255, 255, 255, true)

            for index, line in ipairs(page.lines) do
                DrawTutorialText(line, 0.19, 0.79 + ((index - 1) * 0.027), 0.30, 225, 230, 238, false)
            end

            DrawTutorialText(('ÉTAPE %d / %d'):format(tutorialStep, #tutorialPages), 0.19, 0.895, 0.27, 130, 145, 160, false)
            DrawTutorialText('Q  Précédent     E  Suivant     RETOUR  Passer', 0.81, 0.895, 0.27, 170, 195, 215, false)

            DisableControlAction(0, 38, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 177, true)

            if IsDisabledControlJustPressed(0, 38) then
                if tutorialStep >= #tutorialPages then
                    FinishTutorial()
                else
                    tutorialStep = tutorialStep + 1
                end
            elseif IsDisabledControlJustPressed(0, 44) then
                tutorialStep = math.max(1, tutorialStep - 1)
            elseif IsDisabledControlJustPressed(0, 177) then
                FinishTutorial()
            end
        end
    end)
end)

local function LoadFreemodeModel(gender)
    local model = joaat(gender == 'f' and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    if not IsModelInCdimage(model) or not IsModelValid(model) then return false end
    if GetEntityModel(PlayerPedId()) == model then return true end
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(model) then return false end
    SetPlayerModel(PlayerId(), model)
    SetModelAsNoLongerNeeded(model)
    SetPedDefaultComponentVariation(PlayerPedId())
    return true
end

local function SetSafeComponent(ped, component, drawable, texture)
    local count = GetNumberOfPedDrawableVariations(ped, component)
    if not count or count < 1 then return end
    drawable = math.max(0, math.min(math.floor(tonumber(drawable) or 0), count - 1))
    local textures = GetNumberOfPedTextureVariations(ped, component, drawable)
    texture = math.max(0, math.min(math.floor(tonumber(texture) or 0), math.max(0, (textures or 1) - 1)))
    SetPedComponentVariation(ped, component, drawable, texture, 0)
end

local function ApplyCharacterAppearance(gender, skin)
    skin = type(skin) == 'table' and skin or {}
    LoadFreemodeModel(gender)
    local ped = PlayerPedId()
    local hairStyle = tonumber(skin.hairStyle) or 0
    local hairCount = GetNumberOfPedDrawableVariations(ped, 2)
    if hairCount and hairCount > 0 then
        hairStyle = math.max(0, math.min(math.floor(hairStyle), hairCount - 1))
        SetPedComponentVariation(ped, 2, hairStyle, 0, 0)
    end
    local hairColor = math.max(0, math.min(math.floor(tonumber(skin.hairColor) or 0), 63))
    SetPedHairColor(ped, hairColor, hairColor)

    local outfits = {
        casual = { pants = 0, shoes = 1, undershirt = 15, top = 15 },
        business = { pants = 10, shoes = 10, undershirt = 10, top = 10 },
        worker = { pants = 36, shoes = 12, undershirt = 59, top = 56 },
        sport = { pants = 5, shoes = 3, undershirt = 15, top = 15 }
    }
    if type(skin.components) == 'table' then
        for component = 0, 11 do
            local saved = skin.components[tostring(component)] or skin.components[component]
            if type(saved) == 'table' then
                SetSafeComponent(ped, component, saved.drawable, saved.texture)
            end
        end
    else
        local outfit = outfits[skin.clothing] or outfits.casual
        SetSafeComponent(ped, 4, outfit.pants, 0)
        SetSafeComponent(ped, 6, outfit.shoes, 0)
        SetSafeComponent(ped, 8, outfit.undershirt, 0)
        SetSafeComponent(ped, 11, outfit.top, 0)
        SetSafeComponent(ped, 3, 0, 0)
    end

    if type(skin.props) == 'table' then
        for prop = 0, 7 do
            local saved = skin.props[tostring(prop)] or skin.props[prop]
            if type(saved) == 'table' then
                local drawable = tonumber(saved.drawable) or -1
                local texture = tonumber(saved.texture) or 0
                if drawable < 0 then
                    ClearPedProp(ped, prop)
                else
                    local propCount = GetNumberOfPedPropDrawableVariations(ped, prop)
                    if propCount and propCount > 0 then
                        drawable = math.min(drawable, propCount - 1)
                        local textureCount = GetNumberOfPedPropTextureVariations(ped, prop, drawable)
                        texture = math.max(0, math.min(texture, math.max(0, (textureCount or 1) - 1)))
                        SetPedPropIndex(ped, prop, drawable, texture, true)
                    end
                end
            end
        end
    end
end

local function OpenCreator(maxCharacters)
    SetNuiFocus(true, true)
    ApplyCharacterAppearance('m', { hairStyle = 4, hairColor = 0, clothing = 'casual' })
    SendNUIMessage({ action = 'openRegistration', maxCharacters = maxCharacters or 3 })
    isCreating = true
    SetupCreatorCamera()
end

function SetupCreatorCamera()
    local ped = PlayerPedId()
    SetEntityCoords(ped, -1042.0, -2745.0, 21.3, false, false, false, true)
    SetEntityHeading(ped, 330.0)
    FreezeEntityPosition(ped, true)
    charCamera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(charCamera, -1040.8, -2743.0, 21.6)
    PointCamAtEntity(charCamera, ped, 0.0, 0.0, 0.2, true)
    SetCamActive(charCamera, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function CloseCharacterUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeRegistration' })
    SendNUIMessage({ action = 'closeCharacterSelection' })
    if charCamera then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(charCamera, false)
        charCamera = nil
    end
    FreezeEntityPosition(PlayerPedId(), false)
    isCreating = false
end

RegisterNUICallback('beginCreation', function(data, cb)
    CloseCharacterUI()
    OpenCreator(3)
    cb({ status = 'ok' })
end)

RegisterNUICallback('saveCharacter', function(data, cb)
    TriggerServerEvent('rp_characters:server:createCharacter', data)
    cb({ status = 'submitted' })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    TriggerServerEvent('rp_characters:server:selectCharacter', data.slot)
    cb({ status = 'submitted' })
end)

RegisterNUICallback('updateSkinPreview', function(data, cb)
    if type(data) == 'table' then ApplyCharacterAppearance(data.gender, data.skin) end
    cb({ status = 'ok' })
end)

RegisterNetEvent('rp_characters:client:openMenu', function(maxCharacters)
    OpenCreator(maxCharacters)
end)

RegisterNetEvent('rp_characters:client:openCharacterSelection', function(characters, maxCharacters)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCharacterSelection', characters = characters, maxCharacters = maxCharacters or 3 })
end)

RegisterNetEvent('rp_characters:client:closeMenu', function()
    CloseCharacterUI()
end)

RegisterNetEvent('rp_characters:client:spawnPlayer', function(coords, gender, skin)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end
    ApplyCharacterAppearance(gender, skin)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    SetEntityHeading(ped, coords.heading or 0.0)
    FreezeEntityPosition(ped, false)
    Wait(500)
    DoScreenFadeIn(1000)
    Wait(1500)
    TriggerServerEvent('rp_characters:server:requestTutorial')
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(2000)
    TriggerServerEvent('rp_characters:server:checkPlayer')
end)
