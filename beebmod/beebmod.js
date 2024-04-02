"use strict";

function beebmod() {
  const xhr = new XMLHttpRequest();
  xhr.addEventListener("load", beebmod_loaded);

  xhr.open("GET", "mods/winners.mod");
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
  log("Name: " + modfile.getName());
  log("Positions: " + modfile.getNumPositions());
  log("Patterns: " + modfile.getNumPatterns());
  for (let i = 0; i < 31; ++i) {
    const sample = modfile.getSample(i);
    const name = sample.getName();
    const length = sample.getLength();
    if ((name.length > 0) || (length > 0)) {
      const volume = sample.getVolume();
      const padded_index = (i.toString().padEnd(2, ' '));
      const padded_name = name.padEnd(22, ' ');
      const padded_volume = (volume.toString().padEnd(2, ' '));
      log("Sample " +
          padded_index +
          ": " +
          padded_name +
          ", volume: " +
          padded_volume +
          ", length: " +
          length);
    }
  }

  const player = new MODPlayerAmiga(modfile);
  window.player = player;
  player.play();
}
