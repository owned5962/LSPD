const post=(name,data={})=>fetch('https://rp_fuel/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).then(r=>r.json().catch(()=>({})));
const panel=document.getElementById('fuel-panel');
const litres=document.getElementById('litres');
const status=document.getElementById('status');
const payButton=document.getElementById('pay');
const closeButton=document.getElementById('close');
let price=6,busy=false,maxLitres=100,baseMs=2500,perLitreMs=700,isRefueling=false,progressFrame=0;
const money=n=>new Intl.NumberFormat('fr-FR').format(n)+' $';
const durationText=ms=>{const seconds=Math.max(0,Math.ceil(ms/1000));return seconds<60?seconds+' seconde'+(seconds>1?'s':''):Math.floor(seconds/60)+' min '+String(seconds%60).padStart(2,'0')+' s';};
function update(){
  const n=Number(litres.value)||1;
  document.getElementById('litres-value').textContent=n;
  document.getElementById('total-price').textContent=money(n*price);
  document.getElementById('estimated-time').textContent=durationText(baseMs+n*perLitreMs);
  payButton.disabled=busy||isRefueling||maxLitres<1||n>maxLitres;
  closeButton.disabled=busy||isRefueling;
}
function setProgress(percent,remaining){
  document.getElementById('progress-bar').style.width=Math.max(0,Math.min(100,percent))+'%';
  document.getElementById('progress-percent').textContent=Math.floor(percent)+' %';
  document.getElementById('countdown').textContent=durationText(remaining);
}
function startProgress(durationMs,n){
  isRefueling=true;
  busy=false;
  document.getElementById('purchase-section').classList.add('hidden');
  document.getElementById('payment-section').classList.add('hidden');
  document.getElementById('progress-section').classList.remove('hidden');
  document.getElementById('progress-litres').textContent=n+' L en cours de chargement';
  closeButton.disabled=true;
  status.textContent='Paiement accepté. La pompe délivre le carburant...';
  const start=performance.now();
  const tick=now=>{
    if(!isRefueling)return;
    const elapsed=now-start;
    const ratio=Math.min(1,elapsed/durationMs);
    setProgress(ratio*100,Math.max(0,durationMs-elapsed));
    if(ratio<1)progressFrame=requestAnimationFrame(tick);
  };
  cancelAnimationFrame(progressFrame);
  progressFrame=requestAnimationFrame(tick);
}
function resetProgress(){
  isRefueling=false;
  cancelAnimationFrame(progressFrame);
  closeButton.disabled=false;
  document.getElementById('progress-section').classList.add('hidden');
  document.getElementById('purchase-section').classList.remove('hidden');
  document.getElementById('payment-section').classList.remove('hidden');
}
litres.addEventListener('input',update);
window.addEventListener('message',e=>{
  const d=e.data||{};
  if(d.action==='openFuel'){
    resetProgress();
    price=Number(d.price)||6;
    baseMs=Number(d.baseFillMilliseconds)||2500;
    perLitreMs=Number(d.millisecondsPerLitre)||700;
    maxLitres=Math.max(0,Math.min(100,Number(d.maxLitres??(100-Number(d.fuel||0)))));
    litres.max=String(Math.max(1,maxLitres));
    litres.value=String(Math.max(1,Math.min(10,maxLitres)));
    document.getElementById('unit-price').textContent=money(price);
    document.getElementById('fuel-current').textContent=Math.round(Number(d.fuel)||0)+'%';
    document.getElementById('vehicle-name').textContent=String(d.vehicle||'Véhicule');
    status.textContent=maxLitres>0?'Choisissez la quantité puis confirmez le paiement.':'Le réservoir est déjà plein.';
    panel.classList.remove('hidden');
    update();
  }else if(d.action==='closeFuel'){
    resetProgress();
    panel.classList.add('hidden');
  }else if(d.action==='fuelingStarted'){
    startProgress(Number(d.durationMs)||0,Number(d.litres)||0);
  }else if(d.action==='purchaseFailed'){
    busy=false;
    closeButton.disabled=false;
    status.textContent=d.message||'Paiement refusé.';
    update();
  }else if(d.action==='fuelingCancelled'){
    resetProgress();
    busy=false;
    closeButton.disabled=false;
    status.textContent=d.message||'Ravitaillement annulé. Le remboursement est lancé.';
    update();
  }else if(d.action==='fuelPurchased'){
    isRefueling=false;
    cancelAnimationFrame(progressFrame);
    setProgress(100,0);
    document.getElementById('progress-litres').textContent='Réservoir mis à jour';
    status.textContent=d.message||'Ravitaillement terminé.';
    closeButton.disabled=false;
  }
});
function close(){
  if(isRefueling||busy)return;
  panel.classList.add('hidden');
  post('close').catch(()=>{});
}
closeButton.addEventListener('click',close);
document.addEventListener('keydown',e=>{
  if(e.key==='Escape'&&!panel.classList.contains('hidden')){
    e.preventDefault();
    if(!isRefueling&&!busy)close();
  }
});
payButton.addEventListener('click',()=>{
  if(busy||isRefueling||maxLitres<1)return;
  busy=true;
  payButton.disabled=true;
  closeButton.disabled=true;
  status.textContent='Vérification du solde et validation du paiement...';
  post('purchase',{litres:Number(litres.value),payment:document.getElementById('payment').value})
    .catch(()=>{busy=false;status.textContent='Erreur de communication avec le serveur.';update();});
});
