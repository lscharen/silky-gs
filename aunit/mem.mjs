/**
 * aunit/mem.mjs — Assembly-style typed buffer builder
 *
 * Provides terse, assembler-idiomatic helpers for constructing typed binary
 * data for aunit memory fixtures. All functions return a plain Buffer that
 * composes naturally with the `data` field of a `memory` entry:
 *
 *   memory: [{ label: 'my_table', data: mem.dw(0x0100, 0x0200, 0x0300) }]
 *
 * Complex structures can be built with Buffer.concat:
 *
 *   data: Buffer.concat([mem.db(0x01), mem.db(4), mem.dl(0x7E0000)])
 *
 * Numeric methods accept a single value, variadic values, or an array:
 *   mem.db(0xFF)
 *   mem.db(0x00, 0x01, 0x02)
 *   mem.db([0x00, 0x01, 0x02])
 */

function _toArray(args) {
  if (args.length === 1 && Array.isArray(args[0])) return args[0];
  return args;
}

export const mem = {
  /** Define Byte — one or more 8-bit values. */
  db(...args) {
    const vals = _toArray(args);
    return Buffer.from(vals.map(v => v & 0xFF));
  },

  /** Define Word — one or more 16-bit little-endian values. */
  dw(...args) {
    const vals = _toArray(args);
    const buf = Buffer.allocUnsafe(vals.length * 2);
    vals.forEach((v, i) => buf.writeUInt16LE(v & 0xFFFF, i * 2));
    return buf;
  },

  /** Define Long — one or more 24-bit little-endian values (65816 bank:address pointer). */
  dl(...args) {
    const vals = _toArray(args);
    const buf = Buffer.allocUnsafe(vals.length * 3);
    vals.forEach((v, i) => {
      buf[i * 3]     =  v        & 0xFF;
      buf[i * 3 + 1] = (v >>  8) & 0xFF;
      buf[i * 3 + 2] = (v >> 16) & 0xFF;
    });
    return buf;
  },

  /** Define Double — one or more 32-bit little-endian values. */
  dd(...args) {
    const vals = _toArray(args);
    const buf = Buffer.allocUnsafe(vals.length * 4);
    vals.forEach((v, i) => buf.writeUInt32LE(v >>> 0, i * 4));
    return buf;
  },

  /** ASCII string, no terminator. */
  asc(str) {
    return Buffer.from(str, 'ascii');
  },

  /** Null-terminated ASCII string. */
  asciiz(str) {
    return Buffer.from(str + '\0', 'ascii');
  },
};
