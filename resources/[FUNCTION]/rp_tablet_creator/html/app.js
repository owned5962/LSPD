const post=(name,data={})=>fetch('https://rp_tablet_creator/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).then(r=>r.json().catch(()=>({})));
const tablet=document.getElementById('tablet'),status=document.getElementById('status');
function close(){tablet.classList.add('hidden');post('close').catch(()=>{});}
function activateCreatorTab(tab){
    document.querySelectorAll('.creator-tab').forEach(item => item.classList.toggle('active', item.dataset.tab === tab));
    document.querySelectorAll('[data-tab-panel]').forEach(panel => { panel.hidden = panel.dataset.tabPanel !== tab; });
}
document.getElementById('close').addEventListener('click',close);
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!tablet.classList.contains('hidden')){e.preventDefault();close();}});
window.addEventListener('message',e=>{const d=e.data||{};if(d.action==='open'){tablet.classList.remove('hidden');activateCreatorTab('weather');document.getElementById('role').textContent=String(d.role||'CRÉATEUR').toUpperCase();status.textContent='Connecté · Contrôles autorisés';}else if(d.action==='close'){tablet.classList.add('hidden');}else if(d.action==='result'){status.textContent=d.message||'';status.style.color=d.success?'#86efac':'#fca5a5';}});
document.querySelectorAll('[data-weather]').forEach(button=>button.addEventListener('click',()=>post('setWorld',{weather:button.dataset.weather}).catch(()=>{status.textContent='Erreur de communication';})));
document.getElementById('apply-time').addEventListener('click',()=>post('setWorld',{hours:Number(document.getElementById('hours').value),minutes:Number(document.getElementById('minutes').value)}).catch(()=>{status.textContent='Erreur de communication';}));
document.getElementById('send').addEventListener('click',()=>{const message=document.getElementById('announcement').value.trim();if(!message){status.textContent='Saisissez une annonce avant de diffuser.';return;}post('broadcast',{message}).then(()=>{document.getElementById('announcement').value='';}).catch(()=>{status.textContent='Erreur de communication';});});


let creatorJobs = [], creatorBlips = [], creatorMapping = [], creatorProps = [];
let creatorJobGarages = [];
let editingJobGarageVehicles = [];

function selectedJobGarage() {
    return creatorJobGarages.find(item => item.job === document.getElementById('job-garage-job').value) || null;
}
function renderJobGarageVehicles() {
    const host = document.getElementById('job-garage-vehicle-list');
    const count = document.getElementById('job-garage-count');
    host.replaceChildren();
    count.value = editingJobGarageVehicles.length + ' / 20';
    if (!editingJobGarageVehicles.length) {
        host.textContent = 'Aucun véhicule ajouté à cette flotte.';
        return;
    }
    editingJobGarageVehicles.forEach((vehicle, index) => {
        const row = document.createElement('div');
        row.className = 'org-row';
        const label = document.createElement('span');
        label.textContent = vehicle.label + ' · ' + vehicle.model + ' · grade ' + vehicle.minGrade + '+';
        const remove = document.createElement('button');
        remove.type = 'button';
        remove.textContent = 'Retirer';
        remove.addEventListener('click', () => {
            editingJobGarageVehicles.splice(index, 1);
            renderJobGarageVehicles();
        });
        row.append(label, remove);
        host.append(row);
    });
}
function loadJobGarage(jobName) {
    const garage = creatorJobGarages.find(item => item.job === jobName);
    editingJobGarageVehicles = Array.isArray(garage?.vehicles) ? garage.vehicles.map(item => ({
        model: String(item.model || ''), label: String(item.label || item.model || ''),
        minGrade: Number(item.minGrade || 0)
    })) : [];
    document.getElementById('job-garage-status').textContent = garage
        ? 'Garage existant chargé. Coordonnées : ' + [garage.x, garage.y, garage.z].map(v => Number(v).toFixed(1)).join(', ')
        : 'Aucun garage configuré. Placez-vous au futur garage avant de sauvegarder.';
    renderJobGarageVehicles();
}
function renderJobGarages(rows) {
    creatorJobGarages = Array.isArray(rows) ? rows.map(item => {
        let vehicles = item.vehicles;
        if (typeof vehicles === 'string') { try { vehicles = JSON.parse(vehicles); } catch (_) { vehicles = []; } }
        return { ...item, vehicles: Array.isArray(vehicles) ? vehicles : [] };
    }) : [];
    const select = document.getElementById('job-garage-job');
    const previous = select.value;
    fillSelect(select, creatorJobs, 'name', 'label');
    if (creatorJobs.some(item => item.name === previous)) select.value = previous;
    loadJobGarage(select.value);
}
document.getElementById('job-garage-job').addEventListener('change', event => loadJobGarage(event.target.value));
document.getElementById('job-garage-add-vehicle').addEventListener('click', () => {
    const model = document.getElementById('job-garage-model').value.trim().toLowerCase();
    const label = document.getElementById('job-garage-label').value.trim();
    const minGrade = Number(document.getElementById('job-garage-grade').value);
    if (!/^[a-z0-9_]{3,50}$/.test(model) || label.length < 2 || label.length > 50
        || !Number.isInteger(minGrade) || minGrade < 0 || minGrade > 4) {
        creatorMessage('Vérifiez le modèle, le nom affiché et le grade minimum.');
        return;
    }
    if (editingJobGarageVehicles.length >= 20) { creatorMessage('Maximum 20 véhicules par flotte.'); return; }
    if (editingJobGarageVehicles.some(item => item.model === model)) { creatorMessage('Ce modèle est déjà dans la flotte.'); return; }
    editingJobGarageVehicles.push({ model, label, minGrade });
    document.getElementById('job-garage-model').value = '';
    document.getElementById('job-garage-label').value = '';
    renderJobGarageVehicles();
});
document.getElementById('job-garage-save').addEventListener('click', () => {
    const job = document.getElementById('job-garage-job').value;
    if (!job) { creatorMessage('Sélectionnez un métier.'); return; }
    if (!editingJobGarageVehicles.length) { creatorMessage('Ajoutez au moins un véhicule à la flotte.'); return; }
    post('saveJobGarage', { job, vehicles: editingJobGarageVehicles })
        .then(() => { document.getElementById('job-garage-status').textContent = 'Enregistrement demandé au serveur…'; })
        .catch(() => creatorMessage('Impossible de sauvegarder le garage métier.'));
});
document.getElementById('job-garage-delete').addEventListener('click', () => {
    const job = document.getElementById('job-garage-job').value;
    if (!job || !selectedJobGarage()) { creatorMessage('Aucun garage enregistré pour ce métier.'); return; }
    if (!window.confirm('Supprimer la configuration du garage de ' + job + ' ?')) return;
    post('deleteJobGarage', { job }).catch(() => creatorMessage('Impossible de supprimer le garage métier.'));
});

