let allJobs = [];
let currentCategory = 'all';
let currentSearch = '';

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openJobCenter') {
        allJobs = data.jobs || [];
        document.getElementById('jobs-count').innerText = allJobs.length;
        document.getElementById('jobcenter-app').classList.remove('hidden');
        renderJobs();
    } else if (data.action === 'closeJobCenter') {
        document.getElementById('jobcenter-app').classList.add('hidden');
    }
});

function renderJobs() {
    const container = document.getElementById('jobs-container');
    container.innerHTML = '';

    const filtered = allJobs.filter(job => {
        const matchesCategory = (currentCategory === 'all' || job.category === currentCategory);
        const matchesSearch = job.label.toLowerCase().includes(currentSearch.toLowerCase()) || 
                              job.description.toLowerCase().includes(currentSearch.toLowerCase());
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
        if (!isWhitelisted) {
            actionBtn.addEventListener('click', () => {
                chooseJob(job.name);
            });
        }

        container.appendChild(card);
    });
}

function chooseJob(jobName) {
    fetch(`https://${GetParentResourceName()}/selectJob`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jobName })
    }).catch(() => {});
    document.getElementById('jobcenter-app').classList.add('hidden');
}

function closeJobCenter() {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});
    document.getElementById('jobcenter-app').classList.add('hidden');
}

document.getElementById('close-jobcenter').addEventListener('click', closeJobCenter);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeJobCenter();
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

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'rp_jobs';
}
