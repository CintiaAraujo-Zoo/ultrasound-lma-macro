// ============================================================
//  Ultrasound Morphometry Macro for Fiji/ImageJ
//  Longissimus dorsi muscle area (LMA), subcutaneous fat
//  thickness, and muscle depth — semi-automated workflow
//
//  Version  : 3.1.0
//  Author   : Cintia Araujo (Kaoru) — UESPI / UNIVASF / UIUC
//  License  : MIT  (see LICENSE)
//  Repository: https://github.com/YOUR_USERNAME/ultrasound-lma-macro
//
//  Compatible with Fiji / ImageJ 1.x — no extra plugins required.
//
//  ── Image naming ─────────────────────────────────────────────
//  No fixed pattern required. Any filename is accepted.
//  At Init (F1) a dialog allows you to confirm or freely edit
//  the three identifier fields (Subject, Group, Replicate).
//  Auto-detection is attempted for common patterns:
//    A#S#_#   A#C#_#   ID#_Group#_Rep#   and similar structures.
//
//  ── Keyboard shortcuts ───────────────────────────────────────
//  F1  Init            Open metadata dialog · reset session
//  F2  Set Scale       Calibrate from a drawn 1-cm reference line
//  F3  Measure LMA     Trace muscle ROI → area, perimeter, circularity
//  F4  Measure Fat     Three subcutaneous fat thickness measurements
//  F5  Measure Depth   Dorsal–ventral muscle depth measurement
//  F6  Save Results    Append row to CSV · reset for next image
//  F7  Status          Inspect current session state
//  F8  Reset           Clear measurements (saved CSVs untouched)
//  F9  Open Folder     Open CSV output folder in file manager
//
//  ── Output ───────────────────────────────────────────────────
//  One CSV per unique Group value: lma_<group>.csv
//  CSV columns:
//    image_file, subject, group, replicate,
//    lma_area_cm2, lma_perimeter_cm, lma_circularity,
//    fat1_mm, fat2_mm, fat3_mm, fat_mean_mm, muscle_depth_mm
// ============================================================

var VERSION = "3.1.0";

// ── Sentinel for "not yet measured" ──────────────────────────
var MISSING = -999999;

// ── Persistent preference keys ───────────────────────────────
var K_OUT_DIR  = "lma.out_dir";
var K_IMAGE    = "lma.image_title";
var K_SUBJECT  = "lma.subject";      // free-text: animal ID, sample ID, etc.
var K_GROUP    = "lma.group";        // free-text: session, treatment, collection, etc.
var K_REP      = "lma.replicate";    // free-text: replicate, scan number, etc.
var K_SCALED   = "lma.scale_set";
var K_LMA_AREA = "lma.area_cm2";
var K_LMA_PER  = "lma.perimeter_cm";
var K_LMA_CIRC = "lma.circularity";
var K_FAT1     = "lma.fat1_mm";
var K_FAT2     = "lma.fat2_mm";
var K_FAT3     = "lma.fat3_mm";
var K_FATM     = "lma.fat_mean_mm";
var K_DEPTH    = "lma.depth_mm";
var K_CSV_PATH = "lma.csv_path";   // computed and stored by buildCsvPath()
var K_UNIT     = "lma.scale_unit";  // stored at F2, used in all display dialogs

var DIV = "\n────────────────────\n";

// ============================================================
//  PREFS HELPERS
// ============================================================
function prefsSetS(key, val)  { call("ij.Prefs.set", key, val); }
function prefsGetS(key, def)  { return call("ij.Prefs.get", key, def); }
function prefsSetN(key, val)  { call("ij.Prefs.set", key, toString(val)); }
function prefsGetN(key, def)  { return parseFloat(call("ij.Prefs.get", key, toString(def))); }

// ============================================================
//  GENERAL HELPERS
// ============================================================

function ensureImageOpen() {
    if (nImages == 0) {
        showMessage("No Image Open",
            "Please open an image before running this command.");
        exit("No image open.");
    }
}

function tickStatus(v, unit) {
    if (isMissing(v)) return "pending";
    return d2s(v, 3) + " " + unit;
}