let creatorJobStorages = [];
let creatorStorageCatalog = [];
let editingJobStorageWeapons = [];

function selectedJobStorage() {
    return creatorJobStorages.find(item => item.job === document.getElementById('job-storage-job').value) || null;
}
function renderJobStorageWeapons() {
    const host = document.getElementById('job-storage-weapon-list');
    document.getElementById('job-storage-count').value = editingJobStorageWeapons.length + ' / 30';
    host.replaceChildren();
    if (!editingJobStorageWeapons.length) {
        host.textContent = 'Aucune arme configurée.';
        return;
    }
    editingJobStorageWeapons.forEach((weapon, index) => {
        const row = document.createElement('div');
        row.className = 'org-row';
        const item = creatorStorageCatalog.find(entry => entry.name === weapon.name);
        const label = document.createElement('span');
        label.textContent = (item?.label || weapon.name) + ' · grade ' + weapon.minGrade + '+';
        const remove = document.createElement('button');
        remove.type = 'button';
        remove.textContent = 'Retirer';
        remove.addEventListener('click', () => {
            editingJobStorageWeapons.splice(index, 1);
            renderJobStorageWeapons();
        });
        row.append(label, remove);
        host.append(row);
    });
}
function loadJobStorage(jobName) {
    const storage = creatorJobStorages.find(item => item.job === jobName);
    editingJobStorageWeapons = Array.isArray(storage?.armory_items) ? storage.armory_items.map(item => ({
        name: String(item.name || ''), minGrade: Number(item.minGrade || 0)
    })) : [];
    document.getElementById('job-storage-stash').checked = storage
        ? storage.stash_enabled === true || Number(storage.stash_enabled) === 1 : true;
    document.getElementById('job-storage-armory').checked = storage
        ? storage.armory_enabled === true || Number(storage.armory_enabled) === 1 : true;
    document.getElementById('job-storage-status').textContent = storage
        ? 'Configuration chargée. Position : ' + [storage.x, storage.y, storage.z].map(v => Number(v).toFixed(1)).join(', ')
        : 'Aucun coffre configuré. Placez-vous à son emplacement avant de sauvegarder.';
    renderJobStorageWeapons();
}
function renderJobStorages(rows, catalog) {
    creatorJobStorages = Array.isArray(rows) ? rows : [];
    creatorStorageCatalog = Array.isArray(catalog) ? catalog : [];
    const select = document.getElementById('job-storage-job');
    const previous = select.value;
    fillSelect(select, creatorJobs, 'name', 'label');
    if (creatorJobs.some(item => item.name === previous)) select.value = previous;
    const weaponSelect = document.getElementById('job-storage-weapon');
    fillSelect(weaponSelect, creatorStorageCatalog, 'name', 'label');
    loadJobStorage(select.value);
}
document.getElementById('job-storage-job').addEventListener('change', event => loadJobStorage(event.target.value));
document.getElementById('job-storage-add-weapon').addEventListener('click', () => {
    const name = document.getElementById('job-storage-weapon').value;
    const minGrade = Number(document.getElementById('job-storage-grade').value);
    if (!name || !Number.isInteger(minGrade) || minGrade < 0 || minGrade > 4) {
        creatorMessage('Choisissez une arme et un grade minimum valide.');
        return;
    }
    if (editingJobStorageWeapons.length >= 30) { creatorMessage('Maximum 30 armes autorisées.'); return; }
    if (editingJobStorageWeapons.some(item => item.name === name)) { creatorMessage('Cette arme est déjà configurée.'); return; }
    editingJobStorageWeapons.push({ name, minGrade });
    renderJobStorageWeapons();
});
document.getElementById('job-storage-save').addEventListener('click', () => {
    const job = document.getElementById('job-storage-job').value;
    const stashEnabled = document.getElementById('job-storage-stash').checked;
    const armoryEnabled = document.getElementById('job-storage-armory').checked;
    if (!job || (!stashEnabled && !armoryEnabled) || (armoryEnabled && !editingJobStorageWeapons.length)) {
        creatorMessage('Sélectionnez un métier et activez au moins un espace correctement configuré.');
        return;
    }
    post('saveJobStorage', { job, stashEnabled, armoryEnabled, armoryItems: editingJobStorageWeapons })
        .then(() => { document.getElementById('job-storage-status').textContent = 'Enregistrement demandé au serveur…'; })
        .catch(() => creatorMessage('Impossible de sauvegarder le coffre métier.'));
});
document.getElementById('job-storage-delete').addEventListener('click', () => {
    const job = document.getElementById('job-storage-job').value;
    if (!job || !selectedJobStorage()) { creatorMessage('Aucune configuration pour ce métier.'); return; }
    if (!window.confirm('Supprimer le coffre et l’armurerie de ' + job + ' ?')) return;
    post('deleteJobStorage', { job }).catch(() => creatorMessage('Impossible de supprimer la configuration.'));
});

