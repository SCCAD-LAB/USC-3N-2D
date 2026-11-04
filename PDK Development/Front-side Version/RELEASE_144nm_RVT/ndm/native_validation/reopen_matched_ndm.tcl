# Native ICC2 readback in a fresh process, never a reused workspace.
proc usc144_readback {} {
    source [file join $::env(USC144_NDM_WORK) inputs.tcl]
    source [file join $::env(USC144_NDM_WORK) check_ndm_interfaces.tcl]
    if {!$ndm_final_timing_gate} {error "Final native57 timing gate is not satisfied"}
    open_lib $ndm_output
    set names {}
    foreach_in_collection cell [get_lib_cells */*] {lappend names [lindex [split [get_attribute $cell name] /] end]}
    set names [lsort -unique $names]
    if {$names ne $ndm_expected_cells || [llength $names] != 57} {error "Reopened NDM57 cell-name mismatch"}
    if {[sizeof_collection [get_site_defs -quiet -exact $ndm_expected_site]] < 1} {error "Reopened NDM selected site is absent"}
    usc144_check_interfaces $ndm_expected_interfaces [file join $::env(USC144_NDM_WORK) REOPENED_INTERFACES.tsv]
    set stream [open [file join $::env(USC144_NDM_WORK) REOPENED_57_CELLS.txt] w]
    puts $stream [join $names \n];close $stream
    set stream [open [file join $::env(USC144_NDM_WORK) REOPENED_SITE.txt] w]
    puts $stream $ndm_expected_site;close $stream
    puts "USC144_NDM_REOPEN_PASS 57"
}
if {[catch {usc144_readback} message]} {puts stderr "USC144_NDM_REOPEN_ERROR $message";exit 1}
exit
