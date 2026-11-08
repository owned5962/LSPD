let currentAdmin = null;
let currentPlayers = [];
let allJobs = [];

// Clock update
setInterval(() => {
    const d = new Date();
    const hours = String(d.getHours()).padStart(2, '0');
    const mins = String(d.getMinutes()).padStart(2, '0');
    const timeEl = document.getElementById('tablet-time');
    if (timeEl) timeEl.innerText = `${hours}:${mins}`;
}, 1000);

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openTablet') {
        currentAdmin = data.admin || {};
        currentPlayers = data.players || [];
        allJobs = data.jobs || [];

        document.getElementById('admin-name').innerText = (currentAdmin.name || 'ADMIN').toUpperCase();
        document.getElementById('tablet-wrapper').classList.remove('hidden');

        populateJobsSelector();
        populatePlayersTable();
        navigateTo('homescreen');
    } else if (data.action === 'closeTablet') {
        document.getElementById('tablet-wrapper').classList.add('hidden');
    }
});

function navigateTo(appId) {
    document.querySelectorAll('.app-screen').forEach(el => el.classList.remove('active'));
    const target = document.getElementById(`app-${appId}`);
    if (target) {
        target.classList.add('active');
    }
}

// App grid navigation
document.querySelectorAll('.app-icon-item').forEach(item => {
    item.addEventListener('click', () => {
        const app = item.getAttribute('data-app');
        navigateTo(app);
    });
});

document.querySelectorAll('.back-btn').forEach(btn => {
    btn.addEventListener('click', () => navigateTo('homescreen'));
});

document.getElementById('dock-home').addEventListener('click', () => navigateTo('homescreen'));

function closeTablet() {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});
    document.getElementById('tablet-wrapper').classList.add('hidden');
}

document.getElementById('dock-power').addEventListener('click', closeTablet);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'F10') {
        closeTablet();
    }
});

function populateJobsSelector() {
    const sel = document.getElementById('job-selector');
    sel.innerHTML = '';
    allJobs.forEach(j => {
        const opt = document.createElement('option');
        opt.value = j.name;
        opt.innerText = `${j.label} (${j.category})`;
        sel.appendChild(opt);
    });
}

function populatePlayersTable() {
    const tbody = document.getElementById('players-tbody');
    tbody.innerHTML = '';

    if (currentPlayers.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding: 20px; color:#94a3b8;">Aucun joueur connecté actuellement.</td></tr>';
        return;
    }

    currentPlayers.forEach(p => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td><strong>#${p.id}</strong></td>
            <td>${p.name} <br><small style="color:#94a3b8;">(${p.rawName})</small></td>
            <td>${p.jobLabel || p.job} (Grade ${p.grade})</td>
            <td><span style="color:#10b981;">${p.cash} $</span></td>
            <td><span style="color:#38bdf8;">${p.bank} $</span></td>
            <td>
                <div class="table-actions">
                    <button class="mini-btn blue btn-tp" title="Se téléporter"><i class="fas fa-location-arrow"></i> TP</button>
                    <button class="mini-btn orange btn-bring" title="Amener le joueur"><i class="fas fa-magnet"></i> Bring</button>
                    <button class="mini-btn green btn-revive" title="Réanimer"><i class="fas fa-first-aid"></i> Heal</button>
                    <button class="mini-btn red btn-freeze" title="Geler / Dégeler"><i class="fas fa-snowflake"></i></button>
                    <button class="mini-btn red btn-kick" title="Expulser"><i class="fas fa-user-times"></i></button>
                </div>
            </td>
        `;

        tr.querySelector('.btn-tp').addEventListener('click', () => {
            fetch(`https://${GetParentResourceName()}/teleportToPlayer`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ playerId: p.id })
            });
        });

        tr.querySelector('.btn-bring').addEventListener('click', () => {
            fetch(`https://${GetParentResourceName()}/bringPlayer`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ playerId: p.id })
            });
        });

        tr.querySelector('.btn-revive').addEventListener('click', () => {
            fetch(`https://${GetParentResourceName()}/revivePlayer`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ playerId: p.id })
            });
        });

        let frozen = false;
        tr.querySelector('.btn-freeze').addEventListener('click', () => {
            frozen = !frozen;
            fetch(`https://${GetParentResourceName()}/freezePlayer`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ playerId: p.id, freeze: frozen })
            });
        });

        tr.querySelector('.btn-kick').addEventListener('click', () => {
            const reason = prompt(`Raison de l'expulsion pour ${p.name}:`, "Expulsion administrative");
            if (reason) {
                fetch(`https://${GetParentResourceName()}/kickPlayer`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ playerId: p.id, reason })
                });
            }
        });

        tbody.appendChild(tr);
    });
}

// Economy actions
document.getElementById('btn-eco-give').addEventListener('click', () => {
    const playerId = document.getElementById('eco-player-id').value;
    const type = document.getElementById('eco-type').value;
    const amount = document.getElementById('eco-amount').value;
    if (!playerId || !amount) return;

    fetch(`https://${GetParentResourceName()}/manageEconomy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playerId, type, amount, operation: 'give' })
    });
    document.getElementById('eco-amount').value = '';
});

document.getElementById('btn-eco-remove').addEventListener('click', () => {
    const playerId = document.getElementById('eco-player-id').value;
    const type = document.getElementById('eco-type').value;
    const amount = document.getElementById('eco-amount').value;
    if (!playerId || !amount) return;

    fetch(`https://${GetParentResourceName()}/manageEconomy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playerId, type, amount, operation: 'remove' })
    });
    document.getElementById('eco-amount').value = '';
});

// Job Assignment
document.getElementById('btn-assign-job').addEventListener('click', () => {
    const playerId = document.getElementById('job-player-id').value;
    const jobName = document.getElementById('job-selector').value;
    const grade = document.getElementById('job-grade-input').value;
    if (!playerId || !jobName) return;

    fetch(`https://${GetParentResourceName()}/setJob`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playerId, jobName, grade })
    });
});

// Vehicles
document.getElementById('btn-spawn-veh').addEventListener('click', () => {
    const model = document.getElementById('veh-model-input').value.trim();
    if (!model) return;
    fetch(`https://${GetParentResourceName()}/spawnVehicle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ model })
    });
});

document.getElementById('btn-delete-veh').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/deleteVehicle`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
});

// World & Weather
document.getElementById('btn-apply-world').addEventListener('click', () => {
    const weather = document.getElementById('weather-select').value;
    const hours = document.getElementById('time-hours').value;
    const minutes = document.getElementById('time-minutes').value;
    fetch(`https://${GetParentResourceName()}/setWeatherTime`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ weather, hours, minutes })
    });
});

// Broadcast
document.getElementById('btn-send-broadcast').addEventListener('click', () => {
    const message = document.getElementById('broadcast-message').value.trim();
    if (!message) return;
    fetch(`https://${GetParentResourceName()}/broadcastAnnouncement`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message })
    });
    document.getElementById('broadcast-message').value = '';
});

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'rp_tablet_admin';
}
