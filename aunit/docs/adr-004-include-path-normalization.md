# ADR-004: Include Path Normalization for Generated Harnesses

**Date:** 2026-04-23  
**Status:** Accepted

## Context

`runGeneratedTest` and `cpu65816` accept an `includes` array — paths to the source files that define the function under test.  The caller may supply absolute or relative paths, and in practice absolute paths arrive in several distinct formats depending on how the test file constructs them.

The three formats observed in real test files:

### Format A — plain Windows absolute path

```js
const SRC = 'C:\\checkout\\silky-gs-ref\\src\\misc\\App.Msg.s';
```

This is what `path.resolve()` or `path.join()` with a conventional Windows root produces.  `path.resolve(testDir, SRC)` returns `SRC` unchanged.  No problem.

### Format B — URL `pathname` on Windows (leading forward slash)

```js
const SRC_ROOT = new URL('./src/', import.meta.url).pathname;
// → '/C:/checkout/silky-gs-ref/src/'
const SRC = path.join(SRC_ROOT, 'misc/App.Msg.s');
```

`URL.prototype.pathname` on Windows produces a POSIX-style absolute URL path: `/C:/checkout/silky-gs-ref/src/`.  The leading `/` is valid in a URL but is **not** a valid Windows absolute path prefix.

`path.join('/C:/checkout/.../src/', 'misc/App.Msg.s')` on Windows converts the forward slashes to backslashes and treats the leading `/` as a root separator, producing:

```
\C:\checkout\silky-gs-ref\src\misc\App.Msg.s
```

A backslash-prefixed path with no drive letter is a *drive-relative rooted path* in Windows — it means "root of the current drive" rather than drive `C:`.  When `path.resolve(testDir, p)` is called with such a path, Node.js prepends the drive letter of `testDir`, giving:

```
C:\C:\checkout\silky-gs-ref\src\misc\App.Msg.s
```

Merlin32 then computes the `put` path relative to `tmpDir` and emits:

```asm
            put   ../../../../../../C:/checkout/silky-gs-ref/src/misc/App.Msg.s
```

The `C:` directory component in the middle causes Merlin32's ProDOS path layer to fail — it sees `C:` as a plain subdirectory name rather than a drive letter, so it looks for a literal directory named `C:` that does not exist.

### Format C — `path.join` of format B (leading backslash, Windows)

Format B's URL pathname, after passing through `path.join` on Windows, loses the forward slashes and gains backslashes, but the malformed leading separator is preserved.  This is the same problem as format B but with a backslash instead of a forward slash as the first character.  Both arrive at the same broken resolution.

## The Problem

When an `includes` entry arrives as format B or C, `resolve(testDir, p)` silently produces a nonsense doubled-drive path (`C:\C:\...`).  `relative(tmpDir, that_path)` then generates a relative path that contains `C:` as a plain directory component in the middle — which Merlin32 cannot open.

The failure manifests as:

```
Impossible to open Source file
  'C:\Users\...\AppData\Local\Temp\auXXX\../../../../../../C:/checkout/.../App.Msg.s'.
```

## Decision

Normalize every element of `includes` through `_normAbsPath(testDir, p)` before any further path computation.

```js
function _normAbsPath(testDir, p) {
  const first = p.charCodeAt(0);
  if ((first === 47 || first === 92) && /^[A-Za-z]:/.test(p.slice(1))) p = p.slice(1);
  return resolve(testDir, p);
}
```

The logic: if the path begins with `/` (47) or `\` (92) and the next two characters are a drive letter followed by `:`, strip the leading separator.  This converts both format B (`/C:/...`) and format C (`\C:\...`) into a valid Windows absolute path with a drive letter prefix, which `path.resolve` then handles correctly.

### Why `charCodeAt()` with magic constants instead of a regex

The natural formulation would be a regex:

```js
if (/^[/\\][A-Za-z]:/.test(p)) p = p.slice(1);
```

This does not work reliably.  The character class `[/\\]` contains a bare `/` inside a regex literal.  In ECMAScript, `/` inside `[...]` is permitted without escaping, but both Node.js (v20) and common linters treat the first `/` as potentially ambiguous — the parser may see the `/` as the regex terminator and mis-tokenise the remainder as a division expression.  In practice the regex is silently miscompiled: `.toString()` reveals that `\\` inside the class is treated as `\[`, making the effective pattern match a literal `[A-Za-z]` sequence rather than a drive-letter character class.  The test returns `false` for every valid input.

Escaping the slash as `\/` (`/^[\/\\][A-Za-z]:/`) does not help — the same mis-tokenisation occurs on this Node.js version.  Constructing the regex with `new RegExp('^[/\\\\][A-Za-z]:')` avoids the literal-parsing ambiguity but requires four backslashes in the string source to produce two in the resulting regex, which is opaque to the reader and easy to get wrong.

Using `charCodeAt(0)` sidesteps the issue entirely:

- `47` is `/` (U+002F SOLIDUS)  
- `92` is `\` (U+005C REVERSE SOLIDUS)

The subsequent `/^[A-Za-z]:/` applied to `p.slice(1)` has no problematic characters inside its character class, so it compiles and runs correctly.

The constants are odd-looking but the surrounding comment anchors them.  They are not considered good style for new code; this is a pragmatic workaround for a specific Node.js regex-literal parsing behaviour.

### Potential future improvement

Once the ambiguity in the regex literal parser is understood more precisely — or if the project moves to a Node.js version or linter configuration where `[/\\]` inside a regex literal is handled correctly — the `charCodeAt` check can be replaced with the cleaner regex form.  Alternatively, the entire function body can be replaced with:

```js
function _normAbsPath(testDir, p) {
  // Handle URL.pathname format: fileURLToPath converts '/C:/...' → 'C:\...'
  if (/^\/[A-Za-z]:/.test(p)) p = fileURLToPath('file://' + p);
  return resolve(testDir, p);
}
```

`fileURLToPath` from `node:url` is the canonical API for converting URL pathnames to Windows paths and handles the drive-letter case correctly.  It was not used initially because it requires importing `fileURLToPath` (already available in the module) and the `file://` prefix construction adds noise, but it is semantically correct and avoids the `charCodeAt` constants.

The backslash-prefix case (format C) does not arise from `fileURLToPath` — it is produced by `path.join` consuming a format-B string — and can be handled by the simpler guard `if (p[0] === '\\' && /^[A-Za-z]:/.test(p.slice(1))) p = p.slice(1);` which has no regex-literal ambiguity because no `/` appears inside `[...]`.

## Consequences

**Good:**
- All three path formats resolve to a valid Windows absolute path before any `relative()` or `put` computation.
- No Merlin32 `put` directive ever contains a drive-letter component in the middle of a relative path.
- The normalizer is a pure function with no side effects; it is tested implicitly by the generated-harness tests.

**Constraints:**
- Source files and the OS temp directory must remain on the same Windows drive for `path.relative(tmpDir, absInclude)` to produce a drive-letter-free relative path.  Cross-drive includes would need a different strategy (copying files into `tmpDir` or using a shared base directory as CWD).
- The `charCodeAt` constants must be replaced if the project ever moves to a platform where character code 47 is not `/` or 92 is not `\` — though no such platform is anticipated for a Windows-native toolchain.
