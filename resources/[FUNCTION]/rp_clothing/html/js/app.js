const resource = 'rp_clothing';
let catalog = [];
let activeCategory = null;

const categoryIcons = {
    tops:'fa-shirt', undershirts:'fa-shirt', arms:'fa-mitten', pants:'fa-person', shoes:'fa-shoe-prints',
    bags:'fa-bag-shopping', accessories:'fa-link', decals:'fa-stamp', vests:'fa-shield-halved',
    hats:'fa-hat-cowboy', glasses:'fa-glasses', ears:'fa-gem', watches:'fa-clock', bracelets:'fa-ring'
};
const post = (name, data = {}) => fetch(`https://${resource}/${name}`, {
    method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(data)
});

function renderCategories() {
    const list = document.getElementById('category-list');
    list.replaceChildren();
    catalog.forEach(category => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'category-btn' + (activeCategory?.id === category.id ? ' active' : '');
        button.innerHTML = `<i class="fa-solid ${categoryIcons[category.id] || 'fa-shirt'}"></i><span></span><i class="fa-solid fa-chevron-right arrow"></i>`;
        button.querySelector('span').textContent = category.label;
        button.addEventListener('click', () => selectCategory(category.id));
        list.appendChild(button);
    });
}
function selectCategory(id) {
    activeCategory = catalog.find(item => item.id === id) || catalog[0];
    if (!activeCategory) return;
    renderCategories();
    document.getElementById('category-title').textContent = activeCategory.label;
    document.getElementById('item-count').textContent = `${activeCategory.count} modèles disponibles`;
    updateControls();
}
function updateControls() {
    if (!activeCategory) return;
    const isProp = activeCategory.kind === 'prop';
    const drawable = activeCategory.drawable;
    document.getElementById('drawable-value').textContent = isProp && drawable === 0 ? 'Aucun' : String(isProp ? drawable : drawable + 1);
    document.getElementById('drawable-total').textContent = `/ ${activeCategory.count}`;
    const range = document.getElementById('texture-range');
    range.max = Math.max(0, activeCategory.textureCount - 1);
    range.value = activeCategory.texture;
    document.getElementById('texture-value').textContent = String(activeCategory.texture);
    document.getElementById('texture-total').textContent = `${activeCategory.textureCount} variante(s)`;
}
async function preview() {
    if (!activeCategory) return;
    const result = await post('previewVariation', {
        kind:activeCategory.kind, index:activeCategory.index,
        drawable:activeCategory.drawable, texture:activeCategory.texture
    }).then(r => r.json()).catch(() => null);
    if (result?.textureCount) {
        activeCategory.textureCount = result.textureCount;
        activeCategory.texture = result.texture ?? activeCategory.texture;
        updateControls();
    }
}
function moveDrawable(delta) {
    if (!activeCategory) return;
    const max = Math.max(0, activeCategory.count - 1);
    activeCategory.drawable = Math.max(0, Math.min(max, activeCategory.drawable + delta));
    activeCategory.texture = 0;
    activeCategory.textureCount = 1;
    updateControls();
    preview();
}
document.getElementById('prev-item').addEventListener('click', () => moveDrawable(-1));
document.getElementById('next-item').addEventListener('click', () => moveDrawable(1));
document.getElementById('texture-range').addEventListener('input', event => {
    if (!activeCategory) return;
    activeCategory.texture = Number(event.target.value) || 0;
    document.getElementById('texture-value').textContent = String(activeCategory.texture);
    preview();
});
window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'open') {
        document.getElementById('clothing-wrapper').classList.remove('hidden');
        catalog = Array.isArray(data.catalog) ? data.catalog : [];
        activeCategory = null;
        selectCategory(catalog[0]?.id);
        post('requestOutfits');
    } else if (data.action === 'close') {
        document.getElementById('clothing-wrapper').classList.add('hidden');
    } else if (data.action === 'outfits') {
        renderSavedOutfits(Array.isArray(data.outfits) ? data.outfits : []);
    }
});
function renderSavedOutfits(outfits) {
    const list = document.getElementById('outfit-list');
    list.replaceChildren();
    if (!outfits.length) {
        const empty = document.createElement('p');
        empty.className = 'empty-outfits'; empty.textContent = 'Aucune tenue sauvegardée.';
        list.appendChild(empty); return;
    }
    outfits.forEach(outfit => {
        if (!outfit || !Number.isInteger(Number(outfit.id)) || typeof outfit.name !== 'string') return;
        const button = document.createElement('button');
        button.className = 'saved-outfit-btn'; button.type = 'button'; button.textContent = outfit.name;
        button.addEventListener('click', () => post('applySavedOutfit', {id:Number(outfit.id)}));
        list.appendChild(button);
    });
}
document.querySelectorAll('.preset-btn').forEach(button => button.addEventListener('click', () => {
    post('applyPreset', {outfit:button.dataset.outfit});
    document.getElementById('outfit-name').value = button.innerText.trim();
}));
document.getElementById('btn-save').addEventListener('click', async () => {
    const name = document.getElementById('outfit-name').value || 'Nouvelle tenue';
    await post('saveOutfit', {name});
    document.getElementById('clothing-wrapper').classList.add('hidden');
});
function closeShop() {
    document.getElementById('clothing-wrapper').classList.add('hidden');
    post('close');
}
document.getElementById('close-btn').addEventListener('click', closeShop);
document.addEventListener('keydown', event => {
    if (event.key === 'Escape') { event.preventDefault(); closeShop(); }
});
