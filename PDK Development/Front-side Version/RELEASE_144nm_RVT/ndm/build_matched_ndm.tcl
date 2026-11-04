# Run only with final selected57 timing inputs. Native syntax checked by LM help.
proc usc144_names {} {
    set names {}
    foreach_in_collection cell [get_lib_cells */*] {
        lappend names [lindex [split [get_attribute $cell name] /] end]
    }
    return [lsort -unique $names]
}
proc usc144_build {} {
    source [file join $::env(USC144_NDM_WORK) inputs.tcl]
    if {!$ndm_final_timing_gate} {error "Final native57 timing gate is not satisfied"}
    create_workspace -technology $ndm_tech usc144_matched_144nm_rvt
    read_db [list $ndm_db]
    read_lef -include tech [list $ndm_tech_lef]
    read_lef -preserve_lef_cell_site [list $ndm_cell_lef]
    # Build the physical frames; -noresolve performs only compatibility checks.
    check_workspace
    set actual [usc144_names]
    if {$actual ne $ndm_expected_cells || [llength $actual] != 57} {error "NDM57 cell-name mismatch"}
    if {[sizeof_collection [get_site_defs -quiet -exact $ndm_expected_site]] < 1} {error "Selected NDM site is absent"}
    commit_workspace -output $ndm_output
    puts "USC144_NDM_BUILD_PASS 57"
}
if {[catch {usc144_build} message]} {puts stderr "USC144_NDM_BUILD_ERROR $message";exit 1}
exit
