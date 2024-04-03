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
      if (index < player.sample_maxes[j]) {
        player.sample_indexes[j] = index;
        player.loadOutput(j);
      } else {
        // Repeat loop the sample if it has a repeat, otherwise silence.
        const sample = player.samples[j];
        const repeat_length = sample.getRepeatLength();
        if (repeat_length > 2) {
          // TODO: bounds checking here.
          const repeat_start = sample.getRepeatStart();
          player.sample_indexes[j] = repeat_start;
          player.sample_maxes[j] = (repeat_start + repeat_length);
        } else {
          player.sample_indexes[j] = -1;
          player.outputs[j] = 0.0;
        }
      }
    }

    data[i] = value;

    player.hostSampleTick();
  }
}
