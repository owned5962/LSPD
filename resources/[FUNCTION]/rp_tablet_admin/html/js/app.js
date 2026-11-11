// State & Configuration
let currentMode = 'admin'; // 'admin' ou 'creator'
let activeGrade = 'superoperator';
let selectedPlayerId = null;
let onlinePlayers = [];
const frozenPlayers = new Set();

function nuiPost(endpoint, payload) {
    if (typeof GetParentResourceName !== 'function') return Promise.reject(new Error('NUI indisponible'));
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload || {})
    }).then(response => { if (!response.ok) throw new Error(`HTTP ${response.status}`); return response.json().catch(() => ({})); });
}

// Permissions catalog with default values per grade
const allPermissions = [
    { id: 'tp_to', label: 'Téléportation Cible (Goto)', desc: 'Se téléporter instantanément sur un joueur', icon: 'fa-location-arrow' },
    { id: 'tp_here', label: 'Téléporter sur Moi (Bring)', desc: 'Attirer le joueur à sa position actuelle', icon: 'fa-magnet' },
    { id: 'freeze', label: 'Freeze / Défreeze', desc: 'Bloquer ou débloquer la motricité du joueur', icon: 'fa-snowflake' },
    { id: 'spectate', label: 'Caméra Spectateur', desc: 'Espionner la vue du joueur sans être vu', icon: 'fa-eye' },
    { id: 'heal', label: 'Soigner (Heal)', desc: 'Restaurer toute la santé et l\'armure', icon: 'fa-medkit' },
    { id: 'revive', label: 'Réanimer (Revive)', desc: 'Réanimer un joueur dans le coma', icon: 'fa-heart' },
    { id: 'noclip', label: 'Mode Vol (NoClip)', desc: 'Traverser les murs et se déplacer librement', icon: 'fa-ghost' },
    { id: 'godmode', label: 'Invincibilité (Godmode)', desc: 'Immunité aux balles et collisions', icon: 'fa-shield-virus' },
    { id: 'kick', label: 'Expulser (Kick)', desc: 'Éjecter un fauteur de troubles du serveur', icon: 'fa-user-times' },
    { id: 'ban', label: 'Bannir Joueur (Ban)', desc: 'Bannissement temporaire ou définitif', icon: 'fa-ban' },
    { id: 'give_money', label: 'Donner de l\'Argent', desc: 'Créditer du cash ou banque d\'urgence', icon: 'fa-money-bill-wave' },
    { id: 'spawn_veh', label: 'Spawn Véhicule Staff', desc: 'Faire apparaître un véhicule d\'intervention', icon: 'fa-car' }
];

// Configuration par défaut par rôle
const rolePermissions = {
    helper: {
        tp_to: true,
        tp_here: false,
        freeze: true,
        spectate: true,
        heal: true,
        revive: true,
        noclip: false,
        godmode: false,
        kick: false,
        ban: false,
        give_money: false,
        spawn_veh: true
    },
    operator: {
        tp_to: true,
        tp_here: true,
        freeze: true,
        spectate: true,
        heal: true,
        revive: true,
        noclip: true,
        godmode: false,
        kick: true,
        ban: false,
        give_money: false,
        spawn_veh: true
    },
    superoperator: {
        tp_to: true,
        tp_here: true,
        freeze: true,
        spectate: true,
        heal: true,
        revive: true,
        noclip: true,
        godmode: true,
        kick: true,
        ban: true,
        give_money: true,
        spawn_veh: true
    },
    fondateur: {
        tp_to: true,
        tp_here: true,
        freeze: true,
        spectate: true,
        heal: true,
        revive: true,
        noclip: true,
        godmode: true,
        kick: true,
        ban: true,
        give_money: true,
        spawn_veh: true
    }
};

// Initialisation au chargement
document.addEventListener('DOMContentLoaded', () => {
    const tabletWrapper = document.getElementById('tablet-wrapper');
    if (tabletWrapper) tabletWrapper.classList.remove('is-open');
    setupTabSwitching();
    renderPermissionsMatrix();

    // The close button was present in the HTML but had no click handler.
    const closeButton = document.getElementById('btn-close-tablet');
    if (closeButton) {
        closeButton.addEventListener('click', closeAdminTablet);
    }

    // Keep keyboard closing available while the NUI has focus.
    document.addEventListener('keydown', (event) => {
        if (event.key !== 'Escape' && event.key !== 'F10') return;
        const wrapper = document.getElementById('tablet-wrapper');
        if (!wrapper || !wrapper.classList.contains('is-open')) return;
        event.preventDefault();
        event.stopPropagation();
        closeAdminTablet(event.key === 'F10' ? 'f10' : 'escape');
    });

    window.addEventListener('message', handleTabletMessage);
    updateClock();
    setInterval(updateClock, 1000);
});

