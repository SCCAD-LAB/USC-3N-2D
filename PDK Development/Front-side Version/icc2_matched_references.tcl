# Native reference query: get_attribute [current_lib] ref_libs.
# Existing routed libraries are inspected, never rebound.
proc fspr_normalized_refs {paths} {
    set result {}
    foreach path $paths {lappend result [file normalize $path]}
    return $result
}
proc fspr_ref_payloads {directory {relative ""} {depth 0}} {
    if {$depth > 16} {error "NDM payload directory nesting exceeds16"}
    set result {}
    foreach path [lsort [glob -nocomplain -directory [file join $directory $relative] *]] {
        set name [file join $relative [file tail $path]]
        if {[file isdirectory $path]} {
            if {[file type $path] eq "link"} {error "Use explicit canonical NDM payload directories"}
            set result [concat $result [fspr_ref_payloads $directory $name [expr {$depth+1}]]]
        } elseif {[file isfile $path]} {
            set checksum [lindex [split [exec sha256sum -- $path]] 0]
            lappend result [list $name $checksum]
        }
    }
    return $result
}
proc fspr_reference_provenance {paths} {
    global fspr_release_binding fspr_dev
    if {![regexp {^[0-9a-f]{64}$} $fspr_release_binding]} {error "Missing final matched-release binding"}
    set readiness [file join $fspr_dev matched_release_readiness.tcl]
    set readiness_sha [lindex [split [exec sha256sum -- $readiness]] 0]
    set normalized [fspr_normalized_refs $paths]
    set payloads {}
    foreach path $normalized {
        if {![file isdirectory $path]} {error "Expected an explicit NDM directory: $path"}
        set fingerprints [fspr_ref_payloads $path]
        if {![llength $fingerprints]} {error "NDM reference payload is empty: $path"}
        lappend payloads [list $path $fingerprints]
    }
    return [dict create schema usc144_matched_refs_v1 release_binding $fspr_release_binding readiness_sha256 $readiness_sha ref_libs $normalized payload_sha256 $payloads]
}
proc fspr_assert_current_references {expected} {
    set actual [fspr_normalized_refs [get_attribute [current_lib] ref_libs]]
    if {$actual ne [fspr_normalized_refs $expected]} {
        error "Existing library reference mismatch; no rebind performed. Use its original matched release or a fresh work directory."
    }
}
proc fspr_icc2_open_or_create {design_library expected_refs} {
    set expected_refs [fspr_normalized_refs $expected_refs]
    set provenance [fspr_reference_provenance $expected_refs]
    set record "[file normalize $design_library].usc144_provenance"
    if {[file exists $design_library]} {
        if {![file isfile $record]} {error "Existing library has no matched144nm provenance; no rebind performed"}
        set stream [open $record r];set saved [string trim [read $stream]];close $stream
        if {[catch {dict size $saved}] || $saved ne $provenance} {error "Existing library readiness/source provenance differs; no rebind performed"}
        open_lib $design_library
        fspr_assert_current_references $expected_refs
        if {[fspr_reference_provenance $expected_refs] ne $provenance} {error "Reference/readiness/source changed during library open; no rebind performed"}
    } else {
        create_lib -use_technology_lib [lindex $expected_refs 0] -ref_libs $expected_refs $design_library
        fspr_assert_current_references $expected_refs
        set after_create [fspr_reference_provenance $expected_refs]
        if {$after_create ne $provenance} {error "Reference/readiness/source changed during library creation; no provenance saved and no rebind performed. Use a fresh work directory."}
        set temporary "${record}.[pid].tmp"
        set stream [open $temporary w];puts $stream $provenance;close $stream
        file rename -force $temporary $record
    }
}
proc fspr_require_selected_site {name} {
    set sites [get_site_defs -quiet -exact $name]
    if {[sizeof_collection $sites] < 1} {error "Selected placement site is absent: $name"}
    return $sites
}
