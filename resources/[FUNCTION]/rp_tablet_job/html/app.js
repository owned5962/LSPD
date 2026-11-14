const resource = 'rp_tablet_job';
let state = null;
let policeAlerts = [];
let jobBankSubmitting = false;

const $ = id => document.getElementById(id);
const post = (name, data = {}) => fetch('https://' + resource + '/' + name, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data)
}).then(async response => {
  if (!response.ok) throw new Error('NUI request failed: ' + response.status);
  return response.json().catch(() => ({ ok: true }));
}).catch(error => {
  console.error('[rp_tablet_job] NUI request failed:', name, error);
  const note = $('role-note');
  if (note) note.textContent = 'La communication avec le serveur a échoué. Réessayez.';
  return { ok: false };
});

const missionCatalog = {
  police: [['Patrouille de secteur', 'Effectuez une patrouille préventive dans votre secteur.'], ['Sécurisation d’une zone', 'Assurez une présence visible et sécurisez le périmètre.']],
  ambulance: [['Ronde de prévention', 'Effectuez une ronde de prévention et vérifiez les points de secours.'], ['Intervention médicale', 'Préparez-vous à répondre à une demande d’assistance.']],
  firefighter: [['Inspection de sécurité', 'Effectuez une inspection préventive de votre secteur.'], ['Préparation intervention', 'Vérifiez le matériel et préparez une intervention.']],
  mechanic: [['Contrôle atelier', 'Vérifiez les équipements et l’état de l’atelier.'], ['Assistance dépannage', 'Préparez une mission d’assistance aux automobilistes.']],
  taxi: [['Course de transport', 'Prenez en charge une demande de transport.'], ['Mise à disposition', 'Assurez une présence dans les zones fréquentées.']],
  security: [['Ronde de surveillance', 'Effectuez une ronde de surveillance de votre secteur.'], ['Sécurisation de site', 'Assurez la sécurisation d’un site professionnel.']],
  delivery: [['Tournée de livraison', 'Préparez une tournée de livraison de colis.'], ['Collecte de colis', 'Effectuez une collecte auprès des partenaires.']],
  garbage: [['Tournée de collecte', 'Préparez une tournée de collecte des déchets.'], ['Contrôle de secteur', 'Vérifiez la propreté et les points de collecte.']]
};

function showTab(name) {
  document.querySelectorAll('.page').forEach(page => page.classList.toggle('active', page.id === name));
  document.querySelectorAll('.nav').forEach(button => button.classList.toggle('active', button.dataset.tab === name));
}

document.querySelectorAll('.nav').forEach(button => button.addEventListener('click', () => showTab(button.dataset.tab)));
$('close').addEventListener('click', () => post('close'));
$('refresh').addEventListener('click', () => post('refresh'));
$('refresh-police').addEventListener('click', () => post('refresh'));
$('duty-toggle').addEventListener('click', () => post('toggleDuty'));
$('job-bank-refresh').addEventListener('click', () => post('refreshJobBank'));
$('salary-stats-refresh')?.addEventListener('click', () => post('refreshSalaryStats'));
$('job-bank-deposit').addEventListener('click', () => submitJobBank('jobBankDeposit'));
$('job-bank-withdraw').addEventListener('click', () => submitJobBank('jobBankWithdraw'));

async function submitJobBank(action) {
  if (jobBankSubmitting) return;
  const input = $('job-bank-amount');
  const amount = Number(input.value);
  if (!Number.isInteger(amount) || amount < 1 || amount > 1000000) {
    $('job-bank-permissions').textContent = 'Saisissez un montant entier compris entre 1 et 1 000 000 $.';
    return;
  }
  const depositWasDisabled = $('job-bank-deposit').disabled;
  const withdrawWasDisabled = $('job-bank-withdraw').disabled;
  jobBankSubmitting = true;
  $('job-bank-deposit').disabled = true;
  $('job-bank-withdraw').disabled = true;
  const result = await post(action, { amount });
  jobBankSubmitting = false;
  $('job-bank-deposit').disabled = depositWasDisabled;
  $('job-bank-withdraw').disabled = withdrawWasDisabled;
  if (result?.ok !== false) input.value = '';
}

