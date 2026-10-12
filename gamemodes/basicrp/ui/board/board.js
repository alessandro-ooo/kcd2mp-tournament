// A notice board on a surface in the world: the mode sends the notices, the player's use key picks the next one to read.
//
//   from the mode   KcdMp.onMessage({notices: [{title, text}]}) - at this copy's ready, and whenever a notice is pinned
//   the use key     KcdMp.onSurfaceUse(f) - the player pressed it on this board's prompt (on that player's copy alone)
//   to the mode     KcdMp.emitServer("board.read", <the notice's number, from 1>) - the surface's events_out lists the name
// KcdMp.surface says which surface this copy draws ({name, id, width, height}). The notices are players' text: they go on the page with
// textContent. Opened in a browser (with sdk.js next to the folder) the page runs in mock mode with two made-up notices; KcdMp.mock.use()
// in the console presses the use key.
(() => {
  "use strict";

  const list = document.getElementById("notices");
  let notices = [];
  let read = -1;   // the notice the player reads now (-1: none yet)

  function draw() {
    list.replaceChildren(...notices.slice(-6).map((notice, i) => {
      const li = document.createElement("li");
      const title = document.createElement("strong");
      title.textContent = String(notice.title || "");
      const text = document.createElement("span");
      text.textContent = String(notice.text || "");
      li.append(title, text);
      li.classList.toggle("read", i === read);
      return li;
    }));
  }

  KcdMp.onMessage((data) => {
    if (data && Array.isArray(data.notices)) {
      notices = data.notices;
      if (read >= notices.length) read = -1;
      draw();
    }
  });

  KcdMp.onSurfaceUse(() => {
    if (notices.length === 0) return;
    read = (read + 1) % Math.min(notices.length, 6);
    draw();
    KcdMp.emitServer("board.read", read + 1).catch((e) => KcdMp.log.warn(`board.read: ${e.message}`));
  });

  if (KcdMp.env.mock) {
    KcdMp.mock.message({
      notices: [
        { title: "Wanted", text: "A smith's apprentice. Ask at the forge by the gate." },
        { title: "Lost", text: "A brown mare with a white star. A reward for her return." },
      ],
    });
  }
})();
