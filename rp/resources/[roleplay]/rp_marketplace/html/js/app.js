let marketplaceAds = [
    { id: 'ad_1', category: 'car', title: 'Karin Sultan RS Custom', price: 68000, seller: 'Marcus_V (555-4012)' },
    { id: 'ad_2', category: 'car', title: 'Bravado Buffalo STX', price: 110000, seller: 'Tony_S (555-8819)' },
    { id: 'ad_3', category: 'bike', title: 'Vélo BMX Pro Chrome', price: 750, seller: 'Carl_J (555-2144)' },
    { id: 'ad_4', category: 'bike', title: 'Pegassi Bati 801 RR', price: 18500, seller: 'Elena_R (555-9011)' },
    { id: 'ad_5', category: 'item', title: 'Kit d\'Outils & Kit Réparation x5', price: 1200, seller: 'Bob_M (555-3301)' },
    { id: 'ad_6', category: 'item', title: 'Montre de Luxe Crowex Gold', price: 9500, seller: 'Vincent_K (555-7762)' }
];

let currentCat = 'all';

document.addEventListener('DOMContentLoaded', () => {
    renderListings();
    document.getElementById('btn-close').addEventListener('click', closeUI);
});

function switchCategory(cat) {
    currentCat = cat;
    document.querySelectorAll('.cat-btn').forEach(b => b.classList.remove('active'));
    event.target.classList.add('active');
    renderListings();
}

function renderListings() {
    const container = document.getElementById('listings-container');
    container.innerHTML = '';

    const filtered = marketplaceAds.filter(a => currentCat === 'all' || a.category === currentCat);

    filtered.forEach(ad => {
        const card = document.createElement('div');
        card.className = 'ad-card';

        let badgeClass = 'badge-item';
        let badgeLabel = 'Objet';
        if (ad.category === 'car') {
            badgeClass = 'badge-car';
            badgeLabel = 'Voiture';
        } else if (ad.category === 'bike') {
            badgeClass = 'badge-bike';
            badgeLabel = 'Vélo / Moto';
        }

        card.innerHTML = `
            <div>
                <span class="ad-badge ${badgeClass}">${badgeLabel}</span>
                <h4 class="ad-title">${ad.title}</h4>
                <div class="ad-seller"><i class="fa-solid fa-user"></i> ${ad.seller}</div>
            </div>
            <div>
                <div class="ad-price">$${ad.price.toLocaleString()}</div>
                <button class="btn-buy-ad" onclick="buyListing('${ad.id}', ${ad.price})">
                    <i class="fa-solid fa-cart-shopping"></i> Acheter Immédiatement
                </button>
            </div>
        `;
        container.appendChild(card);
    });
}

function openPublishModal() {
    document.getElementById('modal-publish').classList.add('active');
}

function closePublishModal() {
    document.getElementById('modal-publish').classList.remove('active');
}

function submitAd() {
    const cat = document.getElementById('ad-category').value;
    const title = document.getElementById('ad-title').value.trim();
    const price = parseInt(document.getElementById('ad-price').value);
    const phone = document.getElementById('ad-phone').value.trim();

    if (!title || isNaN(price) || price <= 0) {
        alert('Veuillez renseigner un titre et un prix valide.');
        return;
    }

    const newAd = {
        id: 'ad_' + Date.now(),
        category: cat,
        title: title,
        price: price,
        seller: `Moi (${phone})`
    };

    marketplaceAds.unshift(newAd);
    closePublishModal();
    renderListings();

    fetch(`https://${GetParentResourceName()}/publishAd`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newAd)
    }).catch(e => console.log('Mock publishAd', newAd));
}

function buyListing(id, price) {
    fetch(`https://${GetParentResourceName()}/buyListing`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id, price })
    }).catch(e => console.log('Mock buyListing', id, price));

    marketplaceAds = marketplaceAds.filter(a => a.id !== id);
    renderListings();
}

function closeUI() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(e => {});
}

function GetParentResourceName() {
    return (window.GetParentResourceName) ? window.GetParentResourceName() : 'rp_marketplace';
}
