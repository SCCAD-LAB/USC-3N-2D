#=====================================================================
# OpenPiton_icc2.tcl -- Self-contained PnR script (normal2D)
#
# Target tool : Synopsys IC Compiler II (icc2_shell)
# Design      : OpenPiton tile (12 SRAM macros)
# Floorplan   : 300.006 x 362.01 um (margins 2)
# PDK family  : 3nm GAA FSPR (Front-Side Power Rail)
# Author      : SCCAD Lab
#
# Required inputs in current working directory:
#   - tile.netlist.v                (synthesized Verilog netlist)
#   - tile.sdc                      (timing constraints)
#   - tile.pin.tcl                  (IO pin placement -- shipped side file)
#   - impl/FloorPlan.def            (pre-placed SRAM macros -- required)
#
# Required environment variables (or source run.sh):
#   - PDK_ROOT          (root of the released FSPR PDK)
#
# NOTE on layer-name convention:
#   ICC2 uses string layer NAMES ("M8", "M1", ...), not integer indices.
#   The vars(2D_PNR,*RouteLayer) and vars(2D_PNR,PinRouteLayerList) are
#   layer-name strings.  Do not change them to integers.
#
# To run:
#   bash run.sh                    -> invokes icc2_shell
#
# Run produces:
#   - ./impl_normal2D/normal2D/{place,postCTS,route}.design  (checkpoints)
#   - ./log/pnr/normal2D.*.rpt                               (reports)
#   - normal2D.logging
#   - tile.{pin.layer, pin.loc, pin.tcl}
#=====================================================================

#=====================================================================
# USER CONFIGURATION
#=====================================================================
# Set PDK_ROOT before invoking this script:
#   export PDK_ROOT=/path/to/USC-3N-2D
# All other paths derive from PDK_ROOT.

if { ![info exists ::env(PDK_ROOT)] } {
    puts "ERROR: please set PDK_ROOT to the USC-3N-2D repository root before sourcing this script"
    exit 1
}
set techDir [file normalize $::env(PDK_ROOT)]
source [file join $techDir {PDK Development/Front-side Version/selected_collateral.tcl}]
fspr_require_matched_release 1
source [file join $::fspr_dev icc2_matched_references.tcl]
set ::env(NDM_DIR) [file dirname $::fspr_ndm]
set ::env(TF_DIR) [file dirname $::fspr_tf]
set ::env(TLU_DIR) [file join $::fspr_vendor_root(Synopsys) ITF]
set ::env(MACRODB_DIR) [file dirname $::fspr_db]

# Design name controls input filenames (.netlist.v, .sdc, etc.)
set ::env(build_name) "tile"

# OpenPiton requires hard-macro NDM for its SRAMs.  Auto-set from the
# standard PDK layout; override HARDNDM before invoking the script if your
# SRAM library lives elsewhere.
if { ![info exists ::env(HARDNDM)] && [file isdirectory "$techDir/openpiton_mem_L3_256k/2d_hard_ndm"] } {
    set ::env(HARDNDM) "$techDir/openpiton_mem_L3_256k/2d_hard_ndm"
}

# Input-file checks
echo "--------SCCAD Lab ICC2 PnR script---------"
if { ![file exists $::env(build_name).sdc] } {
    puts "\n\[ERROR\] missing $::env(build_name).sdc\n"; exit 1
}
if { ![file exists $::env(build_name).netlist.v] && ![file exists $::env(build_name).netlist.v.gz] } {
    puts "\n\[ERROR\] missing $::env(build_name).netlist.v(.gz)\n"; exit 1
}

#=====================================================================
# DESIGN VARIABLES (inlined from $::env(build_name).variables.tcl)
#=====================================================================
set vars(LibUnit,Time)  1ps
set vars(LibUnit,Cap)   1fF
set vars(LibUnit,Process) 3
set vars(CpuUsage)      25
set vars(FlowEffort)    standard
set vars(PowerEffort)   high

set vars(Route,HorizontalMetals) "M2 M4 M6 M8"
set vars(Route,VerticalMetals)   "M1 M3 M5 M7"
set vars(Route,DRIter)           20
set vars(Place,SiteDef)          $::fspr_site
set vars(Route,RedundantVias)    0