function isMissing(v) {
    return (v == MISSING || isNaN(v));
}

function resetSession() {
    prefsSetS(K_IMAGE,    "");
    prefsSetS(K_SUBJECT,  "");
    prefsSetS(K_GROUP,    "");
    prefsSetS(K_REP,      "");
    prefsSetN(K_SCALED,   0);
    prefsSetS(K_UNIT,     "cm");
    prefsSetN(K_LMA_AREA, MISSING);
    prefsSetN(K_LMA_PER,  MISSING);
    prefsSetN(K_LMA_CIRC, MISSING);
    prefsSetN(K_FAT1,     MISSING);
    prefsSetN(K_FAT2,     MISSING);
    prefsSetN(K_FAT3,     MISSING);
    prefsSetN(K_FATM,     MISSING);
    prefsSetN(K_DEPTH,    MISSING);
}

function configureMeasurements() {
    run("Set Measurements...", "area perimeter shape length redirect=None decimal=4");
}

function stripExtension(name) {
    var lower = toLowerCase(name);
    var exts  = newArray(".jpg", ".jpeg", ".png", ".tif", ".tiff", ".bmp", ".gif");
    for (var e = 0; e < exts.length; e++) {
        if (endsWith(lower, exts[e])) {
            name = substring(name, 0, lengthOf(name) - lengthOf(exts[e]));
            break;
        }
    }
    return name;
}

// ── Auto-detection heuristics ────────────────────────────────
// Tries several common filename patterns and returns an array
// [subject, group, replicate].  Returns ["","",""] on failure.
// The user always sees and can edit these values in the dialog.
// ─────────────────────────────────────────────────────────────
function guessMetadata(base) {
    var subject = "";
    var group   = "";
    var rep     = "";

    // Pattern 1: A#S#_#  or  A#C#_#  (e.g. A1S2_1, A12C3_2)
    //   Subject = number after A
    //   Group   = letter + number after it (S2, C3, T1 …)
    //   Rep     = number after _
    if (indexOf(base, "A") == 0 && indexOf(base, "_") > 0) {
        var posFirst  = 1;  // after leading A
        var posLetter = -1;
        var posUnder  = indexOf(base, "_");

        // Find the first letter after the animal digits
        for (var i = posFirst; i < posUnder; i++) {
            var c = substring(base, i, i+1);
            if (c >= "A" && c <= "Z" || c >= "a" && c <= "z") {
                posLetter = i;
                break;
            }
        }

        if (posLetter > posFirst) {
            subject = substring(base, posFirst, posLetter);  // digits only
            group   = substring(base, posLetter, posUnder);  // e.g. S2, C3
            rep     = substring(base, posUnder + 1);
        }
    }

    // Pattern 2: three tokens separated by underscores: tok1_tok2_tok3
    //   e.g. Animal01_Control_1, Sample5_T2_Rep2
    if (subject == "" && rep == "") {
        var parts = split(base, "_");
        if (parts.length >= 3) {
            subject = parts[0];
            group   = parts[1];
            rep     = parts[2];
        } else if (parts.length == 2) {
            subject = parts[0];
            rep     = parts[1];
        }
    }

    return newArray(subject, group, rep);
}

// Sanitize a string for use in a filename (replace spaces/special chars)
function sanitizeForFilename(s) {
    s = replace(s, " ",  "_");
    s = replace(s, "/",  "-");
    s = replace(s, "\\", "-");
    s = replace(s, ":",  "-");
    s = replace(s, "*",  "");
    s = replace(s, "?",  "");
    s = replace(s, "\"", "");
    s = replace(s, "<",  "");
    s = replace(s, ">",  "");
    s = replace(s, "|",  "-");
    return s;
}

// Builds the CSV file path and stores it in K_CSV_PATH pref.
// Avoids returning strings from functions (not reliable in ImageJ macro language).
function buildCsvPath() {
    var dir = prefsGetS(K_OUT_DIR, "");
    if (dir == "") {
        dir = getDirectory("Select output folder for CSV files");
        if (dir == "") exit("No output folder selected. Aborted.");
        prefsSetS(K_OUT_DIR, dir);
    }
    var grp = prefsGetS(K_GROUP, "");
    var tag = "results";
    if (grp != "") tag = sanitizeForFilename(grp);
    prefsSetS(K_CSV_PATH, dir + "lma_" + tag + ".csv");
}

