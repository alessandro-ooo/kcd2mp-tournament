// Letters painted on a wall: the mode sends the words when this copy is ready.
//
//   from the mode   KcdMp.onMessage({name, line})
// Opened in a browser (with sdk.js next to the folder) the page runs in mock mode with a made-up tavern.
(() => {
  "use strict";

  KcdMp.onMessage((data) => {
    if (data && typeof data.name === "string") {
      document.getElementById("name").textContent = data.name;
      document.getElementById("line").textContent = typeof data.line === "string" ? data.line : "";
    }
  });

  if (KcdMp.env.mock) {
    KcdMp.mock.message({ name: "The Pike and Perch", line: "Rooms - Ale - Stabling" });
  }
})();
