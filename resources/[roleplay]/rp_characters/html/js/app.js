let currentTabIndex = 0;
const tabs = ['identity', 'appearance', 'spawn'];
let selectedColor = 0;
let selectedSpawn = 'airport';
let maxCharacters = 3;

const resourceName = () => window.GetParentResourceName ? window.GetParentResourceName() : 'rp_characters';
const postNui = (name, payload) => fetch(`https://${resourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload || {})
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openRegistration') {
        maxCharacters = data.maxCharacters || 3;
        document.getElementById('character-selection').classList.add('hidden');
        document.getElementById('registration-app').classList.remove('hidden');
        switchTab(0);
    } else if (data.action === 'closeRegistration') {
        document.getElementById('registration-app').classList.add('hidden');
    } else if (data.action === 'openCharacterSelection') {
        maxCharacters = data.maxCharacters || 3;
        renderCharacters(data.characters || []);
        document.getElementById('registration-app').classList.add('hidden');
        document.getElementById('character-selection').classList.remove('hidden');
    } else if (data.action === 'closeCharacterSelection') {
        document.getElementById('character-selection').classList.add('hidden');
    }
});

function renderCharacters(characters) {
    const list = document.getElementById('character-list');
    list.replaceChildren();
    const occupied = new Set();
    characters.forEach((character) => {
        occupied.add(Number(character.char_id));
        const card = document.createElement('button');
        card.type = 'button';
        card.className = 'character-card';
        const name = document.createElement('strong');
        name.textContent = `${character.firstname} ${character.lastname}`;
        const details = document.createElement('span');
        details.textContent = `Emplacement ${character.char_id} · ${character.job || 'Sans emploi'}`;
        card.append(name, details);
        card.addEventListener('click', () => postNui('selectCharacter', { slot: Number(character.char_id) }));
        list.appendChild(card);
    });
    for (let slot = 1; slot <= maxCharacters; slot++) {
        if (occupied.has(slot)) continue;
        const empty = document.createElement('div');
        empty.className = 'character-card empty';
        empty.textContent = `Emplacement ${slot} · Libre`;
        list.appendChild(empty);
    }
    const createButton = document.getElementById('create-character-btn');
    createButton.disabled = characters.length >= maxCharacters;
    createButton.textContent = characters.length >= maxCharacters ? 'Limite de personnages atteinte' : 'Créer un personnage';
}

document.getElementById('create-character-btn').addEventListener('click', () => {
    postNui('beginCreation').catch(() => {});
});

function switchTab(index) {
    currentTabIndex = index;
    const tabName = tabs[index];
    document.querySelectorAll('.tab-btn').forEach((btn, i) => btn.classList.toggle('active', i === index));
    document.querySelectorAll('.tab-content').forEach(content => content.classList.toggle('active', content.id === `${tabName}-tab`));
    const prev = document.getElementById('prev-btn');
    const next = document.getElementById('next-btn');
    const submit = document.getElementById('submit-btn');
    prev.disabled = index === 0;
    prev.style.opacity = index === 0 ? '0.5' : '1';
    next.classList.toggle('hidden', index === tabs.length - 1);
    submit.classList.toggle('hidden', index !== tabs.length - 1);
}

document.querySelectorAll('.tab-btn').forEach((btn, idx) => btn.addEventListener('click', () => switchTab(idx)));
document.getElementById('prev-btn').addEventListener('click', () => { if (currentTabIndex > 0) switchTab(currentTabIndex - 1); });
document.getElementById('next-btn').addEventListener('click', () => { if (currentTabIndex < tabs.length - 1) switchTab(currentTabIndex + 1); });
document.getElementById('height').addEventListener('input', e => document.getElementById('height-val').textContent = e.target.value);
document.getElementById('hair-style').addEventListener('input', e => document.getElementById('hair-val').textContent = e.target.value);

document.querySelectorAll('.color-dot').forEach(dot => dot.addEventListener('click', () => {
    document.querySelectorAll('.color-dot').forEach(d => d.classList.remove('active'));
    dot.classList.add('active');
    selectedColor = Number(dot.dataset.color);
}));
document.querySelectorAll('.spawn-card').forEach(card => card.addEventListener('click', () => {
    document.querySelectorAll('.spawn-card').forEach(c => c.classList.remove('active'));
    card.classList.add('active');
    selectedSpawn = card.dataset.spawn;
}));
document.getElementById('gender').addEventListener('change', e => {
    postNui('updateSkinPreview', { gender: e.target.value }).catch(() => {});
});

document.getElementById('creator-form').addEventListener('submit', e => {
    e.preventDefault();
    const payload = {
        firstname: document.getElementById('firstname').value.trim(),
        lastname: document.getElementById('lastname').value.trim(),
        dateofbirth: document.getElementById('dateofbirth').value,
        gender: document.getElementById('gender').value,
        height: Number(document.getElementById('height').value),
        spawnPoint: selectedSpawn,
        skin: {
            hairStyle: Number(document.getElementById('hair-style').value),
            hairColor: selectedColor,
            clothing: document.getElementById('clothing-style').value
        }
    };
    postNui('saveCharacter', payload).catch(() => {});
});