set vars(FloorPlan,AspectRatio)     1
set vars(FloorPlan,StdCellDensity)  0.7
set vars(FloorPlan,LeftMargin)      2
set vars(FloorPlan,BottomMargin)    2
set vars(FloorPlan,RightMargin)     2
set vars(FloorPlan,TopMargin)       2
set vars(FloorPlan,Width)           300.006
set vars(FloorPlan,Height)          362.01

set vars(ClockUncertainty,preCTS)    0
set vars(ClockUncertainty,CTS)       0
set vars(ClockUncertainty,postCTS)   0
set vars(ClockUncertainty,postRoute) 0

set vars(ccopt,latencyOpt) 0
set vars(ccopt,optType)    "all"

set vars(SwitchingActivity,RegToggle) 0.2
set vars(SwitchingActivity,IpToggle)  0.2
set vars(SwitchingActivity,ClkToggle) 2.0
set vars(SwitchingActivity,DutyRatio) 0.5

set vars(ExtractionEngine,postRoute) "IQRC"
set vars(ExtractionEngine,Scaling)   1

# ICC2 layer names are strings, not integers!
set vars(2D_PNR,placeMaxDensity)        0.9
set vars(2D_PNR,maxRouteLayer)          "M8"
set vars(2D_PNR,minRouteLayer)          "M1"
set vars(2D_PNR,maxPinRouteLayer)       "M8"
set vars(2D_PNR,PinRouteLayerList)      "M2 M3 M4 M5 M6 M7 M8"
set vars(2D_PNR,minPinRouteLayer)       "M1"
set vars(2D_PNR,leakageToDynamicRatio)  0.1
set vars(2D_PNR,routingIteration)       2
set vars(2D_PNR,routeProcessNode)       N12
set vars(2D_PNR,designProcessNode)      N12
set vars(2D_PNR,routeSignoffEffort)     1

set vars(saveDesign,flp)     1
set vars(saveDesign,place)   1
set vars(saveDesign,preCTS)  1
set vars(saveDesign,ccopt)   1
set vars(saveDesign,postCTS) 1
set vars(saveDesign,route)   1

#=====================================================================
# UTILITY PROCEDURES (logging helpers, used by normal2D path)
#=====================================================================

proc ladd { l } { package require Tcl 8.5; ::tcl::mathop::+ {*}$l }

proc lmean { l } {
    if { $l == "0x0" || [llength $l] == 0 } {
        return 0
    } else {
        return [expr [ladd $l] * 1.0 / [llength $l]]
    }
}

proc check_get_var { varname } {
    upvar $varname var
    if { [info exists var] } { return $var } else { return "undef" }
}

proc fill_nan { vname } {
    upvar $vname v
    if { $v == "" } { set v 0 }
}

proc bbox2area { bboxes } {
    set areas ""
    if { [llength [lindex [lindex $bboxes 0] 0]] == 1 } {
        set bboxes [list $bboxes]
    }
    foreach bbox $bboxes {
        lassign $bbox p0 p1
        lassign $p0 x0 y0
        lassign $p1 x1 y1
        lappend areas [expr ($x1 - $x0) * ($y1 - $y0)]
    }
    return $areas
}

proc log_timing_summary { fname {mpaths 100} } {
    set write_data ""
    foreach_in_collection path [get_timing_paths -max_paths $mpaths] {
        set tdel [get_attr $path -q total_delay];               fill_nan tdel
        set stl  [get_attr $path -q startpoint_clock_latency]
        set endl [get_attr $path -q endpoint_clock_latency]
        if { $stl != "" && $endl != "" } {
            set uskw [expr $endl - $stl]
        } else { set uskw 0 }
        fill_nan stl; fill_nan endl
        set cppr [get_attr $path -q common_path_pessimism];     fill_nan cppr
        set chk  [get_attr $path -q check_value];               fill_nan chk
        set slk  [get_attr $path -q slack];                     fill_nan slk
        set pgn  [get_attr $path -q path_group_name]
        set pgc  [get_attr [get_path_groups $pgn] comment]
        if { $pgc != "" } { set pgc "U" } else { set pgc "A" }
        set endp [get_attr $path endpoint_name]
        set stp  [get_attr $path startpoint_name]
        set write_data ${write_data}[format "%12.4f %-12s (%1s) %6.2f %6.2f %6.2f %6.2f %6.2f %6.2f %-32s %-32s\n" \
            $slk $pgn $pgc $tdel $uskw $stl $endl $cppr $chk $stp $endp]
    }
    echo "---------------------------------------------------------------------------------------------------------------" >> $fname
    echo [format "%12s %-12s (%1s) %6s %6s %6s %6s %6s %6s %-32s %-32s\n" \
        "Slack" "Path Group" "" "Delay" "USkew" "StLate" "EnLate" "UCPPR" "Check" "Start Point" "End Point"] >> $fname
    echo $write_data >> $fname
}

