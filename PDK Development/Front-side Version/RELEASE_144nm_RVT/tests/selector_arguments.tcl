# Executes actual file-selector procedures with command stubs. No native PNR.
set repo [lindex $argv 0]
set sources [lindex $argv 1]
set tool [lindex $argv 2]
set design [lindex $argv 3]
set macro [lindex $argv 4]
set fixture [lindex $argv 5]
set ::env(PDK_ROOT) $repo
source [file join $sources {PDK Development/Front-side Version/selected_collateral.tcl}]
cd $fixture

proc load_actual_proc {path name} {
    set stream [open $path r];set text [read $stream];close $stream
    set collecting 0;set body ""
    foreach line [split $text \n] {
        if {!$collecting && [string match "proc $name *" $line]} {set collecting 1}
        if {$collecting} {
            append body $line \n
            if {[info complete $body]} {uplevel #0 $body;return}
        }
    }
    error "Could not load actual procedure $name"
}
proc option {args_list key} {
    set index [lsearch -exact $args_list $key]
    if {$index < 0} {return ""}
    return [lindex $args_list [expr {$index+1}]]
}
proc same_list {actual expected label} {
    if {[llength $actual] != [llength $expected]} {error "$label list length: [llength $actual] expected [llength $expected]"}
    foreach value $actual target $expected {if {$value ne $target} {error "$label element mismatch: $value"}}
}
proc same_scalar {actual expected label} {
    if {$actual ne $expected} {error "$label scalar mismatch (serialized braces are not a filename): $actual"}
}
proc suppressMessage {args} {}
proc setLibraryUnit {args} {}
proc echo {args} {}
proc create_library_set {args} {
    same_list [option $args -timing] $::expected_libs timing
    incr ::library_calls
}
proc create_rc_corner {args} {
    set qrc [option $args -qx_tech_file]
    if {$qrc ne ""} {same_scalar $qrc $::fspr_qrc_tch qrc;incr ::qrc_calls}
    set cap [option $args -cap_table]
    if {$cap ne ""} {same_scalar $cap $::expected_cap cap;incr ::cap_calls}
}
proc update_rc_corner {args} {
    set qrc [option $args -qx_tech_file]
    if {$qrc ne ""} {same_scalar $qrc $::fspr_qrc_tch qrc_update;incr ::qrc_calls}
}
proc setExtractRCMode {args} {
    same_scalar [option $args -lefTechFileMap] $::fspr_qrc_map qrc_map
    incr ::map_calls
}
foreach command {create_constraint_mode create_delay_corner create_analysis_view remove_corners create_mode create_corner create_scenario set_scenario_status read_sdc set_parasitic_parameters report_corners} {proc $command {args} {}}
proc create_lib {args} {
    same_scalar [option $args -use_technology_lib] $::fspr_ndm technology_reference
    same_list [option $args -ref_libs] $::expected_ndms ndm_refs
    incr ::ndm_calls
}
proc read_parasitic_tech {args} {
    same_scalar [option $args -tlup] $::fspr_tluplus tluplus
    incr ::tlu_calls
}
set ::library_calls 0;set ::qrc_calls 0;set ::cap_calls 0;set ::map_calls 0
set ::ndm_calls 0;set ::tlu_calls 0
array set ::vars {LibUnit,Time 1ps LibUnit,Cap 1fF}
set ::env(build_name) point_scalar_mult
foreach variable {HARDMACROLEF_DIR HARDMACROLIB_DIR CAPTBL_DIR HARDNDM} {unset -nocomplain ::env($variable)}
set macro_lef [file join $fixture {macro files} {memory cell.lef}]
set macro_lib [file join $fixture {macro files} {memory timing.lib}]
set macro_ndm [file join $fixture {macro files} {memory cells.ndm}]
set ::expected_cap [file join $fixture {cap tables} {one cap.capTbl}]

if {$tool eq "cadence"} {
    set ::env(TECHLEF_DIR) [file dirname $::fspr_tech_lef(Cadence)]
    set ::env(MACROLEF_DIR) [file dirname $::fspr_std_lef(Cadence)]
    set ::env(MACROLIB_DIR) [file dirname $::fspr_lib(Cadence)]
    set ::env(TCH_DIR) [file dirname $::fspr_qrc_tch]
    set expected_lefs [list $::fspr_tech_lef(Cadence) $::fspr_std_lef(Cadence)]
    set ::expected_libs [list $::fspr_lib(Cadence)]
    if {$macro} {
        set ::env(HARDMACROLEF_DIR) [file dirname $macro_lef]
        set ::env(HARDMACROLIB_DIR) [file dirname $macro_lib]
        set ::env(CAPTBL_DIR) [file dirname $::expected_cap]
        lappend expected_lefs $macro_lef;lappend ::expected_libs $macro_lib
    }
    set path [file join $sources "PnR-Cadence/Front-side Version/Runfiles/${design}_innovus.tcl"]
    load_actual_proc $path prc_Enc_setupConfig
    load_actual_proc $path prc_Enc_mmmcConfig
    prc_Enc_setupConfig
    same_list $::init_lef_file $expected_lefs init_lef_file
    same_list $::rda_Input(ui_leffile) $expected_lefs ui_leffile
    prc_Enc_mmmcConfig
    if {$library_calls!=1 || $qrc_calls!=1 || $map_calls!=1 || $cap_calls!=$macro} {error "Missing file consumer call"}
} elseif {$tool eq "synopsys"} {
    set ::env(TLU_DIR) [file dirname $::fspr_tluplus]
    set ::expected_ndms [list $::fspr_ndm]
    if {$macro} {set ::env(HARDNDM) [file dirname $macro_ndm];lappend ::expected_ndms $macro_ndm}
    set path [file join $sources "PnR-Synopsys/Front-side Version/Runfiles/${design}_icc2.tcl"]
    source [file join $sources {PDK Development/Front-side Version/icc2_matched_references.tcl}]
    # Argument-only test; resume/provenance behavior is tested separately.
    rename fspr_reference_provenance fspr_reference_provenance_real
    proc fspr_reference_provenance {paths} {return [dict create fixture argument_only refs $paths]}
    proc current_lib {} {return fixture_design}
    proc get_attribute {object attribute} {return $::expected_ndms}
    load_actual_proc $path prc_ICC_createLibs
    load_actual_proc $path prc_ICC_mcmmConfig
    prc_ICC_createLibs;prc_ICC_mcmmConfig
    if {$ndm_calls!=1 || $tlu_calls!=1} {error "Missing NDM/parasitic consumer call"}
} elseif {$tool eq "openroad"} {
    set ::tech_lef $::fspr_tech_lef(OpenROAD)
    set ::std_cell_lef $::fspr_std_lef(OpenROAD)
    set ::liberty_file $::fspr_lib(OpenROAD);set ::extra_lef {};set ::extra_liberty {}
    set ::expected_open_lefs [list $::tech_lef $::std_cell_lef]
    set ::expected_open_libs [list $::liberty_file]
    if {$macro} {lappend ::extra_lef $macro_lef;lappend ::extra_liberty $macro_lib;lappend ::expected_open_lefs $macro_lef;lappend ::expected_open_libs $macro_lib}
    namespace eval sta {proc corners {} {return {default}}}
    set ::actual_open_lefs {};set ::actual_open_libs {}
    proc read_lef {path} {lappend ::actual_open_lefs $path}
    proc read_liberty {path} {lappend ::actual_open_libs $path}
    set helper [file join $sources {PnR-OpenROAD/Front-side Version/OpenROAD_Runfiles/flow_helpers.tcl}]
    if {![file exists $helper]} {set helper [file join $repo {PnR-OpenROAD/Front-side Version/OpenROAD_Runfiles/flow_helpers.tcl}]}
    load_actual_proc $helper read_libraries
    read_libraries
    same_list $::actual_open_lefs $::expected_open_lefs openroad_lefs
    same_list $::actual_open_libs $::expected_open_libs openroad_libs
} else {error "Unknown test tool"}
puts "USC144_ACTUAL_SELECTOR_ARGUMENTS_PASS $tool $design macros=$macro"
