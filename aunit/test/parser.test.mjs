/**
 * aunit/test/parser.test.mjs
 *
 * Pure-JS unit tests for the AUNT packet parser.
 * All test vectors are hand-crafted buffers — no assembly or emulator needed.
 *
 * Packet layout:
 *   [0-3]  'AUNT' magic (LE32: 0x544E5541)
 *   [4]    version = 1
 *   [5]    status  (0 = ok)
 *   [6-7]  record count (LE16)
 *   [8..]  records: tag(1) payloadLen(2-LE16) payload
 *
 * Record payloads:
 *   'R'  16 bytes: A X Y P DP SP DBR K  (each 2 bytes LE; P/DBR/K low byte used)
 *   'M'  5+N bytes: bank(1) addrLo(2) length(2) data[length]
 *   'V'  1+nameLen+2 bytes: nameLen(1) name[nameLen] value(2-LE16)
 */

import { describe, test, expect } from 'vitest';
import { parseResult, formatResult, ParseError } from 'aunit/parser';

// ---------------------------------------------------------------------------
// Packet builder helpers
// ---------------------------------------------------------------------------

function header(status, recCount) {
  const buf = Buffer.alloc(8);
  buf.writeUInt32LE(0x544E5541, 0);   // 'AUNT'
  buf.writeUInt8(1, 4);               // version
  buf.writeUInt8(status, 5);
  buf.writeUInt16LE(recCount, 6);
  return buf;
}

function rRecord({ A = 0, X = 0, Y = 0, P = 0, DP = 0, SP = 0, DBR = 0, K = 0 } = {}) {
  const payload = Buffer.alloc(16);
  payload.writeUInt16LE(A,   0);
  payload.writeUInt16LE(X,   2);
  payload.writeUInt16LE(Y,   4);
  payload.writeUInt16LE(P,   6);
  payload.writeUInt16LE(DP,  8);
  payload.writeUInt16LE(SP,  10);
  payload.writeUInt16LE(DBR, 12);
  payload.writeUInt16LE(K,   14);
  const hdr = Buffer.alloc(3);
  hdr.writeUInt8(0x52, 0);            // 'R'
  hdr.writeUInt16LE(16, 1);
  return Buffer.concat([hdr, payload]);
}

function mRecord(bank, addr, data) {
  const dataBuf = Buffer.isBuffer(data) ? data : Buffer.from(data);
  const hdr = Buffer.alloc(3);
  hdr.writeUInt8(0x4D, 0);            // 'M'
  hdr.writeUInt16LE(5 + dataBuf.length, 1);
  const meta = Buffer.alloc(5);
  meta.writeUInt8(bank, 0);
  meta.writeUInt16LE(addr, 1);
  meta.writeUInt16LE(dataBuf.length, 3);
  return Buffer.concat([hdr, meta, dataBuf]);
}

function vRecord(name, value) {
  const nameBuf = Buffer.from(name, 'ascii');
  const hdr = Buffer.alloc(3);
  hdr.writeUInt8(0x56, 0);            // 'V'
  hdr.writeUInt16LE(1 + nameBuf.length + 2, 1);
  const lenByte = Buffer.alloc(1);
  lenByte.writeUInt8(nameBuf.length, 0);
  const valBuf = Buffer.alloc(2);
  valBuf.writeUInt16LE(value, 0);
  return Buffer.concat([hdr, lenByte, nameBuf, valBuf]);
}

function packet(status, ...records) {
  return Buffer.concat([header(status, records.length), ...records]);
}

// ---------------------------------------------------------------------------
// Empty / header-only packet
// ---------------------------------------------------------------------------
describe('parseResult — empty packet', () => {
  test('ok=true when status=0', () => {
    const r = parseResult(packet(0));
    expect(r.ok).toBe(true);
    expect(r.status).toBe(0);
  });

  test('ok=false when status=1', () => {
    const r = parseResult(packet(1));
    expect(r.ok).toBe(false);
    expect(r.status).toBe(1);
  });

  test('registers is null with no R record', () => {
    expect(parseResult(packet(0)).registers).toBeNull();
  });

  test('memory array is empty with no M records', () => {
    expect(parseResult(packet(0)).memory).toEqual([]);
  });

  test('values object is empty with no V records', () => {
    expect(parseResult(packet(0)).values).toEqual({});
  });

  test('accepts Uint8Array as well as Buffer', () => {
    const buf = new Uint8Array(packet(0));
    expect(() => parseResult(buf)).not.toThrow();
  });
});

