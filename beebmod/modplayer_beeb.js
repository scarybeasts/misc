"use strict";

function MODPlayerBeeb(modfile, is_merged) {
  // The SN76489 runs at 250kHz.
  // The beeb driver for sampled output will typically set the SN period to 1,
  // meaning that a 125kHz square wave is ouput (because the SN at period 1
  // will invert the channel on/off at 250kHz).
  // Sampled output is then achieved by rapidly modulating the volume of the
  // 125kHz square wave.
  // We run at a host output rate one quarter of that, 62.5kHz, so that the host
  // can keep up without latency issues. We still invert the output every tick,
  // so the modulated square wave will be 31.25kHz. This is deliberate worse
  // than the beeb setup, but it seems to sound fine.
  const rate = 62500;

  this.player = new MODPlayer(this,
                              modfile,
                              rate,
                              beeb_player_callback,
                              this.noteHit.bind(this));
  this.is_merged = is_merged;
  this.beeb_levels_to_u8 = new Uint8Array(16);
  this.u8_to_one_channel = new Uint8Array(256);
  this.two_channel_outputs = new Array(256);
  this.u8_to_two_channel = new Uint8Array(256);
  this.period_advances = new Uint16Array(1024);
  this.counter = 0;
  this.channel_outputs = new Uint8Array(4);
  this.channel_advances_hi = new Uint8Array(4);
  this.channel_advances_lo = new Uint8Array(4);
  this.channel_sample_sub_index = new Uint8Array(4);

  this.buildTables();
}

MODPlayerBeeb.prototype.buildTables = function() {
  // Build the mapping of the beeb's 15 output levels to a u8 value.
  const beeb_volume_exponent = -0.1;
  for (let i = 15; i >= 1; --i) {
    const exponent = ((15 - i) * beeb_volume_exponent);
    const float_value = Math.pow(10.0, exponent);
    const u8_value = Math.round(float_value * 255);
    this.beeb_levels_to_u8[i] = u8_value;
  }
  this.beeb_levels_to_u8[0] = 0;

  // Build the mapping of requested sample u8 output level to available
  // u8 output level.
  // TODO: this doesn't give great results.
  // The loudest quantized level is 255, and only is used if the incoming
  // sample value is 255!
  let current_value = 0;
  let next_beeb_level = 1;
  let next_beeb_level_value = this.beeb_levels_to_u8[1];
  for (let i = 0; i < 256; ++i) {
    if (i == next_beeb_level_value) {
      current_value = next_beeb_level_value;
      next_beeb_level++;
      if (next_beeb_level < 16) {
        next_beeb_level_value = this.beeb_levels_to_u8[next_beeb_level];
      } else {
        // Set the next level value to one that will never be hit.
        next_beeb_level_value = 256;
      }
    }
    this.u8_to_one_channel[i] = current_value;
  }

  // Build the mapping of requested sample u8 output level to available
  // u8 output level, build from a pair of SN channels outputting together
  // to achieve better vertical resolution.
  for (let i = 0; i < 256; ++i) {
    this.two_channel_outputs[i] = null;
  }
  for (let i = 0; i < 16; ++i) {
    for (let j = 0; j < 16; ++j) {
      const added_output =
        (this.beeb_levels_to_u8[i] + this.beeb_levels_to_u8[j]);
      const normalized_output = Math.round((added_output / 510) * 255);
      if (this.two_channel_outputs[normalized_output] == null) {
        const lookups = new Uint8Array(2);
        // TODO: do we want to prefer the larger output value to always be
        // first?
        lookups[0] = i;
        lookups[1] = j;
        this.two_channel_outputs[normalized_output] = lookups;
      }
    }
  }

  // Build the mapping of requested sample u8 output level to available
  // two channel levels.
  // TODO: this doesn't give great results.
  // The loudest quantized level is 255, and only is used if the incoming
  // sample value is 255!
  current_value = 0;
  let next_level_value = -1;
  for (let i = 0; i < 256; ++i) {
    if ((next_level_value == -1) || (i == next_level_value)) {
      current_value = i;
      for (let j = (i + 1); j < 256; ++j) {
        if (this.two_channel_outputs[j] != null) {
          next_level_value = j;
          break;
        }
      }
    }
    this.u8_to_two_channel[i] = current_value;
  }

  // Build the mapping of MOD periods to beeb advance increments.
  const amiga_clocks = (28375160.0 / 8.0);
  // 7.8kHz.
  const beeb_freq = (2000000 / 64 / 4);
  for (let i = 113; i <= 856; ++i) {
    const freq = (amiga_clocks / i);
    const advance_float = (freq / beeb_freq * 256);
    const advance = Math.round(advance_float);
    this.period_advances[i] = advance;
  }
}