// Builds and writes header + data row directly — avoids string-returning functions.
function appendToCsv() {
    buildCsvPath();
    var path = prefsGetS(K_CSV_PATH, "");

    if (!File.exists(path)) {
        var header = "image_file,subject,group,replicate,";
        header = header + "lma_area_cm2,lma_perimeter_cm,lma_circularity,";
        header = header + "fat1_mm,fat2_mm,fat3_mm,fat_mean_mm,muscle_depth_mm\n";
        File.append(header, path);
    }

    var img  = prefsGetS(K_IMAGE,    getTitle());
    var sub  = prefsGetS(K_SUBJECT,  "");
    var grp  = prefsGetS(K_GROUP,    "");
    var rep  = prefsGetS(K_REP,      "");
    var area = prefsGetN(K_LMA_AREA, MISSING);
    var per  = prefsGetN(K_LMA_PER,  MISSING);
    var circ = prefsGetN(K_LMA_CIRC, MISSING);
    var f1   = prefsGetN(K_FAT1,     MISSING);
    var f2   = prefsGetN(K_FAT2,     MISSING);
    var f3   = prefsGetN(K_FAT3,     MISSING);
    var fm   = prefsGetN(K_FATM,     MISSING);
    var dep  = prefsGetN(K_DEPTH,    MISSING);

    var row = img  + "," + sub  + "," + grp  + "," + rep  + ",";
    row = row + area + "," + per + "," + circ + ",";
    row = row + f1 + "," + f2 + "," + f3 + "," + fm + "," + dep + "\n";
    File.append(row, path);
}

function openFolder(path) {
    var os = toLowerCase(getInfo("os.name"));
    if      (startsWith(os, "windows")) exec("explorer", replace(path, "/", "\\"));
    else if (startsWith(os, "mac"))     exec("open", path);
    else                                exec("xdg-open", path);
}

function requireScale() {
    if (prefsGetN(K_SCALED, 0) != 1) {
        showMessage("Scale Not Calibrated",
            "You must calibrate the image scale before measuring.\n\n" +
            "  1. Draw a line over the known-length reference bar\n" +
            "  2. Press F2 to set the scale\n" +
            "  3. Then proceed with F3, F4, or F5");
        exit("Scale not calibrated.");
    }
}

// ============================================================
//  MAIN WORKFLOW MACROS
// ============================================================

// ── F1  INIT ─────────────────────────────────────────────────
macro "Init [f1]" {
    ensureImageOpen();
    configureMeasurements();
    resetSession();

    var title = getTitle();
    var base  = stripExtension(title);

    // Try to pre-fill fields from filename — user always edits
    var guess   = guessMetadata(base);
    var subject = guess[0];
    var group   = guess[1];
    var rep     = guess[2];

    // ── Editable metadata dialog ──────────────────────────────
    Dialog.create("Image Metadata  —  LMA Macro v" + VERSION);
    Dialog.addMessage(
        "File: " + title + "\n" +
        "Review and edit the fields below.\n" +
        "Any text is accepted — no fixed naming pattern required.");
    Dialog.addString("Subject / Animal ID", subject, 20);
    Dialog.addString("Group / Session / Treatment", group, 20);
    Dialog.addString("Replicate / Scan", rep, 10);
    Dialog.addMessage(
        "These values will be written to the CSV output.\n" +
        "The Group field is also used to name the output file:\n" +
        "  lma_<group>.csv  (or  lma_results.csv  if left blank)");
    Dialog.show();

    subject = Dialog.getString();
    group   = Dialog.getString();
    rep     = Dialog.getString();

    prefsSetS(K_IMAGE,   title);
    prefsSetS(K_SUBJECT, subject);
    prefsSetS(K_GROUP,   group);
    prefsSetS(K_REP,     rep);

    var csvTag = "results";
    if (group != "") csvTag = sanitizeForFilename(group);
    showMessage("Session Initialized  —  v" + VERSION,
        "File      : " + title + DIV +
        "Subject   : " + subject +
        "\nGroup     : " + group +
        "\nReplicate : " + rep + DIV +
        "Output CSV: lma_" + csvTag + ".csv" +
        DIV +
        "NEXT STEP :\n" +
        "Draw a line over the scale bar → F2");
}

