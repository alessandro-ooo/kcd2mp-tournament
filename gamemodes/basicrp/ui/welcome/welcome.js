// The realm's welcome at the join: the rules and a short test - the player types the word the mode asks for - with the keyboard
// and the mouse from the start, in front of the password box (the mode's frame has focus "open"). The window is drawn at once and
// filled when the mode's message comes; Esc stays here (the rules come before the password).
//
//   from the mode   KcdMp.onMessage({name, rules: ["..."], answer})
//   to the mode     KcdMp.emitServer("welcome.accept")
(() => {
  "use strict";

  const $ = (id) => document.getElementById(id);
  let answer = "agree";
  let sent = false;
  document.body.classList.add("ready");   // on screen as soon as the page is: it may hold the keys before the mode's message

  const plain = (text) => String(text || "").trim().toLowerCase();

  KcdMp.onMessage((data) => {
    if (!data || typeof data !== "object") return;
    if (typeof data.name === "string" && data.name !== "") $("title").textContent = "Welcome to " + data.name;
    if (typeof data.answer === "string" && data.answer !== "") answer = data.answer;
    $("word").textContent = answer;
    $("rules").replaceChildren(...(Array.isArray(data.rules) ? data.rules : []).map((rule) => {
      const li = document.createElement("li");
      li.textContent = String(rule);
      return li;
    }));
  });

  function enter() {
    if (sent) return;
    if (plain($("answer").value) !== plain(answer)) {
      $("wrong").textContent = "Type the word as it stands above: " + answer;
      $("wrong").hidden = false;
      return;
    }
    sent = true;
    $("enter").disabled = true;
    KcdMp.emitServer("welcome.accept").catch(() => {
      sent = false;   // the server did not take it (the connection, a full queue): the player may try again
      $("enter").disabled = false;
    });
  }

  $("enter").addEventListener("click", enter);
  $("answer").addEventListener("input", () => { $("wrong").hidden = true; });
  window.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      enter();
    } else if (e.key === "Escape") {
      e.preventDefault();   // kept: the SDK gives the keyboard back on an Esc the page leaves alone
    }
  });
})();
