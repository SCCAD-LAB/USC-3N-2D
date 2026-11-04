set_operating_condition -voltage 0.7 -temp 25
set_units -timing 1ps -capacitance 1ff -leakage_power 1pw
set_var ski_enable 0
set_var extsim_cmd /tools/software/cadence/spectre/25.10.09.367/bin/spectre
set_var extsim_cmd_option {+aps +mt=1 +spice}
set_var extsim_option {method=gear2only reltol=1e-6 vabstol=1e-9 iabstol=1e-15}
set_var extsim_leakage_option {method=gear2only reltol=1e-6 vabstol=1e-9 iabstol=1e-15}
set_var extsim_tran_append {maxstep=2e-13}
set_var extsim_save_failed 1
set_var extsim_save_passed 0
set_var extsim_deck_dir /tmp/yhuang861/usc144_github_release_20261103/characterization/native_cells/OR3x1/c4c45d8331940981/DECK
set_var slew_lower_rise 0.1
set_var slew_upper_rise 0.9
set_var slew_lower_fall 0.1
set_var slew_upper_fall 0.9
set_var measure_slew_lower_rise 0.1
set_var measure_slew_upper_rise 0.9
set_var measure_slew_lower_fall 0.1
set_var measure_slew_upper_fall 0.9
define_template -type delay -index_1 {0.0025 0.005 0.01 0.02 0.04 0.08 0.16} -index_2 {0.00036 0.00072 0.00144 0.00288 0.00576 0.01152 0.02304} d7
define_template -type power -index_1 {0.0025 0.005 0.01 0.02 0.04 0.08 0.16} -index_2 {0.00036 0.00072 0.00144 0.00288 0.00576 0.01152 0.02304} p7
define_template -type constraint -index_1 {0.0025 0.005 0.01 0.02 0.04 0.08 0.16} -index_2 {0.0025 0.005 0.01 0.02 0.04 0.08 0.16} c7
set_vdd VDD 0.7
set_gnd VSS 0
define_cell -input {A B C} -output {Y} -delay d7 -power p7 -constraint c7 {OR3x1}
set_var parse_leafcells_without_model 1
set_var extsim_model_include {/tmp/yhuang861/usc144_github_release_20261103/characterization/native_cells/OR3x1/c4c45d8331940981/model_native.scs}
define_leafcell -element -extsim_model -type nmos -pin_position {0 1 2 3} {NMOS_LVT}
define_leafcell -element -extsim_model -type pmos -pin_position {0 1 2 3} {PMOS_LVT}
read_spice -format spice {/tmp/yhuang861/usc144_github_release_20261103/characterization/native_cells/OR3x1/c4c45d8331940981/cells.sp}
char_library -extsim spectre -thread 16 -cells {OR3x1}
set_attribute -cells {OR3x1} area 0.036288
write_library -overwrite /tmp/yhuang861/usc144_github_release_20261103/characterization/native_cells/OR3x1/c4c45d8331940981/candidate.lib
puts USC144_NATIVE_CELL_CHARACTERIZATION_COMPLETE
exit