proc log_timing_power { fname } {
    echo "\n#######timin report#########\n" >> $fname
    report_timing >> $fname
    echo "########timing avgs of 100 critical paths in each group" >> $fname
    echo "path_group slack path_delay useful_skew setup" >> $fname
    foreach p [get_attr [get_path_groups -filter comment=="user_gen"] name] {
        set paths [get_timing_paths -groups $p -max_paths 100 -slack_lesser_than 0.0]
        set stl   [lmean [get_attr $paths startpoint_clock_latency]]
        set endl  [lmean [get_attr $paths   endpoint_clock_latency]]
        set cppr  [lmean [get_attr $paths common_path_pessimism]]
        set skew  [expr $endl + $cppr - $stl]
        set setup [lmean [get_attr $paths -q check_value]]
        echo "$p [lmean [get_attr $paths slack]] [lmean [get_attr $paths total_delay]] $skew $setup" >> $fname
    }
    log_timing_summary $fname 10
    echo "\n#######power report#########\n" >> $fname
    report_power >> $fname
}

proc log_caps { fname } {
    echo "\n#######capacitance report#########\n" >> $fname
    set wc  [ladd [get_attr [get_flat_nets -filter {defined(wire_capacitance_max) && net_type=="signal"}] wire_capacitance_max]]
    set wcc [ladd [get_attr [get_flat_nets -filter {defined(wire_capacitance_max) && net_type=="clock" }] wire_capacitance_max]]
    set pc0 [ladd [get_attr [get_flat_pins] max_fall_input_cap]]
    set pc1 [ladd [get_attr [get_flat_pins] max_rise_input_cap]]
    set pc  [expr 0.5 * ($pc0 + $pc1)]
    echo "Total Signal Net Cap: $wc"  >> $fname
    echo "Total Clock  Net Cap: $wcc" >> $fname
    echo "Total Wire Cap: [expr $wc + $wcc]" >> $fname
    echo "Total Pin Cap: $pc" >> $fname
    echo "Total Cap: [expr $wc + $wcc + $pc]" >> $fname
}

proc log_routing { fname } {
    echo "\n#######wl and via report#########\n" >> $fname
    set path_shapes [get_shapes -f shape_type=="path"]
    foreach layer [get_attr [get_layers -filter layer_type=="interconnect"] name] {
        echo "Total Wirelength on layer $layer: [ladd [get_attr [filter $path_shapes layer_name==$layer] length]] um" >> $fname
    }
    echo "-----------------------------------------------" >> $fname
    echo "Total Wirelength: [ladd [get_attr [get_shapes -f shape_type=="path"] length]] um" >> $fname
    echo "-----------------------------------------------" >> $fname
    foreach layer [get_attr [get_layers -filter layer_type=="via_cut"] name] {
        echo "Total via cuts on layer $layer: [sizeof [get_vias -f cut_layer_names==$layer]]" >> $fname
    }
}

proc log_cell_info { fname } {
    echo "\n#######cell report#########\n" >> $fname
    echo "Number of cells: [sizeof [get_flat_cells]]" >> $fname
    echo "Number of macros: [sizeof [get_flat_cells -f is_hard_macro]]" >> $fname
    set sca     [ladd [get_attr [get_flat_cells -f !is_hard_macro] area]]
    set mca     [ladd [bbox2area [get_attr [get_flat_cells -f is_hard_macro] bbox]]]
    set cur_mca [ladd [get_attr [get_flat_cells -f is_hard_macro] area]]
    set chipa   [get_attr [get_core_area] area]
    echo "Std Cell Area: ${sca}um^2" >> $fname
    echo "Total Macro Area: ${mca}um^2" >> $fname
    echo "Cur Die Macro Area: ${cur_mca}um^2" >> $fname
    echo "Chip Area: ${chipa}um^2" >> $fname
    echo "Total Utilization: [expr ($cur_mca + $sca) / $chipa]" >> $fname
    echo "Number of nets: [sizeof [get_flat_nets]]" >> $fname
}

