let progressInterval = null;
let notificationSequence = 0;

function hideTextUI() {
    document.getElementById('textui-container')?.classList.add('hidden');
}

window.addEventListener('message', function(event) {
    const data = event.data || {};

    if (data.action === 'updateVehicleHUD') {
        const hud = document.getElementById('vehicle-hud');
        hud?.classList.toggle('hidden', data.visible !== true);
        const vehicleType = document.getElementById('vehicle-type'); if (vehicleType) vehicleType.textContent = String(data.vehicleType || 'VÉHICULE');
        const vehicleModel = document.getElementById('vehicle-model'); if (vehicleModel) vehicleModel.textContent = String(data.vehicleName || '--');
        const speed = document.getElementById('vehicle-speed'); if (speed) speed.textContent = String(Math.max(0, Number(data.speed) || 0));
        const fuel = Math.max(0, Math.min(100, Number(data.fuel) || 0));
        const fuelText = document.getElementById('vehicle-fuel'); if (fuelText) fuelText.textContent = Math.round(fuel) + '%';
        const fuelBar = document.getElementById('vehicle-fuel-bar');
        if (fuelBar) {
            fuelBar.style.width = fuel + '%';
            fuelBar.style.background = fuel <= 15 ? '#ef4444' : fuel <= 30 ? '#f59e0b' : '#34d399';
        }
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
        activateDiagnosticsTab('overview');
    } else if (data.action === 'hideDiagnostics') {
        document.getElementById('client-diagnostics')?.classList.add('hidden');
    } else if (data.action === 'updateDiagnostics') {
        const setDiag = (id, value) => { const el = document.getElementById(id); if (el) el.textContent = String(value); };
        const fps = Math.max(0, Number(data.fps) || 0);
        const ping = Math.max(0, Number(data.ping) || 0);
        setDiag('diag-fps', fps);
        setDiag('diag-fps-performance', fps);
        setDiag('diag-ping', ping + ' ms');
        pushDiagnosticSample(fpsSamples, fps, 'diag-fps-chart', '', 'En attente de FPS…');
        pushDiagnosticSample(pingSamples, ping, 'diag-ping-chart', ' ms', 'En attente de ping…');
        const frameMs = Math.max(0, Number(data.frameMs) || 0);
        setDiag('diag-frame-ms', frameMs.toFixed(2) + ' ms');
        setDiag('diag-frame-current', frameMs.toFixed(2) + ' ms');
        pushFrameSample(frameMs);
        const c = data.coords || {};
        setDiag('diag-coords', [c.x, c.y, c.z].join(' / '));
    } else if (data.action === 'updateServerDiagnostics') {
        renderServerDiagnostics(data.stats || {});
    } else if (data.action === 'showTextUI') {
        const textElement = document.getElementById('textui-text');
        if (textElement) textElement.textContent = String(data.text ?? '');
        // Keep the prompt visible until the owning resource explicitly hides it.
        // This avoids flicker when proximity loops refresh at intervals above 350 ms.
        document.getElementById('textui-container')?.classList.remove('hidden');
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
    const setCircle = (id, value) => {
        const el = document.getElementById(id);
        if (el) el.style.setProperty('--progress', Math.max(0, Math.min(100, Number(value) || 0)) + '%');
    };

    ['hunger', 'thirst', 'stamina'].forEach(key => {
        const value = Math.max(0, Math.min(100, Number(data[key]) || 0));
        setText('hud-' + key, Math.round(value) + '%');
        setCircle('hud-' + key + '-circle', value);
    });

    const jobPanel = document.getElementById('hud-job-panel');
    const jobLabel = document.getElementById('hud-job-label');
    const jobGrade = document.getElementById('hud-job-grade');
    const jobDuty = document.getElementById('hud-job-duty');
    if (jobLabel) jobLabel.textContent = String(data.jobLabel || 'Sans-emploi');
    if (jobGrade) jobGrade.textContent = String(data.jobGradeLabel || 'Demandeur');
    if (jobDuty) {
        jobDuty.textContent = data.duty === true ? 'EN SERVICE' : 'HORS SERVICE';
        jobDuty.classList.toggle('on-duty', data.duty === true);
    }
    jobPanel?.classList.toggle('hidden', data.visible !== true);

    const adminLevel = Math.max(0, Math.min(4, Math.floor(Number(data.adminLevel) || 0)));
    const adminCircle = document.getElementById('hud-admin-circle');
    setText('hud-admin-level', adminLevel);
    if (adminCircle) adminCircle.dataset.level = String(adminLevel);

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


// Lightweight local charts for the F12 diagnostics panel.
const frameSamples = [], fpsSamples = [], pingSamples = [], registrationSamples = [];
function pushDiagnosticSample(target, value, canvasId, suffix, emptyLabel) {
    if (!Number.isFinite(value)) return;
    target.push({ label: new Date().toLocaleTimeString('fr-FR', {hour:'2-digit', minute:'2-digit', second:'2-digit'}), value });
    if (target.length > 30) target.shift();
    drawLineChart(canvasId, target, suffix, emptyLabel);
}
function drawLineChart(canvasId, values, suffix, emptyLabel) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    const width = Math.max(180, canvas.clientWidth || 320);
    const height = Number(canvas.getAttribute('height')) || 90;
    const ratio = window.devicePixelRatio || 1;
    canvas.width = Math.round(width * ratio);
    canvas.height = Math.round(height * ratio);
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    ctx.clearRect(0, 0, width, height);
    ctx.font = '10px Segoe UI';
    ctx.fillStyle = '#94a3b8';
    if (!values.length) { ctx.fillText(emptyLabel || 'Aucune donnée', 8, 18); return; }
    const pad = { left: 8, right: 8, top: 10, bottom: 17 };
    const plotW = width - pad.left - pad.right;
    const plotH = height - pad.top - pad.bottom;
    const max = Math.max(1, ...values.map(v => Number(v.value) || 0));
    ctx.strokeStyle = 'rgba(148,163,184,.18)';
    ctx.lineWidth = 1;
    for (let i = 0; i < 3; i++) {
        const y = pad.top + plotH * i / 2;
        ctx.beginPath(); ctx.moveTo(pad.left, y); ctx.lineTo(width - pad.right, y); ctx.stroke();
    }
    ctx.strokeStyle = '#38bdf8'; ctx.lineWidth = 2; ctx.beginPath();
    values.forEach((point, index) => {
        const x = pad.left + (values.length === 1 ? plotW / 2 : plotW * index / (values.length - 1));
        const y = pad.top + plotH - ((Number(point.value) || 0) / max) * plotH;
        if (index === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    });
    ctx.stroke();
    values.forEach((point, index) => {
        const x = pad.left + (values.length === 1 ? plotW / 2 : plotW * index / (values.length - 1));
        const y = pad.top + plotH - ((Number(point.value) || 0) / max) * plotH;
        ctx.fillStyle = '#7dd3fc'; ctx.beginPath(); ctx.arc(x, y, 2.5, 0, Math.PI * 2); ctx.fill();
    });
    ctx.fillStyle = '#94a3b8'; ctx.fillText(String(values[0].label || ''), pad.left, height - 3);
    const last = values[values.length - 1];
    const label = String(last.label || '') + ' · ' + Number(last.value || 0).toFixed(suffix === ' ms' ? 2 : 0) + suffix;
    ctx.textAlign = 'right'; ctx.fillText(label, width - pad.right, height - 3); ctx.textAlign = 'left';
}
function pushFrameSample(value) {
    if (!Number.isFinite(value)) return;
    frameSamples.push({ label: new Date().toLocaleTimeString('fr-FR', {hour:'2-digit', minute:'2-digit', second:'2-digit'}), value });
    if (frameSamples.length > 30) frameSamples.shift();
    drawLineChart('diag-frame-chart', frameSamples, ' ms', 'En attente de mesures…');
}
function renderServerDiagnostics(stats) {
    const registered = document.getElementById('diag-registered');
    if (registered) registered.textContent = stats.registered == null ? 'Indisponible' : Number(stats.registered).toLocaleString('fr-FR');
    const online = document.getElementById('diag-players');
    if (online && Number.isFinite(Number(stats.online))) online.textContent = Number(stats.online) + ' en ligne';
    const updated = document.getElementById('diag-updated');
    if (updated) updated.textContent = 'Mis à jour ' + new Date().toLocaleTimeString('fr-FR', {hour:'2-digit', minute:'2-digit'});
    const history = Array.isArray(stats.registrationHistory) ? stats.registrationHistory.slice().reverse() : [];
    registrationSamples.splice(0, registrationSamples.length, ...history.map(row => ({ label: String(row.day || '').slice(5), value: Number(row.total) || 0 })));
    drawLineChart('diag-registration-chart', registrationSamples, '', 'Aucune inscription sur la période');
    const host = document.getElementById('diag-jobs-chart');
    if (!host) return;
    host.replaceChildren();
    const jobs = Array.isArray(stats.jobs) ? stats.jobs : [];
    if (!jobs.length) {
        const empty = document.createElement('span'); empty.className = 'diagnostic-empty'; empty.textContent = 'Aucun joueur avec un métier chargé'; host.appendChild(empty); return;
    }
    const maxCount = Math.max(1, ...jobs.map(job => Number(job.count) || 0));
    jobs.forEach(job => {
        const row = document.createElement('div'); row.className = 'diagnostic-job-row';
        const meta = document.createElement('div'); meta.className = 'diagnostic-job-meta';
        const name = document.createElement('span'); name.textContent = String(job.label || job.name || 'Inconnu');
        const count = document.createElement('b'); count.textContent = String(Number(job.count) || 0);
        const track = document.createElement('div'); track.className = 'diagnostic-job-track';
        const fill = document.createElement('span'); fill.style.width = ((Number(job.count) || 0) / maxCount * 100) + '%';
        meta.append(name, count); track.appendChild(fill); row.append(meta, track); host.appendChild(row);
    });
}
document.getElementById('open-resource-monitor')?.addEventListener('click', () => {
    fetch('https://' + (window.GetParentResourceName ? GetParentResourceName() : 'rp_ui') + '/openResourceMonitor', {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}'
    }).catch(() => {});
});


// F12 navigation: keep the dashboard compact while preserving live metric updates.
function activateDiagnosticsTab(tab) {
    const allowed = ['overview', 'performance', 'community'];
    const active = allowed.includes(tab) ? tab : 'overview';
    document.querySelectorAll('[data-diagnostics-tab]').forEach(button => {
        const selected = button.dataset.diagnosticsTab === active;
        button.classList.toggle('active', selected);
        if (selected) button.setAttribute('aria-current', 'page');
        else button.removeAttribute('aria-current');
    });
    document.querySelectorAll('[data-diagnostics-panel]').forEach(panel => {
        const selected = panel.dataset.diagnosticsPanel === active;
        panel.hidden = !selected;
        panel.classList.toggle('active', selected);
    });
    // Canvases inside a hidden tab have zero width; redraw after it becomes visible.
    requestAnimationFrame(() => {
        drawLineChart('diag-fps-chart', fpsSamples, '', 'En attente de FPS…');
        drawLineChart('diag-ping-chart', pingSamples, ' ms', 'En attente de ping…');
        drawLineChart('diag-frame-chart', frameSamples, ' ms', 'En attente de mesures…');
        drawLineChart('diag-registration-chart', registrationSamples, '', 'Aucune inscription sur la période');
    });
}
document.querySelectorAll('[data-diagnostics-tab]').forEach(button => {
    button.addEventListener('click', () => activateDiagnosticsTab(button.dataset.diagnosticsTab));
});
