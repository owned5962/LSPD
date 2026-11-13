const post=(name,data={})=>fetch('https://rp_tablet_creator/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).then(r=>r.json().catch(()=>({})));
const tablet=document.getElementById('tablet'),status=document.getElementById('status');
function close(){tablet.classList.add('hidden');post('close').catch(()=>{});}
function activateCreatorTab(tab){
    document.querySelectorAll('.creator-tab').forEach(item => item.classList.toggle('active', item.dataset.tab === tab));
    document.querySelectorAll('[data-tab-panel]').forEach(panel => { panel.hidden = panel.dataset.tabPanel !== tab; });
}
document.getElementById('close').addEventListener('click',close);
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!tablet.classList.contains('hidden')){e.preventDefault();close();}});
window.addEventListener('message',e=>{const d=e.data||{};if(d.action==='open'){tablet.classList.remove('hidden');activateCreatorTab('world');document.getElementById('role').textContent=String(d.role||'CRÉATEUR').toUpperCase();status.textContent='Connecté · Contrôles autorisés';}else if(d.action==='close'){tablet.classList.add('hidden');}else if(d.action==='result'){status.textContent=d.message||'';status.style.color=d.success?'#86efac':'#fca5a5';}});
document.querySelectorAll('[data-weather]').forEach(button=>button.addEventListener('click',()=>post('setWorld',{weather:button.dataset.weather}).catch(()=>{status.textContent='Erreur de communication';})));
document.getElementById('apply-time').addEventListener('click',()=>post('setWorld',{hours:Number(document.getElementById('hours').value),minutes:Number(document.getElementById('minutes').value)}).catch(()=>{status.textContent='Erreur de communication';}));
document.getElementById('send').addEventListener('click',()=>{const message=document.getElementById('announcement').value.trim();if(!message){status.textContent='Saisissez une annonce avant de diffuser.';return;}post('broadcast',{message}).then(()=>{document.getElementById('announcement').value='';}).catch(()=>{status.textContent='Erreur de communication';});});


let creatorJobs = [], creatorBlips = [], creatorMapping = [], creatorProps = [];
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
function submitNewJob() {
    const data = {
        name: document.getElementById('new-job-name').value.trim().toLowerCase(),
        label: document.getElementById('new-job-label').value.trim(),
        category: document.getElementById('new-job-category').value.trim().toLowerCase(),
        description: document.getElementById('new-job-description').value.trim(),
        whitelisted: document.getElementById('new-job-whitelisted').checked,
        grades: {}
    };
    for (let grade = 0; grade <= 4; grade++) {
        data.grades[grade] = {
            label: document.getElementById('new-job-grade-' + grade).value.trim(),
            salary: Number(document.getElementById('new-job-salary-' + grade).value)
        };
    }
    if (!/^[a-z][a-z0-9_]{2,39}$/.test(data.name) || data.label.length < 2 || data.description.length < 3
        || Object.values(data.grades).some(g => g.label.length < 2 || !Number.isInteger(g.salary) || g.salary < 0 || g.salary > 100000)) {
        creatorMessage('Vérifiez l’identifiant, la description et les cinq grades/salaires.'); return;
    }
    post('createJob', data).catch(() => creatorMessage('Impossible de contacter le serveur.'));
}
document.getElementById('create-job').addEventListener('click', submitNewJob);

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
        row.append(swatch, label); host.append(row);
    });
}
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
    post('createGang', data).catch(() => creatorMessage('Impossible de contacter le serveur.'));
});
window.addEventListener('message', event => {
    const data = event.data || {};
    if (data.action === 'organizationsData') renderCreatorGangs(data.gangs || []);
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