function renderJobStorageHistory(data) {
    const host = document.getElementById('job-storage-history');
    host.replaceChildren();
    const entries = Array.isArray(data.entries) ? data.entries : [];
    if (!entries.length) {
        host.textContent = 'Aucun mouvement enregistré pour ' + String(data.job || 'ce métier') + '.';
        return;
    }
    entries.forEach(entry => {
        const row = document.createElement('div');
        row.className = 'org-row';
        const detail = document.createElement('span');
        const kind = entry.storage_type === 'armory' ? 'Armurerie' : 'Coffre';
        const action = entry.direction === 'deposit' ? 'Dépôt' : 'Retrait';
        const quantity = Math.max(0, Number(entry.item_count) || 0);
        const item = String(entry.item_name || 'Objet inconnu');
        const player = String(entry.player_name || 'Joueur inconnu');
        const timestamp = String(entry.created_at || '').replace('T', ' ').replace(/\.000Z$/, '');
        detail.textContent = '#' + String(entry.id) + ' · ' + timestamp + ' · ' + kind + ' · ' +
            action + ' · ' + item + ' ×' + quantity + ' · ' + player +
            ' (ID personnage ' + String(entry.character_id || '?') + ')';
        row.append(detail);
        host.append(row);
    });
}
document.getElementById('job-storage-history-refresh').addEventListener('click', () => {
    const job = document.getElementById('job-storage-job').value;
    if (!job) { creatorMessage('Sélectionnez un métier avant de consulter son historique.'); return; }
    document.getElementById('job-storage-history').textContent = 'Chargement de l’historique…';
    post('refreshJobStorageHistory', { job })
        .catch(() => { document.getElementById('job-storage-history').textContent = 'Erreur de communication.'; });
});
window.addEventListener('message', event => {
    const message = event.data || {};
    if (message.action === 'jobStorageHistory') renderJobStorageHistory(message.data || {});
});

function fillSelect(select, items, valueKey, labelKey) {
    select.replaceChildren();
    items.forEach(item => { const option=document.createElement('option'); option.value=item[valueKey]; option.textContent=item[labelKey] || item[valueKey]; select.append(option); });
}
function renderPropOptions() {
    const search=(document.getElementById('mapping-search')?.value||'').trim().toLowerCase();
    const filtered=creatorProps.filter(item=>item.model.toLowerCase().includes(search));
    const select=document.getElementById('mapping-prop');
    const previous=select.value;
    fillSelect(select,filtered,'model','label');
    if(filtered.some(item=>item.model===previous))select.value=previous;
    if(!filtered.length){const option=document.createElement('option');option.textContent='Aucun prop trouvé';option.value='';select.append(option);}
}
document.getElementById('mapping-search').addEventListener('input',renderPropOptions);
function loadBlipForJob(jobName) {
    const item=creatorBlips.find(row=>row.job===jobName);
    const pos=window.creatorPosition||{x:0,y:0,z:0};
    document.getElementById('blip-label').value=item?.label||creatorJobs.find(j=>j.name===jobName)?.label||jobName;
    document.getElementById('blip-x').value=item?.x??pos.x;
    document.getElementById('blip-y').value=item?.y??pos.y;
    document.getElementById('blip-z').value=item?.z??pos.z;
    document.getElementById('blip-sprite').value=item?.sprite??1;
    document.getElementById('blip-color').value=item?.color??3;
    document.getElementById('blip-scale').value=item?.scale??0.7;
    document.getElementById('blip-enabled').checked=item ? (item.enabled===true||Number(item.enabled)===1) : true;
    document.getElementById('blip-help').textContent=item?'Configuration existante chargée.':'Aucun blip enregistré pour ce métier.';
}
function renderMapping() {
    const host=document.getElementById('mapping-list');host.replaceChildren();
    if(!creatorMapping.length){host.textContent='Aucun objet de mapping enregistré.';return;}
    creatorMapping.forEach(item=>{
        const row=document.createElement('div');row.className='mapping-row';
        const label=document.createElement('span');label.textContent='#'+item.id+' · '+item.model;
        const del=document.createElement('button');del.textContent='Supprimer';del.addEventListener('click',()=>post('deleteProp',{id:item.id}).catch(()=>{status.textContent='Erreur de communication';}));
        row.append(label,del);host.append(row);
    });
}
window.addEventListener('message',e=>{
    const d=e.data||{};
    if(d.action==='toolsData'){
        creatorJobs=d.jobs||[];creatorBlips=d.blips||[];creatorMapping=d.mapping||[];window.creatorPosition=d.position||{x:0,y:0,z:0};
        const jobSelect=document.getElementById('blip-job');fillSelect(jobSelect,creatorJobs,'name','label');
        renderJobGarages(d.jobGarages || []);
        renderJobStorages(d.jobStorages || [], d.storageCatalog || []);
        creatorProps=Object.keys(d.catalog||{}).sort().map(model=>({model,label:model}));
        renderPropOptions();
        if(jobSelect.value)loadBlipForJob(jobSelect.value);
        renderMapping();
    } else if(d.action==='creatorAdminData'){
        renderCreatorAdminData(d.data||{});
    } else if(d.action==='mappingAdded'){
        if(d.item)creatorMapping.unshift(d.item);renderMapping();
    } else if(d.action==='mappingRemoved'){
        creatorMapping=creatorMapping.filter(item=>Number(item.id)!==Number(d.id));renderMapping();
    }
});
document.getElementById('place-prop').addEventListener('click',()=>{
    const model=document.getElementById('mapping-prop').value;if(!model)return;
    post('spawnProp',{model}).catch(()=>{status.textContent='Impossible de placer cet objet.';});
});
document.getElementById('blip-job').addEventListener('change',e=>loadBlipForJob(e.target.value));
document.getElementById('save-blip').addEventListener('click',()=>{
    const data={job:document.getElementById('blip-job').value,label:document.getElementById('blip-label').value.trim(),
        x:Number(document.getElementById('blip-x').value),y:Number(document.getElementById('blip-y').value),z:Number(document.getElementById('blip-z').value),
        sprite:Number(document.getElementById('blip-sprite').value),color:Number(document.getElementById('blip-color').value),
        scale:Number(document.getElementById('blip-scale').value),enabled:document.getElementById('blip-enabled').checked};
    if(!data.job||!data.label||![data.x,data.y,data.z,data.sprite,data.color,data.scale].every(Number.isFinite)){status.textContent='Complétez tous les champs du blip.';return;}
    post('saveJobBlip',data).catch(()=>{status.textContent='Erreur lors de la sauvegarde du blip.';});
});


