let currentPlayers = [];
let currentProtections = {};
let selectedSpectateId = null;
let threatCount = 0;

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'open') {
        currentProtections = data.protections || {};
        currentPlayers = data.players || [];
        document.getElementById('stat-players').innerText = currentPlayers.length;
        renderProtections(currentProtections);
        updateProtectionStats(currentProtections);
        renderSurveillancePlayers(currentPlayers);
        document.getElementById('anticheat-window').classList.remove('hidden');
    } else if (data.action === 'protections') {
        currentProtections = data.protections || {};
        renderProtections(currentProtections);
        updateProtectionStats(currentProtections);
    } else if (data.action === 'updatePlayers') {
        currentPlayers = Array.isArray(data.players) ? data.players : [];
        document.getElementById('stat-players').innerText = currentPlayers.length;
        renderSurveillancePlayers(currentPlayers);
        if (selectedSpectateId !== null) updateSelectedTelemetry();
    } else if (data.action === 'close') {
        document.getElementById('anticheat-window').classList.add('hidden');
    } else if (data.action === 'newDetection') {
        threatCount++;
        document.getElementById('stat-threats').innerText = threatCount;
        addDetectionLog(data.alert);
    }
});

// Tab Switching
document.querySelectorAll('.nav-item').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.nav-item').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));
        btn.classList.add('active');

        const tab = btn.dataset.tab;
        document.getElementById(`pane-${tab}`).classList.add('active');
    });
});

function updateProtectionStats(protections) {
    const modules = Object.values(protections || {});
    const active = modules.filter(item => item && item.enabled === true).length;
    const counter = document.getElementById('stat-modules');
    if (counter) counter.textContent = `${active}/${modules.length}`;
}

function renderProtections(protections) {
    const grid = document.getElementById('protections-list');
    grid.innerHTML = '';

    for (const [key, prot] of Object.entries(protections)) {
        const card = document.createElement('div');
        card.className = 'protection-card';
        card.innerHTML = `
            <div class="prot-info">
                <h5>${prot.label}</h5>
                <p>Détection active côté client & serveur</p>
            </div>
            <label class="switch">
                <input type="checkbox" ${prot.enabled ? 'checked' : ''} data-key="${key}">
                <span class="slider"></span>
            </label>
        `;
        const checkbox = card.querySelector('input');
        checkbox.addEventListener('change', () => {
            fetch(`https://rp_anticheat/toggleProtection`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ protectionKey: key, state: checkbox.checked })
            });
        });
        grid.appendChild(card);
    }
}

function renderSurveillancePlayers(players) {
    const list = document.getElementById('surveillance-players');
    if (!list) return;
    list.replaceChildren();
    players.forEach(p => {
        const row = document.createElement('button');
        row.type = 'button';
        row.className = 'p-card';
        row.classList.toggle('is-self', p.isSelf === true);
        const info = document.createElement('div');
        const name = document.createElement('strong');
        name.textContent = String(p.name || p.rawName || ('Joueur ' + p.id)) + (p.isSelf ? ' (VOUS)' : '');
        const id = document.createElement('small');
        id.textContent = ' (ID ' + p.id + ')';
        info.append(name, id);
        const eye = document.createElement('i');
        eye.className = 'fa-solid fa-eye';
        eye.style.color = p.isSelf ? '#22c55e' : '#ef4444';
        row.append(info, eye);
        row.addEventListener('click', () => {
            selectedSpectateId = Number(p.id);
            updateSelectedTelemetry();
            // Selecting yourself is supported for live telemetry; spectating yourself is not.
            if (p.isSelf !== true) {
                fetch('https://rp_anticheat/spectatePlayer', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ targetId: p.id })
                }).catch(() => {});
            } else {
                document.getElementById('cam-target-name').textContent = name.textContent;
            }
        });
        list.appendChild(row);
    });
}

function updateSelectedTelemetry() {
    const player = currentPlayers.find(item => Number(item.id) === Number(selectedSpectateId));
    if (!player) {
        selectedSpectateId = null;
        document.getElementById('cam-target-name').textContent = 'AUCUNE CIBLE';
        return;
    }
    document.getElementById('cam-target-name').textContent =
        String(player.name || player.rawName || 'Joueur') + (player.isSelf ? ' (VOUS)' : '') + ' (ID ' + player.id + ')';
    const health = Number(player.health) || 0;
    document.getElementById('telemetry-hp').textContent = Math.max(0, Math.min(100, Math.round(health / 2))) + '%';
    document.getElementById('telemetry-armor').textContent = Math.max(0, Math.min(100, Number(player.armor) || 0)) + '%';
    document.getElementById('telemetry-ping').textContent = (Number(player.ping) || 0) + 'ms';
}

function addDetectionLog(alert) {
    const feed = document.getElementById('live-alerts-feed');
    if (feed.querySelector('.empty-state')) feed.innerHTML = '';

    const item = document.createElement('div');
    item.className = 'detection-alert-item';
    item.style.padding = '10px';
    item.style.marginBottom = '8px';
    item.style.borderRadius = '8px';
    item.style.background = 'rgba(239, 68, 68, 0.15)';
    item.style.borderLeft = '4px solid #ef4444';
    item.innerHTML = `<strong>[${alert.time}]</strong> ${alert.playerName} (ID ${alert.playerId}) : <span style="color:#ef4444;">${alert.reason}</span>`;
    feed.prepend(item);

    const tbody = document.getElementById('logs-table-body');
    const tr = document.createElement('tr');
    tr.innerHTML = `
        <td>${alert.time}</td>
        <td>${alert.playerName} (${alert.playerId})</td>
        <td><strong style="color:#ef4444;">${alert.reason}</strong></td>
        <td><button style="padding:4px 8px; background:#eab308; border:none; border-radius:4px; color:black; cursor:pointer;" onclick="punish(${alert.playerId}, 'kick')">Kick</button></td>
    `;
    tbody.prepend(tr);
}

function punish(id, type) {
    fetch(`https://rp_anticheat/punishPlayer`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ targetId: id, punishType: type, reason: 'Triche détectée par Anticheat' })
    });
}

document.getElementById('btn-stop-spectate').addEventListener('click', () => {
    fetch(`https://rp_anticheat/stopSpectate`, { method: 'POST', body: '{}' });
    document.getElementById('cam-target-name').innerText = 'AUCUNE CIBLE';
});

document.getElementById('btn-cam-kick').addEventListener('click', () => {
    if (selectedSpectateId) punish(selectedSpectateId, 'kick');
});

document.getElementById('btn-cam-ban').addEventListener('click', () => {
    if (selectedSpectateId) punish(selectedSpectateId, 'ban');
});

function closeAnticheatUI() {
    document.getElementById('anticheat-window').classList.add('hidden');
    fetch(`https://rp_anticheat/close`, { method: 'POST', body: '{}' }).catch(() => {});
}

document.getElementById('btn-close').addEventListener('click', () => {
    closeAnticheatUI();
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { e.preventDefault(); closeAnticheatUI(); }
});
