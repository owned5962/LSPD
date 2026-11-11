const progressBar = document.getElementById('progress-bar');
const progressTrack = document.getElementById('progress-track');
const progressText = document.getElementById('load-percentage');
const statusText = document.getElementById('load-status');
const detailText = document.getElementById('load-detail');
const phaseSteps = Array.from(document.querySelectorAll('[data-phase]'));
const updatesList = document.getElementById('updates-list');
const updatesRefresh = document.getElementById('updates-refresh');
const futureList = document.getElementById('future-list');

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
        const missionPending = step.dataset.phase === 'missions' && !missionStageSeen;
        step.classList.toggle('is-current', step.dataset.phase === stage);
        step.classList.toggle('is-done', index !== -1 && index < activeIndex && !missionPending);
        step.classList.toggle('is-planned', missionPending);
    });
}

function renderUpdates(data) {
    if (!updatesList) return;
    const updates = Array.isArray(data.updates) ? data.updates.slice(0, 6) : [];
    updatesList.replaceChildren();

    if (updates.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'update-placeholder';
        empty.textContent = 'Aucune nouveauté disponible pour le moment.';
        updatesList.appendChild(empty);
    } else {
        updates.forEach((update) => {
            const row = document.createElement('div');
            row.className = 'update-row';
            const main = document.createElement('div');
            main.className = 'update-main';
            const title = document.createElement('div');
            title.className = 'update-title';
            title.textContent = String(typeof update === 'string' ? update : (update.title || 'Mise à jour du serveur')).slice(0, 100);
            const meta = document.createElement('div');
            meta.className = 'update-meta';
            meta.textContent = String(typeof update === 'string' ? 'Nouveauté récente' : (update.date || 'Date indisponible'));
            main.append(title, meta);
            const badge = document.createElement('span');
            badge.className = 'update-badge';
            badge.textContent = String(typeof update === 'string' ? '' : (update.sha || '')).slice(0, 7);
            row.append(main, badge);
            updatesList.appendChild(row);
        });
    }

    if (futureList) {
        const future = Array.isArray(data.future) ? data.future.slice(0, 10) : [];
        futureList.replaceChildren();
        if (future.length === 0) {
            const empty = document.createElement('li');
            empty.textContent = 'Aucune annonce pour le moment.';
            futureList.appendChild(empty);
        } else {
            future.forEach((item) => {
                const entry = document.createElement('li');
                entry.textContent = String(item).slice(0, 140);
                futureList.appendChild(entry);
            });
        }
    }

    if (updatesRefresh) {
        updatesRefresh.textContent = data.source === 'files'
            ? 'Dernière synchronisation : ' + (data.fetchedAt || 'à l’instant') + ' • Fichiers du projet'
            : 'Fichiers de nouveautés indisponibles • Réessayez à la prochaine connexion';
    }
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

    if (data.eventName === 'lssUpdates') {
        renderUpdates(data);
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

// Browser-only preview: no fake GitHub entries or fake FiveM telemetry.
if (!('invokeNative' in window)) {
    setStage('map', 'Aperçu visuel — les vraies données arrivent depuis FiveM.');
    renderUpdates({ updates: [], source: 'preview' });
}
