"use strict";

function beebmod() {
  window.modfile = null;
  window.player = null;

  const play_button = document.getElementById("play");
  play_button.addEventListener("click", play_mod_file);
  const stop_button = document.getElementById("stop");
  stop_button.addEventListener("click", stop_mod_file);

  const xhr = new XMLHttpRequest();
  xhr.addEventListener("load", beebmod_loaded);

  xhr.open("GET", "mods/winners.mod");
  xhr.responseType = "arraybuffer";
  xhr.send();
}

function log_clear() {
  const e = document.getElementById("log");
  e.textContent = "";
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
  load_mod_file(binary);
}

function load_mod_file(binary) {
  log_clear();
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
}

function play_mod_file() {
  if (window.modfile == null) {
    return;
  }

  stop_mod_file();

  const player = new MODPlayerAmiga(window.modfile);
  window.player = player;
  player.play();
}

function stop_mod_file() {
  const player = window.player;
  if (player == null) {
    return;
  }
  player.stop();
  window.player = null;
}
