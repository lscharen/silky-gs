#!/usr/bin/env node
'use strict';

/**
 * make-boot-disk — Build a minimal raw 5.25" (143360-byte) floppy image
 * whose boot sector jumps straight into a fixed-address benchmark binary.
 *
 * The apple2gs ROM03 5.25" boot routine validates the boot sector (byte 0
 * must be the sector count, $01 for a single-sector loader) before
 * reading track 0 into $0800 and jumping to $0801. This image's boot
 * sector contains:
 *
 *   $0800: $01                 ; sector count -- required for ROM03 to
 *                               accept the sector and jump to $0801
 *   $0801: CLC
 *          XCE                 ; enter native mode (E=0)
 *          REP #$30            ; 16-bit A/X/Y
 *          LDA #<stack> / TCS  ; set S -- NOT done via Lua register pokes,
 *          LDA #<direct>/ TCD  ; which were found to conflict with
 *                               firmware's own emulation-mode assumptions
 *                               if set before the CPU runs its own reset
 *                               sequence
 *          [stage+copy tail]   ; The JSL + EXIT/FAIL loops below are
 *                               staged as data here and copied to $2000
 *                               immediately -- BEFORE any toolbox call
 *                               that could fail -- because $0800 is also
 *                               the application's direct page (D
 *                               register): once the benchmark code starts
 *                               running and touches its own direct-page
 *                               variables, it can physically overwrite
 *                               this boot stub sitting at $0800-$08FF,
 *                               corrupting the very loops the harness
 *                               breakpoints on. $2000 (the ProDOS SYSTEM
 *                               load address) is unused this early.
 *          _TLBootInit         ; Tool Locator cold-boot init (tool $101) --
 *                               normally done once by firmware/GS/OS before
 *                               anything touches the toolbox; our boot stub
 *                               skips all of that.
 *          _TLStartUp          ; Tool Locator StartUp (tool $201) --
 *                               registers this "application" with the Tool
 *                               Locator, a prerequisite for other tools'
 *                               StartUp calls to do anything.
 *          [GetNewID + 4x      ; Per Apple IIgs Technote #27: MMStartUp
 *           NewHandle]         ; fails if called from memory that hasn't
 *                               been allocated through the Memory Manager
 *                               (true for us -- we never went through
 *                               ProDOS 8/GS/OS's own allocation of the
 *                               memory a launched application occupies).
 *                               Fix: GetNewID for a temporary bootstrap ID
 *                               (stashed at direct-page offset $FE, NOT a
 *                               register -- a JSL to a system routine
 *                               gives no guarantee any register survives
 *                               the call), then NewHandle fixed-location
 *                               blocks covering what ProDOS 8/GS/OS would
 *                               normally have reserved: 00/0800 ($B800),
 *                               E0/2000 ($4000), E1/2000 ($8000) -- and,
 *                               only with --reserve-bank-01, 01/0800
 *                               ($B800). That range overlaps $01/2000-9FFF,
 *                               the Super Hi-Res shadow screen; real game
 *                               code allocates that itself via GS/OS, which
 *                               fails if our boot stub already claimed it,
 *                               so it's off by default.
 *          _MMStartUp          ; Memory Manager StartUp (tool $202) --
 *                               pulls the Master User ID into A. Real game
 *                               code (via InitMemory) expects this in A on
 *                               entry, matching what GS/OS normally passes
 *                               to a launched program.
 *          LDX/LDY #0          ; zero X/Y only -- A is left holding the
 *                               Master User ID from MMStartUp
 *          JMP $2000           ; transfer to the pre-copied JSL/EXIT/FAIL
 *                               loops (see above)
 *
 *   At $2000 (copied there early, executed only once JMP $2000 above runs):
 *   JSL <start-address>        ; CALL into the preloaded benchmark code --
 *                               JSL (not JML) so a plain RTL in the
 *                               benchmark binary returns here
 *   EXIT:  WDM $01              ; success completion signal
 *          BRA EXIT             ; spin -- Lua breaks here and never needs
 *                               to resume it
 *   FAIL:  WDM $02              ; failure completion signal -- every
 *          BRA FAIL             ; toolbox call above checks the carry flag
 *                               (clear=success, set=failure, standard
 *                               convention) immediately after the call and
 *                               jumps here on failure, so a debugger can
 *                               tell a failed boot-time toolbox call apart
 *                               from a normal completion without having to
 *                               single-step to find which call failed.
 *
 * Because entry is via JSL/RTL, the benchmark binary itself needs no WDM
 * instruction at all -- it's a normal callable subroutine. The EXIT/FAIL
 * addresses are fixed by this stub's own layout, not derived from the
 * benchmark binary's listing, so scripts/mame_bench.lua no longer needs to
 * scan for them -- they're written to a JSON sidecar file (<output>.json)
 * next to the disk image for the harness to read.
 *
 * No filesystem structure is needed beyond that -- the rest of the image
 * is unused padding. This lets a normal, unmodified firmware boot flow
 * (POST, memory manager init, disk boot) land in the benchmark code with
 * no debugger register manipulation and no dependence on breaking into
 * the emulated CPU mid-boot.
 *
 * The benchmark binary itself must be preloaded into memory separately
 * (scripts/mame_bench.lua does this directly via the CPU's program space
 * before the machine starts running) since a real disk read of the full
 * payload would need a working RWTS/SmartPort reader in the boot stub --
 * unnecessary complexity when Lua can just poke the bytes in directly.
 */

