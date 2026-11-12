const root = document.getElementById('garage');
const list = document.getElementById('vehicle-list');
const empty = document.getElementById('empty');
const storeButton = document.getElementById('store');
const tuningRoot = document.getElementById('tuning');
const categorySelect = document.getElementById('tuning-category');
const levelSlider = document.getElementById('tuning-level');
const levelLabel = document.getElementById('tuning-level-label');
const priceLabel = document.getElementById('tuning-price');
const tuningBuy = document.getElementById('tuning-buy');

let currentGarage = null;
let vehicleRows = [];
let tuningCategories = [];
let activeCategory = null;
let tuningPending = false;

const post = (name, data = {}) => fetch('https://rp_garages/' + name, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
}).then(response => response.json().catch(() => ({})));

const escapeHtml = value => String(value == null ? '' : value).replace(/[&<>"']/g, char => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[char]));

const money = value => new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(Number(value) || 0);

function updateTuningPreview() {
    if (!activeCategory) return;
    const index = Number(levelSlider.value);
    const price = activeCategory.toggle ? activeCategory.basePrice : activeCategory.basePrice * (index + 1);
    levelLabel.textContent = activeCategory.toggle
        ? (index === 1 ? 'Activé' : 'Désactivé')
        : 'Niveau ' + (index + 1);
    priceLabel.textContent = money(price) + ' , { modType: activeCategory.modType, modIndex: index });
}

function selectTuningCategory() {
    activeCategory = tuningCategories.find(item => String(item.modType) === categorySelect.value) || null;
    if (!activeCategory) return;
    levelSlider.min = 0;
    levelSlider.max = Math.max(0, Number(activeCategory.maxIndex) || 0);
    levelSlider.value = Math.min(levelSlider.max, Math.max(0, Number(activeCategory.current) || 0));
    document.getElementById('tuning-status').textContent = activeCategory.toggle
        ? 'Active ou désactive cette option et vérifie le résultat avant de payer.'
        : 'Prévisualise le niveau sélectionné directement sur ton véhicule.';
    updateTuningPreview();
}

function renderVehicles() {
    list.innerHTML = '';
    document.getElementById('vehicle-count').textContent = vehicleRows.length + ' véhicule' + (vehicleRows.length > 1 ? 's' : '');
    empty.classList.toggle('hidden', vehicleRows.length > 0);
    vehicleRows.forEach(vehicle => {
        const stored = vehicle.stored === true;
        const card = document.createElement('article');
        card.className = 'vehicle-card';
        const status = stored ? 'RANGÉ' : 'SORTI';
        const stateClass = stored ? 'ready' : 'out';
        const engine = Math.round(Math.max(0, Math.min(1000, Number(vehicle.engine) || 1000)) / 10);
        const fuel = Math.round(Math.max(0, Math.min(100, Number(vehicle.fuel) || 0)));
        let action = stored
            ? '<button class="retrieve" data-id="' + Number(vehicle.id) + '">Sortir le véhicule <span>→</span></button>'
            : '<div class="out-note">Ce véhicule est actuellement sorti du garage.</div>';
        card.innerHTML =
            '<div class="vehicle-art"><span>▰</span><small>' + (stored ? 'EN GARAGE' : 'À L’EXTÉRIEUR') + '</small></div>' +
            '<div class="vehicle-info">' +
                '<div class="vehicle-heading"><div><h3>' + escapeHtml(vehicle.label) + '</h3><p>' + escapeHtml(vehicle.model) + '</p></div>' +
                '<span class="status ' + stateClass + '">' + status + '</span></div>' +
                '<div class="vehicle-meta"><span>PLAQUE <strong>' + escapeHtml(vehicle.plate) + '</strong></span>' +
                '<span>ÉTAT MOTEUR <strong>' + engine + '%</strong></span><span>ESSENCE <strong>' + fuel + '%</strong></span></div>' +
                action + '</div>';
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
    if (data.action === 'openTuning') {
        root.classList.add('hidden');
        tuningRoot.classList.remove('hidden');
        tuningPending = false;
        tuningBuy.disabled = false;
        tuningBuy.textContent = 'Confirmer et payer →';
        document.getElementById('workshop-title').textContent = data.workshop || 'Atelier mécanique';
        document.getElementById('tuning-plate').textContent = data.plate || '—';
        tuningCategories = Array.isArray(data.categories) ? data.categories : [];
        categorySelect.innerHTML = tuningCategories.map(item =>
            '<option value="' + Number(item.modType) + '">' + escapeHtml(item.label) + '</option>'
        ).join('');
        if (tuningCategories.length) {
            categorySelect.value = String(tuningCategories[0].modType);
            selectTuningCategory();
        }
    } else if (data.action === 'closeTuning') {
        tuningRoot.classList.add('hidden');
        tuningPending = false;
    } else if (data.action === 'tuneSaved') {
        const category = tuningCategories.find(item => Number(item.modType) === Number(data.modType));
        if (category) {
            category.current = Number(data.modIndex);
            category.installedIndex = Number(data.modIndex);
        }
        tuningPending = false;
        tuningBuy.disabled = true;
        tuningBuy.textContent = 'Amélioration enregistrée ✓';
        document.getElementById('tuning-status').textContent = 'Amélioration payée et sauvegardée sur ton véhicule.';
    } else if (data.action === 'tuneRollback') {
        tuningPending = false;
        tuningBuy.disabled = false;
        tuningBuy.textContent = 'Réessayer';
        document.getElementById('tuning-status').textContent = 'La modification a été annulée et le paiement remboursé.';
    } else if (data.action === 'open') {
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

categorySelect.addEventListener('change', selectTuningCategory);
levelSlider.addEventListener('input', updateTuningPreview);
tuningBuy.addEventListener('click', () => {
    if (!activeCategory || tuningPending) return;
    tuningPending = true;
    tuningBuy.disabled = true;
    tuningBuy.textContent = 'Paiement et enregistrement…';
    post('buyTune', { modType: activeCategory.modType, modIndex: Number(levelSlider.value) });
});

document.getElementById('tuning-close').addEventListener('click', () => post('closeTuning'));
document.getElementById('close').addEventListener('click', () => post('close'));
storeButton.addEventListener('click', () => {
    storeButton.disabled = true;
    post('storeVehicle').finally(() => setTimeout(() => { storeButton.disabled = false; }, 1500));
});

document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    if (!tuningRoot.classList.contains('hidden')) post('closeTuning');
    else if (!root.classList.contains('hidden')) post('close');
});
;
    const alreadyInstalled = Number(activeCategory.installedIndex) === index;
    tuningBuy.disabled = alreadyInstalled || tuningPending;
    tuningBuy.textContent = alreadyInstalled ? 'Déjà installé' : 'Confirmer et payer →';
    post('previewTune', { modType: activeCategory.modType, modIndex: index });
}

function selectTuningCategory() {
    activeCategory = tuningCategories.find(item => String(item.modType) === categorySelect.value) || null;
    if (!activeCategory) return;
    levelSlider.min = 0;
    levelSlider.max = Math.max(0, Number(activeCategory.maxIndex) || 0);
    levelSlider.value = Math.min(levelSlider.max, Math.max(0, Number(activeCategory.current) || 0));
    document.getElementById('tuning-status').textContent = activeCategory.toggle
        ? 'Active ou désactive cette option et vérifie le résultat avant de payer.'
        : 'Prévisualise le niveau sélectionné directement sur ton véhicule.';
    updateTuningPreview();
}

function renderVehicles() {
    list.innerHTML = '';
    document.getElementById('vehicle-count').textContent = vehicleRows.length + ' véhicule' + (vehicleRows.length > 1 ? 's' : '');
    empty.classList.toggle('hidden', vehicleRows.length > 0);
    vehicleRows.forEach(vehicle => {
        const stored = vehicle.stored === true;
        const card = document.createElement('article');
        card.className = 'vehicle-card';
        const status = stored ? 'RANGÉ' : 'SORTI';
        const stateClass = stored ? 'ready' : 'out';
        const engine = Math.round(Math.max(0, Math.min(1000, Number(vehicle.engine) || 1000)) / 10);
        const fuel = Math.round(Math.max(0, Math.min(100, Number(vehicle.fuel) || 0)));
        let action = stored
            ? '<button class="retrieve" data-id="' + Number(vehicle.id) + '">Sortir le véhicule <span>→</span></button>'
            : '<div class="out-note">Ce véhicule est actuellement sorti du garage.</div>';
        card.innerHTML =
            '<div class="vehicle-art"><span>▰</span><small>' + (stored ? 'EN GARAGE' : 'À L’EXTÉRIEUR') + '</small></div>' +
            '<div class="vehicle-info">' +
                '<div class="vehicle-heading"><div><h3>' + escapeHtml(vehicle.label) + '</h3><p>' + escapeHtml(vehicle.model) + '</p></div>' +
                '<span class="status ' + stateClass + '">' + status + '</span></div>' +
                '<div class="vehicle-meta"><span>PLAQUE <strong>' + escapeHtml(vehicle.plate) + '</strong></span>' +
                '<span>ÉTAT MOTEUR <strong>' + engine + '%</strong></span><span>ESSENCE <strong>' + fuel + '%</strong></span></div>' +
                action + '</div>';
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
    if (data.action === 'openTuning') {
        root.classList.add('hidden');
        tuningRoot.classList.remove('hidden');
        tuningPending = false;
        tuningBuy.disabled = false;
        tuningBuy.textContent = 'Confirmer et payer →';
        document.getElementById('workshop-title').textContent = data.workshop || 'Atelier mécanique';
        document.getElementById('tuning-plate').textContent = data.plate || '—';
        tuningCategories = Array.isArray(data.categories) ? data.categories : [];
        categorySelect.innerHTML = tuningCategories.map(item =>
            '<option value="' + Number(item.modType) + '">' + escapeHtml(item.label) + '</option>'
        ).join('');
        if (tuningCategories.length) {
            categorySelect.value = String(tuningCategories[0].modType);
            selectTuningCategory();
        }
    } else if (data.action === 'closeTuning') {
        tuningRoot.classList.add('hidden');
        tuningPending = false;
    } else if (data.action === 'tuneSaved') {
        const category = tuningCategories.find(item => Number(item.modType) === Number(data.modType));
        if (category) category.current = Number(data.modIndex);
        tuningPending = false;
        tuningBuy.disabled = false;
        tuningBuy.textContent = 'Amélioration enregistrée ✓';
        document.getElementById('tuning-status').textContent = 'Amélioration payée et sauvegardée sur ton véhicule.';
    } else if (data.action === 'tuneRollback') {
        tuningPending = false;
        tuningBuy.disabled = false;
        tuningBuy.textContent = 'Réessayer';
        document.getElementById('tuning-status').textContent = 'La modification a été annulée et le paiement remboursé.';
    } else if (data.action === 'open') {
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

categorySelect.addEventListener('change', selectTuningCategory);
levelSlider.addEventListener('input', updateTuningPreview);
tuningBuy.addEventListener('click', () => {
    if (!activeCategory || tuningPending) return;
    tuningPending = true;
    tuningBuy.disabled = true;
    tuningBuy.textContent = 'Paiement et enregistrement…';
    post('buyTune', { modType: activeCategory.modType, modIndex: Number(levelSlider.value) });
});

document.getElementById('tuning-close').addEventListener('click', () => post('closeTuning'));
document.getElementById('close').addEventListener('click', () => post('close'));
storeButton.addEventListener('click', () => {
    storeButton.disabled = true;
    post('storeVehicle').finally(() => setTimeout(() => { storeButton.disabled = false; }, 1500));
});

document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return;
    if (!tuningRoot.classList.contains('hidden')) post('closeTuning');
    else if (!root.classList.contains('hidden')) post('close');
});
