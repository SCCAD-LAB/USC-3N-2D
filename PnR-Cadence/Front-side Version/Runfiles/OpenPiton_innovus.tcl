#=====================================================================
# OpenPiton_innovus.tcl -- Self-contained PnR script (normal2D)
#
# Target tool : Cadence Innovus
# Design      : OpenPiton tile (28 SRAM macros)
# Floorplan   : 333.102 x 401.640 um (margins 2)
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
# To run:
#   bash run.sh                    -> invokes innovus
#
# Run produces:
#   - impl/normal2D*.enc           (design checkpoints)
#   - log/normal2D*.summary.rpt.gz (per-stage summary)
#   - RPT/                         (postRoute reports)
#   - normal2D.{def, spef.gz, analysis.summary.rpt.gz}
#   - tile.{pin.layer, pin.loc, pin.tcl, scaled.cts}
#=====================================================================

#=====================================================================
# USER CONFIGURATION
#=====================================================================
# Set PDK_ROOT before invoking this script:
#   export PDK_ROOT=/path/to/USC-3N-2D
# All other paths derive from PDK_ROOT.

if {![info exists ::env(PDK_ROOT)]} {
    puts "ERROR: please set PDK_ROOT to the USC-3N-2D repository root before sourcing this script"
    exit 1
}
set techDir [file normalize $::env(PDK_ROOT)]
source [file join $techDir {PDK Development/Front-side Version/selected_collateral.tcl}]
fspr_require_matched_release
set ::env(TECHLEF_DIR) [file dirname $::fspr_tech_lef(Cadence)]
set ::env(MACROLEF_DIR) [file dirname $::fspr_std_lef(Cadence)]
set ::env(MACROLIB_DIR) [file dirname $::fspr_lib(Cadence)]
set ::env(TCH_DIR) [file dirname $::fspr_qrc_tch]
# CAPTBL_DIR is optional (some PDKs ship captbl files; FSPR uses QRC techfiles).
# Uncomment if your PDK has a 2d_captbl dir:
#   set ::env(CAPTBL_DIR) "$techDir/2d_captbl"

# OpenPiton hard-macro paths (28 SRAM/RF macros).  These are auto-set from
# the standard PDK layout; override before invoking the script if your
# SRAM library lives elsewhere.
if {![info exists ::env(HARDMACROLEF_DIR)] && [file isdirectory "$techDir/openpiton_mem_L3_256k/2d_hard_lef"]} {
    set ::env(HARDMACROLEF_DIR) "$techDir/openpiton_mem_L3_256k/2d_hard_lef"
}
if {![info exists ::env(HARDMACROLIB_DIR)] && [file isdirectory "$techDir/openpiton_mem_L3_256k/2d_hard_lib"]} {
    set ::env(HARDMACROLIB_DIR) "$techDir/openpiton_mem_L3_256k/2d_hard_lib"
}

# Design name controls input filenames (.netlist.v, .sdc, etc.)
set ::env(build_name) "tile"

# OpenPiton requires hard-macro NDM/LEF for its SRAMs.  Set these env vars
# to the SRAM library locations before invoking the script if your PDK
# delivers them outside the default 2d_lef/2d_db trees.
#   setenv HARDMACROLEF_DIR /path/to/sram_lef
#   setenv HARDMACROLIB_DIR /path/to/sram_lib

