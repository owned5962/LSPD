const state = {
    players: [],
    protections: {},
    logs: [],
    bans: [],
    selectedPlayerId: null,
    spectatingId: null,
    currentTab: 'dashboard'
};

const $ = (id) => document.getElementById(id);
const nui = (name, payload = {}) => fetch(`https://rp_anticheat/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
}).then((response) => response.json().catch(() => ({})));

const tabTitles = {
    dashboard: ['VUE GÉNÉRALE', 'Tableau de bord'],
    protections: ['PROTECTIONS', 'Centre des protections'],
    players: ['JOUEURS', 'Joueurs connectés'],
    surveillance: ['SURVEILLANCE', 'Surveillance en direct'],
    logs: ['DÉTECTIONS', 'Centre des détections'],
    bans: ['BANNISSEMENTS', 'Gestion des bannissements']
};

function escapeText(value) {
    return String(value ?? '');
}

function showToast(message, isError = false) {
    const region = $('toast-region');
    if (!region) return;
    const toast = document.createElement('div');
    toast.className = 'toast' + (isError ? ' error' : '');
    toast.textContent = message;
    region.appendChild(toast);
    window.setTimeout(() => toast.remove(), 3200);
}

function setTab(tab) {
    if (!tabTitles[tab]) return;
    state.currentTab = tab;
    document.querySelectorAll('.nav-item').forEach((button) => {
        button.classList.toggle('active', button.dataset.tab === tab);
    });
    document.querySelectorAll('.tab-pane').forEach((pane) => {
        pane.classList.toggle('active', pane.id === `pane-${tab}`);
    });
    $('section-name').textContent = tabTitles[tab][0];
    $('page-title').textContent = tabTitles[tab][1];
    if (tab === 'logs') nui('requestLogs').catch(() => showToast('Impossible de charger les détections.', true));
    if (tab === 'bans') nui('requestBans').catch(() => showToast('Impossible de charger les bannissements.', true));
    if (tab === 'players' || tab === 'surveillance') renderPlayers();
}

function updateClock() {
    $('current-clock').textContent = new Date().toLocaleTimeString('fr-FR', { hour12: false });
}

function renderDashboard() {
    const active = Object.values(state.protections).filter((item) => item && item.enabled === true).length;
    $('stat-players').textContent = state.players.length;
    $('stat-threats').textContent = state.logs.length;
    $('stat-modules').textContent = `${active}/${Object.keys(state.protections).length}`;
    $('stat-bans').textContent = state.bans.length || '0';
    $('nav-protection-count').textContent = Object.keys(state.protections).length;
    $('nav-alert-count').textContent = state.logs.length;

    const feed = $('dashboard-alerts');
    feed.replaceChildren();
    if (!state.logs.length) {
        feed.innerHTML = '<div class="empty-state">Aucune anomalie signalée pour le moment.</div>';
    } else {
        state.logs.slice(0, 5).forEach((alert) => {
            const row = document.createElement('div');
            row.className = 'alert-row';
            const mark = document.createElement('div');
            mark.className = 'alert-mark';
            mark.innerHTML = '<i class="fa-solid fa-triangle-exclamation"></i>';
            const details = document.createElement('div');
            details.style.minWidth = '0';
            const title = document.createElement('strong');
            title.textContent = `${alert.playerName || 'Joueur inconnu'} · ID ${alert.playerId ?? '?'}`;
            const reason = document.createElement('small');
            reason.textContent = alert.reason || 'Détection';
            details.append(title, reason);
            const time = document.createElement('span');
            time.className = 'alert-time';
            time.textContent = alert.time || '--:--:--';
            row.append(mark, details, time);
            feed.appendChild(row);
        });
    }

    const modules = $('dashboard-protections');
    modules.replaceChildren();
    Object.entries(state.protections).forEach(([key, protection]) => {
        const line = document.createElement('div');
        line.className = 'module-line';
        const label = document.createElement('span');
        label.textContent = protection.label || key;
        const status = document.createElement('b');
        status.textContent = protection.enabled ? 'ACTIF' : 'INACTIF';
        status.style.color = protection.enabled ? 'var(--green)' : 'var(--muted)';
        const bar = document.createElement('div');
        bar.className = 'module-bar';
        const fill = document.createElement('i');
        fill.style.width = protection.enabled ? '100%' : '0%';
        bar.appendChild(fill);
        const wrap = document.createElement('div');
        wrap.append(line, bar);
        line.append(label, status);
        modules.appendChild(wrap);
    });
}

function renderProtections() {
    const grid = $('protections-list');
    grid.replaceChildren();
    const icons = {
        godmode: 'fa-heart-pulse',
        speedhack: 'fa-person-running',
        blacklisted_weapons: 'fa-gun',
        thermal_night_vision: 'fa-eye',
        spectate_monitoring: 'fa-video',
        explosion_spam: 'fa-bomb',
        weapon_damage: 'fa-crosshairs'
    };
    const descriptions = {
        godmode: 'Signale les états d’invincibilité suspects. Des faux positifs restent possibles selon les scripts serveur.',
        speedhack: 'Surveille les déplacements à pied anormalement rapides.',
        blacklisted_weapons: 'Détecte et retire les armes interdites configurées.',
        thermal_night_vision: 'Détecte les modes de vision thermique et nocturne non autorisés.',
        spectate_monitoring: 'Autorise l’équipe habilitée à observer les joueurs en jeu.',
        explosion_spam: 'Limite les rafales d’explosions reçues côté serveur.',
        weapon_damage: 'Bloque les dégâts provenant des armes de la liste noire.'
    };

    Object.entries(state.protections).forEach(([key, protection]) => {
        const card = document.createElement('article');
        card.className = 'protection-card';
        const info = document.createElement('div');
        info.className = 'prot-info';
        const icon = document.createElement('div');
        icon.className = 'prot-icon';
        icon.innerHTML = `<i class="fa-solid ${icons[key] || 'fa-shield'}"></i>`;
        const copy = document.createElement('div');
        const title = document.createElement('h5');
        title.textContent = protection.label || key;
        const desc = document.createElement('p');
        desc.textContent = descriptions[key] || 'Protection Anticheat configurable.';
        copy.append(title, desc);
        info.append(icon, copy);
        const label = document.createElement('label');
        label.className = 'switch';
        const input = document.createElement('input');
        input.type = 'checkbox';
        input.checked = protection.enabled === true;
        input.addEventListener('change', () => {
            input.disabled = true;
            nui('toggleProtection', { protectionKey: key, state: input.checked })
                .then(() => showToast('Demande de modification envoyée.'))
                .catch(() => {
                    input.checked = !input.checked;
                    showToast('Impossible de modifier cette protection.', true);
                })
                .finally(() => { input.disabled = false; });
        });
        const slider = document.createElement('span');
        slider.className = 'slider';
        label.append(input, slider);
        card.append(info, label);
        grid.appendChild(card);
    });
    updateProtectionStats();
}

function updateProtectionStats() {
    const active = Object.values(state.protections).filter((item) => item && item.enabled === true).length;
    $('stat-modules').textContent = `${active}/${Object.keys(state.protections).length}`;
}

function playerDisplayName(player) {
    return escapeText(player.name || player.rawName || `Joueur ${player.id}`);
}

function renderPlayers() {
    const query = ($('player-search')?.value || '').trim().toLowerCase();
    const filtered = state.players.filter((player) =>
        playerDisplayName(player).toLowerCase().includes(query) || String(player.id).includes(query)
    );
    $('player-list-count').textContent = `${filtered.length}`;
    const list = $('players-list');
    list.replaceChildren();
    if (!filtered.length) {
        const empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.textContent = state.players.length ? 'Aucun joueur ne correspond à la recherche.' : 'Aucun joueur connecté.';
        list.appendChild(empty);
    }
    filtered.forEach((player) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'player-row' + (Number(player.id) === Number(state.selectedPlayerId) ? ' selected' : '');
        const avatar = document.createElement('span');
        avatar.className = 'avatar';
        avatar.textContent = playerDisplayName(player).slice(0, 1).toUpperCase();
        const meta = document.createElement('span');
        meta.className = 'player-meta';
        const name = document.createElement('strong');
        name.textContent = playerDisplayName(player);
        const sub = document.createElement('small');
        sub.textContent = `ID ${player.id} · ${player.job || 'Sans emploi'}`;
        meta.append(name, sub);
        const ping = document.createElement('span');
        ping.className = 'ping';
        ping.textContent = `${Number(player.ping) || 0} ms`;
        button.append(avatar, meta, ping);
        button.addEventListener('click', () => {
            state.selectedPlayerId = Number(player.id);
            renderPlayers();
            renderPlayerDetail();
        });
        list.appendChild(button);
    });
    const surveillance = $('surveillance-players');
    surveillance.replaceChildren();
    state.players.forEach((player) => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'player-row' + (Number(player.id) === Number(state.selectedPlayerId) ? ' selected' : '');
        const avatar = document.createElement('span');
        avatar.className = 'avatar';
        avatar.textContent = playerDisplayName(player).slice(0, 1).toUpperCase();
        const meta = document.createElement('span');
        meta.className = 'player-meta';
        const name = document.createElement('strong');
        name.textContent = playerDisplayName(player);
        const sub = document.createElement('small');
        sub.textContent = `ID ${player.id} · ${Number(player.ping) || 0} ms`;
        meta.append(name, sub);
        button.append(avatar, meta);
        button.addEventListener('click', () => {
            state.selectedPlayerId = Number(player.id);
            renderPlayers();
            renderPlayerDetail();
            updateTelemetry(player);
        });
        surveillance.appendChild(button);
    });
    renderPlayerDetail();
}

function renderPlayerDetail() {
    const panel = $('player-detail');
    const player = state.players.find((item) => Number(item.id) === Number(state.selectedPlayerId));
    panel.replaceChildren();
    if (!player) {
        const empty = document.createElement('div');
        empty.className = 'detail-empty';
        empty.innerHTML = '<i class="fa-solid fa-user-shield"></i><strong>Aucun joueur sélectionné</strong><span>Sélectionne un joueur dans la liste pour afficher ses informations.</span>';
        panel.appendChild(empty);
        return;
    }
    const head = document.createElement('div');
    head.className = 'detail-head';
    const avatar = document.createElement('span');
    avatar.className = 'avatar';
    avatar.textContent = playerDisplayName(player).slice(0, 1).toUpperCase();
    const title = document.createElement('div');
    const name = document.createElement('strong');
    name.textContent = playerDisplayName(player);
    const meta = document.createElement('small');
    meta.textContent = `ID ${player.id} · ${player.job || 'Sans emploi'}`;
    title.append(name, meta);
    head.append(avatar, title);
    panel.appendChild(head);

    const stats = document.createElement('div');
    stats.className = 'detail-stats';
    const values = [
        ['SANTÉ', `${Math.max(0, Math.round((Number(player.health) || 0) / 2))}%`],
        ['ARMURE', `${Math.max(0, Number(player.armor) || 0)}%`],
        ['PING', `${Number(player.ping) || 0} ms`],
        ['ARGENT', `$${Number(player.cash) || 0}`],
        ['BANQUE', `$${Number(player.bank) || 0}`],
        ['INSTANCE', escapeText(player.routingBucket ?? '—')]
    ];
    values.forEach(([label, value]) => {
        const cell = document.createElement('div');
        cell.className = 'detail-stat';
        const small = document.createElement('small');
        small.textContent = label;
        const strong = document.createElement('strong');
        strong.textContent = value;
        cell.append(small, strong);
        stats.appendChild(cell);
    });
    panel.appendChild(stats);
    const actions = document.createElement('div');
    actions.className = 'detail-actions';
    const observe = document.createElement('button');
    observe.className = 'primary-btn';
    observe.innerHTML = '<i class="fa-solid fa-eye"></i> Observer';
    observe.addEventListener('click', () => startSpectate(player.id));
    const kick = document.createElement('button');
    kick.className = 'secondary-btn';
    kick.innerHTML = '<i class="fa-solid fa-user-xmark"></i> Kick';
    kick.addEventListener('click', () => punish(player.id, 'kick'));
    const ban = document.createElement('button');
    ban.className = 'danger-btn';
    ban.innerHTML = '<i class="fa-solid fa-ban"></i> Bannir';
    ban.addEventListener('click', () => punish(player.id, 'ban'));
    actions.append(observe, kick, ban);
    panel.appendChild(actions);
}

function updateTelemetry(player) {
    $('cam-target-name').textContent = `${playerDisplayName(player)} · ID ${player.id}`;
    $('telemetry-hp').textContent = `${Math.max(0, Math.round((Number(player.health) || 0) / 2))}%`;
    $('telemetry-armor').textContent = `${Math.max(0, Number(player.armor) || 0)}%`;
    $('telemetry-ping').textContent = `${Number(player.ping) || 0} ms`;
}

function startSpectate(targetId) {
    if (!targetId || Number(targetId) === Number(window.GetPlayerServerId)) return;
    state.selectedPlayerId = Number(targetId);
    nui('spectatePlayer', { targetId: Number(targetId) })
        .then(() => showToast('Demande de surveillance envoyée.'))
        .catch(() => showToast('Impossible de lancer la surveillance.', true));
}

function punish(targetId, type) {
    const label = type === 'ban' ? 'bannir définitivement' : 'expulser';
    if (!window.confirm(`Confirmer : ${label} le joueur ID ${targetId} ?`)) return;
    const reason = window.prompt('Motif de la sanction :', 'Triche / comportement interdit');
    if (reason === null) return;
    nui('punishPlayer', { targetId: Number(targetId), punishType: type, reason: reason.slice(0, 180) })
        .then(() => showToast('Demande de sanction envoyée.'))
        .catch(() => showToast('Échec de la demande de sanction.', true));
}

function renderLogs() {
    const body = $('logs-table-body');
    const query = ($('log-search')?.value || '').trim().toLowerCase();
    const filtered = state.logs.filter((log) =>
        `${log.playerName || ''} ${log.playerId || ''} ${log.reason || ''}`.toLowerCase().includes(query)
    );
    body.replaceChildren();
    if (!filtered.length) {
        const row = document.createElement('tr');
        const cell = document.createElement('td');
        cell.colSpan = 5;
        cell.className = 'empty-state';
        cell.textContent = state.logs.length ? 'Aucune détection ne correspond au filtre.' : 'Aucune détection enregistrée.';
        row.appendChild(cell);
        body.appendChild(row);
        return;
    }
    filtered.forEach((log) => {
        const row = document.createElement('tr');
        const time = document.createElement('td');
        time.textContent = log.time || '--:--:--';
        const player = document.createElement('td');
        player.textContent = `${log.playerName || 'Joueur inconnu'} (ID ${log.playerId ?? '?'})`;
        const reason = document.createElement('td');
        reason.textContent = log.reason || 'Détection';
        const severity = document.createElement('td');
        const badge = document.createElement('span');
        badge.className = 'severity';
        badge.textContent = log.severity || 'ALERTE';
        severity.appendChild(badge);
        const action = document.createElement('td');
        const kick = document.createElement('button');
        kick.className = 'small-action';
        kick.textContent = 'Sanction';
        kick.addEventListener('click', () => punish(log.playerId, 'kick'));
        action.appendChild(kick);
        row.append(time, player, reason, severity, action);
        body.appendChild(row);
    });
}

function renderBans() {
    const body = $('bans-table-body');
    body.replaceChildren();
    if (!state.bans.length) {
        const row = document.createElement('tr');
        const cell = document.createElement('td');
        cell.colSpan = 5;
        cell.className = 'empty-state';
        cell.textContent = 'Aucun bannissement enregistré.';
        row.appendChild(cell);
        body.appendChild(row);
        return;
    }
    state.bans.forEach((ban) => {
        const row = document.createElement('tr');
        const identifier = document.createElement('td');
        identifier.textContent = ban.identifier || '—';
        const reason = document.createElement('td');
        reason.textContent = ban.reason || 'Sans motif';
        const by = document.createElement('td');
        by.textContent = ban.banned_by || '—';
        const date = document.createElement('td');
        date.textContent = ban.created_at || '—';
        const action = document.createElement('td');
        const button = document.createElement('button');
        button.className = 'small-action';
        button.textContent = 'Débannir';
        button.addEventListener('click', () => {
            if (!window.confirm(`Lever le bannissement de ${ban.identifier} ?`)) return;
            nui('unban', { identifier: ban.identifier })
                .then(() => showToast('Demande de débannissement envoyée.'))
                .catch(() => showToast('Impossible de lever ce bannissement.', true));
        });
        action.appendChild(button);
        row.append(identifier, reason, by, date, action);
        body.appendChild(row);
    });
    $('stat-bans').textContent = state.bans.length;
}

function closeUI() {
    $('anticheat-window').classList.add('hidden');
    nui('close').catch(() => {});
}

function refreshAll() {
    nui('requestLogs').catch(() => {});
    nui('requestBans').catch(() => {});
    showToast('Actualisation demandée.');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') {
        state.players = Array.isArray(data.players) ? data.players : [];
        state.protections = data.protections || {};
        state.logs = Array.isArray(data.logs) ? data.logs : [];
        $('anticheat-window').classList.remove('hidden');
        setTab('dashboard');
        renderProtections();
        renderPlayers();
        renderLogs();
        renderDashboard();
        nui('requestBans').catch(() => {});
    } else if (data.action === 'protections') {
        state.protections = data.protections || {};
        renderProtections();
        renderDashboard();
    } else if (data.action === 'updatePlayers') {
        state.players = Array.isArray(data.players) ? data.players : [];
        renderPlayers();
        renderDashboard();
    } else if (data.action === 'updateLogs') {
        state.logs = Array.isArray(data.logs) ? data.logs : [];
        renderLogs();
        renderDashboard();
    } else if (data.action === 'updateBans') {
        state.bans = Array.isArray(data.bans) ? data.bans : [];
        renderBans();
        renderDashboard();
    } else if (data.action === 'newDetection') {
        if (data.alert) {
            state.logs.unshift(data.alert);
            state.logs = state.logs.slice(0, 250);
            renderLogs();
            renderDashboard();
        }
    } else if (data.action === 'spectateStarted') {
        state.spectatingId = Number(data.targetId);
        showToast(`Surveillance active · ID ${data.targetId}`);
    } else if (data.action === 'spectateStopped') {
        state.spectatingId = null;
        showToast('Surveillance arrêtée.');
    } else if (data.action === 'close') {
        $('anticheat-window').classList.add('hidden');
    }
});

document.querySelectorAll('.nav-item').forEach((button) => button.addEventListener('click', () => setTab(button.dataset.tab)));
document.querySelectorAll('[data-goto]').forEach((button) => button.addEventListener('click', () => setTab(button.dataset.goto)));
$('btn-close').addEventListener('click', closeUI);
$('btn-refresh').addEventListener('click', refreshAll);
$('btn-refresh-bans').addEventListener('click', () => nui('requestBans').catch(() => showToast('Erreur de chargement.', true)));
$('player-search').addEventListener('input', renderPlayers);
$('log-search').addEventListener('input', renderLogs);
$('btn-start-spectate').addEventListener('click', () => {
    if (state.selectedPlayerId) startSpectate(state.selectedPlayerId);
    else showToast('Sélectionne d’abord un joueur.', true);
});
$('btn-stop-spectate').addEventListener('click', () => {
    nui('stopSpectate').catch(() => {});
    state.spectatingId = null;
    $('cam-target-name').textContent = 'AUCUNE CIBLE';
});
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !$('anticheat-window').classList.contains('hidden')) {
        event.preventDefault();
        closeUI();
    }
});

updateClock();
window.setInterval(updateClock, 1000);
