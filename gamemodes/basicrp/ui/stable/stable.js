// The stable master's horses: one card a coat, the player's own marked, a Buy on the others.
//
//   from the mode   KcdMp.onMessage({coats: ["black", ...], current: "chestnut" | null, price: 300, money: 412, hasHorse: true})
//   to the mode     KcdMp.emitServer("stable.buy", {coat}) - the mode checks the purse and the horse and answers with a notice
//                   KcdMp.emitServer("stable.close")
(() => {
  "use strict";

  // body and mane colours of the game's ten coats (an unknown coat gets a plain brown)
  const COLOURS = {
    black: ["#1d1a17", "#0e0c0b"], bay_dun: ["#a0794a", "#2a1d14"], chestnut: ["#8a4b24", "#6d3518"], light_grey: ["#c4c1b8", "#e9e6de"],
    buckskin: ["#c9a46a", "#1f1712"], palomino: ["#d8b46a", "#f1e6c4"], seal_brown: ["#3d2618", "#1a110b"], dark_grey: ["#5d5b57", "#2b2a28"],
    red_roan: ["#8e5a4b", "#4a2a20"], brown: ["#5e3a22", "#2d1b10"],
  };
  const $ = (id) => document.getElementById(id);
  const label = (coat) => coat.replace(/_/g, " ");

  KcdMp.onMessage((data) => {
    if (!data || !Array.isArray(data.coats)) return;
    document.body.classList.add("ready");
    const price = Number(data.price) || 0;
    const money = Number(data.money) || 0;
    $("offer").textContent = data.hasHorse
      ? "Your horse for one of another coat, " + price + " groschen. Which one?"
      : "You have no horse to trade yet - /horse brings you your first one, then come back.";
    $("money").textContent = "Purse: " + money.toLocaleString() + " gr";
    $("coats").replaceChildren(...data.coats.map((coat) => {
      const card = document.createElement("div");
      card.className = "coat";
      card.setAttribute("role", "listitem");
      const yours = coat === data.current;
      card.classList.toggle("yours", yours);
      const swatch = document.createElement("div");
      swatch.className = "swatch";
      const [body, mane] = COLOURS[coat] || ["#6b4a2e", "#2d1b10"];
      swatch.style.background = body;
      swatch.style.setProperty("--mane", mane);
      const name = document.createElement("div");
      name.className = "name";
      name.textContent = label(coat);
      const tag = document.createElement("div");
      tag.className = "tag";
      tag.textContent = yours ? "your horse" : price + " gr";
      const buy = document.createElement("button");
      buy.type = "button";
      buy.className = "action";
      buy.textContent = "Trade";
      buy.disabled = yours || !data.hasHorse || money < price;
      buy.addEventListener("click", () => KcdMp.emitServer("stable.buy", { coat }).catch(() => {}));
      card.append(swatch, name, tag, buy);
      return card;
    }));
  });

  $("close").addEventListener("click", () => KcdMp.emitServer("stable.close").catch(() => {}));
})();