# Input-file checks
if { ![ file exists $::env(build_name).sdc ] } {
    puts "\n\[ERROR\] missing $::env(build_name).sdc\n"; exit 1
}
if { ![ file exists $::env(build_name).netlist.v ] && ![ file exists $::env(build_name).netlist.v.gz ] } {
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

set vars(FloorPlan,AspectRatio)     0.829349
set vars(FloorPlan,StdCellDensity)  0.7
set vars(FloorPlan,LeftMargin)      2
set vars(FloorPlan,BottomMargin)    2
set vars(FloorPlan,RightMargin)     2
set vars(FloorPlan,TopMargin)       2
set vars(FloorPlan,Width)           333.102
set vars(FloorPlan,Height)          401.640

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

set vars(2D_PNR,placeMaxDensity)        0.9
set vars(2D_PNR,maxRouteLayer)          8
set vars(2D_PNR,minRouteLayer)          1
set vars(2D_PNR,maxPinRouteLayer)       8
set vars(2D_PNR,minPinRouteLayer)       1
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

set vars(iterOpt,detailRefinePlace) 0

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

# No-op (placeholder retained for compatibility with previous flow hooks)
proc miv_tracking { dstage wmode } { return }

proc sumRpt { outFile } {
    if { [string range $outFile end-2 end] == ".gz" } {
        set outFile [string range $outFile 0 end-3]
    }
    summaryReport -noHtml -outFile $outFile
    catch { exec gzip -f $outFile }
}

# Sets up LEF/SDC/netlist; single-die, single-corner.
proc prc_Enc_setupConfig { } {
    uplevel \#0 {
        suppressMessage ENCLF-200
        suppressMessage ENCLF-201
        suppressMessage LEFPARS-2043
        suppressMessage LEFPARS-2007
        suppressMessage TECHLIB-459
        suppressMessage TECHLIB-436

        set LEFfiles {}

        # TECHLEF setup
        set techLEF "$::env(TECHLEF_DIR)"
        if { $techLEF != "" } {
            foreach fileName [list $::fspr_tech_lef(Cadence)] {
                lappend LEFfiles $fileName
            }
        }

        # MACROLEF setup
        set macroLEF "$::env(MACROLEF_DIR)"
        if { $macroLEF != "" } {
            foreach fileName [list $::fspr_std_lef(Cadence)] {
                lappend LEFfiles $fileName
            }
        }

        # HARDMACROLEF setup (optional)
        if { [info exists ::env(HARDMACROLEF_DIR)] } {
            set hardmacroLEF "$::env(HARDMACROLEF_DIR)"
            if { $hardmacroLEF != "" } {
                foreach fileName [glob -d $hardmacroLEF *lef] {
                    lappend LEFfiles $fileName
                }
            }
        }

        # SDC setup
        set SDCfile $::env(build_name).sdc

        # Netlist setup
        set NETlist $::env(build_name).netlist.v
        if { [file exists $::env(build_name).netlist.v.gz] } {
            set NETlist $::env(build_name).netlist.v.gz
        }

        setLibraryUnit -time $vars(LibUnit,Time) -cap $vars(LibUnit,Cap)

        set rda_Input(ui_settop) 0
        set rda_Input(ui_leffile) $LEFfiles

        global init
        set init_design_uniquify 0
        set init_import_mode {-treatUndefinedCellAsBbox 0 -keepEmptyModule 1 }
        set init_verilog $NETlist
        set init_design_netlisttype {Verilog}
        set init_design_settop {0}
        set init_top_cell {}
        set init_io_file ""
        set init_lef_file $LEFfiles
        set delaycal_use_default_delay_limit {1000}
        set delaycal_default_net_delay {1000.0ps}
        set delaycal_default_net_load {0.5pf}
        set delaycal_input_transition_delay {0.0ps}
        set extract_shrink_factor {1.0}
        set init_oa_ref_lib {}
        set init_abstract_view {}
        set init_layout_view {}
        set init_pwr_net {VDD}
        set init_gnd_net {VSS}
    }
}

