const NUI_RESOURCE = 'rp_inventory';
let selectedItem = null;
let currentItems = [];

const itemVisuals = [
    { test: /bread|sandwich|pizza|tacos|burger|hotdog|donut|cookie|pomme|salade|steak/i, emoji: '🍔', label: 'Nourriture' },
    { test: /water|soda|coffee|the_|jus|milkshake|biere|vin_|whisky|drink/i, emoji: '🥤', label: 'Boisson' },
    { test: /medikit|bandage/i, emoji: '🩹', label: 'Soins' },
    { test: /id_card|driver_license|license/i, emoji: '🪪', label: 'Document' },
    { test: /phone/i, emoji: '📱', label: 'Téléphone' },
    { test: /radio/i, emoji: '📻', label: 'Communication' },
    { test: /repair|tool|scrap|rubber|copper|electronic|battery/i, emoji: '🧰', label: 'Équipement' },
    { test: /handcuff/i, emoji: '🔗', label: 'Sécurité' }
];

function visualForItem(item) {
    return itemVisuals.find(entry => entry.test.test(item.name || '')) || { emoji: '📦', label: 'Objet' };
}

function makeItemImage(item) {
    const visual = visualForItem(item);
    const name = String(item.name || 'item');
    // A stable per-item hash gives every distinct item its own artwork palette.
    let hash = 0;
    for (let i = 0; i < name.length; i++) hash = ((hash << 5) - hash + name.charCodeAt(i)) | 0;
    const hue = Math.abs(hash) % 360;
    const label = name.replace(/[^a-z0-9_]/gi, '').slice(0, 12).toUpperCase();
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="96" viewBox="0 0 128 96">
      <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop stop-color="hsl(${hue},58%,28%)"/><stop offset="1" stop-color="hsl(${(hue + 42) % 360},52%,13%)"/></linearGradient></defs>
      <rect width="128" height="96" rx="14" fill="url(#g)"/>
      <path d="M12 72 L116 18" stroke="hsl(${hue},85%,72%)" stroke-opacity=".22" stroke-width="10"/>
      <circle cx="64" cy="45" r="31" fill="hsl(${hue},85%,72%)" opacity=".13"/>
      <text x="64" y="59" text-anchor="middle" font-size="40">${visual.emoji}</text>
      <text x="64" y="86" text-anchor="middle" font-size="8" font-weight="700" fill="#e2e8f0" letter-spacing=".8">${label}</text>
    </svg>`;
    return 'data:image/svg+xml;charset=UTF-8,' + encodeURIComponent(svg);
}

window.addEventListener('message', function(event) {
    const data = event.data || {};
    if (data.action === 'open' || data.action === 'update') {
        currentItems = Array.isArray(data.inventory) ? data.inventory : [];
        document.getElementById('inventory-wrapper').classList.remove('hidden');
        const weight = Number(data.currentWeight || 0);
        const maxWeight = Number(data.maxWeight || 30);
        document.getElementById('weight-text').innerText = `${weight.toFixed(1)} / ${maxWeight.toFixed(1)} KG`;
        document.getElementById('weight-fill').style.width = Math.min((weight / Math.max(maxWeight, 0.1)) * 100, 100) + '%';
        renderGrid(currentItems);
    } else if (data.action === 'close') {
        document.getElementById('inventory-wrapper').classList.add('hidden');
        selectedItem = null;
        document.getElementById('selected-label').innerText = 'Aucun';
    }
});

function renderGrid(items) {
    selectedItem = selectedItem ? (items.find(item => item.name === selectedItem.name) || null) : null;
    document.getElementById('selected-label').innerText = selectedItem
        ? `${selectedItem.label || selectedItem.name} (x${selectedItem.count})` : 'Aucun';
    const grid = document.getElementById('items-grid');
    grid.innerHTML = '';
    items.forEach(item => {
        const slot = document.createElement('button');
        slot.type = 'button';
        slot.className = 'inv-slot';
        slot.setAttribute('aria-label', (item.label || item.name) + ', quantité ' + item.count);
        if (selectedItem && selectedItem.name === item.name) slot.classList.add('selected');

        const image = document.createElement('img');
        image.className = 'item-image';
        image.src = makeItemImage(item);
        image.alt = visualForItem(item).label;
        image.draggable = false;

        const name = document.createElement('span');
        name.className = 'item-name';
        name.textContent = item.label || item.name || 'Objet';

        const count = document.createElement('span');
        count.className = 'item-count';
        count.textContent = 'x' + Math.max(0, Number(item.count) || 0);

        slot.append(image, name, count);
        slot.addEventListener('click', () => {
            document.querySelectorAll('.inv-slot').forEach(s => s.classList.remove('selected'));
            slot.classList.add('selected');
            selectedItem = item;
            document.getElementById('selected-label').innerText = `${item.label || item.name} (x${item.count})`;
        });
        grid.appendChild(slot);
    });

    for (let i = 0; i < Math.max(0, 25 - items.length); i++) {
        const emptySlot = document.createElement('div');
        emptySlot.className = 'inv-slot empty';
        emptySlot.setAttribute('aria-hidden', 'true');
        grid.appendChild(emptySlot);
    }
}

document.getElementById('btn-close').addEventListener('click', closeUI);
document.addEventListener('keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); closeUI(); }
});

function nuiPost(endpoint, payload = {}) {
    return fetch(`https://${NUI_RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload)
    }).catch(error => console.error(`[rp_inventory] NUI ${endpoint} failed:`, error));
}

function closeUI() { nuiPost('close'); }

document.getElementById('btn-use').addEventListener('click', () => {
    if (selectedItem) nuiPost('useItem', { item: selectedItem.name });
});
document.getElementById('btn-drop').addEventListener('click', () => {
    if (!selectedItem) return;
    const count = Math.max(1, parseInt(document.getElementById('item-quantity').value, 10) || 1);
    nuiPost('dropItem', { item: selectedItem.name, count });
});
document.getElementById('btn-give').addEventListener('click', () => {
    if (!selectedItem) return;
    const count = Math.max(1, parseInt(document.getElementById('item-quantity').value, 10) || 1);
    nuiPost('giveItem', { item: selectedItem.name, count });
});
