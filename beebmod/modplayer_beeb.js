"use strict";

function MODPlayerBeeb(modfile) {
  // The SN76489 runs at 250kHz.
  const rate = 250000;

  this.player = new MODPlayer(modfile, rate, beeb_player_callback);
}

function beeb_player_callback(event) {
  const player = event.target.context.player;
  const outputBuffer = event.outputBuffer;
  const data = outputBuffer.getChannelData(0);
  let host_samples_counter = player.host_samples_counter;

  for (let i = 0; i < data.length; ++i) {
    let value = 0.0;

    data[i] = value;

    host_samples_counter--;
    if (host_samples_counter == 0) {
      host_samples_counter = player.host_samples_per_tick;
      player.loadRow();
    }
  }
}
