# Changelog

All notable changes to this project are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [3.1.0] — 2025-04-30

### Changed — Major redesign: flexible metadata

- **Removed mandatory filename pattern.**  
  Any filename is now accepted. No naming convention is enforced.

- **Init (F1) opens an editable metadata dialog** with three free-text fields:
  `Subject / Animal ID`, `Group / Session / Treatment`, and `Replicate / Scan`.  
  Fields are pre-filled via heuristic auto-detection when the filename matches
  common patterns (`A#C#_#`, `A#S#_#`, `tok1_tok2_tok3`, etc.) — always editable.

- **Scale dialog (F2) accepts any known length and unit** (cm / mm / in).

- **CSV output filename derived from the Group field**: `lma_<group>.csv`.  
  Falls back to `lma_results.csv` if Group is left blank.

- **CSV column names updated**: `animal → subject`, `session → group`.  
  `lma_*` prefix replaces `aol_*`.

### Fixed — ImageJ macro language compatibility

- **Ternary operators (`? :`) removed throughout.**  
  ImageJ macro language does not support ternary operators in any context.  
  All replaced with `if / else` blocks.

- **Nested function definitions inside macros removed.**  
  `tick()` was defined inside the `Status` macro — not supported.  
  Moved to top-level as `tickStatus()`.

- **String-returning user functions replaced with Prefs-based procedures.**  
  ImageJ macro language cannot reliably return strings from user functions
  that involve concatenation with other function calls.  
  `getCsvPath()` and `getOrChooseOutDir()` replaced by `buildCsvPath()`,
  which stores the result in `K_CSV_PATH` pref; callers read from Prefs directly.

- **Scale flag changed from string to numeric.**  
  String comparison `prefsGetS(K_SCALED) != "true"` fails at runtime;
  replaced with numeric `prefsGetN(K_SCALED, 0) != 1`.

- **Unit display fixed.**  
  `getInfo("micrometer.abbreviation")` always returns `"µm"` regardless of scale.  
  Fixed by storing the chosen unit in `K_UNIT` pref at F2, and reading it in all
  display dialogs (F3, F4, F5, F6, F7).

### Added

- `guessMetadata()` — heuristic auto-detection of Subject / Group / Replicate from filename.
- `sanitizeForFilename()` — cleans Group field for safe use in CSV filename.
- `K_UNIT` pref key — persists the scale unit across the session.
- `buildCsvPath()` — Prefs-safe procedure replacing `getCsvPath()`.
- `tickStatus()` — top-level helper for Status dialog display.

---

## [3.0.0] — 2025-04-30

### Fixed — Critical bugs from original version

- **Fat (F4) and depth (F5) measurements silently returned 0.**  
  `getResult("Length", n-1)` requires `"length"` in the `Set Measurements` call —  
  it was missing. Added to `configureMeasurements()`.

- **`Open Output Folder` (F9) crashed on Windows and macOS.**  
  Hard-coded `xdg-open` is Linux-only.  
  Fixed with OS detection via `getInfo("os.name")`.

- **`csvLine()` could record the wrong image filename.**  
  `getTitle()` was called at save time (F6); fixed by storing it in Prefs at Init (F1).

### Added

- Scale guard (`requireScale()`) in F3, F4, and F5.
- Confirmation dialog in Reset (F8).
- ROI Manager integration in F3 (optional).
- `waitForUser` prompt in F5 for consistent UX with F4.
- `VERSION` constant displayed in dialogs.

### Changed

- All dialog text translated to English with scientific terminology.
- Macro renamed from `AOL_Macro.ijm` to `LMA_Macro.ijm`.

---

## [2.0.0] — 2025 (original Portuguese version, `AOL_Macro.ijm`)

### Added
- Full F1–F9 keyboard-driven workflow.
- LMA area, perimeter, circularity via polygon ROI.
- Subcutaneous fat thickness — three measurements + mean.
- Muscle anatomical depth measurement.
- Per-collection CSV output with automatic header creation.
- Session state persistence via `ij.Prefs`.
- Optional spline smoothing for muscle contour.
- Status display (F7).
