let allJobs = [];
let currentCategory = 'all';
let currentSearch = '';
const NUI_RESOURCE = 'rp_jobs';

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openJobCenter') {
        allJobs = data.jobs || [];
        document.getElementById('jobs-count').innerText = allJobs.length;
        document.getElementById('jobcenter-app').classList.remove('hidden');
        renderJobs();
    } else if (data.action === 'jobSelectionResult') {
        clearTimeout(pendingJobTimeout);
        const status = document.getElementById('job-status');
        if (status) status.textContent = data.message || (data.success ? 'Embauche confirmée.' : 'Candidature refusée.');
        document.querySelectorAll('.select-job-btn:not(.disabled)').forEach(button => {
            button.disabled = false;
            if (button.dataset.originalLabel) button.textContent = button.dataset.originalLabel;
        });
        if (data.success) document.getElementById('jobcenter-app').classList.add('hidden');
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
                    <div class="job-icon">
                        <i class="${job.icon || 'fas fa-briefcase'}"></i>
                    </div>
                    <div class="job-title-wrap">
                        <h3>${job.label}</h3>
                        <span class="job-tag ${isWhitelisted ? 'tag-whitelisted' : 'tag-free'}">
                            ${isWhitelisted ? 'Candidature Requise' : 'Libre Accès'}
                        </span>
                    </div>
                </div>
                <p class="job-desc">${job.description}</p>
            </div>
            <div class="job-card-bottom">
                <span class="salary-tag">Salaire: dès ${startingSalary} $</span>
                <button class="select-job-btn ${isWhitelisted ? 'disabled' : ''}" data-name="${job.name}">
                    ${isWhitelisted ? 'Sur Concours' : 'Postuler Immédiatement'}
                </button>
            </div>
        `;

        const actionBtn = card.querySelector('.select-job-btn');
        if (isWhitelisted) actionBtn.disabled = true;
        if (!isWhitelisted) {
            actionBtn.addEventListener('click', () => {
                chooseJob(job.name);
            });
        }

        container.appendChild(card);
    });
}

let pendingJobTimeout = null;

function chooseJob(jobName) {
    const button = Array.from(document.querySelectorAll('.select-job-btn')).find(item => item.dataset.name === jobName);
    if (!button || button.disabled) return;
    button.dataset.originalLabel = button.textContent;
    button.disabled = true;
    button.textContent = 'Envoi en cours…';
    const status = document.getElementById('job-status');
    if (status) status.textContent = 'Transmission de votre demande au serveur…';
    clearTimeout(pendingJobTimeout);
    pendingJobTimeout = setTimeout(() => {
        if (button.disabled) {
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
