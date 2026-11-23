# G-code fixtures

Read by `spec/models/gcode/summary_spec.rb`. Kept short: a header, the footer and a few dozen moves.

| File | From |
|---|---|
| `prusaslicer_single.gcode` | A real PrusaSlicer 2.9.6 file (MK3-style profile, PLA), cut down: start G-code with its two prime lines, part of layers 1 and 2, the end G-code, the footer and ten keys of the config block |
| `truncated.gcode` | `prusaslicer_single`, cut in layer 2: no end G-code, no footer |
| `prusaslicer_m600.gcode` | `prusaslicer_single` with PrusaSlicer's colour change in layer 2 (`;COLOR_CHANGE,T0,#E70000` then `M600`) and a second, bare `M600` at the end of layer 2 |
| `prusaslicer_unknown_material.gcode` | `prusaslicer_single` with `filament_type = PCTG`, no colour and 0 g (no density in the profile) |
| `prusaslicer_multi_tool.gcode` | `prusaslicer_single` with `T0`, a `T1` block, back to `T0`, and three-tool footer lists (the third tool unused) |
| `unknown_slicer.gcode` | `prusaslicer_single` with an OrcaSlicer first line: same keys, not read |
| `cura_single.gcode` | A real Cura 4.11.0 file (`spec/fixture_files/test.gcode`), cut down: header, start G-code, part of layers 0 and 1, the end G-code and the settings |
| `relative_extrusion.gcode` | Hand-written: `M83`, a `G91` block, `G92 E0`, retractions and travels |
| `binary.bgcode` | The first bytes of a binary G-code file |

The multi-tool, M600 and unknown-material files are edits of a real single-tool file: no real file of each was at
hand. Their keys and markers follow PrusaSlicer 2.9's output (`;COLOR_CHANGE,T<n>,<colour>` before
`color_change_gcode`, lists separated by `, ` for amounts and `;` for config values).
