/**
 * aunit/runner.mjs  -  AUnit test runner
 *
 * Two entry points:
 *
 *   runAssemblyTest(sourcePath, opts)
 *     Assembles a hand-written test harness (.s), runs it under GoldenGate,
 *     and returns a parsed AUNT result object.
 *     Supports both ORCA/M (default) and Merlin32 assemblers.
 *
 *   runGeneratedTest(config, opts)
 *     Builds the test harness automatically from a JS description of the
 *     test environment (registers, memory setup, memory capture) and runs it.
 *     No hand-written assembly required beyond the function under test.
 *     Supports both ORCA/M (default) and Merlin32 assemblers.
 *
 * Assembler selection:
 *   Pass  opts.assembler = 'orca'     (default) for ORCA/M via iix assemble/link.
 *   Pass  opts.assembler = 'merlin32' for Merlin32 — produces OMF in one step.
 *   For runGeneratedTest, assembler may also live in config.assembler.
 *
 * ORCA/M build artifacts:
 *   runAssemblyTest: assembler runs with cwd = source directory so that
 *     relative `copy` paths inside .s files resolve correctly.  Object files
 *     (.ROOT, .A) are written there but deleted in the outer finally block.
 *     The linker writes the executable into an OS temp directory via an
 *     absolute KEEP= path.  iix runs with cwd = temp dir so out.dat lands
 *     there too.  The temp directory is deleted in a finally block.
 *   runGeneratedTest: ALL artifacts (generated .s, .ROOT, .A, exe, out.dat)
 *     live in a single OS temp directory.  Copy directives use absolute
 *     Windows paths so the assembler can locate library files even though
 *     cwd is no longer the source tree.  The temp directory is deleted on
 *     completion.
 *
 * Merlin32 build artifacts:
 *   A generated link file (TYP S16, DSK <exe>, ASM <source>) is written to
 *   tmpDir.  Merlin32 assembles and links in one step, writing the OMF to
 *   the absolute path given by DSK.  iix then runs the OMF.  The entire
 *   tmpDir is deleted on completion.
 *
 * Result object:
 *   result.ok          boolean  true if status byte is 0
 *   result.status      number   raw status byte from header
 *   result.registers   object   { A, X, Y, P, DP, SP, DBR, K } (numbers)
 *   result.memory[]    array    [{ bank, address, data: Buffer }]
 *   result.values{}    object   { name: value } from 'V' records
 *   result.raw         Buffer   the complete out.dat binary
 */

import { execFile }                          from 'node:child_process';
import { promisify }                         from 'node:util';
import { readFile, writeFile, unlink,
         mkdtemp, rm }                       from 'node:fs/promises';
import { tmpdir }                            from 'node:os';
import { fileURLToPath }                     from 'node:url';
import { dirname, basename, join,
         resolve }                           from 'node:path';
import { parseResult }                       from './parser.mjs';

const execFileP = promisify(execFile);

// GoldenGate exits with this code when a program terminates via the normal
// BRK #0 at ff/ff01 (the launcher's return address trap).  Treat it as a
// successful run and check for out.dat instead of throwing.
const IIX_NORMAL_EXIT = 4294967294; // 0xFFFFFFFE = -2 as uint32

const IIX      = 'C:\\Program Files (x86)\\GoldenGate\\iix.exe';
const MERLIN32 = 'C:\\Programs\\IIgsXDev\\bin\\Merlin32-BD-1.1.0.exe';

// Resolved once at module load time.
const _runnerDir      = dirname(fileURLToPath(import.meta.url));
const MERLIN32_MACROS = resolve(_runnerDir, '..', 'macros');

