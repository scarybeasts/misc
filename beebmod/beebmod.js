"use strict";

async function beebmod() {
  window.modfile = null;
  window.player = null;
  window.beebmod_play_sample_channel = 0;

  beebmod_setup_listeners();
  // Wait for audio setup to finish because loading a file needs to post
  // information to the AudioWorklet context.
  await beebmod_setup_audio();
  beebmod_load_initial_file();
}

function beebmod_setup_listeners() {
  const play_button = document.getElementById("play");
  play_button.addEventListener("click", beebmod_button_play);
  const stop_button = document.getElementById("stop");
  stop_button.addEventListener("click", beebmod_button_stop);
  const radio_amiga = document.getElementById("radio_amiga");
  radio_amiga.addEventListener("change", beebmod_radio_amiga);
  const radio_beeb_separate = document.getElementById("radio_beeb_separate");
  radio_beeb_separate.addEventListener("change", beebmod_radio_beeb_separate);
  const radio_beeb_merged2 = document.getElementById("radio_beeb_merged2");
  radio_beeb_merged2.addEventListener("change", beebmod_radio_beeb_merged2);
  for (let i = 1; i <= 4; ++i) {
    const checkbox_play = document.getElementById("checkbox_play" + i);
    checkbox_play.addEventListener("change", beebmod_checkbox_play);
  }

  // This is the actual drop handler.
  document.addEventListener("drop", file_dropped);
  // We need these machinations to prevent drops from triggering the download
  // UI.
  // See:
  // https://stackoverflow.com/questions/6756583/prevent-browser-from-loading-a-drag-and-dropped-file#comment67550173_6756680
  window.addEventListener("dragover", drop_on_window);
  window.addEventListener("drop", drop_on_window);
}

async function beebmod_setup_audio() {
  const options = new Object();
  options.sampleRate = 250000;
  options.latencyHint = "interactive";
  const audio_context = new AudioContext(options);

  await audio_context.audioWorklet.addModule("modprocessor.js");
  const audio_node = new AudioWorkletNode(audio_context, "modprocessor");
  audio_node.connect(audio_context.destination);

  window.beebmod_audio_context = audio_context;
  window.beebmod_audio_node = audio_node;
  window.beebmod_port = audio_node.port;
}

function beebmod_load_initial_file() {
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
  play_input.addEventListener("keypress", beebmod_play_sample);
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
  sample_table_clear();

  log("MOD file length: " + binary.length);

  const modfile = new MODFile(binary);
  const ret = modfile.parse();
  if (ret == 0) {
    log("MOD parse failure");
    return;
  }

  window.modfile = modfile;
  const num_positions = modfile.getNumPositions();
  const num_patterns = modfile.getNumPatterns();
  log("Name: " + modfile.getName());
  log("Positions: " + num_positions);
  log("Patterns: " + num_patterns);

  const port = window.beebmod_port;
  port.postMessage(["NEWSONG", num_patterns, num_positions]);

  for (let i = 1; i < 32; ++i) {
    const sample = modfile.getSample(i);
    const name = sample.name;
    const length = sample.binary.length;
    if ((name.length > 0) || (length > 0)) {
      const volume = sample.volume;
      const repeat_start = sample.repeat_start;
      const repeat_length = sample.repeat_length;

      sample_table_add(i, name, volume, length, repeat_start, repeat_length);
    }

    port.postMessage(["SAMPLE", i, sample]);
  }
  for (let i = 0; i < num_patterns; ++i) {
    port.postMessage(["PATTERN", i, modfile.getPattern(i)]);
  }
  for (let i = 0; i < num_positions; ++i) {
    port.postMessage(["POSITION", i, modfile.getPatternIndex(i + 1)])
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

function beebmod_button_play() {
  const element_start_position =
      document.getElementById("number_start_position");
  const start_position = element_start_position.valueAsNumber;
  window.beebmod_port.postMessage(["PLAY", start_position]);
}

function beebmod_button_stop() {
  window.beebmod_port.postMessage(["STOP"]);
}

function beebmod_radio_amiga() {
  window.beebmod_port.postMessage(["AMIGA"]);
}

function beebmod_radio_beeb_separate() {
  window.beebmod_port.postMessage(["BEEB_SEPARATE"]);
}

function beebmod_radio_beeb_merged2() {
  window.beebmod_port.postMessage(["BEEB_MERGED2"]);
}

function beebmod_checkbox_play(event) {
  const id = event.target.id;
  let channel = Number(id.slice(-1));
  channel--;
  const checked = event.target.checked;
  window.beebmod_port.postMessage(["PLAY_CHANNEL", channel, checked]);
}

function beebmod_play_sample(event) {
  const name = event.target.name;
  const sample_index = Number(name);
  const key_code = event.code;
  let channel = window.beebmod_play_sample_channel;

  let note = 0;
  switch (key_code) {
  // Octave 1.
  case "KeyZ": note = 1; break;
  case "KeyS": note = 2; break;
  case "KeyX": note = 3; break;
  case "KeyD": note = 4; break;
  case "KeyC": note = 5; break;
  case "KeyV": note = 6; break;
  case "KeyG": note = 7; break;
  case "KeyB": note = 8; break;
  case "KeyH": note = 9; break;
  case "KeyN": note = 10; break;
  case "KeyJ": note = 11; break;
  case "KeyM": note = 12; break;
  // Keys that overlap imto octave 2.
  case "Comma": note = 13; break;
  case "KeyL": note = 14; break;
  case "Period": note = 15; break;
  case "Semicolon": note = 16; break;
  case "Slash": note = 17; break;
  // Octave 2.
  case "KeyQ": note = 13; break;
  case "Digit2": note = 14; break;
  case "KeyW": note = 15; break;
  case "Digit3": note = 16; break;
  case "KeyE": note = 17; break;
  case "KeyR": note = 18; break;
  case "Digit5": note = 19; break;
  case "KeyT": note = 20; break;
  case "Digit6": note = 21; break;
  case "KeyY": note = 22; break;
  case "Digit7": note = 23; break;
  case "KeyU": note = 24; break;
  // Keys that overlap imto octave 3.
  case "KeyI": note = 25; break;
  case "Digit9": note = 26; break;
  case "KeyO": note = 27; break;
  case "Digit0": note = 28; break;
  case "KeyP": note = 29; break;
  case "BracketLeft": note = 30; break;
  case "Equal": note = 31; break;
  case "BracketRight": note = 32; break;
  }

  if (note != 0) {
    note--;
    window.beebmod_port.postMessage(
        ["PLAY_SAMPLE", channel, sample_index, note]);
  }
  channel++;
  if (channel == 4) {
    channel = 0;
  }
  window.beebmod_play_sample_channel = channel;
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