// ── F2  SET SCALE ─────────────────────────────────────────────
macro "Set Scale [f2]" {
    ensureImageOpen();
    getLine(x1, y1, x2, y2, lw);

    if (x1 == -1) {
        showMessage("No Line Detected",
            "Use the Straight Line tool  (shortcut: \\)\n" +
            "Draw it over a reference of known length on the image\n" +
            "(e.g. the 1-cm scale bar), then press F2 again.\n\n" +
            "You will enter the known length in the next step.");
        exit("No line selection.");
    }

    var px = sqrt((x2-x1)*(x2-x1) + (y2-y1)*(y2-y1));

    // Ask for the known length so users are not locked to 1 cm
    Dialog.create("Set Image Scale");
    Dialog.addMessage("Line length: " + d2s(px, 1) + " pixels\n" +
        "Enter the real-world length this line represents:");
    Dialog.addNumber("Known length", 1);
    Dialog.addChoice("Unit", newArray("cm", "mm", "in"), "cm");
    Dialog.show();

    var known = Dialog.getNumber();
    var unit  = Dialog.getChoice();

    run("Set Scale...", "distance=" + px + " known=" + known + " unit=" + unit);
    prefsSetS(K_UNIT, unit);
    prefsSetN(K_SCALED, 1);

    showMessage("Scale Calibrated",
        d2s(px, 2) + " px  =  " + known + " " + unit + DIV +
        "NEXT STEP :\n" +
        "Trace the muscle contour → F3");
}

// ── F3  MEASURE LMA ───────────────────────────────────────────
macro "Measure LMA [f3]" {
    ensureImageOpen();
    requireScale();

    if (selectionType() == -1) {
        showMessage("No ROI Selected",
            "Recommended tool: Polygon Selection\n\n" +
            "  • Click point-by-point along the muscle border\n" +
            "  • Backspace     → remove last point\n" +
            "  • Double-click  → close contour\n" +
            "  • Alt + click   → adjust existing points\n\n" +
            "Freehand and brush selections are also accepted.\n\n" +
            "After tracing, press F3 to measure.");
        exit("No ROI selection.");
    }

    if (getBoolean(
            "Apply spline smoothing to the contour?\n\n" +
            "Recommended to reduce hand-tracing irregularities\n" +
            "and improve area reproducibility.")) {
        run("Fit Spline");
    }

    if (getBoolean(
            "Add ROI to ROI Manager?\n\n" +
            "Allows you to review, overlay, or export\n" +
            "the traced contour later.")) {
        roiManager("Add");
        var idx = roiManager("count") - 1;
        roiManager("select", idx);
        roiManager("rename", prefsGetS(K_IMAGE, getTitle()) + "_LMA");
    }

    run("Measure");
    var n = nResults;
    if (n < 1) {
        showMessage("Measurement Error",
            "No results were returned.\n" +
            "Verify that the scale has been calibrated (F2).");
        exit("No results from Measure.");
    }

    var area = getResult("Area",   n - 1);
    var per  = getResult("Perim.", n - 1);
    var circ = getResult("Circ.",  n - 1);
    prefsSetN(K_LMA_AREA, area);
    prefsSetN(K_LMA_PER,  per);
    prefsSetN(K_LMA_CIRC, circ);
    run("Clear Results");

    var unit2 = prefsGetS(K_UNIT, "cm");
    showMessage("LMA Measured",
        "Area        : " + d2s(area, 4) + " " + unit2 + "²" +
        "\nPerimeter   : " + d2s(per,  4) + " " + unit2 +
        "\nCircularity : " + d2s(circ, 4) + DIV +
        "Happy with the tracing?\n" +
        "  ✓  Yes → proceed to F4\n" +
        "  ✗  No  → press F8 to reset, re-trace, then F3\n" + DIV +
        "NEXT STEP :\n" +
        "Measure subcutaneous fat (3×) → F4");
}