// ---------------------------------------------------------------------------
// _runTest — private core (ORCA/M): assemble, link, execute, parse
//
// absSource  absolute path to the .s source file
// sourceDir  directory where assembler is invoked (cwd); .ROOT/.A land here
// tmpDir     directory where exe and out.dat land; also iix execution cwd
// ---------------------------------------------------------------------------
async function _runTest(absSource, sourceDir, tmpDir, opts = {}) {
  const {
    trace   = false,
    outFile = 'out.dat',
  } = opts;

  const base    = basename(absSource, '.s');
  const objRoot = join(sourceDir, base + '.ROOT');
  const objA    = join(sourceDir, base + '.A');
  const exePath = join(tmpDir,    base + '.aunit');
  const outPath = join(tmpDir,    outFile);

  try {
    // --- assemble ---
    // cwd = sourceDir so relative `copy` paths inside the .s resolve correctly.
    try {
      await execFileP(IIX, ['assemble', '-P', absSource], { cwd: sourceDir });
    } catch (err) {
      throw new AssemblyError(`assemble failed: ${err.stderr || err.message}`);
    }

    // --- link ---
    // KEEP= is an absolute path so the executable lands in tmpDir.
    try {
      await execFileP(IIX, ['link', base, `KEEP=${exePath}`], { cwd: sourceDir });
    } catch (err) {
      throw new AssemblyError(`link failed: ${err.stderr || err.message}`);
    }

    // --- execute ---
    // cwd = tmpDir so out.dat is written there, not into the source tree.
    const iixArgs = trace ? ['--trace-gsos', exePath] : [exePath];

    let iixExitCode = 0;
    try {
      await execFileP(IIX, iixArgs, { cwd: tmpDir });
    } catch (err) {
      iixExitCode = err.code;
      if (iixExitCode !== IIX_NORMAL_EXIT) {
        throw new AssemblyError(
          `execution failed (exit ${iixExitCode}): ${err.stderr || err.message}`
        );
      }
    }

    // --- read and parse ---
    let raw;
    try {
      raw = await readFile(outPath);
    } catch (err) {
      throw new AssemblyError(
        `out.dat not found — did the harness call AUnit_WriteResults? ` +
        `iix exit ${iixExitCode} (${err.message})`
      );
    }

    const result = parseResult(raw);
    result.raw   = raw;
    return result;

  } finally {
    // Always remove object files; Promise.allSettled silently ignores missing files.
    await Promise.allSettled([unlink(objRoot), unlink(objA)]);
  }
}

// ---------------------------------------------------------------------------
// _runTestMerlin32 — private core (Merlin32): assemble+link in one step
//
// absSource  absolute path to the master .s source file
// sourceDir  cwd for Merlin32 (affects relative PUT paths in the source)
// tmpDir     where the link file, OMF exe, and out.dat land
// ---------------------------------------------------------------------------
async function _runTestMerlin32(absSource, sourceDir, tmpDir, opts = {}) {
  const {
    trace   = false,
    outFile = 'out.dat',
  } = opts;

  const base     = basename(absSource, '.s');
  const exePath  = join(tmpDir, base + '.aunit');
  const linkPath = join(tmpDir, `_link_${base}.s`);
  const outPath  = join(tmpDir, outFile);

  // Generate a minimal Merlin32 link file that points to the source and
  // writes the OMF output to tmpDir.
  const linkSource = [
    '* Auto-generated AUnit link file — do not edit',
    '            TYP   S16',
    `            DSK   ${exePath}`,
    `            ASM   ${absSource}`,
  ].join('\n') + '\n';

  await writeFile(linkPath, linkSource, 'utf8');

  // --- assemble + link (one Merlin32 invocation) ---
  // cwd = sourceDir so relative PUT paths in the source file resolve correctly.
  try {
    await execFileP(MERLIN32, [MERLIN32_MACROS, linkPath], { cwd: sourceDir });
  } catch (err) {
    throw new AssemblyError(
      `merlin32 assemble failed:\n${err.stdout || ''}\n${err.stderr || err.message}`
    );
  }

  // --- execute ---
  // cwd = tmpDir so out.dat is written there.
  const iixArgs = trace ? ['--trace-gsos', exePath] : [exePath];

  let iixExitCode = 0;
  try {
    await execFileP(IIX, iixArgs, { cwd: tmpDir });
  } catch (err) {
    iixExitCode = err.code;
    if (iixExitCode !== IIX_NORMAL_EXIT) {
      throw new AssemblyError(
        `execution failed (exit ${iixExitCode}): ${err.stderr || err.message}`
      );
    }
  }

  // --- read and parse ---
  let raw;
  try {
    raw = await readFile(outPath);
  } catch (err) {
    throw new AssemblyError(
      `out.dat not found — did the harness call AUnit_WriteResults? ` +
      `iix exit ${iixExitCode} (${err.message})`
    );
  }

  const result = parseResult(raw);
  result.raw   = raw;
  return result;
}

