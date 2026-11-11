const tablet = document.getElementById('tablet');
const vehicleList = document.getElementById('vehicles');
const priceLabel = document.getElementById('price');
const durationLabel = document.getElementById('duration-value');
const confirmButton = document.getElementById('confirm');
const declineButton = document.getElementById('decline');
const renewalNote = document.getElementById('renewal-note');
const vehicleSection = document.getElementById('vehicle-section');
const resource = 'rp_vehicle_rental';
let selectedModel = null;
let minutes = 60;
let pricePerTen = 100;
let maxHours = 12;
let isRenewal = false;
let graceTimer = null;
let locationKey = null;

function post(name, data) {
    return fetch('https://' + resource + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    });
}

function updatePrice() {
    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;
    durationLabel.textContent = hours ? (rest ? hours + ' h ' + rest + ' min' : hours + ' h') : rest + ' min';
    priceLabel.textContent = (Math.ceil(minutes / 10) * pricePerTen) + ' $';
}

function renderVehicles(vehicles) {
    vehicleList.innerHTML = '';
    selectedModel = null;
    (vehicles || []).forEach(function(vehicle, index) {
        const button = document.createElement('button');
        button.className = 'vehicle' + (index === 0 ? ' active' : '');
        const name = document.createElement('strong');
        name.textContent = vehicle.label;
        const category = document.createElement('span');
        category.textContent = vehicle.category;
        button.append(name, category);
        button.addEventListener('click', function() {
            selectedModel = vehicle.model;
            document.querySelectorAll('.vehicle').forEach(function(item) { item.classList.remove('active'); });
            button.classList.add('active');
        });
        vehicleList.appendChild(button);
        if (index === 0) selectedModel = vehicle.model;
    });
}

function closeTablet() {
    if (graceTimer) clearInterval(graceTimer);
    tablet.classList.add('hidden');
    post('close');
}

window.addEventListener('message', function(event) {
    const data = event.data || {};
    if (data.action === 'open') {
        isRenewal = data.renewal === true;
        pricePerTen = Number(data.price) || 100;
        maxHours = Number(data.maxHours) || 12;
        minutes = 60;
        tablet.classList.remove('hidden');
        updatePrice();
        document.getElementById('heading').textContent = isRenewal ? 'Prolonger votre location' : 'Prenez la route.';
        document.getElementById('subtitle').textContent = isRenewal
            ? 'Choisissez le temps supplémentaire souhaité.'
            : 'Choisissez votre véhicule et la durée de location.';
        vehicleSection.classList.toggle('hidden', isRenewal);
        renewalNote.classList.toggle('hidden', !isRenewal);
        declineButton.classList.toggle('hidden', !isRenewal);
        confirmButton.textContent = isRenewal ? 'Payer la prolongation' : 'Confirmer la location';
        confirmButton.disabled = false;
        if (!isRenewal) {
            locationKey = data.location || null;
            renderVehicles(data.vehicles || []);
        } else {
            selectedModel = null;
        }
        if (graceTimer) clearInterval(graceTimer);
        if (isRenewal) {
            let remaining = 60;
            document.getElementById('grace').textContent = 'Vous avez ' + remaining + ' secondes.';
            graceTimer = setInterval(function() {
                remaining -= 1;
                document.getElementById('grace').textContent = 'Vous avez ' + Math.max(0, remaining) + ' secondes.';
                if (remaining <= 0) {
                    clearInterval(graceTimer);
                    closeTablet();
                }
            }, 1000);
        }
    } else if (data.action === 'close') {
        tablet.classList.add('hidden');
        if (graceTimer) clearInterval(graceTimer);
    }
});

document.getElementById('minus').addEventListener('click', function() {
    minutes = Math.max(10, minutes - 10);
    updatePrice();
});
document.getElementById('plus').addEventListener('click', function() {
    minutes = Math.min(maxHours * 60, minutes + 10);
    updatePrice();
});
confirmButton.addEventListener('click', function() {
    if (isRenewal) {
        post('renew', { minutes: minutes });
    } else if (selectedModel && locationKey) {
        post('rent', { location: locationKey, model: selectedModel, minutes: minutes });
    }
    confirmButton.disabled = true;
    setTimeout(function() { confirmButton.disabled = false; }, 1200);
});
declineButton.addEventListener('click', function() {
    post('decline');
    tablet.classList.add('hidden');
    if (graceTimer) clearInterval(graceTimer);
});
document.getElementById('close').addEventListener('click', closeTablet);
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && !tablet.classList.contains('hidden')) closeTablet();
});