// ── F4  MEASURE FAT ───────────────────────────────────────────
macro "Measure Fat [f4]" {
    ensureImageOpen();
    requireScale();

    prefsSetN(K_FAT1, MISSING);
    prefsSetN(K_FAT2, MISSING);
    prefsSetN(K_FAT3, MISSING);
    prefsSetN(K_FATM, MISSING);

    var fat = newArray(3);

    for (var i = 1; i <= 3; i++) {
        waitForUser("Subcutaneous Fat — Measurement " + i + " / 3",
            "Tool: Straight Line  (shortcut: \\)\n\n" +
            "Draw a line perpendicular to the skin surface,\n" +
            "spanning the full thickness of the subcutaneous\n" +
            "fat layer above the Longissimus dorsi muscle.\n\n" +
            "Click OK when the line is in place.");

        getLine(x1, y1, x2, y2, lw);
        if (x1 == -1) {
            showMessage("No Line — Fat " + i,
                "No line was detected.\n" +
                "Draw a line with the Straight Line tool and click OK.");
            exit("No line for fat measurement " + i + ".");
        }

        run("Measure");
        var n = nResults;
        if (n < 1) {
            showMessage("Measurement Error — Fat " + i,
                "No result returned.\n" +
                "Verify that the scale has been calibrated (F2).");
            exit("No result for fat " + i + ".");
        }

        fat[i - 1] = getResult("Length", n - 1);
        run("Clear Results");
    }

    prefsSetN(K_FAT1, fat[0]);
    prefsSetN(K_FAT2, fat[1]);
    prefsSetN(K_FAT3, fat[2]);
    var mean = (fat[0] + fat[1] + fat[2]) / 3.0;
    prefsSetN(K_FATM, mean);

    var unit = prefsGetS(K_UNIT, "cm");
    showMessage("Fat Thickness Measured",
        "Fat 1  : " + d2s(fat[0], 3) + " " + unit +
        "\nFat 2  : " + d2s(fat[1], 3) + " " + unit +
        "\nFat 3  : " + d2s(fat[2], 3) + " " + unit + DIV +
        "Mean   : " + d2s(mean, 3) + " " + unit + DIV +
        "NEXT STEP :\n" +
        "Measure muscle depth → F5");
}

// ── F5  MEASURE DEPTH ─────────────────────────────────────────
macro "Measure Depth [f5]" {
    ensureImageOpen();
    requireScale();

    waitForUser("Muscle Depth Measurement",
        "Tool: Straight Line  (shortcut: \\)\n\n" +
        "Draw a line from the DORSAL border to the\n" +
        "VENTRAL border of the Longissimus dorsi muscle,\n" +
        "following the anatomical depth axis.\n\n" +
        "Click OK when the line is in place.");

    getLine(x1, y1, x2, y2, lw);
    if (x1 == -1) {
        showMessage("No Line Detected",
            "Draw the depth line (dorsal to ventral border)\n" +
            "then press F5 again.");
        exit("No line selection.");
    }

    run("Measure");
    var n = nResults;
    if (n < 1) {
        showMessage("Measurement Error",
            "No result returned.\n" +
            "Verify that the scale has been calibrated (F2).");
        exit("No result for depth.");
    }

    var dep = getResult("Length", n - 1);
    prefsSetN(K_DEPTH, dep);
    run("Clear Results");

    var unit = prefsGetS(K_UNIT, "cm");
    showMessage("Muscle Depth Measured",
        "Muscle depth : " + d2s(dep, 3) + " " + unit + DIV +
        "NEXT STEP :\n" +
        "Save results → F6");
}

