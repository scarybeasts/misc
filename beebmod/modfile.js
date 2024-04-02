"use strict";

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

function MODSample(binary, name) {
  this.binary = binary;
  this.name = name;
  this.length = binary.length;
}

MODSample.prototype.getName = function() {
  return this.name;
}

MODSample.prototype.getLength = function() {
  return this.length;
}

function MODNote(binary) {
  this.binary = binary;
  this.period = ((binary[0] & 0x0F) << 8);
  this.period |= binary[1];
  this.sample = (binary[0] & 0xF0);
  this.sample |= (binary[2] >> 4);
}

function MODRow(binary) {
  const channels = new Array(4);
  for (let i = 0; i < 4; ++i) {
    const note = new MODNote(binary.slice((i * 4), ((i + 1) * 4)));
    channels[i] = note;
  }

  this.channels = channels;
}

MODRow.prototype.getChannel = function(index) {
  return this.channels[index];
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

MODPattern.prototype.getRow = function(index) {
  return this.rows[index];
}

function MODFile(binary) {
  this.binary = binary;
  this.name = null;
  this.samples = new Array(31);
  this.num_positions = 0;
  this.num_patterns = 0;
  this.positions = new Uint8Array(128);
  this.patterns = new Array();
}

MODFile.prototype.parse = function() {
  const binary = this.binary;
  const binary_length = binary.length;
  if (binary_length < 1084) {
    return 0;
  }

  this.name = mod_get_string(binary, 0, 20);

  const num_positions = binary[950];
  if ((num_positions < 1) || (num_positions > 128)) {
    return 0;
  }
  this.num_positions = num_positions;

  let num_patterns = 0;
  for (let i = 0; i < 128; ++i) {
    const pattern_index = binary[952 + i];
    if (pattern_index > 63) {
      return 0;
    }
    this.positions[i] = pattern_index;
    if (pattern_index > num_patterns) {
      num_patterns = pattern_index;
    }
  }
  num_patterns++;
  this.num_patterns = num_patterns;

  let patterns_offset = 1084;
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
  for (let i = 0; i < 31; ++i) {
    let sample_meta_offset = (20 + (i * 30));
    let sample_length = (binary[sample_meta_offset + 22] * 256);
    sample_length += binary[sample_meta_offset + 23];
    sample_length *= 2;

    let sample_extent = (samples_offset + sample_length);
    if (sample_extent > binary_length) {
      return 0;
    }
    let sample_binary = binary.slice(samples_offset, sample_extent);
    const sample_name = mod_get_string(binary, sample_meta_offset, 22);

    const sample = new MODSample(sample_binary, sample_name);
    this.samples[i] = sample;

    samples_offset += sample_length;
  }
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
  return this.positions[position];
}

MODFile.prototype.getPattern = function(index) {
  return this.patterns[index];
}

MODFile.prototype.getSample = function(index) {
  return this.samples[index];
}