proc log_results { stage {mode a} } {
    upvar outName outn
    set fname ${outn}.logging
    if { $mode == "w" } { echo "" > $fname }
    echo "#############################################" >> $fname
    echo [date] >> $fname
    echo "Stage: $stage" >> $fname
    echo "#############################################" >> $fname
    report_user_units >> $fname
    log_timing_power $fname
    log_caps         $fname
    log_routing      $fname
    log_cell_info    $fname
    echo "\n\n\n\n\n" >> $fname
}

#=====================================================================
# HELPER PROCEDURES
#=====================================================================

proc prc_spSplit { str chars } {
    set final ""
    set init [split $str $chars]
    foreach element $init {
        if { $element != {} } {
            lappend final $element
        }
    }
    return $final
}

proc prc_toTSV { str } {
    set trailing [string range $str 4 end]
    set TSV "TSV${trailing}"
    return $TSV
}

proc prc_toFSV { str } {
    set FSV "F${str}"
    return $FSV
}

# Setup site/layer routing direction (single-die normal2D path)
proc prc_ICC_setupConfig { } {
    uplevel \#0 {
        set selected_sites [fspr_require_selected_site $vars(Place,SiteDef)]
        set_attribute $selected_sites symmetry Y
        set previous_defaults [get_site_defs -quiet -filter {is_default == true}]
        if {[sizeof_collection $previous_defaults] > 0} {set_attribute $previous_defaults is_default false}
        set_attribute $selected_sites is_default true
        set_attribute [get_layers ${vars(Route,VerticalMetals)}]   -name routing_direction -value vertical
        set_attribute [get_layers ${vars(Route,HorizontalMetals)}] -name routing_direction -value horizontal
    }
}

# Create the design lib for normal2D
proc prc_ICC_createLibs { } {
    uplevel \#0 {
        set cellNdm {}
        foreach fileName [list $::fspr_ndm] { lappend cellNdm $fileName }

        if { [info exists ::env(HARDNDM)] } {
            set hardNdm "$::env(HARDNDM)"
            foreach fileName [lsort [glob -d $hardNdm *.ndm]] { lappend cellNdm $fileName }
        }

        echo $cellNdm
        fspr_icc2_open_or_create ./impl_normal2D $cellNdm
    }
    echo "SCCAD: prc_ICC_createLibs done"
}

# Single-corner MCMM: S1 / M1 / C1
proc prc_ICC_mcmmConfig { } {
    uplevel \#0 {
        remove_corners -all
        set tlu "$::env(TLU_DIR)"

        if { $tlu != "" } {
            set tluFile $::fspr_tluplus
            set nxtGrd $::fspr_extraction_grid
            if { $tluFile != "" } {
                read_parasitic_tech -tlup $tluFile -name nomTLU
            } elseif { $nxtGrd != "" } {
                read_parasitic_tech -tlup $nxtGrd -name nomTLU
            }
        }

        create_mode    M1
        create_corner  C1
        create_scenario -name S1 -mode M1 -corner C1

        if { [info exists vars(ICC2,hold_off)] && $vars(ICC2,hold_off) == 1 } {
            set_scenario_status S1 -hold false
        }

        read_sdc ./$::env(build_name).sdc
        set_parasitic_parameters -corners C1 -late_spec nomTLU -early_spec nomTLU
        report_corners
    }
    echo "mcmm config done"
}

