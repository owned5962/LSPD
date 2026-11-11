window.addEventListener('message', function(event) {
    if (event.data.action === 'open') {
        document.getElementById('clothing-wrapper').classList.remove('hidden');
        fetch(`https://${GetParentResourceName()}/requestOutfits`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' }).catch(() => {});
    } else if (event.data.action === 'close') {
        document.getElementById('clothing-wrapper').classList.add('hidden');
    } else if (event.data.action === 'outfits') {
        renderSavedOutfits(Array.isArray(event.data.outfits) ? event.data.outfits : []);
    }
});

function renderSavedOutfits(outfits) {
    const list = document.getElementById('outfit-list');
    list.replaceChildren();
    if (outfits.length === 0) {
        const empty = document.createElement('p');
        empty.className = 'empty-outfits';
        empty.textContent = 'Aucune tenue sauvegardée.';
        list.appendChild(empty);
        return;
    }
    outfits.forEach(outfit => {
        if (!outfit || !Number.isInteger(Number(outfit.id)) || typeof outfit.name !== 'string') return;
        const button = document.createElement('button');
        button.className = 'saved-outfit-btn';
        button.type = 'button';
        button.textContent = outfit.name;
        button.addEventListener('click', () => {
            fetch(`https://${GetParentResourceName()}/applySavedOutfit`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ id: Number(outfit.id) })
            }).catch(() => {});
        });
        list.appendChild(button);
    });
}

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


document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    event.preventDefault();
    document.getElementById('clothing-wrapper')?.classList.add('hidden');
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', body: '{}' }).catch(() => {});
});
