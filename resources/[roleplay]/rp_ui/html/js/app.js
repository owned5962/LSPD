let progressInterval = null;

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'showTextUI') {
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
