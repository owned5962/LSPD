let currentBet = 500;

function setBet(amount) {
    currentBet = amount;
    document.querySelectorAll(".bet-chip").forEach(b => b.classList.remove("active"));
    event.target.classList.add("active");
}

document.getElementById("btn-spin").addEventListener("click", () => {
    fetch(`https://${GetParentResourceName()}/playSlots`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ bet: currentBet })
    }).catch(() => {});
});

document.getElementById("btn-buy-chips").addEventListener("click", () => {
    const val = parseInt(document.getElementById("cashier-amount").value);
    fetch(`https://${GetParentResourceName()}/buyChips`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ amount: val })
    }).catch(() => {});
});

document.getElementById("btn-sell-chips").addEventListener("click", () => {
    const val = parseInt(document.getElementById("cashier-amount").value);
    fetch(`https://${GetParentResourceName()}/sellChips`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ amount: val })
    }).catch(() => {});
});

document.getElementById("close-btn").addEventListener("click", () => {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: "POST",
        headers: { "Content-Type": "application/json" }
    }).catch(() => {});
});

window.addEventListener("message", (event) => {
    const data = event.data;
    if (data.action === "updateChips") {
        document.getElementById("chips-counter").textContent = data.chips.toLocaleString('fr-FR');
    } else if (data.action === "slotsOutcome") {
        document.getElementById("reel-1").textContent = data.reels[0];
        document.getElementById("reel-2").textContent = data.reels[1];
        document.getElementById("reel-3").textContent = data.reels[2];
        if (data.win > 0) {
            document.getElementById("last-win-text").innerHTML = `Dernier gain : <span class="highlight">+${data.win.toLocaleString('fr-FR')} jetons !</span>`;
        } else {
            document.getElementById("last-win-text").innerHTML = `Dernier gain : <span style="color:#ef4444;">Perdu</span>`;
        }
    }
});
