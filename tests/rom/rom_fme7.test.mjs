/**
 * Native tests for the optional FME-7 register-state module. These assemble
 * the real source and execute its JSL entries; no cartridge data is needed.
 * Register state is distinct from applying mappings to native code or PPU RAM.
 */
import { describe, test, expect } from 'vitest';
import { join } from 'node:path';
import { cpu65816 } from 'iigs-unit';

const { sequence } = cpu65816({
  assembler: 'merlin32',
  includes: [join(process.env.SRC_ROOT, 'rom/rom_fme7.s')],
});

// GoldenGate loads the harness in bank $02. All tested entries run with an
// unrelated data bank, so DBR-relative writes to the wrong bank fail loudly.
const CALLER = { DBR: 0x05, DP: 0x0800, SP: 0x09FF, P: 0x30, mx: 3 };
const STATE = [
  { label: 'FME7_Command', length: 1 },
  { label: 'FME7_CHR', length: 8 },
  { label: 'FME7_PRG6000', length: 1 },
  { label: 'FME7_PRG', length: 4 },
  { label: 'FME7_Mirror', length: 1 },
];

const initialState = (last = 31) => ({
  FME7_Command: [0],
  FME7_CHR: Array(8).fill(0),
  FME7_PRG6000: [0],
  FME7_PRG: [0, 0, 0, last],
  FME7_Mirror: [0],
});

function reset(last = 31) {
  return sequence().jsl('FME7_Reset', { ...CALLER, A: last });
}

function write(seq, command, value) {
  return seq
    .jsl('FME7_Select', { A: command })
    .jsl('FME7_Write', { A: value });
}

async function state(seq) {
  // AUnit_AppendMem captures from DBR. Restore the harness bank only AFTER
  // the tested calls; ABI preservation is checked separately without this.
  seq.inline('            phk\n            plb');
  for (const spec of STATE) seq.captureMemory(spec);
  const r = await seq.run();
  return Object.fromEntries(STATE.map(({ label }) => [label, [...r.memory[label]]]));
}

// Give every writable bank a distinct value before isolated-write tests.
// An off-by-one store must corrupt a nonzero neighbour, not a spare zero.
function seeded() {
  const seq = reset();
  for (let slot = 0; slot < 8; slot++) write(seq, slot, 0x80 + slot);
  write(seq, 8, 0xE5);
  write(seq, 9, 0x11);
  write(seq, 10, 0x22);
  write(seq, 11, 0x33);
  write(seq, 12, 3);
  return seq;
}

function seededState(command = 12) {
  return {
    FME7_Command: [command],
    FME7_CHR: [0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87],
    FME7_PRG6000: [0xE5],
    FME7_PRG: [0x11, 0x22, 0x33, 31],
    FME7_Mirror: [3],
  };
}

describe('FME7_Reset', () => {
  test('initializes all state and accepts the configured final 8 KiB bank', async () => {
    expect(await state(reset())).toEqual(initialState());
  });

  test('masks the final bank to six hardware bits', async () => {
    expect(await state(reset(0xFF))).toEqual(initialState(63));
  });

  test('clears previously written state and replaces the fixed bank on every reset', async () => {
    expect(await state(seeded().jsl('FME7_Reset', { A: 5 }))).toEqual(initialState(5));
  });
});

describe('FME7_Select', () => {
  test.each(Array.from({ length: 16 }, (_, command) => command))(
    'selects command $%x while ignoring the upper command nibble',
    async (command) => {
      const expected = initialState();
      expected.FME7_Command = [command];
      expect(await state(reset().jsl('FME7_Select', { A: 0xF0 | command }))).toEqual(expected);
    },
  );

  test('does not write a parameter merely by selecting another command', async () => {
    expect(await state(seeded().jsl('FME7_Select', { A: 0xF1 }))).toEqual(seededState(1));
  });
});

