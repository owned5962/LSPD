local atmCooldowns = {}
local bankCooldowns = {}

-- Obtenir le nombre de policiers connectés
function GetPoliceCount()
    local count = 0
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local user = exports['rp_core']:GetUser(tonumber(playerId))
        if user and (user.job == 'police' or user.job == 'sheriff' or user.job == 'swat' or user.job == 'fib') then
            count = count + 1
        end
    end
    return count
end

-- Alerter tous les policiers
function NotifyPolice(coords, title, text)
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local user = exports['rp_core']:GetUser(tonumber(playerId))
        if user and (user.job == 'police' or user.job == 'sheriff' or user.job == 'swat' or user.job == 'fib') then
            TriggerClientEvent('rp_robberies:policeAlert', tonumber(playerId), coords, title, text)
        end
    end
end

-- Demande de piratage ATM
RegisterNetEvent('rp_robberies:requestStartATM', function(coords)
    local src = source
    local now = os.time()

    local cops = GetPoliceCount()
    if cops < Config.RequiredCops.ATM then
        TriggerClientEvent('rp_core:notify', src, "Il n'y a pas assez de policiers en ville pour cette action (" .. cops .. "/" .. Config.RequiredCops.ATM .. ")", "error")
        return
    end

    -- Hash de position pour cooldown d'ATM spécifique
    local atmKey = string.format("%.1f_%.1f", coords.x, coords.y)
    if atmCooldowns[atmKey] and (now - atmCooldowns[atmKey] < Config.Cooldowns.ATM) then
        local remaining = Config.Cooldowns.ATM - (now - atmCooldowns[atmKey])
        TriggerClientEvent('rp_core:notify', src, "Ce distributeur a déjà été vidé récemment. Réessayez dans " .. remaining .. "s.", "error")
        return
    end

    atmCooldowns[atmKey] = now
    TriggerClientEvent('rp_robberies:startMinigame', src, 'ATM', atmKey, 20)
    
    -- 50% de chance d'alerter les forces de l'ordre dès le début du piratage
    if math.random(1, 100) <= 50 then
        NotifyPolice(coords, "PIRATAGE DAB DÉTECTÉ", "Un individu tente de pirater un distributeur automatique !")
    end
end)

-- Demande de braquage de Banque
RegisterNetEvent('rp_robberies:requestStartBank', function(bankId)
    local src = source
    local now = os.time()

    local targetBank = nil
    for _, b in ipairs(Config.Banks) do
        if b.id == bankId then
            targetBank = b
            break
        end
    end

    if not targetBank then return end

    local requiredCops = targetBank.type == 'CentralBank' and Config.RequiredCops.CentralBank or Config.RequiredCops.Fleeca
    local cops = GetPoliceCount()

    if cops < requiredCops then
        TriggerClientEvent('rp_core:notify', src, "Effectifs de police insuffisants (" .. cops .. "/" .. requiredCops .. ")", "error")
        return
    end

    local cooldownTime = targetBank.type == 'CentralBank' and Config.Cooldowns.CentralBank or Config.Cooldowns.Fleeca
    if bankCooldowns[bankId] and (now - bankCooldowns[bankId] < cooldownTime) then
        local remaining = math.ceil((cooldownTime - (now - bankCooldowns[bankId])) / 60)
        TriggerClientEvent('rp_core:notify', src, "Cette banque a déjà été braquée récemment. Coffre verrouillé pour encore " .. remaining .. " minutes.", "error")
        return
    end

    bankCooldowns[bankId] = now
    TriggerClientEvent('rp_robberies:startMinigame', src, targetBank.type, bankId, targetBank.timeToRob)

    -- Alerte automatique de l'alarme silencieuse
    NotifyPolice(targetBank.coords, "BRAQUAGE MAJEUR EN COURS", "Alarme intrusion déclenchée à : " .. targetBank.name)
end)

-- Braquage réussi
RegisterNetEvent('rp_robberies:completeRobbery', function(type, targetId)
    local src = source
    local user = exports['rp_core']:GetUser(src)
    if not user then return end

    local reward = 0
    if type == 'ATM' then
        reward = math.random(Config.Rewards.ATM.min, Config.Rewards.ATM.max)
        TriggerClientEvent('rp_core:notify', src, "Braquage du DAB réussi ! Vous avez extrait " .. reward .. " $ en coupures non marquées.", "success")
    elseif type == 'Fleeca' then
        reward = math.random(Config.Rewards.Fleeca.min, Config.Rewards.Fleeca.max)
        TriggerClientEvent('rp_core:notify', src, "Coffre Fleeca dévalisé ! Butin récupéré : " .. reward .. " $.", "success")
    elseif type == 'CentralBank' then
        reward = math.random(Config.Rewards.CentralBank.min, Config.Rewards.CentralBank.max)
        TriggerClientEvent('rp_core:notify', src, "CASSE DU SIÈCLE RÉUSSI ! Butin de la Banque Centrale : " .. reward .. " $ !", "success")
    end

    if reward > 0 then
        exports['rp_economy']:AddMoney(src, 'cash', reward)
    end
end)

-- Échec du piratage
RegisterNetEvent('rp_robberies:hackFailed', function(type, targetId)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    NotifyPolice(coords, "TENTATIVE D'INTRUSION ÉCHOUÉE", "L'alarme a retenti suite à une tentative d'intrusion manquée !")
end)
