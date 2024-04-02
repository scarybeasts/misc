"use strict";

function MODPlayerAmiga(modfile) {
  this.ctx = null;
  this.modfile = modfile;
  this.position = 0;
  this.row_index = 0;
  this.pattern = null;
  this.row = null;

  this.rate = 0;
  this.host_samples_per_tick = 0;
  this.host_samples_counter = 0;
  
  this.samples = new Array(4);
  this.sample_lengths = new Uint16Array(4);
  this.sample_indexes = new Int32Array(4);
  this.sample_periods = new Uint16Array(4);
  this.sample_counters = new Int16Array(4);
  this.outputs = new Float32Array(4);

  for (let i = 0; i < 4; ++i) {
    this.samples[i] = null;
    this.sample_lengths[i] = 0;
    this.sample_indexes[i] = -1;
    this.sample_periods[i] = 0;
    this.sample_counters[i] = 0;
    this.outputs[i] = 0.0;
  }

  this.loadRow();
}

MODPlayerAmiga.prototype.loadRow = function() {
  const modfile = this.modfile;
  let num_patterns = modfile.getNumPatterns();
  let position = this.position;
  let pattern_index = modfile.getPatternIndex(position);
  if (pattern_index >= num_patterns) {
    pattern_index = 0;
  }
  const pattern = modfile.getPattern(pattern_index);
  this.pattern = pattern;
  let row_index = this.row_index;
  const row = pattern.getRow(row_index);
  row_index++;
  if (row_index == 64) {
    row_index = 0;
    position++;
    if (position == 128) {
      position = 0;
    }
    this.position = position;
  }
  this.row_index = row_index;

  for (let i = 0; i < 4; ++i) {
    const note = row.getChannel(i);
    let sample_index = note.sample;
    if ((sample_index > 0) && (sample_index < 31)) {
      sample_index--;
      const period = note.period;
      const sample = modfile.getSample(sample_index);
      this.samples[i] = sample;
      this.sample_lengths[i] = sample.length;
      this.sample_periods[i] = period;
      this.sample_counters[i] = period;
      if (sample.length > 0) {
        this.sample_indexes[i] = 0;
        this.loadOutput(i);
      } else {
        this.sample_indexes[i] = -1;
        this.outputs[i] = 0.0;
      }
    }
  }
}

MODPlayerAmiga.prototype.loadOutput = function(channel) {
  let index = this.sample_indexes[channel];
  let s8_value = this.samples[channel].binary[index];
  let float_value;
  // Map to -0.25 -> 0.25.
  if (s8_value <= 127) {
    float_value = (s8_value / 508.0);
  } else {
    float_value = ((s8_value - 256) / 512.0);
  }
  this.outputs[channel] = float_value;
}

MODPlayerAmiga.prototype.play = function() {
  // Sample ticks are based on 28.63636 MHz (NTSC) or 28.37516 MHz (PAL) main
  // oscillator, divided by 8.
  // We'll use PAL.
  // That's a tick rate of 3546895Hz.
  // We'll subdivide by 50 to get a rate the host audio subsystem will accept:
  // 70938Hz.
  this.rate = 70938;

  // Song ticks are 50Hz.
  // The song speed (SPD) is defined as how many 50Hz ticks pass between
  // pattern rows. By default, SPD is 6.
  // So rate / (50 / 6) is the number of host audio samples between pattern
  // rows.
  this.host_samples_per_tick = 8513;
  this.host_samples_counter = this.host_samples_per_tick;

  let options = new Object();
  options.sampleRate = this.rate;
  options.latencyHint = "playback";
  let ctx = new AudioContext(options);
  // Custom property.
  ctx.player = this;
  this.ctx = ctx;

  let processor = ctx.createScriptProcessor(16384, 1, 1);
  processor.addEventListener("audioprocess", audio_process);
  processor.connect(ctx.destination);
}

function audio_process(event) {
  const player = event.target.context.player;
  const outputBuffer = event.outputBuffer;
  const data = outputBuffer.getChannelData(0);
  let host_samples_counter = player.host_samples_counter;

  for (let i = 0; i < data.length; ++i) {
    let value = 0.0;
    for (let j = 0; j < 4; ++j) {
      value += player.outputs[j];
      let index = player.sample_indexes[j];
      if (index == -1) {
        continue;
      }
      let counter = player.sample_counters[j];
      counter -= 50;
      if (counter > 0) {
        player.sample_counters[j] = counter;
        continue;
      }
      counter += player.sample_periods[j];
      player.sample_counters[j] = counter;
      index++;
      if (index < player.sample_lengths[j]) {
        player.sample_indexes[j] = index;
        player.loadOutput(j);
      } else {
        player.sample_indexes[j] = -1;
        player.outputs[j] = 0.0;
      }
    }

    data[i] = value;

    host_samples_counter--;
    if (host_samples_counter == 0) {
      host_samples_counter = player.host_samples_per_tick;
      player.loadRow();
    }
  }

  player.host_samples_counter = host_samples_counter;
}
