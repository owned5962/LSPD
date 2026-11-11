const post = (name, data = {}) => fetch('https://rp_economy/' + name, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
}).then(response => response.json()).catch(() => ({ ok: false }));

const $ = id => document.getElementById(id);
let bankOpen = false;
let authenticated = false;
let isATM = false;
let toastTimer = null;
const busy = new Set();

function formatMoney(value) {
    const amount = Number(value);
    return new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(Number.isFinite(amount) ? amount : 0) + ' $';
}

function showToast(message, kind = 'info') {
    const toast = $('bank-toast');
    toast.textContent = message || 'Opération terminée.';
    toast.className = 'toast ' + (kind === 'error' ? 'error' : kind === 'success' ? 'success' : 'info');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toast.classList.add('hidden'), 4200);
}

function setAuthStatus(message, state = '') {
    const status = $('auth-status');
    status.textContent = message;
    status.className = 'auth-status ' + state;
}

function setButtonBusy(id, value, label) {
    const button = $(id);
    if (!button) return;
    button.disabled = value;
    if (value) {
        button.dataset.originalLabel = button.textContent;
        button.textContent = label || 'Traitement…';
    } else if (button.dataset.originalLabel) {
        button.textContent = button.dataset.originalLabel;
        delete button.dataset.originalLabel;
    }
}

function resetTerminal() {
    bankOpen = false;
    authenticated = false;
    busy.clear();
    $('bank-container').classList.add('hidden');
    $('screen-auth').classList.remove('hidden');
    $('screen-account').classList.add('hidden');
    $('deposit-amount').value = '';
    $('withdraw-amount').value = '';
    $('transfer-id').value = '';
    $('transfer-amount').value = '';
    $('bank-toast').classList.add('hidden');
    $('fingerprint-btn').disabled = false;
    $('fingerprint-btn').innerHTML = '<span class="finger-btn-icon">◎</span> Scanner mon empreinte';
    setAuthStatus('En attente de votre empreinte');
}

function closeBank() {
    if (!bankOpen) return;
    post('close');
    resetTerminal();
}

function validAmount(inputId) {
    const input = $(inputId);
    const amount = Number(input.value);
    if (!Number.isSafeInteger(amount) || amount < 1 || amount > 1000000) {
        showToast('Saisissez un montant entier compris entre 1 et 1 000 000 $.', 'error');
        input.focus();
        return null;
    }
    return amount;
}

async function runTransaction(name, buttonId, payload, inputs, label) {
    if (!authenticated || busy.has(name)) return;
    busy.add(name);
    setButtonBusy(buttonId, true, label || 'Traitement…');
    const result = await post(name, payload);
    if (!result || result.ok === false) {
        showToast('Impossible d’envoyer la demande. Réessayez.', 'error');
        busy.delete(name);
        setButtonBusy(buttonId, false);
        return;
    }
    inputs.forEach(id => { if ($(id)) $(id).value = ''; });
    showToast('Demande envoyée à la banque…', 'info');
}

$('fingerprint-btn').addEventListener('click', async () => {
    if (!bankOpen || authenticated || busy.has('authenticate')) return;
    busy.add('authenticate');
    const button = $('fingerprint-btn');
    button.disabled = true;
    button.innerHTML = '<span class="finger-btn-icon scanning">◎</span> Lecture en cours…';
    setAuthStatus('Analyse de votre empreinte biométrique…', 'scanning');
    $('fingerprint-btn').classList.add('scanning-button');
    const result = await post('authenticate');
    if (!result || result.ok === false) {
        busy.delete('authenticate');
        button.disabled = false;
        button.innerHTML = '<span class="finger-btn-icon">◎</span> Réessayer';
        button.classList.remove('scanning-button');
        setAuthStatus('Lecteur indisponible. Réessayez.', 'error');
    }
});

