let progressInterval = null;
let textUiHideTimer = null;
let notificationSequence = 0;

function hideTextUI() {
    if (textUiHideTimer !== null) {
        clearTimeout(textUiHideTimer);
        textUiHideTimer = null;
    }
    document.getElementById('textui-container')?.classList.add('hidden');
}

window.addEventListener('message', function(event) {
    const data = event.data || {};

    if (data.action === 'updateVehicleHUD') {
        const hud = document.getElementById('vehicle-hud');
        hud?.classList.toggle('hidden', data.visible !== true);
        const speed = document.getElementById('vehicle-speed'); if (speed) speed.textContent = String(Math.max(0, Number(data.speed) || 0));
        const fuel = Math.max(0, Math.min(100, Number(data.fuel) || 0));
        const fuelText = document.getElementById('vehicle-fuel'); if (fuelText) fuelText.textContent = Math.round(fuel) + '%';
        const fuelBar = document.getElementById('vehicle-fuel-bar'); if (fuelBar) fuelBar.style.width = fuel + '%';
        const gear = document.getElementById('vehicle-gear'); if (gear) gear.textContent = Number(data.gear) === 0 ? 'R' : String(data.gear || 'N');
    } else if (data.action === 'hideVehicleHUD') {
        document.getElementById('vehicle-hud')?.classList.add('hidden');
    } else if (data.action === 'notify') {
        showRPNotification(data.message, data.kind, data.duration);
    } else if (data.action === 'updateHUD') {
        updatePlayerHUD(data);
    } else if (data.action === 'hideHUD') {
        document.getElementById('player-hud')?.classList.add('hidden');
        document.getElementById('hud-job-panel')?.classList.add('hidden');
    } else if (data.action === 'showDiagnostics') {
        document.getElementById('client-diagnostics')?.classList.remove('hidden');
    } else if (data.action === 'hideDiagnostics') {
        document.getElementById('client-diagnostics')?.classList.add('hidden');
    } else if (data.action === 'updateDiagnostics') {
        const setDiag = (id, value) => { const el = document.getElementById(id); if (el) el.textContent = String(value); };
        setDiag('diag-fps', Math.max(0, Number(data.fps) || 0));
        setDiag('diag-ping', Math.max(0, Number(data.ping) || 0) + ' ms');
        setDiag('diag-players', (Number(data.players) || 0) + ' / ' + (Number(data.maxPlayers) || 0));
        const c = data.coords || {};
        setDiag('diag-coords', [c.x, c.y, c.z].join(' / '));
    } else if (data.action === 'showTextUI') {
        const textElement = document.getElementById('textui-text');
        if (textElement) textElement.textContent = String(data.text ?? '');
        document.getElementById('textui-container')?.classList.remove('hidden');
        if (textUiHideTimer !== null) clearTimeout(textUiHideTimer);
        // Job resources refresh the prompt while the player remains nearby.
        // Auto-hide it when they leave, even if a resource forgets to send hideTextUI.
        textUiHideTimer = setTimeout(hideTextUI, 350);
    } else if (data.action === 'hideTextUI') {
        hideTextUI();
    } else if (data.action === 'startProgress') {
        startProgress(data.duration, data.label, data.canCancel);
    } else if (data.action === 'cancelProgress') {
        cancelProgress();
    }
});

function startProgress(duration, label, canCancel) {
    clearInterval(progressInterval);
    const container = document.getElementById('progress-container');
    const labelEl = document.getElementById('progress-label');
    const fillEl = document.getElementById('progress-fill');
    const percentEl = document.getElementById('progress-percentage');

    labelEl.innerText = label || 'Action...';
    fillEl.style.width = '0%';
    percentEl.innerText = '0%';
    container.classList.remove('hidden');

    duration = Math.max(100, Math.min(120000, Number(duration) || 5000));
    const startTime = Date.now();
    progressInterval = setInterval(() => {
        const elapsed = Date.now() - startTime;
        let progress = (elapsed / duration) * 100;
        if (progress > 100) progress = 100;

        fillEl.style.width = progress + '%';
        percentEl.innerText = Math.floor(progress) + '%';

        if (progress >= 100) {
            clearInterval(progressInterval);
            setTimeout(() => {
                container.classList.add('hidden');
            }, 250);
        }
    }, 50);
}

function cancelProgress() {
    clearInterval(progressInterval);
    document.getElementById('progress-container').classList.add('hidden');
}


function updatePlayerHUD(data) {
    const hud = document.getElementById('player-hud');
    if (!hud) return;
    const setText = (id, value) => { const el = document.getElementById(id); if (el) el.textContent = String(value); };
    const setBar = (id, value) => {
        const el = document.getElementById(id);
        if (el) el.style.width = Math.max(0, Math.min(100, Number(value) || 0)) + '%';
    };
    setText('hud-job', data.job || 'Sans-emploi');
    setText('hud-grade', data.grade || '');
    document.getElementById('hud-job-panel')?.classList.toggle('hidden', data.visible !== true);
    ['health', 'armor', 'hunger', 'thirst'].forEach(key => {
        const value = Math.max(0, Math.min(100, Number(data[key]) || 0));
        setText('hud-' + key, Math.round(value) + '%');
        setBar('hud-' + key + '-bar', value);
    });
    hud.classList.toggle('hidden', data.visible !== true);
}


function showRPNotification(message, kind, duration) {
    const host = document.getElementById('rp-notifications');
    if (!host) return;
    const toast = document.createElement('div');
    toast.className = 'rp-toast ' + (['success','error','warning'].includes(kind) ? kind : 'info');
    const title = document.createElement('strong');
    title.textContent = kind === 'success' ? 'SUCCÈS' : kind === 'error' ? 'ERREUR' : kind === 'warning' ? 'ATTENTION' : 'LOS SANTOS RP';
    const body = document.createElement('span');
    body.textContent = String(message || '');
    toast.append(title, body);
    host.appendChild(toast);
    const id = ++notificationSequence;
    setTimeout(() => { toast.classList.add('leaving'); setTimeout(() => toast.remove(), 250); }, Math.max(1500, Math.min(10000, Number(duration) || 4000)));
    while (host.children.length > 5) host.firstElementChild.remove();
}

document.getElementById('close-diagnostics')?.addEventListener('click', () => {
    fetch('https://' + (window.GetParentResourceName ? GetParentResourceName() : 'rp_ui') + '/closeDiagnostics', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}'
    }).catch(() => {});
});
