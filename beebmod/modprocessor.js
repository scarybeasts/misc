"use strict";

class MODProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.port.onmessage = this.handleMessage.bind(this);

    // Song data.
    this.samples = new Array(32);
    this.num_patterns = 0;
    this.num_positions = 0;
    this.patterns = new Array(256);
    this.positions = new Uint8Array(256);

    // Play state.
    this.is_playing = false;
    this.rate = sampleRate;
    this.mod_position = 0;
    this.mod_pattern_index = 0;
    this.mod_pattern = null;
    this.mod_row_index = 0;
    this.mod_speed = 0;
    this.mod_sample = new Array(4);
    this.mod_sample_end = new Uint16Array(4);
    this.mod_sample_repeat_start = new Uint16Array(4);
    this.mod_sample_repeat_length = new Uint16Array(4);
    this.mod_sample_index = new Uint16Array(4);
    this.mod_period = new Uint16Array(4);
    this.host_samples_per_row = 0;
    this.host_samples_counter = 0;

    // Use sample 0, which isn't a valid MOD sample number, to point to a
    // silent sample. This enables a more streamlined play path without so
    // many checks and branches.
    const sample0 = new Object();
    sample0.binary = new Uint8Array(65535);
    sample0.name = "[internal silence]";
    sample0.volume = 64;
    sample0.repeat_start = 0;
    sample0.repeat_length = 65535;
    this.samples[0] = sample0;

    this.setupAmiga();

    this.handleReset(0, 0);

    console.log("AudioWorklet rate: " + sampleRate);
  }

  process(inputs, outputs, parameters) {
    if (this.is_playing == false) {
      return true;
    }

    const output = outputs[0];
    const output_channel = output[0];
    const length = output_channel.length;

    let host_samples_counter = this.host_samples_counter;
    const amiga_clocks_per_host_sample = this.amiga_clocks_per_host_sample;

    let sample0 = this.mod_sample[0];
    let sample1 = this.mod_sample[1];
    let sample2 = this.mod_sample[2];
    let sample3 = this.mod_sample[3];
    let counter0 = this.amiga_counters[0];
    let counter1 = this.amiga_counters[1];
    let counter2 = this.amiga_counters[2];
    let counter3 = this.amiga_counters[3];

    let do_reload_value = true;

    let value;

    for (let i = 0; i < length; ++i) {
      if (do_reload_value) {
        do_reload_value = false;
        value = sample0[this.mod_sample_index[0]];
        value += sample1[this.mod_sample_index[1]];
        value += sample2[this.mod_sample_index[2]];
        value += sample3[this.mod_sample_index[3]];
        // Value is -512 to 508.
        // Convert to -1.0 to +1.0.
        value = (value / 512.0);
      }

      output_channel[i] = value;

      counter0 -= amiga_clocks_per_host_sample;
      while (counter0 <= 0) {
        counter0 += this.mod_period[0];
        this.mod_sample_index[0]++;
        if (this.mod_sample_index[0] == this.mod_sample_end[0]) {
          if (this.mod_sample_repeat_length[0] > 2) {
            const repeat_start = this.mod_sample_repeat_start[0];
            this.mod_sample_index[0] = repeat_start;
            this.mod_sample_end[0] =
                (repeat_start + this.mod_sample_repeat_length[0]);
          } else {
            this.loadMODSample(0, 0, 65535);
            sample0 = this.mod_sample[0];
          }
        }
        do_reload_value = true;
      }
      counter1 -= amiga_clocks_per_host_sample;
      while (counter1 <= 0) {
        counter1 += this.mod_period[1];
        this.mod_sample_index[1]++;
        if (this.mod_sample_index[1] == this.mod_sample_end[1]) {
          if (this.mod_sample_repeat_length[1] > 2) {
            const repeat_start = this.mod_sample_repeat_start[1];
            this.mod_sample_index[1] = repeat_start;
            this.mod_sample_end[1] =
                (repeat_start + this.mod_sample_repeat_length[1]);
          } else {
            this.loadMODSample(1, 0, 65535);
            sample1 = this.mod_sample[1];
          }
        }
        do_reload_value = true;
      }
      counter2 -= amiga_clocks_per_host_sample;
      while (counter2 <= 0) {
        counter2 += this.mod_period[2];
        this.mod_sample_index[2]++;
        if (this.mod_sample_index[2] == this.mod_sample_end[2]) {
          if (this.mod_sample_repeat_length[2] > 2) {
            const repeat_start = this.mod_sample_repeat_start[2];
            this.mod_sample_index[2] = repeat_start;
            this.mod_sample_end[2] =
                (repeat_start + this.mod_sample_repeat_length[2]);
          } else {
            this.loadMODSample(2, 0, 65535);
            sample2 = this.mod_sample[2];
          }
        }
        do_reload_value = true;
      }
      counter3 -= amiga_clocks_per_host_sample;
      while (counter3 <= 0) {
        counter3 += this.mod_period[3];
        this.mod_sample_index[3]++;
        if (this.mod_sample_index[3] == this.mod_sample_end[3]) {
          if (this.mod_sample_repeat_length[3] > 2) {
            const repeat_start = this.mod_sample_repeat_start[3];
            this.mod_sample_index[3] = repeat_start;
            this.mod_sample_end[3] =
                (repeat_start + this.mod_sample_repeat_length[3]);
          } else {
            this.loadMODSample(3, 0, 65535);
            sample3 = this.mod_sample[3];
          }
        }
        do_reload_value = true;
      }

      host_samples_counter--;
      if (host_samples_counter == 0) {
        host_samples_counter = this.host_samples_per_row;
        this.loadMODRowAndAdvance();
        sample0 = this.mod_sample[0];
        sample1 = this.mod_sample[1];
        sample2 = this.mod_sample[2];
        sample3 = this.mod_sample[3];
        counter0 = this.amiga_counters[0];
        counter1 = this.amiga_counters[1];
        counter2 = this.amiga_counters[2];
        counter3 = this.amiga_counters[3];
        do_reload_value = true;
      }
    }

    this.host_samples_counter = host_samples_counter;
    this.mod_sample[0] = sample0;
    this.mod_sample[1] = sample1;
    this.mod_sample[2] = sample2;
    this.mod_sample[3] = sample3;
    this.amiga_counters[0] = counter0;
    this.amiga_counters[1] = counter1;
    this.amiga_counters[2] = counter2;
    this.amiga_counters[3] = counter3;

    return true;
  }

  handleMessage(event) {
    const data_array = event.data;
    const name = data_array[0];
    if (name == "RESET") {
      const num_patterns = data_array[1];
      const num_positions = data_array[2];
      this.handleReset(num_patterns, num_positions);
    } else if (name == "SAMPLE") {
      const index = data_array[1];
      const sample = data_array[2];
      if ((index > 0) && (index < 32)) {
        this.samples[index] = sample;
      }
    } else if (name == "PATTERN") {
      const index = data_array[1];
      const pattern = data_array[2];
      this.patterns[index] = pattern;
    } else if (name == "POSITION") {
      const index = data_array[1];
      const pattern_index = data_array[2];
      this.positions[index] = pattern_index;
    } else if (name == "PLAY") {
      const position = data_array[1];
      this.handlePlay(position);
    } else if (name == "STOP") {
      this.is_playing = false;
    } else {
      console.log("unknown command: " + name);
    }
  }

  handleReset(num_patterns, num_positions) {
    this.num_patterns = num_patterns;
    this.num_positions = num_positions;

    const sample0 = this.samples[0];
    for (let i = 0; i < 4; ++i) {
      this.loadMODSample(i, 0, 65535);
    }
  }

  handlePlay(position) {
    this.setMODPosition(position);

    // Song ticks are 50Hz.
    // The song speed (SPD) is defined as how many 50Hz ticks pass between
    // pattern rows. By default, SPD is 6.
    // A great summary of row timing may be found here:
    // https://modarchive.org/forums/index.php?topic=2709.0
    // This must be called before loadMODRow() in case that changes speed.
    this.setMODSpeed(6);

    this.loadMODRowAndAdvance();

    this.is_playing = true;
  }

  loadMODRowAndAdvance() {
    const pattern = this.mod_pattern;
    var mod_row_index = this.mod_row_index;
    if (mod_row_index == 0) {
      console.log("playing position: " +
                  this.mod_position +
                  ", pattern: " +
                  this.mod_pattern_index);
    }
    const row = pattern.rows[mod_row_index];

    mod_row_index++;
    if (mod_row_index == 64) {
      mod_row_index = 0;
      this.setMODPosition(this.mod_position + 1);
    }
    this.mod_row_index = mod_row_index;

    for (let i = 0; i < 4; ++i) {
      const note = row.channels[i];
  
      let period = note.period; 
      let sample_index = note.sample;
      
      // Always set the period even if there's no sample specified.
      // Example: winners.mod (position 21 / pattern 15)
      // BassoonTracker seems to change the period and leave the current sample
      // playing at its current position. That's what we do.
      // If there's a sample with no period, we start the sample with the
      // current channel period.
      // Example: anar13.mod (first position)
      // Seems like there's some behavior difference depending on ProTracker
      // version, so we can pick anything sensible.
      // See:
      // https://www.stef.be/bassoontracker/docs/trackerQuircks.txt
      if (period != 0) {
        this.mod_period[i] = period;
      } else {
        period = this.mod_period[i];
      }

      if ((sample_index > 0) && (sample_index < 32)) {
        this.loadMODSample(i, sample_index, period);
      }

      const command = note.command;
      const major_command = (command >> 8);
      const minor_command = (command & 0xFF);
      switch (major_command) {
      // Jump to specific row in next song position.
      // Example: moondark.mod (first position)
      case 0xD:
        // TODO: what if this occurred at the last row index 63. Would it skip
        // 2 positions or 1?
        if (mod_row_index == 0) {
          alert("command 0xDxx at row index 63");
        }
        this.setMODPosition(this.mod_position + 1);
        // TODO: what if the row index is out of bounds? Is it just masked?
        if (minor_command > 63) {
          alert("command 0xDxx with excessive row index");
        }
        this.mod_row_index = minor_command;
        break;
      // Set speed (minor 0x00-0x1F) or tempo (minor 0x20-0xFF).
      // Example: winners.mod (first position)
      case 0xF:
        if (minor_command == 0) {
          alert("command 0xF00");
        }
        if (minor_command < 0x20) {
          this.setMODSpeed(minor_command);
        }
        break;
      }
    }
  }

  loadMODSample(channel, sample_index, period) {
    const sample = this.samples[sample_index];
    this.mod_sample[channel] = sample.binary;
    this.mod_sample_end[channel] = sample.binary.length;
    this.mod_sample_repeat_start[channel] = sample.repeat_start;
    this.mod_sample_repeat_length[channel] = sample.repeat_length;
    this.mod_sample_index[channel] = 0;
    this.mod_period[channel] = period;
    this.amiga_counters[channel] = period;
  }

  setMODPosition(position) {
    const num_positions = this.num_positions;
    if (position == 0) {
      position = 1;
    } else if (position > num_positions) {
      position = 1;
    }
    this.mod_position = position;
    const pattern_index = this.positions[position - 1];
    const pattern = this.patterns[pattern_index];
    this.mod_pattern_index = pattern_index;
    this.mod_pattern = pattern;
    this.mod_row_index = 0;
  }

  setMODSpeed(speed) {
    // speed, aka. SPD, is the number of 50Hz ticks between pattern rows.
    this.mod_speed = speed;
    this.host_samples_per_row = Math.round((this.rate / 50) * speed);
    this.host_samples_counter = this.host_samples_per_row;
  }

  setupAmiga() {
    this.amiga_counters = new Float32Array(4);

    // This is the rate of "period" ticks that are used to represent note
    // frequencies in a MOD file.
    // See:
    // https://forum.amiga.org/index.php?topic=62974.0
    // This gives playback rates of MOD notes:
    // C-1  =   4143Hz  (period 856) (lowest)
    // C-2  =   8287Hz  (period 428)
    // C-3  =  16574Hz  (period 214)
    // B-3  =  31377Hz  (period 113) (highest)
    const amiga_clocks = (28375160.0 / 8.0);
    const amiga_clocks_per_host_sample = (amiga_clocks / this.rate);
    this.amiga_clocks_per_host_sample = amiga_clocks_per_host_sample;
  }
}

registerProcessor("modprocessor", MODProcessor);
