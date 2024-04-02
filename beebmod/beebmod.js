"use strict";

function beebmod() {
  const xhr = new XMLHttpRequest();
  xhr.addEventListener("load", beebmod_loaded);

  xhr.open("GET", "moondark.mod");
  xhr.responseType = "arraybuffer";
  xhr.send();
}

function log(text) {
  const e = document.getElementById("log");
  e.textContent += text + "\n";
}

function beebmod_loaded(e) {
  const xhr = e.target;
  if (xhr.readyState != 4) {
    return;
  }
  if (xhr.status != 200) {
    alert("modfile load failed");
    return;
  }

  const response = xhr.response;
  const binary = new Uint8Array(response);
  log("MOD file length: " + binary.length);

  const modfile = new MODFile(binary);
  const ret = modfile.parse();
  if (ret == 0) {
    log("MOD parse failure");
    return;
  }

  window.modfile = modfile;
  log("Positions: " + modfile.getNumPositions());
  log("Patterns: " + modfile.getNumPatterns());

  const player = new MODPlayerAmiga(modfile);
  window.player = player;
  player.play();
}