// ---------------------------------------------------------------------------
// R (register) record
// ---------------------------------------------------------------------------
describe('parseResult — R record', () => {
  test('parses all register fields', () => {
    const r = parseResult(packet(0, rRecord({ A: 0x1234, X: 0x5678, Y: 0x9ABC,
                                              P: 0x30, DP: 0x0100, SP: 0x01FF,
                                              DBR: 0x02, K: 0x02 })));
    expect(r.registers.A).toBe(0x1234);
    expect(r.registers.X).toBe(0x5678);
    expect(r.registers.Y).toBe(0x9ABC);
    expect(r.registers.P).toBe(0x30);
    expect(r.registers.DP).toBe(0x0100);
    expect(r.registers.SP).toBe(0x01FF);
    expect(r.registers.DBR).toBe(0x02);
    expect(r.registers.K).toBe(0x02);
  });

  test('P is masked to low byte', () => {
    const r = parseResult(packet(0, rRecord({ P: 0x0130 })));
    expect(r.registers.P).toBe(0x30);
  });

  test('DBR is masked to low byte', () => {
    const r = parseResult(packet(0, rRecord({ DBR: 0x0102 })));
    expect(r.registers.DBR).toBe(0x02);
  });

  test('K is masked to low byte', () => {
    const r = parseResult(packet(0, rRecord({ K: 0x0102 })));
    expect(r.registers.K).toBe(0x02);
  });

  test('default registers are all zero', () => {
    const r = parseResult(packet(0, rRecord()));
    expect(r.registers.A).toBe(0);
    expect(r.registers.X).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// M (memory) record
// ---------------------------------------------------------------------------
describe('parseResult — M record', () => {
  test('parses bank, address, length and data', () => {
    const data = Buffer.from([0xDE, 0xAD, 0xBE, 0xEF]);
    const r = parseResult(packet(0, mRecord(0x02, 0x1000, data)));
    expect(r.memory.length).toBe(1);
    expect(r.memory[0].bank).toBe(0x02);
    expect(r.memory[0].address).toBe(0x1000);
    expect(r.memory[0].length).toBe(4);
    expect([...r.memory[0].data]).toEqual([0xDE, 0xAD, 0xBE, 0xEF]);
  });

  test('multiple M records produce multiple entries in order', () => {
    const r = parseResult(packet(0,
      mRecord(0x02, 0x1000, [0x01]),
      mRecord(0x02, 0x2000, [0x02]),
    ));
    expect(r.memory.length).toBe(2);
    expect(r.memory[0].address).toBe(0x1000);
    expect(r.memory[1].address).toBe(0x2000);
  });

  test('empty data region has length 0', () => {
    const r = parseResult(packet(0, mRecord(0x02, 0x0000, [])));
    expect(r.memory[0].length).toBe(0);
    expect(r.memory[0].data.length).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// V (named value) record
// ---------------------------------------------------------------------------
describe('parseResult — V record', () => {
  test('parses name and value', () => {
    const r = parseResult(packet(0, vRecord('count', 0x0042)));
    expect(r.values['count']).toBe(0x42);
  });

  test('multiple V records populate values object', () => {
    const r = parseResult(packet(0,
      vRecord('a', 0x0001),
      vRecord('b', 0x0002),
    ));
    expect(r.values['a']).toBe(1);
    expect(r.values['b']).toBe(2);
  });

  test('value 0xFFFF round-trips', () => {
    const r = parseResult(packet(0, vRecord('x', 0xFFFF)));
    expect(r.values['x']).toBe(0xFFFF);
  });
});

// ---------------------------------------------------------------------------
// Mixed records
// ---------------------------------------------------------------------------
describe('parseResult — mixed records', () => {
  test('R + M + V all parsed in one packet', () => {
    const r = parseResult(packet(0,
      rRecord({ A: 0xABCD }),
      mRecord(0x02, 0x3000, [0x11, 0x22]),
      vRecord('result', 0x1234),
    ));
    expect(r.registers.A).toBe(0xABCD);
    expect(r.memory[0].address).toBe(0x3000);
    expect(r.values['result']).toBe(0x1234);
  });

  test('unknown record tag is silently skipped', () => {
    const unknown = Buffer.from([0x5A, 0x02, 0x00, 0x00, 0x00]); // tag='Z', len=2, 2 bytes
    const r = parseResult(packet(0, unknown));
    expect(r.ok).toBe(true);
    expect(r.registers).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// Error conditions
// ---------------------------------------------------------------------------
describe('parseResult — error conditions', () => {
  test('throws ParseError on bad magic', () => {
    const buf = packet(0);
    buf.writeUInt32LE(0xDEADBEEF, 0);
    expect(() => parseResult(buf)).toThrow(ParseError);
    expect(() => parseResult(buf)).toThrow(/magic/i);
  });

  test('throws ParseError when buffer is too short (< 8 bytes)', () => {
    expect(() => parseResult(Buffer.from([0x41, 0x55, 0x4E]))).toThrow(ParseError);
    expect(() => parseResult(Buffer.from([0x41, 0x55, 0x4E]))).toThrow(/too short/i);
  });

  test('throws ParseError on unsupported version', () => {
    const buf = packet(0);
    buf.writeUInt8(99, 4);
    expect(() => parseResult(buf)).toThrow(ParseError);
    expect(() => parseResult(buf)).toThrow(/version/i);
  });
});

// ---------------------------------------------------------------------------
// formatResult smoke test
// ---------------------------------------------------------------------------
describe('formatResult', () => {
  test('returns a non-empty string', () => {
    const r = parseResult(packet(0, rRecord({ A: 0x1234 })));
    const s = formatResult(r);
    expect(typeof s).toBe('string');
    expect(s.length).toBeGreaterThan(0);
  });

  test('includes status line', () => {
    const r = parseResult(packet(0));
    expect(formatResult(r)).toMatch(/status.*ok/i);
  });

  test('includes FAIL for non-zero status', () => {
    const r = parseResult(packet(5));
    expect(formatResult(r)).toMatch(/FAIL/i);
  });

  test('includes register values when R record present', () => {
    const r = parseResult(packet(0, rRecord({ A: 0x1234 })));
    expect(formatResult(r)).toMatch(/1234/i);
  });
});