$('deposit-btn').addEventListener('click', () => {
    const amount = validAmount('deposit-amount');
    if (amount !== null) runTransaction('deposit', 'deposit-btn', { amount }, ['deposit-amount'], 'Dépôt…');
});
$('withdraw-btn').addEventListener('click', () => {
    const amount = validAmount('withdraw-amount');
    if (amount !== null) runTransaction('withdraw', 'withdraw-btn', { amount }, ['withdraw-amount'], 'Retrait…');
});
$('transfer-btn').addEventListener('click', () => {
    const targetId = Number($('transfer-id').value);
    const amount = validAmount('transfer-amount');
    if (!Number.isSafeInteger(targetId) || targetId < 1) {
        showToast('Indiquez un ID joueur valide.', 'error');
        $('transfer-id').focus();
        return;
    }
    if (amount !== null) runTransaction('transfer', 'transfer-btn', { targetId, amount }, ['transfer-id', 'transfer-amount'], 'Envoi…');
});

$('close-bank').addEventListener('click', closeBank);
document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && bankOpen) {
        event.preventDefault();
        closeBank();
    }
});

window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'openBank') {
        resetTerminal();
        bankOpen = true;
        isATM = data.isATM === true;
        $('bank-container').classList.remove('hidden');
        $('location-label').textContent = data.locationLabel || (isATM ? 'Distributeur automatique · 24/7' : 'Agence bancaire');
        $('transfer-section').classList.toggle('hidden', isATM);
        $('account-holder').textContent = data.playerName || 'Citoyen';
        $('account-number').textContent = data.accountNumber || 'LS-000000';
        setAuthStatus('En attente de votre empreinte');
    } else if (data.action === 'authenticationSuccess') {
        if (!bankOpen) return;
        authenticated = true;
        busy.delete('authenticate');
        $('fingerprint-btn').classList.remove('scanning-button');
        $('screen-auth').classList.add('hidden');
        $('screen-account').classList.remove('hidden');
        $('account-holder').textContent = data.playerName || 'Citoyen';
        $('account-number').textContent = data.accountNumber || 'LS-000000';
        $('display-bank').textContent = formatMoney(data.bank);
        $('display-cash').textContent = formatMoney(data.cash);
        showToast('Empreinte reconnue. Bienvenue chez Fleeca.', 'success');
    } else if (data.action === 'authenticationFailed') {
        busy.delete('authenticate');
        $('fingerprint-btn').disabled = false;
        $('fingerprint-btn').classList.remove('scanning-button');
        $('fingerprint-btn').innerHTML = '<span class="finger-btn-icon">◎</span> Réessayer';
        setAuthStatus(data.message || 'Empreinte non reconnue.', 'error');
    } else if (data.action === 'authenticationExpired') {
        authenticated = false;
        busy.clear();
        $('screen-account').classList.add('hidden');
        $('screen-auth').classList.remove('hidden');
        $('fingerprint-btn').disabled = false;
        $('fingerprint-btn').classList.remove('scanning-button');
        $('fingerprint-btn').innerHTML = '<span class="finger-btn-icon">◎</span> Scanner à nouveau';
        setAuthStatus('Votre session a expiré. Veuillez vous identifier.', 'error');
    } else if (data.action === 'updateBalances') {
        $('display-cash').textContent = formatMoney(data.cash);
        $('display-bank').textContent = formatMoney(data.bank);
        ['deposit', 'withdraw', 'transfer'].forEach(name => {
            if (busy.has(name)) {
                busy.delete(name);
                setButtonBusy(name + '-btn', false);
            }
        });
    } else if (data.action === 'bankNotice') {
        showToast(data.message, data.kind);
        if (data.kind === 'error' || data.kind === 'warning' || data.kind === 'success') {
            ['deposit', 'withdraw', 'transfer'].forEach(name => {
                if (busy.has(name)) {
                    busy.delete(name);
                    setButtonBusy(name + '-btn', false);
                }
            });
        }
    } else if (data.action === 'closeBank') {
        resetTerminal();
    }
});