# Single-corner MMMC: curRC / curLib / curCon / curDel / curAnal
proc prc_Enc_mmmcConfig { } {
    uplevel \#0 {
        set LIBfiles {}

        # MACROLIB setup
        set macroLIB "$::env(MACROLIB_DIR)"
        if { $macroLIB != "" } {
            foreach fileName [list $::fspr_lib(Cadence)] {
                lappend LIBfiles $fileName
            }
        }

        # HARDMACROLIB setup (optional)
        if { [info exists ::env(HARDMACROLIB_DIR)] } {
            set hardmacroLIB "$::env(HARDMACROLIB_DIR)"
            if { $hardmacroLIB != "" } {
                foreach fileName [glob -d $hardmacroLIB *lib] {
                    lappend LIBfiles $fileName
                }
            }
        }

        set CAPfiles {}
        if { [info exists ::env(CAPTBL_DIR)] } {
            set CAP "$::env(CAPTBL_DIR)"
            if { $CAP != "" } {
                foreach fileName [glob -d $CAP *capTbl] {
                    lappend CAPfiles $fileName
                }
            }
        }

        if {[llength $CAPfiles] > 1} {error "Expected one explicit cap-table file"}
        set CAPfile [lindex $CAPfiles 0]
        set TCHfile ""
        set MAPfile ""
        if { [info exists ::env(TCH_DIR)] } {
            set TCH "$::env(TCH_DIR)"
            if { $TCH != "" } {
                set TCHfile $::fspr_qrc_tch
                set MAPfile $::fspr_qrc_map
            }
        }

        # Single-corner MMMC
        if { [info exists ::env(CAPTBL_DIR)] && ![info exists ::env(TCH_DIR)] } {
            create_rc_corner -name curRC -cap_table $CAPfile
        } elseif { ![info exists ::env(CAPTBL_DIR)] && [info exists ::env(TCH_DIR)] } {
            create_rc_corner -name curRC -qx_tech_file $TCHfile
        } elseif { [info exists ::env(CAPTBL_DIR)] && [info exists ::env(TCH_DIR)] } {
            create_rc_corner -name curRC -cap_table $CAPfile
            update_rc_corner -name curRC -qx_tech_file $TCHfile
        }
        if { $MAPfile ne "" } {
            setExtractRCMode -engine postRoute -lefTechFileMap $MAPfile
        }

        if { [info exists vars(ExtractionEngine,ScalingRes)] } {
            set scaling_res $vars(ExtractionEngine,ScalingRes)
        } else { set scaling_res 1 }
        if { [info exists vars(ExtractionEngine,ScalingCap)] } {
            set scaling_cap $vars(ExtractionEngine,ScalingCap)
        } else { set scaling_cap 1 }

        set scaling_res1 "$scaling_res $scaling_res $scaling_res"
        set scaling_res2 "$scaling_res"
        set scaling_cap1 "$scaling_cap $scaling_cap $scaling_cap"
        set scaling_cap2 "$scaling_cap"

        update_rc_corner -name curRC -postRoute_cap     $scaling_cap1
        update_rc_corner -name curRC -postRoute_clkcap  $scaling_cap1
        update_rc_corner -name curRC -postRoute_clkres  $scaling_res1
        update_rc_corner -name curRC -postRoute_res     $scaling_res1
        update_rc_corner -name curRC -postRoute_xcap    $scaling_cap1
        update_rc_corner -name curRC -preRoute_cap      $scaling_cap2
        update_rc_corner -name curRC -preRoute_clkcap   {0}
        update_rc_corner -name curRC -preRoute_clkres   {0}
        update_rc_corner -name curRC -preRoute_res      $scaling_res2
        update_rc_corner -name curRC -T                 {25}
        create_library_set    -name curLib  -timing $LIBfiles
        create_constraint_mode -name curCon -sdc_files "$SDCfile"
        create_delay_corner   -name curDel  -library_set curLib -rc_corner curRC
        create_analysis_view  -name curAnal -constraint_mode curCon -delay_corner curDel
    }
}

# Default toggle-rate based switching activity (no VCD).
proc prc_Enc_setSwitchingActivity { } {
    uplevel \#0 {
        set_default_switching_activity -reset
        set_default_switching_activity \
            -duty            $vars(SwitchingActivity,DutyRatio) \
            -input_activity  $vars(SwitchingActivity,IpToggle) \
            -seq_activity    $vars(SwitchingActivity,RegToggle)

        set clock_ports [get_ports -filter {is_clock_used_as_clock==true} -quiet]
        if { $clock_ports != "" } {
            set_switching_activity \
                -duty       $vars(SwitchingActivity,DutyRatio) \
                -activity   $vars(SwitchingActivity,ClkToggle) \
                -input_port $clock_ports
        }
    }
}

