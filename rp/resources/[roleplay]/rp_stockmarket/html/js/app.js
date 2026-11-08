const defaultStocks = [
    { id: 'MAZ', name: 'Maze Bank Financial', symbol: 'MAZ / USD', price: 340.50, change: 4.8 },
    { id: 'MRW', name: 'Merryweather Security', symbol: 'MRW / USD', price: 185.20, change: -1.4 },
    { id: 'LSC', name: 'Los Santos Customs', symbol: 'LSC / USD', price: 92.40, change: 8.6 },
    { id: 'BLT', name: 'Bleeter Social Media', symbol: 'BLT / USD', price: 45.10, change: 12.3 },
    { id: 'ECL', name: 'eCola Beverages Corp', symbol: 'ECL / USD', price: 28.90, change: -3.1 },
    { id: 'FLC', name: 'Fleeca Holding Inc', symbol: 'FLC / USD', price: 210.00, change: 2.1 }
];

let activeStock = defaultStocks[0];

function renderStockList() {
    const container = document.getElementById('stocks-container');
    if (!container) return;
    container.innerHTML = '';

    defaultStocks.forEach(stock => {
        const item = document.createElement('div');
        item.className = 'stock-item' + (stock.id === activeStock.id ? ' active' : '');
        item.innerHTML = `
            <div class="stock-info">
                <div class="name">${stock.name}</div>
                <div class="symbol">${stock.symbol}</div>
            </div>
            <div class="stock-numbers">
                <div class="price">${stock.price.toFixed(2)} $</div>
                <div class="var ${stock.change >= 0 ? 'up' : 'down'}">${stock.change >= 0 ? '+' : ''}${stock.change.toFixed(1)}%</div>
            </div>
        `;
        item.addEventListener('click', () => {
            selectStock(stock);
            document.querySelectorAll('.stock-item').forEach(i => i.classList.remove('active'));
            item.classList.add('active');
        });
        container.appendChild(item);
    });
}

function selectStock(stock) {
    activeStock = stock;
    document.getElementById('active-stock-name').innerText = stock.name;
    document.getElementById('active-stock-symbol').innerText = stock.symbol;
    document.getElementById('active-stock-price').innerText = `${stock.price.toFixed(2)} $`;

    const changeEl = document.getElementById('active-stock-change');
    changeEl.className = 'price-change ' + (stock.change >= 0 ? 'positive' : 'negative');
    changeEl.innerText = `${stock.change >= 0 ? '+' : ''}${stock.change.toFixed(1)}% aujourd'hui`;

    updateTotalCost();
}

function updateTotalCost() {
    const qty = parseInt(document.getElementById('trade-qty').value) || 1;
    const total = qty * activeStock.price;
    document.getElementById('trade-total-cost').innerText = `${total.toLocaleString()} $`;
}

const tradeQtyEl = document.getElementById('trade-qty');
if (tradeQtyEl) {
    tradeQtyEl.addEventListener('input', updateTotalCost);
}

window.addEventListener('message', function(event) {
    const data = event.data;
    if (data.action === 'open') {
        document.getElementById('stock-container').classList.remove('hidden');
        renderStockList();
        selectStock(defaultStocks[0]);
    } else if (data.action === 'close') {
        document.getElementById('stock-container').classList.add('hidden');
    }
});

function executeTrade(type) {
    const qty = parseInt(document.getElementById('trade-qty').value) || 1;
    fetch(`https://${GetParentResourceName()}/executeTrade`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            stockId: activeStock.id,
            action: type,
            quantity: qty,
            price: activeStock.price
        })
    });
}

function closeStock() {
    document.getElementById('stock-container').classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeStock();
});