function renderJobBank(data) {
  const label = $('job-bank-label');
  const balance = $('job-bank-balance');
  const permissions = $('job-bank-permissions');
  const deposit = $('job-bank-deposit');
  const withdraw = $('job-bank-withdraw');
  const history = $('job-bank-history');
  history.innerHTML = '';

  if (!data || !data.account) {
    label.textContent = 'Compte indisponible';
    balance.textContent = '—';
    permissions.textContent = 'Aucun compte bancaire n’est associé à ce métier.';
    deposit.disabled = true;
    withdraw.disabled = true;
    const empty = document.createElement('div');
    empty.className = 'note';
    empty.textContent = 'Aucune opération disponible.';
    history.append(empty);
    return;
  }

  const account = data.account;
  label.textContent = account.label || account.job || 'Compte métier';
  balance.textContent = (Number(account.balance) || 0).toLocaleString('fr-FR') + ' $';
  const canDeposit = account.allow_deposit === true || Number(account.allow_deposit) === 1;
  const canWithdraw = account.allow_withdraw === true || Number(account.allow_withdraw) === 1;
  permissions.textContent = 'Dépôts : ' + (canDeposit ? 'autorisés' : 'désactivés') +
    ' · Retraits : ' + (canWithdraw ? 'autorisés' : 'désactivés');
  deposit.disabled = !canDeposit;
  withdraw.disabled = !canWithdraw;

  const rows = Array.isArray(data.history) ? data.history : [];
  if (!rows.length) {
    const empty = document.createElement('div');
    empty.className = 'note';
    empty.textContent = 'Aucune opération enregistrée pour ce métier.';
    history.append(empty);
    return;
  }

  rows.forEach(item => {
    const row = document.createElement('article');
    row.className = 'job-bank-history-row';
    const info = document.createElement('div');
    const who = document.createElement('b');
    who.textContent = (item.transaction_type === 'deposit' ? 'Dépôt' : 'Retrait') + ' · ' + (item.player_name || 'Employé');
    const date = document.createElement('small');
    date.textContent = item.created_at ? new Date(item.created_at).toLocaleString('fr-FR') : 'Date inconnue';
    info.append(who, date);
    const amount = document.createElement('strong');
    amount.className = item.transaction_type === 'deposit' ? 'positive' : 'negative';
    amount.textContent = (item.transaction_type === 'deposit' ? '+' : '−') +
      (Number(item.amount) || 0).toLocaleString('fr-FR') + ' $';
    row.append(info, amount);
    history.append(row);
  });
}

function renderPoliceAlerts() {
  const container = $('police-alerts');
  if (!container) return;
  container.innerHTML = '';
  $('police-alert-count').textContent = policeAlerts.filter(alert => alert.status === 'En cours').length;
  if (!policeAlerts.length) {
    const empty = document.createElement('div');
    empty.className = 'note';
    empty.textContent = 'Aucune alerte de dispatch pour le moment.';
    container.append(empty);
    return;
  }

  policeAlerts.slice().reverse().forEach(alert => {
    const card = document.createElement('article');
    card.className = 'police-alert';
    const head = document.createElement('div');
    head.className = 'alert-head';
    const title = document.createElement('b');
    title.textContent = alert.title || 'Interpellation refusée';
    const severity = document.createElement('span');
    severity.className = 'severity';
    severity.textContent = alert.severity || '—';
    head.append(title, severity);
    const detail = document.createElement('p');
    detail.textContent = 'Suspect : ' + (alert.suspect || 'Inconnu') + ' · ID ' + alert.playerId + ' · ' + (alert.status || 'En cours');
    const actions = document.createElement('div');
    actions.className = 'alert-actions';
    const gps = document.createElement('button');
    gps.textContent = 'GPS suspect';
    gps.disabled = !alert.coords || !Number.isFinite(Number(alert.coords.x)) || !Number.isFinite(Number(alert.coords.y));
    gps.addEventListener('click', () => post('policeWaypoint', { x: Number(alert.coords.x), y: Number(alert.coords.y) }));
    const take = document.createElement('button');
    take.textContent = 'Prendre en charge';
    take.disabled = alert.status !== 'En cours';
    take.addEventListener('click', () => post('markPoliceAlert', { id: alert.id, status: 'Pris en charge' }));
    const close = document.createElement('button');
    close.textContent = 'Clôturer';
    close.disabled = alert.status === 'Clôturée';
    close.addEventListener('click', () => post('markPoliceAlert', { id: alert.id, status: 'Clôturée' }));
    actions.append(gps, take, close);
    card.append(head, detail, actions);
    container.append(card);
  });
}

function upsertPoliceAlert(alert) {
  if (!alert) return;
  const index = policeAlerts.findIndex(item => item.id === alert.id);
  if (index >= 0) policeAlerts[index] = alert;
  else policeAlerts.push(alert);
  renderPoliceAlerts();
}

