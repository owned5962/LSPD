const panel = document.getElementById('territory-panel');
const colorsEl = document.getElementById('colors');
const claimButton = document.getElementById('claim');
const feedback = document.getElementById('feedback');
let currentInfo = null;
let selectedColor = null;
let pending = false;

// Browser console stacks include the exact app.js line for each diagnostic.
function diag(level, event, details) {
    const prefix = '[rp_territories][NUI][' + event + ']';
    const stack = new Error().stack;
    const logger = console[level] || console.log;
    logger.call(console, prefix, details || '', stack);
}

window.addEventListener('error', event => {
    diag('error', 'UNCAUGHT_JS_ERROR', (event.message || 'Erreur inconnue') +
        ' | ' + (event.filename || 'fichier inconnu') + ':' +
        (event.lineno || 0) + ':' + (event.colno || 0));
});
window.addEventListener('unhandledrejection', event => {
    diag('error', 'UNHANDLED_PROMISE', String(event.reason || 'Promesse rejetée'));
});
diag('info', 'BOOT', 'Interface NUI initialisée');

const post = async (name, data = {}) => {
    try {
        const response = await fetch(`https://rp_territories/${name}`, {
            method: 'POST',
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: JSON.stringify(data)
        });
        if (!response.ok) diag('error', 'NUI_CALLBACK_HTTP_ERROR', name + ' | HTTP ' + response.status);
        else diag('debug', 'NUI_CALLBACK_OK', name);
        return response;
    } catch (error) {
        diag('error', 'NUI_CALLBACK_FAILED', name + ' | ' + String(error));
        throw error;
    }
};

function renderColors(colors) {
    if (!Array.isArray(colors)) diag('error', 'COLOR_DATA_INVALID', 'La liste des couleurs reçue n’est pas un tableau');
    else diag('debug', 'COLOR_LIST_RENDER', colors.length + ' couleur(s)');
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
    diag('info', 'PANEL_OPEN', 'Secteur=' + String(info?.sectorId || 'inconnu'));
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
    diag('debug', 'NUI_MESSAGE', 'Action=' + String(data.action || 'inconnue'));
    if (data.action === 'open') openPanel(data.info || {});
    if (data.action === 'claimResult') {
        pending = false;
        claimButton.disabled = currentInfo?.occupied && !currentInfo?.isOwner;
        feedback.textContent = data.result?.message || 'Résultat inconnu.';
        feedback.className = data.result?.success ? 'success' : '';
        if (data.result?.success) panel.classList.add('hidden');
    }
});

claimButton.addEventListener('click', async () => {
    if (!currentInfo || pending || claimButton.disabled || !selectedColor) return;
    diag('info', 'CLAIM_CLICK', 'Secteur=' + currentInfo.sectorId + ' | couleur=' + selectedColor);
    pending = true;
    claimButton.disabled = true;
    feedback.textContent = 'Traitement du paiement…';
    try {
        await post('claim', {sectorId: currentInfo.sectorId, colorId: selectedColor});
        diag('info', 'CLAIM_CALLBACK_SENT', 'La demande NUI a été transmise au client Lua');
    } catch (error) {
        diag('error', 'CLAIM_SUBMIT_FAILED', String(error));
        feedback.textContent = 'Impossible de contacter le serveur.';
        pending = false;
        claimButton.disabled = false;
    }
});
function closePanel() {
    diag('info', 'PANEL_CLOSE', 'Fermeture demandée');
    panel.classList.add('hidden');
    post('close').catch(error => diag('error', 'PANEL_CLOSE_FAILED', String(error)));
}
document.getElementById('close').addEventListener('click', closePanel);
document.addEventListener('keydown', event => {
    if (event.key === 'Escape') closePanel();
});
