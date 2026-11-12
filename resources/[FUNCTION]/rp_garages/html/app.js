const root = document.getElementById('garage');
const list = document.getElementById('vehicle-list');
const empty = document.getElementById('empty');
const storeButton = document.getElementById('store');
let currentGarage = null;
let vehicleRows = [];

const post = (name, data = {}) => fetch(`https://rp_garages/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
}).then(response => response.json().catch(() => ({})));

const escapeHtml = value => String(value ?? '').replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[char]));

const money = value => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(Number(value) || 0);

function renderVehicles() {
    list.innerHTML = '';
    document.getElementById('vehicle-count').textContent = `${vehicleRows.length} véhicule${vehicleRows.length > 1 ? 's' : ''}`;
    empty.classList.toggle('hidden', vehicleRows.length > 0);
    vehicleRows.forEach(vehicle => {
        const stored = vehicle.stored === true;
        const card = document.createElement('article');
        card.className = 'vehicle-card';
        card.innerHTML = `
            <div class="vehicle-art"><span>▰</span><small>${stored ? 'EN GARAGE' : 'À L’EXTÉRIEUR'}</small></div>
            <div class="vehicle-info">
                <div class="vehicle-heading"><div><h3>${escapeHtml(vehicle.label)}</h3><p>${escapeHtml(vehicle.model)}</p></div><span class="status ${stored ? 'ready' : 'out'}">${stored ? 'RANGÉ' : 'SORTI'}</span></div>
                <div class="vehicle-meta"><span>PLAQUE <strong>${escapeHtml(vehicle.plate)}</strong></span><span>ÉTAT MOTEUR <strong>${Math.round(Math.max(0, Math.min(1000, Number(vehicle.engine) || 1000)) / 10)}%</strong></span><span>ESSENCE <strong>${Math.round(Math.max(0, Math.min(100, Number(vehicle.fuel) || 0)))}%</strong></span></div>
                ${stored ? `<button class="retrieve" data-id="${Number(vehicle.id)}">Sortir le véhicule <span>→</span></button>` : '<div class="out-note">Ce véhicule est actuellement sorti du garage.</div>'}
            </div>`;
        list.appendChild(card);
    });
    list.querySelectorAll('.retrieve').forEach(button => button.addEventListener('click', () => {
        button.disabled = true;
        button.textContent = 'Préparation du véhicule…';
        post('retrieveVehicle', { vehicleId: Number(button.dataset.id) });
    }));
}

window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'open') {
        currentGarage = data.garage;
        document.getElementById('garage-title').textContent = data.garage || 'Garage personnel';
        vehicleRows = Array.isArray(data.vehicles) ? data.vehicles : [];
        storeButton.classList.toggle('hidden', data.currentVehicle !== true);
        root.classList.remove('hidden');
        renderVehicles();
    } else if (data.action === 'close') {
        root.classList.add('hidden');
        currentGarage = null;
    } else if (data.action === 'refresh') {
        vehicleRows = Array.isArray(data.vehicles) ? data.vehicles : vehicleRows;
        renderVehicles();
    }
});

document.getElementById('close').addEventListener('click', () => post('close'));
storeButton.addEventListener('click', () => {
    storeButton.disabled = true;
    post('storeVehicle').finally(() => setTimeout(() => { storeButton.disabled = false; }, 1500));
});
document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !root.classList.contains('hidden')) post('close');
});
