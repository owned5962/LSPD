let isMuted = false;
const audio = document.getElementById('bg-music');
const toggleBtn = document.getElementById('toggle-audio-btn');
const audioIcon = document.getElementById('audio-icon');

if (audio) {
    audio.volume = 0.25;
    const playPromise = audio.play();
    if (playPromise !== undefined) {
        playPromise.catch(() => {
            // Autoplay policy prevented playback, user can manually toggle
        });
    }
}

if (toggleBtn) {
    toggleBtn.addEventListener('click', () => {
        if (!audio) return;
        if (isMuted) {
            audio.play();
            audioIcon.className = "fas fa-volume-up";
            isMuted = false;
        } else {
            audio.pause();
            audioIcon.className = "fas fa-volume-mute";
            isMuted = true;
        }
    });
}

// FiveM Handlers for Game Loading Events
const progressBar = document.getElementById('progress-bar');
const progressText = document.getElementById('load-percentage');
const statusText = document.getElementById('load-status');

let currentCount = 0;
let totalCount = 100;

window.addEventListener('message', (e) => {
    const data = e.data;
    if (data.eventName === 'loadProgress') {
        const percent = Math.floor(data.loadFraction * 100);
        if (progressBar) progressBar.style.width = `${percent}%`;
        if (progressText) progressText.innerText = `${percent}%`;
    } else if (data.eventName === 'onLogLine') {
        if (statusText) statusText.innerText = data.message || "Chargement des données du jeu...";
    } else if (data.eventName === 'initFunctionInvoking') {
        if (statusText) statusText.innerText = `Initialisation: ${data.name || ''}...`;
    }
});

// Fallback simulated progress if testing outside FiveM game client
if (!window.invokeNative) {
    let mockPercent = 20;
    const interval = setInterval(() => {
        mockPercent += 10;
        if (mockPercent > 100) {
            clearInterval(interval);
            return;
        }
        if (progressBar) progressBar.style.width = `${mockPercent}%`;
        if (progressText) progressText.innerText = `${mockPercent}%`;
    }, 600);
}
