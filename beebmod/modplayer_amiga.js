"use strict";

function MODPlayerAmiga(modfile) {
  // Sample ticks are based on 28.63636 MHz (NTSC) or 28.37516 MHz (PAL) main
  // oscillator, divided by 8.
  // We'll use PAL.
  // That's a tick rate of 3546895Hz.
  // We'll subdivide by 50 to get a rate the host audio subsystem will accept:
  // 70938Hz.
  const rate = 70938;

  this.player = new MODPlayer(this,
                              modfile,
                              rate,
                              amiga_player_callback,
                              this.noteHit.bind(this));
  this.sample_counters = new Float32Array(4);

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
  const amiga_clocks_per_host_sample = (amiga_clocks / rate);
  this.amiga_clocks_per_host_sample = amiga_clocks_per_host_sample;
}

MODPlayerAmiga.prototype.reset = function() {
}

MODPlayerAmiga.prototype.noteHit = function(channel, sample_index, period) {
  if ((sample_index > 0) && (sample_index < 32)) {
    this.sample_counters[channel] = period;
  }
}

MODPlayerAmiga.prototype.advanceSample = function(channel) {
  let counter = this.sample_counters[channel];
  counter -= this.amiga_clocks_per_host_sample;
  if (counter <= 0) {
    counter += this.player.sample_periods[channel];
    this.player.advanceSampleIndex(channel);
  }
  this.sample_counters[channel] = counter;
}

function amiga_player_callback(event) {
  const amiga_player = event.target.context.player;
  const player = amiga_player.player;
  const outputBuffer = event.outputBuffer;
  const data = outputBuffer.getChannelData(0);

  for (let i = 0; i < data.length; ++i) {
    let s8_accumulation = 0;
    for (let j = 0; j < 4; ++j) {
      s8_accumulation += player.outputs[j];

      amiga_player.advanceSample(j);
    }

    // Value is -512 to 508.
    // Convert to about -1.0 to +1.0.
    let float_value = (s8_accumulation / 512.0);
    data[i] = float_value;

    player.hostSampleTick();
  }
}
