"use strict";

function MODPlayerBeeb(modfile) {
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

  this.beeb_levels_to_u8 = new Uint8Array(16);
  this.u8_to_quantized_u8 = new Uint8Array(256);
  this.player = new MODPlayer(this, modfile, rate, beeb_player_callback);
  this.counter = 0;
  this.outputs = new Uint8Array(4);

  this.buildTables();
}

MODPlayerBeeb.prototype.buildTables = function() {
  const beeb_volume_exponent = -0.1;
  for (let i = 15; i >= 1; --i) {
    const exponent = ((15 - i) * beeb_volume_exponent);
    const float_value = Math.pow(10.0, exponent);
    const u8_value = Math.round(float_value * 255);
    this.beeb_levels_to_u8[i] = u8_value;
  }
  this.beeb_levels_to_u8[0] = 0;

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
    this.u8_to_quantized_u8[i] = current_value;
  }
}

MODPlayerBeeb.prototype.reset = function() {
  this.counter = 0;
  for (let i = 0; i < 4; ++i) {
    this.updateOutput(i);
  }
}

MODPlayerBeeb.prototype.updateOutput = function(channel) {
  const s8_value = this.player.outputs[channel];
  const u8_value = (s8_value + 128);
  const u8_value_quantized = this.u8_to_quantized_u8[u8_value];
  this.outputs[channel] = u8_value_quantized;
}

function beeb_player_callback(event) {
  const beeb_player = event.target.context.player;
  const player = beeb_player.player;
  const outputBuffer = event.outputBuffer;
  const data = outputBuffer.getChannelData(0);
  let counter = beeb_player.counter;

  for (let i = 0; i < data.length; ++i) {
    const is_even = !(counter & 1);
    let u8_accumulation = 0;

    for (let j = 0; j < 4; ++j) {
      let index = player.sample_indexes[j];
      if (index == -1) {
        continue;
      }
      if (is_even) {
        u8_accumulation += beeb_player.outputs[j];
      }

      player.advanceSampleCounter(j);
    }

    if (is_even) {
      beeb_player.updateOutput(counter >> 1);
    }

    // Value is 0 to 1020.
    // Convert to 0.0 to 1.0.
    // We deliberately only output zero or positive values, which is the upper
    // half of the available waveform space. It probably doesn't matter a whole
    // lot, but the SN76489 outputs like this.
    const float_value = (u8_accumulation / 1020);
    data[i] = float_value;

    counter++;
    if (counter == 8) {
      counter = 0;
    }

    player.hostSampleTick();
  }

  this.counter = counter;
}