// ── F6  SAVE RESULTS ──────────────────────────────────────────
macro "Save Results [f6]" {
    ensureImageOpen();

    var area = prefsGetN(K_LMA_AREA, MISSING);
    var per  = prefsGetN(K_LMA_PER,  MISSING);
    var circ = prefsGetN(K_LMA_CIRC, MISSING);
    var fm   = prefsGetN(K_FATM,     MISSING);
    var dep  = prefsGetN(K_DEPTH,    MISSING);

    if (isMissing(area) || isMissing(per) || isMissing(circ)) {
        showMessage("LMA Not Measured",
            "Measure the Longissimus dorsi area first → F3");
        exit("LMA not measured.");
    }
    if (isMissing(fm)) {
        showMessage("Fat Thickness Not Measured",
            "Measure subcutaneous fat thickness first → F4");
        exit("Fat not measured.");
    }
    if (isMissing(dep)) {
        showMessage("Muscle Depth Not Measured",
            "Measure muscle depth first → F5");
        exit("Depth not measured.");
    }

    appendToCsv();

    var path = prefsGetS(K_CSV_PATH, "");
    var img  = prefsGetS(K_IMAGE,   getTitle());
    var sub  = prefsGetS(K_SUBJECT, "");
    var grp  = prefsGetS(K_GROUP,   "");
    var rep  = prefsGetS(K_REP,     "");
    var unit = prefsGetS(K_UNIT, "cm");

    showMessage("Results Saved  ✓",
        "File      : " + path + DIV +
        "Image     : " + img +
        "\nSubject   : " + sub +
        "\nGroup     : " + grp +
        "\nReplicate : " + rep + DIV +
        "LMA area  : " + d2s(area, 3) + " " + unit + "²" +
        "\nFat mean  : " + d2s(fm,   3) + " " + unit +
        "\nDepth     : " + d2s(dep,  3) + " " + unit + DIV +
        "Open the next image and press F1.");

    resetSession();
}

// ============================================================
//  UTILITY MACROS
// ============================================================

// ── F7  STATUS ────────────────────────────────────────────────
macro "Status [f7]" {
    ensureImageOpen();

    var sub    = prefsGetS(K_SUBJECT, "");
    var grp    = prefsGetS(K_GROUP,   "");
    var rep    = prefsGetS(K_REP,     "");
    var scaled = prefsGetN(K_SCALED,  0);
    var area   = prefsGetN(K_LMA_AREA, MISSING);
    var fm     = prefsGetN(K_FATM,     MISSING);
    var dep    = prefsGetN(K_DEPTH,    MISSING);
    var unit   = prefsGetS(K_UNIT, "cm");

    var st_sub = "(not set)";
    if (sub != "") st_sub = sub;
    var st_grp = "(not set)";
    if (grp != "") st_grp = grp;
    var st_rep = "(not set)";
    if (rep != "") st_rep = rep;
    var st_scale = "not calibrated (F2)";
    if (scaled == 1) st_scale = "calibrated";
    var st_area  = tickStatus(area, unit + "2");
    var st_fat   = tickStatus(fm,   unit);
    var st_dep   = tickStatus(dep,  unit);

    showMessage("Session Status  —  v" + VERSION,
        "Image     : " + getTitle() + DIV +
        "Subject   : " + st_sub +
        "\nGroup     : " + st_grp +
        "\nReplicate : " + st_rep + DIV +
        "Scale     : " + st_scale +
        "\nLMA area  : " + st_area +
        "\nFat mean  : " + st_fat +
        "\nDepth     : " + st_dep);
}

// ── F8  RESET ─────────────────────────────────────────────────
macro "Reset [f8]" {
    if (getBoolean(
            "Clear all measurements for the current image?\n\n" +
            "This does NOT affect any previously saved CSV rows.")) {
        resetSession();
        showMessage("Session Reset",
            "All measurements cleared.\n\n" +
            "Press F1 to start a new image.");
    }
}

// ── F9  OPEN OUTPUT FOLDER ────────────────────────────────────
macro "Open Output Folder [f9]" {
    var out = prefsGetS(K_OUT_DIR, "");
    if (out == "") {
        showMessage("Output Folder Not Set",
            "No output folder has been selected yet.\n" +
            "It will be requested automatically on your first save (F6).");
    } else {
        openFolder(out);
    }
}