// ---------------------------------------------------------------------------
// runAssemblyTest — hand-written harness
// ---------------------------------------------------------------------------

/**
 * Assemble, link, and run a hand-written test harness.
 *
 * @param {string} sourcePath  Absolute or repo-relative path to the .s file.
 * @param {object} [opts]
 * @param {string}  [opts.assembler='orca']     'orca' or 'merlin32'.
 * @param {boolean} [opts.keepArtifacts=false]  Keep temp dir (logs its path).
 * @param {boolean} [opts.trace=false]          Pass --trace-gsos to iix.
 * @param {string}  [opts.outFile='out.dat']    GS/OS output filename.
 * @returns {Promise<object>}
 */
export async function runAssemblyTest(sourcePath, opts = {}) {
  const { keepArtifacts = false, assembler = 'orca' } = opts;

  const absSource = resolve(sourcePath);
  const sourceDir = dirname(absSource);
  const tmpDir    = await mkdtemp(join(tmpdir(), 'aunit-'));

  try {
    if (assembler === 'merlin32') {
      return await _runTestMerlin32(absSource, sourceDir, tmpDir, opts);
    }
    return await _runTest(absSource, sourceDir, tmpDir, opts);
  } finally {
    if (keepArtifacts) {
      console.log(`[aunit] artifacts kept in: ${tmpDir}`);
    } else {
      await rm(tmpDir, { recursive: true, force: true });
    }
  }
}

// ---------------------------------------------------------------------------
// runGeneratedTest — auto-generated harness
// ---------------------------------------------------------------------------

/**
 * Generate a test harness from a JS description, assemble it, run it,
 * and return the parsed AUNT result.
 *
 * All artifacts (generated .s, exe, out.dat) are written to an OS temp
 * directory and deleted on completion.  Nothing is written into the source
 * tree.  Include paths use absolute Windows paths so that library files
 * resolve correctly regardless of cwd.
 *
 * @param {object} config
 *
 * @param {string}   config.assembler
 *   'orca' (default) or 'merlin32'.  Selects the assembler and the syntax
 *   used in the generated harness.
 *
 * @param {string}   config.testDir
 *   Absolute path to the calling test file's directory.  Used to resolve
 *   relative include paths.
 *   Typically: dirname(fileURLToPath(import.meta.url))
 *
 * @param {string}   config.call
 *   Assembly label of the function under test.  Must be defined in one of
 *   the included source files (or their transitive includes).
 *
 * @param {string[]} [config.includes=[]]
 *   Paths to .s source files that define the function under test and any
 *   dependencies.  Each path may be absolute or relative to testDir.
 *   ORCA/M: included via `copy` directives.
 *   Merlin32: included via `put` directives.
 *
 * @param {object}   [config.registers={}]
 *   Initial 16-bit CPU register values: { A?, X?, Y? }.
 *
 * @param {Array}    [config.memory=[]]
 *   Memory regions to pre-populate before the call.  Each entry:
 *   { label: string, offset?: number, data: Buffer | number[] }
 *
 * @param {Array}    [config.captureMemory=[]]
 *   Memory regions to snapshot after the call.  Each entry:
 *   { label: string, offset?: number, length: number }
 *
 * @param {object}   [opts]  Same options as runAssemblyTest.
 * @returns {Promise<object>}
 */
export async function runGeneratedTest(config, opts = {}) {
  const {
    assembler     = 'orca',
    testDir,
    call,
    callMode      = 'jsl',
    includes      = [],
    registers     = {},
    memory        = [],
    captureMemory = [],
  } = config;

  if (!testDir) throw new Error('runGeneratedTest: config.testDir is required');
  if (!call)    throw new Error('runGeneratedTest: config.call is required');

  const { keepArtifacts = false } = opts;

  const tmpDir = await mkdtemp(join(tmpdir(), 'aunit-'));

  // Unique suffix to avoid collisions when tests run sequentially.
  const suffix  = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  const genName = `_aunit_${suffix}`;

  try {
    if (assembler === 'merlin32') {
      return await _runGeneratedMerlin32(
        { testDir, call, callMode, includes, registers, memory, captureMemory },
        genName, tmpDir, opts
      );
    }
    return await _runGeneratedOrca(
      { testDir, call, callMode, includes, registers, memory, captureMemory },
      genName, tmpDir, opts
    );
  } finally {
    if (keepArtifacts) {
      console.log(`[aunit] artifacts kept in: ${tmpDir}`);
    } else {
      await rm(tmpDir, { recursive: true, force: true });
    }
  }
}

