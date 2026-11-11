let allJobs = [];
let currentCategory = 'all';
let currentSearch = '';
let jobStats = {};

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, char => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[char]));
}

function jobEmoji(job) {
    const key = String(job.name || '').toLowerCase();
    const label = String(job.label || '').toLowerCase();
    const source = key + ' ' + label;
    const visuals = [
        [/police|security|ranger|judge|lawyer|guard/, '🚓'],
        [/ambulance|doctor|medic|pharmac|veterin/, '🩺'],
        [/fire|pompi/, '🚒'],
        [/mechanic|towtruck|electrician|plumber|welder/, '🛠️'],
        [/taxi|bus|driver|delivery|postman|courier|boat|diver|dock/, '🚚'],
        [/realestate|architect|construction/, '🏙️'],
        [/journal|photograph|media/, '📸'],
        [/miner|lumber|farmer|fisher|butcher|winemaker|florist/, '🌿'],
        [/bank|account|financ/, '💳'],
        [/garbage|cleaner|recycl/, '♻️'],
        [/casino|dealer/, '🎲'],
        [/event|dj|cinema|music|artist/, '🎬'],
        [/it_|tech|cyber|program/, '💻'],
        [/armorer|weapon/, '🎯'],
        [/tailor|fashion/, '🧵'],
        [/fitness|coach|sport/, '🏋️'],
        [/smuggler|illegal|underground/, '🕶️']
    ];
    const match = visuals.find(([pattern]) => pattern.test(source));
    if (match) return match[1];
    const category = String(job.category || '');
    return ({ transport: '🚘', artisanat: '🔧', industrie: '🏗️', commerce: '🏬', public_service: '🏛️', divertissement: '🎭', justice: '⚖️', sante: '🩺', technologie: '💻' })[category] || '💼';
}

function jobIllustration(job) {
    const emoji = jobEmoji(job);
    const label = escapeHtml(job.label || job.name || 'Métier').slice(0, 34);
    let hash = 0;
    for (const char of String(job.name || label)) hash = (hash * 31 + char.charCodeAt(0)) >>> 0;
    const hue = hash % 360;
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 180">
      <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="hsl(${hue},68%,24%)"/><stop offset="1" stop-color="hsl(${(hue+48)%360},78%,11%)"/></linearGradient></defs>
      <rect width="640" height="180" fill="url(#g)"/>
      <circle cx="520" cy="30" r="130" fill="white" opacity=".06"/><circle cx="570" cy="160" r="95" fill="white" opacity=".05"/>
      <path d="M0 150 L90 105 160 145 240 90 330 150 410 112 500 160 640 100 V180 H0Z" fill="white" opacity=".07"/>
      <text x="36" y="106" font-size="78" font-family="Arial,sans-serif">${emoji}</text>
      <text x="160" y="83" fill="white" font-size="25" font-weight="700" font-family="Arial,sans-serif">${label.replace(/&/g,'&amp;')}</text>
      <text x="162" y="112" fill="white" opacity=".62" font-size="12" letter-spacing="3" font-family="Arial,sans-serif">LOS SANTOS · CARRIÈRES</text>
    </svg>`;
    return 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg);
}

function showView(view) {
    document.querySelectorAll('.view-tab').forEach(button => button.classList.toggle('active', button.dataset.view === view));
    document.querySelectorAll('.view-panel').forEach(panel => panel.classList.toggle('active', panel.id === (view === 'statistics' ? 'statistics-view' : 'jobs-view')));
    if (view === 'statistics') renderJobStats();
}

function renderJobStats() {
    const container = document.getElementById('job-stats-list');
    const rows = allJobs.map(job => ({ job, count: Math.max(0, Number(jobStats[job.name]) || 0) }))
        .sort((a, b) => b.count - a.count || String(a.job.label).localeCompare(String(b.job.label), 'fr'));
    const total = rows.reduce((sum, row) => sum + row.count, 0);
    const leader = rows[0] && rows[0].count > 0 ? rows[0] : null;
    document.getElementById('stats-total').textContent = total.toLocaleString('fr-FR');
    document.getElementById('stats-leader').textContent = leader ? leader.job.label : 'Pas encore de choix';
    container.replaceChildren();
    if (!leader) {
        const empty = document.createElement('p');
        empty.className = 'stats-empty';
        empty.textContent = 'Aucune embauche enregistrée pour le moment. Le classement apparaîtra dès les premières embauches.';
        container.appendChild(empty);
        return;
    }
    const max = leader.count;
    rows.filter(row => row.count > 0).slice(0, 10).forEach((row, index) => {
        const item = document.createElement('article');
        item.className = 'job-stat-row';
        const heading = document.createElement('div');
        heading.className = 'job-stat-heading';
        const name = document.createElement('strong');
        name.textContent = `${index + 1}. ${row.job.label}`;
        const count = document.createElement('span');
        count.textContent = `${row.count} ${row.count > 1 ? 'choix' : 'choix'}`;
        heading.append(name, count);
        const track = document.createElement('div');
        track.className = 'job-stat-track';
        const fill = document.createElement('span');
        fill.style.width = `${Math.max(2, (row.count / max) * 100)}%`;
        track.appendChild(fill);
        item.append(heading, track);
        container.appendChild(item);
    });
}

document.querySelectorAll('.view-tab').forEach(button => button.addEventListener('click', () => showView(button.dataset.view)));
document.getElementById('refresh-stats').addEventListener('click', () => {
    document.getElementById('stats-note').textContent = 'Actualisation des statistiques…';
    fetch(`https://${NUI_RESOURCE}/requestStats`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
        .catch(() => { document.getElementById('stats-note').textContent = 'Impossible de contacter le serveur.'; });
});
const NUI_RESOURCE = 'rp_jobs';

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openJobCenter') {
        allJobs = data.jobs || [];
        jobStats = {};
        document.getElementById('jobs-count').innerText = allJobs.length;
        showView('jobs');
        document.getElementById('jobcenter-app').classList.remove('hidden');
        renderJobs();
    } else if (data.action === 'jobStats') {
        jobStats = data.stats || {};
        renderJobStats();
        const note = document.getElementById('stats-note');
        if (note) note.textContent = 'Statistiques actualisées à partir des embauches validées.';
    } else if (data.action === 'jobSelectionResult') {
        clearTimeout(pendingJobTimeout);
        activeJobRequest = false;
        const status = document.getElementById('job-status');
        if (status) status.textContent = data.message || (data.success ? 'Embauche confirmée.' : 'Candidature refusée.');
        document.querySelectorAll('.select-job-btn:not(.disabled)').forEach(button => {
            button.disabled = false;
            if (button.dataset.originalLabel) button.textContent = button.dataset.originalLabel;
        });
        if (data.success) closeJobCenter();
    } else if (data.action === 'closeJobCenter') {
        document.getElementById('jobcenter-app').classList.add('hidden');
    }
});

