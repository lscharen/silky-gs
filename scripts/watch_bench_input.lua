-- watch_bench_input.lua
--
-- Diagnostic variant of scripts/mame_bench.lua: boots the same way (see
-- that file's header for the full boot-stub/breakpoint-detection design
-- notes -- this reuses the identical JSL/EXIT/FAIL handling), but instead
-- of just timing cycles, it also breaks on every read of BenchInputData
-- (src/rom/rom_input.s's BENCH_MODE branch) and logs {index, byte} to a
-- trace file. This is for answering one question: is NES_ReadInput really
-- consuming bench_input.bin in order and all the way to the end, or is
-- something (an off-by-one in the BENCH_MODE_LEN exhaustion check in
-- scaffold.s, an extra/missing NES_TriggerNMI call, etc.) causing it to
-- stall, skip, repeat, or run past the end of the table.
--
-- Each hit is cross-checked directly against the bytes on disk in
-- bench_input.bin (BENCH_INPUT_FILE) at the same index, so a mismatch
-- means the *wrong byte* is being fed to the ROM, not just a suspicious
-- index sequence.
--
-- Launch (same shape as run-bench.js's own MAME invocation -- reuse an
-- existing boot.po/segments.json/boot.po.json from a prior `node
-- scripts/run-bench.js src/games/smb` run rather than regenerating them):
--
--   mame apple2gs -window -nomax -skip_gameinfo -nofilter -snapsize 704x462 \
--     -speed 4.0 -debug -debugger none -flop1 src/games/smb/boot.po \
--     -autoboot_script scripts/watch_bench_input.lua
--
-- Required env vars (same as mame_bench.lua):
--   BENCH_SEGMENTS   segments.json (see run-bench.js)
--   BENCH_JSL        boot.po.json's jslAddr
--   BENCH_EXIT       boot.po.json's exitAddr
--   BENCH_FAIL       boot.po.json's failAddr
--
-- Additional env vars for this script:
--   BENCH_READ_ADDR  "BB/OOOO" address of the "lda BenchInputData,x"
--                     instruction in rom_input.s's BENCH_MODE branch.
--                     This shifts whenever code before it in the link
--                     order changes size -- regenerate by grepping the
--                     current build's listing, e.g.:
--                       grep "lda.*BenchInputData,x" src/games/smb/Main_S01_MAIN_Output.txt
--                     (default below matches the build current as of this
--                     writing: 03/AF43)
--   BENCH_INPUT_FILE path to the canned input file (default:
--                     src/games/smb/bench_input.bin)
--   BENCH_TRACE_OUT  output trace file (default: bench_input_trace.txt)
--
-- Output: BENCH_TRACE_OUT gets one line per read, "frame=N index=I byte=XX
-- [ok|MISMATCH expected=YY][ REPEAT | SKIP n]", plus a final summary line.
-- Also printed live via consolelog.

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
local READ_ADDR_S    = getenv("BENCH_READ_ADDR", "03/AF43")
local JOY_ADDR_S     = getenv("BENCH_JOY_ADDR", "07/8A4D")
local JOY_COND       = getenv("BENCH_JOY_COND", "(A&0xFF)!=0")
local WATCH_ADDR_S   = getenv("BENCH_WATCH_ADDR", "03/AF36")
local INPUT_FILE     = getenv("BENCH_INPUT_FILE", "src/games/smb/bench_input.bin")
local TRACE_OUT      = getenv("BENCH_TRACE_OUT", "bench_input_trace.txt")

if not SEGMENTS_FILE or not JSL_ADDR_S or not EXIT_ADDR_S or not FAIL_ADDR_S then
    error("BENCH_SEGMENTS, BENCH_JSL, BENCH_EXIT, and BENCH_FAIL environment variables are required")
end

local JSL_ADDR  = parseAddr(JSL_ADDR_S)
local EXIT_ADDR = parseAddr(EXIT_ADDR_S)
local FAIL_ADDR = parseAddr(FAIL_ADDR_S)
local READ_ADDR = parseAddr(READ_ADDR_S)
local JOY_ADDR  = parseAddr(JOY_ADDR_S)
local WATCH_ADDR = parseAddr(WATCH_ADDR_S)

local CPU_TAG = ":maincpu"

local machine = manager.machine
local dbg     = machine.debugger
local cpu     = machine.devices[CPU_TAG]
local space   = cpu.spaces["program"]

local function log(s) print("[watch] " .. s) end

-- ---------------------------------------------------------------------
-- On-screen overlay: continuously redraw the byte at BENCH_WATCH_ADDR
-- (default 03/AF36 -- native_joy+1, see rom_input.s) via MAME's built-in
-- popmessage overlay, so single-stepping through the interactive
-- debugger shows what's actually sitting there frame by frame without
-- having to switch to a memory-view window each time.
-- ---------------------------------------------------------------------
emu.register_frame_done(function()
    local v = space:read_u8(WATCH_ADDR.flat)
    machine:popmessage(string.format("[%s] = $%02X (%d)", WATCH_ADDR_S, v, v))
end)
log(string.format("watching %s -- value overlaid on screen every frame", WATCH_ADDR_S))

local trace = assert(io.open(TRACE_OUT, "w"))
local function tlog(s)
    trace:write(s .. "\n")
    trace:flush()
end

-- ---------------------------------------------------------------------
-- Load bench_input.bin so every read can be cross-checked against the
-- actual bytes on disk, not just its own internal consistency.
-- ---------------------------------------------------------------------
local expectedBytes = {}
do
    local f = assert(io.open(INPUT_FILE, "rb"), "cannot open bench input file: " .. INPUT_FILE)
    local data = f:read("*a")
    f:close()
    for i = 1, #data do
        expectedBytes[i - 1] = data:byte(i)
    end
    log(string.format("loaded %d expected bytes from %s", #data, INPUT_FILE))
end

-- ---------------------------------------------------------------------
-- Segment loading, identical to mame_bench.lua.
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

-- ---------------------------------------------------------------------
-- Read/watch bookkeeping.
-- ---------------------------------------------------------------------
local readCount   = 0
local lastIndex   = nil
local mismatches  = 0
local anomalies   = 0
local maxIndexSeen = -1

local function onReadHit()
    -- Stopped right before "lda BenchInputData,x" executes: X already
    -- holds the index (see rom_input.s -- "ldx BenchInputIndex" runs
    -- immediately before this). Step one instruction so A picks up the
    -- byte that was actually read, then resume.
    local index = cpu.state["X"].value & 0xFFFF
    local dbr = cpu.state["DBR"].value & 0xFF
    dbg:command("step")
    local byte = cpu.state["A"].value & 0xFF

    readCount = readCount + 1
    maxIndexSeen = math.max(maxIndexSeen, index)

    local expected = expectedBytes[index]
    local status
    if expected == nil then
        status = "MISMATCH expected=<out-of-range>"
        mismatches = mismatches + 1
    elseif byte ~= expected then
        status = string.format("MISMATCH expected=%02X", expected)
        mismatches = mismatches + 1
    else
        status = "ok"
    end

    local order = ""
    if lastIndex ~= nil then
        if index == lastIndex then
            order = " REPEAT"
        elseif index == lastIndex + 1 then
            order = ""
        elseif index > lastIndex + 1 then
            order = string.format(" SKIP(%d)", index - lastIndex - 1)
            anomalies = anomalies + 1
        else
            order = string.format(" OUT-OF-ORDER(prev=%d)", lastIndex)
            anomalies = anomalies + 1
        end
    end
    lastIndex = index

    tlog(string.format("read#%-5d index=%-4d byte=%02X dbr=%02X %s%s", readCount, index, byte, dbr, status, order))
end

-- ---------------------------------------------------------------------
-- Breakpoint dispatch, following the same consolelog-polling technique
-- as mame_bench.lua (see its header notes for why: "-debug" alone hides
-- breakpoint hits from every other Lua notifier tried).
-- ---------------------------------------------------------------------
cpu.debug:bpset(JSL_ADDR.flat, "1", "")
log(string.format("armed preload trap @ %s", JSL_ADDR_S))

cpu.debug:bpset(EXIT_ADDR.flat, "1", "")
log(string.format("armed exit trap @ %s", EXIT_ADDR_S))

cpu.debug:bpset(FAIL_ADDR.flat, "1", "")
log(string.format("armed boot-toolbox failure trap @ %s", FAIL_ADDR_S))

cpu.debug:bpset(READ_ADDR.flat, "1", "")
log(string.format("armed BenchInputData read trap @ %s", READ_ADDR_S))

-- 07/8A4D: right after ReadPortBits's "sta {$06fc},x" (see
-- SMBROM_S05_SMBROM_Output.txt) -- this is where the ROM itself has just
-- consumed the byte the HAL fed it via native_joy, into its own $06FC,x
-- shadow. Conditioned on A0 != 0 so it only stops on frames where the ROM
-- actually saw a button held, and left un-resumed (no auto "go") so the
-- interactive debugger takes over for manual inspection.
cpu.debug:bpset(JOY_ADDR.flat, JOY_COND, "")
log(string.format("armed joypad-consumed trap @ %s (condition: %s)", JOY_ADDR_S, JOY_COND))

local consolelog = dbg.consolelog
local last       = 0
local done       = false

local function finish(reason)
    tlog(string.format("--- %s: %d reads, indices 0..%d seen, %d mismatches, %d order anomalies ---",
        reason, readCount, maxIndexSeen, mismatches, anomalies))
    log(string.format("%s -- trace written to %s (%d reads, %d mismatches, %d anomalies)",
        reason, TRACE_OUT, readCount, mismatches, anomalies))
    trace:close()
    done = true
    machine:exit()
end

emu.register_periodic(function()
    if done then return end
    if #consolelog == last then return end
    last = #consolelog
    local msg = consolelog[#consolelog]
    if not msg:find("Stopped at", 1, true) then return end

    local flat = (cpu.state["PB"].value << 16) | cpu.state["PC"].value

    if flat == JSL_ADDR.flat then
        loadSegments()
        last = #consolelog
        dbg:command("go")
    elseif flat == READ_ADDR.flat then
        onReadHit()
        last = #consolelog
        dbg:command("go")
    elseif flat == JOY_ADDR.flat then
        log(string.format("joypad-consumed trap hit @ %s -- A0=%02X, X=%d -- stopped for manual inspection",
            JOY_ADDR_S, cpu.state["A"].value & 0xFF, cpu.state["X"].value & 0xFFFF))
        -- deliberately no dbg:command("go") -- leave it stopped
    elseif flat == EXIT_ADDR.flat then
        finish("benchmark RTL exit reached")
    elseif flat == FAIL_ADDR.flat then
        log("BOOT TOOLBOX CALL FAILED (carry was set) -- see the boot stub's "
            .. "carry checks in scripts/make-boot-disk.js")
        finish("boot failure")
    else
        log(string.format("stopped at unexpected %06X (%s) -- resuming", flat, msg))
        dbg:command("go")
    end
end)

log("setup complete, issuing go")
dbg:command("go")
