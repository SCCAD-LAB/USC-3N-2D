proc run {} {
open_lib {/tmp/yhuang861/usc144_github_release_20261103/matched_native_NDM_local_1793805882/native_build/3nm_GAA_FSPR_144nm_rvt.ndm}
puts "USC144_INPUT_CAP_UNIT [get_user_units -input -type capacitance]"
puts "USC144_OUTPUT_CAP_UNIT [get_user_units -output -type capacitance]"
report_units
report_lib -verbose [get_object_name [current_lib]]
set checked 0
set stream [open TIMING_ARCS.tsv w]
foreach_in_collection cell [get_lib_cells */*] {set name [get_attribute $cell name];set count [sizeof_collection [get_lib_timing_arcs -of_objects $cell]];if {$count<1} {error "No timing arcs for $name"};puts $stream "$name\t$count";incr checked}
close $stream
puts "USC144_INV_A_CAP_RAW [get_attribute [get_lib_pins */INVx1/A] capacitance]"
puts "USC144_TIMING_CONTENT_PASS $checked"
}
if {[catch {run} message]} {puts "USC144_TIMING_ERROR $message";exit 1}
exit
