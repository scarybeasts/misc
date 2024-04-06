"use strict";

function MODPlayerBeeb(modfile) {
  // The SN76489 runs at 250kHz.
  const rate = 250000;

  this.beeb_levels_to_u8 = new Uint8Array(16);
  this.u8_to_quantized_u8 = new Uint8Array(256);
  this.player = new MODPlayer(this, modfile, rate, beeb_player_callback);

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
        // Never hit.
        next_beeb_level_value = 256;
      }
    }
    this.u8_to_quantized_u8[i] = current_value;
  }
}

function beeb_player_callback(event) {
  const beeb_player = event.target.context.player;
  const player = beeb_player.player;
  const outputBuffer = event.outputBuffer;
  const data = outputBuffer.getChannelData(0);

  for (let i = 0; i < data.length; ++i) {
    let u8_accumulation = 0;
    for (let j = 0; j < 4; ++j) {
      let index = player.sample_indexes[j];
      if (index == -1) {
        continue;
      }
      const s8_value = player.outputs[j];
      const u8_value = (s8_value + 128);
      const u8_value_quantized = beeb_player.u8_to_quantized_u8[u8_value];
      u8_accumulation += u8_value_quantized;

      let counter = player.sample_counters[j];
      counter -= 14;
      if (counter > 0) {
        player.sample_counters[j] = counter;
        continue;
      }
      counter += player.sample_periods[j];
      player.sample_counters[j] = counter;
      player.advanceSample(j);
    }

    // Value is 0 to 1020.
    // Convert to 0.0 to 2.0.
    let float_value = (u8_accumulation / 510);
    // Convert to -1.0 to 1.0.
    float_value -= 1.0;
    data[i] = float_value;

    player.hostSampleTick();
  }
}
