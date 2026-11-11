const resource='rp_tablet_job';
let state=null;
const $=id=>document.getElementById(id);
const post=(name,data={})=>fetch('https://'+resource+'/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).catch(()=>{});
const missionCatalog={
 police:[['Patrouille de secteur','Effectuez une patrouille préventive dans votre secteur.'],['Sécurisation d’une zone','Assurez une présence visible et sécurisez le périmètre.']],
 ambulance:[['Ronde de prévention','Effectuez une ronde de prévention et vérifiez les points de secours.'],['Intervention médicale','Préparez-vous à répondre à une demande d’assistance.']],
 firefighter:[['Inspection de sécurité','Effectuez une inspection préventive de votre secteur.'],['Préparation intervention','Vérifiez le matériel et préparez une intervention.']],
 mechanic:[['Contrôle atelier','Vérifiez les équipements et l’état de l’atelier.'],['Assistance dépannage','Préparez une mission d’assistance aux automobilistes.']],
 taxi:[['Course de transport','Prenez en charge une demande de transport.'],['Mise à disposition','Assurez une présence dans les zones fréquentées.']],
 security:[['Ronde de surveillance','Effectuez une ronde de surveillance de votre secteur.'],['Sécurisation de site','Assurez la sécurisation d’un site professionnel.']],
 delivery:[['Tournée de livraison','Préparez une tournée de livraison de colis.'],['Collecte de colis','Effectuez une collecte auprès des partenaires.']],
 garbage:[['Tournée de collecte','Préparez une tournée de collecte des déchets.'],['Contrôle de secteur','Vérifiez la propreté et les points de collecte.']]
};
function showTab(name){document.querySelectorAll('.page').forEach(p=>p.classList.toggle('active',p.id===name));document.querySelectorAll('.nav').forEach(b=>b.classList.toggle('active',b.dataset.tab===name));}
document.querySelectorAll('.nav').forEach(b=>b.addEventListener('click',()=>showTab(b.dataset.tab)));
$('close').addEventListener('click',()=>post('close'));
$('refresh').addEventListener('click',()=>post('refresh'));
$('duty-toggle').addEventListener('click',()=>post('toggleDuty'));
function render(data){
 state=data;
 $('job-title').textContent=data.job||'Tablette métier';
 $('job-name').textContent=data.job||'—';
 $('grade-name').textContent=data.grade||'—';
 $('grade-title').textContent=data.grade||'Bienvenue';
 $('team-count').textContent=(data.roster||[]).length;
 $('duty-label').textContent=data.duty?'En service':'Hors service';
 $('duty-toggle').textContent=data.duty?'Terminer mon service':'Prendre mon service';
 $('duty-toggle').classList.toggle('off',data.duty);
 $('roster').innerHTML='';
 (data.roster||[]).forEach(person=>{
  const row=document.createElement('div');row.className='person';
  const info=document.createElement('div');const name=document.createElement('b');name.textContent=person.name;
  const grade=document.createElement('small');grade.textContent=person.grade;info.append(name,grade);
  const status=document.createElement('span');status.className='status'+(person.duty?' on':'');status.textContent=person.duty?'En service':'Hors service';row.append(info,status);$('roster').append(row);
 });
 const current=data.mission;
 $('active-mission').innerHTML='';
 if(current){const card=document.createElement('div');card.className='mission-card';const info=document.createElement('div');const title=document.createElement('b');title.textContent='Mission en cours : '+current.title;const desc=document.createElement('p');desc.textContent=current.description;info.append(title,desc);const done=document.createElement('button');done.textContent='Clôturer';done.addEventListener('click',()=>post('finishMission'));card.append(info,done);$('active-mission').append(card);}
 $('mission-list').innerHTML='';
 const missions=missionCatalog[data.jobName]||[];
 missions.forEach(([title,description])=>{
  const card=document.createElement('div');card.className='mission-card';const info=document.createElement('div');const h=document.createElement('b');h.textContent=title;const p=document.createElement('p');p.textContent=description;info.append(h,p);const btn=document.createElement('button');btn.textContent=current?'Mission en cours':'Accepter';btn.disabled=!!current||!data.duty;btn.addEventListener('click',()=>post('startMission',{title,description}));card.append(info,btn);$('mission-list').append(card);
 });
 if(!missions.length){const empty=document.createElement('div');empty.className='note';empty.textContent='Aucune mission prédéfinie pour ce métier pour le moment.';$('mission-list').append(empty);}
 $('role-note').textContent=data.duty?'Vous êtes en service. Les actions sont soumises aux contrôles du module de votre métier.':'Prenez votre service pour accéder aux missions proposées.';
}
window.addEventListener('message',event=>{
 const data=event.data||{};
 if(data.action==='open'){ $('tablet').classList.remove('hidden');showTab('overview');render(data.data||{});}
 if(data.action==='update')render(data.data||{});
 if(data.action==='close')$('tablet').classList.add('hidden');
});
document.addEventListener('keydown',event=>{if(event.key==='Escape'){event.preventDefault();post('close');}});
