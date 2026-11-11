// State & Configuration
let currentMode = 'admin'; // 'admin' ou 'creator'
let activeGrade = 'superoperator';
let selectedPlayerId = null;
let onlinePlayers = [];
let availableJobs = [];
let adminTabletOpen = false;
let mapViewState = { zoom: 1, panX: 0, panY: 0, dragging: false, dragMoved: false, lastX: 0, lastY: 0 };
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
    setupAdminSubViews();
    setupPlayerMap();
    renderPermissionsMatrix();
    setInterval(() => {
        const mapView = document.getElementById('admin-map-view');
        if (adminTabletOpen && mapView && mapView.classList.contains('active')) refreshPlayerMap();
    }, 2500);

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
        adminTabletOpen = false;
        if (tabletWrapper) tabletWrapper.classList.remove('is-open');
        return;
    }
    if (data.action === 'playerPositions') {
        updateOnlinePlayerPositions(Array.isArray(data.players) ? data.players : []);
        return;
    }
    if (data.action === 'auditLogs') {
        renderAuditLogs(data.logs);
        return;
    }
    if (data.action !== 'openTablet') return;

    adminTabletOpen = true;
    if (tabletWrapper) tabletWrapper.classList.add('is-open');
    onlinePlayers = Array.isArray(data.players) ? data.players : [];
    availableJobs = Array.isArray(data.jobs) ? data.jobs : [];
    renderJobOptions();
    renderPlayerMap();
    renderMapPlayerList();
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
    renderMapPlayerList();
    renderPlayerMap();
    const target = document.getElementById('selected-target-name');
    if (target) target.textContent = `${name} [ID: ${id}]`;
}

function playerAction(action) {
    if (!Number.isInteger(selectedPlayerId) || selectedPlayerId < 1) return showToast('Sélectionnez un joueur connecté.');
    const endpoints = { goto: 'teleportToPlayer', bring: 'bringPlayer', freeze: 'freezePlayer', revive: 'revivePlayer', heal: 'healPlayer', kick: 'kickPlayer' };
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
        showToast(action === 'freeze' ? (payload.freeze ? 'Demande de gel envoyée.' : 'Demande de dégel envoyée.') : action === 'heal' ? 'Soin envoyé au joueur.' : 'Demande envoyée au serveur.');
    }).catch(() => showToast('Impossible de contacter le serveur.'));
}


function manageSelectedMoney(operation) {
    if (!Number.isInteger(selectedPlayerId) || selectedPlayerId < 1) return showToast('Sélectionnez un joueur connecté.');
    const amount = Number(document.getElementById('admin-money-amount')?.value);
    const type = document.getElementById('admin-money-type')?.value;
    if (!Number.isInteger(amount) || amount < 1 || amount > 1000000) return showToast('Montant invalide (1 à 1 000 000).');
    nuiPost('manageEconomy', { playerId: selectedPlayerId, type: type, amount: amount, operation: operation })
        .then(() => showToast((operation === 'give' ? 'Ajout' : 'Retrait') + ' demandé au serveur.'))
        .catch(() => showToast('Impossible de modifier le compte du joueur.'));
}

function banSelectedPlayer() {
    if (!Number.isInteger(selectedPlayerId) || selectedPlayerId < 1) return showToast('Sélectionnez un joueur connecté.');
    const reason = document.getElementById('admin-ban-reason')?.value.trim();
    if (!reason) return showToast('Saisissez un motif de bannissement.');
    if (!window.confirm('Confirmer le bannissement permanent du joueur ID ' + selectedPlayerId + ' ?')) return;
    nuiPost('banPlayer', { playerId: selectedPlayerId, reason: reason })
        .then(() => showToast('Demande de bannissement envoyée.'))
        .catch(() => showToast('Impossible de bannir ce joueur.'));
}
function setSelectedJob() {
    if (!Number.isInteger(selectedPlayerId) || selectedPlayerId < 1) return showToast('Sélectionnez un joueur connecté.');
    const jobName = document.getElementById('admin-job-name')?.value.trim();
    const grade = Number(document.getElementById('admin-job-grade')?.value);
    if (!jobName || !Number.isInteger(grade) || grade < 0 || grade > 20) return showToast('Métier ou grade invalide.');
    nuiPost('setJob', { playerId: selectedPlayerId, jobName: jobName, grade: grade })
        .then(() => showToast('Modification du métier envoyée.'))
        .catch(() => showToast('Impossible de modifier le métier.'));
}

