# Merlin32 OMF Relocation Bug: `EXT_LABEL+CONSTANT` Drops the Addend at Runtime

## Summary

When a cross-file external symbol (`EXT`) is referenced with a constant offset —
e.g. `STA SomeExternalBuffer+4, X` — the Merlin32 assembler's **listing output
(`*_Output.txt`) shows the correct, fully-resolved address** (base + offset), but
the **OMF loader relocates the reference using only the bare `EXT` symbol's
address and silently drops the `+CONSTANT` addend**. The assembled operand bytes
in the listing are correct; the bug is in how the OMF loader patches that operand
at load time.

This was diagnosed live in a debugger (not from static analysis — the listings
are misleading here since they show the *intended* address, not the *actual*
runtime address) while tracking down a rendering bug in the Zelda port's status
screen. It is not specific to any one label; it is systemic to the
`EXT_LABEL+CONSTANT` addressing pattern itself.

## Symptom

Code that pokes a byte into the middle of an externally-defined data buffer
(a common pattern for patching palette bytes, level numbers, or transfer-buffer
tile IDs at runtime) silently writes to the *start* of that buffer instead of
the intended offset — corrupting whatever the first few bytes were used for
while leaving the "actual" target byte untouched. There's no assembler warning
or error; the `.txt` listing looks completely correct, which makes this bug
invisible to static review of the source or listings. It only shows up as a
runtime data-corruption symptom (e.g. garbled/blank tiles, wrong palette colors)
that requires single-stepping the actual running code to catch.

## The fix: give the target offset its own bare label

Do not rely on `EXT_LABEL+CONSTANT` arithmetic surviving relocation. Instead,
split the data definition so the exact byte you need to reference gets its own
`ENT`-exported label with zero offset, and `EXT`-import *that* label everywhere
it's used:

```asm
; Before (buggy under OMF relocation when TransferBuf is EXT elsewhere):
TransferBuf ENT
            db    $01, $02, $03, $04, $05

; some other bank/file:
    STA TransferBuf+3, X   ; <-- addend silently dropped at runtime

; After:
TransferBuf ENT
            db    $01, $02, $03
TransferBufByte3 ENT        ; = TransferBuf+3
            db    $04, $05

; some other bank/file:
    STA TransferBufByte3, X   ; bare EXT label, no arithmetic -- safe
```

This does not change the assembled byte layout (the split introduces no new
bytes, no padding, no reordering) — it only adds a second label pointing partway
into the same data.

## Fixed instances (2026-08, Zelda port)

Found by scanning every `EXT`-declared symbol across `src/games/zelda/src/rom_0*.s`
for uses of the form `LABEL+N` / `LABEL-N` in an operand, then checking whether
that label was actually `EXT` (cross-file) in the file where the offset was used
(same-file `ENT`-local references are not affected — the bug is specific to OMF
cross-file relocation, not local assembly).

| Original expression | Defined in | Used (with offset) in | New anchor label |
|---|---|---|---|
| `TriforceRow0TransferBuf+4` | `rom_06.s` | `rom_05.s` (×3) | `TriforceRow0Content` |
| `MenuPalettesTransferBuf+20` | `rom_06.s` | `rom_01.s`, `rom_02.s`, `rom_07_fixed.s` | `MenuPalettesByte20` |
| `MenuPalettesTransferBuf+32` | `rom_06.s` | `rom_02.s` | `MenuPalettesByte32` |
| `LevelPaletteRow7TransferBuf+3` | `rom_06.s` | `rom_07_fixed.s` | `LevelPaletteRow7Byte3` |
| `LevelNumberTransferBuf+9` | `rom_06.s` | `rom_05.s` | `LevelNumberByte9` |
| `SpriteOffsets+1` | `rom_01.s` | `rom_04.s` | `SpriteOffsetsByte1` |

The `TriforceRow0TransferBuf+4` case was the confirmed root cause of a rendering
bug where the Triforce graphic on the inventory/status screen rendered its apex
and base correctly but was missing the four interior rows of diagonal-edge
tiles — `UpdateMenuStartOW`'s "draw an empty Triforce" loop
(`rom_05.s`, indexing via `TriforceTransferBufOffsets`) was writing its
otherwise-correct tile data to `TriforceRow0TransferBuf` (offset 0) instead of
`TriforceRow0TransferBuf+4`, corrupting the header/PPU-address bytes of
`TriforceRow1/2/3TransferBuf` (which are laid out contiguously right after
`TriforceRow0TransferBuf` in ROM) every time the inventory screen opened.

`SpriteOffsets+1, Y` also appears twice in `rom_01.s` itself, where
`SpriteOffsets` is defined locally via `ENT` (not `EXT`) — those two sites are
same-file/same-bank references and are **not** affected by this bug, so they
were left as-is.

## Checking for more instances

To re-scan for this pattern (e.g. after adding new cross-bank data references),
look for any `EXT`-declared symbol used with a `+` or `-` constant offset in a
*different* file than the one that `ENT`-defines it:

```bash
# 1. Collect every symbol declared EXT anywhere in the bank files
grep -h -E '^[A-Za-z_][A-Za-z0-9_]*[[:space:]]+EXT[[:space:]]*$' rom_0*.s \
  | awk '{print $1}' | sort -u > ext_names.txt

# 2. For each name, search for "NAME+N" / "NAME-N" across all bank files
while read -r name; do
  grep -n -E "\\b${name}[+-](\\\$[0-9A-Fa-f]+|[0-9]+)\\b" rom_0*.s
done < ext_names.txt
```

Then manually confirm, for each hit, that the symbol is genuinely declared `EXT`
(not locally `ENT`) in the file where the offset is used — only those are at risk.