// ---------------------------------------------------------------------------
// _runGeneratedOrca — generate and run an ORCA/M harness
// ---------------------------------------------------------------------------
async function _runGeneratedOrca(config, genName, tmpDir, opts) {
  const { testDir, call, callMode = 'jsl', includes, registers, memory, captureMemory } = config;

  const aunitS = join(_runnerDir, 'lib', 'aunit.s');
  const ioS    = join(_runnerDir, 'lib', 'io.s');

  // Convert any path to an absolute Windows path with forward slashes.
  const copyPath = (p) => resolve(testDir, p).replace(/\\/g, '/');

  const hex4     = (n) => `$${(n & 0xFFFF).toString(16).padStart(4, '0').toUpperCase()}`;
  const addrExpr = (label, offset = 0) => offset === 0 ? label : `${label}+${offset}`;

  const lines = [];
  const emit  = (...strs) => lines.push(...strs);

  emit(
    '* Auto-generated AUnit harness — do not edit',
    `* call: ${call}`,
    '',
    '        org    $020000',
    'Main    start',
    '',
    '        clc',
    '        xce                    ; native mode',
    '        rep    #$30            ; 16-bit A and X/Y',
    '',
    '        phk',
    '        plb                    ; DBR = program bank ($02)',
    '',
    '        jsl    AUnit_Init',
    '',
  );

  const A = registers.A ?? 0;
  const X = registers.X ?? 0;
  const Y = registers.Y ?? 0;
  emit(
    '* --- register setup ---',
    `        lda    #${hex4(A)}`,
    `        ldx    #${hex4(X)}`,
    `        ldy    #${hex4(Y)}`,
    '',
  );

  memory.forEach((item, i) => {
    const offset = item.offset ?? 0;
    const data   = Buffer.isBuffer(item.data) ? item.data : Buffer.from(item.data);
    if (data.length === 0) return;
    emit(
      `* --- memory setup ${i}: ${addrExpr(item.label, offset)} (${data.length} bytes) ---`,
      `        lda    #${data.length - 1}`,
      `        ldx    #_AUSetup${i}`,
      `        ldy    #${addrExpr(item.label, offset)}`,
      `        dc     h'540202'          ; mvn $02,$02`,
      '',
    );
  });

  emit(
    '* --- call ---',
    `        ${callMode}    ${call}`,
    '',
    '* --- capture registers ---',
    '        php',
    '        phk',
    '        plb',
    '        rep    #$30',
    '        jsl    AUnit_CaptureRegs',
    '',
  );

  captureMemory.forEach((item, i) => {
    const offset = item.offset ?? 0;
    emit(
      `* --- capture memory ${i}: ${addrExpr(item.label, offset)} (${item.length} bytes) ---`,
      `        lda    #${addrExpr(item.label, offset)}`,
      `        ldx    #${item.length}`,
      '        jsl    AUnit_AppendMem',
      '',
    );
  });

  emit(
    '        jsl    AUnit_WriteResults',
    '        rtl',
    '',
  );

  memory.forEach((item, i) => {
    const data = Buffer.isBuffer(item.data) ? item.data : Buffer.from(item.data);
    if (data.length === 0) return;
    emit(`_AUSetup${i} dc h'${data.toString('hex').toUpperCase()}'`);
  });

  emit(
    '',
    '        end',
    '',
  );

  for (const inc of includes) {
    emit(`        copy   ${copyPath(inc)}`);
  }
  emit(
    `        copy   ${copyPath(aunitS)}`,
    `        copy   ${copyPath(ioS)}`,
  );

  const source  = lines.join('\n') + '\n';
  const genPath = join(tmpDir, genName + '.s');
  await writeFile(genPath, source, 'utf8');

  return await _runTest(genPath, tmpDir, tmpDir, opts);
}

