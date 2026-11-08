window.addEventListener('message', function(event) {
    if (event.data.action === 'open') {
        document.getElementById('clothing-wrapper').classList.remove('hidden');
    } else if (event.data.action === 'close') {
        document.getElementById('clothing-wrapper').classList.add('hidden');
    }
});

document.querySelectorAll('.preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const outfit = btn.dataset.outfit;
        document.getElementById('outfit-name').value = btn.innerText.trim();
        fetch(`https://${GetParentResourceName()}/applyPreset`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ outfit })
        }).catch(() => {});
    });
});

document.getElementById('btn-save').addEventListener('click', () => {
    const name = document.getElementById('outfit-name').value || 'Nouvelle tenue';
    fetch(`https://${GetParentResourceName()}/saveOutfit`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: name })
    });
    document.getElementById('clothing-wrapper').classList.add('hidden');
});

document.getElementById('close-btn').addEventListener('click', () => {
    document.getElementById('clothing-wrapper').classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', body: '{}' });
});