MODPlayerBeeb.prototype.reset = function() {
  this.counter = 0;
  for (let i = 0; i < 4; ++i) {
    this.channel_advances_hi[i] = 0;
    this.channel_advances_lo[i] = 0;
    this.channel_sample_sub_index[i] = 0;
    this.updateOutput(i);
  }
}

MODPlayerBeeb.prototype.noteHit = function(channel, sample_index, period) {
  if (period != 0) {
    const advance = this.period_advances[period];
    this.channel_advances_hi[channel] = Math.floor(advance / 256);
    this.channel_advances_lo[channel] = (advance % 256);
  }
  if ((sample_index > 0) && (sample_index < 32)) {
    this.channel_sample_sub_index[channel] = 0;
  }
}

MODPlayerBeeb.prototype.updateOutput = function(channel) {
  const s8_value = this.player.outputs[channel];
  const u8_value = (s8_value + 128);
  this.channel_outputs[channel] = u8_value;
}

MODPlayerBeeb.prototype.advanceSample = function(channel) {
  const advance_hi = this.channel_advances_hi[channel];
  for (let i = 0; i < advance_hi; ++i) {
    player.advanceSampleIndex(channel);
  }
  const advance_lo = this.channel_advances_lo[channel];
  let sample_sub_index = this.channel_sample_sub_index[channel];
  sample_sub_index += advance_lo;
  if (sample_sub_index >= 256) {
    player.advanceSampleIndex(channel);
    sample_sub_index -= 256;
  }
  this.channel_sample_sub_index[channel] = sample_sub_index;
}

function beeb_player_callback(event) {
  const beeb_player = event.target.context.player;
  const player = beeb_player.player;
  const outputBuffer = event.outputBuffer;
  const data = outputBuffer.getChannelData(0);
  const is_merged = beeb_player.is_merged;
  let counter = beeb_player.counter;

  for (let i = 0; i < data.length; ++i) {
    const is_even = !(counter & 1);
    let u8_accumulation = 0;

    for (let j = 0; j < 4; ++j) {
      if (is_even) {
        var u8_value = beeb_player.channel_outputs[j];
        if (is_merged) {
          // Update all channels together at ~7.8kHz.
          if (counter == 0) {
            beeb_player.updateOutput(j);
            beeb_player.advanceSample(j);
          }
          // Lower resolution to 6 bits.
          u8_value >>= 2;
          u8_accumulation += u8_value;
        } else {
          // Update all channels at ~7.8kHz individually and staggered.
          if (counter == (j * 2)) {
            beeb_player.updateOutput(j);
            beeb_player.advanceSample(j);
          }
          const u8_value_quantized = beeb_player.u8_to_one_channel[u8_value];
          u8_accumulation += u8_value_quantized;
        }
      }
    }

    // Value is 0 to 1020.
    // Convert value to 0.0 to 1.0.
    // We deliberately only output zero or positive values, which is the upper
    // half of the available waveform space. It probably doesn't matter a whole
    // lot, but the SN76489 outputs like this.
    let float_value;
    if (is_merged) {
      // Max is 252, which is (0x3f * 4), which is ((0xff >> 2) * 4).
      let u8_value = Math.round(u8_accumulation * (255 / 252));
      u8_value = beeb_player.u8_to_two_channel[u8_value];
      float_value = (u8_value / 255);
    } else {
      float_value = (u8_accumulation / 1020);
    }

    data[i] = float_value;

    counter = ((counter + 1) % 8);

    player.hostSampleTick();
  }

  this.counter = counter;
}
