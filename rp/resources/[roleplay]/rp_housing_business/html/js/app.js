const housingData = [
    { id: 'apt_delperro', title: 'Appartement Vue Mer Del Perro', type: 'both', location: 'Del Perro Heights, Étage 12', specs: '3 Pièces • Garage 2 Places', buyPrice: 320000, rentPrice: 1500 },
    { id: 'villa_vinewood', title: 'Villa Contemporaine Vinewood', type: 'buy', location: 'Kimble Hill, Vinewood Hills', specs: '6 Pièces • Piscine • Garage 6 Places', buyPrice: 1250000, rentPrice: 0 },
    { id: 'studio_legion', title: 'Studio Moderne Legion', type: 'rent', location: 'San Andreas Ave, Centre-ville', specs: '1 Pièce • Meublé', buyPrice: 0, rentPrice: 650 },
    { id: 'motel_sandy', title: 'Caravane Rénovée Sandy Shores', type: 'both', location: 'Marina Drive, Sandy Shores', specs: '2 Pièces • Terrain Extérieur', buyPrice: 45000, rentPrice: 300 }
];

const businessData = [
    { id: 'b_tequilala', title: 'Club & Bar Tequi-la-la', location: 'West Eclipse Blvd', income: 'Revenu est.: $4,500/jour', buyPrice: 850000, rentPrice: 4000 },
    { id: 'b_repairshop', title: 'Atelier Mécanique Paleto', location: 'Paleto Bay Main St', income: 'Revenu est.: $3,200/jour', buyPrice: 420000, rentPrice: 2200 },
    { id: 'b_store', title: 'Supérette 24/7 Vespucci', location: 'Vespucci Canals', income: 'Revenu est.: $2,100/jour', buyPrice: 280000, rentPrice: 1200 }
];

let myAssets = [
    { id: 'prop_current_1', title: 'Appartement Eclipse Towers', type: 'Propriétaire', status: 'Acheté pour $450,000' }
];

document.addEventListener('DOMContentLoaded', () => {
    // Nav tabs
    const tabBtns = document.querySelectorAll('.tab-btn');
    const tabContents = document.querySelectorAll('.tab-content');

    tabBtns.forEach(btn => {
        btn.addEventListener('click', () => {
            tabBtns.forEach(b => b.classList.remove('active'));
            tabContents.forEach(c => c.classList.remove('active'));
            btn.classList.add('active');
            document.getElementById(`tab-${btn.getAttribute('data-tab')}`).classList.add('active');
        });
    });

    renderHousing('all');
    renderBusinesses();
    renderMyAssets();

    document.getElementById('btn-close').addEventListener('click', closeUI);
});

function renderHousing(filter) {
    const container = document.getElementById('housing-list');
    container.innerHTML = '';

    const filtered = housingData.filter(h => {
        if (filter === 'buy') return h.type === 'buy' || h.type === 'both';
        if (filter === 'rent') return h.type === 'rent' || h.type === 'both';
        return true;
    });

    filtered.forEach(h => {
        const card = document.createElement('div');
        card.className = 'prop-card';
        let actionButtons = '';
        if (h.type === 'buy' || h.type === 'both') {
            actionButtons += `<button class="btn-action btn-buy" onclick="buyProperty('${h.id}', ${h.buyPrice})"><i class="fa-solid fa-cart-shopping"></i> Acheter ($${h.buyPrice.toLocaleString()})</button>`;
        }
        if (h.type === 'rent' || h.type === 'both') {
            actionButtons += `<button class="btn-action btn-rent" onclick="rentProperty('${h.id}', ${h.rentPrice})"><i class="fa-solid fa-file-contract"></i> Louer ($${h.rentPrice}/sem)</button>`;
        }

        card.innerHTML = `
            <div>
                <span class="prop-badge ${h.type === 'rent' ? 'badge-rent' : 'badge-buy'}">
                    ${h.type === 'both' ? 'Achat & Location' : (h.type === 'buy' ? 'Achat uniquement' : 'Location uniquement')}
                </span>
                <h3 class="prop-title">${h.title}</h3>
                <div class="prop-location"><i class="fa-solid fa-location-dot"></i> ${h.location}</div>
                <div class="prop-specs">${h.specs}</div>
            </div>
            <div>
                <div class="prop-price">
                    ${h.buyPrice > 0 ? `$${h.buyPrice.toLocaleString()}` : ''}
                    ${h.rentPrice > 0 ? `<small>${h.buyPrice > 0 ? ' ou ' : ''}$${h.rentPrice}/semaine</small>` : ''}
                </div>
                <div class="prop-actions">
                    ${actionButtons}
                </div>
            </div>
        `;
        container.appendChild(card);
    });
}

