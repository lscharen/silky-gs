-- mame_bench.lua
--
-- MAME autoboot script for the silky-gs benchmark harness.
--
-- Strategy: rather than break into the CPU mid-boot and try to force a
-- PC/bank redirect via debugger register writes (unreliable -- see below),
-- let the firmware boot completely normally from a minimal custom floppy
-- image (scripts/make-boot-disk.js). The boot stub does all native-mode /
-- register setup itself (real 65816 instructions), then JSLs into the
-- entry segment's start address. Since entry is via JSL, the benchmark
-- code is a normal callable subroutine ending in RTL; it needs no WDM
-- instruction at all. Completion is signaled by the boot stub's own fixed
-- WDM/BRA spin loop after the RTL returns -- a single, deterministic
-- address independent of the benchmark code's contents.
--
-- A benchmark build may consist of MULTIPLE fixed-address segments (one
-- Merlin32 "Bench.s" link file producing several same-named raw binaries,
-- each with its own ORG -- see e.g. src/games/smb/Bench.s, which links a
-- main-code segment plus PPU/tile-data/ROM segments each approaching a
-- full 64KB bank). All segments are loaded into memory; only the FIRST
-- one (the entry segment) is JSLed into.
--
-- None of the segments are preloaded before the machine starts running.
-- Firmware's own POST/RAM-sizing self-test clobbers RAM banks (including
-- wherever a segment would be loaded) if written before boot -- so Lua
-- instead breaks at the boot stub's own JSL instruction (after POST has
-- already run, before the jump executes), injects every segment there,
-- and resumes.
--
-- Lua's jobs: arm a breakpoint at the JSL instruction (inject all
-- segments when hit), arm a breakpoint at the fixed exit address (report
-- + exit when hit), and dispatch between the two via consolelog polling.
--
-- Launch:
--   mame apple2gs -debug -debugger none -window \
--     -flop1 boot.po -autoboot_script scripts/mame_bench.lua
--
-- Configuration is via environment variables so this script is not edited
-- per game:
--   BENCH_SEGMENTS path to a JSON array of {name, addr, file, size}
--                  describing every segment to load, in entry order
--                  (required) -- see scripts/run-bench.js
--   BENCH_JSL      address of the boot stub's JSL instruction "BB/OOOO",
--                  from the sidecar JSON written by scripts/make-boot-disk.js
--                  (required)
--   BENCH_EXIT     exit breakpoint address "BB/OOOO", from the same
--                  sidecar (required)
--   BENCH_RESULT   output file for the benchmark result (default: bench_result.txt)
--
-- CONFIRMED against this MAME build (0.288), see scripts/mame_probe.lua
-- history for the full trail:
--   - "-debug" alone fully blocks the emulation thread on halt in a way
--     that's invisible to every Lua notifier (frame/pause/periodic) --
--     unusable for detecting breakpoint hits.
--   - "-debugger none" keeps the emulation thread running; breakpoint
--     hits are detectable by polling manager.machine.debugger.consolelog
--     (an indexable log-line table) for a "Stopped at ..." line via
--     emu.register_periodic. This is the technique used by
--     https://github.com/a2stuff/a2d/blob/main/tests/infrastructure/debugger.lua
--   - cpu.state["PC"] writes reliably stick ONLY when they stay within
--     the current bank (offset-only). Writing cpu.state["PB"] (or PC
--     with an implied bank change) does NOT reliably take effect.
--   - $00/C600 is genuine ROM (ROM03 firmware) and cannot be patched.
--     ROM03 also validates the boot sector (sector-count byte) before
--     jumping to it -- see scripts/make-boot-disk.js.
--   - Presetting cpu.state["S"/"D"/"A"/"X"/"Y"] via Lua BEFORE the machine
--     ever runs derails the boot into ROM exception-handler wandering --
--     it conflicts with firmware's own mode/state assumptions. All
--     register/mode setup is done by real 65816 instructions in the boot
--     stub instead.
--   - Preloading segment data via space:write_u8 BEFORE the machine ever
--     runs gets clobbered by firmware's own POST/RAM-sizing self-test --
--     confirmed by inspecting memory interactively at the JSL: bytes were
--     garbage, not the preloaded binary. Fixed by deferring the preload
--     to a breakpoint at the JSL instruction itself.
--   - There is no Lua API for reading a true per-CPU cycle counter
--     (cpu.debug.evaluate/.symbols, cpu.execute, cpu.state["totalcycles"]
--     are all nil in this build). But the debugger CONSOLE recognizes
--     "totalcycles" as a valid expression -- `dbg:command("print
--     totalcycles")` writes its value (in hex, no "0x" prefix) as the next
--     consolelog line, which can be parsed back out. Verified exact: a
--     JSL(8)+NOP(2)+NOP(2)+RTL(6) sequence measured a totalcycles delta of
--     exactly 18. This is the real per-instruction cycle count, unlike an
--     elapsed-wall-time * clock-rate estimate.
--   - space:write_u8 in a byte-by-byte loop was measured (via a standalone
--     probe) at ~65536 writes / 0.09 sec -- fast enough that even several
--     near-64KB segments (a few hundred KB total) load in well under a
--     second, negligible next to MAME's multi-second boot/POST time. No
--     bulk-write API (space:write_block) exists in this build, but none
--     is needed at this size.

local function getenv(name, default)
    local v = os.getenv(name)
    if v == nil or v == "" then return default end
    return v
end

local function parseAddr(str)
    local bank, off = str:match("^(%x%x)/(%x%x%x%x)$")
    if not bank then
        error("bad address '" .. tostring(str) .. "', expected BB/OOOO")
    end
    local b = tonumber(bank, 16)
    local o = tonumber(off, 16)
    return { bank = b, offset = o, flat = (b << 16) | o }
