// State & Configuration
let currentMode = 'admin'; // 'admin' ou 'creator'
let activeGrade = 'superoperator';
let selectedPlayerId = 1;

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
    setupTabSwitching();
    renderPermissionsMatrix();
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
    showToast(`Permissions enregistrées avec succès pour ${activeGrade.toUpperCase()} !`);
    if (window.invokeNative) {
        fetch(`https://${GetParentResourceName()}/savePermissions`, {
            method: 'POST',
            body: JSON.stringify({ grade: activeGrade, permissions: rolePermissions[activeGrade] })
        });
    }
}

// Actions du Menu Admin
function selectPlayer(id, name, job) {
    selectedPlayerId = id;
    document.querySelectorAll('.player-entry').forEach(el => el.classList.remove('selected'));
    event.currentTarget.classList.add('selected');
    document.getElementById('selected-target-name').textContent = `${name.replace('_', ' ')} [ID: ${id}]`;
}

function playerAction(action) {
    showToast(`Action '${action.toUpperCase()}' exécutée sur le joueur #${selectedPlayerId}`);
    if (window.invokeNative) {
        fetch(`https://${GetParentResourceName()}/adminAction`, {
            method: 'POST',
            body: JSON.stringify({ action: action, target: selectedPlayerId })
        });
    }
}

function triggerAdminAction(act) {
    showToast(`Action globale exécutée : ${act}`);
}

// Commandes du serveur depuis le Menu Créateur
function setWeather(weather) {
    showToast(`Météo du serveur changée en : ${weather}`);
}

function setTime(h, m) {
    showToast(`Heure du monde ajustée : ${h}h00`);
}

function sendBroadcast() {
    const input = document.getElementById('broadcast-msg');
    const msg = input.value.trim();
    if (!msg) return;
    showToast(`Annonce Créateur diffusée : "${msg}"`);
    input.value = '';
}

function wipeVehicles() {
    showToast('Purge de tous les véhicules abandonnés lancée !');
}

function wipePeds() {
    showToast('Nettoyage des entités et PNJ achevé.');
}

function toggleWhitelist() {
    showToast('Statut de protection et verrouillage du serveur basculé.');
}

function showToast(msg) {
    const toast = document.getElementById('toast-notify');
    if (!toast) return;
    toast.textContent = msg;
    toast.style.display = 'block';
    setTimeout(() => {
        toast.style.display = 'none';
    }, 2800);
}
