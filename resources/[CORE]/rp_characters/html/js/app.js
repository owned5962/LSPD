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
const resourceName = () => (window.GetParentResourceName ? window.GetParentResourceName() : 'rp_characters');
const postNui = (name, payload) => fetch(`https://${resourceName()}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload || {})
}).then(async (response) => {
    if (!response.ok) throw new Error(`NUI request failed: ${name} (${response.status})`);
    try { return await response.json(); } catch (_) { return {}; }
});
const parentNames = ['Benjamin','Daniel','Joshua','Noah','John','Alex','Isaac','Evan','Ethan','Vincent','Angel','Diego','Adrian','Gabriel','Michael','Santiago','Kevin','Louis','Samuel','Anthony','Claude','Niko','John','Misty','Jez','Jodie','Miriam','Eunice','Debra','Emilia','Hannah','Aubrey','Jasmine','Gigi','Katherine','Chastity','Paige','Petunia','Leah','Kelly','Kimberly','Debra','Rea','Olivia','Sophia','Charlotte'];

function fillParents() {
    ['father','mother'].forEach((id) => {
        const select = document.getElementById(id);
        if (!select) return;
        select.innerHTML = '';
        parentNames.forEach((name, index) => {
            const option = document.createElement('option');
            option.value = String(index);
            option.textContent = name;
            select.appendChild(option);
        });
    });
    const father = document.getElementById('father');
    const mother = document.getElementById('mother');
    if (father) father.value = '0';
    if (mother) mother.value = '21';
}

function buildFaceSliders() {
    const container = document.getElementById('face-sliders');
    if (!container) return;
    container.innerHTML = '';
    faceLabels.forEach((label, index) => {
        const group = document.createElement('div');
        group.className = 'form-group';
        const caption = document.createElement('label');
        caption.htmlFor = `face-${index}`;
        caption.textContent = `${label} : `;
        const value = document.createElement('span');
        value.id = `face-val-${index}`;
        value.textContent = '0';
        caption.appendChild(value);
        const slider = document.createElement('input');
        slider.type = 'range';
        slider.id = `face-${index}`;
        slider.min = '-100';
        slider.max = '100';
        slider.value = '0';
        slider.addEventListener('input', () => {
            value.textContent = slider.value;
            sendAppearancePreview();
        });
        group.append(caption, slider);
        container.appendChild(group);
    });
}

function elVal(id, fallback) {
    const el = document.getElementById(id);
    if (!el) return fallback;
    return el.value;
}

function getSkin() {
    try {
        const faceFeatures = {};
        faceLabels.forEach((_, index) => {
            const node = document.getElementById(`face-${index}`);
            faceFeatures[String(index)] = node ? Number(node.value) / 100 : 0;
        });
        const father = Number(elVal('father', '0'));
        const mother = Number(elVal('mother', '21'));
        const shapeMix = Number(elVal('shape-mix', '50')) / 100;
        const skinMix = Number(elVal('skin-mix', '50')) / 100;
        return {
            hairStyle: Number(elVal('hair-style', '4')),
            hairColor: selectedColor || 0,
            clothing: elVal('clothing-style', 'casual'),
            eyeColor: Number(elVal('eye-color', '0')),
            headBlend: {
                shapeFirst: father, shapeSecond: mother, shapeThird: 0,
                skinFirst: father, skinSecond: mother, skinThird: 0,
                shapeMix, skinMix, thirdMix: 0.0
            },
            faceFeatures,
            components: Object.fromEntries([3,4,5,6,9,11].map(component => [
                String(component),
                { drawable: Number(elVal('component-' + component, '0')), texture: 0 }
            ])),
            props: Object.fromEntries([0,1,6,7].map(prop => [
                String(prop),
                { drawable: Number(elVal('prop-' + prop, '-1')), texture: 0 }
            ])),
            overlays: {
                '1': { index: Number(elVal('beard-style', '0')), opacity: Number(elVal('beard-opacity', '100')) / 100, color: selectedColor },
                '2': { index: Number(elVal('brow-style', '0')), opacity: Number(elVal('brow-opacity', '100')) / 100, color: selectedColor }
            }
        };
    } catch (error) {
        console.error('[rp_characters] getSkin failed', error);
        return { hairStyle: 4, hairColor: 0, clothing: 'casual', eyeColor: 0 };
    }
}

let previewTimer = null;
function sendAppearancePreview() {
    ['shape-mix','skin-mix'].forEach(id => {
        const valNode = document.getElementById(`${id}-val`);
        const inputNode = document.getElementById(id);
        if (valNode && inputNode) valNode.textContent = inputNode.value;
    });
    if (previewTimer !== null) window.clearTimeout(previewTimer);
    previewTimer = window.setTimeout(() => {
        previewTimer = null;
        postNui('updateSkinPreview', {
            gender: elVal('gender', 'm'),
            skin: getSkin()
        }).catch((err) => console.warn('[rp_characters] preview failed', err));
    }, 50);
}

function showCreatorError(message) {
    const submitButton = document.getElementById('submit-btn');
    if (submitButton) {
        submitButton.disabled = false;
        submitButton.textContent = 'Réessayer la création';
        submitButton.dataset.pending = 'false';
        submitButton.classList.remove('hidden');
    }
    let box = document.getElementById('creator-error');
    if (!box) {
        box = document.createElement('div');
        box.id = 'creator-error';
        box.style.cssText = 'margin:10px 22px;padding:10px 12px;border-radius:10px;background:rgba(239,68,68,0.15);border:1px solid rgba(239,68,68,0.4);color:#fecaca;font-size:12px;font-weight:700;';
        const form = document.getElementById('creator-form');
        if (form) form.insertBefore(box, form.firstChild);
    }
    box.textContent = message || 'La création a échoué.';
    box.classList.remove('hidden');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'openRegistration') {
        maxCharacters = normalizeCharacterLimit(data.maxCharacters);
        const sel = document.getElementById('character-selection');
        const reg = document.getElementById('registration-app');
        if (sel) sel.classList.add('hidden');
        if (reg) reg.classList.remove('hidden');
        switchTab(0);
        sendAppearancePreview();
    } else if (data.action === 'closeRegistration') {
        const reg = document.getElementById('registration-app');
        if (reg) reg.classList.add('hidden');
        const submitButton = document.getElementById('submit-btn');
        if (submitButton) {
            submitButton.dataset.pending = 'false';
            submitButton.disabled = false;
            submitButton.textContent = 'Confirmer & Créer';
        }
    } else if (data.action === 'openCharacterSelection') {
        maxCharacters = normalizeCharacterLimit(data.maxCharacters);
        renderCharacters(data.characters);
        const reg = document.getElementById('registration-app');
        const sel = document.getElementById('character-selection');
        if (reg) reg.classList.add('hidden');
        if (sel) sel.classList.remove('hidden');
    } else if (data.action === 'closeCharacterSelection') {
        const sel = document.getElementById('character-selection');
        if (sel) sel.classList.add('hidden');
    } else if (data.action === 'creationResult') {
        if (data.ok === false) {
            showCreatorError((data && data.message) ? String(data.message) : 'La création a échoué.');
        }
    }
});

function renderCharacters(characters) {
    const list = document.getElementById('character-list');
    if (!list) return;
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
    if (enterButton) {
        enterButton.disabled = true;
        enterButton.textContent = 'Entrer en ville';
    }
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
            if (enterButton) enterButton.disabled = false;
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
    if (createButton) {
        createButton.disabled = slots.size >= maxCharacters;
        createButton.textContent = slots.size >= maxCharacters
            ? 'Limite de personnages atteinte'
            : (slots.size > 0 ? 'Créer un autre personnage' : 'Créer mon personnage');
    }
}

function switchTab(index) {
    currentTabIndex = Math.max(0, Math.min(tabs.length - 1, index));
    const tabName = tabs[currentTabIndex];
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tabName);
    });
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.toggle('active', content.id === `${tabName}-tab`);
    });
    const prev = document.getElementById('prev-btn');
    const next = document.getElementById('next-btn');
    const submit = document.getElementById('submit-btn');
    if (prev) {
        prev.disabled = currentTabIndex === 0;
        prev.style.opacity = currentTabIndex === 0 ? '0.5' : '1';
    }
    if (next) next.classList.toggle('hidden', currentTabIndex === tabs.length - 1);
    if (submit) {
        const onLast = currentTabIndex === tabs.length - 1;
        submit.classList.toggle('hidden', !onLast);
        if (onLast && submit.dataset.pending !== 'true') {
            submit.disabled = false;
            if (submit.textContent === 'Enregistrement…') submit.textContent = 'Confirmer & Créer';
        }
    }
}

function bindUi() {
    const createBtn = document.getElementById('create-character-btn');
    if (createBtn) createBtn.addEventListener('click', () => postNui('beginCreation').catch(() => {}));

    const rotL = document.getElementById('rotate-character-left');
    const rotR = document.getElementById('rotate-character-right');
    if (rotL) rotL.addEventListener('click', () => postNui('rotateCharacter', { direction: -1 }).catch(() => {}));
    if (rotR) rotR.addEventListener('click', () => postNui('rotateCharacter', { direction: 1 }).catch(() => {}));

    const enterBtn = document.getElementById('enter-city-btn');
    if (enterBtn) enterBtn.addEventListener('click', () => {
        if (!Number.isInteger(selectedCharacterSlot) || characterSelectionPending) return;
        characterSelectionPending = true;
        enterBtn.disabled = true;
        enterBtn.textContent = 'Chargement du personnage…';
        postNui('selectCharacter', { slot: selectedCharacterSlot }).catch(() => {
            characterSelectionPending = false;
            enterBtn.disabled = false;
            enterBtn.textContent = 'Entrer en ville';
        });
        window.setTimeout(() => {
            const sel = document.getElementById('character-selection');
            if (characterSelectionPending && sel && !sel.classList.contains('hidden')) {
                characterSelectionPending = false;
                enterBtn.disabled = selectedCharacterSlot === null;
                enterBtn.textContent = 'Entrer en ville';
            }
        }, 8000);
    });

    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => switchTab(tabs.indexOf(btn.dataset.tab)));
    });

    const prevBtn = document.getElementById('prev-btn');
    const nextBtn = document.getElementById('next-btn');
    if (prevBtn) prevBtn.addEventListener('click', () => { if (currentTabIndex > 0) switchTab(currentTabIndex - 1); });
    if (nextBtn) nextBtn.addEventListener('click', () => { if (currentTabIndex < tabs.length - 1) switchTab(currentTabIndex + 1); });

    const heightInput = document.getElementById('height');
    if (heightInput) heightInput.addEventListener('input', e => {
        const n = document.getElementById('height-val');
        if (n) n.textContent = e.target.value;
    });

    const hairInput = document.getElementById('hair-style');
    if (hairInput) hairInput.addEventListener('input', e => {
        const n = document.getElementById('hair-val');
        if (n) n.textContent = e.target.value;
        sendAppearancePreview();
    });

    document.querySelectorAll('.color-dot').forEach(dot => dot.addEventListener('click', () => {
        document.querySelectorAll('.color-dot').forEach(d => d.classList.remove('active'));
        dot.classList.add('active');
        selectedColor = Number(dot.dataset.color) || 0;
        sendAppearancePreview();
    }));

    document.querySelectorAll('.spawn-card').forEach(card => card.addEventListener('click', () => {
        document.querySelectorAll('.spawn-card').forEach(c => c.classList.remove('active'));
        card.classList.add('active');
        selectedSpawn = card.dataset.spawn || 'airport';
    }));

    ['gender','clothing-style','father','mother','shape-mix','skin-mix','eye-color','brow-style','beard-style','brow-opacity','beard-opacity','component-3','component-4','component-5','component-6','component-9','component-11','prop-0','prop-1','prop-6','prop-7'].forEach(id => {
        const node = document.getElementById(id);
        if (!node) return;
        node.addEventListener('input', sendAppearancePreview);
        node.addEventListener('change', sendAppearancePreview);
    });

    const form = document.getElementById('creator-form');
    if (form) {
        form.addEventListener('submit', (e) => {
            e.preventDefault();
            e.stopPropagation();
            const errBox = document.getElementById('creator-error');
            if (errBox) {
                errBox.textContent = '';
                errBox.classList.add('hidden');
            }

            const dobRaw = (elVal('dateofbirth', '') || '').trim();
            const dobDigits = dobRaw.replace(/[^0-9]/g, '');
            if (dobDigits.length === 8) {
                const dobEl = document.getElementById('dateofbirth');
                if (dobEl) dobEl.value = dobDigits.slice(0,2)+'/'+dobDigits.slice(2,4)+'/'+dobDigits.slice(4);
            }

            if (typeof form.reportValidity === 'function' && !form.reportValidity()) {
                showCreatorError('Vérifiez les champs obligatoires (prénom, nom, date de naissance).');
                return;
            }

            const firstname = elVal('firstname', '').trim();
            const lastname = elVal('lastname', '').trim();
            if (firstname.length < 2 || lastname.length < 2) {
                showCreatorError('Prénom et nom doivent contenir au moins 2 caractères.');
                return;
            }

            const submitButton = document.getElementById('submit-btn');
            if (!submitButton) {
                console.error('[rp_characters] submit-btn missing from DOM');
                return;
            }
            if (submitButton.dataset.pending === 'true') return;

            submitButton.dataset.pending = 'true';
            submitButton.disabled = true;
            submitButton.textContent = 'Enregistrement…';
            submitButton.classList.remove('hidden');

            const payload = {
                firstname,
                lastname,
                dateofbirth: elVal('dateofbirth', '01/01/1990').split('/').reverse().join('-'),
                gender: elVal('gender', 'm'),
                height: Number(elVal('height', '175')) || 175,
                spawnPoint: selectedSpawn || 'airport',
                skin: getSkin()
            };

            console.log('[rp_characters] submitting character', payload.firstname, payload.lastname);

            postNui('saveCharacter', payload).then((result) => {
                if (result && result.status === 'error') {
                    throw new Error('Character submission rejected by client callback');
                }
                // Success path: server will close NUI and spawn. Keep button locked briefly.
                window.setTimeout(() => {
                    if (submitButton.dataset.pending === 'true') {
                        // Still pending after 12s → allow retry
                        submitButton.dataset.pending = 'false';
                        submitButton.disabled = false;
                        submitButton.textContent = 'Réessayer la création';
                        showCreatorError('Aucune réponse du serveur. Vérifiez la console F8 / FXServer puis réessayez.');
                    }
                }, 12000);
            }).catch((err) => {
                console.error('[rp_characters] saveCharacter failed', err);
                submitButton.dataset.pending = 'false';
                submitButton.disabled = false;
                submitButton.textContent = 'Réessayer la création';
                showCreatorError('Échec de l’envoi NUI. Ouvrez F8 et regardez les erreurs client.');
            });
        });
    }

    // Direct click fallback if form submit is blocked by browser/CEF quirks
    const submitBtn = document.getElementById('submit-btn');
    if (submitBtn) {
        submitBtn.addEventListener('click', (e) => {
            // Let the form submit handler run; this ensures the button is clickable even if type=submit is ignored.
            if (submitBtn.dataset.pending === 'true') {
                e.preventDefault();
                return;
            }
            const formEl = document.getElementById('creator-form');
            if (formEl && typeof formEl.requestSubmit === 'function') {
                // requestSubmit triggers the submit event with validation
                // Avoid double-fire if the click already bubbles to form
            }
        });
    }

    const dob = document.getElementById('dateofbirth');
    if (dob) dob.addEventListener('input', event => {
        const digits = event.target.value.replace(/[^0-9]/g, '').slice(0, 8);
        event.target.value = digits.length > 4
            ? digits.slice(0, 2) + '/' + digits.slice(2, 4) + '/' + digits.slice(4)
            : digits.length > 2
                ? digits.slice(0, 2) + '/' + digits.slice(2)
                : digits;
    });
}

// Boot
fillParents();
buildFaceSliders();
bindUi();
switchTab(0);
console.log('[rp_characters] NUI app ready');
