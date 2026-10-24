#!/usr/bin/env node
'use strict';

/**
 * convert.js -- Tengen Tetris: the ca65 disassembly (https://github.com/zohassadar/TengenTetrisDisasm)
 * to Merlin32 source for the IIgs runtime.
 *
 *   node tools/convert.js <disasm dir>
 *
 * Writes, in the game's directory:
 *
 *   ram.s       the RAM map (tetris-ram.asm) and the game constants (constants.asm) as equates
 *   rom_code.s  main.asm (and the nametable includes) from $8000 to $FFFF, with the shims below
 *   chr0.bin    CHR-ROM bank 0 (gfx/game_tileset.png + dancers_tileset.png): the menus and the game
 *   chr1.bin    CHR-ROM bank 1 (gfx/title_tileset.png + various_tileset.png): the title screen and
 *               the leaderboard
 *   prg.bin     the original 32KB PRG-ROM, rebuilt from the listing's object code comments (used by
 *               tools/verify.js to check the assembled ROM; not assembled)
 *
 * da65 writes every line with its address and object code (`; 8003 A9 01`), so the conversion keeps
 * the ROM layout exactly: every shim has the size of the code it replaces (padded with NOPs), and
 * anything bigger is a JSR to a routine in the support area below $8000 (support.s).  The vectors,
 * the RTS jump tables and the data tables stay at their NES addresses, and tools/verify.js checks
 * that every byte the shims don't touch assembles to the original.
 *
 * Shims:
 *   - PPU / APU register loads and stores -> JSR to the rom_inject.s hooks (BIT_2002 is in support.s)
 *   - abs,Y accesses to the NES zero page (the direct page is in another bank) -> JSR to a _ABS_Y helper
 *   - the hand patches in PATCHES (by address): reset, the NMI, the CNROM bank write, the controller
 *     read, the indirect APU writes and the loops that wait for the NMI (they yield instead)
 */

const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const GAME_DIR = path.resolve(__dirname, '..');

// The PPU / APU registers, by the names main.asm gives them
const REGS = {
  PPUCTRL: '2000', PPUMASK: '2001', PPUSTATUS: '2002', OAMADDR: '2003', OAMDATA: '2004',
  PPUSCROLL: '2005', PPUADDR: '2006', PPUDATA: '2007',
  SQ1_VOL: '4000', SQ1_SWEEP: '4001', SQ1_LO: '4002', SQ1_HI: '4003',
  SQ2_VOL: '4004', SQ2_SWEEP: '4005', SQ2_LO: '4006', SQ2_HI: '4007',
  TRI_LINEAR: '4008', TRI_LO: '400A', TRI_HI: '400B',
  NOISE_VOL: '400C', NOISE_LO: '400E', NOISE_HI: '400F',
  DMC_FREQ: '4010', DMC_RAW: '4011', DMC_START: '4012', DMC_LEN: '4013',
  OAMDMA: '4014', SND_CHN: '4015', JOY1: '4016', JOY2: '4017',
};

// The register hooks that exist (rom_inject.s, and BIT_2002 in support.s)
const HOOKS = new Set([
  'STA_2000', 'STX_2000', 'STA_2001', 'STX_2001', 'LDA_2002', 'LDX_2002', 'BIT_2002', 'STA_2003',
  'STA_2005', 'STA_2006', 'STX_2006', 'STY_2006', 'LDA_2007', 'STA_2007', 'STX_2007',
  'STA_4014', 'STA_4015', 'STX_4015', 'STA_4016', 'STX_4016', 'LDA_4016', 'LDA_4017', 'STA_4017',
]);

// abs,Y to the NES zero page: the rom_inject.s macro for each mnemonic
const ABS_Y_MACROS = { lda: 'LDA_ABS_Y', sta: 'STA_ABS_Y', cmp: 'CMP_ABS_Y', sbc: 'SBC_ABS_Y', adc: 'ADC_ABS_Y', ora: 'ORA_ABS_Y' };

const nop = (n) => (n > 0 ? [`            ds    ${n},$EA                 ; (NOP padding: the ROM layout is kept)`] : []);

