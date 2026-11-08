let timerInterval = null;
let remainingTime = 20;
let totalTime = 20;
let targetSequence = [];
let currentStep = 0;
let currentTargetType = 'ATM';
let currentTargetId = null;

const hexPool = ['0x4F', '0x9A', '0x1B', '0xC3', '0x7E', '0x2D', '0x88', '0xFA', '0x5C', '0xE1', '0x33', '0xA7'];

window.addEventListener('message', function(event) {
    const data = event.data;

    if (data.action === 'startHack') {
        currentTargetType = data.type || 'ATM';
        currentTargetId = data.id || null;
        startHackingGame(currentTargetType, data.duration || 20);
    } else if (data.action === 'closeHack') {
        closeHackingGame();
    }
});

function startHackingGame(type, duration) {
    document.getElementById('hack-container').classList.remove('hidden');
    document.getElementById('terminal-title').innerText = type === 'ATM' 
        ? 'DÉCRYPTAGE DAB - PROTOCOLE DISTRIBUTEUR' 
        : 'TERMINAL DE SÉCURITÉ - COFFRE FORT BANCAIRE';
    document.getElementById('security-level').innerText = type === 'ATM' ? 'NIVEAU: MOYEN' : 'NIVEAU: CRITIQUE';

    totalTime = duration;
    remainingTime = duration;
    currentStep = 0;

    // Pick 4 unique hex values for sequence
    const shuffled = [...hexPool].sort(() => 0.5 - Math.random());
    targetSequence = shuffled.slice(0, 4);

    document.getElementById('target-sequence-code').innerText = targetSequence.join('  ➔  ');

    // Generate Grid with 8 items including targets
    const gridElements = [...targetSequence, ...shuffled.slice(4, 8)].sort(() => 0.5 - Math.random());
    const gridContainer = document.getElementById('memory-grid');
    gridContainer.innerHTML = '';

    gridElements.forEach(hex => {
        const block = document.createElement('div');
        block.className = 'memory-block';
        block.innerText = hex;
        block.addEventListener('click', () => handleBlockClick(block, hex));
        gridContainer.appendChild(block);
    });

    // Start Timer
    clearInterval(timerInterval);
    updateTimerDisplay();
    timerInterval = setInterval(() => {
        remainingTime -= 0.1;
        if (remainingTime <= 0) {
            clearInterval(timerInterval);
            finishHack(false, 'Temps écoulé ! Alarme déclenchée !');
        } else {
            updateTimerDisplay();
        }
    }, 100);
}

function updateTimerDisplay() {
    const percent = Math.max(0, (remainingTime / totalTime) * 100);
    document.getElementById('hack-timer-bar').style.width = percent + '%';
    document.getElementById('hack-timer-text').innerText = `Temps restant : ${Math.max(0, remainingTime).toFixed(1)}s`;
}

function handleBlockClick(block, hex) {
    if (hex === targetSequence[currentStep]) {
        block.classList.add('matched');
        currentStep++;

        if (currentStep >= targetSequence.length) {
            clearInterval(timerInterval);
            finishHack(true, 'Intrusion réussie ! Accès aux fonds autorisé.');
        }
    } else {
        block.classList.add('error');
        setTimeout(() => block.classList.remove('error'), 400);
        remainingTime = Math.max(0, remainingTime - 3); // Penalty
        updateTimerDisplay();
    }
}

function finishHack(success, message) {
    setTimeout(() => {
        closeHackingGame();
        fetch(`https://${GetParentResourceName()}/hackResult`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                success: success,
                type: currentTargetType,
                targetId: currentTargetId,
                message: message
            })
        });
    }, 500);
}

function closeHackingGame() {
    clearInterval(timerInterval);
    document.getElementById('hack-container').classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/closeUI`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

document.getElementById('btn-abort-hack').addEventListener('click', () => {
    closeHackingGame();
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeHackingGame();
    }
});
