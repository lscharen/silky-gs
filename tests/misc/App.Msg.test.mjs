/**
 * tests/misc/App.Msg.test.mjs
 */
import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const SRC      = join(process.env.SRC_ROOT, './misc/App.Msg.s');
const FONT_SRC = join(process.env.SRC_ROOT, './misc/font.s');

describe('AppMsg', () => {
  const { jsr } = cpu65816({
    includes:  [SRC, FONT_SRC],
    assembler: 'merlin32',
  });

  test('Convert zero to a two-character string', async () => {
    const result = await jsr('ByteToString', {
      A: 0,
      Y: 'buffer',
      allocMemory: [{ label: 'buffer', length: 2 }],
    });
    expect(result.memory['buffer'].toString()).toBe('00');
  });

  test('Convert single digit to a two-character string', async () => {
    const result = await jsr('ByteToString', {
      A: 5,
      Y: 'buffer',
      allocMemory: [{ label: 'buffer', length: 2 }],
    });
    expect(result.memory['buffer'].toString()).toBe('05');
  });

  test('Convert single hex digit to a two-character string', async () => {
    const result = await jsr('ByteToString', {
      A: 0x0A,
      Y: 'buffer',
      allocMemory: [{ label: 'buffer', length: 2 }],
    });
    expect(result.memory['buffer'].toString()).toBe('0A');
  });

  test('Convert arbitrary byte to a two-character string', async () => {
    const result = await jsr('ByteToString', {
      A: 0xAB,
      Y: 'buffer',
      allocMemory: [{ label: 'buffer', length: 2 }],
    });
    expect(result.memory['buffer'].toString()).toBe('AB');
  });
});
