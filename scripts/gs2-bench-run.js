#!/usr/bin/env node
'use strict';

/**
 * gs2-bench-run -- Run one Zelda BENCH_MODE trial in GSSquared, through the gs2-mcp server (the same
 * one Claude Code uses; it is driven here over its stdio MCP transport).  See docs/BENCH_ZELDA.md.
 *
 *   node scripts/gs2-bench-run.js --info <bench-zelda --out json> --config <.gs2 file> [--label name]
 *                                 [--rooms] [--dump dir] [--shots a,b,c] [--count sym,sym] [--watch a,b]
 *
 *   --rooms          log the room changes along the route
 *   --dump dir       save the sprite compile bank, the tiledata bank and the dispatch table at BenchDone
 *   --stats          read the sprite cache counters at BenchDone (a build with bench-zelda.js --stats)
 *   --gridstats      read the grid renderer's counters (the 'GRIDSTAT' block; a GRID_STATS build)
 *   --shots a,b,c    hash the SHR screen at the start of those frames (ascending), to check that two builds
 *                    draw the same pictures
 *   --count a,b      count how often execution reaches these symbols (names exported by bench-zelda.js)
 *   --watch a,b      for every frame from a to b, list the SHR lines that changed since the previous frame, with the
 *                    game mode, the sprite 0 split flag (s0=1: a scroll transition, drawn by Zelda's _RenderScreen) and
 *                    Link's direction: shows which part of the screen each kind of frame writes to
 *   --delay ms       with --watch: stay on each frame for this long (and print it on stderr), to look at the screen
 *   (the cycle count of a run with --rooms, --shots, --count or --watch is not the result: the stops cost time)
 *
 * The .gs2 config must boot a GS/OS image that has the build installed as SYSTEM/Start (see
 * scripts/bench-zelda.js) and should run at maximum speed (speed = "ludicrous").
 *
 * The run: wait for BenchStart, note the CPU cycle count, run to BenchDone, note it again, and read
 * the game state.  Prints one JSON line.
 */

const fs = require('fs');
const { spawn } = require('child_process');

const GS2_MCP = process.env.GS2_MCP || 'C:/Programs/IIgsXDev/bin/gs2-mcp-windows-amd64-v0.1.4.exe';
const GS2_BIN = process.env.GS2_BIN || 'C:/checkout/GSSquared/gssquared-1.0.1954-win64/GSSquared.exe';