const fs   = require('fs');
const path = require('path');

const DISK_SIZE = 143360; // 5.25" 140K raw image
const BOOT_BASE = 0x0800;

const USAGE = `\
Usage: make-boot-disk --start <BB/OOOO> [-o <file>]

Build a minimal bootable raw .dsk image whose boot sector jumps to the
given address after entering native mode.

Options:
  --start <BB/OOOO>   Address to JML to after boot (required)
  --banks <N>         Number of contiguous 64KB banks, starting at
                       --start's bank (offset 0), to allocate via
                       NewHandle before MMStartUp -- the benchmark
                       binary's own code/data occupies this memory, and
                       (per Technote #27) MMStartUp fails if called while
                       any of the memory the application occupies is
                       unallocated. (default: 1)
  --stack <hex>       Initial S register, set via TCS before the jump
                       (default: 0x17FF)
  --direct <hex>      Initial D (direct page) register, set via TCD before
                       the jump (default: 0x0800)
  --reserve-bank-01   Also allocate 01/0800, size $B800 (one of the 4
                       fixed ProDOS 8/GS/OS blocks from Technote #27).
                       Off by default: this range overlaps $01/2000-9FFF,
                       the Super Hi-Res shadow screen -- real game code
                       (via GS/OS) allocates that itself and expects to
                       be able to, which fails if our boot stub already
                       claimed it. Only enable this for code that does
                       NOT allocate its own shadow screen memory.
  -o, --output <file> Output path (default: boot.dsk)
  -h, --help          Show this help message and exit
`;

function parseArgs(argv) {
    const opts = { start: null, banks: '1', stack: '0x17FF', direct: '0x0800', reserveBank01: false, output: 'boot.dsk' };
    let i = 0;
    while (i < argv.length) {
        const arg = argv[i];
        switch (arg) {
            case '-h': case '--help':
                console.log(USAGE);
                process.exit(0);
                break;
            case '--start':
                i++;
                opts.start = argv[i];
                break;
            case '--banks':
                i++;
                opts.banks = argv[i];
                break;
            case '--stack':
                i++;
                opts.stack = argv[i];
                break;
            case '--direct':
                i++;
                opts.direct = argv[i];
                break;
            case '--reserve-bank-01':
                opts.reserveBank01 = true;
                break;
            case '-o': case '--output':
                i++;
                opts.output = argv[i];
                break;
            default:
                console.error(`error: unknown argument: ${arg}`);
                console.error('Run with --help for usage.');
                process.exit(1);
        }
        i++;
    }
    if (!opts.start) {
        console.error('error: --start is required');
        console.error('Run with --help for usage.');
        process.exit(1);
    }
    return opts;
}

function parseAddr(str) {
    const m = str.match(/^([0-9A-Fa-f]{2})\/([0-9A-Fa-f]{4})$/);
    if (!m) throw new Error(`bad address '${str}', expected BB/OOOO`);
    return { bank: parseInt(m[1], 16), offset: parseInt(m[2], 16) };
}

