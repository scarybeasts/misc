"use strict";

// A good resource for the MOD format:
// https://eblong.com/zarf/blorb/mod-spec.txt

function mod_get_string(binary, offset, length) {
  let ret = "";
  for (let i = 0; i < length; ++i) {
    let value = binary[offset + i];
    if (value == 0) {
      break;
    }
    if ((value < 32) || (value >= 127)) {
      value = 32;
    }
    ret = (ret + String.fromCharCode(value));
  }

  return ret;
}

function MODSample(binary, name, volume, repeat_start, repeat_length) {
  this.binary = binary;
  this.name = name;
  this.volume = volume;
  this.repeat_start = repeat_start;
  this.repeat_length = repeat_length;
}

function MODNote(binary) {
  this.binary = binary;
  this.period = ((binary[0] & 0x0F) << 8);
  this.period |= binary[1];
  this.sample = (binary[0] & 0xF0);
  this.sample |= (binary[2] >> 4);
  this.command = ((binary[2] & 0x0F) << 8);
  this.command |= binary[3];
}

function MODRow(binary) {
  const channels = new Array(4);
  for (let i = 0; i < 4; ++i) {
    const note = new MODNote(binary.slice((i * 4), ((i + 1) * 4)));
    channels[i] = note;
  }

  this.channels = channels;
}

function MODPattern(binary) {
  const rows = new Array(64);
  const row_length = (4 * 4);
  for (let i = 0; i < 64; ++i) {
    const row =
        new MODRow(binary.slice((i * row_length), ((i + 1) * row_length)));
    rows[i] = row;
  }

  this.rows = rows;
}

function MODFile(binary) {
  this.binary = binary;
  this.name = null;
  this.samples = new Array(32);
  this.num_positions = 0;
  this.num_patterns = 0;
  this.positions = new Uint8Array(128);
  this.patterns = new Array();

  this.samples.fill(null);
}

MODFile.prototype.parse = function() {
  const binary = this.binary;
  const binary_length = binary.length;
  if (binary_length < 1084) {
    return 0;
  }

  this.name = mod_get_string(binary, 0, 20);
  const signature = mod_get_string(binary, 1080, 4);

  console.log("name: " + this.name, ", signature: " + signature);
  var num_samples = 15;
  if ((signature == "M.K.") ||
      (signature == "M!K!") ||
      (signature == "FLT4")) {
    num_samples = 31;
  }

  let positions_offset = (20 + (num_samples * 30));
  const num_positions = binary[positions_offset];
  if ((num_positions < 1) || (num_positions > 128)) {
    return 0;
  }
  this.num_positions = num_positions;

  positions_offset += 2;
  let num_patterns = 0;
  for (let i = 0; i < 128; ++i) {
    const pattern_index = binary[positions_offset + i];
    this.positions[i] = pattern_index;
    if (pattern_index > num_patterns) {
      num_patterns = pattern_index;
    }
  }
  num_patterns++;
  this.num_patterns = num_patterns;

  let patterns_offset = (positions_offset + 128);
  if (num_samples == 31) {
    // Skip the signature.
    patterns_offset += 4;
  }
  let pattern_length = (64 * 4 * 4);
  for (let i = 0; i < num_patterns; ++i) {
    let pattern_extent = (patterns_offset + pattern_length);
    if (pattern_extent > binary_length) {
      return 0;
    }

    const pattern =
        new MODPattern(binary.slice(patterns_offset, pattern_extent));
    this.patterns.push(pattern);
    patterns_offset += pattern_length;
  }

  let samples_offset = patterns_offset;
  this.samples[0] = undefined;
  for (let i = 0; i < num_samples; ++i) {
    let sample_meta_offset = (20 + (i * 30));
    let sample_length = (binary[sample_meta_offset + 22] * 256);
    sample_length += binary[sample_meta_offset + 23];
    sample_length *= 2;
    let volume = binary[sample_meta_offset + 25];
    let repeat_start = (binary[sample_meta_offset + 26] * 256);
    repeat_start += binary[sample_meta_offset + 27];
    // Old-style 15 sample SoundTracker modules have the repeat start in
    // bytes, not words.
    if (num_samples == 31) {
      repeat_start *= 2;
    }
    let repeat_length = (binary[sample_meta_offset + 28] * 256);
    repeat_length += binary[sample_meta_offset + 29];
    repeat_length *= 2;

    let sample_extent = (samples_offset + sample_length);
    if (sample_extent > binary_length) {
      return 0;
    }

    let sample_binary = binary.slice(samples_offset, sample_extent);
    // MOD files store sample data as signed 8-bit.
    sample_binary = new Int8Array(sample_binary);
    const sample_name = mod_get_string(binary, sample_meta_offset, 22);

    const sample = new MODSample(sample_binary,
                                 sample_name,
                                 volume,
                                 repeat_start,
                                 repeat_length);
    this.samples[i + 1] = sample;

    samples_offset += sample_length;
  }

  // See if there's a speed command in the first row of the MOD.
  // We can use this to start playback of the MOD in the middle,
  // and get a reasonable speed.
  const first_pattern_index = this.getPatternIndex(1);
  const first_pattern = this.getPattern(first_pattern_index);
  const first_row = first_pattern.rows[0];
  this.first_row_speed = -1;
  for (let i = 0; i < 4; ++i) {
    const note = first_row.channels[i];
    if ((note.command & 0xF00) == 0xF00) {
      this.first_row_speed = (note.command & 0x0FF);
      break;
    }
  }

  return 1;
}

MODFile.prototype.getName = function() {
  return this.name;
}

MODFile.prototype.getNumPositions = function() {
  return this.num_positions;
}

MODFile.prototype.getNumPatterns = function() {
  return this.num_patterns;
}

MODFile.prototype.getPatternIndex = function(position) {
  return this.positions[position - 1];
}

MODFile.prototype.getPattern = function(index) {
  return this.patterns[index];
}

MODFile.prototype.getSample = function(index) {
  return this.samples[index];
}

MODFile.prototype.getFirstRowSpeed = function() {
  return this.first_row_speed;
}