/**
 * The hand patches, by the address of the first instruction they replace.  `bytes` is how many bytes
 * of the original they replace (whole instructions, checked); `lines` replace them, padded with NOPs
 * to the same size (`size` is the size of `lines`).  Labels inside the replaced range are kept (they
 * are emitted in place), so branches into it still assemble; the routines they call are in support.s.
 */
const PATCHES = {
  // reset: no SEI / CLD (the task runs with interrupts on), and the stack is the runtime's (no TXS)
  0xA911: { bytes: 2, size: 0, why: 'reset: sei / cld (the NES task runs with interrupts enabled)' },
  0xA926: { bytes: 1, size: 0, why: 'reset: txs (the runtime owns the stack)' },
  // reset: the two PPUSTATUS VBlank waits
  0xA91B: { bytes: 5, size: 0, why: 'reset: VBlank wait 1 (no PPUSTATUS VBlank flag to wait on)' },
  0xA920: { bytes: 5, size: 0, why: 'reset: VBlank wait 2' },

  // mainLoop: wait for the next frame by yielding to the runtime, which runs the NMI
  0x800F: { bytes: 4, size: 3, lines: ['            jsr   WaitNextFrame_GS          ; (was lda frameCounterLow / cmp frameCounterLowLastFrame)'],
            why: 'mainLoop: yield until the NMI has run' },

  // L8ED0: wait until the NMI has emptied the PPU slots
  0x8ED0: { bytes: 6, size: 3, lines: ['            jsr   WaitPPUSlots_GS           ; (was the currentPPUSlot = nextPPUSlot spin)'],
            why: 'L8ED0: yield until the NMI has sent the staged PPU writes' },

  // enableNMIAndWaitForRendering: @waitForRender spins until the NMI has sent the slot
  0xA3EE: { bytes: 4, size: 3, lines: ['            jsr   WaitRenderSlot_GS         ; (was lda ppuRenderSlot0Length,x / bne @waitForRender)'],
            why: 'enableNMIAndWaitForRendering: yield until the NMI has sent the slot' },

  // waitForNMIAndDisablePPURendering: @waitForNMI spins until every slot is sent
  0xA44E: { bytes: 10, size: 3, lines: ['            jsr   WaitPPUIdle_GS            ; (was the @waitForNMI spin)'],
            why: 'waitForNMIAndDisablePPURendering: yield until the NMI has sent every slot' },

  // enablePPURendering: the two PPUSTATUS VBlank waits
  0xA469: { bytes: 10, size: 0, why: 'enablePPURendering: the VBlank waits' },

  // pollController: the serial controller read -> the runtime's controller bytes
  0xA41A: { bytes: 23, size: 3, lines: ['            jsr   ReadControllers_GS        ; (was the 8-bit JOY1 / JOY2 serial read)'],
            why: 'pollController: read the controllers from the runtime' },

  // setCNROMBank: record the CHR bank the ROM selects (ppu_bank), for the render to load
  0x9EB0: { bytes: 3, size: 3, lines: ['            jsr   SetCNROMBank_GS           ; (was stx currentCHRBank / inx)'],
            why: 'setCNROMBank: record the CHR-ROM bank (ppu_bank)' },

  // nmi: the CNROM bank write (and the Tengen $6000-$603F writes): nothing to do, setCNROMBank recorded
  // the bank
  0xA7D0: { bytes: 30, size: 2, lines: ['            bra   *+30                      ; (was the $6000,x writes and sta cnromBank2or3,x)'],
            why: 'nmi: the CHR bank write (setCNROMBank_GS records the bank)' },
  // nmi: the runtime calls the NMI handler with JSL
  0xA80D: { bytes: 1, size: 1, lines: ['            rtl                             ; (was rti: the runtime calls the NMI with jsl)'],
            why: 'nmi: rti -> rtl' },

  // The APU writes through the (apuRegister) pointer -> the APU hooks
  0xD8A5: { bytes: 4, size: 3, lines: ['            jsr   WriteApuSlot1_GS          ; (was ldy #$00 / sta (apuRegister),y)'], why: 'APU slot 1 write' },
  0xD8BF: { bytes: 5, size: 3, lines: ['            jsr   WriteApuSlot2_GS          ; (was lda audioStagingSlot2 / sta (apuRegister),y)'], why: 'APU slot 2 write' },
  0xD8CB: { bytes: 5, size: 3, lines: ['            jsr   WriteApuSlot3_GS          ; (was lda audioStagingSlot3 / sta (apuRegister),y)'], why: 'APU slot 3 write' },
  0xD8D7: { bytes: 5, size: 3, lines: ['            jsr   WriteApuSlot4_GS          ; (was lda audioStagingSlot4 / sta (apuRegister),y)'], why: 'APU slot 4 write' },
};

