/**
 * tests/ppu/ppu.color.test.mjs
 *
 * Unit tests for the NES→IIgs colour conversion routine (NES_ColorToIIgs).
 * Source: src/rom/rom_color.s — a self-contained module with no external
 * symbol dependencies, extracted from rom_helpers.s.
 */
import { describe, test, expect } from 'vitest';
import { join }                   from 'node:path';
import { cpu65816 }               from 'iigs-unit';

const COLOR_SRC = join(process.env.SRC_ROOT, 'rom/rom_color.s');

describe('NES_ColorToIIgs', () => {
  const { jsr } = cpu65816({
    includes:  [COLOR_SRC],
    assembler: 'merlin32',
  });

  // NES colour 0 ($00) is medium grey → IIgs $0777
  test('colour 0x00 (medium grey) → 0x0777', async () => {
    const r = await jsr('NES_ColorToIIgs', { A: 0x00 });
    expect(r.A).toBe(0x0777);
  });

  // NES colour 0x20 (white) → IIgs $0FFF
  test('colour 0x20 (white) → 0x0FFF', async () => {
    const r = await jsr('NES_ColorToIIgs', { A: 0x20 });
    expect(r.A).toBe(0x0fff);
  });

  // NES colour 0x30 (bright white) → IIgs $0FFF
  test('colour 0x30 (bright white) → 0x0FFF', async () => {
    const r = await jsr('NES_ColorToIIgs', { A: 0x30 });
    expect(r.A).toBe(0x0fff);
  });

  // High bits beyond bit 5 must be masked: 0x40 should wrap to 0x00 → $0777
  test('colour 0x40 masked to 0x00 → 0x0777', async () => {
    const r = await jsr('NES_ColorToIIgs', { A: 0x40 });
    expect(r.A).toBe(0x0777);
  });

  // NES colour 0x0F is an illegal black → IIgs $0000
  test('illegal colour 0x0F → 0x0000', async () => {
    const r = await jsr('NES_ColorToIIgs', { A: 0x0f });
    expect(r.A).toBe(0x0000);
  });
});