describe('FME7_Write', () => {
  test.each(Array.from({ length: 8 }, (_, slot) => slot))(
    'writes all eight CHR bank bits to slot %i without changing another register',
    async (slot) => {
      const expected = seededState(slot);
      expected.FME7_CHR[slot] = 0xFF;
      expect(await state(write(seeded(), slot, 0xFF))).toEqual(expected);
    },
  );

  test.each([0x00, 0x20, 0x3F, 0x40, 0x7F, 0x80, 0xBF, 0xC0, 0xFF])(
    'retains the complete $6000 bank/RAM-control byte $%x',
    async (value) => {
      const expected = seededState(8);
      expected.FME7_PRG6000 = [value];
      expect(await state(write(seeded(), 8, value))).toEqual(expected);
    },
  );

  test.each([9, 10, 11])(
    'keeps six PRG bank bits for command $%x and leaves the final bank fixed',
    async (command) => {
      const expected = seededState(command);
      expected.FME7_PRG[command - 9] = 0x3F;
      expect(await state(write(seeded(), command, 0xFF))).toEqual(expected);
    },
  );

  test.each([0, 1, 2, 3])('stores mirroring mode %i using only two bits', async (mode) => {
    const expected = seededState(12);
    expected.FME7_Mirror = [mode];
    expect(await state(write(seeded(), 12, 0xFC | mode))).toEqual(expected);
  });

  test.each([13, 14, 15])('leaves bank state unchanged for IRQ command $%x', async (command) => {
    expect(await state(write(seeded(), command, 0xFF))).toEqual(seededState(command));
  });

  test('keeps the selected command for successive parameter writes', async () => {
    const expected = seededState(3);
    expected.FME7_CHR[3] = 0xFE;
    const seq = write(seeded(), 3, 0x12).jsl('FME7_Write', { A: 0xFE });
    expect(await state(seq)).toEqual(expected);
  });
});

describe('FME-7 JSL calling convention', () => {
  // Both flag patterns set M/X, with flags deliberately inconsistent with A.
  // Decimal mode is tested separately because AUnit uses binary arithmetic.
  const cases = [
    ['reset', 'FME7_Reset', null, 0xFF],
    ['select', 'FME7_Select', null, 0xF9],
    ['CHR write', 'FME7_Write', 7, 0xFE],
    ['$6000 write', 'FME7_Write', 8, 0xE5],
    ['PRG write', 'FME7_Write', 11, 0xFF],
    ['mirror write', 'FME7_Write', 12, 0xFE],
    ['ignored IRQ write', 'FME7_Write', 15, 0xFF],
  ];

  for (const P of [0x30, 0xF7]) {
    test.each(cases)(`preserves registers and P=$${P.toString(16)} during %s`, async (_name, entry, command, value) => {
      const seq = reset();
      if (command !== null) seq.jsl('FME7_Select', { A: command });
      const inputs = { ...CALLER, A: 0xA500 | value, X: 0x96, Y: 0xE7, P };
      const r = await seq.jsl(entry, inputs).run();
      for (const register of ['A', 'X', 'Y', 'P', 'DBR', 'DP', 'SP']) {
        expect(r[register], register).toBe(inputs[register]);
      }
      expect(r.K).toBe(0x02);
    });
  }

  test.each(cases)('preserves decimal mode and flags during %s', async (_name, entry, command, value) => {
    const seq = sequence({ allocMemory: [{ label: 'savedFlags', length: 1 }] })
      .jsl('FME7_Reset', { ...CALLER, A: 31 });
    if (command !== null) seq.jsl('FME7_Select', { A: command });
    const r = await seq
      .jsl(entry, { ...CALLER, A: 0xA500 | value, P: 0xFF })
      // Save the returned P before clearing D for the test library's buffer
      // and stack-offset arithmetic. No instruction precedes this PHP.
      .inline(`            php
            cld
            pla
            stal  savedFlags
            phk
            plb`)
      .run();
    expect(r.memory.savedFlags[0]).toBe(0xFF);
  });
});