function renderJobOptions() {
    const datalist = document.getElementById('admin-job-options');
    if (!datalist) return;
    datalist.replaceChildren();
    availableJobs.forEach(job => {
        if (!job || typeof job.name !== 'string') return;
        const option = document.createElement('option');
        option.value = job.name;
        option.label = job.label || job.name;
        datalist.append(option);
    });
}

function setupAdminSubViews() {
    document.querySelectorAll('[data-admin-view]').forEach(button => {
        button.addEventListener('click', () => {
            const target = button.dataset.adminView;
            document.querySelectorAll('[data-admin-view]').forEach(item => item.classList.toggle('active', item === button));
            document.getElementById('admin-players-view')?.classList.toggle('active', target === 'players');
            document.getElementById('admin-map-view')?.classList.toggle('active', target === 'map');
            if (target === 'map') {
                renderPlayerMap();
                refreshPlayerMap();
            }
        });
    });
}

function refreshPlayerMap() {
    if (!adminTabletOpen) return;
    nuiPost('requestPlayerPositions').catch(() => showToast('Impossible de récupérer les positions des joueurs.'));
}

function updateOnlinePlayerPositions(players) {
    const current = new Map(onlinePlayers.map(player => [Number(player.id), player]));
    onlinePlayers = players.map(player => Object.assign({}, current.get(Number(player.id)) || {}, player));
    renderPlayerMap();
    renderMapPlayerList();
    const count = document.getElementById('map-player-count');
    if (count) count.textContent = String(onlinePlayers.length);
    const updated = document.getElementById('map-updated-at');
    if (updated) updated.textContent = 'Mis à jour à ' + new Date().toLocaleTimeString('fr-FR');
}

function setupPlayerMap() {
    const canvas = document.getElementById('player-map');
    if (!canvas) return;
    const resize = () => {
        const rect = canvas.getBoundingClientRect();
        if (!rect.width || !rect.height) return;
        const ratio = window.devicePixelRatio || 1;
        canvas.width = Math.round(rect.width * ratio);
        canvas.height = Math.round(rect.height * ratio);
        canvas.getContext('2d').setTransform(ratio, 0, 0, ratio, 0, 0);
        renderPlayerMap();
    };
    if (typeof ResizeObserver === 'function') new ResizeObserver(resize).observe(canvas.parentElement);
    else window.addEventListener('resize', resize);
    canvas.addEventListener('wheel', event => {
        event.preventDefault();
        changeMapZoom(event.deltaY < 0 ? 1.15 : 0.87);
    }, { passive: false });
    canvas.addEventListener('mousedown', event => {
        mapViewState.dragging = true;
        mapViewState.dragMoved = false;
        mapViewState.lastX = event.clientX;
        mapViewState.lastY = event.clientY;
        canvas.classList.add('dragging');
    });
    window.addEventListener('mouseup', () => {
        mapViewState.dragging = false;
        canvas.classList.remove('dragging');
    });
    window.addEventListener('mousemove', event => {
        if (!mapViewState.dragging) return;
        const dx = event.clientX - mapViewState.lastX;
        const dy = event.clientY - mapViewState.lastY;
        if (Math.abs(dx) + Math.abs(dy) > 2) mapViewState.dragMoved = true;
        mapViewState.panX += dx;
        mapViewState.panY += dy;
        mapViewState.lastX = event.clientX;
        mapViewState.lastY = event.clientY;
        renderPlayerMap();
    });
    canvas.addEventListener('click', event => {
        if (mapViewState.dragMoved) {
            mapViewState.dragMoved = false;
            return;
        }
        const rect = canvas.getBoundingClientRect();
        const x = event.clientX - rect.left;
        const y = event.clientY - rect.top;
        const hit = getMapMarkers(rect.width, rect.height).find(marker => Math.hypot(marker.x - x, marker.y - y) < 18);
        if (!hit) return;
        const player = onlinePlayers.find(item => Number(item.id) === hit.id);
        if (player) {
            selectPlayer(player.id, player.name || player.rawName || 'Joueur', player.job);
            renderMapPlayerList();
            renderPlayerMap();
        }
    });
    resize();
}

