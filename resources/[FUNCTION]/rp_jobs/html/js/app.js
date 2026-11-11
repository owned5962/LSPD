let allJobs = [];
let currentCategory = 'all';
let currentSearch = '';

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data !== 'object') return;
    if (data.action === 'openJobCenter') {
        allJobs = Array.isArray(data.jobs) ? data.jobs : [];
        document.getElementById('jobs-count').textContent = String(allJobs.length);
        document.getElementById('jobcenter-app').classList.remove('hidden');
        renderJobs();
    } else if (data.action === 'closeJobCenter') {
        document.getElementById('jobcenter-app').classList.add('hidden');
    }
});

function renderJobs() {
    const container = document.getElementById('jobs-container');
    container.replaceChildren();

    const filtered = allJobs.filter(job => {
        if (!job || typeof job !== 'object') return false;
        const label = typeof job.label === 'string' ? job.label : '';
        const description = typeof job.description === 'string' ? job.description : '';
        const matchesCategory = currentCategory === 'all' || job.category === currentCategory;
        const matchesSearch = (label + ' ' + description).toLowerCase().includes(currentSearch.toLowerCase());
        return matchesCategory && matchesSearch;
    });

    if (filtered.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'empty-state';
        empty.textContent = 'Aucun métier trouvé correspondant à vos critères.';
        container.appendChild(empty);
        return;
    }

    filtered.forEach(job => {
        const card = document.createElement('article');
        card.className = 'job-card';

        const top = document.createElement('div');
        const cardTop = document.createElement('div');
        cardTop.className = 'job-card-top';
        const iconWrap = document.createElement('div');
        iconWrap.className = 'job-icon';
        const icon = document.createElement('i');
        icon.className = typeof job.icon === 'string' && /^[a-z0-9 -]+$/i.test(job.icon)
            ? job.icon : 'fas fa-briefcase';
        icon.setAttribute('aria-hidden', 'true');
        iconWrap.appendChild(icon);

        const titleWrap = document.createElement('div');
        titleWrap.className = 'job-title-wrap';
        const title = document.createElement('h3');
        title.textContent = typeof job.label === 'string' ? job.label : 'Métier sans nom';
        const tag = document.createElement('span');
        const isWhitelisted = job.whitelisted === true;
        tag.className = 'job-tag ' + (isWhitelisted ? 'tag-whitelisted' : 'tag-free');
        tag.textContent = isWhitelisted ? 'Candidature requise' : 'Libre accès';
        titleWrap.append(title, tag);
        cardTop.append(iconWrap, titleWrap);

        const description = document.createElement('p');
        description.className = 'job-desc';
        description.textContent = typeof job.description === 'string' ? job.description : '';
        top.append(cardTop, description);

        const bottom = document.createElement('div');
        bottom.className = 'job-card-bottom';
        const salary = document.createElement('span');
        salary.className = 'salary-tag';
        const startingSalary = Number.isFinite(Number(job.grades?.[0]?.salary))
            ? Number(job.grades[0].salary) : null;
        salary.textContent = startingSalary === null ? 'Salaire à définir' : 'Salaire : dès ' + startingSalary + ' $';

        const button = document.createElement('button');
        button.className = 'select-job-btn' + (isWhitelisted ? ' disabled' : '');
        button.type = 'button';
        button.textContent = isWhitelisted ? 'Sur concours' : 'Postuler immédiatement';
        button.disabled = isWhitelisted;
        if (!isWhitelisted && typeof job.name === 'string') {
            button.addEventListener('click', () => chooseJob(job.name));
        } else {
            button.disabled = true;
        }

        bottom.append(salary, button);
        card.append(top, bottom);
        container.appendChild(card);
    });
}

function chooseJob(jobName) {
    fetch(`https://${GetParentResourceName()}/selectJob`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ jobName })
    }).catch(() => {});
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

document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') closeJobCenter();
});

document.getElementById('job-search').addEventListener('input', (event) => {
    currentSearch = event.target.value;
    renderJobs();
});

document.querySelectorAll('.filter-btn').forEach(button => {
    button.addEventListener('click', () => {
        document.querySelectorAll('.filter-btn').forEach(item => item.classList.remove('active'));
        button.classList.add('active');
        currentCategory = button.getAttribute('data-cat') || 'all';
        renderJobs();
    });
});

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'rp_jobs';
}