function renderBusinesses() {
    const container = document.getElementById('business-list');
    container.innerHTML = '';

    businessData.forEach(b => {
        const card = document.createElement('div');
        card.className = 'prop-card';
        card.innerHTML = `
            <div>
                <span class="prop-badge badge-buy">Commerce / Entreprise</span>
                <h3 class="prop-title">${b.title}</h3>
                <div class="prop-location"><i class="fa-solid fa-map-pin"></i> ${b.location}</div>
                <div class="prop-specs">${b.income}</div>
            </div>
            <div>
                <div class="prop-price">
                    $${b.buyPrice.toLocaleString()} <small>ou $${b.rentPrice}/semaine</small>
                </div>
                <div class="prop-actions">
                    <button class="btn-action btn-buy" onclick="buyBusiness('${b.id}', ${b.buyPrice})"><i class="fa-solid fa-briefcase"></i> Acheter Entreprise</button>
                    <button class="btn-action btn-rent" onclick="rentBusiness('${b.id}', ${b.rentPrice})"><i class="fa-solid fa-handshake"></i> Bail Commercial</button>
                </div>
            </div>
        `;
        container.appendChild(card);
    });
}

function renderMyAssets() {
    const container = document.getElementById('myprops-list');
    container.innerHTML = '';

    if (myAssets.length === 0) {
        container.innerHTML = '<p style="color:#94a3b8; text-align:center; padding: 20px;">Vous ne possédez aucun bien immobilier ou commerce pour le moment.</p>';
        return;
    }

    myAssets.forEach((asset, idx) => {
        const div = document.createElement('div');
        div.className = 'myprop-item';
        div.innerHTML = `
            <div class="myprop-info">
                <h4>${asset.title}</h4>
                <p>${asset.type} • ${asset.status}</p>
            </div>
            <button class="btn-sell" onclick="sellAsset(${idx})"><i class="fa-solid fa-money-bill-wave"></i> Revendre (70%)</button>
        `;
        container.appendChild(div);
    });
}

function filterHousing(type) {
    document.querySelectorAll('.pill').forEach(p => p.classList.remove('active'));
    event.target.classList.add('active');
    renderHousing(type);
}

function buyProperty(id, price) {
    fetch(`https://${GetParentResourceName()}/buyProperty`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, price })
    }).catch(e => console.log('Mock buyProperty', id, price));
}

function rentProperty(id, price) {
    fetch(`https://${GetParentResourceName()}/rentProperty`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, price })
    }).catch(e => console.log('Mock rentProperty', id, price));
}

function buyBusiness(id, price) {
    fetch(`https://${GetParentResourceName()}/buyBusiness`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, price })
    }).catch(e => console.log('Mock buyBusiness', id, price));
}

function rentBusiness(id, price) {
    fetch(`https://${GetParentResourceName()}/rentBusiness`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, price })
    }).catch(e => console.log('Mock rentBusiness', id, price));
}

function sellAsset(index) {
    myAssets.splice(index, 1);
    renderMyAssets();
}

function closeUI() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(e => {});
}

function GetParentResourceName() {
    return (window.GetParentResourceName) ? window.GetParentResourceName() : 'rp_housing_business';
}