# Single-die, single-mode PnR settings.
proc prc_Enc_setPNRmodes { } {
    uplevel \#0 {
        set placeMaxDensity      $vars(2D_PNR,placeMaxDensity)
        set maxRouteLayer        $vars(2D_PNR,maxRouteLayer)
        set minRouteLayer        $vars(2D_PNR,minRouteLayer)
        set maxPinRouteLayer     $vars(2D_PNR,maxPinRouteLayer)
        set minPinRouteLayer     $vars(2D_PNR,minPinRouteLayer)
        set leakageToDynamicRatio $vars(2D_PNR,leakageToDynamicRatio)
        set iteration            $vars(2D_PNR,routingIteration)

        # place mode -- timing-driven
        setPlaceMode -reset
        setPlaceMode \
            -maxDensity   $placeMaxDensity \
            -timingEffort high

        # trial-route mode
        setTrialRouteMode -reset
        setTrialRouteMode \
            -maxRouteLayer $maxRouteLayer \
            -minRouteLayer $minRouteLayer

        # pin-assignment mode
        setPinAssignMode -reset
        setPinAssignMode -maxLayer $maxPinRouteLayer -minLayer $minPinRouteLayer

        # delay-calculation mode
        setDelayCalMode -reset
        setDelayCalMode \
            -reportOutBound false \
            -SIAware true \
            -engine aae

        setAnalysisMode -reset
        setAnalysisMode \
            -analysisType onChipVariation \
            -cppr both

        # nano-route mode -- timing/SI driven
        setNanoRouteMode -reset
        setNanoRouteMode \
            -drouteEndIteration $iteration \
            -drouteFixAntenna false \
            -routeBottomRoutingLayer $minRouteLayer \
            -routeTopRoutingLayer $maxRouteLayer \
            -routeUnconnectedPorts true \
            -routeWithTimingDriven true \
            -routewithSiDriven true \
            -routeWithViaOnlyForStandardCellPin true

        # optimization mode
        setOptMode -reset
        setOptMode -maxDensity $placeMaxDensity \
            -addInst true \
            -addInstancePrefix OPT \
            -allEndPoints true \
            -effort high \
            -fixCap true \
            -fixTran true \
            -fixFanoutLoad true \
            -leakageToDynamicRatio $leakageToDynamicRatio \
            -postRouteAllowOverlap false \
            -PowerEffort high \
            -simplifyNetlist true \
            -verbose true
    }
}

#=====================================================================
# MAIN FLOW (normal2D)
#=====================================================================

suppressMessage ENCPTN-1027
suppressMessage ENCPTN-1520
set tcl_precision 6
setMultiCpuUsage -localCpu 16
if { [info exists vars(CpuUsage)] } {
    setMultiCpuUsage -localCpu $vars(CpuUsage)
}

set outName "normal2D"

# ---- Fresh setup ----
prc_Enc_setupConfig
prc_Enc_mmmcConfig

init_design -setup curAnal -hold curAnal
set_analysis_view -setup curAnal -hold curAnal

setDesignMode -reset
setDesignMode -process $vars(LibUnit,Process) \
              -flowEffort $vars(FlowEffort) \
              -powerEffort $vars(PowerEffort)

report_resource -verbose

floorPlan -d $vars(FloorPlan,Width) $vars(FloorPlan,Height) \
          $vars(FloorPlan,LeftMargin) \
          $vars(FloorPlan,BottomMargin) \
          $vars(FloorPlan,RightMargin) \
          $vars(FloorPlan,TopMargin)

prc_Enc_setPNRmodes

# RC extraction effort
if { [info exists vars(ExtractionEngine,effort)] && $vars(ExtractionEngine,effort) == "low" } {
    setExtractRCMode -engine postRoute -effortLevel low -coupled true
} elseif { [info exists vars(ExtractionEngine,postRoute)] && $vars(ExtractionEngine,postRoute) == "IQRC" } {
    setExtractRCMode -engine postRoute -effortLevel high -coupled true -tQuantusForPostRoute false
} elseif { [info exists vars(ExtractionEngine,postRoute)] && $vars(ExtractionEngine,postRoute) == "TQRC" } {
    setExtractRCMode -engine postRoute -effortLevel medium -coupled true \
        -tQuantusForPostRoute true -tQuantusModelFile rc_model.bin
} else {
    setExtractRCMode -engine postRoute -effortLevel high -coupled true
}

# User override hook: load extra floorplan / config from current dir
if { [file exists "config.tcl"] }     { source config.tcl }
if { [file exists "config_flp.tcl"] } { source config_flp.tcl }

# OpenPiton ships a pre-placed macro DEF (28 SRAM macros).  Read it here if
# present.  Without this DEF, the floorplan will be empty of macros.
if { [file exists "./impl/FloorPlan.def"] } {
    defIn -floorplan ./impl/FloorPlan.def
} elseif { [file exists "./impl/FloorPlan.def.gz"] } {
    defIn -floorplan ./impl/FloorPlan.def.gz
} else {
    puts "\[WARN\] impl/FloorPlan.def not found -- floorplan will have no macros"
}

if { [info exists vars(saveDesign,flp)] && $vars(saveDesign,flp) == 1 } {
    saveDesign impl/${outName}_flp.enc
}
sumRpt log/${outName}_flp.summary.rpt.gz