// ---------------------------------------------------------------------------
// _runGeneratedMerlin32 — generate and run a Merlin32 harness
// ---------------------------------------------------------------------------
async function _runGeneratedMerlin32(config, genName, tmpDir, opts) {
  const { testDir, call, callMode = 'jsl', includes, registers, memory, captureMemory } = config;

  const aunitS = join(_runnerDir, 'lib', 'aunit.merlin.s');
  const ioS    = join(_runnerDir, 'lib', 'io.merlin.s');

  // Absolute path with forward slashes for PUT directives.
  const putPath  = (p) => resolve(testDir, p).replace(/\\/g, '/');
  const hex4     = (n) => `$${(n & 0xFFFF).toString(16).padStart(4, '0').toUpperCase()}`;
  const addrExpr = (label, offset = 0) => offset === 0 ? label : `${label}+${offset}`;

  const lines = [];
  const emit  = (...strs) => lines.push(...strs);

  emit(
    '* Auto-generated AUnit harness — do not edit',
    `* call: ${call}`,
    '',
    '            rel                      ; relocatable OMF segment',
    '            mx    %00                ; 16-bit A and X/Y',
    '',
    'Main',
    '            clc',
    '            xce                      ; native mode',
    '            rep   #$30               ; 16-bit A and X/Y',
    '',
    '            phk',
    '            plb                      ; DBR = program bank ($02)',
    '',
    '            jsl   AUnit_Init',
    '',
  );

  const A = registers.A ?? 0;
  const X = registers.X ?? 0;
  const Y = registers.Y ?? 0;
  emit(
    '* --- register setup ---',
    `            lda   #${hex4(A)}`,
    `            ldx   #${hex4(X)}`,
    `            ldy   #${hex4(Y)}`,
    '',
  );

  memory.forEach((item, i) => {
    const offset = item.offset ?? 0;
    const data   = Buffer.isBuffer(item.data) ? item.data : Buffer.from(item.data);
    if (data.length === 0) return;
    emit(
      `* --- memory setup ${i}: ${addrExpr(item.label, offset)} (${data.length} bytes) ---`,
      `            lda   #${data.length - 1}`,
      `            ldx   #_AUSetup${i}`,
      `            ldy   #${addrExpr(item.label, offset)}`,
      `            mvn   $02,$02`,
      '',
    );
  });

  emit(
    '* --- call ---',
    `            ${callMode}   ${call}`,
    '',
    '* --- capture registers ---',
    '            php',
    '            phk',
    '            plb',
    '            rep   #$30',
    '            jsl   AUnit_CaptureRegs',
    '',
  );

  captureMemory.forEach((item, i) => {
    const offset = item.offset ?? 0;
    emit(
      `* --- capture memory ${i}: ${addrExpr(item.label, offset)} (${item.length} bytes) ---`,
      `            lda   #${addrExpr(item.label, offset)}`,
      `            ldx   #${item.length}`,
      '            jsl   AUnit_AppendMem',
      '',
    );
  });

  emit(
    '            jsl   AUnit_WriteResults',
    '            rtl',
    '',
  );

  // Inline data tables (after RTL — never executed)
  memory.forEach((item, i) => {
    const data = Buffer.isBuffer(item.data) ? item.data : Buffer.from(item.data);
    if (data.length === 0) return;
    emit(`_AUSetup${i} hex   ${data.toString('hex').toUpperCase()}`);
  });

  emit('');

  // PUT includes: user files first, then AUnit library (all absolute paths).
  for (const inc of includes) {
    emit(`            put   ${putPath(inc)}`);
  }
  emit(
    `            put   ${putPath(aunitS)}`,
    `            put   ${putPath(ioS)}`,
  );

  const source  = lines.join('\n') + '\n';
  const genPath = join(tmpDir, genName + '.s');
  await writeFile(genPath, source, 'utf8');

  // sourceDir = tmpDir: all PUT paths are absolute, so cwd doesn't matter.
  return await _runTestMerlin32(genPath, tmpDir, tmpDir, opts);
}

// ---------------------------------------------------------------------------
// captureMemory decoding helpers (used by cpu65816)
// ---------------------------------------------------------------------------

