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
        renderSurveillancePlayers(currentPlayers);
        document.getElementById('anticheat-window').classList.remove('hidden');
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
            fetch(`https://${rp_anticheat}/toggleProtection`, {
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
    list.innerHTML = '';

    players.forEach(p => {
        const row = document.createElement('div');
        row.className = 'p-card';
        row.innerHTML = `
            <div>
                <strong>${p.name}</strong> <small>(ID ${p.id})</small>
            </div>
            <i class="fa-solid fa-eye" style="color: #ef4444;"></i>
        `;
        row.addEventListener('click', () => {
            selectedSpectateId = p.id;
            document.getElementById('cam-target-name').innerText = `${p.name} (ID ${p.id})`;
            document.getElementById('telemetry-hp').innerText = `${p.health || 100}%`;
            document.getElementById('telemetry-armor').innerText = `${p.armor || 0}%`;
            document.getElementById('telemetry-ping').innerText = `${p.ping || 25}ms`;

            fetch(`https://${rp_anticheat}/spectatePlayer`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ targetId: p.id })
            });
        });
        list.appendChild(row);
    });
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
    fetch(`https://${rp_anticheat}/punishPlayer`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ targetId: id, punishType: type, reason: 'Triche détectée par Anticheat' })
    });
}

document.getElementById('btn-stop-spectate').addEventListener('click', () => {
    fetch(`https://${rp_anticheat}/stopSpectate`, { method: 'POST', body: '{}' });
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
    fetch(`https://${rp_anticheat}/close`, { method: 'POST', body: '{}' }).catch(() => {});
}

document.getElementById('btn-close').addEventListener('click', () => {
    closeAnticheatUI();
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { e.preventDefault(); closeAnticheatUI(); }
});