// Creator server/player administration. All server mutations are revalidated in Lua.
let creatorPlayers = [];
let creatorItems = [];
let creatorModules = [];

function creatorMessage(message, success=false) {
    status.textContent = message;
    status.style.color = success ? '#86efac' : '#fca5a5';
}
function renderCreatorAdminData(data) {
    if (Array.isArray(data.jobs)) creatorJobs = data.jobs;
    creatorPlayers = Array.isArray(data.players) ? data.players : [];
    creatorItems = Array.isArray(data.items) ? data.items : [];
    creatorModules = Array.isArray(data.modules) ? data.modules : [];

    const serverName = document.getElementById('creator-server-name');
    const serverSlots = document.getElementById('creator-server-slots');
    if (serverName && data.settings) serverName.value = data.settings.name || 'Los Santos Stories';
    if (serverSlots && data.settings) serverSlots.value = Number(data.settings.slots || 64);
    const fuelPrice = document.getElementById('creator-fuel-price');
    const fuelConsumption = document.getElementById('creator-fuel-consumption');
    if (fuelPrice && data.settings) fuelPrice.value = Number(data.settings.fuelPrice || 6);
    if (fuelConsumption && data.settings) fuelConsumption.value = Number(data.settings.fuelConsumption || 2.5);

    const playerSelect = document.getElementById('creator-player');
    const selectedId = playerSelect.value;
    playerSelect.replaceChildren();
    creatorPlayers.forEach(player => {
        const option = document.createElement('option');
        option.value = String(player.id);
        option.textContent = (player.name || ('Joueur ' + player.id)) + ' · ID ' + player.id;
        playerSelect.append(option);
    });
    if (creatorPlayers.some(player => String(player.id) === selectedId)) playerSelect.value = selectedId;
    else if (creatorPlayers.length) playerSelect.value = String(creatorPlayers[0].id);

    const jobSelect = document.getElementById('creator-job');
    fillSelect(jobSelect, creatorJobs, 'name', 'label');
    const itemSelect = document.getElementById('creator-item');
    fillSelect(itemSelect, creatorItems, 'name', 'label');
    renderCreatorModules();
    renderCreatorJobGrades();
    loadCreatorPlayer();
}
function renderCreatorModules() {
    const host = document.getElementById('creator-module-list');
    if (!host) return;
    host.replaceChildren();
    if (!creatorModules.length) { host.textContent = 'Aucun module facultatif disponible.'; return; }
    creatorModules.forEach(module => {
        const row = document.createElement('div');
        row.className = 'module-row';
        const description = document.createElement('div');
        const name = document.createElement('strong');
        name.textContent = module.label || module.name;
        const state = document.createElement('small');
        state.textContent = module.name + ' · ' + (module.state || 'inconnu');
        description.append(name, state);
        const toggle = document.createElement('input');
        toggle.type = 'checkbox';
        toggle.checked = module.enabled === true;
        toggle.disabled = module.state === 'missing' || module.state === 'starting' || module.state === 'stopping';
        toggle.setAttribute('aria-label', 'Activer ' + (module.label || module.name));
        toggle.addEventListener('change', () => {
            toggle.disabled = true;
            post('setModuleState', { name: module.name, enabled: toggle.checked })
                .catch(() => { toggle.disabled = false; toggle.checked = !toggle.checked; creatorMessage('Impossible de contacter le serveur.'); });
        });
        row.append(description, toggle);
        host.append(row);
    });
}
function getSelectedCreatorPlayer() {
    const id = Number(document.getElementById('creator-player')?.value);
    return creatorPlayers.find(player => Number(player.id) === id) || null;
}
function loadCreatorPlayer() {
    const player = getSelectedCreatorPlayer();
    if (!player) return;
    document.getElementById('creator-firstname').value = player.firstname || '';
    document.getElementById('creator-lastname').value = player.lastname || '';
    document.getElementById('creator-age').value = Number(player.age || 25);
    document.getElementById('creator-role').value = player.group || 'user';
    document.getElementById('creator-skin').value = 'keep';
    document.getElementById('creator-gender').value = player.gender || 'm';
    document.getElementById('creator-cash').value = Number(player.cash || 0);
    document.getElementById('creator-bank').value = Number(player.bank || 0);
    document.getElementById('creator-job').value = player.job || 'unemployed';
    document.getElementById('creator-access-admin').checked = player.tablets?.admin !== false;
    document.getElementById('creator-access-anticheat').checked = player.tablets?.anticheat !== false;
    document.getElementById('creator-access-creator').checked = player.tablets?.creator !== false;
    renderCreatorJobGrades(player.grade);
}
function renderCreatorJobGrades(selectedGrade) {
    const select = document.getElementById('creator-job-grade');
    const job = creatorJobs.find(item => item.name === document.getElementById('creator-job').value);
    select.replaceChildren();
    const grades = Array.isArray(job?.grades) ? job.grades : [{ grade: 0, label: 'Grade 0' }];
    grades.forEach(item => {
        const option = document.createElement('option');
        option.value = String(item.grade);
        option.textContent = item.label || ('Grade ' + item.grade);
        select.append(option);
    });
    if (selectedGrade !== undefined && grades.some(item => Number(item.grade) === Number(selectedGrade))) {
        select.value = String(selectedGrade);
    }
}
document.getElementById('creator-player').addEventListener('change', loadCreatorPlayer);
document.getElementById('creator-job').addEventListener('change', () => renderCreatorJobGrades());
document.getElementById('creator-refresh').addEventListener('click', () => post('refreshTools').catch(() => creatorMessage('Actualisation impossible.')));
document.getElementById('creator-save-server').addEventListener('click', () => {
    const name = document.getElementById('creator-server-name').value.trim();
    const slots = Number(document.getElementById('creator-server-slots').value);
    if (name.length < 3 || !Number.isInteger(slots) || slots < 1 || slots > 1024) {
        creatorMessage('Nom du serveur ou nombre de slots invalide.'); return;
    }
    post('setServerSettings', { name, slots }).catch(() => creatorMessage('Erreur lors de la sauvegarde du serveur.'));
});
document.getElementById('creator-save-fuel').addEventListener('click', () => {
    const pricePerLitre = Number(document.getElementById('creator-fuel-price').value);
    const consumptionMultiplier = Number(document.getElementById('creator-fuel-consumption').value);
    if (!Number.isInteger(pricePerLitre) || pricePerLitre < 1 || pricePerLitre > 1000
        || !Number.isFinite(consumptionMultiplier) || consumptionMultiplier < 0.1 || consumptionMultiplier > 20) {
        creatorMessage('Prix du litre ou multiplicateur invalide.'); return;
    }
    post('setFuelSettings', { pricePerLitre, consumptionMultiplier })
        .then(() => post('refreshTools'))
        .catch(() => creatorMessage('Erreur lors de la sauvegarde des réglages carburant.'));
});
document.getElementById('creator-save-identity').addEventListener('click', () => {
    const player = getSelectedCreatorPlayer(); if (!player) { creatorMessage('Sélectionnez un joueur.'); return; }
    const data = {
        playerId: player.id,
        firstname: document.getElementById('creator-firstname').value.trim(),
        lastname: document.getElementById('creator-lastname').value.trim(),
        age: Number(document.getElementById('creator-age').value),
        group: document.getElementById('creator-role').value,
        skinPreset: document.getElementById('creator-skin').value
    };
    post('updatePlayerIdentity', data).catch(() => creatorMessage('Erreur lors de la modification de l’identité.'));
});
document.getElementById('creator-save-balances').addEventListener('click', () => {
    const player = getSelectedCreatorPlayer(); if (!player) { creatorMessage('Sélectionnez un joueur.'); return; }
    const cash = Number(document.getElementById('creator-cash').value);
    const bank = Number(document.getElementById('creator-bank').value);
    if (![cash, bank].every(value => Number.isInteger(value) && value >= 0 && value <= 100000000)) {
        creatorMessage('Les soldes doivent être des nombres entiers entre 0 et 100 000 000.'); return;
    }
    post('updatePlayerBalances', { playerId: player.id, cash, bank }).catch(() => creatorMessage('Erreur lors de la modification des soldes.'));
});
document.getElementById('creator-save-job').addEventListener('click', () => {
    const player = getSelectedCreatorPlayer(); if (!player) { creatorMessage('Sélectionnez un joueur.'); return; }
    post('updatePlayerJob', { playerId: player.id, jobName: document.getElementById('creator-job').value, grade: Number(document.getElementById('creator-job-grade').value) })
        .catch(() => creatorMessage('Erreur lors de la modification du métier.'));
});
function updateCreatorInventory(operation) {
    const player = getSelectedCreatorPlayer(); if (!player) { creatorMessage('Sélectionnez un joueur.'); return; }
    const count = Number(document.getElementById('creator-item-count').value);
    const itemName = document.getElementById('creator-item').value;
    if (!itemName || !Number.isInteger(count) || count < 1 || count > 1000) { creatorMessage('Objet ou quantité invalide.'); return; }
    post('updatePlayerInventory', { playerId: player.id, itemName, count, operation })
        .catch(() => creatorMessage('Erreur lors de la modification de l’inventaire.'));
}
document.getElementById('creator-item-add').addEventListener('click', () => updateCreatorInventory('add'));
document.getElementById('creator-item-remove').addEventListener('click', () => updateCreatorInventory('remove'));
document.querySelectorAll('.creator-tab').forEach(button => button.addEventListener('click', () => activateCreatorTab(button.dataset.tab)));
document.getElementById('creator-save-access').addEventListener('click', () => {
    const player = getSelectedCreatorPlayer(); if (!player) { creatorMessage('Sélectionnez un joueur.'); return; }
    post('updatePlayerAccess', {
        playerId: player.id,
        admin: document.getElementById('creator-access-admin').checked,
        anticheat: document.getElementById('creator-access-anticheat').checked,
        creator: document.getElementById('creator-access-creator').checked
    }).catch(() => creatorMessage('Erreur lors de la sauvegarde des accès.'));
});

 
// Forms for persistent server organizations.
let editingJobName = null;
let creatorCustomJobs = [];