function renderJobs() {
    const container = document.getElementById('jobs-container');
    container.innerHTML = '';

    const filtered = allJobs.filter(job => {
        const matchesCategory = (currentCategory === 'all' || job.category === currentCategory);
        const matchesSearch = String(job.label || job.name || '').toLowerCase().includes(currentSearch.toLowerCase()) ||
                              String(job.description || '').toLowerCase().includes(currentSearch.toLowerCase());
        return matchesCategory && matchesSearch;
    });

    if (filtered.length === 0) {
        container.innerHTML = '<div style="grid-column: 1/-1; text-align: center; color: #94a3b8; padding: 40px;">Aucun métier trouvé correspondant à vos critères.</div>';
        return;
    }

    filtered.forEach(job => {
        const card = document.createElement('div');
        card.className = 'job-card';

        const startingSalary = job.grades && job.grades[0] ? job.grades[0].salary : 200;
        const isWhitelisted = job.whitelisted;

        card.innerHTML = `
            <div>
                <div class="job-card-top">
                    <img class="job-image" src="${jobIllustration(job)}" alt="Illustration : ${escapeHtml(job.label || job.name)}" loading="lazy">
                    <div class="job-title-wrap">
                        <h3>${escapeHtml(job.label)}</h3>
                        <span class="job-tag ${isWhitelisted ? 'tag-whitelisted' : 'tag-free'}">
                            ${isWhitelisted ? 'Candidature Requise' : 'Libre Accès'}
                        </span>
                    </div>
                </div>
                <p class="job-desc">${escapeHtml(job.description)}</p>
            </div>
            <div class="job-card-bottom">
                <span class="salary-tag">Salaire: dès ${startingSalary} $</span>
                <button class="select-job-btn ${isWhitelisted ? 'disabled' : ''}" data-name="${escapeHtml(job.name)}">
                    ${isWhitelisted ? 'Sur Concours' : 'Postuler Immédiatement'}
                </button>
            </div>
        `;

        const actionBtn = card.querySelector('.select-job-btn');
        if (isWhitelisted) actionBtn.disabled = true;
        if (!isWhitelisted) {
            actionBtn.addEventListener('click', () => {
                chooseJob(job.name, actionBtn);
            });
        }

        container.appendChild(card);
    });
}

let pendingJobTimeout = null;
let activeJobRequest = false;

function chooseJob(jobName, button) {
    // Ignore duplicate/re-entrant clicks while a single server response is pending.
    if (activeJobRequest) return;
    if (!button || button.disabled || typeof jobName !== 'string' || !jobName) return;
    activeJobRequest = true;
    button.dataset.originalLabel = button.textContent;
    button.disabled = true;
    button.textContent = 'Envoi en cours…';
    const status = document.getElementById('job-status');
    if (status) status.textContent = 'Transmission de votre demande au serveur…';
    clearTimeout(pendingJobTimeout);
    pendingJobTimeout = setTimeout(() => {
        if (button.disabled) {
            activeJobRequest = false;
            button.disabled = false;
            button.textContent = button.dataset.originalLabel || 'Postuler Immédiatement';
            if (status) status.textContent = 'Le serveur ne répond pas. Vérifiez la console serveur et réessayez.';
        }
    }, 10000);
    fetch(`https://${NUI_RESOURCE}/selectJob`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jobName })
    }).then(response => response.json()).then(result => {
        if (!result || result.status !== 'submitted') throw new Error('Demande non transmise');
    }).catch(() => {
        activeJobRequest = false;
        clearTimeout(pendingJobTimeout);
        button.disabled = false;
        button.textContent = button.dataset.originalLabel || 'Postuler Immédiatement';
        if (status) status.textContent = 'Erreur de communication avec le serveur. Réessayez.';
    });
}

function closeJobCenter() {
    fetch(`https://${NUI_RESOURCE}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});
    document.getElementById('jobcenter-app').classList.add('hidden');
}

document.getElementById('close-jobcenter').addEventListener('click', closeJobCenter);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        e.preventDefault();
        closeJobCenter();
    }
});

document.getElementById('job-search').addEventListener('input', (e) => {
    currentSearch = e.target.value;
    renderJobs();
});

document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        currentCategory = btn.getAttribute('data-cat');
        renderJobs();
    });
});
