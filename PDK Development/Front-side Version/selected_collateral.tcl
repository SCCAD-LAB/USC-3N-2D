# Exact front-side 144 nm collateral. PDK_ROOT is the repository root.
if {![info exists ::env(PDK_ROOT)]} {error "Set PDK_ROOT to the USC-3N-2D repository root"}
set fspr_repo_root [file normalize $::env(PDK_ROOT)]
set fspr_dev [file join $fspr_repo_root {PDK Development/Front-side Version}]
set fspr_gds [file join $fspr_dev GDS 3nm_GAA_FSPR_144nm.gds]
set fspr_model [file join $fspr_dev MODEL 3nm_GAA_FSPR_RVT.sp]
foreach vendor {Cadence OpenROAD Synopsys} {
    set fspr_vendor_root($vendor) [file join $fspr_repo_root "PnR-$vendor/Front-side Version"]
    set fspr_tech_lef($vendor) [file join $fspr_vendor_root($vendor) TECH-LEF 3nm_GAA_FSPR.tech.lef]
    set fspr_std_lef($vendor) [file join $fspr_vendor_root($vendor) LEF 3nm_GAA_FSPR.lef]
    set lib_folder LIB
    if {$vendor eq "Synopsys"} {set lib_folder LIB_DB}
    set fspr_lib($vendor) [file join $fspr_vendor_root($vendor) $lib_folder 3nm_GAA_FSPR_rvt_nldm.lib]
}
set fspr_db [file join $fspr_vendor_root(Synopsys) LIB_DB 3nm_GAA_FSPR_rvt_nldm.db]
set fspr_ndm [file join $fspr_vendor_root(Synopsys) NDM 3nm_GAA_FSPR_144nm_rvt.ndm]
set fspr_tf [file join $fspr_vendor_root(Synopsys) TF 3nm_GAA_FSPR.tf]
set fspr_tluplus [file join $fspr_vendor_root(Synopsys) ITF 3nm_GAA_FSPR.tluplus]
set fspr_qrc_tch [file join $fspr_vendor_root(Cadence) QRC 3nm_GAA_FSPR.tch]
set fspr_qrc_map [file join $fspr_vendor_root(Cadence) QRC 3nm_GAA_FSPR.layermap]
set fspr_release [file join $fspr_dev RELEASE_144nm_RVT]
set fspr_drc_deck [file join $fspr_release physical rules matched_144nm DRC sccad3nm_main.drc.rs]
set fspr_lvs_deck [file join $fspr_release physical rules matched_144nm LVS ICV_3nm.rs]
set fspr_pex_deck [file join $fspr_release physical rules matched_144nm LVS ICV_3nm_FSPR_PEX.rs]
set fspr_starrc_map [file join $fspr_release physical rules matched_144nm StarRC starrcxt.mapping]
set fspr_extraction_grid [file join $fspr_vendor_root(Synopsys) ITF 3nm_GAA_FSPR.nxtgrd]
# These are fin-present144nm mapping adapters; rules/github is historical.
# Native LVS checks topology; independent dimension/body audits remain separate.
set fspr_site coreSite
set fspr_release_binding pending
set fspr_final_timing_ready 0
set fspr_matched_release_ready 0
source [file join $fspr_dev matched_release_readiness.tcl]
proc fspr_require_final_timing {} {
    global fspr_final_timing_ready
    if {!$fspr_final_timing_ready} {error "Matched 57-cell native LIB/DB is pending. This private physical snapshot cannot run PNR."}
}
proc fspr_require_matched_release {{with_ndm 0}} {
    global fspr_matched_release_ready fspr_release_binding fspr_gds fspr_model fspr_std_lef fspr_lib fspr_db fspr_ndm
    if {!$fspr_matched_release_ready} {error "Matched 144nm release is pending final timing/NDM validation; old timing or historical NDM is not a fallback."}
    if {![regexp {^[0-9a-f]{64}$} $fspr_release_binding]} {error "Missing final matched-source binding"}
    set required [list $fspr_gds $fspr_model $fspr_db]
    foreach vendor {Cadence OpenROAD Synopsys} {lappend required $fspr_std_lef($vendor) $fspr_lib($vendor)}
    if {$with_ndm} {lappend required $fspr_ndm}
    foreach path $required {if {![file exists $path]} {error "Missing matched collateral: $path"}}
}