function resetJobEditor() {
    editingJobName = null;
    document.getElementById('new-job-name').readOnly = false;
    document.getElementById('create-job').innerHTML = '<i class="fa-solid fa-plus"></i> Créer le métier';
    document.getElementById('cancel-job-edit').hidden = true;
    document.getElementById('new-job-name').value = '';
    document.getElementById('new-job-label').value = '';
    document.getElementById('new-job-category').value = 'commerce';
    document.getElementById('new-job-description').value = '';
    document.getElementById('new-job-whitelisted').checked = false;
    document.getElementById('new-job-capacity').value = '0';
    for (let grade = 0; grade <= 4; grade++) {
        document.getElementById('new-job-grade-' + grade).value = ['Débutant', 'Employé', 'Confirmé', 'Responsable', 'Directeur'][grade];
        document.getElementById('new-job-salary-' + grade).value = [200, 300, 400, 500, 650][grade];
    }
}

function readJobEditor() {
    const data = {
        name: document.getElementById('new-job-name').value.trim().toLowerCase(),
        label: document.getElementById('new-job-label').value.trim(),
        category: document.getElementById('new-job-category').value.trim().toLowerCase(),
        description: document.getElementById('new-job-description').value.trim(),
        whitelisted: document.getElementById('new-job-whitelisted').checked,
        maxEmployees: Number(document.getElementById('new-job-capacity').value),
        grades: {}
    };
    for (let grade = 0; grade <= 4; grade++) {
        data.grades[grade] = {
            label: document.getElementById('new-job-grade-' + grade).value.trim(),
            salary: Number(document.getElementById('new-job-salary-' + grade).value)
        };
    }
    if (!/^[a-z][a-z0-9_]{2,39}$/.test(data.name) || data.label.length < 2 || data.description.length < 3
        || data.category.length < 1 || data.category.length > 32 || !/^[a-z][a-z0-9_]*$/.test(data.category)
        || !Number.isInteger(data.maxEmployees) || data.maxEmployees < 0 || data.maxEmployees > 500
        || Object.values(data.grades).some(g => g.label.length < 2 || !Number.isInteger(g.salary) || g.salary < 0 || g.salary > 100000)) {
        creatorMessage('Vérifiez l’identifiant, la catégorie, la description et les cinq grades/salaires.'); return null;
    }
    return data;
}

