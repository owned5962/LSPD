let progressInterval = null;

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'updateHUD') {
        updatePlayerHUD(data);
    } else if (data.action === 'hideHUD') {
        document.getElementById('player-hud')?.classList.add('hidden');
    } else if (data.action === 'showTextUI') {
        document.getElementById('textui-text').innerHTML = data.text;
        document.getElementById('textui-container').classList.remove('hidden');
    } else if (data.action === 'hideTextUI') {
        document.getElementById('textui-container').classList.add('hidden');
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
    const money = value => new Intl.NumberFormat('fr-FR').format(Number(value) || 0) + ' $';
    setText('hud-job', data.job || 'Sans-emploi');
    setText('hud-grade', data.grade || '');
    setText('hud-cash', money(data.cash));
    setText('hud-bank', money(data.bank));
    ['health', 'armor', 'hunger', 'thirst'].forEach(key => {
        const value = Math.max(0, Math.min(100, Number(data[key]) || 0));
        setText('hud-' + key, Math.round(value) + '%');
        setBar('hud-' + key + '-bar', value);
    });
    hud.classList.toggle('hidden', data.visible !== true);
}
