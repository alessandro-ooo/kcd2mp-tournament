// An inventory window: the mode sends what the player carries, the page shows it with the game's own item pictures.
//
//   from the mode   KcdMp.onMessage({items: [{class, name, display, category, amount, health, worn, weight, price}], money})
//   to the mode     KcdMp.emitServer("inventory.close") - the Close button (the frame's events_out lists the name)
// KcdMp.itemIcon(key) is the address of an item's picture (the item's GUID or game name): an <img> shows it, nothing can read it
// back. Item names are the game's: they go on the page with textContent. Opened in a browser (with sdk.js next to the folder) the
// page runs in mock mode with a few made-up items and placeholder pictures.
(() => {
  "use strict";

  const TABS = [
    { label: "All", test: () => true },
    { label: "Weapons", test: (i) => /Weapon|Ammo/.test(i.category) },
    { label: "Armour", test: (i) => /Armor|Helmet|Hood/.test(i.category) },
    { label: "Food", test: (i) => /Food|Herb|Poison|Ointment/.test(i.category) },
    { label: "Other", test: (i) => !/Weapon|Ammo|Armor|Helmet|Hood|Food|Herb|Poison|Ointment/.test(i.category) },
  ];

  const $ = (id) => document.getElementById(id);
  let items = [];
  let tab = 0;
  let picked = null;   // the class of the picked item

  const groschen = (tenths) => (tenths / 10).toLocaleString(undefined, { maximumFractionDigits: 1 }) + " gr";
  const kilos = (kg) => kg.toLocaleString(undefined, { maximumFractionDigits: 2 }) + " kg";

  // an item's picture: its name when it has one, else its GUID; a picture that fails to load gives way to the name
  function icon(item, size) {
    const img = document.createElement("img");
    img.alt = "";
    img.width = size;
    img.height = size;
    img.src = KcdMp.itemIcon(item.name || item.class);
    img.addEventListener("error", () => {
      const missing = document.createElement("span");
      missing.className = "missing";
      missing.textContent = item.display;
      img.replaceWith(missing);
    }, { once: true });
    return img;
  }

  function renderTabs() {
    $("tabs").replaceChildren(...TABS.map((t, i) => {
      const button = document.createElement("button");
      button.type = "button";
      button.setAttribute("role", "tab");
      button.setAttribute("aria-selected", String(i === tab));
      button.textContent = t.label;
      button.addEventListener("click", () => { tab = i; render(); });
      return button;
    }));
  }

  function renderDetails() {
    const item = items.find((i) => i.class === picked);
    $("details").hidden = !item;
    if (!item) return;
    const big = $("d-icon");
    big.src = KcdMp.itemIcon(item.name || item.class);
    $("d-name").textContent = item.display;
    $("d-category").textContent = item.category || "-";
    $("d-amount").textContent = String(item.amount);
    $("d-weight").textContent = kilos(item.weight * item.amount);
    $("d-price").textContent = groschen(item.price * item.amount);
    $("d-health").textContent = Math.round(item.health) + "%";
    $("d-worn").hidden = !item.worn;
  }

  function render() {
    renderTabs();
    const shown = items.filter(TABS[tab].test).sort((a, b) => a.display.localeCompare(b.display));
    $("grid").replaceChildren(...shown.map((item) => {
      const slot = document.createElement("div");
      slot.className = "slot";
      slot.setAttribute("role", "option");
      slot.title = item.display;
      slot.classList.toggle("picked", item.class === picked);
      slot.append(icon(item, 64));
      if (item.amount > 1) {
        const amount = document.createElement("span");
        amount.className = "amount";
        amount.textContent = String(item.amount);
        slot.append(amount);
      }
      if (item.worn) {
        const worn = document.createElement("span");
        worn.className = "worn";
        slot.append(worn);
      }
      slot.addEventListener("click", () => { picked = item.class; render(); });
      return slot;
    }));
    renderDetails();
  }

  KcdMp.onMessage((data) => {
    if (!data || !Array.isArray(data.items)) return;
    items = data.items;
    if (!items.some((i) => i.class === picked)) picked = items.length > 0 ? items[0].class : null;
    const total = items.reduce((sum, i) => sum + i.weight * i.amount, 0);
    $("money").textContent = "Purse: " + Number(data.money || 0).toLocaleString() + " gr";
    $("weight").textContent = "Carrying " + kilos(total);
    render();
  });

  $("close").addEventListener("click", () => KcdMp.emitServer("inventory.close").catch(() => {}));

  // ---- in a browser: a few made-up items
  if (KcdMp.env.mock) {
    KcdMp.mock.message({
      money: 312,
      items: [
        { class: "1", name: "longSwordDuel", display: "Duelling longsword", category: "MeleeWeapon", amount: 1, health: 92, worn: true, weight: 2.1, price: 6650 },
        { class: "2", name: "bread", display: "Bread", category: "Food", amount: 3, health: 100, worn: false, weight: 0.5, price: 40 },
        { class: "3", name: "apple", display: "Apple", category: "Food", amount: 5, health: 100, worn: false, weight: 0.15, price: 9 },
        { class: "4", name: "herb_chamomile", display: "Chamomile", category: "Herb", amount: 7, health: 100, worn: false, weight: 0.05, price: 6 },
        { class: "5", name: "arrow_hunting", display: "Hunting arrow", category: "Ammo", amount: 20, health: 100, worn: false, weight: 0.05, price: 12 },
      ],
    });
  }
})();
