const taxiDestinations = [
    { id: 'legion', name: 'Place Legion Square (Centre-Ville)', price: 45, desc: 'Cœur névralgique de Los Santos, banques et commerces.', coords: { x: 195.2, y: -933.8, z: 30.6 } },
    { id: 'airport', name: 'Aéroport International (LSX)', price: 120, desc: 'Terminaux 1-4, pistes d\'atterrissage et loueurs.', coords: { x: -1037.2, y: -2737.5, z: 20.1 } },
    { id: 'pier', name: 'Del Perro Pier (Plage)', price: 75, desc: 'Jetée d\'attractions, front de mer et bars de plage.', coords: { x: -1652.8, y: -999.4, z: 13.0 } },
    { id: 'hospital', name: 'Hôpital Pillbox Hill', price: 50, desc: 'Urgences médicales et centre de soins principal.', coords: { x: 341.0, y: -1397.0, z: 32.5 } },
    { id: 'casino', name: 'The Diamond Casino & Resort', price: 90, desc: 'Vinewood Est, jeux, courses hippiques et bars.', coords: { x: 924.5, y: 47.1, z: 81.1 } },
    { id: 'sandy', name: 'Sandy Shores (Grand Senora)', price: 210, desc: 'Aérodrome de Trevor, station service et désert.', coords: { x: 1877.0, y: 3705.8, z: 33.2 } }
];

const busRoutes = [
    { id: 'line1', name: 'Ligne 1 : Express Métropolitain', price: 15, desc: 'Aéroport LSX ➔ Del Perro ➔ Legion Square ➔ Hôpital Pillbox' },
    { id: 'line2', name: 'Ligne 2 : Vinewood Hills & Casino', price: 15, desc: 'Legion Square ➔ Alta ➔ Casino Diamond ➔ Vinewood Boulevard' },
    { id: 'line3', name: 'Ligne 3 : Intercités Nord (Sandy Shores)', price: 30, desc: 'Los Santos Central ➔ Senora Freeway ➔ Sandy Shores Medical' }
];

document.addEventListener('DOMContentLoaded', () => {
    // Tab switching
    const tabButtons = document.querySelectorAll('.tab-btn');
    const tabPanels = document.querySelectorAll('.tab-panel');

    tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            tabButtons.forEach(b => b.classList.remove('active'));
            tabPanels.forEach(p => p.classList.remove('active'));

            btn.classList.add('active');
            const target = btn.getAttribute('data-tab');
            document.getElementById(`tab-${target}`).classList.add('active');
        });
    });

    // Populate Taxi Destinations
    const taxiList = document.getElementById('taxi-destinations');
    taxiDestinations.forEach(dest => {
        const card = document.createElement('div');
        card.className = 'destination-card';
        card.innerHTML = `
            <div>
                <div class="card-top">
                    <span class="card-title">${dest.name}</span>
                    <span class="card-price">$${dest.price}</span>
                </div>
                <p class="card-desc">${dest.desc}</p>
            </div>
            <button class="btn-ride" onclick="orderTaxi('${dest.id}')">
                <i class="fa-solid fa-taxi"></i> Appeler Chauffeur IA
            </button>
        `;
        taxiList.appendChild(card);
    });

    // Populate Bus Routes
    const busList = document.getElementById('bus-routes-list');
    busRoutes.forEach(route => {
        const card = document.createElement('div');
        card.className = 'route-card';
        card.innerHTML = `
            <div>
                <div class="card-top">
                    <span class="card-title">${route.name}</span>
                    <span class="card-price">$${route.price}</span>
                </div>
                <p class="card-desc">${route.desc}</p>
            </div>
            <button class="btn-ride" onclick="boardBus('${route.id}')">
                <i class="fa-solid fa-ticket"></i> Monter dans le Bus Suivant
            </button>
        `;
        busList.appendChild(card);
    });

    document.getElementById('btn-close').addEventListener('click', closeUI);
});

function orderTaxi(destId) {
    const dest = taxiDestinations.find(d => d.id === destId);
    const style = document.getElementById('taxi-driving-style').value;
    fetch(`https://${GetParentResourceName()}/requestTaxi`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ destination: dest, drivingStyle: style })
    }).catch(e => console.log('Mock requestTaxi:', destId, style));
    closeUI();
}

function boardBus(routeId) {
    const route = busRoutes.find(r => r.id === routeId);
    fetch(`https://${GetParentResourceName()}/requestBus`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ route: route })
    }).catch(e => console.log('Mock requestBus:', routeId));
    closeUI();
}

function closeUI() {
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(e => {});
}

function GetParentResourceName() {
    return (window.GetParentResourceName) ? window.GetParentResourceName() : 'rp_transit_ai';
}

window.addEventListener('message', (event) => {
    if (event.data.action === 'openTransit') {
        document.getElementById('transit-container').style.display = 'flex';
    } else if (event.data.action === 'closeTransit') {
        document.getElementById('transit-container').style.display = 'none';
    }
});
