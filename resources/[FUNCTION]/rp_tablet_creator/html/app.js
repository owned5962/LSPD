const post=(name,data={})=>fetch('https://rp_tablet_creator/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).then(r=>r.json().catch(()=>({})));
const tablet=document.getElementById('tablet'),status=document.getElementById('status');
function close(){tablet.classList.add('hidden');post('close').catch(()=>{});}
document.getElementById('close').addEventListener('click',close);
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!tablet.classList.contains('hidden')){e.preventDefault();close();}});
window.addEventListener('message',e=>{const d=e.data||{};if(d.action==='open'){tablet.classList.remove('hidden');document.getElementById('role').textContent=String(d.role||'CRÉATEUR').toUpperCase();status.textContent='Connecté · Contrôles autorisés';}else if(d.action==='close'){tablet.classList.add('hidden');}else if(d.action==='result'){status.textContent=d.message||'';status.style.color=d.success?'#86efac':'#fca5a5';}});
document.querySelectorAll('[data-weather]').forEach(button=>button.addEventListener('click',()=>post('setWorld',{weather:button.dataset.weather}).catch(()=>{status.textContent='Erreur de communication';})));
document.getElementById('apply-time').addEventListener('click',()=>post('setWorld',{hours:Number(document.getElementById('hours').value),minutes:Number(document.getElementById('minutes').value)}).catch(()=>{status.textContent='Erreur de communication';}));
document.getElementById('send').addEventListener('click',()=>{const message=document.getElementById('announcement').value.trim();if(!message){status.textContent='Saisissez une annonce avant de diffuser.';return;}post('broadcast',{message}).then(()=>{document.getElementById('announcement').value='';}).catch(()=>{status.textContent='Erreur de communication';});});


let creatorJobs = [], creatorBlips = [], creatorMapping = [];
function fillSelect(select, items, valueKey, labelKey) {
    select.replaceChildren();
    items.forEach(item => { const option=document.createElement('option'); option.value=item[valueKey]; option.textContent=item[labelKey] || item[valueKey]; select.append(option); });
}
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
        const props=Object.keys(d.catalog||{}).sort().map(model=>({model,label:model}));
        fillSelect(document.getElementById('mapping-prop'),props,'model','label');
        if(jobSelect.value)loadBlipForJob(jobSelect.value);
        renderMapping();
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
