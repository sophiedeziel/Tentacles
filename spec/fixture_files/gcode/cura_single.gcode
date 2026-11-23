;FLAVOR:Marlin
;TIME:4271
;Filament used: 0.797727m
;Layer height: 0.12
;MINX:119.5
;MINY:39.5
;MINZ:0.12
;MAXX:180.5
;MAXY:260.5
;MAXZ:0.36
;Generated with Cura_SteamEngine 4.11.0
M140 S50
M105
M190 S50
M104 S200
M105
M109 S200
M82 ;absolute extrusion mode
M201 X500.00 Y500.00 Z100.00 E5000.00 ;Setup machine max acceleration
M203 X500.00 Y500.00 Z10.00 E50.00 ;Setup machine max feedrate
M204 P500.00 R1000.00 T500.00 ;Setup Print/Retract/Travel acceleration
M205 X8.00 Y8.00 Z0.40 E5.00 ;Setup Jerk
M220 S100 ;Reset Feedrate
M221 S100 ;Reset Flowrate

G28 ;Home

G92 E0 ;Reset Extruder
G1 Z2.0 F3000 ;Move Z Axis up
G1 X10.1 Y20 Z0.28 F5000.0 ;Move to start position
G1 X10.1 Y200.0 Z0.28 F1500.0 E15 ;Draw the first line
G1 X10.4 Y200.0 Z0.28 F5000.0 ;Move to side a little
G1 X10.4 Y20 Z0.28 F1500.0 E30 ;Draw the second line
G92 E0 ;Reset Extruder
G1 Z2.0 F3000 ;Move Z Axis up

G92 E0
G92 E0
G1 F1800 E-5
;LAYER_COUNT:3
;LAYER:0
M107
G0 F6000 X120.192 Y46.284 Z0.12
;TYPE:SKIRT
G1 F1800 E0
G1 F1200 X120.554 Y45.442 E0.0096
G1 X120.989 Y44.635 E0.01921
G1 X121.491 Y43.869 E0.0288
G1 X122.059 Y43.15 E0.0384
G1 X122.687 Y42.483 E0.048
G1 X123.371 Y41.873 E0.0576
G1 X124.106 Y41.325 E0.06721
G1 X124.886 Y40.844 E0.07681
G1 X125.704 Y40.432 E0.0864
G1 X126.555 Y40.093 E0.096
G1 X127.433 Y39.83 E0.1056
G1 X128.33 Y39.644 E0.1152
G1 X129.24 Y39.537 E0.1248
G1 X129.715 Y39.513 E0.12978
G1 X130.036 Y39.504 E0.13315
G1 X130.33 Y39.5 E0.13623
G1 X169.293 Y39.5 E0.54444
G1 X170.141 Y39.511 E0.55333
G1 X171.056 Y39.564 E0.56293
G1 X171.963 Y39.697 E0.57253
G1 X172.854 Y39.908 E0.58213
G1 X173.724 Y40.196 E0.59173
G1 X174.566 Y40.559 E0.60134
G1 X175.372 Y40.994 E0.61093
G1 X176.138 Y41.497 E0.62053
G1 X176.857 Y42.066 E0.63014
G1 X177.523 Y42.694 E0.63973
G1 X178.132 Y43.379 E0.64933
G1 X178.679 Y44.114 E0.65893
G1 X179.16 Y44.894 E0.66853
G1 X179.571 Y45.713 E0.67813
G1 X179.91 Y46.564 E0.68773
G1 X180.172 Y47.442 E0.69733
G1 X180.357 Y48.34 E0.70694
G1 X180.463 Y49.25 E0.71653
;LAYER:1
M106 S85
;TYPE:WALL-INNER
;MESH:Checklist maker whiteboard v1.stl
G1 F1350 X166.7 Y66.7 E277.44669
G1 X166.7 Y53.3 E277.58708
G1 X153.3 Y53.3 E277.72747
G1 X153.3 Y66.7 E277.86787
G0 F7500 X153.5 Y66.5
G1 F1350 X166.5 Y66.5 E278.00407
G1 X166.5 Y53.5 E278.14027
G1 X153.5 Y53.5 E278.27647
G1 X153.5 Y66.5 E278.41267
G0 F7500 X153.7 Y66.3
G1 F1350 X166.3 Y66.3 E278.54468
G1 X166.3 Y53.7 E278.67669
G1 X153.7 Y53.7 E278.80869
G1 X153.7 Y66.3 E278.9407
G0 F7500 X153.9 Y66.1
;TYPE:WALL-OUTER
G1 F1350 X166.1 Y66.1 E279.06852
G1 X166.1 Y53.9 E279.19634
G1 X153.9 Y53.9 E279.32416
G1 X153.9 Y66.1 E279.45198
G1 F1800 E274.45198
G0 F7500 X153.7 Y66.1
G0 X153.23 Y65.273
G0 X154.665 Y65.273
G0 X142.11 Y64.9
G0 X142.682 Y66.218
;TIME_ELAPSED:4271.772062
G1 F1800 E792.72729
M140 S0
M107
G91 ;Relative positioning
G1 E-2 F2700 ;Retract a bit
G1 E-2 Z0.2 F2400 ;Retract and raise Z
G1 X5 Y5 F3000 ;Wipe out
G1 Z10 ;Raise Z more
G90 ;Absolute positioning

G1 X0 Y300 ;Present print
M106 S0 ;Turn-off fan
M104 S0 ;Turn-off hotend
M140 S0 ;Turn-off bed

M84 X Y E ;Disable all steppers but Z

M82 ;absolute extrusion mode
M104 S0
;End of Gcode
;SETTING_3 {"global_quality": "[general]\\nversion = 4\\nname = Super Quality #2
;SETTING_3 \\ndefinition = creality_cr10s\\n\\n[metadata]\\ntype = quality_chang
;SETTING_3 es\\nquality_type = super\\nsetting_version = 17\\n\\n[values]\\nadhe
;SETTING_3 sion_type = skirt\\n\\n", "extruder_quality": ["[general]\\nversion =
;SETTING_3  4\\nname = Super Quality #2\\ndefinition = creality_cr10s\\n\\n[meta
;SETTING_3 data]\\ntype = quality_changes\\nquality_type = super\\nsetting_versi
;SETTING_3 on = 17\\nposition = 0\\n\\n[values]\\nalternate_extra_perimeter = Tr
;SETTING_3 ue\\ninfill_pattern = gyroid\\ninfill_sparse_density = 25\\nmaterial_
;SETTING_3 flow = 105\\nretraction_count_max = 35\\nretraction_speed = 30\\nskin
;SETTING_3 _monotonic = True\\nspeed_print = 50\\n\\n"]}