# Switching activity + pre-CTS clock uncertainty
prc_Enc_setSwitchingActivity
set_interactive_constraint_modes [all_constraint_modes -active]
set_clock_uncertainty $vars(ClockUncertainty,preCTS) [all_clocks]

report_resource -verbose

# Initial placement + pin assignment
placeDesign -prePlaceOpt
assignIoPins

##=====================================================================
## PIN PLACEMENT
##   OpenPiton uses an external pin.tcl file (~5000 lines) shipped
##   alongside this script.  It is sourced here after assignIoPins.
##=====================================================================
if { [file exists "$::env(build_name).pin.tcl"] } {
    source "$::env(build_name).pin.tcl"
} else {
    puts "\[WARN\] $::env(build_name).pin.tcl not found -- using assignIoPins defaults"
}

if { [info exists vars(saveDesign,place)] && $vars(saveDesign,place) == 1 } {
    saveDesign impl/${outName}_place.enc
}
sumRpt log/${outName}_place.summary.rpt.gz
report_resource -verbose

# preCTS optimization
optDesign -preCTS
report_resource -verbose

# Refresh switching activity + CTS clock uncertainty
prc_Enc_setSwitchingActivity
set_interactive_constraint_modes [all_constraint_modes -active]
set_clock_uncertainty $vars(ClockUncertainty,CTS) [all_clocks]
set cts_override_minimum_skew_target true

if { [info exists vars(saveDesign,preCTS)] && $vars(saveDesign,preCTS) == 1 } {
    saveDesign impl/${outName}_preCTS.enc
}
sumRpt log/${outName}_preCTS.summary.rpt.gz

#---------------------------------------------------------------------
# CTS specification (inlined from $::env(build_name).ctsvar)
#---------------------------------------------------------------------
set cts_buf  {BUFx8 BUFx7 BUFx6 BUFx5 BUFx4 BUFx3 BUFx2 BUFx10 BUFx1}
set cts_inv  {INVx8 INVx7 INVx6 INVx5 INVx4 INVx3 INVx2 INVx16 INVx14 INVx12 INVx10 INVx1}
set max_skew  auto
set max_trans auto
set max_fo    16

set_ccopt_property buffer_cells     $cts_buf
set_ccopt_property inverter_cells   $cts_inv
set_ccopt_property target_skew      $max_skew
set_ccopt_property target_max_trans $max_trans
set_ccopt_property max_fanout       $max_fo

set_ccopt_effort -high
clock_opt_design -prefix cts

if { [info exists vars(saveDesign,ccopt)] && $vars(saveDesign,ccopt) == 1 } {
    saveDesign impl/${outName}_ccopt.enc
}
sumRpt log/${outName}_ccopt.summary.rpt.gz

# postCTS optimization
set_interactive_constraint_modes [all_constraint_modes -active]
set_clock_uncertainty $vars(ClockUncertainty,postCTS) [all_clocks]
optDesign -postCTS
if { [info exists vars(saveDesign,postCTS)] && $vars(saveDesign,postCTS) == 1 } {
    saveDesign impl/${outName}_postCTS.enc
}
sumRpt log/${outName}_postCTS.summary.rpt.gz
report_resource -verbose

# Routing
routeDesign -globalDetail
if { [info exists vars(saveDesign,route)] && $vars(saveDesign,route) == 1 } {
    saveDesign impl/${outName}_route.enc
}
sumRpt log/${outName}_route.summary.rpt.gz
report_resource -verbose

# postRoute optimization
set_interactive_constraint_modes [all_constraint_modes -active]
set_clock_uncertainty $vars(ClockUncertainty,postRoute) [all_clocks]
setDelayCalMode -siAware true
setAnalysisMode -analysisType onChipVariation -cppr both
optDesign -postRoute -setup -outDir RPT -prefix PR -expandedViews

saveDesign impl/${outName}.enc
report_resource -verbose

# Final extraction
if { [info exists vars(ExtractionEngine,effort)] && $vars(ExtractionEngine,effort) == "low" } {
    setExtractRCMode -engine postRoute -effortLevel low -coupled true \
        -total_c_th 0.0 -relative_c_th 0.0 -coupling_c_th 0.0 -capFilterMode relAndCoup
} else {
    setExtractRCMode -engine postRoute -effortLevel high -coupled true \
        -total_c_th 0.0 -relative_c_th 0.0 -coupling_c_th 0.0 -capFilterMode relAndCoup
}
extractRC
rcOut -spef impl/${outName}.spef.gz

