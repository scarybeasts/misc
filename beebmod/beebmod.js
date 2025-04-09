"use strict";

async function beebmod() {
  window.beebmod_play_sample_channel = 0;
  window.beebmod_mod_file = null;

  beebmod_setup_listeners();
  // Wait for audio setup to finish because loading a file needs to post
  // information to the AudioWorklet context.
  await beebmod_setup_audio();
  beebmod_set_default_config();
  beebmod_load_initial_file();
}

function beebmod_setup_listeners() {
  const play_button = document.getElementById("play");
  play_button.addEventListener("click", beebmod_button_play);
  const stop_button = document.getElementById("stop");
  stop_button.addEventListener("click", beebmod_button_stop);
  const radio_amiga = document.getElementById("radio_amiga");
  radio_amiga.addEventListener("change", beebmod_radio_amiga);
  const radio_beeb_separate_15k =
      document.getElementById("radio_beeb_separate_15k");
  radio_beeb_separate_15k.addEventListener("change",
                                          beebmod_radio_beeb_separate_15k);
  const radio_beeb_merged2_7k =
      document.getElementById("radio_beeb_merged2_7k");
  radio_beeb_merged2_7k.addEventListener("change",
                                         beebmod_radio_beeb_merged2_7k);
  const radio_beeb_merged2_10k =
      document.getElementById("radio_beeb_merged2_10k");
  radio_beeb_merged2_10k.addEventListener("change",
                                          beebmod_radio_beeb_merged2_10k);
  const radio_beeb_merged2_15k =
      document.getElementById("radio_beeb_merged2_15k");
  radio_beeb_merged2_15k.addEventListener("change",
                                          beebmod_radio_beeb_merged2_15k);
  const radio_beeb_merged3_7k =
      document.getElementById("radio_beeb_merged3_7k");
  radio_beeb_merged3_7k.addEventListener("change",
                                         beebmod_radio_beeb_merged3_7k);
  const radio_beeb_merged3_10k =
      document.getElementById("radio_beeb_merged3_10k");
  radio_beeb_merged3_10k.addEventListener("change",
                                          beebmod_radio_beeb_merged3_10k);
  for (let i = 1; i <= 4; ++i) {
    const checkbox_play = document.getElementById("checkbox_play" + i);
    checkbox_play.addEventListener("change", beebmod_checkbox_play);
  }
  for (let i = 1; i <= 4; ++i) {
    const input_period = document.getElementById("number_period" + i);
    input_period.addEventListener("change", beebmod_number_period);
  }
  const checkbox_filter = document.getElementById("checkbox_filter");
  checkbox_filter.addEventListener("change", beebmod_checkbox_filter);
  const checkbox_volumes = document.getElementById("checkbox_volumes");
  checkbox_volumes.addEventListener("change", beebmod_checkbox_volumes);
  const number_beeb_merged_gain =
      document.getElementById("number_beeb_merged_gain");
  number_beeb_merged_gain.addEventListener("change",
                                           beebmod_number_beeb_merged_gain);
  const number_beeb_offset = document.getElementById("number_beeb_offset");
  number_beeb_offset.addEventListener("change", beebmod_number_beeb_offset);

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
  const filter_node = audio_context.createBiquadFilter();
  filter_node.type = "lowpass";
  filter_node.frequency.value = 48000;
  filter_node.Q.value = 5;
  audio_node.connect(filter_node);
  filter_node.connect(audio_context.destination);

  window.beebmod_audio_context = audio_context;
  window.beebmod_audio_node = audio_node;
  window.beebmod_filter_node = filter_node;
  window.beebmod_port = audio_node.port;
}

function beebmod_set_default_config() {
  beebmod_load_number_config("number_start_position", 1);
  beebmod_load_number_config("number_beeb_merged_gain", 2.0);
  beebmod_load_number_config("number_beeb_offset", 0);
  beebmod_load_number_config("number_period1", 2);
  beebmod_load_number_config("number_period2", 3);
  beebmod_load_number_config("number_period3", 5);
  beebmod_load_number_config("number_period4", 1);
}

