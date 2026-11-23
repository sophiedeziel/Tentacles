; Hand-written: relative extrusion (M83), a G91 block and G92 E0. No slicer
G21 ; millimetres
G90 ; absolute positions
M83 ; relative extrusion
G28 ; home: the position is unknown until the next move
G1 Z0.2 F600
G1 X10 Y10 F3000 ; travel
G1 X50 Y10 E2.0 F1200 ; extrude
G1 E-0.8 F3600 ; retract
G1 X150 Y150 F9000 ; travel, not in the box
G1 X80 Y60 ; travel
G1 E0.8 F3600 ; unretract in place
G1 X80 Y30 E1.0 F1200 ; extrude
G91 ; relative positions (and extrusion)
G1 X-5 E0.4 ; to X75 Y30
G1 Z0.2 ; to Z0.4
G1 Y-20 E0.8 ; to X75 Y10, at Z0.4
G90 ; absolute positions, relative extrusion again
G92 E0
G1 X200 Y200 E-1 F9000 ; travel with a retraction, not in the box
G1 Z10 ; raise
M84
