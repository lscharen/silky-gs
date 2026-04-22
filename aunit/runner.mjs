/**
 * aunit/runner.mjs  -  AUnit test runner
 *
 * Assembles an ORCA-syntax .s file, links it, executes it under
 * GoldenGate (iix), reads the resulting out.dat, and returns a
 * parsed result object.
 *
 * Build artifacts are kept out of the source tree:
 *   - assemble runs with cwd = source dir (required so that relative
 *     `copy` paths inside the .s file resolve correctly), but the
 *     .ROOT and .A object files it produces are deleted immediately
 *     after the link step.
 *   - link writes the executable directly into an OS temp directory
 *     via an absolute KEEP= path.
 *   - iix runs with cwd = temp dir, so out.dat lands there too.
 *   - the temp directory is deleted in a finally block regardless of
 *     whether the test passes or throws.
 *
 * Usage:
 *   import { runAssemblyTest } from './aunit/runner.mjs';
 *   const result = await runAssemblyTest('tests/my_test.s');
 *
 * The returned object:
 *   result.ok          boolean  true if harness completed without GS/OS error
 *   result.status      number   harness status byte (0=ok)
 *   result.registers   object   { A, X, Y, P, DP, SP, DBR, K } (numbers)
 *   result.memory[]    array    { bank, address, data: Buffer }
 *   result.values{}    object   named 16-bit values { name: number }
 *   result.raw         Buffer   the full out.dat binary
 */

import { execFile }                     from 'node:child_process';
import { promisify }                    from 'node:util';
import { readFile, unlink, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir }                        from 'node:os';
import { dirname, basename, join, resolve } from 'node:path';
import { parseResult }                  from './parser.mjs';

const execFileP = promisify(execFile);

// GoldenGate exits with this code when a program terminates via the normal
// BRK #0 at ff/ff01 (the launcher's return address trap).  Treat it as a
// successful run and check for out.dat instead of throwing.
const IIX_NORMAL_EXIT = 4294967294; // 0xFFFFFFFE = -2 as uint32

const IIX = 'C:\\Program Files (x86)\\GoldenGate\\iix.exe';

/**
 * Run one assembly test.
 *
 * @param {string} sourcePath  Absolute or repo-relative path to the .s file
 * @param {object} [opts]
 * @param {boolean} [opts.keepArtifacts=false]  Keep temp dir on completion (logs its path)
 * @param {boolean} [opts.trace=false]          Pass --trace-gsos to iix
 * @param {string}  [opts.outFile='out.dat']    GS/OS output filename written by harness
 * @returns {Promise<object>}
 */
export async function runAssemblyTest(sourcePath, opts = {}) {
  const {
    keepArtifacts = false,
    trace         = false,
    outFile       = 'out.dat',
  } = opts;

  const absSource = resolve(sourcePath);
  const sourceDir = dirname(absSource);
  const base      = basename(absSource, '.s');

  // Temporary directory receives the linked executable and out.dat.
  // It is deleted in the finally block regardless of outcome.
  const tmpDir = await mkdtemp(join(tmpdir(), 'aunit-'));

  // Object files written by the assembler into sourceDir.
  // Deleted immediately after linking so the source tree is clean.
  const objRoot = join(sourceDir, base + '.ROOT');
  const objA    = join(sourceDir, base + '.A');

  // Executable and result land in tmpDir.
  const exePath = join(tmpDir, base + '.aunit');
  const outPath = join(tmpDir, outFile);

  try {
    // --- assemble ---
    // Must run with cwd = sourceDir so that `copy` directives inside the
    // source file resolve relative to the source location.
    // Produces <base>.ROOT and <base>.A in sourceDir.
    try {
      await execFileP(IIX, ['assemble', '-P', absSource], { cwd: sourceDir });
    } catch (err) {
      throw new AssemblyError(`assemble failed: ${err.stderr || err.message}`);
    }

    // --- link ---
    // Reads <base>.ROOT + <base>.A from sourceDir (cwd).
    // KEEP= is an absolute path so the executable lands in tmpDir.
    try {
      await execFileP(IIX, ['link', base, `KEEP=${exePath}`], { cwd: sourceDir });
    } catch (err) {
      throw new AssemblyError(`link failed: ${err.stderr || err.message}`);
    } finally {
      // Remove object files from the source tree immediately, even if the
      // link step itself failed.
      await Promise.allSettled([unlink(objRoot), unlink(objA)]);
    }

    // --- execute ---
    // cwd = tmpDir so out.dat is written there, not into the source tree.
    const iixArgs = trace ? ['--trace-gsos', exePath] : [exePath];

    let iixExitCode = 0;
    try {
      await execFileP(IIX, iixArgs, { cwd: tmpDir });
    } catch (err) {
      iixExitCode = err.code;
      // GoldenGate's normal program-exit trap (BRK #0 at ff/ff01) causes iix
      // to return IIX_NORMAL_EXIT.  Anything else is a true crash.
      if (iixExitCode !== IIX_NORMAL_EXIT) {
        throw new AssemblyError(
          `execution failed (exit ${iixExitCode}): ${err.stderr || err.message}`
        );
      }
    }

    // --- read result ---
    let raw;
    try {
      raw = await readFile(outPath);
    } catch (err) {
      throw new AssemblyError(
        `out.dat not found — did the harness call AUnit_WriteResults? ` +
        `iix exit ${iixExitCode} (${err.message})`
      );
    }

    // --- parse ---
    const result = parseResult(raw);
    result.raw   = raw;
    return result;

  } finally {
    if (keepArtifacts) {
      console.log(`[aunit] artifacts kept in: ${tmpDir}`);
    } else {
      await rm(tmpDir, { recursive: true, force: true });
    }
  }
}

export class AssemblyError extends Error {
  constructor(msg) { super(msg); this.name = 'AssemblyError'; }
}
