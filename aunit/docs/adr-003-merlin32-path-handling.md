# ADR-003: Merlin32 Path Handling — Relative Paths Over Absolute Windows Paths

**Date:** 2026-04-23  
**Status:** Accepted

## Context

The aunit runner generates two kinds of file references that Merlin32 must resolve:

1. **`DSK` in the link file** — the output path for the assembled OMF binary.
2. **`PUT` in the assembly source** — include paths for library and user source files.

The initial implementation supplied absolute Windows paths for both:

```
            DSK   C:\Users\lscharen\AppData\Local\Temp\aunit-7CAKkj\_aunit_mobj16hirix1.aunit
            ASM   C:\Users\lscharen\AppData\Local\Temp\aunit-7CAKkj\_aunit_mobj16hirix1.s
```

```asm
            put   C:/checkout/silky-gs-ref/aunit/lib/aunit.merlin.s
            put   C:/checkout/silky-gs-ref/aunit/test/merlin32/nop_func.s
```

Both caused Merlin32 to fail.

## The Problem: Merlin32 Uses ProDOS Path Semantics

Merlin32 is a native Windows executable, but it was originally a ProDOS application and retains ProDOS-style path resolution internally. This has two concrete consequences.

### 1. ProDOS filename validation on the `DSK` output path

Merlin32 validates the output filename given in `DSK` against ProDOS naming rules:

- Maximum 15 characters (including any dots)
- Only letters, digits, and dots — no underscores, dashes, spaces, or other punctuation

The initial implementation generated names such as `_aunit_mobj16hirix1.aunit` (25 chars, underscores) from a `Date.now().toString(36)` suffix prefixed with `_aunit_`. Both violations caused Merlin32 to abort immediately with:

```
Error, Bad Link file name '..._aunit_mobj16hirix1.aunit' :
  Invalid Prodos file name (15 chars max, letters/numbers/. allowed).
```

Merlin32 validates **every path component** in the `DSK` value as a ProDOS filename — not just the leaf name. This means the temp directory itself (`aunit-7CAKkj`, containing a dash) also fails validation, even if the leaf filename is corrected.

### 2. Drive-letter paths are treated as relative

In ProDOS, there is no concept of a drive letter. A path beginning with `C:\` or `C:/` is not recognised as an absolute root — `C:` is treated as a plain directory name, resolved relative to the current working directory. Merlin32 therefore prepends its CWD to any Windows absolute path, producing nonsense:

```
Impossible to open Source file
  'C:\Users\...\Temp\au3AxBZc\C:\checkout\...\nop_func.s'
```

This affects both `PUT` directives in assembly source and — if an absolute path were given for `ASM` in a link file — the source file itself.

The same behaviour would affect ORCA/M source files compiled through GoldenGate's `iix assemble`, for the same reason: GoldenGate's assembler front-end also uses ProDOS path semantics for directives it processes.

## Decision

Use carefully constructed relative or bare paths everywhere Merlin32 must resolve a filename.

### `DSK`: bare filename, resolved relative to the link file

The link file lives in `tmpDir`. Merlin32 resolves a bare `DSK` filename relative to the link file's own directory, so:

```
            DSK   aunitmob.aunit
```

produces `tmpDir/aunitmob.aunit` without Merlin32 ever inspecting the Windows path components of `tmpDir`. The stem is derived from the source basename, stripped of non-alphanumeric characters and capped at 8 characters, giving a total of 14 characters including `.aunit` — safely under the 15-character ProDOS limit.

The `mkdtemp` prefix was also changed from `'aunit-'` to `'au'` (no dash) so that if Merlin32 ever does see the temp-dir name it passes ProDOS validation.

### `PUT`: forward-slash relative path from the Merlin32 CWD

Merlin32 is invoked with `cwd = sourceDir` (the directory of the primary source file). For generated harnesses `sourceDir = tmpDir`. Include paths are computed as the relative path from `tmpDir` to the absolute include location, then converted to forward slashes:

```js
const putPath = (p) => relative(tmpDir, resolve(testDir, p)).replace(/\\/g, '/');
```

This produces paths like:

```asm
            put   ../../../../../../checkout/silky-gs-ref/aunit/lib/aunit.merlin.s
            put   ../../../../../../checkout/silky-gs-ref/aunit/test/merlin32/nop_func.s
```

Because these paths contain no drive-letter prefix, Merlin32 resolves them as genuine relative paths from its CWD and locates the correct files on disk. Forward slashes are used because Merlin32 accepts them as path separators, and they are less likely to be misinterpreted than backslashes in the ProDOS path layer.

For hand-written harnesses (via `runAssemblyTest`), `PUT` directives in the source file are already written as relative paths (e.g. `../../lib/aunit.merlin.s`) by the test author, so no transformation is needed.

## Consequences

**Good:**
- The DSK bare-filename approach is robust to any temp directory location — no path components are ever validated by Merlin32's ProDOS checker.
- The relative-path `PUT` approach works regardless of where the project is checked out, as long as the source files are on the same Windows drive as the temp directory (required for Node's `path.relative` to produce a drive-letter-free result).
- Hand-written Merlin32 harnesses continue to use conventional relative `PUT` paths unchanged.

**Constraints:**
- Source files and the OS temp directory must be on the same Windows drive for `path.relative` to produce a relative (not absolute) result. Cross-drive tests would need a different strategy (e.g. copying include files into `tmpDir`).
- The 8-character stem limit means generated OMF names lose most of their uniqueness signal, but collisions are not possible in practice because each test run uses its own `tmpDir`.
- The ORCA/M path (`_runGeneratedOrca`) is unaffected: `iix assemble` resolves `copy` paths through GoldenGate's Windows filesystem mapping, which does handle absolute Windows paths correctly in that context.