function beebmod_load_number_config(name, value) {
  const element = document.getElementById(name);
  element.value = value;
  const event = new Event("change");
  element.dispatchEvent(event);
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
  const volume_input = document.createElement("input");
  volume_input.name = index_string;
  volume_input.type = "number";
  volume_input.value = volume;
  volume_input.addEventListener("change", beebmod_sample_volume_changed);
  volume_cell.appendChild(volume_input);
  const length_cell = row.insertCell(3);
  length_cell.innerText = length.toString();
  const repeat_start_cell = row.insertCell(4);
  repeat_start_cell.innerText = repeat_start.toString();
  const repeat_length_cell = row.insertCell(5);
  repeat_length_cell.innerText = repeat_length.toString();
  const half_res_cell = row.insertCell(6);
  const half_res_checkbox = document.createElement("input");
  half_res_checkbox.name = index_string;
  half_res_checkbox.type = "checkbox";
  half_res_checkbox.checked = false;
  half_res_checkbox.addEventListener("change", beebmod_sample_half_res_changed);
  half_res_cell.appendChild(half_res_checkbox);
  const effect_cell = row.insertCell(7);
  const effect_input = document.createElement("input");
  effect_input.name = index_string;
  effect_input.type = "number";
  effect_input.value = 0;
  effect_input.addEventListener("change", beebmod_sample_effect_changed);
  effect_cell.appendChild(effect_input);
  const play_cell = row.insertCell(8);
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
  window.beebmod_mod_file = null;

  sample_table_clear();

  log("MOD file length: " + binary.length);

  const modfile = new MODFile(binary);
  const ret = modfile.parse();
  if (ret != 1) {
    log("MOD parse failure");
    return;
  }

  window.beebmod_mod_file = modfile;

  const num_positions = modfile.getNumPositions();
  const num_patterns = modfile.getNumPatterns();
  log("Name: " + modfile.getName());
  log("Positions: " + num_positions);
  log("Patterns: " + num_patterns);

  const port = window.beebmod_port;
  port.postMessage(["NEWSONG", num_patterns, num_positions]);

  for (let i = 1; i < 32; ++i) {
    const sample = modfile.getSample(i);
    if (sample == null) {
      continue;
    }
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

function beebmod_radio_beeb_separate_15k() {
  window.beebmod_port.postMessage(["BEEB_SEPARATE_15K"]);
}

function beebmod_radio_beeb_merged2_7k() {
  window.beebmod_port.postMessage(["BEEB_MERGED2_7K"]);
}

function beebmod_radio_beeb_merged2_10k() {
  window.beebmod_port.postMessage(["BEEB_MERGED2_10K"]);
}

function beebmod_radio_beeb_merged2_15k() {
  window.beebmod_port.postMessage(["BEEB_MERGED2_15K"]);
}

function beebmod_radio_beeb_merged3_7k() {
  window.beebmod_port.postMessage(["BEEB_MERGED3_7K"]);
}

function beebmod_radio_beeb_merged3_10k() {
  window.beebmod_port.postMessage(["BEEB_MERGED3_10K"]);
}

function beebmod_checkbox_filter(event) {
  const checked = event.target.checked;
  let frequency;
  if (checked) {
    frequency = 7000;
  } else {
    frequency = 48000;
  }
  window.beebmod_filter_node.frequency.value = frequency;
}

function beebmod_checkbox_volumes(event) {
  const checked = event.target.checked;
  window.beebmod_port.postMessage(["VOLUMES", checked]);
}

function beebmod_number_beeb_merged_gain(event) {
  const target = event.target;
  const value = target.value;
  window.beebmod_port.postMessage(["BEEB_MERGED_GAIN", value]);
}

function beebmod_number_beeb_offset(event) {
  const target = event.target;
  // Need explicit conversion to Number, otherwise negative values were coming
  // in as strings.
  const value = Number(target.value);
  window.beebmod_port.postMessage(["BEEB_OFFSET", value]);
}

function beebmod_checkbox_play(event) {
  const id = event.target.id;
  let channel = Number(id.slice(-1));
  channel--;
  const checked = event.target.checked;
  window.beebmod_port.postMessage(["PLAY_CHANNEL", channel, checked]);
}

function beebmod_number_period(event) {
  const id = event.target.id;
  let channel = Number(id.slice(-1));
  channel--;
  const period = event.target.value;
  window.beebmod_port.postMessage(["SN_PERIOD", channel, period]);
}

function beebmod_play_sample(event) {
  const name = event.target.name;
  const sample_index = Number(name);
  const key_code = event.code;
  let channel = window.beebmod_play_sample_channel;

  let note = 0;
  let do_silence = 0;
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
  case "Space": do_silence = 1; break;
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
  if (do_silence) {
    for (let i = 0; i < 4; ++i) {
      window.beebmod_port.postMessage(["PLAY_SAMPLE", i, 0, 0]);
    }
    channel = 0;
  }
  window.beebmod_play_sample_channel = channel;
}

function beebmod_sample_half_res_changed(event) {
  const target = event.target;
  const name = target.name;
  const sample_index = Number(name);
  const checked = target.checked;
  window.beebmod_port.postMessage(["SAMPLE_HALF_RES", sample_index, checked]);
}

function beebmod_sample_effect_changed(event) {
  const target = event.target;
  const name = target.name;
  const sample_index = Number(name);
  const value = target.value;
  window.beebmod_port.postMessage(["SAMPLE_EFFECT", sample_index, value]);
}

function beebmod_sample_volume_changed(event) {
  const target = event.target;
  const name = target.name;
  const sample_index = Number(name);
  const value = target.value;
  window.beebmod_port.postMessage(["SAMPLE_VOLUME", sample_index, value]);
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