const MAP_BOUNDS = { minX: -4500, maxX: 4500, minY: -4500, maxY: 8500 };
function mapPoint(position, width, height) {
    const baseX = ((Number(position.x) - MAP_BOUNDS.minX) / (MAP_BOUNDS.maxX - MAP_BOUNDS.minX)) * width;
    const baseY = ((MAP_BOUNDS.maxY - Number(position.y)) / (MAP_BOUNDS.maxY - MAP_BOUNDS.minY)) * height;
    return {
        x: width / 2 + (baseX - width / 2) * mapViewState.zoom + mapViewState.panX,
        y: height / 2 + (baseY - height / 2) * mapViewState.zoom + mapViewState.panY
    };
}

function getMapMarkers(width, height) {
    return onlinePlayers.filter(player => player.position && Number.isFinite(Number(player.position.x)) && Number.isFinite(Number(player.position.y)))
        .map(player => Object.assign({ id: Number(player.id) }, mapPoint(player.position, width, height)));
}

function renderPlayerMap() {
    const canvas = document.getElementById('player-map');
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const width = rect.width;
    const height = rect.height;
    if (!width || !height) return;
    const ctx = canvas.getContext('2d');
    ctx.clearRect(0, 0, width, height);
    const gradient = ctx.createLinearGradient(0, 0, width, height);
    gradient.addColorStop(0, '#152735');
    gradient.addColorStop(1, '#0a121c');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);

    // Fond tactique schématique : les marqueurs utilisent les coordonnées monde exactes reçues du serveur.
    ctx.save();
    ctx.translate(width / 2 + mapViewState.panX, height / 2 + mapViewState.panY);
    ctx.scale(mapViewState.zoom, mapViewState.zoom);
    ctx.translate(-width / 2, -height / 2);
    ctx.strokeStyle = 'rgba(116, 153, 170, .16)';
    ctx.lineWidth = 1;
    for (let x = 0; x <= width; x += 48) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke(); }
    for (let y = 0; y <= height; y += 48) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke(); }

    ctx.fillStyle = 'rgba(13, 36, 48, .72)';
    ctx.beginPath();
    ctx.moveTo(0, height * .58);
    ctx.bezierCurveTo(width * .10, height * .48, width * .18, height * .65, width * .29, height * .61);
    ctx.lineTo(width * .28, height);
    ctx.lineTo(0, height);
    ctx.closePath();
    ctx.fill();

    const roads = [
        [[.08,.78],[.24,.68],[.38,.70],[.52,.55],[.72,.50],[.92,.30]],
        [[.12,.18],[.28,.31],[.43,.28],[.58,.40],[.76,.32],[.94,.12]],
        [[.20,.05],[.27,.26],[.34,.47],[.48,.66],[.61,.86]],
        [[.03,.45],[.22,.46],[.42,.49],[.65,.45],[.87,.55]],
        [[.38,.08],[.45,.25],[.54,.42],[.70,.62],[.88,.84]]
    ];
    roads.forEach(points => {
        ctx.beginPath();
        points.forEach((point, index) => {
            const x = point[0] * width;
            const y = point[1] * height;
            if (index === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        });
        ctx.strokeStyle = 'rgba(28, 42, 52, .95)';
        ctx.lineWidth = 7;
        ctx.stroke();
        ctx.strokeStyle = 'rgba(72, 116, 137, .62)';
        ctx.lineWidth = 3;
        ctx.stroke();
    });
    ctx.fillStyle = 'rgba(190, 210, 220, .55)';
    ctx.font = '700 10px sans-serif';
    ctx.fillText('BLAINE COUNTY', width * .56, height * .12);
    ctx.fillText('LOS SANTOS', width * .20, height * .82);
    ctx.fillText('OCEAN PACIFIQUE', width * .04, height * .54);
    ctx.restore();

    const markers = getMapMarkers(width, height);
    markers.forEach(marker => {
        const player = onlinePlayers.find(item => Number(item.id) === marker.id);
        if (marker.x < -20 || marker.x > width + 20 || marker.y < -20 || marker.y > height + 20) return;
        ctx.beginPath();
        ctx.arc(marker.x, marker.y, 10, 0, Math.PI * 2);
        ctx.fillStyle = Number(player && player.id) === Number(selectedPlayerId) ? '#fbbf24' : '#ef4444';
        ctx.shadowColor = ctx.fillStyle;
        ctx.shadowBlur = 13;
        ctx.fill();
        ctx.shadowBlur = 0;
        ctx.lineWidth = 2;
        ctx.strokeStyle = '#fff';
        ctx.stroke();
        ctx.fillStyle = '#fff';
        ctx.font = '700 10px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(String(marker.id), marker.x, marker.y - 15);
    });
    const count = document.getElementById('map-player-count');
    if (count) count.textContent = String(markers.length);
}

