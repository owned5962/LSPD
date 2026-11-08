let currentTabIndex = 0;
const tabs = ['identity', 'appearance', 'spawn'];
let selectedColor = 0;
let selectedSpawn = 'airport';

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'openRegistration') {
        document.getElementById('registration-app').classList.remove('hidden');
        switchTab(0);
    } else if (data.action === 'closeRegistration') {
        document.getElementById('registration-app').classList.add('hidden');
    }
});

function switchTab(index) {
    currentTabIndex = index;
    const tabName = tabs[index];

    document.querySelectorAll('.tab-btn').forEach((btn, i) => {
        btn.classList.toggle('active', i === index);
    });

    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.toggle('active', content.id === `${tabName}-tab`);
    });

    const prevBtn = document.getElementById('prev-btn');
    const nextBtn = document.getElementById('next-btn');
    const submitBtn = document.getElementById('submit-btn');

    prevBtn.disabled = (index === 0);
    prevBtn.style.opacity = index === 0 ? '0.5' : '1';

    if (index === tabs.length - 1) {
        nextBtn.classList.add('hidden');
        submitBtn.classList.remove('hidden');
    } else {
        nextBtn.classList.remove('hidden');
        submitBtn.classList.add('hidden');
    }
}

document.querySelectorAll('.tab-btn').forEach((btn, idx) => {
    btn.addEventListener('click', () => switchTab(idx));
});

document.getElementById('prev-btn').addEventListener('click', () => {
    if (currentTabIndex > 0) switchTab(currentTabIndex - 1);
});

document.getElementById('next-btn').addEventListener('click', () => {
    if (currentTabIndex < tabs.length - 1) switchTab(currentTabIndex + 1);
});

document.getElementById('height').addEventListener('input', (e) => {
    document.getElementById('height-val').innerText = e.target.value;
});

document.getElementById('hair-style').addEventListener('input', (e) => {
    document.getElementById('hair-val').innerText = e.target.value;
});

document.querySelectorAll('.color-dot').forEach(dot => {
    dot.addEventListener('click', () => {
        document.querySelectorAll('.color-dot').forEach(d => d.classList.remove('active'));
        dot.classList.add('active');
        selectedColor = dot.getAttribute('data-color');
    });
});

document.querySelectorAll('.spawn-card').forEach(card => {
    card.addEventListener('click', () => {
        document.querySelectorAll('.spawn-card').forEach(c => c.classList.remove('active'));
        card.classList.add('active');
        selectedSpawn = card.getAttribute('data-spawn');
    });
});

document.getElementById('gender').addEventListener('change', (e) => {
    fetch(`https://${GetParentResourceName()}/updateSkinPreview`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ gender: e.target.value })
    }).catch(() => {});
});

document.getElementById('creator-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const firstname = document.getElementById('firstname').value.trim();
    const lastname = document.getElementById('lastname').value.trim();
    const dateofbirth = document.getElementById('dateofbirth').value;
    const gender = document.getElementById('gender').value;
    const height = document.getElementById('height').value;
    const hairStyle = document.getElementById('hair-style').value;
    const clothing = document.getElementById('clothing-style').value;

    const payload = {
        firstname,
        lastname,
        dateofbirth,
        gender,
        height,
        spawnPoint: selectedSpawn,
        skin: {
            hairStyle,
            hairColor: selectedColor,
            clothing
        }
    };

    fetch(`https://${GetParentResourceName()}/saveCharacter`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    }).then(() => {
        document.getElementById('registration-app').classList.add('hidden');
    }).catch(() => {
        document.getElementById('registration-app').classList.add('hidden');
    });
});

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'rp_characters';
}
