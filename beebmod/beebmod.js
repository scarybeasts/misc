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

function sample_table_clear() {
  const sample_table = document.getElementById("sample_table");
  const length = sample_table.rows.length;
  for (let i = (length - 1); i > 0; --i) {
    sample_table.deleteRow(i);
  }
}

function sample_table_add(i,
                          name,
                          volume,
                          length,
                          repeat_start,
                          repeat_length) {
  const sample_table = document.getElementById("sample_table");
  const row = sample_table.insertRow();
  const index_cell = row.insertCell(0);
  const index_string = i.toString();
  index_cell.innerText = index_string;
  const name_cell = row.insertCell(1);
  name_cell.innerText = name;
  const volume_cell = row.insertCell(2);
  volume_cell.innerText = volume.toString();
  const length_cell = row.insertCell(3);
  length_cell.innerText = length.toString();
  const repeat_start_cell = row.insertCell(4);
  repeat_start_cell.innerText = repeat_start.toString();
  const repeat_length_cell = row.insertCell(5);
  repeat_length_cell.innerText = repeat_length.toString();
  const play_cell = row.insertCell(6);
  const play_input = document.createElement("input");
  play_input.name = index_string;
  play_input.type = "text";
  play_input.addEventListener("keypress", play_sample);
  play_cell.appendChild(play_input);
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
  sample_table_clear();

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
      const repeat_start = sample.getRepeatStart();
      const repeat_length = sample.getRepeatLength();

      sample_table_add(i, name, volume, length, repeat_start, repeat_length);
    }
  }
}

function create_player() {
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
}

function play_mod_file() {
  if (window.modfile == null) {
    return;
  }

  stop_mod_file();
  create_player();

  const player = window.player;
  const number_start_position =
      document.getElementById("number_start_position");
  player.setPosition(number_start_position.valueAsNumber);

  player.playFile();
}

function stop_mod_file() {
  const player = window.player;
  if (player == null) {
    return;
  }
  player.stop();
  window.player = null;
}

function play_sample(event) {
  if (window.modfile == null) {
    return;
  }

  if (window.player == null) {
    create_player();
  }

  const player = window.player;
  const sample_index = Number(event.target.name);
  player.playSample(sample_index);
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