function render(data) {
  state = data || {};
  $('job-title').textContent = data.job || 'Tablette métier';
  $('job-name').textContent = data.job || '—';
  $('grade-name').textContent = data.grade || '—';
  $('grade-title').textContent = data.grade || 'Bienvenue';
  $('team-count').textContent = (data.roster || []).length;
  $('duty-label').textContent = data.duty ? 'En service' : 'Hors service';
  $('duty-toggle').textContent = data.duty ? 'Terminer mon service' : 'Prendre mon service';
  $('duty-toggle').classList.toggle('off', data.duty);
  $('roster').innerHTML = '';

  (data.roster || []).forEach(person => {
    const row = document.createElement('div');
    row.className = 'person';
    const info = document.createElement('div');
    const name = document.createElement('b');
    name.textContent = person.name;
    const grade = document.createElement('small');
    grade.textContent = person.grade;
    info.append(name, grade);
    const status = document.createElement('span');
    status.className = 'status' + (person.duty ? ' on' : '');
    status.textContent = person.duty ? 'En service' : 'Hors service';
    row.append(info, status);
    $('roster').append(row);
  });

  const current = data.mission;
  $('active-mission').innerHTML = '';
  if (current) {
    const card = document.createElement('div');
    card.className = 'mission-card';
    const info = document.createElement('div');
    const title = document.createElement('b');
    title.textContent = 'Mission en cours : ' + current.title;
    const desc = document.createElement('p');
    desc.textContent = current.description;
    info.append(title, desc);
    const done = document.createElement('button');
    done.textContent = 'Clôturer';
    done.addEventListener('click', () => post('finishMission'));
    card.append(info, done);
    $('active-mission').append(card);
  }

  $('mission-list').innerHTML = '';
  const missions = missionCatalog[data.jobName] || [];
  missions.forEach(([title, description]) => {
    const card = document.createElement('div');
    card.className = 'mission-card';
    const info = document.createElement('div');
    const heading = document.createElement('b');
    heading.textContent = title;
    const desc = document.createElement('p');
    desc.textContent = description;
    info.append(heading, desc);
    const button = document.createElement('button');
    button.textContent = current ? 'Mission en cours' : 'Accepter';
    button.disabled = !!current || !data.duty;
    button.addEventListener('click', () => post('startMission', { title, description }));
    card.append(info, button);
    $('mission-list').append(card);
  });
  if (!missions.length) {
    const empty = document.createElement('div');
    empty.className = 'note';
    empty.textContent = 'Aucune mission prédéfinie pour ce métier pour le moment.';
    $('mission-list').append(empty);
  }

  $('role-note').textContent = data.duty
    ? 'Vous êtes en service. Les actions sont soumises aux contrôles du module de votre métier.'
    : 'Prenez votre service pour accéder aux missions proposées.';
  const policeAccess = data.jobName === 'police' && data.duty === true;
  $('police-nav').classList.toggle('hidden', !policeAccess);
  if (!policeAccess && $('police').classList.contains('active')) showTab('overview');
  renderPoliceAlerts();
}

window.addEventListener('message', event => {
  const data = event.data || {};
  if (data.action === 'open') {
    $('tablet').classList.remove('hidden');
    showTab('overview');
    render(data.data || {});
  }
  if (data.action === 'update') render(data.data || {});
  if (data.action === 'jobBankData') renderJobBank(data.data);
  if (data.action === 'policeAlerts') {
    policeAlerts = Array.isArray(data.alerts) ? data.alerts : [];
    renderPoliceAlerts();
  }
  if (data.action === 'policeAlert') upsertPoliceAlert(data.alert);
  if (data.action === 'close') $('tablet').classList.add('hidden');
});

document.addEventListener('keydown', event => {
  if (event.key === 'Escape') {
    event.preventDefault();
    post('close');
  }
});


function renderSalaryStats(data) {
  const values = {
    today: Math.max(0, Number(data?.today) || 0),
    month: Math.max(0, Number(data?.month) || 0),
    year: Math.max(0, Number(data?.year) || 0)
  };
  const format = value => value.toLocaleString('fr-FR', { maximumFractionDigits: 0 }) + ' $';
  $('salary-today').textContent = format(values.today);
  $('salary-month').textContent = format(values.month);
  $('salary-year').textContent = format(values.year);
  const chart = $('salary-chart');
  chart.replaceChildren();
  const max = Math.max(values.today, values.month, values.year, 1);
  [['Aujourd’hui', values.today], ['Ce mois', values.month], ['Cette année', values.year]].forEach(([label, value]) => {
    const row = document.createElement('div');
    row.className = 'salary-chart-row';
    const caption = document.createElement('span');
    caption.textContent = label;
    const track = document.createElement('div');
    track.className = 'salary-chart-track';
    const bar = document.createElement('div');
    bar.className = 'salary-chart-bar';
    bar.style.width = Math.max(1, (value / max) * 100) + '%';
    track.append(bar);
    const amount = document.createElement('b');
    amount.textContent = format(value);
    row.append(caption, track, amount);
    chart.append(row);
  });
  $('salary-stats-note').textContent = data?.unavailable
    ? 'Statistiques indisponibles : vérifiez la table bank_transactions.'
    : 'Versements enregistrés : ' + (Number(data?.paymentsToday) || 0) + ' aujourd’hui. Les montants sont calculés pour le métier connecté.';
}
window.addEventListener('message', event => {
  const message = event.data || {};
  if (message.action === 'salaryStats') renderSalaryStats(message.data || {});
});