function renderCreatorJobs(jobs) {
    creatorCustomJobs = Array.isArray(jobs) ? jobs : [];
    const host = document.getElementById('creator-job-list');
    host.replaceChildren();
    if (!creatorCustomJobs.length) {
        host.textContent = 'Aucun métier personnalisé créé pour le moment.';
        return;
    }
    creatorCustomJobs.forEach(job => {
        const row = document.createElement('div');
        row.className = 'org-row';
        const label = document.createElement('span');
        const capacity = Number(job.maxEmployees || 0) > 0 ? Number(job.maxEmployees) + ' employés max.' : 'Capacité illimitée';
        label.textContent = (job.label || job.name) + ' · ' + job.name + ' · ' + capacity;
        const edit = document.createElement('button');
        edit.type = 'button';
        edit.textContent = 'Modifier';
        edit.addEventListener('click', () => {
            editingJobName = job.name;
            document.getElementById('new-job-name').value = job.name;
            document.getElementById('new-job-name').readOnly = true;
            document.getElementById('new-job-label').value = job.label || '';
            document.getElementById('new-job-category').value = job.category || 'custom';
            document.getElementById('new-job-description').value = job.description || '';
            document.getElementById('new-job-whitelisted').checked = job.whitelisted === true;
            document.getElementById('new-job-capacity').value = Number(job.maxEmployees || 0);
            for (let grade = 0; grade <= 4; grade++) {
                const entry = job.grades?.[grade] || job.grades?.[String(grade)] || {};
                document.getElementById('new-job-grade-' + grade).value = entry.label || ('Grade ' + grade);
                document.getElementById('new-job-salary-' + grade).value = Number(entry.salary || 0);
            }
            document.getElementById('create-job').textContent = 'Enregistrer les modifications';
            document.getElementById('cancel-job-edit').hidden = false;
        });
        const remove = document.createElement('button');
        remove.type = 'button';
        remove.textContent = 'Supprimer';
        remove.addEventListener('click', () => {
            if (!window.confirm('Supprimer le métier ' + (job.label || job.name) + ' ? La suppression sera refusée si des personnages lui sont affectés ou si son compte bancaire contient un solde ou un historique.')) return;
            post('deleteJob', { name: job.name }).catch(() => creatorMessage('Impossible de supprimer le métier.'));
        });
        row.append(label, edit, remove);
        host.append(row);
    });
}