// ---------------------------------------------------------------------------------------------------
// ca65 -> Merlin32

const LISTING_RE = /^(.*?);\s([0-9A-F]{4})((?:\s[0-9A-F]{2})+)/;

// 6502 instruction lengths by opcode (the documented opcodes; 0 = not one)
const OPLEN = (() => {
  const t = new Array(256).fill(0);
  const set = (len, ops) => ops.forEach((o) => { t[o] = len; });
  set(1, [0x00, 0x08, 0x0A, 0x18, 0x28, 0x2A, 0x38, 0x40, 0x48, 0x4A, 0x58, 0x60, 0x68, 0x6A, 0x78, 0x88, 0x8A,
    0x98, 0x9A, 0xA8, 0xAA, 0xB8, 0xBA, 0xC8, 0xCA, 0xD8, 0xE8, 0xEA, 0xF8]);
  set(3, [0x0D, 0x0E, 0x19, 0x1D, 0x1E, 0x20, 0x2C, 0x2D, 0x2E, 0x39, 0x3D, 0x3E, 0x4C, 0x4D, 0x4E, 0x59, 0x5D,
    0x5E, 0x6C, 0x6D, 0x6E, 0x79, 0x7D, 0x7E, 0x8C, 0x8D, 0x8E, 0x99, 0x9D, 0xAC, 0xAD, 0xAE, 0xB9, 0xBC, 0xBD,
    0xBE, 0xCC, 0xCD, 0xCE, 0xD9, 0xDD, 0xDE, 0xEC, 0xED, 0xEE, 0xF9, 0xFD, 0xFE]);
  set(2, [0x01, 0x05, 0x06, 0x09, 0x10, 0x11, 0x15, 0x16, 0x21, 0x24, 0x25, 0x26, 0x29, 0x30, 0x31, 0x35, 0x36,
    0x41, 0x45, 0x46, 0x49, 0x50, 0x51, 0x55, 0x56, 0x61, 0x65, 0x66, 0x69, 0x70, 0x71, 0x75, 0x76, 0x81, 0x84,
    0x85, 0x86, 0x90, 0x91, 0x94, 0x95, 0x96, 0xA0, 0xA1, 0xA2, 0xA4, 0xA5, 0xA6, 0xA9, 0xB0, 0xB1, 0xB4, 0xB5,
    0xB6, 0xC0, 0xC1, 0xC4, 0xC5, 0xC6, 0xC9, 0xD0, 0xD1, 0xD5, 0xD6, 0xE0, 0xE1, 0xE4, 0xE5, 0xE6, 0xE9, 0xF0,
    0xF1, 0xF5, 0xF6]);
  return t;
})();

/** The number of object code bytes a source line assembles to (data: its arguments; code: its opcode) */
function lineLength(code, firstByte, where) {
  const d = code.trim().match(/^\.(byte|word|addr|dbyt)\s+(.*)$/i);
  if (d) return d[2].split(',').length * (d[1].toLowerCase() === 'byte' ? 1 : 2);
  const len = OPLEN[firstByte];
  if (!len) throw new Error(`${where}: unknown opcode $${firstByte.toString(16)}`);
  return len;
}

