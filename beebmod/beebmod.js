"use strict";

function beebmod() {
  window.modfile = null;
  window.player = null;

  const play_button = document.getElementById("play");
  play_button.addEventListener("click", play_mod_file);
  const stop_button = document.getElementById("stop");
  stop_button.addEventListener("click", stop_mod_file);

  // This is the actual drop handler.
  document.addEventListener("drop", file_dropped);
  // We need these machinations to prevent drops from triggering the download
  // UI.
  // See:
  // https://stackoverflow.com/questions/6756583/prevent-browser-from-loading-a-drag-and-dropped-file#comment67550173_6756680
  window.addEventListener("dragover", drop_on_window);
  window.addEventListener("drop", drop_on_window);

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
  for (let i = 1; i < 32; ++i) {
    const sample = modfile.getSample(i);
    const name = sample.getName();
    const length = sample.getLength();
    if ((name.length > 0) || (length > 0)) {
      const volume = sample.getVolume();
      const padded_index = (i.toString().padEnd(2, ' '));
      const padded_name = name.padEnd(22, ' ');
      const padded_volume = (volume.toString().padEnd(2, ' '));
      const padded_length = (length.toString().padEnd(5, ' '));
      const repeat_start = sample.getRepeatStart();
      const repeat_length = sample.getRepeatLength();
      log("Sample " +
          padded_index +
          ": " +
          padded_name +
          ", volume: " +
          padded_volume +
          ", length: " +
          padded_length +
          ", repeat: " +
          repeat_start +
          ", " +
          repeat_length);
    }
  }
}

function play_mod_file() {
  if (window.modfile == null) {
    return;
  }

  stop_mod_file();

  let player = null;
  const radio_amiga = document.getElementById("radio_amiga");
  const radio_beeb_separate = document.getElementById("radio_beeb_separate");
  if (radio_amiga.checked) {
    const amiga_player = new MODPlayerAmiga(window.modfile);
    player = amiga_player.player;
  } else if (radio_beeb_separate.checked) {
    const beeb_player = new MODPlayerBeeb(window.modfile, 0);
    player = beeb_player.player;
  } else {
    const beeb_player = new MODPlayerBeeb(window.modfile, 1);
    player = beeb_player.player;
  }
  window.player = player;

  const number_start_position =
      document.getElementById("number_start_position");
  player.setPosition(number_start_position.valueAsNumber);

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

function file_dropped(event) {
  const file = event.dataTransfer.files[0];
  const reader = new FileReader();
  reader.addEventListener("load", file_loaded);
  reader.readAsArrayBuffer(file);
}

function file_loaded(event) {
  const array_buffer = event.target.result;
  const binary = new Uint8Array(array_buffer);
  load_mod_file(binary);
}

function drop_on_window(event) {
  event.preventDefault();
}
