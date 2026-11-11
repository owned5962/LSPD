const panel = document.getElementById('territory-panel');
const colorsEl = document.getElementById('colors');
const claimButton = document.getElementById('claim');
const feedback = document.getElementById('feedback');
let currentInfo = null;
let selectedColor = null;
let pending = false;

const post = (name, data = {}) => fetch(`https://rp_territories/${name}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json; charset=UTF-8'},
    body: JSON.stringify(data)
});

function renderColors(colors) {
    colorsEl.replaceChildren();
    (Array.isArray(colors) ? colors : []).forEach(color => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'color-option' + (Number(color.id) === selectedColor ? ' selected' : '');
        const swatch = document.createElement('span');
        swatch.className = 'swatch';
        swatch.style.backgroundColor = color.hex;
        const label = document.createElement('span');
        label.textContent = color.name;
        button.append(swatch, label);
        button.addEventListener('click', () => {
            selectedColor = Number(color.id);
            renderColors(currentInfo.colors);
        });
        colorsEl.appendChild(button);
    });
}

function openPanel(info) {
    currentInfo = info;
    selectedColor = Number(info.color) || Number(info.colors?.[0]?.id) || 1;
    pending = false;
    document.getElementById('sector-title').textContent = `Secteur ${info.sectorId || ''}`;
    document.getElementById('price').textContent = `${info.price} $`;
    document.getElementById('duration').textContent = `${info.durationDays} jours`;
    const status = document.getElementById('status');
    const occupiedByOther = info.occupied && !info.isOwner;
    if (info.isOwner) {
        const remaining = Math.max(0, Number(info.expiresAt) - Math.floor(Date.now() / 1000));
        const days = Math.ceil(remaining / 86400);
        status.textContent = `Tu possèdes ce secteur. Il te reste environ ${days} jour(s). Paie 100 $ pour renouveler et changer sa couleur.`;
        claimButton.textContent = 'Renouveler 7 jours — 100 $';
    } else if (occupiedByOther) {
        status.textContent = `Ce secteur est actuellement revendiqué par ${info.ownerName || 'un autre joueur'}. Il sera libéré à son expiration s'il ne renouvelle pas.`;
        claimButton.textContent = 'Secteur indisponible';
    } else {
        status.textContent = 'Ce secteur est libre. Paie 100 $ pour le revendiquer pendant 7 jours.';
        claimButton.textContent = 'Revendiquer le secteur — 100 $';
    }
    claimButton.disabled = occupiedByOther;
    feedback.textContent = '';
    feedback.className = '';
    renderColors(info.colors);
    panel.classList.remove('hidden');
}

window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'open') openPanel(data.info || {});
    if (data.action === 'claimResult') {
        pending = false;
        claimButton.disabled = currentInfo?.occupied && !currentInfo?.isOwner;
        feedback.textContent = data.result?.message || 'Résultat inconnu.';
        feedback.className = data.result?.success ? 'success' : '';
    }
});

claimButton.addEventListener('click', async () => {
    if (!currentInfo || pending || claimButton.disabled || !selectedColor) return;
    pending = true;
    claimButton.disabled = true;
    feedback.textContent = 'Traitement du paiement…';
    try {
        await post('claim', {sectorId: currentInfo.sectorId, colorId: selectedColor});
    } catch (_) {
        feedback.textContent = 'Impossible de contacter le serveur.';
        pending = false;
        claimButton.disabled = false;
    }
});
function closePanel() {
    panel.classList.add('hidden');
    post('close');
}
document.getElementById('close').addEventListener('click', closePanel);
document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closePanel();
});
