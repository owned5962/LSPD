let currentTabIndex = 0;
const tabs = ['identity', 'heritage', 'face', 'appearance', 'spawn'];
let selectedColor = 0;
let selectedSpawn = 'airport';
let maxCharacters = 3;
let selectedCharacterSlot = null;
let characterSelectionPending = false;

function normalizeCharacterLimit(value) {
    const limit = Number(value);
    return Number.isInteger(limit) ? Math.max(1, Math.min(10, limit)) : 3;
}
const faceLabels = [
    'Largeur du nez','Hauteur du nez','Longueur du nez','Abaissement du nez','Pointe du nez','Décalage du nez',
    'Hauteur des sourcils','Profondeur des sourcils','Hauteur des pommettes','Largeur des pommettes',
    'Largeur des joues','Ouverture des yeux','Épaisseur des lèvres','Largeur de la mâchoire',
    'Forme de la mâchoire','Hauteur du menton','Longueur du menton','Largeur du menton',
    'Forme du menton','Épaisseur du cou'
];
const resourceName = () => window.GetParentResourceName ? window.GetParentResourceName() : 'rp_characters';
const postNui = (name, payload) => fetch(`https://${resourceName()}/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload || {})
});
const parentNames = ['Benjamin','Daniel','Joshua','Noah','John','Alex','Isaac','Evan','Ethan','Vincent','Angel','Diego','Adrian','Gabriel','Michael','Santiago','Kevin','Louis','Samuel','Anthony','Claude','Niko','John','Misty','Jez','Jodie','Miriam','Eunice','Debra','Emilia','Hannah','Aubrey','Jasmine','Gigi','Katherine','Chastity','Paige','Petunia','Leah','Kelly','Kimberly','Debra','Rea','Olivia','Sophia','Charlotte'];
function fillParents() {
    ['father','mother'].forEach((id) => {
        const select = document.getElementById(id);
        parentNames.forEach((name, index) => {
            const option = document.createElement('option');
            option.value = index; option.textContent = name;
            select.appendChild(option);
        });
    });
    document.getElementById('father').value = '0';
    document.getElementById('mother').value = '21';
}
function buildFaceSliders() {
    const container = document.getElementById('face-sliders');
    faceLabels.forEach((label, index) => {
        const group = document.createElement('div'); group.className = 'form-group';
        const caption = document.createElement('label'); caption.htmlFor = `face-${index}`;
        caption.textContent = `${label} : `;
        const value = document.createElement('span'); value.id = `face-val-${index}`; value.textContent = '0';
        caption.appendChild(value);
        const slider = document.createElement('input'); slider.type = 'range'; slider.id = `face-${index}`;
        slider.min = '-100'; slider.max = '100'; slider.value = '0';
        slider.addEventListener('input', () => { value.textContent = slider.value; sendAppearancePreview(); });
        group.append(caption, slider); container.appendChild(group);
    });
}
function getSkin() {
    const faceFeatures = {};
    faceLabels.forEach((_, index) => faceFeatures[String(index)] = Number(document.getElementById(`face-${index}`).value) / 100);
    const father = Number(document.getElementById('father').value);
    const mother = Number(document.getElementById('mother').value);
    const shapeMix = Number(document.getElementById('shape-mix').value) / 100;
    const skinMix = Number(document.getElementById('skin-mix').value) / 100;
    return {
        hairStyle: Number(document.getElementById('hair-style').value),
        hairColor: selectedColor,
        clothing: document.getElementById('clothing-style').value,
        eyeColor: Number(document.getElementById('eye-color').value),
        headBlend: { shapeFirst: father, shapeSecond: mother, shapeThird: 0, skinFirst: father, skinSecond: mother, skinThird: 0, shapeMix, skinMix, thirdMix: 0.0 },
        faceFeatures,
        components: Object.fromEntries([3,4,5,6,9,11].map(component => [String(component), { drawable: Number(document.getElementById('component-' + component).value), texture: 0 }])),
        props: Object.fromEntries([0,1,6,7].map(prop => [String(prop), { drawable: Number(document.getElementById('prop-' + prop).value), texture: 0 }])),
        overlays: {
            '1': { index: Number(document.getElementById('beard-style').value), opacity: Number(document.getElementById('beard-opacity').value) / 100, color: selectedColor },
            '2': { index: Number(document.getElementById('brow-style').value), opacity: Number(document.getElementById('brow-opacity').value) / 100, color: selectedColor }
        }
    };
}
function sendAppearancePreview() {
    ['shape-mix','skin-mix'].forEach(id => {
        document.getElementById(`${id}-val`).textContent = document.getElementById(id).value;
    });
    postNui('updateSkinPreview', { gender: document.getElementById('gender').value, skin: getSkin() }).catch(() => {});
}
window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openRegistration') {
        maxCharacters = normalizeCharacterLimit(data.maxCharacters);
        document.getElementById('character-selection').classList.add('hidden');
        document.getElementById('registration-app').classList.remove('hidden');
        switchTab(0); sendAppearancePreview();
    } else if (data.action === 'closeRegistration') {
        document.getElementById('registration-app').classList.add('hidden');
    } else if (data.action === 'openCharacterSelection') {
        maxCharacters = normalizeCharacterLimit(data.maxCharacters); renderCharacters(data.characters);
        document.getElementById('registration-app').classList.add('hidden');
        document.getElementById('character-selection').classList.remove('hidden');
    } else if (data.action === 'closeCharacterSelection') {
        document.getElementById('character-selection').classList.add('hidden');
    }
});
function renderCharacters(characters) {
    const list = document.getElementById('character-list');
    list.replaceChildren();
    selectedCharacterSlot = null;
    characterSelectionPending = false;

    const slots = new Map();
    const safeCharacters = Array.isArray(characters) ? characters : [];
    safeCharacters.forEach((character) => {
        const slot = Number(character && character.char_id);
        if (!Number.isInteger(slot) || slot < 1 || slot > maxCharacters || slots.has(slot)) return;
        slots.set(slot, character);
    });

    const countLabel = document.getElementById('character-count');
    if (countLabel) {
        countLabel.textContent = `${slots.size} personnage(s) créé(s) sur ${maxCharacters} · Sélectionnez une identité pour entrer en ville.`;
    }

    const enterButton = document.getElementById('enter-city-btn');
    enterButton.disabled = true;
    enterButton.textContent = 'Entrer en ville';

    slots.forEach((character, slot) => {
        const card = document.createElement('button');
        card.type = 'button';
        card.className = 'character-card';
        card.setAttribute('aria-pressed', 'false');

        const name = document.createElement('strong');
        const firstname = typeof character.firstname === 'string' ? character.firstname : 'Prénom';
        const lastname = typeof character.lastname === 'string' ? character.lastname : 'inconnu';
        name.textContent = `${firstname} ${lastname}`;
        const details = document.createElement('span');
        const job = typeof character.job === 'string' ? character.job : 'Sans emploi';
        details.textContent = `Emplacement ${slot} · ${job}`;
        card.append(name, details);

        card.addEventListener('click', () => {
            selectedCharacterSlot = slot;
            list.querySelectorAll('.character-card[aria-pressed]').forEach((item) => {
                item.classList.remove('selected');
                item.setAttribute('aria-pressed', 'false');
            });
            card.classList.add('selected');
            card.setAttribute('aria-pressed', 'true');
            enterButton.disabled = false;
        });
        list.appendChild(card);
    });

    for (let slot = 1; slot <= maxCharacters; slot++) {
        if (!slots.has(slot)) {
            const empty = document.createElement('div');
            empty.className = 'character-card empty';
            empty.textContent = `Emplacement ${slot} · Libre`;
            list.appendChild(empty);
        }
    }

    const createButton = document.getElementById('create-character-btn');
    createButton.disabled = slots.size >= maxCharacters;
    createButton.textContent = slots.size >= maxCharacters
        ? 'Limite de personnages atteinte'
        : (slots.size > 0 ? 'Créer un autre personnage' : 'Créer mon personnage');
}
document.getElementById('create-character-btn').addEventListener('click', () => postNui('beginCreation').catch(() => {}));
document.getElementById('enter-city-btn').addEventListener('click', () => {
    if (!Number.isInteger(selectedCharacterSlot) || characterSelectionPending) return;

    characterSelectionPending = true;
    const button = document.getElementById('enter-city-btn');
    button.disabled = true;
    button.textContent = 'Chargement du personnage…';

    postNui('selectCharacter', { slot: selectedCharacterSlot }).catch(() => {
        characterSelectionPending = false;
        button.disabled = false;
        button.textContent = 'Entrer en ville';
    });

    // The server performs the database lookup asynchronously. Avoid duplicate
    // requests while still allowing a retry if the server rejects the selection.
    window.setTimeout(() => {
        if (characterSelectionPending && document.getElementById('character-selection') &&
            !document.getElementById('character-selection').classList.contains('hidden')) {
            characterSelectionPending = false;
            button.disabled = selectedCharacterSlot === null;
            button.textContent = 'Entrer en ville';
        }
    }, 5000);
});
function switchTab(index) {
    currentTabIndex = index; const tabName = tabs[index];
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.toggle('active', btn.dataset.tab === tabName));
    document.querySelectorAll('.tab-content').forEach(content => content.classList.toggle('active', content.id === `${tabName}-tab`));
    document.getElementById('prev-btn').disabled = index === 0;
    document.getElementById('prev-btn').style.opacity = index === 0 ? '0.5' : '1';
    document.getElementById('next-btn').classList.toggle('hidden', index === tabs.length - 1);
    document.getElementById('submit-btn').classList.toggle('hidden', index !== tabs.length - 1);
}
document.querySelectorAll('.tab-btn').forEach(btn => btn.addEventListener('click', () => switchTab(tabs.indexOf(btn.dataset.tab))));
document.getElementById('prev-btn').addEventListener('click', () => { if (currentTabIndex > 0) switchTab(currentTabIndex - 1); });
document.getElementById('next-btn').addEventListener('click', () => { if (currentTabIndex < tabs.length - 1) switchTab(currentTabIndex + 1); });
document.getElementById('height').addEventListener('input', e => document.getElementById('height-val').textContent = e.target.value);
document.getElementById('hair-style').addEventListener('input', e => { document.getElementById('hair-val').textContent = e.target.value; sendAppearancePreview(); });
document.querySelectorAll('.color-dot').forEach(dot => dot.addEventListener('click', () => {
    document.querySelectorAll('.color-dot').forEach(d => d.classList.remove('active'));
    dot.classList.add('active'); selectedColor = Number(dot.dataset.color); sendAppearancePreview();
}));
document.querySelectorAll('.spawn-card').forEach(card => card.addEventListener('click', () => {
    document.querySelectorAll('.spawn-card').forEach(c => c.classList.remove('active'));
    card.classList.add('active'); selectedSpawn = card.dataset.spawn;
}));
['gender','clothing-style','father','mother','shape-mix','skin-mix','eye-color','brow-style','beard-style','brow-opacity','beard-opacity','component-3','component-4','component-5','component-6','component-9','component-11','prop-0','prop-1','prop-6','prop-7'].forEach(id => {
    document.getElementById(id).addEventListener('input', sendAppearancePreview);
    document.getElementById(id).addEventListener('change', sendAppearancePreview);
});
document.getElementById('creator-form').addEventListener('submit', e => {
    e.preventDefault();
    postNui('saveCharacter', {
        firstname: document.getElementById('firstname').value.trim(),
        lastname: document.getElementById('lastname').value.trim(),
        dateofbirth: document.getElementById('dateofbirth').value.split('/').reverse().join('-'),
        gender: document.getElementById('gender').value,
        height: Number(document.getElementById('height').value),
        spawnPoint: selectedSpawn, skin: getSkin()
    }).catch(() => {});
});
fillParents(); buildFaceSliders();
document.getElementById('dateofbirth').addEventListener('input', event => {
    const digits = event.target.value.replace(/[^0-9]/g, '').slice(0, 8);
    event.target.value = digits.length > 4 ? digits.slice(0, 2) + '/' + digits.slice(2, 4) + '/' + digits.slice(4) : digits.length > 2 ? digits.slice(0, 2) + '/' + digits.slice(2) : digits;
});
