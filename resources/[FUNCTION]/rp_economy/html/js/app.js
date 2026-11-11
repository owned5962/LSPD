function formatMoney(num) {
    return new Intl.NumberFormat('fr-FR').format(num) + ' $';
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openBank') {
        document.getElementById('bank-container').classList.remove('hidden');
        document.getElementById('display-cash').innerText = formatMoney(data.cash);
        document.getElementById('display-bank').innerText = formatMoney(data.bank);
        document.getElementById('account-holder').innerText = (data.playerName || 'CITOYEN').toUpperCase();
        document.getElementById('account-number').innerText = data.accountNumber || 'LS-8931';
        
        if (data.isATM) {
            document.getElementById('bank-title').innerText = "FLEÈCA ATM 24/7";
            document.getElementById('transfer-section').style.display = 'none';
        } else {
            document.getElementById('bank-title').innerText = "FLEÈCA BANK LOS SANTOS";
            document.getElementById('transfer-section').style.display = 'block';
        }
    } else if (data.action === 'updateBalances') {
        document.getElementById('display-cash').innerText = formatMoney(data.cash);
        document.getElementById('display-bank').innerText = formatMoney(data.bank);
    } else if (data.action === 'closeBank') {
        document.getElementById('bank-container').classList.add('hidden');
    }
});

function closeBank() {
    fetch(`https://rp_economy/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(() => {});
    document.getElementById('bank-container').classList.add('hidden');
}

document.getElementById('close-bank').addEventListener('click', closeBank);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { e.preventDefault(); closeBank(); }
});

document.getElementById('deposit-btn').addEventListener('click', () => {
    const amount = parseInt(document.getElementById('deposit-amount').value);
    if (!amount || amount <= 0) return;
    fetch(`https://rp_economy/deposit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount })
    });
    document.getElementById('deposit-amount').value = '';
});

document.getElementById('withdraw-btn').addEventListener('click', () => {
    const amount = parseInt(document.getElementById('withdraw-amount').value);
    if (!amount || amount <= 0) return;
    fetch(`https://rp_economy/withdraw`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount })
    });
    document.getElementById('withdraw-amount').value = '';
});

document.getElementById('transfer-btn').addEventListener('click', () => {
    const targetId = parseInt(document.getElementById('transfer-id').value);
    const amount = parseInt(document.getElementById('transfer-amount').value);
    if (!targetId || !amount || amount <= 0) return;
    fetch(`https://rp_economy/transfer`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ targetId, amount })
    });
    document.getElementById('transfer-id').value = '';
    document.getElementById('transfer-amount').value = '';
});

