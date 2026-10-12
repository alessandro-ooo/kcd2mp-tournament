// A short line from the mode in the corner for six seconds - a purchase, the stable's trade. The mode sends {text}.
(() => {
  "use strict";
  const stack = document.getElementById("stack");
  KcdMp.onMessage((data) => {
    const text = data && typeof data.text === "string" ? data.text : "";
    if (!text) return;
    const line = document.createElement("div");
    line.className = "notice";
    line.textContent = text;
    stack.append(line);
    while (stack.children.length > 4) stack.firstElementChild.remove();
    setTimeout(() => {
      line.classList.add("gone");
      setTimeout(() => line.remove(), 700);
    }, 6000);
  });
})();
