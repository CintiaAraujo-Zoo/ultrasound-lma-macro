<div align="center">

# 🔬 Ultrasound LMA Macro

### Semi-automated morphometry workflow for Fiji/ImageJ

**Longissimus dorsi muscle area · Subcutaneous fat thickness · Muscle depth**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Fiji%20%2F%20ImageJ-brightgreen)](https://fiji.sc/)
[![Version](https://img.shields.io/badge/version-3.1.0-blue)](CHANGELOG.md)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)

</div>

---

A keyboard-driven Fiji/ImageJ macro for **semi-automated measurement of ultrasound B-mode images** in livestock research. Designed for high-throughput sessions with no fixed image naming requirement — adaptable to any experimental design.

Originally developed for *in vivo* sheep evaluation (UESPI / UNIVASF / UIUC), but fully applicable to cattle, goats, and other ruminants.

---

## ✨ Features

- **No naming convention required** — metadata entered via editable dialog at each session
- **Flexible scale calibration** — draw any reference line, enter length and unit (cm / mm / in)
- **LMA tracing** — polygon or freehand ROI with optional spline smoothing and ROI Manager integration
- **Subcutaneous fat** — three independent measurements with automatic mean
- **Muscle depth** — dorsal–ventral anatomical depth of *m. Longissimus dorsi*
- **Structured CSV output** — one file per group/session, auto-generated header, one row per image
- **Keyboard-only workflow** — F1 through F9, no menus needed during analysis
- **Guard rails** — blocks measurement steps if scale is not calibrated
- **Cross-platform** — Windows, macOS, and Linux

---

## 🖥️ Requirements

- [Fiji](https://fiji.sc/) (any recent release — ImageJ 1.x bundled)
- No additional plugins required

---

## ⚙️ Installation

**Session only**
1. Download [`LMA_Macro.ijm`](LMA_Macro.ijm)
2. In Fiji: **Plugins → Macros → Install…** → select the file

**Persistent (auto-loads with Fiji)**

Copy `LMA_Macro.ijm` to your Fiji `macros/` folder and restart Fiji:

| OS | Path |
|----|------|
| Windows | `C:\Fiji.app\macros\` |
| macOS | `/Applications/Fiji.app/macros/` |
| Linux | `~/Fiji.app/macros/` |

---

## 🔑 Keyboard Shortcuts

| Key | Step | Action |
|:---:|------|--------|
| **F1** | Init | Metadata dialog — Subject, Group, Replicate |
| **F2** | Set Scale | Draw reference line → enter known length and unit |
| **F3** | Measure LMA | Trace muscle ROI → area, perimeter, circularity |
| **F4** | Measure Fat | Three subcutaneous fat thickness measurements |
| **F5** | Measure Depth | Dorsal–ventral muscle depth |
| **F6** | Save | Append row to CSV, reset for next image |
| **F7** | Status | Inspect current session state |
| **F8** | Reset | Clear measurements (saved data untouched) |
| **F9** | Open Folder | Open CSV output folder |

---

## 📋 Workflow

```
Open image
    │
    ▼
F1 — Init
    Fill in Subject, Group, Replicate (auto-suggested from filename)
    │
    ▼
F2 — Set Scale
    Draw line over reference bar → enter known length and unit
    │
    ▼
F3 — Measure LMA
    Trace Longissimus dorsi contour → optional spline smoothing
    │
    ▼
F4 — Measure Fat  (×3)
    Draw perpendicular lines across subcutaneous fat layer
    │
    ▼
F5 — Measure Depth
    Draw line from dorsal to ventral muscle border
    │
    ▼
F6 — Save Results
    Row appended to CSV → open next image → F1
```

---

## 🗂️ Metadata and Output

### Flexible metadata (F1 dialog)

No filename pattern is enforced. Every session opens an editable dialog:

```
Subject / Animal ID         →  Animal_01  |  Sheep_15  |  Ewe07
Group / Session / Treatment →  Control    |  Session02  |  HighProtein
Replicate / Scan            →  1          |  Rep2
```

The **Group** field also names the output CSV:

| Group entered | Output file |
|--------------|-------------|
| `Session01` | `lma_Session01.csv` |
| `Control` | `lma_Control.csv` |
| *(blank)* | `lma_results.csv` |

### CSV structure

```
image_file, subject, group, replicate,
lma_area_cm2, lma_perimeter_cm, lma_circularity,
fat1_mm, fat2_mm, fat3_mm, fat_mean_mm, muscle_depth_mm
```

---

## ❓ FAQ

**Can I use this for cattle, goats, or other species?**  
Yes — the macro measures whatever you trace. Fill in Subject and Group to match your experimental design.

**What if a value in the CSV shows `-999999`?**  
That is the internal sentinel for "not measured." Delete that row and re-measure from F1.

**How do I reset the output folder?**  
Run in **Plugins → Macros → Evaluate…**:
```javascript
call("ij.Prefs.set", "lma.out_dir", "");
```

---

## 📖 Citation

If you use this macro in a publication or derivative work, please cite:

```bibtex
@software{araujo_lma_macro_2025,
  author    = {Araujo, Cintia},
  title     = {{Ultrasound LMA Macro for Fiji/ImageJ}},
  version   = {3.1.0},
  year      = {2025},
  publisher = {GitHub / Zenodo},
  url       = {https://github.com/CintiaAraujo-Zoo/ultrasound-lma-macro},
  doi       = {10.5281/zenodo.XXXXXXX}
}
```

**APA 7th:**
> Araujo, C. (2025). *Ultrasound LMA Macro for Fiji/ImageJ* (v3.1.0) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX

---

## 📄 License

MIT — see [LICENSE](LICENSE).

User-authored `.ijm` macros are not derived works of ImageJ/Fiji source code and may be distributed under any license of the author's choosing.

---

<div align="center">

*Developed at UESPI Campus Corrente · UNIVASF Graduate Program in Animal Science · University of Illinois Urbana-Champaign*

</div>
