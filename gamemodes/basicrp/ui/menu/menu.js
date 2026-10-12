// BasicRP's menu: the player's purse and horse, the town's people, and the commands as /help lists them.
//
//   from the mode   KcdMp.onMessage({name, level, money, horse, town: [{name, shop, talk}], help: [{color, text}]})
//                   (color: the chat's 0xRRGGBBAA)
//   to the mode     KcdMp.emitServer("menu.close")
(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);
  const css = (rgba) => "#" + ((Number(rgba) >>> 8) & 0xffffff).toString(16).padStart(6, "0");

  function show(tab) {
    for (const button of document.querySelectorAll("#tabs button")) button.setAttribute("aria-selected", String(button.dataset.tab === tab));
    for (const panel of document.querySelectorAll("[data-panel]")) panel.hidden = panel.dataset.panel !== tab;
  }
  for (const button of document.querySelectorAll("#tabs button")) button.addEventListener("click", () => show(button.dataset.tab));

  function row(list, term, value) {
    const dt = document.createElement("dt");
    dt.textContent = term;
    const dd = document.createElement("dd");
    dd.textContent = value;
    list.append(dt, dd);
  }

  KcdMp.onMessage((data) => {
    if (!data || typeof data !== "object") return;
    document.body.classList.add("ready");
    const you = $("you");
    you.replaceChildren();
    row(you, "Name", data.name || "");
    row(you, "Purse", Number(data.money || 0).toLocaleString() + " groschen");
    row(you, "Horse", data.horse ? "a " + data.horse + " horse" : "none yet - /horse brings one");
    $("where").textContent = data.level ? "You are in " + data.level : "";

    $("town").replaceChildren(...(Array.isArray(data.town) ? data.town : []).map((p) => {
      const li = document.createElement("li");
      const who = document.createElement("span");
      who.className = "who";
      who.textContent = p.name;
      const what = document.createElement("span");
      what.className = "what";
      what.textContent = p.shop ? "sells: " + p.shop : p.talk ? "talk to them" : "about town";
      li.append(who, what);
      return li;
    }));

    $("help").replaceChildren(...(Array.isArray(data.help) ? data.help : []).map((line) => {
      const div = document.createElement("div");
      div.className = "line";
      const text = String(line.text || "");
      if (!text.startsWith(" ")) div.classList.add("head");
      div.style.color = css(line.color);
      div.textContent = text;
      return div;
    }));
  });

  $("close").addEventListener("click", () => KcdMp.emitServer("menu.close").catch(() => {}));
})();