// ---------------------------------------------------------------------
// 65816 byte-sequence builder, matching the macro expansions in
// macros/Util.Macs.s / macros/Mem.Macs.s (PEA is opcode $F4, operand
// little-endian; JSL is $22, operand little-endian + bank byte).
//
// Every toolbox call goes through callTool(), which checks the carry
// flag (the standard toolbox success/failure convention: clear=success,
// set=failure) immediately after the call and jumps to a shared FAIL
// spin loop on failure. The FAIL address isn't known until the whole
// stub (including its own EXIT/FAIL loops) is built, so callTool emits
// a placeholder JMP operand and records its position for patching once
// the real address is known.
// ---------------------------------------------------------------------
function makeBuilder() {
    return { bytes: [], failCheckPositions: [] };
}

function push(b, ...vals) {
    b.bytes.push(...vals);
}

function peaImm16(b, value) {
    push(b, 0xF4, value & 0xFF, (value >> 8) & 0xFF);
}

// PushLong #value -- matches the "PushLong" macro: pushes the bank byte
// (zero-extended to a word) first, then the low 16 bits.
function pushLongImm(b, value) {
    const bankByte = (value >>> 16) & 0xFF;
    const lo16 = value & 0xFFFF;
    peaImm16(b, bankByte);
    peaImm16(b, lo16);
}

function ldxImm16(b, value) {
    push(b, 0xA2, value & 0xFF, (value >> 8) & 0xFF);
}

function pushWordData(b, value) {
    push(b, value & 0xFF, (value >> 8) & 0xFF);
}

// LDX #toolNum ; JSL $E10000 ; BCC +3 ; JMP FAIL (placeholder, patched
// once FAIL's real address is known -- see patchFailJumps()).
function callTool(b, toolNum) {
    ldxImm16(b, toolNum);
    push(b, 0x22, 0x00, 0x00, 0xE1); // JSL $E10000
    push(b, 0x90, 0x03, 0x4C);       // BCC +3 ; JMP <placeholder>
    b.failCheckPositions.push(b.bytes.length);
    push(b, 0x00, 0x00);             // placeholder operand
}

function patchFailJumps(b, failAddr) {
    for (const pos of b.failCheckPositions) {
        b.bytes[pos] = failAddr & 0xFF;
        b.bytes[pos + 1] = (failAddr >> 8) & 0xFF;
    }
}

// Direct-page offset (D=$0800, so absolute $08FE) used to stash the
// temporary bootstrap ID from GetNewID across the NewHandle calls -- NOT
// a register, since a JSL to a system routine gives no guarantee any
// register survives the call.
const USER_ID_DP_OFFSET = 0xFE;

// A shared _NewHandle (Tool $902) subroutine, since 5 near-identical
// inline call sequences made the boot stub too long (it must fit in one
// 256-byte disk sector). The caller points X at a 14-byte parameter
// block (see emitNewHandleParamBlock) and JSRs here; the subroutine
// pushes each word of the block via indexed LDA/PHA, PEIs the userID
// from direct page in between (saving every call site from having to
// duplicate it), makes the call, discards the result Handle, and
// returns. Emits its own carry check (shared across all 5 calls, rather
// than one per call site as before).
function emitNewHandleSub(b) {
    const subAddr = BOOT_BASE + b.bytes.length;
    for (const off of [0, 2, 4, 6]) {
        push(b, 0xBD, off & 0xFF, (off >> 8) & 0xFF); // LDA offset,X
        push(b, 0x48);                                 // PHA
    }
    push(b, 0xD4, USER_ID_DP_OFFSET); // PEI $FE (direct page) -- userID
    for (const off of [8, 10, 12]) {
        push(b, 0xBD, off & 0xFF, (off >> 8) & 0xFF);
        push(b, 0x48);
    }
    callTool(b, 0x0902);
    push(b, 0x68, 0x68); // PLA, PLA -- discard the result Handle
    push(b, 0x60);        // RTS
    return subAddr;
}

// Fixed-location attribute word (see src/core/Memory.s InitMemory).
// Bit 4 (0x0010) is attrNoCross, which forbids the block from crossing a
// bank boundary -- fine for single-bank allocations, but must be cleared
// for the multi-bank code-region allocation below (error $0201, "unable
// to allocate block", otherwise).
const ATTR_FIXED_LOCATION = 0xC017;
const ATTR_FIXED_LOCATION_CROSS_BANK = ATTR_FIXED_LOCATION & ~0x0010;