function submitNewJob() {
    const data = readJobEditor();
    if (!data) return;
    const action = editingJobName ? 'updateJob' : 'createJob';
    post(action, data).then(() => resetJobEditor()).catch(() => creatorMessage('Impossible de contacter le serveur.'));
}
document.getElementById('create-job').addEventListener('click', submitNewJob);
document.getElementById('cancel-job-edit').addEventListener('click', resetJobEditor);

let editingGangName = null;
function resetGangEditor() {
    editingGangName = null;
    document.getElementById('new-gang-name').readOnly = false;
    document.getElementById('create-gang').innerHTML = '<i class="fa-solid fa-plus"></i> Créer le gang';
    document.getElementById('cancel-gang-edit').hidden = true;
    document.getElementById('new-gang-name').value = '';
    document.getElementById('new-gang-label').value = '';
    document.getElementById('new-gang-color').value = '#22c55e';
    document.getElementById('new-gang-description').value = '';
}
function renderCreatorGangs(gangs) {
    const host = document.getElementById('creator-gang-list');
    host.replaceChildren();
    if (!Array.isArray(gangs) || gangs.length === 0) {
        host.textContent = 'Aucun gang créé pour le moment.'; return;
    }
    gangs.forEach(gang => {
        const row = document.createElement('div'); row.className = 'org-row';
        const swatch = document.createElement('span'); swatch.className = 'org-swatch';
        swatch.style.backgroundColor = /^#[0-9a-f]{6}$/i.test(gang.color || '') ? gang.color : '#64748b';
        const label = document.createElement('span'); label.textContent = (gang.label || gang.name) + ' · ' + gang.name;
        const edit = document.createElement('button'); edit.type = 'button'; edit.textContent = 'Modifier';
        edit.addEventListener('click', () => {
            editingGangName = gang.name;
            document.getElementById('new-gang-name').value = gang.name;
            document.getElementById('new-gang-name').readOnly = true;
            document.getElementById('new-gang-label').value = gang.label || '';
            document.getElementById('new-gang-color').value = gang.color || '#64748b';
            document.getElementById('new-gang-description').value = gang.description || '';
            document.getElementById('create-gang').textContent = 'Enregistrer les modifications';
            document.getElementById('cancel-gang-edit').hidden = false;
        });
        const remove = document.createElement('button'); remove.type = 'button'; remove.textContent = 'Supprimer';
        remove.addEventListener('click', () => {
            if (!window.confirm('Supprimer définitivement le gang ' + (gang.label || gang.name) + ' ?')) return;
            post('deleteGang', { name: gang.name }).catch(() => creatorMessage('Impossible de supprimer le gang.'));
        });
        row.append(swatch, label, edit, remove); host.append(row);
    });
}
document.getElementById('cancel-gang-edit').addEventListener('click', resetGangEditor);
document.getElementById('create-gang').addEventListener('click', () => {
    const data = {
        name: document.getElementById('new-gang-name').value.trim().toLowerCase(),
        label: document.getElementById('new-gang-label').value.trim(),
        color: document.getElementById('new-gang-color').value,
        description: document.getElementById('new-gang-description').value.trim()
    };
    if (!/^[a-z][a-z0-9_]{2,39}$/.test(data.name) || data.label.length < 2 || data.description.length < 3) {
        creatorMessage('Vérifiez l’identifiant, le nom et la description du gang.'); return;
    }
    const action = editingGangName ? 'updateGang' : 'createGang';
    post(action, data).then(() => resetGangEditor()).catch(() => creatorMessage('Impossible de contacter le serveur.'));
});
window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'organizationsData') renderCreatorGangs(data.gangs || []);
});
window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'customJobsData') renderCreatorJobs(data.jobs || []);
});