# Apply min/max routing layers + global app-options
proc prc_ICC_setPNRmodes { } {
    echo "pnr modes start"
    uplevel \#0 {
        set_app_options -name place.coarse.continue_on_missing_scandef -value true
        set_app_options -name place.coarse.icg_auto_bound              -value true
        set_app_options -name place_opt.flow.optimize_icgs             -value true

        set_app_options -name time.si_enable_analysis -value true
        set_app_options -list { time.remove_clock_reconvergence_pessimism true \
                                time.clock_reconvergence_pessimism normal }
        set_app_options -name time.use_pt_delay -value true

        set_ignored_layers -min_routing_layer $vars(2D_PNR,minRouteLayer) \
                           -max_routing_layer $vars(2D_PNR,maxRouteLayer)
        set_individual_pin_constraints -ports * -allowed_layers $vars(2D_PNR,PinRouteLayerList)
        if { [info exists vars(2D_PNR,PinSide)] } {
            set_individual_pin_constraints -ports * \
                -allowed_layers $vars(2D_PNR,PinRouteLayerList) \
                -sides          $vars(2D_PNR,PinSide)
        }

        set_app_options -name cts.common.max_net_length -value 220
        set_app_options -name cts.common.max_fanout     -value 40
        set_app_options -name opt.common.max_net_length -value 220
        set_app_options -name opt.common.max_fanout     -value 40

        set_app_options -name route.track.timing_driven   -value true
        set_app_options -name route.global.timing_driven  -value true
        set_app_options -name route.detail.timing_driven  -value true
        set_app_options -name route_opt.flow.enable_ccd   -value true

        if { $vars(Route,RedundantVias) == 1 } {
            set_app_options -name route.common.concurrent_redundant_via_mode             -value reserve_space
            set_app_options -name route.common.post_detail_route_redundant_via_insertion -value low
            set_app_options -name route.detail.optimize_wire_via_effort_level            -value high
        }
        set_app_options -name route.detail.eco_max_number_of_iterations \
                        -value $vars(Route,DRIter)
    }
    echo "pnr modes set"
}

proc prc_ICC_setSwitchingActivity { } {
    uplevel \#0 {
        reset_switching_activity
        set clkName [get_attribute [get_clocks -filter !is_virtual] full_name]
        set_switching_activity -base_clock $clkName \
            -toggle_rate $vars(SwitchingActivity,RegToggle) \
            -static_probability 0.5 \
            [get_pins -of_objects [all_registers] -filter direction=="out"]
        set_switching_activity -base_clock $clkName \
            -toggle_rate $vars(SwitchingActivity,IpToggle) \
            -static_probability 0.5 \
            [remove_from_collection [all_inputs] [list $clkName]]
        set_switching_activity -base_clock $clkName \
            -toggle_rate $vars(SwitchingActivity,ClkToggle) \
            -static_probability 0.5 \
            [get_ports -filter is_clock_used_as_clock==true]
    }
}

proc prc_ICC_setPwrGrps { } {
    uplevel \#0 {
        catch [set_power_group [get_cells -filter {is_sequential && design_type!=macro}] -name seqs]
        catch [set_power_group [get_cells -filter is_clock_network_cell] -name clks]
        catch [set_power_group [get_cells -filter {is_combinational && !is_clock_network_cell}] -name combs]
        catch [set_power_group [get_cells -filter {is_sequential && design_type==macro}] -name macros]
    }
}

#=====================================================================
# MAIN FLOW (normal2D)
#=====================================================================

set_host_options -max_cores 8
if { [info exists vars(CpuUsage)] } { set_host_options -max_cores $vars(CpuUsage) }
set_app_var query_objects_format Tcl

set outName "normal2D"

echo "SCCAD: prc_ICC_createLibs"
prc_ICC_createLibs
sh mkdir -p impl log log/pnr

if { [file exists $::env(build_name).netlist.v] } {
    read_verilog ./$::env(build_name).netlist.v
} else {
    read_verilog ./$::env(build_name).netlist.v.gz
}

prc_ICC_mcmmConfig
prc_ICC_setupConfig