// 14-byte data block (7 words) read by emitNewHandleSub via X-indexed
// LDA, in ascending-offset order, matching the real PushLong convention
// (bank-word pushed BEFORE low-word -- confirmed by how PullLong
// reconstructs a long: first pull -> low address, second pull -> low+2,
// and pulls happen in reverse push order): resultSpace(bank,lo)=always
// 0, size(bank,lo), attributes, location(bank,lo). Not instructions --
// must only ever be reached via LDX #<this address>, never fallen into.
function emitNewHandleParamBlock(b, size, location, attrs) {
    const blockAddr = BOOT_BASE + b.bytes.length;
    pushWordData(b, 0);                        // resultSpace bank
    pushWordData(b, 0);                        // resultSpace low
    pushWordData(b, (size >>> 16) & 0xFF);      // size bank
    pushWordData(b, size & 0xFFFF);             // size low
    pushWordData(b, attrs);                     // attributes
    pushWordData(b, (location >>> 16) & 0xFF);  // location bank
    pushWordData(b, location & 0xFFFF);         // location low
    return blockAddr;
}

function callNewHandleSub(b, subAddr, blockAddr) {
    ldxImm16(b, blockAddr);
    push(b, 0x20, subAddr & 0xFF, (subAddr >> 8) & 0xFF); // JSR subAddr
}

// Safe relocation target for the JSL + EXIT/FAIL spin loops -- $0800 is
// also the application's direct page (D register), so once the
// benchmark code starts running and touches its own direct-page
// variables, it can physically overwrite the boot stub sitting at
// $0800-$08FF, corrupting the very loops the harness breakpoints on.
// $2000 is unused this early and corresponds to the ProDOS SYSTEM load
// address convention.
const SAFE_BASE = 0x2000;

// Builds the JSL + EXIT/FAIL bytes with addresses computed relative to
// SAFE_BASE (i.e. as they'll be once copied there), independent of
// wherever they're physically staged as data in the $0800 boot sector.
function buildTail(addr) {
    const t = { bytes: [] };
    const tpush = (...vals) => t.bytes.push(...vals);

    t.jslAddr = SAFE_BASE + t.bytes.length;
    tpush(0x22, addr.offset & 0xFF, (addr.offset >> 8) & 0xFF, addr.bank); // JSL <start>

    t.exitAddr = SAFE_BASE + t.bytes.length;
    tpush(0x42, 0x01); // WDM $01
    {
        const braInstrAddr = SAFE_BASE + t.bytes.length;
        tpush(0x80, (t.exitAddr - (braInstrAddr + 2)) & 0xFF); // BRA EXIT
    }

    t.failAddr = SAFE_BASE + t.bytes.length;
    tpush(0x42, 0x02); // WDM $02
    {
        const braInstrAddr = SAFE_BASE + t.bytes.length;
        tpush(0x80, (t.failAddr - (braInstrAddr + 2)) & 0xFF); // BRA FAIL
    }

    return t;
}

