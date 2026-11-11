let progressInterval = null;

window.addEventListener('message', function(event) {
    const data = event.data;
    if (!data || typeof data !== 'object') return;

    if (data.action === 'showTextUI') {
        document.getElementById('textui-text').textContent = String(data.text || '');
        document.getElementById('textui-container').classList.remove('hidden');
    } else if (data.action === 'hideTextUI') {
        document.getElementById('textui-container').classList.add('hidden');
    } else if (data.action === 'startProgress') {
        startProgress(data.duration, data.label, data.canCancel);
    } else if (data.action === 'cancelProgress') {
        cancelProgress();
    } else if (data.action === 'setHudVisible') {
        document.getElementById('player-hud').classList.toggle('hidden', data.visible !== true);
        if (data.visible !== true) {
            document.getElementById('vehicle-speedometer').classList.add('hidden');
        }
    } else if (data.action === 'updateHud') {
        updateHud(data);
    }
});

function startProgress(duration, label, canCancel) {
    clearInterval(progressInterval);
    const safeDuration = Math.max(1, Number(duration) || 5000);
    const container = document.getElementById('progress-container');
    const labelEl = document.getElementById('progress-label');
    const fillEl = document.getElementById('progress-fill');
    const percentEl = document.getElementById('progress-percentage');

    labelEl.textContent = String(label || 'Action...');
    fillEl.style.width = '0%';
    percentEl.textContent = '0%';
    container.classList.remove('hidden');

    const startTime = Date.now();
    progressInterval = setInterval(() => {
        const elapsed = Date.now() - startTime;
        const progress = Math.min(100, (elapsed / safeDuration) * 100);
        fillEl.style.width = progress + '%';
        percentEl.textContent = Math.floor(progress) + '%';

        if (progress >= 100) {
            clearInterval(progressInterval);
            progressInterval = null;
            setTimeout(() => container.classList.add('hidden'), 250);
        }
    }, 50);
}

function cancelProgress() {
    clearInterval(progressInterval);
    progressInterval = null;
    document.getElementById('progress-container').classList.add('hidden');
}

function clampPercent(value) {
    const number = Number(value);
    return Number.isFinite(number) ? Math.max(0, Math.min(100, number)) : 0;
}

function updateHud(data) {
    const health = clampPercent(data.health);
    const armour = clampPercent(data.armour);
    document.getElementById('hud-health-fill').style.width = health + '%';
    document.getElementById('hud-armour-fill').style.width = armour + '%';
    document.getElementById('hud-health-value').textContent = String(Math.round(health));
    document.getElementById('hud-armour-value').textContent = String(Math.round(armour));

    const speedometer = document.getElementById('vehicle-speedometer');
    if (data.inVehicle === true) {
        const speed = Math.max(0, Math.round(Number(data.speed) || 0));
        const fuel = clampPercent(data.fuel);
        document.getElementById('vehicle-speed').textContent = String(speed);
        document.getElementById('vehicle-fuel-fill').style.width = fuel + '%';
        document.getElementById('vehicle-fuel-value').textContent = Math.round(fuel) + '%';
        speedometer.classList.remove('hidden');
    } else {
        speedometer.classList.add('hidden');
    }
}
