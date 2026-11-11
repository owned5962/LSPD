(() => {
  'use strict';
  const progressBar = document.getElementById('progress-bar');
  const progressText = document.getElementById('load-percentage');
  const statusText = document.getElementById('load-status');
  let lastProgress = 0;

  function setProgress(value) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return;
    const percent = Math.max(lastProgress, Math.min(100, Math.round(parsed * 100)));
    lastProgress = percent;
    if (progressBar) progressBar.style.width = percent + '%';
    if (progressText) progressText.textContent = percent + '%';
  }

  window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || typeof data !== 'object') return;

    if (data.eventName === 'loadProgress') {
      setProgress(data.loadFraction);
      if (statusText && lastProgress < 100) statusText.textContent = 'Téléchargement des ressources...';
    } else if (data.eventName === 'onLogLine') {
      if (statusText && typeof data.message === 'string') {
        statusText.textContent = data.message.slice(0, 140);
      }
    } else if (data.eventName === 'initFunctionInvoking') {
      if (statusText && typeof data.name === 'string') {
        statusText.textContent = 'Initialisation : ' + data.name.slice(0, 100);
      }
    } else if (data.eventName === 'startInitFunction') {
      if (statusText) statusText.textContent = 'Préparation de votre session...';
    } else if (data.eventName === 'endInitFunction') {
      if (statusText) statusText.textContent = 'Finalisation de la connexion...';
    }
  });

  // Local preview only: FiveM drives the real progress through loadProgress.
  if (!('invokeNative' in window)) {
    let demo = 0;
    const timer = window.setInterval(() => {
      demo = Math.min(100, demo + 2);
      setProgress(demo / 100);
      if (statusText) statusText.textContent = demo < 100 ? 'Aperçu du chargement...' : 'Aperçu terminé';
      if (demo >= 100) window.clearInterval(timer);
    }, 180);
  }
})();