/** Split a main.asm line: { code, comment, addr, bytes } (addr / bytes are null without object code) */
function splitLine(raw, where) {
  const line = raw.replace(/\s+$/, '');
  const m = line.match(LISTING_RE);
  if (m) {
    const code = m[1].replace(/\s+$/, '');
    // the hex dump runs into the ASCII dump: take as many bytes as the line assembles to
    const all = m[3].trim().split(/\s+/).map((h) => parseInt(h, 16));
    const bytes = all.slice(0, lineLength(code, all[0], where));
    return { code, comment: null, addr: parseInt(m[2], 16), bytes };
  }
  const c = line.indexOf(';');
  if (c >= 0) return { code: line.slice(0, c).replace(/\s+$/, ''), comment: line.slice(c), addr: null, bytes: null };
  return { code: line, comment: null, addr: null, bytes: null };
}

const hex2 = (v) => `$${v.toString(16).toUpperCase().padStart(2, '0')}`;
const hex4 = (v) => `$${v.toString(16).toUpperCase().padStart(4, '0')}`;

// A Merlin32-safe expression: symbols and numbers joined by + / -, optionally after < or >
const SAFE_EXPR = /^[<>]?(?:[A-Za-z_][A-Za-z0-9_]*|\$[0-9A-Fa-f]+|\d+)(?:[+-](?:[A-Za-z_][A-Za-z0-9_]*|\$[0-9A-Fa-f]+|\d+))*$/;

function convertLabels(text) {
  return text.replace(/@([A-Za-z_][A-Za-z0-9_]*)/g, ':$1');
}

/** Convert the operand of an instruction; returns the Merlin32 operand text */
function convertOperand(mnem, operand, bytes, where) {
  if (!operand) return '';
  if (/^a$/i.test(operand)) return '';                         // lsr a -> lsr
  if (operand.startsWith('#')) {
    const expr = operand.slice(1);
    if (SAFE_EXPR.test(expr)) return '#' + expr;
    // Anything else (~, ', *, ...): the byte the original assembled to
    if (bytes.length !== 2) throw new Error(`${where}: immediate with ${bytes.length} bytes`);
    return `#${hex2(bytes[1])}`;
  }
  return convertLabels(operand);
}

function emitInstr(mnem, operand, comment) {
  const body = `            ${mnem.padEnd(5)} ${operand}`.replace(/\s+$/, '');
  return comment ? `${body.padEnd(51)} ${comment}` : body;
}

/**
 * Convert one instruction line.  Returns { lines, absY } where absY names a helper to define.
 */
function convertInstr(code, addr, bytes, where, absYHelpers, shims) {
  const m = code.trim().match(/^([a-z]{3})(?:\s+(.*))?$/);
  if (!m) throw new Error(`${where}: can't parse '${code.trim()}'`);
  const mnem = m[1];
  const operand = (m[2] || '').trim();
  const comment = `; ${hex4(addr).slice(1)} ${bytes.map((b) => hex2(b).slice(1)).join(' ')}`;

  // PPU / APU registers
  const reg = operand.match(/^([A-Z0-9_]+)(,[xy])?$/);
  if (reg && REGS[reg[1]]) {
    if (reg[2]) throw new Error(`${where}: indexed register access '${code.trim()}'`);
    const hook = `${mnem.toUpperCase()}_${REGS[reg[1]]}`;
    if (!HOOKS.has(hook)) throw new Error(`${where}: no hook ${hook} for '${code.trim()}'`);
    if (bytes.length !== 3) throw new Error(`${where}: register access is not absolute`);
    shims.push({ addr, len: 3, what: `${mnem} ${reg[1]} -> jsr ${hook}` });
    return [emitInstr('jsr', hook, `${comment}  (${mnem} ${reg[1]})`)];
  }

  // abs,Y with a zero page address: the NES zero page is the direct page, in another bank
  const absy = operand.match(/^(.+),y$/);
  if (absy && bytes.length === 3 && bytes[2] === 0x00 && !operand.startsWith('(')) {
    const macro = ABS_Y_MACROS[mnem];
    if (!macro) throw new Error(`${where}: no abs,Y helper for '${mnem}'`);
    let target = absy[1];
    let name;
    if (/^\$[0-9A-Fa-f]+$/.test(target)) {
      const v = parseInt(target.slice(1), 16);
      target = hex2(v);                                        // $7A, not $007A (Merlin32 sizes it as DP)
      name = `${mnem.toUpperCase()}_00${hex2(v).slice(1)}_Y`;
    } else {
      name = `${mnem.toUpperCase()}_${target.replace(/\+/g, '_p')}_Y`;
    }
    absYHelpers.set(name, `${macro} ${target}`);
    shims.push({ addr, len: 3, what: `${mnem} ${absy[1]},y -> jsr ${name}` });
    return [emitInstr('jsr', name, `${comment}  (${mnem} ${absy[1]},y: the NES zero page)`)];
  }

  // A 16-bit operand that Merlin32 would assemble as a direct page access (or the reverse) would
  // change the layout: verify.js catches those, but catch the obvious ones here
  return [emitInstr(mnem, convertOperand(mnem, operand, bytes, where), comment)];
}