function updateClock() {
    const now = new Date();
    const h = String(now.getHours()).padStart(2, '0');
    const m = String(now.getMinutes()).padStart(2, '0');
    const el = document.getElementById('tablet-time');
    if (el) el.textContent = `${h}:${m}`;
}

// Gestion des onglets principaux (Menu Admin Noir & Rouge vs Menu Créateur Noir & Bleu)
function setupTabSwitching() {
    const tabs = document.querySelectorAll('.mode-btn');
    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            tabs.forEach(t => t.classList.remove('active'));
            tab.classList.add('active');

            const mode = tab.dataset.mode;
            currentMode = mode;

            document.querySelectorAll('.view-panel').forEach(p => p.classList.remove('active'));
            if (mode === 'admin') {
                document.getElementById('view-admin').classList.add('active');
            } else {
                document.getElementById('view-creator').classList.add('active');
            }
        });
    });
}

// Changement d'affichage des rôles dans le menu créateur
function changeGradeConfig(grade) {
    activeGrade = grade;
    document.querySelectorAll('.grade-tab').forEach(b => {
        b.classList.toggle('active', b.dataset.grade === grade);
    });

    const labelMap = {
        superoperator: 'SuperOpérateur',
        operator: 'Opérateur',
        helper: 'Helper',
        fondateur: 'Fondateur'
    };
    document.getElementById('active-grade-title').textContent = labelMap[grade];

    renderPermissionsMatrix();
    showToast(`Configuration chargée pour le grade : ${labelMap[grade]}`);
}

// Rendu des cases à cocher de permissions
function renderPermissionsMatrix() {
    const container = document.getElementById('permissions-container');
    if (!container) return;
    container.innerHTML = '';

    const currentPerms = rolePermissions[activeGrade] || {};
    const isFondateur = activeGrade === 'fondateur';

    allPermissions.forEach(perm => {
        const isChecked = currentPerms[perm.id] === true;
        const div = document.createElement('div');
        div.className = 'perm-item-box';

        div.innerHTML = `
            <div class="perm-details">
                <span class="perm-title"><i class="fas ${perm.icon}"></i> ${perm.label}</span>
                <span class="perm-desc">${perm.desc}</span>
            </div>
            <label class="switch-label">
                <input type="checkbox" data-perm-id="${perm.id}" ${isChecked ? 'checked' : ''} ${isFondateur ? 'disabled' : ''} onchange="togglePermission('${perm.id}', this.checked)">
                <span class="slider"></span>
            </label>
        `;
        container.appendChild(div);
    });
}

function togglePermission(permId, value) {
    if (!rolePermissions[activeGrade]) rolePermissions[activeGrade] = {};
    rolePermissions[activeGrade][permId] = value;
}

function saveCurrentPermissions() {
    showToast('La gestion persistante des permissions par grade reste à implémenter côté serveur.');
}

// Close the Lua/NUI tablet through the registered NUI callback.
function closeAdminTablet(source = 'button') {
    nuiPost('close', { source }).catch(() => {});
}

// Actions du Menu Admin
function handleTabletMessage(event) {
    const data = event.data || {};
    const tabletWrapper = document.getElementById('tablet-wrapper');

    if (data.action === 'closeTablet') {
        if (tabletWrapper) tabletWrapper.classList.remove('is-open');
        return;
    }
    if (data.action === 'auditLogs') {
        renderAuditLogs(data.logs);
        return;
    }
    if (data.action !== 'openTablet') return;

    if (tabletWrapper) tabletWrapper.classList.add('is-open');
    onlinePlayers = Array.isArray(data.players) ? data.players : [];
    frozenPlayers.clear();
    if (Array.isArray(data.frozenPlayers)) data.frozenPlayers.forEach(id => { const parsed = Number(id); if (Number.isInteger(parsed) && parsed > 0) frozenPlayers.add(parsed); });
    renderOnlinePlayers();
    const rank = document.getElementById('current-rank-label');
    if (rank) rank.textContent = String(data.admin?.role || 'ADMIN').toUpperCase();
}

function requestAuditLogs() {
    nuiPost('requestAuditLogs').then(() => showToast('Demande de journaux envoyée.'))
        .catch(() => showToast('Impossible de demander les journaux.'));
}

function renderAuditLogs(logs) {
    const container = document.getElementById('admin-audit-logs');
    if (!container) return;
    container.replaceChildren();
    if (!Array.isArray(logs) || logs.length === 0) {
        const empty = document.createElement('p');
        empty.textContent = 'Aucune action enregistrée.';
        container.append(empty);
        return;
    }
    logs.forEach(log => {
        const entry = document.createElement('article');
        entry.className = 'audit-log-entry';
        const heading = document.createElement('strong');
        heading.textContent = `${log.admin_name || 'Administrateur'} · ${log.action || 'action'}`;
        const details = document.createElement('p');
        details.textContent = `${log.details || ''}${log.target_identifier ? ` · Cible : ${log.target_identifier}` : ''}`;
        const date = document.createElement('small');
        date.textContent = log.created_at ? String(log.created_at) : '';
        entry.append(heading, details, date);
        container.append(entry);
    });
}

