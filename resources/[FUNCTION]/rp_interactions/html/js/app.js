window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'open') {
        const jobData = data.jobData || {};
        document.getElementById('job-title').innerText = jobData.label || 'Menu Métier (F6)';
        renderActions(jobData.actions || []);
        document.getElementById('jobmenu-wrapper').classList.remove('hidden');
    } else if (data.action === 'close') {
        document.getElementById('jobmenu-wrapper').classList.add('hidden');
    }
});

function renderActions(actions) {
    const container = document.getElementById('actions-list');
    container.innerHTML = '';

    actions.forEach(act => {
        const row = document.createElement('div');
        row.className = 'action-row';
        row.innerHTML = `<i class="fa-solid ${act.icon || 'fa-bolt'}"></i> <span>${act.label}</span>`;
        row.addEventListener('click', () => {
            let amount = 0;
            if (act.id === 'billing' || act.id === 'fine') {
                amount = prompt('Montant de la facture ($) :', '250');
                if (!amount) return;
            }
            fetch(`https://rp_interactions/triggerAction`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ actionId: act.id, amount: amount })
            });
            document.getElementById('jobmenu-wrapper').classList.add('hidden');
        });
        container.appendChild(row);
    });
}

document.getElementById('close-btn').addEventListener('click', closeMenu);
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'F6') closeMenu();
});

function closeMenu() {
    document.getElementById('jobmenu-wrapper').classList.add('hidden');
    fetch(`https://rp_interactions/close`, { method: 'POST', body: '{}' });
}
