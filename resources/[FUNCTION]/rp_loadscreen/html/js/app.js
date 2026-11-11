let isMuted = false;
const audio = document.getElementById('bg-music');
const toggleBtn = document.getElementById('toggle-audio-btn');
const audioIcon = document.getElementById('audio-icon');
const trackState = document.getElementById('track-state');

if (audio) {
    audio.volume = 0.2;
    const playPromise = audio.play();
    if (playPromise && typeof playPromise.catch === 'function') {
        playPromise.catch(() => {
            if (trackState) trackState.textContent = 'Cliquez pour activer la musique';
        });
    }
}

if (toggleBtn) {
    toggleBtn.addEventListener('click', async () => {
        if (!audio) return;
        if (isMuted) {
            try {
                await audio.play();
                audioIcon.className = 'fas fa-volume-up';
                if (trackState) trackState.textContent = 'Musique activée';
                isMuted = false;
            } catch (_) {
                if (trackState) trackState.textContent = 'Lecture indisponible';
            }
        } else {
            audio.pause();
            audioIcon.className = 'fas fa-volume-mute';
            if (trackState) trackState.textContent = 'Musique coupée';
            isMuted = true;
        }
    });
}

const progressBar = document.getElementById('progress-bar');
const progressText = document.getElementById('load-percentage');
const statusText = document.getElementById('load-status');
let lastProgress = 0;

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.eventName === 'loadProgress') {
        const fraction = Number(data.loadFraction);
        if (!Number.isFinite(fraction)) return;
        const percent = Math.max(lastProgress, Math.min(100, Math.round(fraction * 100)));
        lastProgress = percent;
        if (progressBar) progressBar.style.width = percent + '%';
        if (progressText) progressText.textContent = percent + '%';
        if (statusText && percent >= 100) statusText.textContent = 'Chargement terminé — préparation de votre arrivée...';
    } else if (data.eventName === 'onLogLine') {
        if (statusText && typeof data.message === 'string' && data.message.trim()) {
            statusText.textContent = data.message;
        }
    } else if (data.eventName === 'initFunctionInvoking') {
        if (statusText) statusText.textContent = 'Initialisation : ' + (data.name || 'des ressources') + '...';
    }
});

// Preview progression only when opened in a normal browser, never in FiveM.
if (!('invokeNative' in window)) {
    let preview = 0;
    const previewTimer = window.setInterval(() => {
        preview = Math.min(100, preview + 4);
        if (progressBar) progressBar.style.width = preview + '%';
        if (progressText) progressText.textContent = preview + '%';
        if (statusText) statusText.textContent = preview === 100 ? 'Aperçu du chargement terminé' : 'Aperçu du chargement du serveur...';
        if (preview >= 100) window.clearInterval(previewTimer);
    }, 350);
}
