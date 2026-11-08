let selectedItem = null;
let currentItems = [];

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'open') {
        currentItems = data.inventory || [];
        document.getElementById('inventory-wrapper').classList.remove('hidden');
        document.getElementById('cash-val').innerText = (data.cash || 0) + ' $';
        document.getElementById('bank-val').innerText = (data.bank || 0) + ' $';

        const weight = (data.currentWeight || 0).toFixed(1);
        const maxWeight = (data.maxWeight || 30.0).toFixed(1);
        document.getElementById('weight-text').innerText = `${weight} / ${maxWeight} KG`;
        document.getElementById('weight-fill').style.width = Math.min((weight / maxWeight) * 100, 100) + '%';

        renderGrid(currentItems);
    } else if (data.action === 'close') {
        document.getElementById('inventory-wrapper').classList.add('hidden');
        selectedItem = null;
    }
});

function renderGrid(items) {
    const grid = document.getElementById('items-grid');
    grid.innerHTML = '';

    // Render occupied slots
    items.forEach(item => {
        const slot = document.createElement('div');
        slot.className = 'inv-slot';
        if (selectedItem && selectedItem.name === item.name) {
            slot.classList.add('selected');
        }

        let icon = 'fa-box';
        if (item.name.includes('bread')) icon = 'fa-bread-slice';
        else if (item.name.includes('water')) icon = 'fa-bottle-water';
        else if (item.name.includes('medikit') || item.name.includes('bandage')) icon = 'fa-kit-medical';
        else if (item.name.includes('card') || item.name.includes('license')) icon = 'fa-id-card';
        else if (item.name.includes('phone')) icon = 'fa-mobile-screen-button';
        else if (item.name.includes('repair')) icon = 'fa-wrench';

        slot.innerHTML = `
            <i class="fa-solid ${icon}"></i>
            <span class="item-name">${item.label || item.name}</span>
            <span class="item-count">x${item.count}</span>
        `;

        slot.addEventListener('click', () => {
            document.querySelectorAll('.inv-slot').forEach(s => s.classList.remove('selected'));
            slot.classList.add('selected');
            selectedItem = item;
            document.getElementById('selected-label').innerText = `${item.label} (x${item.count})`;
        });

        grid.appendChild(slot);
    });

    // Fill remaining empty slots up to 25
    const emptyCount = Math.max(0, 25 - items.length);
    for (let i = 0; i < emptyCount; i++) {
        const emptySlot = document.createElement('div');
        emptySlot.className = 'inv-slot empty';
        emptySlot.style.opacity = '0.35';
        grid.appendChild(emptySlot);
    }
}

document.getElementById('btn-close').addEventListener('click', closeUI);
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' || e.key === 'F2') closeUI();
});

function closeUI() {
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', body: '{}' });
}

document.getElementById('btn-use').addEventListener('click', () => {
    if (!selectedItem) return;
    fetch(`https://${GetParentResourceName()}/useItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ item: selectedItem.name })
    });
});

document.getElementById('btn-drop').addEventListener('click', () => {
    if (!selectedItem) return;
    const count = parseInt(document.getElementById('item-quantity').value) || 1;
    fetch(`https://${GetParentResourceName()}/dropItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ item: selectedItem.name, count: count })
    });
});

document.getElementById('btn-give').addEventListener('click', () => {
    if (!selectedItem) return;
    const count = parseInt(document.getElementById('item-quantity').value) || 1;
    fetch(`https://${GetParentResourceName()}/giveItem`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ item: selectedItem.name, count: count })
    });
});