# Floorplan
if { [file exists "./impl/FloorPlan.def"] } {
    read_def ./impl/FloorPlan.def
    initialize_floorplan -keep_all -keep_boundary
} elseif { [file exists "./impl/FloorPlan.def.gz"] } {
    read_def ./impl/FloorPlan.def.gz
    initialize_floorplan -keep_all -keep_boundary
} elseif { [info exists vars(FloorPlan,Width)] && [info exists vars(FloorPlan,Height)] } {
    initialize_floorplan -shape R \
        -side_length "$vars(FloorPlan,Width) $vars(FloorPlan,Height)" \
        -core_offset "$vars(FloorPlan,LeftMargin) $vars(FloorPlan,BottomMargin) $vars(FloorPlan,RightMargin) $vars(FloorPlan,TopMargin)"
    echo "initialized fpln with width & height"
} else {
    initialize_floorplan -shape R \
        -side_ratio        "1 $vars(FloorPlan,AspectRatio)" \
        -core_utilization  $vars(FloorPlan,StdCellDensity) \
        -core_offset       "$vars(FloorPlan,LeftMargin) $vars(FloorPlan,BottomMargin) $vars(FloorPlan,RightMargin) $vars(FloorPlan,TopMargin)"
    echo "initialized fpln (aspect ratio)"
    write_def -include {cells blockages} -cell_types macro impl/header.def
}

prc_ICC_setPNRmodes

# Switching activity + pre-CTS clock uncertainty
prc_ICC_setSwitchingActivity
if { [info exists vars(ClockUncertainty,preCTS)] } {
    set_clock_uncertainty $vars(ClockUncertainty,preCTS) [all_clocks]
}

remove_buffer_tree -all
echo "Remove buffer tree enabled"

# Placement
create_placement -floorplan -effort high -timing_driven
place_pins -self

##=====================================================================
## PIN PLACEMENT
##   OpenPiton ships an optional tile.pin.tcl side file with the lab's
##   tuned IO placement.  Two notes for academic users:
##     1) The shipped tile.pin.tcl in this release is in Innovus syntax
##        (moveGroupPins ...).  It is NOT directly source-able by ICC2.
##        Either re-format it to set_individual_pin_constraints, or skip
##        it entirely -- place_pins -self above produces a reasonable
##        default IO placement.
##     2) The conditional source below is wrapped in catch so a syntax
##        mismatch never aborts the run.
##=====================================================================
if { [file exists "$::env(build_name).pin.tcl"] } {
    if { [catch { source "$::env(build_name).pin.tcl" } err] } {
        puts "\[WARN\] $::env(build_name).pin.tcl could not be sourced (likely Innovus syntax); continuing with place_pins defaults. Error: $err"
    }
} else {
    puts "\[INFO\] $::env(build_name).pin.tcl not present -- using place_pins defaults"
}
##=====================================================================

set_app_options -name place.coarse.fix_hard_macros -value true

# Placement optimization
place_opt

save_block -compress -as ${outName}/place
log_results place w

# Refresh MCMM and apply CTS clock uncertainty
prc_ICC_mcmmConfig
if { [info exists vars(ClockUncertainty,CTS)] } {
    set_clock_uncertainty $vars(ClockUncertainty,CTS) [all_clocks]
}
if { [check_get_var vars(Target_skew,CTS)] == 1 } {
    set_clock_tree_options -target_skew $vars(Target_skew,CTS)
}
if { [check_get_var vars(Target_latency,CTS)] == 1 } {
    set_clock_tree_options -target_latency $vars(Target_latency,CTS)
}
if { [check_get_var vars(Max_trans,CTS)] == 1 } {
    set_max_transition $vars(Max_trans,CTS) [get_clocks CK] -clock_path
}

# Clock-tree synthesis + post-CTS optimization
set_app_options -name route.common.net_max_layer_mode -value hard
clock_opt
check_routes
save_block -compress -as ${outName}/postCTS
log_results postCTS a

# Routing
if { [file exists "$::env(build_name).postCTS.sdc"] } {
    source $::env(build_name).postCTS.sdc
}
set_app_options -name route.common.net_max_layer_mode -value hard

route_auto
log_results route_auto
route_opt
check_routes
save_block -compress -as ${outName}/route

# Final reports
log_results "final"
check_routes           > ./log/pnr/${outName}.drc
report_qor             > ./log/pnr/${outName}.summary.rpt
report_utilization     > ./log/pnr/${outName}.util.rpt
report_design -routing > ./log/pnr/${outName}.routing.rpt
report_power           > ./log/pnr/${outName}.power.rpt
report_timing          > ./log/pnr/${outName}.timing.rpt
report_clock_qor -type summary > ./log/pnr/${outName}.clock.summary.rpt
report_clock_qor -type latency > ./log/pnr/${outName}.clock.latency.rpt
report_clock_qor -type area    > ./log/pnr/${outName}.clock.area.rpt

