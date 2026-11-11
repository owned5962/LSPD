const tablet = document.getElementById('tablet');
const vehicleList = document.getElementById('vehicles');
const bankLabel = document.getElementById('bank');
const buyButton = document.getElementById('buy');
const selectedName = document.getElementById('selected-name');
const selectedPrice = document.getElementById('selected-price');
const feedback = document.getElementById('feedback');
const resource = 'rp_vehicle_dealership';
let selectedVehicle = null;
let bankBalance = 0;
let purchasePending = false;

function post(name, data) {
    return fetch('https://' + resource + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    });
}

function money(value) {
    return new Intl.NumberFormat('fr-FR').format(Number(value) || 0) + ' $';
}

function renderVehicles(vehicles) {
    vehicleList.innerHTML = '';
    selectedVehicle = null;
    (vehicles || []).forEach(function(vehicle) {
        const card = document.createElement('button');
        card.type = 'button';
        card.className = 'vehicle';
        const art = document.createElement('div');
        art.className = 'vehicle-art';
        const image = document.createElement('img');
        image.src = 'images/' + vehicle.image + '.svg';
        image.alt = vehicle.label;
        image.onerror = function() { image.style.opacity = '0'; };
        art.appendChild(image);

        const info = document.createElement('div');
        info.className = 'vehicle-info';
        const identity = document.createElement('div');
        const name = document.createElement('strong');
        name.textContent = vehicle.label;
        const category = document.createElement('small');
        category.textContent = vehicle.category;
        identity.append(name, category);
        const price = document.createElement('b');
        price.textContent = money(vehicle.price);
        info.append(identity, price);
        card.append(art, info);

        card.addEventListener('click', function() {
            if (purchasePending) return;
            selectedVehicle = vehicle;
            document.querySelectorAll('.vehicle').forEach(function(item) {
                item.classList.remove('active');
                const tag = item.querySelector('.selected-tag');
                if (tag) tag.remove();
            });
            card.classList.add('active');
            const tag = document.createElement('span');
            tag.className = 'selected-tag';
            tag.textContent = 'SÉLECTIONNÉ';
            card.appendChild(tag);
            selectedName.textContent = vehicle.label;
            selectedPrice.textContent = money(vehicle.price);
            buyButton.disabled = false;
            buyButton.textContent = 'Acheter le véhicule →';
            feedback.textContent = vehicle.price > bankBalance ? 'Solde bancaire insuffisant pour ce modèle.' : '';
        });
        vehicleList.appendChild(card);
    });
}

function closeTablet() {
    tablet.classList.add('hidden');
    post('close');
}

window.addEventListener('message', function(event) {
    const data = event.data || {};
    if (data.action === 'open') {
        bankBalance = Number(data.bank) || 0;
        bankLabel.textContent = money(bankBalance);
        document.getElementById('dealer-name').textContent = data.dealer || 'Concessionnaire Los Santos';
        document.getElementById('count').textContent = (data.vehicles || []).length + ' véhicules';
        selectedName.textContent = 'Choisissez un véhicule';
        selectedPrice.textContent = '—';
        feedback.textContent = '';
        purchasePending = false;
        buyButton.disabled = true;
        buyButton.textContent = 'Acheter le véhicule →';
        renderVehicles(data.vehicles || []);
        tablet.classList.remove('hidden');
    } else if (data.action === 'purchaseError') {
        purchasePending = false;
        buyButton.disabled = !selectedVehicle;
        buyButton.textContent = 'Réessayer l’achat →';
        feedback.textContent = data.message || 'Achat impossible.';
    } else if (data.action === 'close') {
        tablet.classList.add('hidden');
    }
});

buyButton.addEventListener('click', function() {
    if (!selectedVehicle || purchasePending || selectedVehicle.price > bankBalance) {
        feedback.textContent = selectedVehicle ? 'Solde bancaire insuffisant.' : 'Sélectionnez un véhicule.';
        return;
    }
    purchasePending = true;
    buyButton.disabled = true;
    buyButton.textContent = 'Validation et préparation…';
    feedback.textContent = 'Votre paiement est en cours de validation.';
    post('buyVehicle', { model: selectedVehicle.model });
});

document.getElementById('close').addEventListener('click', closeTablet);
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape' && !tablet.classList.contains('hidden')) closeTablet();
});