end

local SEGMENTS_FILE = getenv("BENCH_SEGMENTS", nil)
local JSL_ADDR_S     = getenv("BENCH_JSL", nil)
local EXIT_ADDR_S    = getenv("BENCH_EXIT", nil)
local FAIL_ADDR_S    = getenv("BENCH_FAIL", nil)
local RESULT_FILE    = getenv("BENCH_RESULT", "bench_result.txt")

local CPU_TAG = ":maincpu"

if not SEGMENTS_FILE or not JSL_ADDR_S or not EXIT_ADDR_S or not FAIL_ADDR_S then
    error("BENCH_SEGMENTS, BENCH_JSL, BENCH_EXIT, and BENCH_FAIL environment variables are required")
end

local JSL_ADDR  = parseAddr(JSL_ADDR_S)
local EXIT_ADDR = parseAddr(EXIT_ADDR_S)
local FAIL_ADDR = parseAddr(FAIL_ADDR_S)

local machine = manager.machine
local dbg     = machine.debugger
local cpu     = machine.devices[CPU_TAG]
local space   = cpu.spaces["program"]

local function log(s) print("[bench] " .. s) end

-- ---------------------------------------------------------------------
-- Minimal JSON array-of-flat-objects reader (see scripts/run-bench.js
-- for the writer). Handles the escapes JSON.stringify actually produces
-- in a Windows file path (backslashes).
-- ---------------------------------------------------------------------
local function jsonUnescape(s)
    return (s:gsub('\\(.)', '%1'))
end

local function loadSegmentManifest(path)
    local f = assert(io.open(path, "r"), "cannot open segments file: " .. path)
    local text = f:read("*a")
    f:close()

    local segments = {}
    for obj in text:gmatch("{(.-)}") do
        local seg = {}
        -- Values here are simple (names, "BB/OOOO" addresses, file paths)
        -- and never contain a literal quote, so a plain [^"]* capture is
        -- sufficient; jsonUnescape() only needs to collapse the doubled
        -- backslashes JSON.stringify produces for Windows paths.
        for key, val in obj:gmatch('"(%a+)"%s*:%s*"([^"]*)"') do
            seg[key] = jsonUnescape(val)
        end
        for key, val in obj:gmatch('"(%a+)"%s*:%s*(-?%d+)') do
            seg[key] = tonumber(val)
        end
        if seg.addr and seg.file then
            seg.addr = parseAddr(seg.addr)
            table.insert(segments, seg)
        end
    end
    return segments
end

local segments = loadSegmentManifest(SEGMENTS_FILE)
if #segments == 0 then
    error("no segments found in " .. SEGMENTS_FILE)
end

local function loadSegments()
    for _, seg in ipairs(segments) do
        local binFile = assert(io.open(seg.file, "rb"), "cannot open segment: " .. seg.file)
        local bytes = binFile:read("*a")
        binFile:close()

        local base = seg.addr.flat
        for i = 1, #bytes do
            space:write_u8(base + i - 1, bytes:byte(i))
        end

        log(string.format("loaded %-12s %6d bytes @ %02X/%04X", seg.name, #bytes, seg.addr.bank, seg.addr.offset))
    end
end

-- Read the debugger's "totalcycles" expression -- the only way found to
-- get a true per-instruction cycle count in this build (see header notes).
-- Printed in hex with no "0x" prefix.
local function readTotalCycles()
    dbg:command("print totalcycles")
    local line = dbg.consolelog[#dbg.consolelog]
    return tonumber(line, 16)
end

local function report(startCycles, endCycles)
    local text = string.format("cycles=%d\n", endCycles - startCycles)
    log(text)

    local out = assert(io.open(RESULT_FILE, "w"))
    out:write(text)
    out:close()
end

-- ---------------------------------------------------------------------
-- Detect breakpoint hits via consolelog growth (the only reliable
-- signal under "-debugger none"; see header notes).
-- ---------------------------------------------------------------------
cpu.debug:bpset(JSL_ADDR.flat, "1", "")
log(string.format("armed preload trap @ %s", JSL_ADDR_S))

cpu.debug:bpset(EXIT_ADDR.flat, "1", "")
log(string.format("armed exit trap @ %s", EXIT_ADDR_S))

cpu.debug:bpset(FAIL_ADDR.flat, "1", "")
log(string.format("armed boot-toolbox failure trap @ %s", FAIL_ADDR_S))

local consolelog  = dbg.consolelog
local last        = 0
local done        = false
local startCycles = nil

emu.register_periodic(function()
    if done then return end
    if #consolelog == last then return end
    last = #consolelog
    local msg = consolelog[#consolelog]
    if not msg:find("Stopped at", 1, true) then return end

    local flat = (cpu.state["PB"].value << 16) | cpu.state["PC"].value

    if flat == JSL_ADDR.flat then
        loadSegments()
        startCycles = readTotalCycles()
        last = #consolelog
        dbg:command("go")
    elseif flat == EXIT_ADDR.flat then
        report(startCycles, readTotalCycles())
        done = true
        machine:exit()
    elseif flat == FAIL_ADDR.flat then
        log("BOOT TOOLBOX CALL FAILED (carry was set) -- see the boot stub's "
            .. "carry checks in scripts/make-boot-disk.js; no benchmark result produced")
        done = true
        machine:exit()
    else
        log(string.format("stopped at unexpected %06X (%s) -- resuming", flat, msg))
        dbg:command("go")
    end
end)

log("setup complete, issuing go")
dbg:command("go")