# Worst 30 slacks
set top_30_slacks [get_attr [get_timing_paths -nworst 1 -max_paths 30] slack]
echo "Worst 30 slacks: $top_30_slacks \n" > ./log/pnr/${outName}.worst30.slack
set sum 0.0
set count 0
foreach val $top_30_slacks {
    set sum [expr { $sum + $val }]
    incr count
}
if { $count > 0 } {
    set avg [expr { $sum / double($count) }]
    echo "average: $avg \n" >> ./log/pnr/${outName}.worst30.slack
}

#---------------------------------------------------------------------
# Pin / loc / tcl / out-flat output (single-mode, no projection scaling)
#---------------------------------------------------------------------
set lefDefOutVersion 5.7
sh mkdir -p output/global
write_def -include {bounds cells ports nets blockages} -routed_nets \
          -version $lefDefOutVersion output/global/${outName}.def

set box [join [join [join [collection_to_list [get_attribute [get_core_area] -name bounding_box]]]]]
set BoxWidth  [lindex $box 3]
set BoxHeight [lindex $box 4]

echo "\[INFO\]: Creating pin layer file"
set pin_layer_file [open "$::env(build_name).pin.layer" w]
foreach_in_collection thisPort [get_ports -filter {port_type=="signal"}] {
    set name  [get_attribute -objects $thisPort -name full_name]
    set layer [get_attribute -objects $thisPort -name layer_name]
    puts $pin_layer_file "$name $layer"
}
close $pin_layer_file

echo "\[INFO\]: Creating pin location file"
set pin_loc_file [open "$::env(build_name).pin.loc" w]
foreach_in_collection thisPort [get_ports -filter {port_type=="clock"}] {
    set name  [get_attribute -objects $thisPort -name full_name]
    set realx [lindex [lindex [get_attribute -objects $thisPort -name bbox] 0] 0]
    set realy [lindex [lindex [get_attribute -objects $thisPort -name bbox] 0] 1]
    set normx [expr [expr $realx * 10000.0] / $BoxWidth]
    set normy [expr [expr $realy * 10000.0] / $BoxHeight]
    puts $pin_loc_file "$name $normx $normy 0"
}
foreach_in_collection thisPort [get_ports -filter {port_type=="signal"}] {
    set name  [get_attribute -objects $thisPort -name full_name]
    set realx [lindex [lindex [get_attribute -objects $thisPort -name bbox] 0] 0]
    set realy [lindex [lindex [get_attribute -objects $thisPort -name bbox] 0] 1]
    set normx [expr [expr $realx * 10000.0] / $BoxWidth]
    set normy [expr [expr $realy * 10000.0] / $BoxHeight]
    puts $pin_loc_file "$name $normx $normy 0"
}
close $pin_loc_file

echo "\[INFO\]: Creating pin tcl file"
set pin_tcl_file [open "$::env(build_name).pin.tcl" w]
foreach_in_collection thisPort [get_ports -filter {port_type=="signal"}] {
    set name  [get_attribute -objects $thisPort -name full_name]
    set realx [lindex [lindex [get_attribute -objects $thisPort -name bbox] 0] 0]
    set realy [lindex [lindex [get_attribute -objects $thisPort -name bbox] 0] 1]
    set layer [get_attribute -objects $thisPort -name layer_name]
    puts $pin_tcl_file "set_individual_pin_constraints -ports \[get_ports $name\] -loc { $realx $realy } -allowed_layers $layer"
}
close $pin_tcl_file

echo "\[INFO\]: Creating out flat file"
set out_flat_file [open "out.flat" w]
foreach_in_collection thisCell [get_flat_cells] {
    if { ![get_attribute [get_cells $thisCell] -name is_memory_cell] } {
        set name  [get_attribute [get_cells $thisCell] -name full_name]
        set realx [lindex [lindex [get_attribute [get_cells $thisCell] -name bbox] 0] 0]
        set realy [lindex [lindex [get_attribute [get_cells $thisCell] -name bbox] 0] 1]
        set flatx [expr $realx - [expr $BoxWidth  / 2.0]]
        set flaty [expr $realy - [expr $BoxHeight / 2.0]]
        puts $out_flat_file "$name $flatx $flaty"
    }
}
close $out_flat_file

exit
