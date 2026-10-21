#!/usr/bin/env node
'use strict';
// Stage text files for a ProDOS disk image: copies each file into the output folder with CR line
// endings (ProDOS / Apple II text) and writes the folder's _FileInformation.txt, which gives Cadius
// ADDFILE their file type (TXT, $04).
//
//   node scripts/prodos-text.js <output folder> <text file>...
const fs = require('fs');
const path = require('path');

const [outDir, ...files] = process.argv.slice(2);
if (!outDir || files.length === 0) {
    console.error('usage: prodos-text.js <output folder> <text file>...');
    process.exit(1);
}
fs.mkdirSync(outDir, { recursive: true });

const info = [];
for (const file of files) {
    const name = path.basename(file);
    if (!/^[A-Za-z][A-Za-z0-9.]{0,14}$/.test(name)) {
        console.error(`prodos-text: ${name} is not a ProDOS file name (a letter, then up to 14 letters, digits or periods)`);
        process.exit(1);
    }
    const text = fs.readFileSync(file, 'latin1').replace(/\r\n?/g, '\n').replace(/\n/g, '\r');
    fs.writeFileSync(path.join(outDir, name), text, 'latin1');
    info.push(`${name}=Type(04),AuxType(0000),VersionCreate(00),MinVersion(00),Access(E3),` +
        'FolderInfo1(000000000000000000000000000000000000),FolderInfo2(000000000000000000000000000000000000)');
}
fs.writeFileSync(path.join(outDir, '_FileInformation.txt'), info.join('\r\n') + '\r\n');
