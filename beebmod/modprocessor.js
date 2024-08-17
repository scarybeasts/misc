"use strict";

class MODProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.port.onmessage = this.handleMessage.bind(this);

    // Song data.
    this.samples = new Array(32);
    for (let i = 0; i < 32; ++i) {
      this.samples[i] = null;
    }
    this.num_patterns = 0;
    this.num_positions = 0;
    this.patterns = new Array(256);
    for (let i = 0; i < 256; ++i) {
      this.patterns[i] = null;
    }
    this.positions = new Uint8Array(256);

    // State the main page can configure.
    this.is_channel_playing = new Uint8Array(4);
    this.sample_effect = new Uint8Array(32);
    for (let i = 0; i < 4; ++i) {
      this.is_channel_playing[i] = 1;
    }

    // Play state.
    this.is_amiga = true;
    this.beeb_channels = 1;
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
    this.mod_sample_index = new Int32Array(4);
    this.mod_sample_effect_table = new Array(4);
    this.mod_period = new Uint16Array(4);
    this.mod_portamento = new Int16Array(4);
    this.mod_portamento_target = new Uint16Array(4);
    this.s8_outputs = new Int8Array(4);
    for (let i = 0; i < 4; ++i) {
      this.mod_sample[i] = null;
      this.mod_sample_effect_table[i] = null;
    }

    this.host_samples_per_tick = 0;
    this.host_samples_counter = 0;
    this.mod_ticks_counter = 0;

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

    // Note (C-1, C#-1, D-1, ... etc.) to period mapping.
    this.note_to_period = new Uint16Array(
        [856,808,762,720,678,640,604,570,538,508,480,453,
         428,404,381,360,339,320,302,285,269,254,240,226,
         214,202,190,180,170,160,151,143,135,127,120,113]);
    this.effects_tables = new Array();

    this.setupEffects();
    this.setupAmiga();
    this.setupBeeb();

    this.handleStop();

    console.log("AudioWorklet rate: " + sampleRate);
  }

  setupEffects() {
    this.effects_tables[0] = null;

    const gain_effect_2x = new Int8Array(256);
    for (let i = 0; i < 256; ++i) {
      let value = (i - 128);
      value = this.effectGain(value, 2);
      gain_effect_2x[i] = value;
    }
    this.effects_tables[1] = gain_effect_2x;

    const gain_effect_4x = new Int8Array(256);
    for (let i = 0; i < 256; ++i) {
      let value = (i - 128);
      value = this.effectGain(value, 4);
      gain_effect_4x[i] = value;
    }
    this.effects_tables[2] = gain_effect_4x;

    const negative_effect = new Int8Array(256);
    for (let i = 0; i < 256; ++i) {
      let value = (i - 128);
      value = Math.abs(value);
      value *= -1;
      negative_effect[i] = value;
    }
    this.effects_tables[3] = negative_effect;

    const boost_effect = new Int8Array(256);
    for (let i = 0; i < 256; ++i) {
      let value = (i - 128);
      let sign = Math.sign(value);
      let abs = Math.abs(value);
      let mag = Math.pow(abs, 0.5);
      value = (mag / Math.pow(128, 0.5));
      value *= 128;
      value *= sign;
      value = Math.round(value);
      boost_effect[i] = value;
    }
    this.effects_tables[4] = boost_effect;
  }

  effectGain(value, gain) {
    value *= gain;
    if (value > 127) {
      value = 127;
    } else if (value < -128) {
      value = -128;
    }
    return value;
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

  setupBeeb() {
    // Calculated tables.
    this.beeb_period_advances = new Uint16Array(1024);
    this.beeb_sn_vol_to_output = new Float64Array(16);
    this.beeb_u8_to_sn_vol = new Uint8Array(256);
    this.beeb_u8_to_sn_vol_pair1 = new Int8Array(256);
    this.beeb_u8_to_sn_vol_pair2 = new Int8Array(256);
    this.beeb_u8_to_sn_vol_trio1 = new Int8Array(256);
    this.beeb_u8_to_sn_vol_trio2 = new Int8Array(256);
    this.beeb_u8_to_sn_vol_trio3 = new Int8Array(256);

    // Player state.
    this.beeb_sn_is_highs = new Uint8Array(4);
    this.beeb_sn_vols = new Uint8Array(4);
    this.beeb_sn_counters = new Uint8Array(4);
    this.beeb_mod_sample_subindexes = new Uint8Array(4);
    this.beeb_channel_advances_lo = new Uint8Array(4);
    this.beeb_channel_advances_hi = new Uint8Array(4);
    this.beeb_samples_total = 0;

    // Build the mapping of the beeb's 16 output levels to a u8 value.
    const beeb_sn_volume_exponent = -0.1;
    for (let i = 0; i < 15; ++i) {
      const exponent = (i * beeb_sn_volume_exponent);
      const float_value = Math.pow(10.0, exponent);
      this.beeb_sn_vol_to_output[i] = float_value;
    }
    this.beeb_sn_vol_to_output[0xF] = 0.0;

    // Build the mapping of requested sample u8 output level to available
    // SN volume level.
    // NOTE: there's room for more experimentation with this mapping to see
    // if there's any tricks to get it to sound better.
    let current_vol = 0x10;
    let next_target = 0;
    for (let i = 0; i < 256; ++i) {
      if (i == next_target) {
        current_vol--;
        const this_level =
            Math.round(this.beeb_sn_vol_to_output[current_vol] * 255);
        const next_level =
            Math.round(this.beeb_sn_vol_to_output[current_vol - 1] * 255);
        next_target = Math.round((this_level + next_level) / 2);
      }
      this.beeb_u8_to_sn_vol[i] = current_vol;
    }

    // Build the mapping of requested output level to 2 merged channels.
    for (let i = 0; i < 256; ++i) {
      this.beeb_u8_to_sn_vol_pair1[i] = -1;
      this.beeb_u8_to_sn_vol_pair2[i] = -1;
    }
    for (let i = 0; i < 16; ++i) {
      for (let j = 0; j < 16; ++j) {
        // Individual channel outputs must be similar to one another,
        // otherwise there's wild hiss and crackle.
        if (j < i) continue;
        if (j > (i + 1)) continue;
        // Range is 0.0 to 2.0.
        const output =
            (this.beeb_sn_vol_to_output[i] + this.beeb_sn_vol_to_output[j]);
        const u8_output = Math.round(output / 2.0 * 255.0);
        this.beeb_u8_to_sn_vol_pair1[u8_output] = i;
        this.beeb_u8_to_sn_vol_pair2[u8_output] = j;
      }
    }
    let current_vol1 = -1;
    let current_vol2 = -1;
    let current_vol3 = -1;
    let unique_values = 0;
    for (let i = 0; i < 256; ++i) {
      if (this.beeb_u8_to_sn_vol_pair1[i] != -1) {
        unique_values++;
        current_vol1 = this.beeb_u8_to_sn_vol_pair1[i];
        current_vol2 = this.beeb_u8_to_sn_vol_pair2[i];
console.log(i + ": " + current_vol1 + ", " + current_vol2);
      }
      this.beeb_u8_to_sn_vol_pair1[i] = current_vol1;
      this.beeb_u8_to_sn_vol_pair2[i] = current_vol2;
    }
console.log("unique values: " + unique_values);

    // Build the mapping of requested output level to 3 merged channels.
    for (let i = 0; i < 256; ++i) {
      this.beeb_u8_to_sn_vol_trio1[i] = -1;
      this.beeb_u8_to_sn_vol_trio2[i] = -1;
      this.beeb_u8_to_sn_vol_trio3[i] = -1;
    }
    for (let i = 0; i < 16; ++i) {
      for (let j = 0; j < 16; ++j) {
        for (let k = 0; k < 16; ++k) {
          // Individual channel outputs must be similar to one another,
          // otherwise there's wild hiss and crackle.
          if (j < i) continue;
          if (k < j) continue;
          if (j > (i + 1)) continue;
          if (k > (i + 1)) continue;
          // Range is 0.0 to 3.0.
          const output =
              (this.beeb_sn_vol_to_output[i] +
               this.beeb_sn_vol_to_output[j] +
               this.beeb_sn_vol_to_output[k]);
          const u8_output = Math.round(output / 3.0 * 255.0);
          this.beeb_u8_to_sn_vol_trio1[u8_output] = i;
          this.beeb_u8_to_sn_vol_trio2[u8_output] = j;
          this.beeb_u8_to_sn_vol_trio3[u8_output] = k;
        }
      }
    }
    current_vol1 = -1;
    current_vol2 = -1;
    current_vol3 = -1;
    unique_values = 0;
    for (let i = 0; i < 256; ++i) {
      if (this.beeb_u8_to_sn_vol_trio1[i] != -1) {
        unique_values++;
        current_vol1 = this.beeb_u8_to_sn_vol_trio1[i];
        current_vol2 = this.beeb_u8_to_sn_vol_trio2[i];
        current_vol3 = this.beeb_u8_to_sn_vol_trio3[i];
console.log(i + ": " + current_vol1 + ", " + current_vol2 + ", " + current_vol3);
      }
      this.beeb_u8_to_sn_vol_trio1[i] = current_vol1;
      this.beeb_u8_to_sn_vol_trio2[i] = current_vol2;
      this.beeb_u8_to_sn_vol_trio3[i] = current_vol3;
    }
console.log("unique values: " + unique_values);

    // Build the mapping of MOD periods to beeb advance increments.
    const amiga_clocks = (28375160.0 / 8.0);
    // 7.8kHz.
    const beeb_freq = (2000000 / 64 / 4);
    for (let i = 113; i <= 856; ++i) {
      const freq = (amiga_clocks / i);
      const advance_float = (freq / beeb_freq * 256);
      const advance = Math.round(advance_float);
      this.beeb_period_advances[i] = advance;
    }

    this.resetBeeb();
  }

  process(inputs, outputs, parameters) {
    const output = outputs[0];
    const output_channel = output[0];
    const length = output_channel.length;

    const is_amiga = this.is_amiga;

    let value;

    for (let i = 0; i < length; ++i) {
      if (is_amiga) {
        value = this.processAmiga();
      } else {
        value = this.processBeeb();
      }

      output_channel[i] = value;

      this.host_samples_counter--;
      if (this.host_samples_counter == 0) {
        // Do 50Hz tick effects.
        for (let j = 0; j < 4; ++j) {
          const portamento = this.mod_portamento[j];
          if (portamento == 0) {
            continue;
          }
          let period = this.mod_period[j];
          period += portamento;
          const target = this.mod_portamento_target[j];
          if (target != 0) {
            if (((portamento > 0) && (period >= target)) ||
                (period <= target)) {
              period = target;
              this.mod_portamento[j] = 0;
            }
          }
          this.setMODPeriod(j, period);
        }

        // Check if it's a song SPEED tick.
        this.host_samples_counter = this.host_samples_per_tick;
        this.mod_ticks_counter--;
        if (this.mod_ticks_counter == 0) {
          this.mod_ticks_counter = this.mod_speed;

          this.mod_portamento[0] = 0;
          this.mod_portamento[1] = 0;
          this.mod_portamento[2] = 0;
          this.mod_portamento[3] = 0;

          if (this.is_playing) {
            this.loadMODRowAndAdvance();
          }
        }
      }
    }

    return true;
  }

  processAmiga() {
    const amiga_clocks_per_host_sample = this.amiga_clocks_per_host_sample;

    this.amiga_counters[0] -= amiga_clocks_per_host_sample;
    while (this.amiga_counters[0] <= 0) {
      this.amiga_counters[0] += this.mod_period[0];
      this.advanceGeneric(0);
    }
    this.amiga_counters[1] -= amiga_clocks_per_host_sample;
    while (this.amiga_counters[1] <= 0) {
      this.amiga_counters[1] += this.mod_period[1];
      this.advanceGeneric(1);
    }
    this.amiga_counters[2] -= amiga_clocks_per_host_sample;
    while (this.amiga_counters[2] <= 0) {
      this.amiga_counters[2] += this.mod_period[2];
      this.advanceGeneric(2);
    }
    this.amiga_counters[3] -= amiga_clocks_per_host_sample;
    while (this.amiga_counters[3] <= 0) {
      this.amiga_counters[3] += this.mod_period[3];
      this.advanceGeneric(3);
    }

    let value = this.s8_outputs[0];
    value += this.s8_outputs[1];
    value += this.s8_outputs[2];
    value += this.s8_outputs[3];
    // Value is -512 to 508.
    // Convert to 0 to 0.5, which gives a similar volume output to the beeb
    // players, thus enabling better direct comparisons.
    value += 512.0;
    value /= 1020.0;
    value /= 2.0;

    return value;
  }

  advanceGeneric(channel) {
    let index = this.mod_sample_index[channel];
    index++;
    if (index == this.mod_sample_end[channel]) {
      if (this.mod_sample_repeat_length[channel] > 2) {
        const repeat_start = this.mod_sample_repeat_start[channel];
        index = repeat_start;
        this.mod_sample_end[channel] =
            (repeat_start + this.mod_sample_repeat_length[channel]);
      } else {
        this.loadSilentMODSample(channel);
        index = this.mod_sample_index[channel];
      }
    }
    let s8_output = this.mod_sample[channel][index];
    const effect_table = this.mod_sample_effect_table[channel];
    if (effect_table != null) {
      // Need to convert to u8 for an index into the lookup table.
      const u8_index = (s8_output + 128);
      s8_output = effect_table[u8_index];
    }
    this.s8_outputs[channel] = s8_output;
    this.mod_sample_index[channel] = index;
  }

  processBeeb() {
    this.beeb_sn_cycles_counter--;
    if (this.beeb_sn_cycles_counter == 0) {
      // A new command can be given to the SN chip once every 8 SN cycles,
      // which is 32us / 31.25kHz.
      this.beeb_sn_cycles_counter = 8;

      let channel = this.beeb_sn_channel;
      if (this.beeb_channels > 1) {
        if (channel == 0) {
          this.advanceBeeb(0);
          this.advanceBeeb(1);
          this.advanceBeeb(2);
          this.advanceBeeb(3);
          // Range is 0 - 252, midpoint of 128.
          let samples_total = ((this.s8_outputs[0] + 128) >> 2);
          samples_total += ((this.s8_outputs[1] + 128) >> 2);
          samples_total += ((this.s8_outputs[2] + 128) >> 2);
          samples_total += ((this.s8_outputs[3] + 128) >> 2);
          // Center midpoint to 0.
          // Range is -128 to 124.
          samples_total -= 128;
          // Apply gain.
          // Range is -256 to 248.
          // 2x can be too much for some songs.
          samples_total *= 2;
          // Clip.
          if (samples_total < -128) {
            samples_total = -128;
          } else if (samples_total > 127) {
            samples_total = 127;
          }
          // Convert back to u8.
          samples_total += 128;

          this.beeb_samples_total = samples_total;
        }

        const samples_total = this.beeb_samples_total;
        if (this.beeb_channels == 2) {
          if (channel == 0) {
            const sn_vol1 = this.beeb_u8_to_sn_vol_pair1[samples_total];
            this.beeb_sn_vols[0] = sn_vol1;
            // Silence the unused channels in this mode in case coming from a
            // different mode.
            this.beeb_sn_vols[2] = 0xF;
            this.beeb_sn_vols[3] = 0xF;
          } else if (channel == 1) {
            const sn_vol2 = this.beeb_u8_to_sn_vol_pair2[samples_total];
            this.beeb_sn_vols[1] = sn_vol2;
          }
        } else {
          if (channel == 0) {
            const sn_vol1 = this.beeb_u8_to_sn_vol_trio1[samples_total];
            this.beeb_sn_vols[0] = sn_vol1;
            // Silence the unused channels in this mode in case coming from a
            // different mode.
            this.beeb_sn_vols[3] = 0xF;
          } else if (channel == 1) {
            const sn_vol2 = this.beeb_u8_to_sn_vol_trio2[samples_total];
            this.beeb_sn_vols[1] = sn_vol2;
          } else if (channel == 2) {
            const sn_vol3 = this.beeb_u8_to_sn_vol_trio3[samples_total];
            this.beeb_sn_vols[2] = sn_vol3;
          }
        }
      } else {
        this.advanceBeeb(channel);
        const u8_sample_value = (this.s8_outputs[channel] + 128);
        const sn_vol = this.beeb_u8_to_sn_vol[u8_sample_value];
        this.beeb_sn_vols[channel] = sn_vol;
      }

      channel++;
      if (channel == 4) {
        channel = 0;
      }
      this.beeb_sn_channel = channel;
    }

    let value = 0;
    if (this.beeb_sn_is_highs[0]) {
      value += this.beeb_sn_vol_to_output[this.beeb_sn_vols[0]];
    }
    if (this.beeb_sn_is_highs[1]) {
      value += this.beeb_sn_vol_to_output[this.beeb_sn_vols[1]];
    }
    if (this.beeb_sn_is_highs[2]) {
      value += this.beeb_sn_vol_to_output[this.beeb_sn_vols[2]];
    }
    if (this.beeb_sn_is_highs[3]) {
      value += this.beeb_sn_vol_to_output[this.beeb_sn_vols[3]];
    }
    // Divide in a way that leads to similar volume levels across all players.
    if (this.beeb_channels == 1) {
      value /= 3.0;
    } else if (this.beeb_channels == 2) {
      value /= 2.0;
    } else {
      value /= 3.0;
    }

    this.beeb_sn_counters[0]--;
    if (this.beeb_sn_counters[0] == 0) {
      this.beeb_sn_counters[0] = 2;
      this.beeb_sn_is_highs[0] = !this.beeb_sn_is_highs[0];
    }
    this.beeb_sn_counters[1]--;
    if (this.beeb_sn_counters[1] == 0) {
      this.beeb_sn_counters[1] = 3;
      this.beeb_sn_is_highs[1] = !this.beeb_sn_is_highs[1];
    }
    this.beeb_sn_counters[2]--;
    if (this.beeb_sn_counters[2] == 0) {
      this.beeb_sn_counters[2] = 1;
      this.beeb_sn_is_highs[2] = !this.beeb_sn_is_highs[2];
    }
    this.beeb_sn_counters[3]--;
    if (this.beeb_sn_counters[3] == 0) {
      this.beeb_sn_counters[3] = 1;
      this.beeb_sn_is_highs[3] = !this.beeb_sn_is_highs[3];
    }

    return value;
  }

  advanceBeeb(channel) {
    let subindex = this.beeb_mod_sample_subindexes[channel];
    subindex += this.beeb_channel_advances_lo[channel];
    if (subindex >= 256) {
      subindex -= 256;
      this.advanceGeneric(channel);
    }
    this.beeb_mod_sample_subindexes[channel] = subindex;
    let index_increment = this.beeb_channel_advances_hi[channel];
    while (index_increment > 0) {
      this.advanceGeneric(channel);
      index_increment--;
    }
  }

  handleMessage(event) {
    const data_array = event.data;
    const name = data_array[0];
    if (name == "NEWSONG") {
      const num_patterns = data_array[1];
      const num_positions = data_array[2];
      this.handleNewSong(num_patterns, num_positions);
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
      this.handleStop();
      this.handlePlay(position);
    } else if (name == "STOP") {
      this.handleStop();
    } else if (name == "AMIGA") {
      this.is_amiga = true;
    } else if (name == "BEEB_SEPARATE") {
      this.is_amiga = false;
      this.beeb_channels = 1;
    } else if (name == "BEEB_MERGED2") {
      this.is_amiga = false;
      this.beeb_channels = 2;
    } else if (name == "BEEB_MERGED3") {
      this.is_amiga = false;
      this.beeb_channels = 3;
    } else if (name == "PLAY_CHANNEL") {
      const channel = data_array[1];
      const is_play = data_array[2];
      this.is_channel_playing[channel] = is_play;
    } else if (name == "PLAY_SAMPLE") {
      const channel = data_array[1];
      const sample_index = data_array[2];
      const note = data_array[3];
      this.handlePlaySample(channel, sample_index, note);
    } else if (name == "SAMPLE_EFFECT") {
      const sample_index = data_array[1];
      const effect = data_array[2];
      this.sample_effect[sample_index] = effect;
    } else {
      console.log("unknown command: " + name);
    }
  }

  handleNewSong(num_patterns, num_positions) {
    this.num_patterns = num_patterns;
    this.num_positions = num_positions;

    this.handleStop();
  }

  handleStop() {
    this.is_playing = false;

    const sample0 = this.samples[0];
    for (let i = 0; i < 4; ++i) {
      this.loadSilentMODSample(i);
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

  handlePlaySample(channel, sample_index, note) {
    if (sample_index == 0) {
      this.loadSilentMODSample(channel);
    } else {
      const period = this.note_to_period[note];
      this.loadMODSample(channel, sample_index, period);
    }
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
  
      const song_period = note.period;
      const sample_index = note.sample;

      const current_period = this.mod_period[i];
      let new_period = song_period;
      if (new_period == 0) {
        new_period = current_period;
      }
      let new_portamento = 0;

      const command = note.command;
      let major_command = (command >> 8);
      let minor_command = (command & 0xFF);
      switch (major_command) {
      // Portamento up.
      case 0x1:
        new_portamento = -minor_command;
        this.mod_portamento_target[i] = 0;
        break;
      // Portamento down.
      case 0x2:
        new_portamento = minor_command;
        this.mod_portamento_target[i] = 0;
        break;
      // Portamento to note.
      case 0x3:
        // If there's a new target, set it, otherwise this is a continuation.
        if (song_period != 0) {
          this.mod_portamento_target[i] = song_period;
        }
        if (this.mod_portamento_target[i] > current_period) {
          // Sliding positively, which is a portamento down.
          new_portamento = minor_command;
        } else {
          // Sliding negatively, which is a portamento up.
          new_portamento = -minor_command;
        }
        // This command doesn't change the current period.
        new_period = current_period;
        break;
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
      // Misc.
      case 0xE:
        major_command = (minor_command & 0xF0);
        minor_command = (minor_command & 0x0F);
        switch (major_command) {
        // Fineslide up.
        case 0x10:
        {
          new_portamento = -minor_command;
          let target = new_period;
          target -= minor_command;
          this.mod_portamento_target[i] = target;
          break;
        }
        // Fineslide down.
        case 0x20:
        {
          new_portamento = minor_command;
          let target = new_period;
          target += minor_command;
          this.mod_portamento_target[i] = target;
          break;
        }
        default:
          break;
        }
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

      // Always set the period even if there's no sample specified.
      // Example: winners.mod (position 21 / pattern 15)
      this.setMODPeriod(i, new_period);

      if ((sample_index > 0) && (sample_index < 32)) {
        if (this.is_channel_playing[i]) {
          this.loadMODSample(i, sample_index, new_period);
        }
      }
      // Set this last because loadMODSample clears it.
      this.mod_portamento[i] = new_portamento;
    }
  }

  loadMODSample(channel, sample_index, period) {
    const sample = this.samples[sample_index];
    this.mod_sample[channel] = sample.binary;
    this.mod_sample_end[channel] = sample.binary.length;
    this.mod_sample_repeat_start[channel] = sample.repeat_start;
    this.mod_sample_repeat_length[channel] = sample.repeat_length;
    this.mod_sample_index[channel] = -1;
    const effect = this.sample_effect[sample_index];
    const effect_table = this.effects_tables[effect];
    this.mod_sample_effect_table[channel] = effect_table;

    this.setMODPeriod(channel, period);

    this.mod_portamento[channel] = 0;

    // Need to set this to 0 so that our index of -1 gets incremented to 0
    // at first tick.
    this.amiga_counters[channel] = 0;
  }

  loadSilentMODSample(channel) {
    this.loadMODSample(channel, 0, 856);
  }

  setMODPeriod(channel, period) {
    this.mod_period[channel] = period;

    const beeb_period_advance = this.beeb_period_advances[period];
    this.beeb_channel_advances_lo[channel] = (beeb_period_advance & 0xFF);
    this.beeb_channel_advances_hi[channel] = (beeb_period_advance >> 8);
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
    this.mod_ticks_counter = speed;
    this.host_samples_per_tick = Math.round(this.rate / 50);
    this.host_samples_counter = this.host_samples_per_tick;
  }

  resetBeeb() {
    this.beeb_sn_cycles_counter = 1;
    this.beeb_sn_channel = 0;

    for (let i = 0; i < 4; ++i) {
      this.beeb_sn_is_highs[i] = 0;
      // Silent.
      this.beeb_sn_vols[i] = 0xF;
      this.beeb_sn_counters[i] = 1;
      this.beeb_mod_sample_subindexes[i] = 0;
      this.beeb_channel_advances_lo[i] = 0;
      this.beeb_channel_advances_hi[i] = 0;
    }
  }
}

registerProcessor("modprocessor", MODProcessor);
