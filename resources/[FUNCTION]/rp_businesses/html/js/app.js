const tablet=document.getElementById('tablet');
const cashValue=document.getElementById('cash-value');
const buyButton=document.getElementById('buy');
const feedback=document.getElementById('feedback');
let purchasing=false;

function formatCash(value){return Math.max(0,Number(value)||0).toLocaleString('fr-FR')+' $'}
function closeTablet(){
    fetch('https://rp_businesses/closeAmmunation',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'}).catch(()=>{});
}
document.getElementById('close').addEventListener('click',closeTablet);
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!tablet.classList.contains('hidden')){event.preventDefault();closeTablet();}});
buyButton.addEventListener('click',()=>{
    if(purchasing)return;
    purchasing=true;
    buyButton.disabled=true;
    feedback.className='feedback';
    feedback.textContent='Validation du paiement…';
    fetch('https://rp_businesses/buyAmmunationPistol',{method:'POST',headers:{'Content-Type':'application/json'},body:'{}'})
        .catch(()=>{purchasing=false;buyButton.disabled=false;feedback.className='feedback error';feedback.textContent='Connexion au magasin impossible.';});
});
window.addEventListener('message',event=>{
    const data=event.data||{};
    if(data.action==='openAmmunation'){
        tablet.classList.remove('hidden');
        cashValue.textContent=formatCash(data.cash);
        feedback.className='feedback';
        feedback.textContent='Paiement en espèces uniquement.';
        purchasing=false;buyButton.disabled=false;
    }else if(data.action==='closeAmmunation'){
        tablet.classList.add('hidden');
        purchasing=false;buyButton.disabled=false;
    }else if(data.action==='purchaseResult'){
        purchasing=false;buyButton.disabled=false;
        cashValue.textContent=formatCash(data.cash);
        feedback.className='feedback '+(data.success?'success':'error');
        feedback.textContent=data.message||'';
    }
});