function renderOnlinePlayers() {
    const list = document.getElementById('players-list');
    const count = document.getElementById('player-count');
    if (!list) return;
    if (count) count.textContent = String(onlinePlayers.length);
    list.replaceChildren();
    onlinePlayers.forEach(player => {
        const entry = document.createElement('button');
        entry.type = 'button'; entry.className = 'player-entry';
        const info = document.createElement('span'); info.className = 'player-info';
        const name = document.createElement('span'); name.className = 'name';
        name.textContent = `${player.name || player.rawName || 'Joueur'} [ID: ${player.id}]`;
        const meta = document.createElement('span'); meta.className = 'meta';
        meta.textContent = `Métier : ${player.jobLabel || player.job || 'Inconnu'} · Grade : ${player.grade ?? 0}`;
        info.append(name, meta); entry.append(info);
        entry.addEventListener('click', () => selectPlayer(player.id, player.name || player.rawName || 'Joueur', player.job, entry));
        list.append(entry);
    });
    if (onlinePlayers.length) selectPlayer(onlinePlayers[0].id, onlinePlayers[0].name || onlinePlayers[0].rawName || 'Joueur', onlinePlayers[0].job, list.firstElementChild);
    else {
        selectedPlayerId = null;
        const target = document.getElementById('selected-target-name');
        if (target) target.textContent = 'Aucune cible';
    }
}

function filterPlayers() {
    const query = (document.getElementById('player-search')?.value || '').trim().toLowerCase();
    document.querySelectorAll('.player-entry').forEach(entry => {
        entry.hidden = query !== '' && !entry.textContent.toLowerCase().includes(query);
    });
}

function selectPlayer(id, name, job, element) {
    selectedPlayerId = Number(id);
    document.querySelectorAll('.player-entry').forEach(el => el.classList.remove('selected'));
    if (element) element.classList.add('selected');
    const target = document.getElementById('selected-target-name');
    if (target) target.textContent = `${name} [ID: ${id}]`;
}

function playerAction(action) {
    if (!Number.isInteger(selectedPlayerId) || selectedPlayerId < 1) return showToast('Sélectionnez un joueur connecté.');
    const endpoints = { goto: 'teleportToPlayer', bring: 'bringPlayer', freeze: 'freezePlayer', revive: 'revivePlayer', kick: 'kickPlayer' };
    const endpoint = endpoints[action];
    if (!endpoint) return showToast('Cette fonction n’est pas encore disponible.');
    const payload = { playerId: selectedPlayerId };
    if (action === 'freeze') {
        payload.freeze = !frozenPlayers.has(selectedPlayerId);
    }
    if (action === 'kick') payload.reason = 'Expulsé par un administrateur.';
    nuiPost(endpoint, payload).then(() => {
        if (action === 'freeze') {
            if (payload.freeze) frozenPlayers.add(selectedPlayerId);
            else frozenPlayers.delete(selectedPlayerId);
        }
        showToast(action === 'freeze' ? (payload.freeze ? 'Demande de gel envoyée.' : 'Demande de dégel envoyée.') : 'Demande envoyée au serveur.');
    }).catch(() => showToast('Impossible de contacter le serveur.'));
}

function triggerAdminAction(act) {
    showToast('Cette action globale n’est pas encore disponible.');
}

// Commandes du serveur depuis le Menu Créateur
function setWeather(weather) {
    nuiPost('setWeatherTime', { weather }).then(() => showToast('Demande météo envoyée.')).catch(() => showToast('Échec de la demande météo.'));
}

function setTime(h, m) {
    nuiPost('setWeatherTime', { hours: h, minutes: m }).then(() => showToast('Demande horaire envoyée.')).catch(() => showToast('Échec de la demande horaire.'));
}

function sendBroadcast() {
    const input = document.getElementById('broadcast-msg');
    const msg = input.value.trim();
    if (!msg) return showToast('Saisissez une annonce.');
    nuiPost('broadcastAnnouncement', { message: msg }).then(() => { showToast('Annonce transmise au serveur.'); input.value = ''; }).catch(() => showToast('Échec de l’envoi de l’annonce.'));
}

function wipeVehicles() { showToast('Purge des véhicules non disponible : aucune action serveur sécurisée.'); }
function wipePeds() { showToast('Purge des PNJ non disponible : aucune action serveur sécurisée.'); }
function toggleWhitelist() { showToast('Verrouillage serveur non disponible : aucune action serveur sécurisée.'); }

function showToast(msg) {
    const toast = document.getElementById('toast-notify');
    if (!toast) return;
    toast.textContent = msg;
    toast.style.display = 'block';
    setTimeout(() => {
        toast.style.display = 'none';
    }, 2800);
}
