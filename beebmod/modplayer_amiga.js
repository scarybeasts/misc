"use strict";

function MODPlayerAmiga(modfile) {
  // Sample ticks are based on 28.63636 MHz (NTSC) or 28.37516 MHz (PAL) main
  // oscillator, divided by 8.
  // We'll use PAL.
  // That's a tick rate of 3546895Hz.
  // We'll subdivide by 50 to get a rate the host audio subsystem will accept:
  // 70938Hz.
  const rate = 70938;

  this.player = new MODPlayer(modfile, rate, amiga_player_callback);
}

function amiga_player_callback(event) {
  const player = event.target.context.player;
  const outputBuffer = event.outputBuffer;
  const data = outputBuffer.getChannelData(0);

  for (let i = 0; i < data.length; ++i) {
    let s8_accumulation = 0;
    for (let j = 0; j < 4; ++j) {
      s8_accumulation += player.outputs[j];
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
      player.advanceSample(j);
    }

    // Value is -512 to 508.
    // Convert to about -1.0 to +1.0.
    let float_value = (s8_accumulation / 512.0);
    data[i] = float_value;

    player.hostSampleTick();
  }
}
