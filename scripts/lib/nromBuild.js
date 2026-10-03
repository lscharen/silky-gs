'use strict';

/**
 * nromBuild — shared build steps for NROM (static CHR-ROM) games
 *
 * The CHR-ROM is converted offline into the 64KB tiledata bank instead of at
 * startup.  Every 16-byte tile of the 8KB CHR-ROM is converted with
 * ConvertROMTile2 (bitmap + mask + mirrored variants, 128 bytes per tile), so
 * pattern table $0000 fills the first half of the bank and pattern table
 * $1000 the second half.  Nothing here depends on which pattern table PPUCTRL
 * selects for the background or the sprites; Main.s compiles tiles out of
 * this bank after NES_StartUp (ROM_CompileBackgroundTiles /
 * ROM_CompileSpriteTiles) and the game's TileData.s assembles it into the
 * CHRDATA segment with `putbin tiledata.bin`.
 *
 * The CHR-ROM bytes are reconstructed from the game's own PPU.s: everything
 * between the `CHR_ROM` and `PPU_CIRAM` labels, following its `put` and
 * `putbin` directives.  This is exactly what gets assembled into the PPU bank
 * as CHR_ROM, so the two can never disagree.
 */

const fs   = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { convertRomTile2 } = require('./nesTileConvert.js');

const PROJECT_ROOT = path.resolve(__dirname, '..', '..');
const PACKAGE_JSON = require(path.join(PROJECT_ROOT, 'package.json'));

const TILE_SIZE  = 16;
const TILE_COUNT = 512;
const CHR_SIZE   = TILE_COUNT * TILE_SIZE;

// Evaluate a Merlin32 operand made of numbers and symbols joined by + and -
function evalExpr(expr, symbols, where) {
  const s = expr.replace(/[{}\s]/g, '');
  let total = 0;
  const re = /([+-]?)(\$[0-9a-fA-F]+|%[01]+|\d+|[A-Za-z_][A-Za-z0-9_]*)/gy;
  let m;
  let pos = 0;
  while (pos < s.length) {
    re.lastIndex = pos;
    if (!(m = re.exec(s))) throw new Error(`${where}: cannot evaluate '${expr}'`);
    const [, sign, tok] = m;
    let v;
    if (tok[0] === '$') v = parseInt(tok.slice(1), 16);
    else if (tok[0] === '%') v = parseInt(tok.slice(1), 2);
    else if (/^\d/.test(tok)) v = parseInt(tok, 10);
    else if (tok in symbols) v = symbols[tok];
    else throw new Error(`${where}: unknown symbol '${tok}'`);
    total += sign === '-' ? -v : v;
    pos = re.lastIndex;
  }
  return total;
}

// Extract the data bytes from a Merlin32 source file (db / dfb / ddb / dw / da / hex,
// with `name = value` and `name equ value` symbols)
function parseDataSource(file) {
  const bytes = [];
  const symbols = {};
  const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
  lines.forEach((line, i) => {
    const where = `${path.basename(file)}:${i + 1}`;
    const code = line.split(';')[0];
    if (!code.trim()) return;

    let m = code.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*(?:=|\s+equ\s+)(.+)$/i);
    if (m) { symbols[m[1]] = evalExpr(m[2], symbols, where); return; }

    m = code.match(/^(?:[A-Za-z_:][A-Za-z0-9_]*)?\s+(\S+)\s*(.*)$/);
    if (!m) return;                                   // label on its own
    const op = m[1].toLowerCase();
    const args = m[2].trim();
    if (op === 'hex') {
      const hex = args.replace(/[,\s]/g, '');
      for (let k = 0; k < hex.length; k += 2) bytes.push(parseInt(hex.substr(k, 2), 16));
      return;
    }
    const vals = () => args.split(',').map(a => evalExpr(a, symbols, where));
    if (op === 'ds') {
      if (args.startsWith('\\')) throw new Error(`${where}: page-align 'ds \\' is not supported in CHR data`);
      const [count, fill = 0] = vals();
      for (let k = 0; k < count; k++) bytes.push(fill & 0xFF);
    }
    else if (op === 'db' || op === 'dfb') vals().forEach(v => bytes.push(v & 0xFF));
    else if (op === 'dw' || op === 'da') vals().forEach(v => bytes.push(v & 0xFF, (v >> 8) & 0xFF));
    else if (op === 'ddb') vals().forEach(v => bytes.push((v >> 8) & 0xFF, v & 0xFF));
    else throw new Error(`${where}: unsupported directive '${m[1]}' in CHR data`);
  });
  return Buffer.from(bytes);
}

