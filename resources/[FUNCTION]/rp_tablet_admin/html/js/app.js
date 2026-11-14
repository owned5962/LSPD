// State & Configuration
let currentMode = 'admin'; // 'admin' ou 'creator'
let activeGrade = 'superoperator';
let selectedPlayerId = null;
let onlinePlayers = [];
let availableJobs = [];
let adminTabletOpen = false;
let mapInstance = null;
let mapMarkers = new Map();
let selectedMapTeleportPoint = null;
let mapTeleportMarker = null;
let itemCatalog = [];
let weaponPolicy = [];
const panelTargets = { give: null, economy: null, sanction: null, function: null, job: null };
const frozenPlayers = new Set();

const ADMIN_NUI_RESOURCE = 'rp_tablet_admin';

function nuiPost(endpoint, payload) {
    return fetch(`https://${ADMIN_NUI_RESOURCE}/${endpoint}`, {
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
    setupPlayerPickers();
    document.getElementById('admin-job-name')?.addEventListener('change', renderJobGrades);
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
        if (event.key !== 'Escape') return;
        const wrapper = document.getElementById('tablet-wrapper');
        if (!wrapper || !wrapper.classList.contains('is-open')) return;
        event.preventDefault();
        event.stopPropagation();
        closeAdminTablet('escape');
    });

    window.addEventListener('message', handleTabletMessage);

    document.getElementById('admin-map-teleport')?.addEventListener('click', () => {
        if (!selectedMapTeleportPoint) return showToast('Cliquez d’abord sur la carte pour définir un point.');
        const button = document.getElementById('admin-map-teleport');
        if (button) button.disabled = true;
        nuiPost('teleportToMapPoint', selectedMapTeleportPoint)
            .then(() => showToast('Demande de téléportation envoyée.'))
            .catch(() => showToast('Impossible de se téléporter à ce point.'))
            .finally(() => { if (button && selectedMapTeleportPoint) button.disabled = false; });
    });
    document.getElementById('player-report-cancel')?.addEventListener('click', () => nuiPost('closePlayerReport').catch(() => {}));
    document.getElementById('player-report-submit')?.addEventListener('click', () => {
        const input = document.getElementById('player-report-message');
        const message = (input?.value || '').trim();
        if (message.length < 10 || message.length > 500) {
            const status = document.getElementById('player-report-status');
            if (status) status.textContent = 'Le message doit contenir entre 10 et 500 caractères.';
            return;
        }
        nuiPost('submitPlayerReport', { message }).catch(() => {
            const status = document.getElementById('player-report-status');
            if (status) status.textContent = 'Impossible d’envoyer le signalement.';
        });
    });
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
    adminTabletOpen = false;
    document.getElementById('tablet-wrapper')?.classList.remove('is-open');
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
    if (data.action === 'economyResult') {
        const result = data.result || {};
        const target = onlinePlayers.find(player => Number(player.id) === Number(result.playerId));
        if (target && result.success === true) {
            target.cash = Number(result.cash) || 0;
            target.bank = Number(result.bank) || 0;
            renderOnlinePlayers();
            renderPlayerPickers();
        }
        showToast(String(result.message || 'Résultat de l’opération économique reçu.'));
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
    if (data.action === 'reports') { renderReports(data.reports); return; }
    if (data.action === 'openPlayerReport') { document.getElementById('player-report-overlay')?.classList.remove('hidden'); return; }
    if (data.action === 'closePlayerReport') { document.getElementById('player-report-overlay')?.classList.add('hidden'); return; }
    if (data.action === 'playerReportResult') {
        const status = document.getElementById('player-report-status');
        if (status) status.textContent = String(data.message || '');
        if (data.success === true) {
            document.getElementById('player-report-message').value = '';
            document.getElementById('player-report-overlay')?.classList.add('hidden');
            showToast(String(data.message || 'Signalement envoyé.'));
        }
        return;
    }
    if (data.action === 'reportsRefresh') { if (adminTabletOpen) requestReports(); return; }
    if (data.action === 'reportUpdated') {
        const row = document.querySelector('[data-report-id="' + Number(data.reportId) + '"]');
        if (row) {
            const statusCell = row.children[3];
            const actionCell = row.children[5];
            if (statusCell) statusCell.textContent = data.status === 'accepted' ? 'Pris en charge' : data.status === 'resolved' ? 'Traité' : 'Rejeté';
            if (actionCell) actionCell.textContent = data.handledBy ? 'Pris en charge par ' + String(data.handledBy) : 'Mis à jour';
        }
        showToast('Signalement mis à jour.');
        return;
    }
    if (data.action === 'weaponPolicySaveFailed') {
        const status = document.getElementById('weapon-policy-status');
        if (status) status.textContent = 'Échec : ' + String(data.message || 'enregistrement impossible');
        showToast(String(data.message || 'Enregistrement des armes impossible.'));
        return;
    }
    if (data.action === 'weaponPolicySaved') {
        weaponPolicy = Array.isArray(data.weaponPolicy) ? data.weaponPolicy : [];
        renderWeaponPolicy();
        renderAdminWeaponOptions();
        const status = document.getElementById('weapon-policy-status');
        if (status) status.textContent = 'Configuration enregistrée dans MySQL.';
        return;
    }
    if (data.action === 'itemCatalog') {
        itemCatalog = Array.isArray(data.items) ? data.items : [];
        renderItemCatalog();
        return;
    }
    if (data.action !== 'openTablet') return;

    adminTabletOpen = true;
    if (tabletWrapper) tabletWrapper.classList.add('is-open');
    onlinePlayers = Array.isArray(data.players) ? data.players : [];
    availableJobs = Array.isArray(data.jobs) ? data.jobs : [];
    itemCatalog = Array.isArray(data.items) ? data.items : [];
    weaponPolicy = Array.isArray(data.weaponPolicy) ? data.weaponPolicy : [];
    renderWeaponPolicy();
    renderAdminWeaponOptions();
    renderPlayerPickers();
    renderItemCatalog();
    renderJobOptions();
    renderPlayerMap();
    renderMapPlayerList();
    frozenPlayers.clear();
    if (Array.isArray(data.frozenPlayers)) data.frozenPlayers.forEach(id => { const parsed = Number(id); if (Number.isInteger(parsed) && parsed > 0) frozenPlayers.add(parsed); });
    renderOnlinePlayers();
    const rank = document.getElementById('current-rank-label');
    if (rank) rank.textContent = String(data.admin?.role || 'STAFF').toUpperCase();
}

function requestAuditLogs() {
    nuiPost('requestAuditLogs').then(() => showToast('Demande de journaux envoyée.'))
        .catch(() => showToast('Impossible de demander les journaux.'));
}


function requestReports() {
    nuiPost('requestReports').catch(() => showToast('Impossible de charger les signalements.'));
}
function renderReports(reports) {
    const body = document.getElementById('admin-reports-table-body');
    if (!body) return;
    body.replaceChildren();
    const rows = Array.isArray(reports) ? reports : [];
    const counter = document.getElementById('report-open-count');
    if (counter) counter.textContent = String(rows.filter(report => report.status === 'open').length);
    if (!rows.length) {
        const row = document.createElement('tr'), cell = document.createElement('td');
        cell.colSpan = 6; cell.textContent = 'Aucun signalement enregistré.';
        row.appendChild(cell); body.appendChild(row); return;
    }
    rows.forEach(report => {
        const row = document.createElement('tr');
        row.dataset.reportId = String(Number(report.id) || 0);
        const values = [String(report.id || ''), String(report.player_name || 'Joueur'), String(report.message || ''),
            report.status === 'open' ? 'En attente' : report.status === 'accepted' ? 'Pris en charge' : report.status === 'resolved' ? 'Traité' : 'Rejeté', String(report.created_at || '')];
        values.forEach(value => { const cell = document.createElement('td'); cell.textContent = value; row.appendChild(cell); });
        const actions = document.createElement('td');
        if (report.status === 'open') {
            const resolve = document.createElement('button');
            resolve.type = 'button'; resolve.className = 'report-action report-resolve'; resolve.textContent = 'Accepter';
            resolve.classList.add('accept');
            resolve.addEventListener('click', () => updateReportStatus(report.id, 'accepted'));
            const reject = document.createElement('button');
            reject.type = 'button'; reject.className = 'report-action report-reject'; reject.textContent = 'Rejeter';
            reject.addEventListener('click', () => updateReportStatus(report.id, 'rejected'));
            actions.append(resolve, reject);
        } else actions.textContent = report.handled_by ? (report.status === 'accepted' ? 'Pris en charge par ' : 'Par ') + String(report.handled_by) : 'Clôturé';
        row.appendChild(actions); body.appendChild(row);
    });
}
function updateReportStatus(reportId, status) {
    if (!Number.isInteger(Number(reportId)) || !['accepted', 'resolved', 'rejected'].includes(status)) return;
    nuiPost('updateReport', { reportId: Number(reportId), status })
        .catch(() => showToast('Impossible de traiter ce signalement.'));
}

function renderAuditLogs(logs) {
    const body = document.getElementById('admin-audit-table-body');
    if (!body) return;
    body.replaceChildren();
    if (!Array.isArray(logs) || logs.length === 0) {
        const row = document.createElement('tr'), cell = document.createElement('td');
        cell.colSpan = 5; cell.textContent = 'Aucune action enregistrée.';
        row.appendChild(cell); body.appendChild(row); return;
    }
    logs.forEach(log => {
        const row = document.createElement('tr');
        [log.admin_name || 'Administrateur', log.action || 'Action', log.target_identifier || '—', log.details || '—', log.created_at || ''].forEach(value => {
            const cell = document.createElement('td'); cell.textContent = String(value); row.appendChild(cell);
        });
        body.appendChild(row);
    });
}

function drawAdminJobChart(entries) {
    const canvas = document.getElementById('admin-job-chart');
    if (!canvas) return;
    const width = Math.max(220, canvas.clientWidth || 320), height = 76;
    const ratio = Math.max(1, Math.min(2, window.devicePixelRatio || 1));
    canvas.width = Math.round(width * ratio); canvas.height = Math.round(height * ratio);
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    ctx.setTransform(ratio,0,0,ratio,0,0); ctx.clearRect(0,0,width,height);
    ctx.font = '9px Plus Jakarta Sans, sans-serif'; ctx.fillStyle = '#94a3b8';
    if (!entries.length) { ctx.fillText('Aucune donnée joueur disponible',8,18); return; }
    const max = Math.max(1,...entries.map(item=>item.value)), gap=7, rowH=Math.min(13,(height-10-gap*(entries.length-1))/entries.length);
    entries.forEach((item,index)=>{
        const y=5+index*(rowH+gap), barX=104, barW=Math.max(0,width-barX-28);
        ctx.textAlign='right';ctx.fillStyle='#cbd5e1';ctx.fillText(item.label.slice(0,15),96,y+rowH*.78);
        ctx.fillStyle='rgba(239,68,68,.16)';ctx.fillRect(barX,y,barW,rowH);
        ctx.fillStyle='#ef4444';ctx.fillRect(barX,y,barW*item.value/max,rowH);
        ctx.textAlign='left';ctx.fillStyle='#fca5a5';ctx.fillText(String(item.value),Math.min(width-16,barX+barW*item.value/max+5),y+rowH*.78);
    });
}
function renderAdminOverview() {
    const playerCount = document.getElementById('admin-live-players');
    const jobCount = document.getElementById('admin-live-jobs');
    const pingCount = document.getElementById('admin-live-ping');
    if (!playerCount || !jobCount || !pingCount) return;
    playerCount.textContent = String(onlinePlayers.length);
    const jobs = new Map();
    let pingTotal = 0, pingSamples = 0;
    onlinePlayers.forEach(player => {
        const job = String(player.jobLabel || player.job || 'Sans métier');
        jobs.set(job,(jobs.get(job)||0)+1);
        const ping = Number(player.ping);
        if (Number.isFinite(ping) && ping >= 0) { pingTotal += ping; pingSamples++; }
    });
    jobCount.textContent = String(jobs.size);
    pingCount.textContent = pingSamples ? Math.round(pingTotal/pingSamples)+' ms' : '— ms';
    drawAdminJobChart(Array.from(jobs,([label,value])=>({label,value})).sort((a,b)=>b.value-a.value).slice(0,5));
}
function renderOnlinePlayers() {
    const list = document.getElementById('players-list'), count = document.getElementById('player-count');
    if (!list) return;
    if (count) count.textContent = String(onlinePlayers.length);
    list.replaceChildren();
    onlinePlayers.forEach(player => {
        const row = document.createElement('tr');
        row.type = 'button';
        row.className = 'player-entry';
        const values = [
            String(player.id),
            (player.name || player.rawName || 'Joueur') + (player.isSelf ? ' (VOUS)' : ''),
            String(player.jobLabel || player.job || 'Inconnu'),
            String(player.grade ?? 0),
            String(player.ping ?? 0) + ' ms'
        ];
        values.forEach(value => {
            const cell = document.createElement('td');
            cell.textContent = value;
            row.appendChild(cell);
        });
        row.addEventListener('click', () => selectPlayer(player.id, player.name || player.rawName || 'Joueur', player.job, row));
        list.append(row);
    });
    if (selectedPlayerId && !onlinePlayers.some(p => Number(p.id) === Number(selectedPlayerId))) selectedPlayerId = null;
    filterPlayers();
    renderAdminOverview();
}
function filterPlayers() {
    const query = (document.getElementById('player-search')?.value || '').trim().toLowerCase();
    document.querySelectorAll('.player-entry').forEach(entry => { entry.hidden = query !== '' && !entry.textContent.toLowerCase().includes(query); });
}
function selectPlayer(id, name, job, element) {
    selectedPlayerId = Number(id);
    document.querySelectorAll('.player-entry').forEach(el => el.classList.toggle('selected', el === element));
    const target = document.getElementById('selected-target-name');
    if (target) target.textContent = name + ' [ID: ' + id + ']';
    renderMapPlayerList(); renderPlayerMap();
}
function setupPlayerPickers() {
    ['give','economy','sanction','function','job'].forEach(prefix => {
        const search = document.getElementById(prefix + '-player-search'), select = document.getElementById(prefix + '-player-target');
        if (search) search.addEventListener('input', () => renderPlayerPicker(prefix));
        if (select) select.addEventListener('change', () => { panelTargets[prefix] = Number(select.value) || null; updatePanelTargetLabel(prefix); });
    });
}
function renderPlayerPickers() { ['give','economy','sanction','function','job'].forEach(prefix => renderPlayerPicker(prefix)); }
function renderPlayerPicker(prefix) {
    const search = document.getElementById(prefix + '-player-search'), select = document.getElementById(prefix + '-player-target');
    if (!select) return;
    const query = (search?.value || '').trim().toLowerCase(), previous = panelTargets[prefix] || Number(select.value) || null;
    const matches = onlinePlayers.filter(player => player.characterLoaded !== false && (!query || String(player.id).includes(query) || String(player.name || '').toLowerCase().includes(query) || String(player.rawName || '').toLowerCase().includes(query)));
    select.replaceChildren(new Option('Sélectionner un joueur connecté…', ''));
    matches.forEach(player => select.add(new Option((player.name || player.rawName || 'Joueur') + ' · ID ' + player.id, String(player.id))));
    if (previous && matches.some(player => Number(player.id) === Number(previous))) select.value = String(previous);
    else if (/^\d+$/.test(query) && matches.some(player => Number(player.id) === Number(query))) select.value = query;
    panelTargets[prefix] = Number(select.value) || null; updatePanelTargetLabel(prefix);
}
function updatePanelTargetLabel(prefix) {
    const label = document.getElementById(prefix + '-player-selected'); if (!label) return;
    const player = onlinePlayers.find(item => Number(item.id) === Number(panelTargets[prefix]));
    label.textContent = player ? 'Sélection : ' + (player.name || player.rawName || 'Joueur') + ' · ID ' + player.id : 'Aucun joueur sélectionné';
}
function getPanelTarget(prefix) {
    const id = Number(panelTargets[prefix]);
    if (!Number.isInteger(id) || id < 1 || !onlinePlayers.some(player => Number(player.id) === id)) { showToast('Sélectionnez un joueur connecté avec son ID.'); return null; }
    return id;
}

function playerAction(action) {
    const targetId = getPanelTarget('function'); if (!targetId) return;
    const endpoints = { goto:'teleportToPlayer', bring:'bringPlayer', freeze:'freezePlayer', revive:'revivePlayer', heal:'healPlayer', spectate:'spectatePlayer' };
    const endpoint = endpoints[action]; if (!endpoint) return showToast('Fonction indisponible.');
    const payload = { playerId: targetId }; if (action === 'freeze') payload.freeze = !frozenPlayers.has(targetId);
    nuiPost(endpoint, payload).then(() => {
        if (action === 'freeze') { if (payload.freeze) frozenPlayers.add(targetId); else frozenPlayers.delete(targetId); }
        showToast('Action ' + action + ' envoyée pour ID ' + targetId + '.');
    }).catch(() => showToast('Impossible de contacter le serveur.'));
}
function sanctionPlayer(action) {
    const targetId = getPanelTarget('sanction'); if (!targetId || action !== 'kick') return;
    const reason = (document.getElementById('admin-kick-reason')?.value || 'Expulsé par un administrateur.').trim();
    nuiPost('kickPlayer', { playerId: targetId, reason }).then(() => showToast('Demande de kick envoyée.')).catch(() => showToast('Impossible d’expulser ce joueur.'));
}
function banSelectedPlayer() {
    const targetId = getPanelTarget('sanction'); if (!targetId) return;
    const reason = document.getElementById('admin-ban-reason')?.value.trim(); if (!reason) return showToast('Saisissez un motif de bannissement.');
    if (!window.confirm('Confirmer le bannissement permanent du joueur ID ' + targetId + ' ?')) return;
    nuiPost('banPlayer', { playerId: targetId, reason }).then(() => showToast('Demande de bannissement envoyée.')).catch(() => showToast('Impossible de bannir ce joueur.'));
}

function setupAdminSubViews() {
    document.getElementById('weapon-policy-search')?.addEventListener('input', renderWeaponPolicy);
    document.getElementById('weapon-policy-filter')?.addEventListener('change', renderWeaponPolicy);

    document.querySelectorAll('[data-admin-view]').forEach(button => {
        button.addEventListener('click', () => {
            const target = button.dataset.adminView;
            document.querySelectorAll('[data-admin-view]').forEach(item => item.classList.toggle('active',item===button));
            document.querySelectorAll('.admin-subview').forEach(view => view.classList.toggle('active',view.id==='admin-'+target+'-view'));
            if (target==='map') { if (!mapInstance) setupPlayerMap(); setTimeout(()=>{mapInstance?.invalidateSize();mapInstance?.fitBounds([[0,0],[8192,8192]]);renderPlayerMap();},100); refreshPlayerMap(); }
            else if (target==='audit') requestAuditLogs();
            else if (target==='reports') requestReports();
        });
    });
}

function refreshPlayerMap() {
    if (!adminTabletOpen) return;
    nuiPost('requestPlayerPositions').catch(() => showToast('Impossible de récupérer les positions des joueurs.'));
}

function setupPlayerMap() {
    const container = document.getElementById('player-map'); if (!container) return;
    if (typeof L === 'undefined') { container.textContent = 'Carte GTA V indisponible : Leaflet ne s’est pas chargé.'; return; }
    const GTA_CRS = L.extend({}, L.CRS.Simple, { transformation: new L.Transformation(1/32, 0, 1/32, 0) });
    mapInstance = L.map(container, { crs:GTA_CRS, minZoom:0, maxZoom:5, zoomSnap:0.25, attributionControl:false, zoomControl:false });
    const bounds = L.latLngBounds([[0,0],[8192,8192]]);
    L.tileLayer('https://viruxe.github.io/gtav-map-tiles/satelite/{z}/{x}-{y}.webp', { minZoom:0, maxZoom:5, noWrap:true, bounds, tileSize:256, attribution:'GTA V map tiles · viruxe/gtav-map-tiles' }).addTo(mapInstance);
    mapInstance.fitBounds(bounds); mapInstance.setMaxBounds(bounds.pad(0.03));
    mapInstance.on('click', event => {
        const x = ((event.latlng.lng - GTA_MAP_OFFSET_X) / GTA_MAP_SCALE) + GTA_WORLD.minX;
        const y = (event.latlng.lat / GTA_MAP_SCALE) + GTA_WORLD.minY;
        if (!Number.isFinite(x) || !Number.isFinite(y)
            || x < GTA_WORLD.minX || x > GTA_WORLD.maxX
            || y < GTA_WORLD.minY || y > GTA_WORLD.maxY) return;
        selectedMapTeleportPoint = { x: Math.round(x * 10) / 10, y: Math.round(y * 10) / 10 };
        if (mapTeleportMarker) mapInstance.removeLayer(mapTeleportMarker);
        mapTeleportMarker = L.marker(event.latlng).addTo(mapInstance).bindPopup('Point de téléportation<br>X: ' +
            selectedMapTeleportPoint.x + ' · Y: ' + selectedMapTeleportPoint.y).openPopup();
        const button = document.getElementById('admin-map-teleport');
        const status = document.getElementById('map-updated-at');
        if (button) button.disabled = false;
        if (status) status.textContent = 'Point défini · X ' + selectedMapTeleportPoint.x + ' / Y ' + selectedMapTeleportPoint.y;
    });
}
const GTA_WORLD = { minX:-4500, maxX:4500, minY:-4500, maxY:8500 };
const GTA_MAP_SCALE = 8192 / (GTA_WORLD.maxY - GTA_WORLD.minY);
const GTA_MAP_OFFSET_X = (8192 - (GTA_WORLD.maxX - GTA_WORLD.minX) * GTA_MAP_SCALE) / 2;
function worldToMap(position) {
    const x = GTA_MAP_OFFSET_X + (Number(position.x) - GTA_WORLD.minX) * GTA_MAP_SCALE;
    const y = (Number(position.y) - GTA_WORLD.minY) * GTA_MAP_SCALE;
    return [y, x];
}

function mapToWorld(position) {
    return {
        x: ((Number(position.lng) - GTA_MAP_OFFSET_X) / GTA_MAP_SCALE) + GTA_WORLD.minX,
        y: (Number(position.lat) / GTA_MAP_SCALE) + GTA_WORLD.minY
    };
}
function renderPlayerMap() {
    if (!mapInstance) return;
    mapMarkers.forEach(marker => mapInstance.removeLayer(marker)); mapMarkers.clear();
    onlinePlayers.filter(player => player.position && Number.isFinite(Number(player.position.x)) && Number.isFinite(Number(player.position.y))).forEach(player => {
        const marker = L.marker(worldToMap(player.position), {
            icon:L.divIcon({ className:'gta-player-marker'+(Number(player.id)===Number(selectedPlayerId)?' selected':''), html:'<span>'+Number(player.id)+'</span>', iconSize:[30,30], iconAnchor:[15,15] }),
            title:(player.name||player.rawName||'Joueur')+' · ID '+player.id
        }).addTo(mapInstance);
        marker.on('click', () => { selectPlayer(player.id, player.name||player.rawName||'Joueur', player.job); renderMapPlayerList(); });
        mapMarkers.set(Number(player.id),marker);
    });
    const count=document.getElementById('map-player-count'); if(count) count.textContent=String(mapMarkers.size);
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
            ? (player.jobLabel || player.job || 'Inconnu') + ' · X ' + Number(player.position.x).toFixed(0) + ' / Y ' + Number(player.position.y).toFixed(0) + ' / Z ' + Number(player.position.z || 0).toFixed(0) + ' · ' + Number(player.ping || 0) + ' ms'
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

function changeMapZoom(factor) { if (!mapInstance) return; mapInstance.setZoom(Math.max(0,Math.min(5,mapInstance.getZoom()+(factor>1?1:-1)))); }
function resetMapView() { if (mapInstance) mapInstance.fitBounds([[0,0],[8192,8192]]); }

function manageAdminMoney() {
    const targetId = getPanelTarget('economy');
    if (!targetId) return;
    const type = document.getElementById('admin-economy-account')?.value;
    const operation = document.getElementById('admin-economy-operation')?.value;
    const amount = Number(document.getElementById('admin-economy-amount')?.value);
    if (!['cash', 'bank'].includes(type)) return showToast('Sélectionnez un compte valide.');
    if (!['give', 'remove'].includes(operation)) return showToast('Sélectionnez une opération valide.');
    if (!Number.isSafeInteger(amount) || amount < 1 || amount > 1000000) return showToast('Montant invalide (1 à 1 000 000).');
    nuiPost('manageEconomy', { playerId: targetId, type, amount, operation })
        .then(() => showToast('Demande transmise : le serveur confirme le résultat après sauvegarde MySQL.'))
        .catch(() => showToast('Impossible de transmettre cette opération.'));
}
function giveAdminVehicle() {
    const targetId = getPanelTarget('give'); if (!targetId) return;
    const model = (document.getElementById('admin-vehicle-model')?.value || '').trim();
    if (!/^[a-zA-Z0-9_]{2,40}$/.test(model)) return showToast('Saisissez un modèle de véhicule valide.');
    nuiPost('giveVehicle', { playerId: targetId, model }).then(() => showToast('Véhicule attribué au joueur ID ' + targetId + '.')).catch(() => showToast('Impossible d’attribuer le véhicule.'));
}
function renderAdminWeaponOptions() {
    const select = document.getElementById('admin-weapon-name');
    if (!select) return;
    const allowed = weaponPolicy.filter(weapon => weapon && weapon.enabled === true);
    const previous = select.value;
    select.replaceChildren(new Option(allowed.length ? 'Sélectionner une arme autorisée…' : 'Aucune arme autorisée', ''));
    allowed.forEach(weapon => select.add(new Option((weapon.label || weapon.name) + ' · ' + weapon.name, weapon.name)));
    if (allowed.some(weapon => weapon.name === previous)) select.value = previous;
}

function renderWeaponPolicy() {
    const root = document.getElementById('weapon-policy-list');
    if (!root) return;
    const query = (document.getElementById('weapon-policy-search')?.value || '').trim().toLowerCase();
    const filter = document.getElementById('weapon-policy-filter')?.value || 'all';
    const allowedCount = weaponPolicy.filter(weapon => weapon.enabled === true).length;
    const blockedCount = weaponPolicy.length - allowedCount;
    const allowedLabel = document.getElementById('weapon-policy-allowed');
    const blockedLabel = document.getElementById('weapon-policy-blocked');
    if (allowedLabel) allowedLabel.textContent = allowedCount + ' autorisées';
    if (blockedLabel) blockedLabel.textContent = blockedCount + ' interdites';
    root.replaceChildren();
    const filtered = weaponPolicy.filter(weapon => {
        const matchesText = !query || (weapon.label + ' ' + weapon.name + ' ' + weapon.category).toLowerCase().includes(query);
        const matchesState = filter === 'all' || (filter === 'allowed' ? weapon.enabled === true : weapon.enabled !== true);
        return matchesText && matchesState;
    });
    if (!filtered.length) {
        const empty = document.createElement('div'); empty.className = 'weapon-policy-empty';
        empty.textContent = weaponPolicy.length ? 'Aucune arme ne correspond à ce filtre.' : 'Catalogue indisponible.';
        root.appendChild(empty); return;
    }
    const groups = new Map();
    filtered.forEach(weapon => {
        const category = weapon.category || 'Autres';
        if (!groups.has(category)) groups.set(category, []);
        groups.get(category).push(weapon);
    });
    groups.forEach((weapons, category) => {
        const group = document.createElement('section'); group.className = 'weapon-policy-group';
        const heading = document.createElement('h4'); heading.textContent = category + ' · ' + weapons.length;
        const list = document.createElement('div'); list.className = 'weapon-policy-grid';
        weapons.forEach(weapon => {
            const row = document.createElement('label'); row.className = 'weapon-policy-row' + (weapon.enabled ? ' is-allowed' : ' is-blocked');
            const copy = document.createElement('span'); copy.className = 'weapon-policy-copy';
            const name = document.createElement('strong'); name.textContent = weapon.label || weapon.name;
            const code = document.createElement('small'); code.textContent = weapon.name;
            copy.append(name, code);
            const status = document.createElement('span'); status.className = 'weapon-policy-status';
            status.textContent = weapon.enabled ? 'AUTORISÉE' : 'INTERDITE';
            const toggle = document.createElement('input'); toggle.type = 'checkbox'; toggle.checked = weapon.enabled === true;
            toggle.setAttribute('aria-label', (weapon.label || weapon.name) + ' autorisée');
            toggle.addEventListener('change', () => {
                weapon.enabled = toggle.checked;
                row.classList.toggle('is-allowed', toggle.checked);
                row.classList.toggle('is-blocked', !toggle.checked);
                status.textContent = toggle.checked ? 'AUTORISÉE' : 'INTERDITE';
                const saveStatus = document.getElementById('weapon-policy-status');
                if (saveStatus) saveStatus.textContent = 'Modifications non enregistrées.';
                renderAdminWeaponOptions();
                updateWeaponPolicyCounts();
            });
            row.append(copy, status, toggle); list.appendChild(row);
        });
        group.append(heading, list); root.appendChild(group);
    });
    updateWeaponPolicyCounts();
}

function updateWeaponPolicyCounts() {
    const allowed = weaponPolicy.filter(weapon => weapon.enabled === true).length;
    const blocked = weaponPolicy.length - allowed;
    const a = document.getElementById('weapon-policy-allowed'), b = document.getElementById('weapon-policy-blocked');
    if (a) a.textContent = allowed + ' autorisées';
    if (b) b.textContent = blocked + ' interdites';
}

function saveWeaponPolicy() {
    if (!weaponPolicy.length) return showToast('Le catalogue des armes est indisponible.');
    const policy = {};
    weaponPolicy.forEach(weapon => { policy[weapon.name] = weapon.enabled === true; });
    const button = document.querySelector('#admin-weapons-view .weapon-policy-actions button');
    if (button) button.disabled = true;
    nuiPost('saveWeaponPolicy', { policy })
        .then(() => {
            const status = document.getElementById('weapon-policy-status');
            if (status) status.textContent = 'Enregistrement envoyé au serveur…';
            showToast('Enregistrement des autorisations demandé.');
        })
        .catch(() => showToast('Impossible d’enregistrer les autorisations des armes.'))
        .finally(() => { if (button) button.disabled = false; });
}

function giveAdminWeapon() {
    const targetId = getPanelTarget('give'); if (!targetId) return;
    const weapon = document.getElementById('admin-weapon-name')?.value; if (!weapon) return showToast('Sélectionnez une arme autorisée.');
    if (!weaponPolicy.some(item => item.name === weapon && item.enabled === true)) return showToast('Cette arme est désactivée dans la politique serveur.');
    nuiPost('giveWeapon', { playerId: targetId, weapon }).then(() => showToast('Demande d’attribution envoyée au serveur pour le joueur ID ' + targetId + '.')).catch(() => showToast('Impossible d’envoyer la demande d’attribution.'));
}
function renderItemCatalog() {
    const select = document.getElementById('admin-item-name'); if (!select) return;
    select.replaceChildren(new Option(itemCatalog.length ? 'Sélectionner un item…' : 'Catalogue indisponible', ''));
    itemCatalog.forEach(item => { if (item && typeof item.name === 'string') select.add(new Option((item.label || item.name) + ' · ' + item.name, item.name)); });
}
function giveAdminItem() {
    const targetId = getPanelTarget('give'); if (!targetId) return;
    const item = document.getElementById('admin-item-name')?.value, count = Number(document.getElementById('admin-item-count')?.value);
    if (!item || !Number.isInteger(count) || count < 1 || count > 1000) return showToast('Item ou quantité invalide.');
    nuiPost('giveItem', { playerId: targetId, item, count }).then(() => showToast('Item attribué au joueur ID ' + targetId + '.')).catch(() => showToast('Impossible d’attribuer cet item.'));
}

function setSelectedJob() {
    const targetId = getPanelTarget('job'); if (!targetId) return;
    const jobName = document.getElementById('admin-job-name')?.value;
    const grade = Number(document.getElementById('admin-job-grade')?.value);
    if (!jobName || !Number.isInteger(grade) || grade < 0 || grade > 20) return showToast('Métier ou grade invalide.');
    nuiPost('setJob', { playerId: targetId, jobName, grade })
        .then(() => showToast('Métier attribué : ' + jobName + ' (grade ' + grade + ').'))
        .catch(() => showToast('Impossible de modifier le métier.'));
}

function renderJobOptions() {
    const select = document.getElementById('admin-job-name');
    if (!select) return;
    const previous = select.value;
    select.replaceChildren(new Option('Choisir un métier…', ''));
    availableJobs.forEach(job => {
        if (!job || typeof job.name !== 'string') return;
        select.add(new Option(job.label || job.name, job.name));
    });
    if (availableJobs.some(job => job.name === previous)) select.value = previous;
    renderJobGrades();
}

function renderJobGrades() {
    const jobName = document.getElementById('admin-job-name')?.value;
    const gradeSelect = document.getElementById('admin-job-grade');
    if (!gradeSelect) return;
    gradeSelect.replaceChildren();
    const job = availableJobs.find(item => item && item.name === jobName);
    const grades = job && job.grades && typeof job.grades === 'object' ? Object.entries(job.grades) : [];
    grades.sort((a, b) => Number(a[0]) - Number(b[0])).forEach(([grade, details]) => {
        gradeSelect.add(new Option((details && details.label ? details.label : 'Grade ' + grade) + ' · ' + grade, String(grade)));
    });
    if (!grades.length) gradeSelect.add(new Option('Grade 0', '0'));
}

function updateOnlinePlayerPositions(players) {
    const current = new Map(onlinePlayers.map(player => [Number(player.id), player]));
    const incoming = Array.isArray(players) ? players : [];
    onlinePlayers = incoming.map(player => Object.assign({}, current.get(Number(player.id)) || {}, player));
    renderOnlinePlayers();
    renderPlayerPickers();
    renderPlayerMap();
    renderMapPlayerList();
    const count = document.getElementById('map-player-count');
    if (count) count.textContent = String(onlinePlayers.length);
    const updated = document.getElementById('map-updated-at');
    if (updated) updated.textContent = 'Mis à jour à ' + new Date().toLocaleTimeString('fr-FR');
}

function toggleAdminMode(mode) {
    const endpoint = mode === 'noclip' ? 'toggleNoclip' : mode === 'godmode' ? 'toggleGodmode' : null;
    if (!endpoint) return;
    nuiPost(endpoint).then(() => showToast('Demande ' + mode + ' envoyée.')).catch(() => showToast('Impossible de modifier le mode ' + mode + '.'));
}

function stopAdminSpectate() {
    nuiPost('stopSpectate').catch(() => showToast('Impossible d’arrêter la surveillance.'));
}

function spawnAdminVehicle() {
    const input = document.getElementById('admin-vehicle-model');
    const model = (input?.value || '').trim();
    if (!/^[a-zA-Z0-9_]{2,40}$/.test(model)) return showToast('Saisissez un modèle valide (ex. sultan).');
    nuiPost('spawnVehicle', { model }).then(() => showToast('Demande de création envoyée.')).catch(() => showToast('Création du véhicule impossible.'));
}
function applyAdminWorldTime() {
    const weather = document.getElementById('admin-weather')?.value || '';
    const hours = Number(document.getElementById('admin-world-hours')?.value);
    const minutes = Number(document.getElementById('admin-world-minutes')?.value);
    if (!Number.isInteger(hours) || hours < 0 || hours > 23 || !Number.isInteger(minutes) || minutes < 0 || minutes > 59) {
        return showToast('Heure invalide : utilisez 0–23 heures et 0–59 minutes.');
    }
    nuiPost('setWeatherTime', { weather, hours, minutes })
        .then(() => showToast('Heure et météo envoyées au serveur.'))
        .catch(() => showToast('Impossible de modifier l’heure ou la météo.'));
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