/** Convert a data directive line */
function convertData(code, where) {
  const m = code.trim().match(/^\.(byte|word|addr|dbyt)\s+(.*)$/i);
  if (!m) return null;
  const op = { byte: 'db', word: 'dw', addr: 'da', dbyt: 'ddb' }[m[1].toLowerCase()];
  const args = m[2].split(',').map((a) => a.trim());
  for (const a of args) {
    if (!SAFE_EXPR.test(a)) throw new Error(`${where}: unsupported data expression '${a}'`);
  }
  return `            ${op.padEnd(5)} ${args.map(convertLabels).join(',')}`;
}

/**
 * Read main.asm with its includes expanded: [{ raw, where }]
 */
function readSource(disasmDir) {
  const out = [];
  const lines = fs.readFileSync(path.join(disasmDir, 'main.asm'), 'utf8').split(/\r?\n/);
  lines.forEach((raw, i) => {
    const inc = raw.match(/^\s*\.include\s+"([^"]+)"/);
    if (inc) {
      const incLines = fs.readFileSync(path.join(disasmDir, inc[1]), 'utf8').split(/\r?\n/);
      out.push({ raw: `; (${inc[1]})`, where: `main.asm:${i + 1}` });
      incLines.forEach((r, k) => out.push({ raw: r, where: `${inc[1]}:${k + 1}` }));
      return;
    }
    out.push({ raw, where: `main.asm:${i + 1}` });
  });
  return out;
}

