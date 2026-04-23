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
         resolve, relative }                from 'node:path';
import { parseResult }                       from './parser.mjs';

const execFileP = promisify(execFile);

// GoldenGate exits with this code when a program terminates via the normal
// BRK #0 at ff/ff01 (the launcher's return address trap).  Treat it as a
// successful run and check for out.dat instead of throwing.
const IIX_NORMAL_EXIT = 4294967294; // 0xFFFFFFFE = -2 as uint32

const IIX      = process.env.AUNIT_IIX      ?? 'C:\\Program Files (x86)\\GoldenGate\\iix.exe';
const MERLIN32 = process.env.AUNIT_MERLIN32 ?? 'C:\\Programs\\IIgsXDev\\bin\\Merlin32-BD-1.1.0.exe';

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
    let iixError    = null;
    try {
      await execFileP(IIX, iixArgs, { cwd: tmpDir });
    } catch (err) {
      iixExitCode = err.code;
      iixError    = err;
    }

    // --- read and parse ---
    // Check for out.dat before reporting execution failures: a harness that
    // crashes without writing out.dat should surface as a missing-results error.
    let raw;
    try {
      raw = await readFile(outPath);
    } catch (err) {
      if (iixError && iixExitCode !== IIX_NORMAL_EXIT) {
        throw new AssemblyError(
          `out.dat not found — did the harness call AUnit_WriteResults? ` +
          `iix exit ${iixExitCode} (${iixError.message})`
        );
      }
      throw new AssemblyError(
        `out.dat not found — did the harness call AUnit_WriteResults? ` +
        `iix exit ${iixExitCode} (${err.message})`
      );
    }

    if (iixError && iixExitCode !== IIX_NORMAL_EXIT) {
      throw new AssemblyError(
        `execution failed (exit ${iixExitCode}): ${iixError.stderr || iixError.message}`
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
// tmpDir     where the link file and out.dat land; also iix execution cwd
//
// The DSK directive uses a bare filename (no path) so Merlin32 writes the
// OMF to its own cwd (sourceDir).  This avoids ProDOS path validation on
// every Windows path component, which would reject any component containing
// characters illegal in ProDOS names (e.g. dashes in temp-dir suffixes).
// ---------------------------------------------------------------------------
async function _runTestMerlin32(absSource, sourceDir, tmpDir, opts = {}) {
  const {
    trace   = false,
    outFile = 'out.dat',
  } = opts;

  const rawBase  = basename(absSource, '.s');
  // ProDOS: 15-char max, only letters/numbers/dots.  '.aunit' = 6 chars → stem ≤ 8.
  const proBase  = rawBase.replace(/[^a-z0-9]/gi, '').slice(0, 8) || 'aunit';
  const exeName  = proBase + '.aunit';
  // DSK with a bare filename is resolved relative to the link file, which lives
  // in tmpDir — so the OMF lands in tmpDir regardless of the Merlin32 CWD.
  const exePath  = join(tmpDir, exeName);
  const linkPath = join(tmpDir, `_link_${rawBase}.s`);
  const outPath  = join(tmpDir, outFile);

  // Generate a minimal Merlin32 link file.  DSK is a bare filename so Merlin32
  // resolves it relative to the link file (in tmpDir) without validating any
  // intermediate Windows path components as ProDOS names.
  const linkSource = [
    '* Auto-generated AUnit link file — do not edit',
    '            TYP   S16',
    `            DSK   ${exeName}`,
    `            ASM   ${absSource}`,
  ].join('\n') + '\n';

  await writeFile(linkPath, linkSource, 'utf8');

  // --- assemble + link (one Merlin32 invocation) ---
  // cwd = sourceDir so relative PUT paths in the source file resolve correctly.
  // The bare DSK filename is resolved relative to the link file (in tmpDir).
  try {
    await execFileP(MERLIN32, [MERLIN32_MACROS, linkPath], { cwd: sourceDir });
  } catch (err) {
    throw new AssemblyError(
      `merlin32 assemble failed:\n${err.stdout || ''}\n${err.stderr || err.message}`
    );
  }

  // --- execute ---
  // cwd = tmpDir so out.dat is written there, not into sourceDir.
  // exePath is absolute so iix finds the OMF regardless of its cwd.
  const iixArgs = trace ? ['--trace-gsos', exePath] : [exePath];

  let iixExitCode = 0;
  let iixError    = null;
  try {
    await execFileP(IIX, iixArgs, { cwd: tmpDir });
  } catch (err) {
    iixExitCode = err.code;
    iixError    = err;
  }

  // --- read and parse ---
  // Check for out.dat before reporting execution failures: a harness that
  // crashes without writing out.dat should surface as a missing-results error.
  let raw;
  try {
    raw = await readFile(outPath);
  } catch (err) {
    if (iixError && iixExitCode !== IIX_NORMAL_EXIT) {
      throw new AssemblyError(
        `out.dat not found — did the harness call AUnit_WriteResults? ` +
        `iix exit ${iixExitCode} (${iixError.message})`
      );
    }
    throw new AssemblyError(
      `out.dat not found — did the harness call AUnit_WriteResults? ` +
      `iix exit ${iixExitCode} (${err.message})`
    );
  }

  if (iixError && iixExitCode !== IIX_NORMAL_EXIT) {
    throw new AssemblyError(
      `execution failed (exit ${iixExitCode}): ${iixError.stderr || iixError.message}`
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
  const tmpDir    = await mkdtemp(join(tmpdir(), 'au'));

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
    testDir       = process.cwd(),
    call,
    callMode      = 'jsl',
    includes      = [],
    registers     = {},
    memory        = [],
    captureMemory = [],
    allocMemory   = [],
  } = config;

  if (!call) throw new Error('runGeneratedTest: config.call is required');

  const { keepArtifacts = false } = opts;

  const tmpDir = await mkdtemp(join(tmpdir(), 'au'));

  // Unique suffix to avoid collisions when tests run sequentially.
  const suffix  = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  const genName = `_aunit_${suffix}`;

  try {
    if (assembler === 'merlin32') {
      return await _runGeneratedMerlin32(
        { testDir, call, callMode, includes, registers, memory, captureMemory, allocMemory },
        genName, tmpDir, opts
      );
    }
    return await _runGeneratedOrca(
      { testDir, call, callMode, includes, registers, memory, captureMemory, allocMemory },
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
// _emitRegSetup — emit register-initialisation instructions (assembler-neutral)
//
// Registers whose value is undefined are silently skipped.
// Order is mandatory for correctness:
//   DP  — tcd clobbers nothing else
//   DBR — pha+plb (net −1 to SP; must precede any TCS so the adjusted value
//          is correct)
//   SP  — tcs; if P is also set the stored value is pre-adjusted by +1 so
//          that the subsequent plp leaves SP at exactly the requested value
//   X, Y — ldx / ldy (order between them doesn't matter)
//   P push — lda #<P_value>; pha  (P in low byte; pha pushes low byte on top)
//   A  — lda #<A_value>  (loaded after P is staged so A is correct at call)
//   P pop  — plp  (final act before the call; may change M/X width bits)
//
// indent  leading whitespace string that matches the surrounding column style
// emit    the generator's emit(...lines) function
// ---------------------------------------------------------------------------
function _emitRegSetup(registers, indent, emit) {
  const { A, X, Y, DP, DBR, SP, P } = registers;
  if ([A, X, Y, DP, DBR, SP, P].every(v => v === undefined)) return;

  const i    = indent;
  const hex4 = (n) => `$${(n & 0xFFFF).toString(16).padStart(4, '0').toUpperCase()}`;
  // String values are treated as assembly label names (load address of label).
  const regVal = (v) => (typeof v === 'string') ? v : hex4(v);

  emit('* --- register setup ---');

  if (DP !== undefined)
    emit(`${i}lda   #${hex4(DP)}`, `${i}tcd`);

  if (SP !== undefined)
    emit(`${i}lda   #${hex4(SP)}`, `${i}tcs`);

  // Push P first (deepest), then DBR (on top).  Each uses a sep/rep pair so
  // only 1 byte is pushed.  Value is loaded into A while M=0 so that ORCA/M
  // assembles lda #imm as a 2-byte immediate rather than a 3-byte one.
  if (P !== undefined)
    emit(`${i}lda   #${hex4(P & 0xFF)}`, `${i}sep   #$20`, `${i}pha`, `${i}rep   #$20`);

  if (DBR !== undefined)
    emit(`${i}lda   #${hex4(DBR & 0xFF)}`, `${i}sep   #$20`, `${i}pha`, `${i}rep   #$20`);

  if (X !== undefined) emit(`${i}ldx   #${regVal(X)}`);
  if (Y !== undefined) emit(`${i}ldy   #${regVal(Y)}`);
  if (A !== undefined) emit(`${i}lda   #${regVal(A)}`);

  emit('');
}

// ---------------------------------------------------------------------------
// _runGeneratedOrca — generate and run an ORCA/M harness
// ---------------------------------------------------------------------------
async function _runGeneratedOrca(config, genName, tmpDir, opts) {
  const { testDir, call, callMode = 'jsl', includes, registers, memory, captureMemory, allocMemory } = config;

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

  _emitRegSetup(registers, '        ', emit);

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

  emit('* --- call ---');
  if (registers.DBR !== undefined) emit('        plb');
  if (registers.P   !== undefined) emit('        plp');
  emit(
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

  allocMemory.forEach(item => {
    emit(`${item.label}    ds    ${item.length}`);
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
// Path helpers for Merlin32 generated harnesses
// ---------------------------------------------------------------------------

// Resolve a user-supplied include path to a proper absolute Windows path.
// Handles the URL.pathname format that vitest's `new URL(...).pathname` emits
// on Windows: '/C:/some/path' → 'C:\...' (leading slash from URL)
// and the path.join artifact: '\C:\some\path' → 'C:\...' (backslash from join).
function _normAbsPath(testDir, p) {
  // charCode 47 = '/', 92 = '\'.  Strip leading separator before drive letter.
  const first = p.charCodeAt(0);
  if ((first === 47 || first === 92) && /^[A-Za-z]:/.test(p.slice(1))) p = p.slice(1);
  return resolve(testDir, p);
}

// Return the deepest directory that is a common ancestor of every path in
// `absDirs` (an array of already-resolved absolute directory paths).
function _commonParent(absDirs) {
  if (absDirs.length === 1) return absDirs[0];
  const parts = absDirs.map(d => d.replace(/\\/g, '/').split('/'));
  const minLen = Math.min(...parts.map(p => p.length));
  const common = [];
  for (let i = 0; i < minLen; i++) {
    if (parts.every(p => p[i].toLowerCase() === parts[0][i].toLowerCase())) {
      common.push(parts[0][i]);
    } else break;
  }
  // If nothing in common beyond the drive letter, return just the drive root.
  return common.join('\\') || (parts[0][0] + '\\');
}

// ---------------------------------------------------------------------------
// _runGeneratedMerlin32 — generate and run a Merlin32 harness
// ---------------------------------------------------------------------------
async function _runGeneratedMerlin32(config, genName, tmpDir, opts) {
  const { testDir, call, callMode = 'jsl', includes, registers, memory, captureMemory, allocMemory } = config;

  const aunitS = resolve(_runnerDir, 'lib', 'aunit.merlin.s');
  const ioS    = resolve(_runnerDir, 'lib', 'io.merlin.s');

  // Resolve all include paths to proper absolute Windows paths (handling the
  // '/C:/...' URL.pathname format that vitest env vars can produce on Windows).
  const absIncludes = includes.map(p => _normAbsPath(testDir, p));

  // Merlin32 resolves PUT paths relative to the primary source file's directory,
  // which is tmpDir (where the generated harness lives).  Use forward-slash
  // relative paths from tmpDir so no drive-letter prefix appears in any path
  // Merlin32's ProDOS layer must parse.
  const putPath  = (absPath) => relative(tmpDir, absPath).replace(/\\/g, '/');
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

  _emitRegSetup(registers, '            ', emit);

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

  emit('* --- call ---');
  if (registers.DBR !== undefined) emit('            plb');
  if (registers.P   !== undefined) emit('            plp');
  emit(
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

  allocMemory.forEach(item => {
    emit(`${item.label}    ds    ${item.length}`);
  });

  emit('');

  // PUT includes: user files first, then AUnit library.
  // Paths are relative from sourceDir (the Merlin32 CWD).
  for (const absInc of absIncludes) {
    emit(`            put   ${putPath(absInc)}`);
  }
  emit(
    `            put   ${putPath(aunitS)}`,
    `            put   ${putPath(ioS)}`,
  );

  const source  = lines.join('\n') + '\n';
  const genPath = join(tmpDir, genName + '.s');
  await writeFile(genPath, source, 'utf8');

  // sourceDir = tmpDir: Merlin32 resolves PUT paths relative to the primary
  // source file directory (genPath's dir = tmpDir), so cwd = tmpDir is correct.
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
    testDir       = process.cwd(),
    assembler     = 'orca',
    keepArtifacts = false,
    trace         = false,
  } = sharedConfig;

  async function _call(callMode, label, callConfig = {}) {
    const {
      A, X, Y, DP, DBR, SP, P,
      memory        = [],
      captureMemory = [],
      allocMemory   = [],
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

    // Normalize allocMemory: same shape as captureMemory.
    // With 'as': length is derived from the type size × count; result is typed numbers.
    // Without 'as': 'length' must be given directly; result is a raw Buffer (supports .toString()).
    const normalizedAlloc = allocMemory.map(spec => {
      if (spec.as !== undefined) {
        const size = _AS_SIZE[spec.as];
        if (size === undefined) throw new Error(`cpu65816: unknown allocMemory type '${spec.as}'`);
        const count = spec.count ?? 1;
        return { ...spec, length: size * count };
      }
      if (spec.length === undefined) throw new Error(`cpu65816: allocMemory entry '${spec.label}' must specify either 'as' or 'length'`);
      return { ...spec };
    });

    // allocMemory entries are automatically captured after the call so their
    // values are available in result.memory, keyed by label.
    const totalCapture = [...normalizedCapture, ...normalizedAlloc];

    const result = await runGeneratedTest(
      { assembler, testDir, includes, call: label, callMode,
        registers: { A, X, Y, DP, DBR, SP, P }, memory,
        captureMemory: totalCapture, allocMemory: normalizedAlloc },
      { keepArtifacts, trace, ...perCallOpts }
    );

    if (!result.ok) {
      throw new AssemblyError(
        `AUnit harness failed (status ${result.status}) calling ${label}`
      );
    }

    // Build memory output keyed by label.  Combine captureMemory and
    // allocMemory (in that order) to match the order passed to runGeneratedTest.
    const allCaptureSpecs = [...captureMemory, ...allocMemory];
    const memOut = {};
    allCaptureSpecs.forEach((spec, i) => {
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
