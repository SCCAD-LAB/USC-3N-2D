# Actual ICC2 library/site procedures with deterministic command stubs.
set repo [lindex $argv 0]
set sources [lindex $argv 1]
set design [lindex $argv 2]
set fixture [lindex $argv 3]
set ::env(PDK_ROOT) $repo
source [file join $sources {PDK Development/Front-side Version/selected_collateral.tcl}]
source [file join $sources {PDK Development/Front-side Version/icc2_matched_references.tcl}]
cd $fixture
proc load_actual_proc {path name} {
 set f [open $path r];set text [read $f];close $f;set body "";set active 0
 foreach line [split $text \n] {
  if {!$active && [string match "proc $name *" $line]} {set active 1}
  if {$active} {append body $line \n;if {[info complete $body]} {uplevel #0 $body;return}}
 }
 error "Missing actual procedure $name"
}
proc echo {args} {}
proc create_lib {args} {
 if {[lindex $args 0] ne "-use_technology_lib" || [lindex $args 1] ne $::fspr_ndm} {error "Wrong technology inheritance"}
 set index [lsearch -exact $args -ref_libs];set ::actual_refs [lindex $args [expr {$index+1}]]
 file mkdir [lindex $args end];incr ::creates
}
proc current_lib {} {return empty_fixture}
proc get_attribute {object name} {if {$name ne "ref_libs"} {error "Unvalidated attribute"};return $::actual_refs}
proc open_lib {path} {incr ::opens}
proc get_site_defs {args} {
 if {$args eq [list -quiet -filter {is_default == true}]} {return site_core}
 if {$args ne [list -quiet -exact coreSite]} {error "Wrong selected site $args"}
 if {$::site_exists} {return site_coreSite};return {}
}
proc sizeof_collection {collection} {return [llength $collection]}
proc get_layers {layers} {return layers}
proc set_attribute {object args} {
 if {$object eq "site_coreSite"} {lappend ::site_attributes $args}
 if {$object eq ""} {error "Empty site reached attribute consumer"}
}
proc expect_failure {label script} {
 if {![catch {uplevel 1 $script} message]} {error "Expected rejection $label"}
 if {![string match "*no rebind*" $message] && ![string match "*site*absent*" $message]} {error "Unexpected rejection $label: $message"}
 puts "PASS $label"
}
set fspr_ndm [file join $fixture {reference frames} {matched cells.ndm}]
file mkdir $fspr_ndm
set f [open [file join $fspr_ndm payload] w];puts $f fixture;close $f
set fspr_dev [file join $fixture {release metadata}];file mkdir $fspr_dev
set readiness [file join $fspr_dev matched_release_readiness.tcl]
set f [open $readiness w];puts $f fixture;close $f
set fspr_release_binding [string repeat a 64]
set creates 0;set opens 0;set site_exists 1;set site_attributes {}
unset -nocomplain ::env(HARDNDM)
set path [file join $sources "PnR-Synopsys/Front-side Version/Runfiles/${design}_icc2.tcl"]
set f [open $path r];set text [read $f];close $f
foreach line [split $text \n] {
 if {[regexp {^set vars\((Place,SiteDef|Route,VerticalMetals|Route,HorizontalMetals)\)} $line]} {uplevel #0 $line}
}
if {$vars(Place,SiteDef) ne "coreSite"} {error "Actual site assignment mismatches selected LEF"}
load_actual_proc $path prc_ICC_createLibs
load_actual_proc $path prc_ICC_setupConfig
prc_ICC_createLibs
prc_ICC_setupConfig
if {$creates!=1 || [llength $site_attributes]!=2} {error "Fresh branch/site not exercised"}
puts "PASS fresh_technology_and_site"
prc_ICC_createLibs
if {$creates!=1 || $opens!=1} {error "Matching resume was not preserved"}
puts "PASS matched_resume"
set expected_refs $actual_refs
set actual_refs [list /historical/legacy.ndm]
expect_failure historical_references {prc_ICC_createLibs}
set actual_refs $expected_refs
set fspr_release_binding [string repeat b 64]
expect_failure changed_release {prc_ICC_createLibs}
set fspr_release_binding [string repeat a 64]
set f [open $readiness a];puts $f changed;close $f
expect_failure changed_readiness {prc_ICC_createLibs}
set f [open $readiness w];puts $f fixture;close $f
set f [open [file join $fspr_ndm payload] a];puts $f changed;close $f
expect_failure changed_reference_bytes {prc_ICC_createLibs}
file delete ./impl_normal2D.usc144_provenance
expect_failure missing_provenance {prc_ICC_createLibs}
set site_exists 0
expect_failure missing_selected_site {prc_ICC_setupConfig}
if {$creates!=1} {error "An existing library was replaced"}
rename fspr_reference_provenance fspr_real_provenance
set ::fingerprint_calls 0
proc fspr_reference_provenance {paths} {
 incr ::fingerprint_calls
 return [dict create source_payload [expr {$::fingerprint_calls==1 ? "A" : "B"}]]
}
expect_failure drift_during_create {fspr_icc2_open_or_create ./drift_create [list $::fspr_ndm]}
if {[file exists ./drift_create.usc144_provenance]} {error "Drifted source provenance was saved"}
set ::fingerprint_calls 0
file mkdir ./drift_open
set f [open ./drift_open.usc144_provenance w];puts $f [dict create source_payload A];close $f
expect_failure drift_during_open {fspr_icc2_open_or_create ./drift_open [list $::fspr_ndm]}
rename fspr_reference_provenance {}
rename fspr_real_provenance fspr_reference_provenance
puts "USC144_RESUME_SITE_TEST_PASS $design"
