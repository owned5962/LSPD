const app = document.getElementById('app');
const catalog = document.getElementById('catalog');
const exam = document.getElementById('exam');
const heading = document.getElementById('heading');
const subtitle = document.getElementById('subtitle');
const questionNode = document.getElementById('question');
const answersNode = document.getElementById('answers');
const progressLabel = document.getElementById('progress-label');
const progressBar = document.getElementById('progress-bar');
let questions = [];
let answers = [];
let current = 0;

function post(name, data = {}) {
  fetch(`https://rp_drivingschool/${name}`, {
    method: 'POST', headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  }).catch(() => {});
}
function close() { app.classList.add('hidden'); post('close'); }
document.getElementById('close').addEventListener('click', close);
document.getElementById('cancel').addEventListener('click', () => {
  close(); post('cancelExam');
});
function renderCatalog(categories) {
  catalog.innerHTML = '';
  exam.classList.add('hidden');
  catalog.classList.remove('hidden');
  heading.textContent = 'Auto-école';
  subtitle.textContent = 'Choisissez votre catégorie de permis';
  for (const item of categories || []) {
    const card = document.createElement('article');
    card.className = 'license';
    const info = document.createElement('div');
    const name = document.createElement('strong');
    name.textContent = item.label;
    const detail = document.createElement('small');
    detail.textContent = item.owned ? 'Permis déjà obtenu' : new Intl.NumberFormat('fr-FR').format(item.price) + ' $ — théorie + pratique';
    info.append(name, detail);
    const button = document.createElement('button');
    button.textContent = item.owned ? 'Obtenu' : 'S’inscrire';
    button.disabled = !!item.owned;
    if (item.owned) button.classList.add('owned');
    button.addEventListener('click', () => {
      app.classList.add('hidden');
      post('startTheory', { category: item.id });
    });
    card.append(info, button);
    catalog.append(card);
  }
}
function renderQuestion() {
  const item = questions[current];
  if (!item) return;
  progressLabel.textContent = `Question ${current + 1}/${questions.length}`;
  progressBar.style.width = `${((current + 1) / questions.length) * 100}%`;
  questionNode.textContent = item.q;
  answersNode.innerHTML = '';
  item.a.forEach((answer, index) => {
    const button = document.createElement('button');
    button.className = 'answer' + (answers[current] === index + 1 ? ' selected' : '');
    button.textContent = answer;
    button.addEventListener('click', () => {
      answers[current] = index + 1;
      renderQuestion();
    });
    answersNode.append(button);
  });
  document.getElementById('next').disabled = !answers[current];
  document.getElementById('next').textContent = current === questions.length - 1 ? 'Valider l’examen' : 'Continuer';
}
document.getElementById('next').addEventListener('click', () => {
  if (!answers[current]) return;
  if (current < questions.length - 1) {
    current += 1;
    renderQuestion();
    return;
  }
  const result = answers.slice();
  close();
  post('submitTheory', { answers: result });
});
window.addEventListener('message', event => {
  const data = event.data || {};
  if (data.action === 'close') { app.classList.add('hidden'); return; }
  if (data.action === 'open') {
    const owned = new Set((data.licenses || []).map(row => row.category));
    const categories = Object.entries(data.categories || {}).map(([id, item]) => ({
      id, label: item.label, price: Number(item.price) || 0, owned: owned.has(id)
    }));
    app.classList.remove('hidden');
    renderCatalog(categories);
  }
  if (data.action === 'theory') {
    questions = Array.isArray(data.questions) ? data.questions : [];
    answers = [];
    current = 0;
    catalog.classList.add('hidden');
    exam.classList.remove('hidden');
    app.classList.remove('hidden');
    heading.textContent = data.label || 'Examen théorique';
    subtitle.textContent = 'Répondez correctement à au moins 4 questions sur 5.';
    renderQuestion();
  }
});
document.addEventListener('keydown', event => { if (event.key === 'Escape' && !app.classList.contains('hidden')) close(); });