function renderMapPlayerList() {
    const container = document.getElementById('map-player-list');
    if (!container) return;
    container.replaceChildren();
    onlinePlayers.forEach(player => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'map-player-entry' + (Number(player.id) === Number(selectedPlayerId) ? ' selected' : '');
        const name = document.createElement('strong');
        name.textContent = (player.name || player.rawName || 'Joueur') + ' [' + player.id + ']';
        const meta = document.createElement('span');
        meta.textContent = player.position
            ? (player.jobLabel || player.job || 'Inconnu') + ' · X ' + Number(player.position.x).toFixed(0) + ' / Y ' + Number(player.position.y).toFixed(0)
            : 'Position indisponible';
        button.append(name, meta);
        button.addEventListener('click', () => {
            selectPlayer(player.id, player.name || player.rawName || 'Joueur', player.job);
            renderMapPlayerList();
            renderPlayerMap();
        });
        container.append(button);
    });
}

function changeMapZoom(factor) {
    mapViewState.zoom = Math.max(0.75, Math.min(4, mapViewState.zoom * factor));
    renderPlayerMap();
}

function resetMapView() {
    mapViewState.zoom = 1;
    mapViewState.panX = 0;
    mapViewState.panY = 0;
    renderPlayerMap();
}

function manageSelectedMoney(operation) {
    if (!Number.isInteger(selectedPlayerId) || selectedPlayerId < 1) return showToast('Sélectionnez un joueur connecté.');
    const amount = Number(document.getElementById('admin-money-amount')?.value);
    const type = document.getElementById('admin-money-type')?.value;
    if (!Number.isInteger(amount) || amount < 1 || amount > 1000000) return showToast('Montant invalide (1 à 1 000 000).');
    nuiPost('manageEconomy', { playerId: selectedPlayerId, type: type, amount: amount, operation: operation })
        .then(() => showToast((operation === 'give' ? 'Ajout' : 'Retrait') + ' demandé au serveur.'))
        .catch(() => showToast('Impossible de modifier le compte du joueur.'));
}

function setSelectedJob() {
    if (!Number.isInteger(selectedPlayerId) || selectedPlayerId < 1) return showToast('Sélectionnez un joueur connecté.');
    const jobName = document.getElementById('admin-job-name')?.value.trim();
    const grade = Number(document.getElementById('admin-job-grade')?.value);
    if (!jobName || !Number.isInteger(grade) || grade < 0 || grade > 20) return showToast('Métier ou grade invalide.');
    nuiPost('setJob', { playerId: selectedPlayerId, jobName: jobName, grade: grade })
        .then(() => showToast('Modification du métier envoyée.'))
        .catch(() => showToast('Impossible de modifier le métier.'));
}

function renderJobOptions() {
    const datalist = document.getElementById('admin-job-options');
    if (!datalist) return;
    datalist.replaceChildren();
    availableJobs.forEach(job => {
        if (!job || typeof job.name !== 'string') return;
        const option = document.createElement('option');
        option.value = job.name;
        option.label = job.label || job.name;
        datalist.append(option);
    });
}

function setupAdminSubViews() {
    document.querySelectorAll('[data-admin-view]').forEach(button => {
        button.addEventListener('click', () => {
            const target = button.dataset.adminView;
            document.querySelectorAll('[data-admin-view]').forEach(item => item.classList.toggle('active', item === button));
            document.getElementById('admin-players-view')?.classList.toggle('active', target === 'players');
            document.getElementById('admin-map-view')?.classList.toggle('active', target === 'map');
            if (target === 'map') {
                renderPlayerMap();
                refreshPlayerMap();
            }
        });
    });
}

function refreshPlayerMap() {
    if (!adminTabletOpen) return;
    nuiPost('requestPlayerPositions').catch(() => showToast('Impossible de récupérer les positions des joueurs.'));
}

function updateOnlinePlayerPositions(players) {
    const current = new Map(onlinePlayers.map(player => [Number(player.id), player]));
    onlinePlayers = players.map(player => Object.assign({}, current.get(Number(player.id)) || {}, player));
    renderPlayerMap();
    renderMapPlayerList();
    const count = document.getElementById('map-player-count');
    if (count) count.textContent = String(onlinePlayers.length);
    const updated = document.getElementById('map-updated-at');
    if (updated) updated.textContent = 'Mis à jour à ' + new Date().toLocaleTimeString('fr-FR');
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
