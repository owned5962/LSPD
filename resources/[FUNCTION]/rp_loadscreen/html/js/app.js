const progressBar = document.getElementById('progress-bar');
const progressTrack = document.getElementById('progress-track');
const progressText = document.getElementById('load-percentage');
const statusText = document.getElementById('load-status');
const detailText = document.getElementById('load-detail');
const phaseSteps = Array.from(document.querySelectorAll('[data-phase]'));

const STAGES = {
    map: { label: 'Chargement de la carte', color: '#46b9ff', glow: 'rgba(70,185,255,.46)', detail: 'Préparation du monde de Los Santos...' },
    modules: { label: 'Chargement des modules', color: '#9b8cff', glow: 'rgba(155,140,255,.46)', detail: 'Démarrage des systèmes et interfaces...' },
    anticheat: { label: 'Chargement de l’anticheat', color: '#ff747e', glow: 'rgba(255,116,126,.46)', detail: 'Initialisation des protections du serveur...' },
    jobs: { label: 'Chargement des métiers', color: '#42d3a0', glow: 'rgba(66,211,160,.46)', detail: 'Synchronisation des ressources métiers...' },
    missions: { label: 'Chargement des missions', color: '#f5b85f', glow: 'rgba(245,184,95,.46)', detail: 'Initialisation des activités et missions...' },
    player: { label: 'Chargement du joueur', color: '#e58bff', glow: 'rgba(229,139,255,.46)', detail: 'Récupération du compte et des personnages...' }
};

let lastProgress = 0;
let activeStage = 'map';
let missionStageSeen = false;

function updateProgress(value) {
    if (!Number.isFinite(value)) return;
    const percent = Math.max(lastProgress, Math.min(100, Math.round(value)));
    lastProgress = percent;
    if (progressBar) progressBar.style.width = percent + '%';
    if (progressText) progressText.textContent = percent + '%';
}

function setStage(stage, detail, jobCount) {
    const meta = STAGES[stage];
    if (!meta) return;

    activeStage = stage;
    if (stage === 'missions') missionStageSeen = true;
    document.documentElement.style.setProperty('--stage-color', meta.color);
    document.documentElement.style.setProperty('--stage-glow', meta.glow);
    if (progressTrack) progressTrack.dataset.stage = stage;
    if (statusText) statusText.textContent = meta.label;
    if (detailText) {
        const safeDetail = typeof detail === 'string' ? detail.slice(0, 140) : '';
        detailText.textContent = safeDetail || meta.detail;
        if (stage === 'jobs' && Number.isFinite(jobCount)) {
            detailText.textContent = 'Ressources métiers démarrées : ' + Math.max(0, Math.min(50, jobCount)) + '/50';
        }
    }

    const stageOrder = ['map', 'modules', 'anticheat', 'jobs', 'missions', 'player'];
    const activeIndex = stageOrder.indexOf(stage);
    phaseSteps.forEach((step) => {
        const index = stageOrder.indexOf(step.dataset.phase);
        step.classList.toggle('is-current', step.dataset.phase === stage);
        const missionPending = step.dataset.phase === 'missions' && !missionStageSeen;
        step.classList.toggle('is-done', index !== -1 && index < activeIndex && !missionPending);
        step.classList.toggle('is-planned', missionPending);
    });
}

function handleLoadMessage(data) {
    if (!data || typeof data !== 'object') return;

    if (data.eventName === 'loadProgress') {
        const fraction = Number(data.loadFraction);
        if (Number.isFinite(fraction)) updateProgress(Math.max(0, Math.min(1, fraction)) * 100);
        return;
    }

    if (data.eventName === 'lssStage' && typeof data.stage === 'string') {
        setStage(data.stage, data.status, Number.isFinite(Number(data.jobCount)) ? Number(data.jobCount) : undefined);
        return;
    }

    if (data.eventName === 'startDataFileEntries' || data.eventName === 'onDataFileEntry' ||
        data.eventName === 'performMapLoadFunction' || data.eventName === 'endDataFileEntries') {
        setStage('map', 'Chargement des fichiers et des données de la carte...');
        return;
    }

    if (data.eventName === 'startInitFunction' || data.eventName === 'startInitFunctionOrder' ||
        data.eventName === 'initFunctionInvoking' || data.eventName === 'initFunctionInvoked' ||
        data.eventName === 'endInitFunction') {
        if (activeStage === 'map') setStage('modules', 'Initialisation des composants du jeu...');
        return;
    }

    if (data.eventName === 'onLogLine' && typeof data.message === 'string' && detailText) {
        detailText.textContent = data.message.trim().slice(0, 140);
    }
}

window.addEventListener('message', (event) => handleLoadMessage(event.data));

// Browser-only preview: this is a design preview, not FiveM loading telemetry.
if (!('invokeNative' in window)) {
    const demoStages = ['map', 'modules', 'anticheat', 'jobs', 'player'];
    let demoIndex = 0;
    let demoProgress = 0;
    setStage('map', 'Aperçu visuel du loadscreen — aucune connexion FiveM active.');
    const demoTimer = window.setInterval(() => {
        demoProgress = Math.min(100, demoProgress + 2);
        updateProgress(demoProgress);
        if (demoProgress >= (demoIndex + 1) * 20 && demoIndex < demoStages.length - 1) {
            demoIndex += 1;
            setStage(demoStages[demoIndex], 'Aperçu visuel uniquement — les vraies étapes viennent de FiveM.');
        }
        if (demoProgress >= 100) window.clearInterval(demoTimer);
    }, 180);
}
