const tablet = document.getElementById('tablet');
const cashValue = document.getElementById('cash-value');
const productsRoot = document.getElementById('products');
const feedback = document.getElementById('feedback');
const closeButton = document.getElementById('close');
let purchasing = new Set();
let currentMode = 'store';

function formatCash(value) {
    return Math.max(0, Number(value) || 0).toLocaleString('fr-FR') + ' $';
}

function post(name, data = {}) {
    return fetch('https://rp_businesses/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
}

function closeTablet() {
    post(currentMode === 'ammu' ? 'closeAmmunation' : 'closeStore').catch(() => {});
}

function makeProductImage(symbol, label) {
    const escapeXml = value => String(value || '').replace(/[&<>"']/g, char => ({
        '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;'
    }[char]));
    const safeLabel = escapeXml(label || 'Produit');
    const safeSymbol = escapeXml(symbol || '🛒');
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="240" height="160" viewBox="0 0 240 160">' +
        '<defs><linearGradient id="g" x2="0" y2="1"><stop stop-color="#414a50"/><stop offset="1" stop-color="#20262b"/></linearGradient></defs>' +
        '<rect width="240" height="160" rx="14" fill="url(#g)"/>' +
        '<text x="120" y="100" text-anchor="middle" font-size="76">' + safeSymbol + '</text>' +
        '<title>' + safeLabel + '</title></svg>';
    return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}

function renderProducts(products) {
    productsRoot.replaceChildren();
    purchasing.clear();

    (Array.isArray(products) ? products : []).forEach(product => {
        if (!product || typeof product.item !== 'string') return;

        const card = document.createElement('article');
        card.className = 'product-card';

        const visual = document.createElement('div');
        visual.className = 'product-image';
        visual.setAttribute('aria-label', product.label || 'Produit');

        const image = document.createElement('img');
        image.className = 'product-art';
        image.alt = product.label || 'Produit';
        image.src = makeProductImage(product.image, product.label);
        visual.append(image);

        const details = document.createElement('div');
        details.className = 'product-details';

        const name = document.createElement('h2');
        name.textContent = product.label || product.item;

        const price = document.createElement('strong');
        price.className = 'product-price';
        price.textContent = formatCash(product.price);

        const button = document.createElement('button');
        button.className = 'buy-button';
        button.type = 'button';
        button.textContent = 'ACHETER';
        button.addEventListener('click', () => {
            if (purchasing.has(product.item)) return;
            purchasing.add(product.item);
            button.disabled = true;
            feedback.className = 'feedback';
            feedback.textContent = 'Validation de l’achat…';

            const endpoint = product.item === 'pistol' ? 'buyAmmunationPistol' : 'buyStoreItem';
            const payload = product.item === 'pistol' ? {} : { item: product.item };
            post(endpoint, payload).catch(() => {
                purchasing.delete(product.item);
                button.disabled = false;
                feedback.className = 'feedback error';
                feedback.textContent = 'Connexion à la boutique impossible.';
            });
        });

        details.append(name, price, button);
        card.append(visual, details);
        productsRoot.append(card);
    });
}

closeButton.addEventListener('click', closeTablet);
document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && !tablet.classList.contains('hidden')) {
        event.preventDefault();
        closeTablet();
    }
});

window.addEventListener('message', event => {
    const data = event.data || {};

    if (data.action === 'openStore' || data.action === 'openAmmunation') {
        currentMode = data.action === 'openAmmunation' ? 'ammu' : 'store';
        tablet.classList.remove('hidden');
        cashValue.textContent = formatCash(data.cash);
        document.getElementById('store-title').textContent =
            data.storeName || (currentMode === 'ammu' ? 'AMMU-NATION' : 'STORE');

        if (currentMode === 'ammu') {
            renderProducts([{
                item: 'pistol',
                label: 'Pistolet standard',
                price: Number(data.price) || 500,
                image: '🔫'
            }]);
        } else {
            renderProducts(data.products);
        }

        feedback.className = 'feedback';
        feedback.textContent = 'Paiement en espèces uniquement.';
    } else if (data.action === 'closeStore' || data.action === 'closeAmmunation') {
        tablet.classList.add('hidden');
        purchasing.clear();
    } else if (data.action === 'storePurchaseResult' || data.action === 'purchaseResult') {
        cashValue.textContent = formatCash(data.cash);
        feedback.className = 'feedback ' + (data.success ? 'success' : 'error');
        feedback.textContent = data.message || '';
        document.querySelectorAll('.buy-button').forEach(button => {
            button.disabled = false;
        });
        purchasing.clear();
    }
});