function convertMain(disasmDir) {
  const src = readSource(disasmDir);
  const out = [];
  const prg = Buffer.alloc(0x8000, 0xFF);
  const covered = new Uint8Array(0x8000);
  const absYHelpers = new Map();
  const patchesUsed = new Set();
  const shims = [];

  let inBody = false;
  let patch = null;                    // the patch being applied: { start, end, emitted }

  for (const { raw, where } of src) {
    const { code, comment, addr, bytes } = splitLine(raw, where);
    const trimmed = code.trim();

    // The header (the register equates) is replaced by the equates in support.s
    if (!inBody) {
      if (/^[A-Za-z_][A-Za-z0-9_]*:/.test(trimmed)) inBody = true;
      else continue;
    }

    // The original bytes
    if (addr !== null) {
      bytes.forEach((b, k) => {
        const a = addr + k - 0x8000;
        if (a < 0 || a >= 0x8000) throw new Error(`${where}: address out of the PRG`);
        if (covered[a]) throw new Error(`${where}: address ${hex4(addr + k)} twice`);
        prg[a] = b;
        covered[a] = 1;
      });
    }

    if (!trimmed) {
      out.push(comment ? comment : '');
      continue;
    }

    // ca65 directives with no Merlin32 equivalent
    if (/^\.(segment|code|setcpu)\b/.test(trimmed)) {
      out.push(`; ${trimmed}`);
      continue;
    }

    // A label (on its own line in this disassembly)
    const lab = trimmed.match(/^(@?[A-Za-z_][A-Za-z0-9_]*):\s*(.*)$/);
    if (lab) {
      if (lab[2]) throw new Error(`${where}: code after a label`);
      out.push(convertLabels(lab[1]));
      continue;
    }

    if (addr === null) throw new Error(`${where}: no object code for '${trimmed}'`);

    // Inside a patch: drop the original instruction (keep it as a comment)
    if (patch && addr < patch.end) {
      if (addr + bytes.length > patch.end) throw new Error(`${where}: patch at ${hex4(patch.start)} ends inside an instruction`);
      out.push(`;           ${trimmed.padEnd(40)}${comment || ''}`.replace(/\s+$/, '') + `  ; ${hex4(addr).slice(1)} (patched)`);
      if (addr + bytes.length === patch.end) {
        out.push(...nop(patch.def.bytes - patch.def.size));
        patch = null;
      }
      continue;
    }
    if (patch) throw new Error(`${where}: patch at ${hex4(patch.start)} not closed`);

    if (PATCHES[addr]) {
      const def = PATCHES[addr];
      patchesUsed.add(addr);
      shims.push({ addr, len: def.bytes, what: def.why });
      if (def.size > def.bytes) throw new Error(`patch ${hex4(addr)}: ${def.size} bytes in ${def.bytes}`);
      out.push(`; IIgs: ${def.why}`);
      out.push(...(def.lines || []));
      patch = { start: addr, end: addr + def.bytes, def };
      // Re-run this line as the first one of the patch
      out.push(`;           ${trimmed.padEnd(40)}`.replace(/\s+$/, '') + `  ; ${hex4(addr).slice(1)} (patched)`);
      if (addr + bytes.length > patch.end) throw new Error(`${where}: patch at ${hex4(addr)} ends inside an instruction`);
      if (addr + bytes.length === patch.end) {
        out.push(...nop(def.bytes - def.size));
        patch = null;
      }
      continue;
    }

    const data = convertData(trimmed, where);
    if (data !== null) {
      out.push(`${data.padEnd(51)} ; ${hex4(addr).slice(1)}`);
      continue;
    }

    out.push(...convertInstr(trimmed, addr, bytes, where, absYHelpers, shims));
  }

  const missing = Object.keys(PATCHES).map(Number).filter((a) => !patchesUsed.has(a));
  if (missing.length) throw new Error(`patches not applied: ${missing.map(hex4).join(', ')}`);
  for (let a = 0; a < 0x8000; a++) {
    if (!covered[a]) throw new Error(`no object code for ${hex4(a + 0x8000)}`);
  }
  return { out, prg, absYHelpers, shims };
}

// ---------------------------------------------------------------------------------------------------
// RAM map and constants

function convertRam(disasmDir) {
  const out = [];
  let pc = 0;
  for (const raw of fs.readFileSync(path.join(disasmDir, 'tetris-ram.asm'), 'utf8').split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    if (line === '.zeropage') { pc = 0x0000; out.push('', '; Zero page'); continue; }
    if (line === '.bss') { pc = 0x0100; out.push('', '; RAM'); continue; }
    const m = line.match(/^(?:([A-Za-z_][A-Za-z0-9_]*):)?\s*\.res\s+(\$[0-9A-Fa-f]+|\d+)\s*(?:;\s*(.*))?$/);
    if (!m) throw new Error(`tetris-ram.asm: can't parse '${line}'`);
    const size = m[2].startsWith('$') ? parseInt(m[2].slice(1), 16) : parseInt(m[2], 10);
    if (m[1]) {
      // the comment starts with the address; keep what follows it
      const note = (m[3] || '').replace(/^\$[0-9A-Fa-f]{4}\s*/, '');
      const label = `${m[1]}`.padEnd(32);
      out.push(`${label}equ   ${pc < 0x100 ? hex2(pc) + "  " : hex4(pc)}${size > 1 ? `          ; ${size} bytes` : ''}${note ? `${size > 1 ? ', ' : '          ; '}${note}` : ''}`);
    }
    pc += size;
  }
  return out;
}