class Gs2 {
    constructor() {
        this.p = spawn(GS2_MCP, [], { env: { ...process.env, GS2_BIN } });
        this.buf = '';
        this.nextId = 1;
        this.pending = new Map();
        this.p.stdout.on('data', d => {
            this.buf += d;
            let i;
            while ((i = this.buf.indexOf('\n')) >= 0) {
                const line = this.buf.slice(0, i);
                this.buf = this.buf.slice(i + 1);
                if (!line.trim()) continue;
                const msg = JSON.parse(line);
                if (msg.id !== undefined && this.pending.has(msg.id)) {
                    this.pending.get(msg.id)(msg);
                    this.pending.delete(msg.id);
                }
            }
        });
        this.p.stderr.on('data', () => {});
    }
    rpc(method, params) {
        const id = this.nextId++;
        return new Promise(resolve => {
            this.pending.set(id, resolve);
            this.p.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
        });
    }
    async init() {
        await this.rpc('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'gs2-bench-run', version: '1' } });
        this.p.stdin.write(JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized' }) + '\n');
    }
    async call(name, args = {}) {
        const msg = await this.rpc('tools/call', { name, arguments: args });
        if (msg.error) throw new Error(`${name}: ${JSON.stringify(msg.error)}`);
        const r = msg.result;
        if (r.isError) throw new Error(`${name}: ${JSON.stringify(r.content)}`);
        if (r.structuredContent) return r.structuredContent;
        const text = r.content && r.content[0] && r.content[0].text;
        try { return JSON.parse(text); } catch (e) { return { text }; }
    }
    async read(address, length) {
        const r = await this.call('read_mem', { address, length });
        return Buffer.from(r.hex, 'hex');
    }
    close() { try { this.p.kill(); } catch (e) { /* gone */ } }
}

// Wait for the next stop, for as long as it takes (the server only waits timeout_s per call)
async function waitStopped(gs2, seconds) {
    const end = Date.now() + seconds * 1000;
    for (;;) {
        let r;
        try { r = await gs2.call('wait_stopped', { timeout_s: 30 }); } catch (e) { r = null; }
        if (r && r.reason !== undefined) return r;
        if (Date.now() > end) throw new Error('timed out waiting for a breakpoint');
    }
}

function parseSymbolAddr(sym) {                       // "00/EEB6" -> offset
    return parseInt(sym.address.split('/')[1], 16);
}

async function main() {
    const argv = process.argv.slice(2);
    const o = { info: null, config: null, label: 'run', timeout: 1500, rooms: false, stats: false, gridstats: false, dump: null, shots: [], count: [], watch: null, delay: 0 };
    for (let i = 0; i < argv.length; i++) {
        if (argv[i] === '--info') o.info = argv[++i];
        else if (argv[i] === '--config') o.config = argv[++i];
        else if (argv[i] === '--label') o.label = argv[++i];
        else if (argv[i] === '--timeout') o.timeout = parseInt(argv[++i], 10);
        else if (argv[i] === '--rooms') o.rooms = true;
        else if (argv[i] === '--dump') o.dump = argv[++i];
        else if (argv[i] === '--stats') o.stats = true;
        else if (argv[i] === '--gridstats') o.gridstats = true;
        else if (argv[i] === '--delay') o.delay = parseInt(argv[++i], 10);
        else if (argv[i] === '--watch') o.watch = argv[++i].split(',').map(x => parseInt(x, 10));
        else if (argv[i] === '--count') o.count = argv[++i].split(',');
        else if (argv[i] === '--shots') o.shots = argv[++i].split(',').map(x => parseInt(x, 10));
    }
    if (!o.info || !o.config) throw new Error('--info and --config are required');
    const info = JSON.parse(fs.readFileSync(o.info, 'utf8'));
    const sym = info.symbols;
    const startOff = parseSymbolAddr(sym.BenchStart);
    const doneOff = parseSymbolAddr(sym.BenchDone);

    const gs2 = new Gs2();
    try {
        await gs2.init();
        await gs2.call('launch', { platform: 'IIgs', extra_args: [o.config] });

        // BenchStart.  GS/OS runs other code at the same offset in banks below $80 on the way, so a stop only
        // counts when it is the application: D = $0800 and a JSR to NES_ColdBoot is next
        await gs2.call('bp_set', { kind: 'EXEC', address: startOff, addr_mask: 0x80FFFF });
        let stop;
        for (;;) {
            stop = await waitStopped(gs2, 600);
            const t = stop.trace;
            if (t.pb === t.db && t.d === 0x800 && t.opcode === 0x20) break;
            await gs2.call('continue_exec');
        }
        const bank = stop.trace.pb;
        const cycleStart = stop.trace.cycle;

        // --shots: stop at the start of the given frames (BenchInputIndex written) and hash the SHR screen
        // ($E1/2000-9FFF: pixels, SCBs and palettes), to check that two builds draw the same pictures.  The
        // stops cost time, so the cycle count of such a run is not the result
        const shots = {};
        if (o.shots.length) {
            const idxAddr = (bank << 16) | parseSymbolAddr(sym.BenchInputIndex);
            let cur = 0;
            for (const n of o.shots) {
                await gs2.call('bp_clear_all');
                await gs2.call('bp_set', { kind: 'DATA', address: idxAddr, access: 'W', length: 2, ignore_count: n - cur - 1 });
                await gs2.call('continue_exec');
                await waitStopped(gs2, o.timeout);
                cur = (await gs2.read(idxAddr, 2)).readUInt16LE(0);
                shots[cur] = require('crypto').createHash('md5').update(await gs2.read(0xE12000, 0x8000)).digest('hex');
            }
        }

        // --watch a,b: for every frame from a to b, read the SHR pixels and report which screen lines changed since
        // the previous frame (ranges), with the game mode, the sprite 0 split flag and Link's direction
        const watched = [];
        if (o.watch) {
            const [wa, wb] = o.watch;
            const idxAddr = (bank << 16) | parseSymbolAddr(sym.BenchInputIndex);
            const dp = (await gs2.read((bank << 16) | parseSymbolAddr(sym.DP_NES), 2)).readUInt16LE(0);
            await gs2.call('bp_clear_all');
            await gs2.call('bp_set', { kind: 'DATA', address: idxAddr, access: 'W', length: 2, ignore_count: wa - 1 });
            await gs2.call('continue_exec');
            let prev = null;
            for (;;) {
                await waitStopped(gs2, o.timeout);
                const cur = (await gs2.read(idxAddr, 2)).readUInt16LE(0);
                if (cur > wb) break;
                const scr = await gs2.read(0xE12000, 200 * 160);
                const zp = await gs2.read(dp, 256);
                const changed = [];
                if (prev) {
                    let start = -1;
                    for (let l = 0; l <= 200; l++) {
                        const diff = l < 200 && scr.compare(prev, l * 160, l * 160 + 160, l * 160, l * 160 + 160) !== 0;
                        if (diff && start < 0) start = l;
                        if (!diff && start >= 0) { changed.push(start === l - 1 ? `${start}` : `${start}-${l - 1}`); start = -1; }
                    }
                }
                watched.push(`${cur} m${zp[0x12].toString(16)}.${zp[0x13]} s0=${zp[0xE3]} dir=${zp[0x98].toString(16)} room=${zp[0xEB].toString(16)} y=${zp[0x84]} lines: ${changed.join(',') || '-'}`);
                prev = scr;
                if (o.delay) {                                   // stay on this frame, so the screen can be looked at
                    console.error(watched[watched.length - 1]);
                    await new Promise(r => setTimeout(r, o.delay));
                }
                await gs2.call('continue_exec');
            }
            await gs2.call('bp_clear_all');
        }

        // BenchDone
        await gs2.call('bp_clear_all');
        await gs2.call('bp_set', { kind: 'EXEC', address: (bank << 16) | doneOff });
        // --rooms: also stop whenever the game changes room (RoomId, $EB of the NES zero page), to see where
        // the route goes.  The stops cost time, so the cycle count of such a run is not the result
        let dpAddr = 0;
        if (o.rooms) {
            dpAddr = (await gs2.read((bank << 16) | parseSymbolAddr(sym.DP_NES), 2)).readUInt16LE(0);
            await gs2.call('bp_set', { kind: 'DATA', address: dpAddr + 0xEB, access: 'W', length: 1 });
        }
        const visited = [];
        // --count a,b: also count how often execution reaches these symbols (a run with stops: not a timing)
        const counts = {}, countAt = {};
        for (const name of o.count) {
            if (!sym[name]) throw new Error(`no symbol ${name}`);
            const addr = (bank << 16) | parseSymbolAddr(sym[name]);
            counts[name] = 0; countAt[addr] = name;
            await gs2.call('bp_set', { kind: 'EXEC', address: addr });
        }
        await gs2.call('continue_exec');
        let done;
        for (;;) {
            done = await waitStopped(gs2, o.timeout);
            const at = countAt[(done.trace.pb << 16) | done.trace.pc];
            if (at !== undefined) { counts[at]++; await gs2.call('continue_exec'); continue; }
            if (done.kind !== 'DATA') break;
            const idx = (await gs2.read((bank << 16) | parseSymbolAddr(sym.BenchInputIndex), 2)).readUInt16LE(0);
            const room = (await gs2.read(dpAddr + 0xEB, 1))[0];
            visited.push(`${idx}:${room.toString(16)}`);
            await gs2.call('continue_exec');
        }
        const cycleEnd = done.trace.cycle;

        const result = { label: o.label, bank, cycleStart, cycleEnd, cycles: cycleEnd - cycleStart, options: info.options, size: info.size };

        if (o.rooms) result.rooms = visited.join(' ');
        if (o.count.length) result.counts = counts;
        if (o.watch) result.watched = watched;
        if (o.shots.length) result.shots = shots;

        // --dump: the memory banks for offline analysis.  The sprite bank is the operand of the patched JML at
        // csd; the tiledata bank is the high byte of CMPL_BANK (direct page offset 176, D = $0800)
        if (o.dump) {
            fs.mkdirSync(o.dump, { recursive: true });
            const ppuBank = (await gs2.read((bank << 16) | (parseSymbolAddr(sym.SprCacheInit) + 6), 1))[0];
            const spriteBank = (await gs2.read((bank << 16) | (parseSymbolAddr(sym.csd) + 3), 1))[0];
            const tileBank = (await gs2.read(0x800 + 176 + 1, 1))[0];
            fs.writeFileSync(`${o.dump}/sprite.bin`, await gs2.read(spriteBank << 16, 65536));
            fs.writeFileSync(`${o.dump}/tiledata.bin`, await gs2.read(tileBank << 16, 65536));
            fs.writeFileSync(`${o.dump}/comp_tbl.bin`, await gs2.read((ppuBank << 16) | 0x9000, 4096));
            fs.writeFileSync(`${o.dump}/draw_rtn2.txt`, sym.draw_rtn2.address);
            result.dump = { spriteBank, tileBank, ppuBank };
        }

        // --stats: the sprite cache counters (SPR_STATS in Defs.s), in the PPU_MEM bank: the bank byte of the
        // first long store in SprCacheInit (stal PPU_MEM+SPR_COMP_TBL,x)
        if (o.stats) {
            const code = await gs2.read((bank << 16) | parseSymbolAddr(sym.SprCacheInit), 16);
            const at = code.indexOf(0x9F);
            if (at < 0) throw new Error('no stal in SprCacheInit');
            const ppuBank = code[at + 3];
            const c = await gs2.read((ppuBank << 16) | 0x2910, 24);
            const n = i => c.readUInt32LE(i * 4);
            const st = { hits: n(0), misses: n(1), shiftRequests: n(2), compiles: n(3), shiftCompiles: n(4), evictions: n(5) };
            const lookups = st.hits + st.misses;
            st.hitRate = +(100 * st.hits / lookups).toFixed(3);
            st.exactRate = +(100 * (st.hits - st.shiftRequests) / lookups).toFixed(3);
            result.stats = st;
        }

        // --gridstats: the 32-bit counters after the 'GRIDSTAT' signature (ppu_grid.s), in the ENGINE segment's
        // bank: the bank byte of the first jsl in NES_RenderFrame (jsl RenderLatch)
        if (o.gridstats) {
            const rf = await gs2.read((bank << 16) | parseSymbolAddr(sym.NES_RenderFrame), 32);
            const jsl = rf.indexOf(0x22);
            if (jsl < 0) throw new Error('no jsl in NES_RenderFrame');
            const m = await gs2.read(rf[jsl + 3] << 16, 65536);
            const at = m.indexOf(Buffer.from('GRIDSTAT'));
            if (at < 0) throw new Error('no GRIDSTAT block');
            const names = ['dirtyFrames', 'fullFrames', 'erased', 'exposed', 'sprTiles', 'bgCells', 'fbBgOff', 'fbAttr',
                           'fbMany', 'fbAlign', 'fbScroll'];
            const g = {};
            names.forEach((n, i) => { g[n] = m.readUInt32LE(at + 8 + i * 4); });
            const rest = at + 8 + names.length * 4;
            ['bgFrames', 'metatiles', 'mtCells', 'attrFrames', 'eraseWords', 'exposeWords']
                .forEach((n, i) => { g[n] = m.readUInt32LE(rest + i * 4); });
            result.grid = g;
        }

        // The game state: the NES zero page is on the direct page DP_NES in bank 0
        if (sym.DP_NES) {
            const dp = (await gs2.read((bank << 16) | parseSymbolAddr(sym.DP_NES), 2)).readUInt16LE(0);
            const zp = await gs2.read(dp, 256);
            result.game = { mode: zp[0x12], submode: zp[0x13], level: zp[0x10], room: zp[0xEB], frame: zp[0x15],
                            linkX: zp[0x70], linkY: zp[0x84] };
        }
        console.log(JSON.stringify(result));
    } finally {
        try { await gs2.call('quit'); } catch (e) { /* already gone */ }
        gs2.close();
    }
}

main().catch(e => { console.error(e.stack || e.message); process.exit(1); });