function main() {
    const opts = parseArgs(process.argv.slice(2));
    const addr   = parseAddr(opts.start);
    const banks  = parseInt(opts.banks, 10);
    const stack  = parseInt(opts.stack, 16);
    const direct = parseInt(opts.direct, 16);

    const image = Buffer.alloc(DISK_SIZE, 0x00);
    const b = makeBuilder();

    push(b,
        0x01,                       // sector count -- required by ROM03 to accept the sector

        // Turn off the Disk II drive/stepper motor now that the boot
        // sector has been read. X is already set to the slot offset by
        // the slot firmware that jumped here (the classic Apple II
        // generic slot-relative soft-switch convention: base $C088 +
        // (slot * $10)) -- still in emulation mode (8-bit A) at this point.
        0xBD, 0x88, 0xC0,           // LDA $C088,X -- MOTOROFF for this slot

        0x18,                       // CLC
        0xFB,                       // XCE -- enter native mode (E=0)
        0xC2, 0x30,                 // REP #$30 -- 16-bit A/X/Y
        0xA9, stack & 0xFF, (stack >> 8) & 0xFF,   // LDA #stack
        0x1B,                       // TCS
        0xA9, direct & 0xFF, (direct >> 8) & 0xFF, // LDA #direct
        0x5B,                       // TCD
    );

    // Jump over the NewHandle subroutine and its data blocks -- neither
    // is executable code that should ever be fallen into. JMP (not BRA)
    // since the combined size can exceed BRA's +-127 byte range.
    push(b, 0x4C, 0x00, 0x00); // JMP <patched below>
    const jmpOverSubPos = b.bytes.length - 2;

    const newHandleSubAddr = emitNewHandleSub(b);

    const osBlocks = [
        emitNewHandleParamBlock(b, 0xB800, 0x000800, ATTR_FIXED_LOCATION), // 00/0800, $B800
        // 01/0800, $B800 -- SKIPPED by default: overlaps $01/2000-9FFF,
        // the Super Hi-Res shadow screen, which real game code allocates
        // itself via GS/OS. Only reserved if --reserve-bank-01 is passed
        // (for code that does NOT allocate its own shadow screen memory).
        ...(opts.reserveBank01 ? [emitNewHandleParamBlock(b, 0xB800, 0x010800, ATTR_FIXED_LOCATION)] : []),
        emitNewHandleParamBlock(b, 0x4000, 0xE02000, ATTR_FIXED_LOCATION), // E0/2000, $4000
        emitNewHandleParamBlock(b, 0x8000, 0xE12000, ATTR_FIXED_LOCATION), // E1/2000, $8000
    ];
    // The benchmark binary's own code/data occupies memory too, and
    // MMStartUp fails the same way if any of THAT is unallocated -- not
    // just the fixed ProDOS 8/GS/OS blocks above. Claim one contiguous
    // chunk of 64KB banks starting at --start's bank, covering however
    // many banks the benchmark's segments span (assumes segments are
    // packed one-per-bank starting there with no gaps -- true for the
    // fixed-address builds this harness targets). This can span multiple
    // banks, so attrNoCross must be cleared (unlike the single-bank OS
    // blocks above).
    const codeBlock = banks > 0
        ? emitNewHandleParamBlock(b, banks * 0x10000, addr.bank << 16, ATTR_FIXED_LOCATION_CROSS_BANK)
        : null;

    // Stage the JSL + EXIT/FAIL loops as data here (still in the $0800
    // page) -- NOT executable, must be skipped over by the JMP patched
    // below, just like the subroutine+param-blocks above.
    const tail = buildTail(addr);
    const tailSourceAddr = BOOT_BASE + b.bytes.length;
    push(b, ...tail.bytes);
    if (tail.bytes.length % 2 !== 0) push(b, 0xEA); // pad to even length (never executed) for the word-copy loop below
    const copyLen = tail.bytes.length + (tail.bytes.length % 2 !== 0 ? 1 : 0);

    // The JMP above lands HERE, right at the copy-loop code -- which DOES
    // execute as normal flow (unlike the subroutine/data/tail bytes it
    // skipped over). It copies the staged tail to SAFE_BASE now, BEFORE
    // any toolbox call that could fail -- a failing TLBootInit/TLStartUp/
    // etc below jumps to the relocated FAIL loop via patchFailJumps(), so
    // it must already be in place by the time those calls happen, not
    // just before the final JSL.
    const afterSubData = BOOT_BASE + b.bytes.length;
    b.bytes[jmpOverSubPos] = afterSubData & 0xFF;
    b.bytes[jmpOverSubPos + 1] = (afterSubData >> 8) & 0xFF;

    push(b, 0xA2, 0x00, 0x00); // LDX #0
    const copyLoopAddr = BOOT_BASE + b.bytes.length;
    push(b, 0xBD, tailSourceAddr & 0xFF, (tailSourceAddr >> 8) & 0xFF); // LDA tailSourceAddr,X
    push(b, 0x9D, SAFE_BASE & 0xFF, (SAFE_BASE >> 8) & 0xFF);           // STA SAFE_BASE,X
    push(b, 0xE8, 0xE8);        // INX, INX (word-at-a-time copy)
    push(b, 0xE0, copyLen & 0xFF, (copyLen >> 8) & 0xFF); // CPX #copyLen
    push(b, 0xD0, (copyLoopAddr - (BOOT_BASE + b.bytes.length + 2)) & 0xFF); // BNE copyLoop

    callTool(b, 0x0101); // _TLBootInit
    callTool(b, 0x0201); // _TLStartUp

    // GetNewID: temporary bootstrap ID for the NewHandle calls below
    // (Technote #27 -- MMStartUp fails if called from unallocated memory).
    // Takes an idTag parameter: top 4 bits = type ($1 = Application), low
    // 4 bits = auxId (freely chosen) -- $1100 here. Omitting this was the
    // bug found by interactively tracing the JSL $E10000 call.
    peaImm16(b, 0x0000);        // space for result (word)
    peaImm16(b, 0x1100);        // idTag: type=Application($1), auxId=$1
    callTool(b, 0x2003);        // _GetNewID
    push(b, 0x68);               // PLA -- A = temporary bootstrap ID
    push(b, 0x85, USER_ID_DP_OFFSET); // STA $FE (direct page, abs $08FE)

    for (const blockAddr of osBlocks) {
        callNewHandleSub(b, newHandleSubAddr, blockAddr);
    }
    if (codeBlock !== null) {
        callNewHandleSub(b, newHandleSubAddr, codeBlock);
    }

    // _MMStartUp: reserve a word on the stack for the result, make the
    // call, pull the Master User ID into A. Real game code (via
    // InitMemory) expects this in A on entry.
    peaImm16(b, 0x0000);
    callTool(b, 0x0202);
    push(b, 0x68); // PLA -- A = Master User ID

    push(b, 0xA2, 0x00, 0x00); // LDX #0
    push(b, 0xA0, 0x00, 0x00); // LDY #0

    // Address of the JSL instruction itself. Firmware's own POST/RAM-size
    // self-test clobbers RAM banks (including the benchmark binary's load
    // bank) if it's preloaded before boot -- so the harness instead
    // breaks HERE, injects the binary once POST has already run, then
    // resumes into the still-relocated JSL at SAFE_BASE, staged and
    // copied there earlier (see buildTail()/the copy loop above) so it
    // survives the benchmark code's own direct-page (D=$0800) writes,
    // which would otherwise overwrite this code sitting at $0800-$08FF.
    push(b, 0x4C, SAFE_BASE & 0xFF, (SAFE_BASE >> 8) & 0xFF); // JMP SAFE_BASE

    patchFailJumps(b, tail.failAddr);

    // The boot sector's sector-count byte is $01 (a single 256-byte
    // sector) and the same content is written redundantly into every
    // sector slot of track 0 (see below) -- both of which assume the
    // whole stub fits in one sector. Past that, the per-sector copies
    // would silently corrupt each other's overflow.
    if (b.bytes.length > 256) {
        throw new Error(`boot stub is ${b.bytes.length} bytes, exceeding the 256-byte single-sector limit`);
    }

    const boot = Buffer.from(b.bytes);

    // Write the boot sector into every one of the 16 sector-sized slots of
    // track 0 (the first 4096 bytes), not just offset 0. A raw physical
    // boot-sector read is not guaranteed to land on file offset 0 unless
    // the image's sector ordering (DOS-order vs ProDOS-order skew) matches
    // what the ROM's physical read expects -- writing redundantly avoids
    // having to know or guess that mapping.
    const SECTOR_SIZE = 256;
    const SECTORS_PER_TRACK = 16;
    for (let i = 0; i < SECTORS_PER_TRACK; i++) {
        boot.copy(image, i * SECTOR_SIZE);
    }

    fs.writeFileSync(opts.output, image);

    const exitAddr = `00/${tail.exitAddr.toString(16).padStart(4, '0').toUpperCase()}`;
    const failAddr = `00/${tail.failAddr.toString(16).padStart(4, '0').toUpperCase()}`;
    const jslAddrStr = `00/${tail.jslAddr.toString(16).padStart(4, '0').toUpperCase()}`;
    const sidecarPath = `${opts.output}.json`;
    fs.writeFileSync(sidecarPath, JSON.stringify({ exitAddr, failAddr, jslAddr: jslAddrStr }, null, 2));

    console.log(`Wrote ${DISK_SIZE}-byte boot disk (JSL @ ${jslAddrStr} to ${opts.start}, exit @ ${exitAddr}, fail @ ${failAddr}) -> ${opts.output}`);
    console.log(`Wrote sidecar -> ${sidecarPath}`);
}

main();