// Byte size for each supported 'as' type name.
const _AS_SIZE = {
  byte: 1, db: 1,
  word: 2, words: 2, dw: 2,
  long: 3, longs: 3, dl: 3,
  dd:   4,
};

// Decode `count` typed values from `buf` using the given `as` type name.
// Returns a single number when count === 1, an array otherwise.
function _decodeMemory(buf, as, count) {
  const size = _AS_SIZE[as];
  if (size === undefined) throw new Error(`cpu65816: unknown captureMemory type '${as}'`);
  const vals = [];
  for (let i = 0; i < count; i++) {
    const off = i * size;
    let v;
    if      (size === 1) v = buf[off];
    else if (size === 2) v = buf.readUInt16LE(off);
    else if (size === 3) v = buf[off] | (buf[off + 1] << 8) | (buf[off + 2] << 16);
    else                 v = buf.readUInt32LE(off);
    vals.push(v);
  }
  return count === 1 ? vals[0] : vals;
}

// ---------------------------------------------------------------------------
// cpu65816 — builder pattern for generated tests
// ---------------------------------------------------------------------------

/**
 * Create a bound test runner that captures shared config once and returns
 * `jsl` and `jsr` caller functions for use in vitest/jest describe blocks.
 *
 * @param {object} sharedConfig
 * @param {string}   sharedConfig.testDir    Absolute path to the test directory.
 * @param {string[]} [sharedConfig.includes] Source files containing the functions under test.
 * @param {string}   [sharedConfig.assembler='orca']  'orca' or 'merlin32'.
 * @param {boolean}  [sharedConfig.keepArtifacts=false]
 * @param {boolean}  [sharedConfig.trace=false]
 * @returns {{ jsl: Function, jsr: Function }}
 *
 * @example
 *   const { jsl } = cpu65816({ includes: [SRC], testDir: __dirname });
 *   const r = await jsl('MyFunc', { A: 0x10 });
 *   expect(r.A).toBe(0x20);
 */
export function cpu65816(sharedConfig) {
  const {
    includes      = [],
    testDir,
    assembler     = 'orca',
    keepArtifacts = false,
    trace         = false,
  } = sharedConfig;

  async function _call(callMode, label, callConfig = {}) {
    const {
      A             = 0,
      X             = 0,
      Y             = 0,
      memory        = [],
      captureMemory = [],
      ...perCallOpts
    } = callConfig;

    // Normalize captureMemory: when 'as' is present, derive 'length' from
    // the element size and count so the harness generator always sees a length.
    const normalizedCapture = captureMemory.map(spec => {
      if (spec.as === undefined) return spec;
      const size = _AS_SIZE[spec.as];
      if (size === undefined) throw new Error(`cpu65816: unknown captureMemory type '${spec.as}'`);
      const count = spec.count ?? 1;
      return { label: spec.label, offset: spec.offset, length: size * count };
    });

    const result = await runGeneratedTest(
      { assembler, testDir, includes, call: label, callMode,
        registers: { A, X, Y }, memory, captureMemory: normalizedCapture },
      { keepArtifacts, trace, ...perCallOpts }
    );

    if (!result.ok) {
      throw new AssemblyError(
        `AUnit harness failed (status ${result.status}) calling ${label}`
      );
    }

    // Build memory output keyed by label.  Entries with 'as' are decoded into
    // typed JS numbers; entries without 'as' expose the raw Buffer.
    const memOut = {};
    captureMemory.forEach((spec, i) => {
      const entry = result.memory[i];
      if (!entry) return;
      if (spec.as !== undefined) {
        memOut[spec.label] = _decodeMemory(entry.data, spec.as, spec.count ?? 1);
      } else {
        memOut[spec.label] = entry.data;
      }
    });

    return {
      ...result.registers,
      memory: memOut,
      values: result.values,
      raw:    result.raw,
    };
  }

  return {
    jsl: (label, cfg) => _call('jsl', label, cfg),
    jsr: (label, cfg) => _call('jsr', label, cfg),
  };
}

// ---------------------------------------------------------------------------
// Shared error class
// ---------------------------------------------------------------------------

export class AssemblyError extends Error {
  constructor(msg) { super(msg); this.name = 'AssemblyError'; }
}
