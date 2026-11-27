#!/usr/bin/env node
'use strict';

/**
 * build-p8-disk -- Make a self-booting ProDOS 8 disk for a game: no GS/OS.
 *
 *   PRODOS          ProDOS 8 (dist/P8: the P8 file of GS/OS 6.0.x, /SYSTEM/P8)
 *   <NAME>.SYSTEM   the loader (scripts/p8boot/Loader.s), the first SYSTEM file, so ProDOS 8 runs it
 *   GAME.IMG        the game linked to fixed banks (scripts/omf-static.js)
 *
 * The loader reads GAME.IMG into its banks, reserves them and the memory GS/OS would have kept, and starts
 * the game as GS/OS would.  The game knows it was started this way (rom/scaffold.s: P8Booted) and makes
 * no GS/OS calls: no preference or save files, and quitting goes back to ProDOS 8.
 *
 *   node scripts/build-p8-disk.js <OMF load file> <disk image .2mg> [--name SMB] [--first-bank 2]
 */

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { linkStatic } = require('./omf-static.js');

const ROOT = path.resolve(__dirname, '..');
const CONFIG = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8')).config;
const P8 = path.join(ROOT, 'dist', 'P8');
const LOADER = path.join(__dirname, 'p8boot', 'Loader.s');

const INFO = (name, type, aux) =>
    `${name}=Type(${type}),AuxType(${aux}),VersionCreate(00),MinVersion(00),Access(E3),` +
    'FolderInfo1(000000000000000000000000000000000000),FolderInfo2(000000000000000000000000000000000000)\r\n';

function run(exe, args, opts = {}) {
    return execFileSync(exe, args, { stdio: ['ignore', 'pipe', 'inherit'], ...opts }).toString();
}

function buildP8Disk(appFile, imageFile, name = 'GAME', firstBank = 2) {
    if (!fs.existsSync(P8)) throw new Error(`${P8}: missing (ProDOS 8: the P8 file from a GS/OS 6.0.x disk's /SYSTEM)`);
    name = name.toUpperCase().replace(/[^A-Z0-9.]/g, '').slice(0, 8) || 'GAME';
    const stage = fs.mkdtempSync(path.join(os.tmpdir(), 'p8disk-'));

    // The game, linked to fixed banks
    linkStatic(appFile, path.join(stage, 'GAME.IMG'), firstBank, true);

    // The loader (Merlin32 writes the binary next to the source, named after it)
    const asmDir = fs.mkdtempSync(path.join(os.tmpdir(), 'p8loader-'));
    fs.copyFileSync(LOADER, path.join(asmDir, 'Loader.s'));
    run(CONFIG.merlin32, ['-V', path.resolve(ROOT, CONFIG.macros), path.join(asmDir, 'Loader.s')], { cwd: asmDir });
    if (fs.existsSync(path.join(asmDir, 'error_output.txt'))) throw new Error('Loader.s: Merlin32 reported an error');
    const sys = `${name}.SYSTEM`;
    fs.copyFileSync(path.join(asmDir, 'Loader'), path.join(stage, sys));
    fs.copyFileSync(P8, path.join(stage, 'PRODOS'));

    fs.writeFileSync(path.join(stage, '_FileInformation.txt'),
        INFO('PRODOS', 'FF', '0000') + INFO(sys, 'FF', '2000') + INFO('GAME.IMG', '06', '0000'));

    // The volume: 800KB if it fits, else 32MB (a hard disk image)
    const bytes = ['PRODOS', sys, 'GAME.IMG'].reduce((n, f) => n + fs.statSync(path.join(stage, f)).size, 0);
    const size = bytes < 760 * 1024 ? '800KB' : '32MB';
    if (fs.existsSync(imageFile)) fs.unlinkSync(imageFile);
    run(CONFIG.cadius, ['CREATEVOLUME', imageFile, name, size]);
    for (const f of ['PRODOS', sys, 'GAME.IMG']) run(CONFIG.cadius, ['ADDFILE', imageFile, `/${name}/`, path.join(stage, f)]);
    process.stdout.write(run(CONFIG.cadius, ['CATALOG', imageFile]).split('\n').filter(l => /SYS|BIN|\$0/.test(l)).join('\n') + '\n');
    console.log(`build-p8-disk: ${imageFile} (${size})`);
}

module.exports = { buildP8Disk };

if (require.main === module) {
    const argv = process.argv.slice(2);
    const pos = [];
    let name = 'GAME', first = 2;
    for (let i = 0; i < argv.length; i++) {
        if (argv[i] === '--name') name = argv[++i];
        else if (argv[i] === '--first-bank') first = parseInt(argv[++i]);
        else pos.push(argv[i]);
    }
    if (pos.length !== 2) {
        console.error('usage: build-p8-disk.js <OMF load file> <disk image .2mg> [--name SMB] [--first-bank 2]');
        process.exit(1);
    }
    buildP8Disk(path.resolve(pos[0]), path.resolve(pos[1]), name, first);
}
