"use strict";

function MODPlayer(player,
                   modfile,
                   rate,
                   host_play_callback,
                   note_hit_callback) {
  this.player = player;
  this.modfile = modfile;
  this.rate = rate;
  this.host_play_callback = host_play_callback;
  this.note_hit_callback = note_hit_callback;

  this.ctx = null;
  this.position = 0;
  this.row_index = 0;
  this.pattern = null;
  this.row = null;

  this.speed = 0;
  this.host_samples_per_tick = 0;
  this.host_samples_counter = 0;
  
  this.samples = new Array(4);
  this.sample_maxes = new Uint16Array(4);
  this.sample_indexes = new Int32Array(4);
  this.sample_periods = new Uint16Array(4);
  this.outputs = new Int8Array(4);
}

MODPlayer.prototype.loadSample = function(channel, sample_index) {
  const modfile = this.modfile;
  const sample = modfile.getSample(sample_index);
  const length = sample.length;

  this.samples[channel] = sample;
  this.sample_maxes[channel] = length;
  if (length > 0) {
    this.sample_indexes[channel] = 0;
  } else {
    this.sample_indexes[channel] = -1;
  }
  this.loadOutput(channel);
}

MODPlayer.prototype.loadRow = function() {
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
  if (row_index == 0) {
    console.log("playing position: " +
                position +
                ", pattern: " +
                pattern_index);
  }

  row_index++;
  if (row_index == 64) {
    row_index = 0;
    this.incrementPosition();
  }
  this.row_index = row_index;

  for (let i = 0; i < 4; ++i) {
    let do_note_callback = false;
    const note = row.getChannel(i);

    let period = note.period;
    let sample_index = note.sample;

    // Always set the period even if there's no sample specified.
    // Example: winners.mod (position 21 / pattern 15)
    // BassoonTracker seems to change the period and leave the current sample
    // playing at its current position. That's what we do.
    if (period != 0) {
      this.sample_periods[i] = period;
      do_note_callback = true;
    }

    if ((sample_index > 0) && (sample_index < 32)) {
      this.loadSample(i, sample_index);
      do_note_callback = true;
      // If there's a sample with no period, we start the sample with the
      // current channel period.
      // Example: anar13.mod (first position)
      // Seems like there's some behavior difference depending on ProTracker
      // version, so we can pick anything sensible.
      // See:
      // https://www.stef.be/bassoontracker/docs/trackerQuircks.txt
      if (period == 0) {
        period = this.sample_periods[i];
      }
    }

    if (do_note_callback) {
      this.note_hit_callback(i, sample_index, period);
    }

    let command = note.command;
    let major_command = (command >> 8);
    let minor_command = (command & 0xFF);
    switch (major_command) {
    // Jump to specific row in next song position.
    // Example: moondark.mod (first position)
    case 0xD:
      // TODO: what if this occurred at the last row index 63. Would it skip
      // 2 positions or 1?
      if (row_index == 0) {
        alert("command 0xDxx at row index 63");
      }
      this.incrementPosition();
      // TODO: what if the row index is out of bounds? Is it just masked?
      if (minor_command > 63) {
        alert("command 0xDxx with excessive row index");
      }
      this.row_index = minor_command;
      break;
    // Set speed (minor 0x00-0x1F) or tempo (minor 0x20-0xFF).
    // Example: winners.mod (first position)
    case 0xF:
      if (minor_command == 0) {
        alert("command 0xF00");
      }
      if (minor_command < 0x20) {
        this.setSpeed(minor_command);
      }
      break;
    }
  }
}

MODPlayer.prototype.setPosition = function(position) {
  const num_positions = this.modfile.getNumPositions();
  if (position == 0) {
    position = 1;
  } else if (position > num_positions) {
    position = 1;
  }
  this.position = position;
}

MODPlayer.prototype.incrementPosition = function(position) {
  this.setPosition(this.position + 1);
}

MODPlayer.prototype.setSpeed = function(speed) {
  // speed, aka. SPD, is the number of 50Hz ticks between pattern rows.
  this.speed = speed;
  this.host_samples_per_tick = Math.round(this.rate / (50 / speed));
  this.host_samples_counter = this.host_samples_per_tick;
}

MODPlayer.prototype.loadOutput = function(channel) {
  let index = this.sample_indexes[channel];
  if (index == -1) {
    this.outputs[channel] = 0;
  } else {
    this.outputs[channel] = this.samples[channel].binary[index];
  }
}

MODPlayer.prototype.hostSampleTick = function() {
  this.host_samples_counter--;
  if (this.host_samples_counter == 0) {
    this.host_samples_counter = this.host_samples_per_tick;
    this.loadRow();
  }
}

MODPlayer.prototype.advanceSampleIndex = function(channel) {
  let index = this.sample_indexes[channel];
  if (index == -1) {
    return;
  }
  index++;
  if (index == this.sample_maxes[channel]) {
    const sample = this.samples[channel];
    const repeat_length = sample.getRepeatLength();
    if (repeat_length > 2) {
      // TODO: bounds checking here.
      const repeat_start = sample.getRepeatStart();
      index = repeat_start;
      this.sample_maxes[channel] = (repeat_start + repeat_length);
    } else {
      index = -1;
    }
  }
  this.sample_indexes[channel] = index;
  this.loadOutput(channel);
}

MODPlayer.prototype.reset = function() {
  for (let i = 0; i < 4; ++i) {
    this.samples[i] = null;
    this.sample_maxes[i] = 0;
    this.sample_indexes[i] = -1;
    this.sample_periods[i] = 0;
    this.loadOutput(i);
  }

  this.player.reset();
}

MODPlayer.prototype.start = function() {
  this.reset();

  let options = new Object();
  options.sampleRate = this.rate;
  options.latencyHint = "playback";
  let ctx = new AudioContext(options);
  // Custom property.
  ctx.player = this.player;
  this.ctx = ctx;

  let processor = ctx.createScriptProcessor(16384, 0, 1);
  processor.addEventListener("audioprocess", this.host_play_callback);
  processor.connect(ctx.destination);
}

MODPlayer.prototype.playFile = function() {
  if (this.ctx != null) {
     return;
  }

  this.start();

  if (this.position == 0) {
    this.setPosition(1);
  }
  this.row_index = 0;

  // Song ticks are 50Hz.
  // The song speed (SPD) is defined as how many 50Hz ticks pass between
  // pattern rows. By default, SPD is 6.
  // A great summary of row timing may be found here:
  // https://modarchive.org/forums/index.php?topic=2709.0
  this.setSpeed(6);

  // Load the first row to prime things.
  // Must be called after setSpeed() in case in contains a command that affects
  // speed.
  this.loadRow();
}

MODPlayer.prototype.playSample = function(sample_index) {
  if (this.ctx == null) {
    this.start();
  }

  this.loadSample(0, sample_index);
  // C-2
  const period = 428;
  this.sample_periods[0] = period;

  this.note_hit_callback(0, sample_index, period);
}

MODPlayer.prototype.stop = function() {
  const ctx = this.ctx;
  if (ctx == null) {
    return;
  }
  ctx.close();
  this.ctx = null;
  this.position = 0;
}