let creatorJobBankData = { jobs: [], accounts: [], history: [] };
function formatCreatorBankMoney(value) {
    const amount = Number(value);
    return new Intl.NumberFormat('fr-FR', { maximumFractionDigits: 0 }).format(Number.isFinite(amount) ? amount : 0) + ' $';
}
function renderCreatorJobBankSelection() {
    const jobName = document.getElementById('creator-bank-job').value;
    const account = creatorJobBankData.accounts.find(item => item.job === jobName);
    document.getElementById('creator-bank-balance').textContent = formatCreatorBankMoney(account?.balance || 0);
    document.getElementById('creator-bank-account-name').textContent = creatorJobBankData.jobs.find(item => item.name === jobName)?.label || jobName || 'Sélectionnez un métier';
    document.getElementById('creator-bank-allow-deposit').checked = account ? Number(account.allow_deposit) === 1 : true;
    document.getElementById('creator-bank-allow-withdraw').checked = account ? Number(account.allow_withdraw) === 1 : true;
    const host = document.getElementById('creator-bank-history');
    host.replaceChildren();
    const rows = creatorJobBankData.history.filter(item => item.job === jobName);
    if (!rows.length) { host.textContent = 'Aucune opération enregistrée pour ce métier.'; return; }
    rows.forEach(item => {
        const row = document.createElement('div'); row.className = 'creator-bank-history-row';
        const who = document.createElement('span');
        who.textContent = (item.player_name || 'Employé') + ' · ' + (item.transaction_type === 'deposit' ? 'Dépôt' : 'Retrait');
        const amount = document.createElement('strong');
        amount.textContent = (item.transaction_type === 'deposit' ? '+' : '−') + formatCreatorBankMoney(item.amount);
        const date = document.createElement('small');
        date.textContent = item.created_at ? String(item.created_at).replace('T', ' ').slice(0, 19) : '';
        const balance = document.createElement('small');
        balance.textContent = 'Solde après opération : ' + formatCreatorBankMoney(item.balance_after);
        row.append(who, amount, date, balance); host.append(row);
    });
}
function renderCreatorJobBank(data) {
    creatorJobBankData = data || { jobs: [], accounts: [], history: [] };
    const select = document.getElementById('creator-bank-job');
    const previous = select.value;
    fillSelect(select, creatorJobBankData.jobs || [], 'name', 'label');
    if ((creatorJobBankData.jobs || []).some(item => item.name === previous)) select.value = previous;
    renderCreatorJobBankSelection();
}
document.getElementById('creator-bank-job').addEventListener('change', renderCreatorJobBankSelection);
document.getElementById('creator-bank-refresh').addEventListener('click', () => post('refreshJobBank').catch(() => creatorMessage('Actualisation bancaire impossible.')));
document.getElementById('creator-bank-save').addEventListener('click', () => {
    const job = document.getElementById('creator-bank-job').value;
    if (!job) { creatorMessage('Sélectionnez un métier.'); return; }
    post('saveJobBankPermissions', {
        job,
        allowDeposit: document.getElementById('creator-bank-allow-deposit').checked,
        allowWithdraw: document.getElementById('creator-bank-allow-withdraw').checked
    }).catch(() => creatorMessage('Impossible de sauvegarder les autorisations bancaires.'));
});
window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'jobBankData') renderCreatorJobBank(data.data || {});
});


// Politique des armes déplacée dans la console Créateur.
let creatorWeaponPolicy = [];
function renderCreatorWeaponPolicy() {
    const root = document.getElementById('creator-weapon-list');
    if (!root) return;
    const query = (document.getElementById('creator-weapon-search')?.value || '').trim().toLowerCase();
    root.replaceChildren();
    const filtered = creatorWeaponPolicy.filter(item =>
        !query || (String(item.label || '') + ' ' + String(item.name || '')).toLowerCase().includes(query));
    const enabled = creatorWeaponPolicy.filter(item => item.enabled === true).length;
    const summary = document.getElementById('creator-weapon-summary');
    if (summary) summary.textContent = enabled + ' autorisées · ' + (creatorWeaponPolicy.length - enabled) + ' interdites';
    if (!filtered.length) { root.textContent = 'Aucune arme correspondante.'; return; }
    filtered.forEach(item => {
        const row = document.createElement('label');
        row.className = 'weapon-policy-row';
        const description = document.createElement('span');
        description.textContent = String(item.label || item.name) + ' · ' + String(item.name || '');
        const toggle = document.createElement('input');
        toggle.type = 'checkbox';
        toggle.checked = item.enabled === true;
        toggle.addEventListener('change', () => { item.enabled = toggle.checked; renderCreatorWeaponPolicy(); });
        row.append(description, toggle);
        root.append(row);
    });
}
window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'weaponPolicyData' || data.action === 'weaponPolicySaved') {
        creatorWeaponPolicy = Array.isArray(data.weaponPolicy) ? data.weaponPolicy.map(item => ({...item})) : [];
        renderCreatorWeaponPolicy();
    } else if (data.action === 'weaponPolicySaveFailed') {
        creatorMessage(String(data.message || 'Échec de sauvegarde de la politique des armes.'));
    }
});
document.getElementById('creator-weapon-search')?.addEventListener('input', renderCreatorWeaponPolicy);
document.getElementById('creator-weapon-save')?.addEventListener('click', () => {
    if (!creatorWeaponPolicy.length) { creatorMessage('Catalogue des armes indisponible.'); return; }
    const policy = {};
    creatorWeaponPolicy.forEach(item => { policy[item.name] = item.enabled === true; });
    post('saveWeaponPolicy', { policy })
        .then(() => creatorMessage('Enregistrement de la politique des armes demandé.', true))
        .catch(() => creatorMessage('Impossible de sauvegarder la politique des armes.'));
});
