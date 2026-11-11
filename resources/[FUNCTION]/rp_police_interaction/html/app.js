const post=(name,data={})=>fetch('https://rp_police_interaction/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).catch(()=>{});
const panel=document.getElementById('panel');
let open=false;
function close(){panel.classList.add('hidden');open=false;}
document.getElementById('surrender').addEventListener('click',()=>{if(!open)return;post('surrender');close();});
document.getElementById('refuse').addEventListener('click',()=>{if(!open)return;post('refuse');close();});
window.addEventListener('message',event=>{
 const data=event.data||{};
 if(data.action==='open'){
  const item=data.data||{};
  document.getElementById('offence').textContent=item.label||'Infraction constatée';
  document.getElementById('officer').textContent=item.officer||'Agent LSPD';
  document.getElementById('severity').textContent=item.severity||'—';
  panel.classList.remove('hidden');open=true;
 }
 if(data.action==='close')close();
});
document.addEventListener('keydown',event=>{if(open){event.preventDefault();event.stopPropagation();if(event.key==='Escape')post('close');}});