function convertConstants(disasmDir) {
  const out = [];
  for (const raw of fs.readFileSync(path.join(disasmDir, 'constants.asm'), 'utf8').split(/\r?\n/)) {
    const { code, comment } = splitLine(raw);
    const m = code.trim().match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(\S+)$/);
    if (m) out.push(`${m[1].padEnd(32)}equ   ${m[2]}${comment ? `          ${comment}` : ''}`);
    else if (comment) out.push(comment);
    else if (!code.trim()) out.push('');
    else throw new Error(`constants.asm: can't parse '${raw}'`);
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------
// CHR-ROM: the tileset PNGs (128 x 128, 4 grays: 000000 555555 aaaaaa ffffff = colors 0-3)

const CHR_PALETTE = { '000000': 0, '555555': 1, 'aaaaaa': 2, 'ffffff': 3 };

function encodeChr(file) {
  const png = PNG.sync.read(fs.readFileSync(file));
  if (png.width !== 128 || png.height % 8) throw new Error(`${file}: ${png.width}x${png.height}`);
  const tiles = (png.width / 8) * (png.height / 8);
  const chr = Buffer.alloc(tiles * 16);
  for (let t = 0; t < tiles; t++) {
    const tx = (t % 16) * 8;
    const ty = Math.floor(t / 16) * 8;
    for (let y = 0; y < 8; y++) {
      let lo = 0;
      let hi = 0;
      for (let x = 0; x < 8; x++) {
        const p = ((ty + y) * png.width + tx + x) * 4;
        const rgb = png.data.slice(p, p + 3).toString('hex');
        const c = CHR_PALETTE[rgb];
        if (c === undefined) throw new Error(`${file}: color ${rgb} at ${tx + x},${ty + y}`);
        lo |= (c & 1) << (7 - x);
        hi |= ((c >> 1) & 1) << (7 - x);
      }
      chr[t * 16 + y] = lo;
      chr[t * 16 + 8 + y] = hi;
    }
  }
  return chr;
}

// ---------------------------------------------------------------------------------------------------

function main() {
  const disasmDir = process.argv[2];
  if (!disasmDir) {
    console.error('usage: node tools/convert.js <TengenTetrisDisasm dir>');
    process.exit(1);
  }

  const header = [
    '; Tengen Tetris -- generated by tools/convert.js from the ca65 disassembly',
    '; (https://github.com/zohassadar/TengenTetrisDisasm).  Do not edit: change the converter (its PATCHES',
    '; table holds the hand patches) or support.s, and run it again.',
  ];

  const ram = convertRam(disasmDir);
  const consts = convertConstants(disasmDir);
  fs.writeFileSync(path.join(GAME_DIR, 'ram.s'), [
    ...header, '', '; The RAM map (tetris-ram.asm)', ...ram, '', '; The game constants (constants.asm)', ...consts, '',
  ].join('\n'));

  const { out, prg, absYHelpers, shims } = convertMain(disasmDir);
  const helpers = [...absYHelpers.entries()].sort().map(([name, body]) => `${name.padEnd(36)}${body}`);
  fs.writeFileSync(path.join(GAME_DIR, 'rom_code.s'), [
    ...header,
    '; The PRG-ROM, $8000-$FFFF, at its NES addresses (put by rom.s after the support area).',
    '',
    '            mx    %11',
    '',
    ...out,
    '',
  ].join('\n'));
  fs.writeFileSync(path.join(GAME_DIR, 'abs_y.s'), [
    ...header,
    '; The abs,Y accesses to the NES zero page (put by rom.s in the support area; the macros are in',
    '; rom/rom_inject.s)',
    '            mx    %11',
    ...helpers,
    '',
  ].join('\n'));
  fs.writeFileSync(path.join(GAME_DIR, 'prg.bin'), prg);
  fs.writeFileSync(path.join(GAME_DIR, 'tools', 'shims.json'), JSON.stringify(shims.map((s) => ({ ...s, addr: hex4(s.addr) })), null, 1) + '\n');

  const gfx = (n) => encodeChr(path.join(disasmDir, 'gfx', `${n}_tileset.png`));
  fs.writeFileSync(path.join(GAME_DIR, 'chr0.bin'), Buffer.concat([gfx('game'), gfx('dancers')]));
  fs.writeFileSync(path.join(GAME_DIR, 'chr1.bin'), Buffer.concat([gfx('title'), gfx('various')]));

  console.log(`rom_code.s: ${out.length} lines, ${Object.keys(PATCHES).length} patches, ${absYHelpers.size} abs,Y helpers`);
  console.log(`${shims.length} changed ranges (tools/shims.json); ram.s, abs_y.s, prg.bin, chr0.bin, chr1.bin written`);
}

main();