// Reconstruct the CHR-ROM from the CHR_ROM .. PPU_CIRAM region of the game's PPU.s
function loadChrFromPPU(gameDir) {
  const ppu = path.join(gameDir, 'PPU.s');
  const parts = [];
  let inChr = false;
  for (const line of fs.readFileSync(ppu, 'utf8').split(/\r?\n/)) {
    const code = line.split(';')[0];
    if (/^CHR_ROM\b/.test(code)) { inChr = true; continue; }
    if (/^PPU_CIRAM\b/.test(code)) break;
    if (!inChr) continue;
    const m = code.match(/^\s+(put|putbin)\s+(\S+)/i);
    if (m) {
      const file = path.join(gameDir, m[2]);
      parts.push(m[1].toLowerCase() === 'putbin' ? fs.readFileSync(file) : parseDataSource(file));
      console.log(`  CHR-ROM: ${m[1]} ${m[2]} (${parts[parts.length - 1].length} bytes)`);
    } else if (code.trim()) {
      throw new Error(`PPU.s: unexpected line in the CHR_ROM region: '${line.trim()}'`);
    }
  }
  return Buffer.concat(parts);
}

// Convert all 512 CHR-ROM tiles into the 64KB tiledata bank image
function generateTileData(gameDir) {
  console.log('Reading CHR-ROM from PPU.s');
  const chr = loadChrFromPPU(gameDir);
  if (chr.length !== CHR_SIZE) {
    throw new Error(`CHR-ROM is ${chr.length} bytes, expected ${CHR_SIZE}`);
  }

  const out = Buffer.alloc(TILE_COUNT * 128);
  for (let i = 0; i < TILE_COUNT; i++) {
    Buffer.from(convertRomTile2(chr, i * TILE_SIZE)).copy(out, i * 128);
  }
  const outFile = path.join(gameDir, 'tiledata.bin');
  fs.writeFileSync(outFile, out);
  console.log(`  wrote ${path.relative(PROJECT_ROOT, outFile)} (${TILE_COUNT} tiles, ${out.length} bytes)`);
}

function run(cmd, args) {
  console.log(`> ${cmd} ${args.join(' ')}`);
  execFileSync(cmd, args, { stdio: 'inherit', cwd: PROJECT_ROOT });
}

/**
 * Assemble a game: expand the mput blocks in Main.s and assemble the Merlin32
 * link file.  Shared by every game, NROM or not.
 *
 *   gameDir    - the directory that holds Main.s and the link file
 *   linkFile   - Merlin32 link file, relative to gameDir (e.g. 'Master.s')
 */
function assembleGame(gameDir, linkFile) {
  run(process.execPath, [path.join(PROJECT_ROOT, 'scripts', 'gen-includes.js'), path.join(gameDir, 'Main.s')]);
  run(PACKAGE_JSON.config.merlin32, ['-V', PACKAGE_JSON.config.macros, path.join(gameDir, linkFile)]);
}

/**
 * Build an NROM game: precompute tiledata.bin, then assemble it.
 *
 *   gameDir    - the game's directory (holds PPU.s, Main.s, TileData.s)
 *   linkFile   - Merlin32 link file, relative to gameDir (e.g. 'Master.s')
 */
function buildNromGame(gameDir, linkFile) {
  generateTileData(gameDir);
  assembleGame(gameDir, linkFile);
}

module.exports = { buildNromGame, assembleGame, generateTileData, loadChrFromPPU, parseDataSource };