set lefDefOutVersion 5.7
defOut -floorplan -netlist ${outName}.def

sumRpt log/${outName}.summary.rpt.gz
report_analysis_summary > ${outName}.analysis.summary.rpt.gz
setPtnPinStatus * * fixed

# Final clock-tree report
report_ccopt_clock_trees > $::env(build_name).scaled.cts
report_clock_timing -type summary >> $::env(build_name).scaled.cts
report_clock_timing -type latency -histogram -histogram_range 0.02 >> $::env(build_name).scaled.cts

#---------------------------------------------------------------------
# Final design-geometry reports (single-mode -- no projection scaling)
#---------------------------------------------------------------------
set BoxWidth   [dbGet top.fplan.box_sizex]
set BoxHeight  [dbGet top.fplan.box_sizey]
set CoreWidth  [dbGet top.fplan.coreBox_sizex]
set CoreHeight [dbGet top.fplan.coreBox_sizey]
set Corellx    [dbGet top.fplan.coreBox_llx]
set Corelly    [dbGet top.fplan.coreBox_lly]

set pin_layer_file [open "$::env(build_name).pin.layer" w]
foreach_in_collection thisPort [get_ports] {
    set name  [get_property $thisPort hierarchical_name]
    set layer [dbGet [dbGetFTermByName $name].layer.num]
    puts $pin_layer_file "$name $layer"
}
close $pin_layer_file

set pin_loc_file [open "$::env(build_name).pin.loc" w]
foreach_in_collection thisPort [get_ports] {
    set name  [get_property $thisPort hierarchical_name]
    set realx [get_property $thisPort x_coordinate]
    set realy [get_property $thisPort y_coordinate]
    set normx [expr [expr $realx * 10000.0] / $BoxWidth]
    set normy [expr [expr $realy * 10000.0] / $BoxHeight]
    puts $pin_loc_file "$name $normx $normy 0"
}
close $pin_loc_file

set pin_tcl_file [open "$::env(build_name).pin.tcl" w]
foreach_in_collection thisPort [get_ports] {
    set name  [get_property $thisPort hierarchical_name]
    set realx [get_property $thisPort x_coordinate]
    set realy [get_property $thisPort y_coordinate]
    set layer [dbGet [dbGetFTermByName $name].layer.name]
    set width [dbGet [dbGetFTermByName $name].width]
    set depth [dbGet [dbGetFTermByName $name].depth]
    puts $pin_tcl_file "deselectAll"
    puts $pin_tcl_file "selectObject IO_Pin $name"
    puts $pin_tcl_file "moveGroupPins -loc $realx $realy -layer $layer -width $width -depth $depth -withOverlap"
}
close $pin_tcl_file

set out_flat_file [open "out.flat" w]
foreach thisCell [dbGet top.insts.name *] {
    if { ![get_property [get_cells $thisCell] is_memory_cell] } {
        set name   $thisCell
        set realx  [dbGet [dbGetInstByName $name].pt_x]
        set realy  [dbGet [dbGetInstByName $name].pt_y]
        set realx  [expr $realx - $Corellx]
        set realy  [expr $realy - $Corelly]
        set sizex  [dbGet [dbGetInstByName $name].cell.size_x]
        set sizey  [dbGet [dbGetInstByName $name].cell.size_y]
        set realcx [expr $realx + [expr $sizex / 2.0]]
        set realcy [expr $realy + [expr $sizey / 2.0]]
        set flatx  [expr $realcx - [expr $CoreWidth  / 2.0]]
        set flaty  [expr $realcy - [expr $CoreHeight / 2.0]]
        puts $out_flat_file "$name $flatx $flaty"
    }
}
close $out_flat_file

set fp_info [open "fp.info" w]
puts $fp_info "\[INFO\] 2D DESIGN FOOTPRINT"
puts $fp_info "\[INFO\] CoreWidth:  $CoreWidth"
puts $fp_info "\[INFO\] CoreHeight: $CoreHeight"
puts $fp_info "\[INFO\] DieWidth:   $BoxWidth"
puts $fp_info "\[INFO\] DieHeight:  $BoxHeight"
close $fp_info

report_resource -verbose
exit
