/**
 * aunit/test/mem.test.mjs
 *
 * Pure-JS unit tests for the mem typed buffer builder.
 * No assembly, no emulator — fast and always runnable.
 */

import { describe, test, expect } from 'vitest';
import { mem } from 'aunit/mem';

// ---------------------------------------------------------------------------
// db — 8-bit bytes
// ---------------------------------------------------------------------------
describe('mem.db', () => {
  test('single value', () => {
    expect([...mem.db(0xFF)]).toEqual([0xFF]);
  });

  test('variadic values', () => {
    expect([...mem.db(0x00, 0x01, 0x02)]).toEqual([0x00, 0x01, 0x02]);
  });

  test('array form', () => {
    expect([...mem.db([0x10, 0x20, 0x30])]).toEqual([0x10, 0x20, 0x30]);
  });

  test('masks to 8 bits', () => {
    expect([...mem.db(0x1FF)]).toEqual([0xFF]);
  });

  test('zero value', () => {
    expect([...mem.db(0)]).toEqual([0x00]);
  });

  test('returns Buffer', () => {
    expect(Buffer.isBuffer(mem.db(1))).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// dw — 16-bit little-endian words
// ---------------------------------------------------------------------------
describe('mem.dw', () => {
  test('single value is little-endian', () => {
    expect([...mem.dw(0x1234)]).toEqual([0x34, 0x12]);
  });

  test('zero is two zero bytes', () => {
    expect([...mem.dw(0)]).toEqual([0x00, 0x00]);
  });

  test('0xFFFF is two 0xFF bytes', () => {
    expect([...mem.dw(0xFFFF)]).toEqual([0xFF, 0xFF]);
  });

  test('variadic produces correct byte sequence', () => {
    expect([...mem.dw(0x0100, 0x0200)]).toEqual([0x00, 0x01, 0x00, 0x02]);
  });

  test('array form', () => {
    expect([...mem.dw([0x0001, 0x0002, 0x0003])])
      .toEqual([0x01, 0x00, 0x02, 0x00, 0x03, 0x00]);
  });

  test('masks to 16 bits', () => {
    expect([...mem.dw(0x10000)]).toEqual([0x00, 0x00]);
  });

  test('returns Buffer', () => {
    expect(Buffer.isBuffer(mem.dw(1))).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// dl — 24-bit little-endian (65816 bank:address pointer)
// ---------------------------------------------------------------------------
describe('mem.dl', () => {
  test('single value is little-endian 24-bit', () => {
    expect([...mem.dl(0x123456)]).toEqual([0x56, 0x34, 0x12]);
  });

  test('bank $7E address $0000 encodes correctly', () => {
    expect([...mem.dl(0x7E0000)]).toEqual([0x00, 0x00, 0x7E]);
  });

  test('zero is three zero bytes', () => {
    expect([...mem.dl(0)]).toEqual([0x00, 0x00, 0x00]);
  });

  test('variadic produces correct byte sequence', () => {
    expect([...mem.dl(0x010000, 0x020000)])
      .toEqual([0x00, 0x00, 0x01, 0x00, 0x00, 0x02]);
  });

  test('array form', () => {
    expect([...mem.dl([0x7E0000])]).toEqual([0x00, 0x00, 0x7E]);
  });

  test('returns Buffer', () => {
    expect(Buffer.isBuffer(mem.dl(1))).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// dd — 32-bit little-endian
// ---------------------------------------------------------------------------
describe('mem.dd', () => {
  test('single value is little-endian 32-bit', () => {
    expect([...mem.dd(0x12345678)]).toEqual([0x78, 0x56, 0x34, 0x12]);
  });

  test('zero is four zero bytes', () => {
    expect([...mem.dd(0)]).toEqual([0x00, 0x00, 0x00, 0x00]);
  });

  test('variadic produces correct byte sequence', () => {
    expect([...mem.dd(0x00000001, 0x00000002)])
      .toEqual([0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00]);
  });

  test('returns Buffer', () => {
    expect(Buffer.isBuffer(mem.dd(1))).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// asc — ASCII string, no terminator
// ---------------------------------------------------------------------------
describe('mem.asc', () => {
  test('encodes ASCII bytes correctly', () => {
    expect([...mem.asc('Hi')]).toEqual([0x48, 0x69]);
  });

  test('empty string produces empty buffer', () => {
    expect(mem.asc('').length).toBe(0);
  });

  test('no null terminator', () => {
    const buf = mem.asc('A');
    expect(buf.length).toBe(1);
    expect(buf[0]).toBe(0x41);
  });

  test('returns Buffer', () => {
    expect(Buffer.isBuffer(mem.asc('x'))).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// asciiz — null-terminated ASCII string
// ---------------------------------------------------------------------------
describe('mem.asciiz', () => {
  test('appends NUL terminator', () => {
    expect([...mem.asciiz('Hi')]).toEqual([0x48, 0x69, 0x00]);
  });

  test('empty string is just a NUL byte', () => {
    expect([...mem.asciiz('')]).toEqual([0x00]);
  });

  test('returns Buffer', () => {
    expect(Buffer.isBuffer(mem.asciiz('x'))).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Composition via Buffer.concat
// ---------------------------------------------------------------------------
describe('Buffer.concat composition', () => {
  test('struct: db type-tag + db length + dl pointer', () => {
    const buf = Buffer.concat([
      mem.db(0x01),        // type
      mem.db(3),           // length
      mem.dl(0x7E0000),    // pointer
    ]);
    expect([...buf]).toEqual([0x01, 0x03, 0x00, 0x00, 0x7E]);
  });

  test('table of words matches manual construction', () => {
    const table = mem.dw(100, 200, 300);
    const manual = Buffer.from([0x64, 0x00, 0xC8, 0x00, 0x2C, 0x01]);
    expect(table).toEqual(manual);
  });
});
