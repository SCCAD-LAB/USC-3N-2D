#=====================================================================
# ECG_innovus.tcl -- Self-contained PnR script (normal2D)
#
# Target tool : Cadence Innovus
# Design      : ECG point_scalar_mult
# Floorplan   : 57 x 57 um (margins 0)
# PDK family  : 3nm GAA FSPR (Front-Side Power Rail)
# Author      : SCCAD Lab
#
# Required inputs in current working directory:
#   - point_scalar_mult.netlist.v   (synthesized Verilog netlist)
#   - point_scalar_mult.sdc         (timing constraints)
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
#   - point_scalar_mult.{pin.layer, pin.loc, pin.tcl, scaled.cts}
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

# Design name controls input filenames (.netlist.v, .sdc, etc.)
set ::env(build_name) "point_scalar_mult"

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
set vars(CpuUsage)      16
set vars(FlowEffort)    standard
set vars(PowerEffort)   high

set vars(Route,HorizontalMetals) "M2 M4 M6 M8"
set vars(Route,VerticalMetals)   "M1 M3 M5 M7"
set vars(Route,DRIter)           20
set vars(Place,SiteDef)          $::fspr_site
set vars(Route,RedundantVias)    0

set vars(FloorPlan,AspectRatio)     1
set vars(FloorPlan,StdCellDensity)  0.7
set vars(FloorPlan,LeftMargin)      0
set vars(FloorPlan,BottomMargin)    0
set vars(FloorPlan,RightMargin)     0
set vars(FloorPlan,TopMargin)       0
set vars(FloorPlan,Width)           57
set vars(FloorPlan,Height)          57

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
## PIN PLACEMENT (inlined for ECG release)
##   This block restores the lab-tuned I/O pin placement for the
##   point_scalar_mult design.  Replace with your own placement to
##   re-target a different floorplan.
##=====================================================================
deselectAll
selectObject IO_Pin clk
moveGroupPins -loc 28.020 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin reset
moveGroupPins -loc 22.470 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_193_
moveGroupPins -loc 0.000 16.530 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_192_
moveGroupPins -loc 0.000 16.590 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_191_
moveGroupPins -loc 0.000 18.840 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_190_
moveGroupPins -loc 0.000 19.470 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_189_
moveGroupPins -loc 0.000 20.550 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_188_
moveGroupPins -loc 0.000 20.910 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_187_
moveGroupPins -loc 0.000 27.750 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_186_
moveGroupPins -loc 0.000 27.840 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_185_
moveGroupPins -loc 0.000 28.410 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_184_
moveGroupPins -loc 0.000 28.980 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_183_
moveGroupPins -loc 0.000 30.120 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_182_
moveGroupPins -loc 0.000 30.630 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_181_
moveGroupPins -loc 0.000 29.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_180_
moveGroupPins -loc 0.000 30.690 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_179_
moveGroupPins -loc 0.000 31.560 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_178_
moveGroupPins -loc 0.000 31.200 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_177_
moveGroupPins -loc 0.000 32.430 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_176_
moveGroupPins -loc 0.000 32.940 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_175_
moveGroupPins -loc 0.000 33.600 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_174_
moveGroupPins -loc 0.000 33.870 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_173_
moveGroupPins -loc 0.000 35.610 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_172_
moveGroupPins -loc 0.000 35.820 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_171_
moveGroupPins -loc 0.000 36.480 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_170_
moveGroupPins -loc 0.000 36.960 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_169_
moveGroupPins -loc 0.000 37.560 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_168_
moveGroupPins -loc 0.000 37.920 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_167_
moveGroupPins -loc 0.000 40.710 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_166_
moveGroupPins -loc 0.000 39.630 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_165_
moveGroupPins -loc 0.000 42.240 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_164_
moveGroupPins -loc 0.000 41.880 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_163_
moveGroupPins -loc 0.000 43.890 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_162_
moveGroupPins -loc 0.000 43.380 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_161_
moveGroupPins -loc 0.000 41.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_160_
moveGroupPins -loc 0.000 42.510 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_159_
moveGroupPins -loc 13.260 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_158_
moveGroupPins -loc 12.210 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_157_
moveGroupPins -loc 23.490 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_156_
moveGroupPins -loc 22.980 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_155_
moveGroupPins -loc 20.700 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_154_
moveGroupPins -loc 21.390 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_153_
moveGroupPins -loc 20.610 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_152_
moveGroupPins -loc 19.800 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_151_
moveGroupPins -loc 24.750 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_150_
moveGroupPins -loc 24.060 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_149_
moveGroupPins -loc 0.000 39.930 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_148_
moveGroupPins -loc 0.000 40.800 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_147_
moveGroupPins -loc 10.470 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_146_
moveGroupPins -loc 0.000 47.040 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_145_
moveGroupPins -loc 0.000 43.680 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_144_
moveGroupPins -loc 0.000 45.120 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_143_
moveGroupPins -loc 0.000 45.600 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_142_
moveGroupPins -loc 0.000 44.160 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_141_
moveGroupPins -loc 0.000 48.270 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_140_
moveGroupPins -loc 0.000 49.140 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_139_
moveGroupPins -loc 0.000 45.690 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_138_
moveGroupPins -loc 0.000 45.030 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_137_
moveGroupPins -loc 8.760 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_136_
moveGroupPins -loc 9.330 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_135_
moveGroupPins -loc 7.320 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_134_
moveGroupPins -loc 0.000 49.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_133_
moveGroupPins -loc 8.130 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_132_
moveGroupPins -loc 7.260 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_131_
moveGroupPins -loc 10.410 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_130_
moveGroupPins -loc 10.260 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_129_
moveGroupPins -loc 10.530 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_128_
moveGroupPins -loc 0.000 46.470 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_127_
moveGroupPins -loc 13.320 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_126_
moveGroupPins -loc 13.380 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_125_
moveGroupPins -loc 11.400 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_124_
moveGroupPins -loc 12.300 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_123_
moveGroupPins -loc 18.000 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_122_
moveGroupPins -loc 17.940 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_121_
moveGroupPins -loc 13.740 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_120_
moveGroupPins -loc 14.190 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_119_
moveGroupPins -loc 13.590 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_118_
moveGroupPins -loc 13.800 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_117_
moveGroupPins -loc 14.580 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_116_
moveGroupPins -loc 13.650 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_115_
moveGroupPins -loc 16.980 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_114_
moveGroupPins -loc 17.040 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_113_
moveGroupPins -loc 17.100 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_112_
moveGroupPins -loc 19.380 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_111_
moveGroupPins -loc 15.990 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_110_
moveGroupPins -loc 15.000 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_109_
moveGroupPins -loc 12.450 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_108_
moveGroupPins -loc 12.510 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_107_
moveGroupPins -loc 0.000 46.830 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_106_
moveGroupPins -loc 0.000 46.890 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_105_
moveGroupPins -loc 0.000 43.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_104_
moveGroupPins -loc 0.000 42.720 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_103_
moveGroupPins -loc 0.000 40.440 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_102_
moveGroupPins -loc 0.000 39.840 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_101_
moveGroupPins -loc 0.000 38.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_100_
moveGroupPins -loc 0.000 38.400 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_99_
moveGroupPins -loc 0.000 37.500 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_98_
moveGroupPins -loc 0.000 37.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_97_
moveGroupPins -loc 0.000 35.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_96_
moveGroupPins -loc 0.000 35.880 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_95_
moveGroupPins -loc 0.000 32.880 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_94_
moveGroupPins -loc 0.000 33.510 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_93_
moveGroupPins -loc 0.000 35.820 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x1_92_
moveGroupPins -loc 0.000 34.740 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_91_
moveGroupPins -loc 0.000 34.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_90_
moveGroupPins -loc 0.000 33.930 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_89_
moveGroupPins -loc 0.000 32.730 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_88_
moveGroupPins -loc 0.000 32.160 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_87_
moveGroupPins -loc 0.000 31.620 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_86_
moveGroupPins -loc 0.000 30.930 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_85_
moveGroupPins -loc 0.000 29.190 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_84_
moveGroupPins -loc 0.000 29.550 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_83_
moveGroupPins -loc 0.000 28.050 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_82_
moveGroupPins -loc 0.000 28.620 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_81_
moveGroupPins -loc 0.000 18.540 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_80_
moveGroupPins -loc 0.000 17.970 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_79_
moveGroupPins -loc 0.000 15.450 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_78_
moveGroupPins -loc 0.000 15.090 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_77_
moveGroupPins -loc 0.000 14.580 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_76_
moveGroupPins -loc 0.000 14.280 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_75_
moveGroupPins -loc 0.000 12.570 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_74_
moveGroupPins -loc 0.000 12.210 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_73_
moveGroupPins -loc 0.000 10.470 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_72_
moveGroupPins -loc 0.000 8.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_71_
moveGroupPins -loc 0.000 8.820 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_70_
moveGroupPins -loc 0.000 8.520 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_69_
moveGroupPins -loc 0.000 11.700 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_68_
moveGroupPins -loc 0.000 10.830 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_67_
moveGroupPins -loc 0.000 13.710 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_66_
moveGroupPins -loc 0.000 13.140 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_65_
moveGroupPins -loc 0.000 17.100 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_64_
moveGroupPins -loc 0.000 16.470 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_63_
moveGroupPins -loc 0.000 19.770 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_62_
moveGroupPins -loc 0.000 19.200 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_61_
moveGroupPins -loc 0.000 20.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_60_
moveGroupPins -loc 0.000 20.490 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_59_
moveGroupPins -loc 0.000 26.610 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_58_
moveGroupPins -loc 0.000 25.530 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_57_
moveGroupPins -loc 0.000 26.100 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_56_
moveGroupPins -loc 0.000 26.970 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_55_
moveGroupPins -loc 0.000 24.870 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_54_
moveGroupPins -loc 0.000 24.660 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_53_
moveGroupPins -loc 0.000 24.000 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_52_
moveGroupPins -loc 0.000 24.060 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_51_
moveGroupPins -loc 0.000 23.430 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_50_
moveGroupPins -loc 0.000 23.520 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_49_
moveGroupPins -loc 0.000 21.420 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_48_
moveGroupPins -loc 0.000 19.980 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_47_
moveGroupPins -loc 0.000 23.580 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_46_
moveGroupPins -loc 0.000 23.940 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_45_
moveGroupPins -loc 0.000 20.970 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_44_
moveGroupPins -loc 0.000 20.700 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_43_
moveGroupPins -loc 0.000 22.350 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_42_
moveGroupPins -loc 0.000 22.920 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_41_
moveGroupPins -loc 0.000 16.650 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_40_
moveGroupPins -loc 0.000 16.596 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x1_39_
moveGroupPins -loc 0.000 14.520 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_38_
moveGroupPins -loc 0.000 15.360 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_37_
moveGroupPins -loc 0.000 21.990 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_36_
moveGroupPins -loc 0.000 21.480 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_35_
moveGroupPins -loc 0.000 16.800 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_34_
moveGroupPins -loc 0.000 16.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_33_
moveGroupPins -loc 0.000 12.840 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_32_
moveGroupPins -loc 0.000 13.770 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_31_
moveGroupPins -loc 16.320 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_30_
moveGroupPins -loc 15.930 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_29_
moveGroupPins -loc 14.850 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_28_
moveGroupPins -loc 12.780 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_27_
moveGroupPins -loc 18.000 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_26_
moveGroupPins -loc 19.470 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_25_
moveGroupPins -loc 22.530 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_24_
moveGroupPins -loc 21.360 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_23_
moveGroupPins -loc 23.340 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_22_
moveGroupPins -loc 22.620 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_21_
moveGroupPins -loc 17.280 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_20_
moveGroupPins -loc 18.930 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_19_
moveGroupPins -loc 21.870 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_18_
moveGroupPins -loc 21.420 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_17_
moveGroupPins -loc 14.730 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_16_
moveGroupPins -loc 15.150 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_15_
moveGroupPins -loc 12.240 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_14_
moveGroupPins -loc 12.150 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_13_
moveGroupPins -loc 10.200 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_12_
moveGroupPins -loc 9.600 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_11_
moveGroupPins -loc 11.010 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_10_
moveGroupPins -loc 11.700 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_9_
moveGroupPins -loc 0.000 7.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_8_
moveGroupPins -loc 0.000 7.680 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_7_
moveGroupPins -loc 0.000 7.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_6_
moveGroupPins -loc 6.960 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_5_
moveGroupPins -loc 0.000 7.890 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_4_
moveGroupPins -loc 0.000 8.160 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_3_
moveGroupPins -loc 8.010 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_2_
moveGroupPins -loc 8.460 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_1_
moveGroupPins -loc 9.060 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x1_0_
moveGroupPins -loc 8.520 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_193_
moveGroupPins -loc 56.994 27.540 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_192_
moveGroupPins -loc 56.994 28.050 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_191_
moveGroupPins -loc 56.994 34.680 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_190_
moveGroupPins -loc 56.994 35.040 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_189_
moveGroupPins -loc 56.994 30.630 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_188_
moveGroupPins -loc 56.994 30.420 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_187_
moveGroupPins -loc 56.994 31.560 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_186_
moveGroupPins -loc 56.994 32.070 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_185_
moveGroupPins -loc 56.994 43.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_184_
moveGroupPins -loc 56.994 43.320 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_183_
moveGroupPins -loc 56.994 35.820 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_182_
moveGroupPins -loc 37.200 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_181_
moveGroupPins -loc 56.994 33.810 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_180_
moveGroupPins -loc 56.994 33.600 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_179_
moveGroupPins -loc 36.660 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_178_
moveGroupPins -loc 36.990 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_177_
moveGroupPins -loc 36.720 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_176_
moveGroupPins -loc 36.600 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_175_
moveGroupPins -loc 36.180 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_174_
moveGroupPins -loc 36.360 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_173_
moveGroupPins -loc 36.648 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y1_172_
moveGroupPins -loc 36.420 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_171_
moveGroupPins -loc 36.000 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_170_
moveGroupPins -loc 35.340 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_169_
moveGroupPins -loc 34.620 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_168_
moveGroupPins -loc 34.680 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_167_
moveGroupPins -loc 35.760 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_166_
moveGroupPins -loc 36.240 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_165_
moveGroupPins -loc 35.940 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_164_
moveGroupPins -loc 36.480 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_163_
moveGroupPins -loc 35.700 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_162_
moveGroupPins -loc 34.890 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_161_
moveGroupPins -loc 37.350 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_160_
moveGroupPins -loc 36.540 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_159_
moveGroupPins -loc 35.550 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_158_
moveGroupPins -loc 34.830 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_157_
moveGroupPins -loc 35.880 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_156_
moveGroupPins -loc 36.300 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_155_
moveGroupPins -loc 38.790 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_154_
moveGroupPins -loc 38.040 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_153_
moveGroupPins -loc 40.890 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_152_
moveGroupPins -loc 42.030 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_151_
moveGroupPins -loc 43.920 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_150_
moveGroupPins -loc 43.980 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_149_
moveGroupPins -loc 46.350 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_148_
moveGroupPins -loc 45.690 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_147_
moveGroupPins -loc 45.390 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_146_
moveGroupPins -loc 45.120 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_145_
moveGroupPins -loc 44.160 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_144_
moveGroupPins -loc 44.100 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_143_
moveGroupPins -loc 44.580 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_142_
moveGroupPins -loc 44.040 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_141_
moveGroupPins -loc 41.820 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_140_
moveGroupPins -loc 41.460 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_139_
moveGroupPins -loc 56.994 43.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_138_
moveGroupPins -loc 42.780 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_137_
moveGroupPins -loc 48.660 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_136_
moveGroupPins -loc 49.200 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_135_
moveGroupPins -loc 48.000 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_134_
moveGroupPins -loc 48.360 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_133_
moveGroupPins -loc 56.994 44.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_132_
moveGroupPins -loc 56.994 44.520 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_131_
moveGroupPins -loc 56.994 47.910 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_130_
moveGroupPins -loc 56.994 48.000 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_129_
moveGroupPins -loc 56.994 43.590 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_128_
moveGroupPins -loc 56.994 43.380 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_127_
moveGroupPins -loc 56.994 41.010 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_126_
moveGroupPins -loc 56.994 40.500 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_125_
moveGroupPins -loc 56.994 42.810 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_124_
moveGroupPins -loc 56.994 42.510 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_123_
moveGroupPins -loc 56.994 42.150 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_122_
moveGroupPins -loc 56.994 41.940 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_121_
moveGroupPins -loc 56.994 36.960 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_120_
moveGroupPins -loc 56.994 37.320 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_119_
moveGroupPins -loc 56.994 36.750 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_118_
moveGroupPins -loc 56.994 37.260 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_117_
moveGroupPins -loc 56.994 39.570 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_116_
moveGroupPins -loc 56.994 39.000 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_115_
moveGroupPins -loc 56.994 33.000 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_114_
moveGroupPins -loc 56.994 33.510 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_113_
moveGroupPins -loc 56.994 37.560 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_112_
moveGroupPins -loc 56.994 38.490 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_111_
moveGroupPins -loc 56.994 38.430 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_110_
moveGroupPins -loc 56.994 38.550 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_109_
moveGroupPins -loc 56.994 32.940 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_108_
moveGroupPins -loc 56.994 32.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_107_
moveGroupPins -loc 56.994 35.880 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_106_
moveGroupPins -loc 56.994 35.310 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_105_
moveGroupPins -loc 56.994 36.810 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_104_
moveGroupPins -loc 56.994 36.120 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_103_
moveGroupPins -loc 56.994 30.360 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_102_
moveGroupPins -loc 56.994 30.690 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_101_
moveGroupPins -loc 56.994 34.980 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_100_
moveGroupPins -loc 56.994 35.250 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_99_
moveGroupPins -loc 56.994 35.610 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_98_
moveGroupPins -loc 56.994 35.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_97_
moveGroupPins -loc 56.994 31.620 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_96_
moveGroupPins -loc 56.994 31.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_95_
moveGroupPins -loc 56.994 32.700 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_94_
moveGroupPins -loc 56.994 32.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_93_
moveGroupPins -loc 56.994 35.100 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_92_
moveGroupPins -loc 56.994 35.190 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_91_
moveGroupPins -loc 56.994 29.190 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_90_
moveGroupPins -loc 56.994 27.990 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_89_
moveGroupPins -loc 56.994 30.060 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_88_
moveGroupPins -loc 56.994 31.200 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_87_
moveGroupPins -loc 56.994 32.580 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_86_
moveGroupPins -loc 56.994 32.130 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_85_
moveGroupPins -loc 56.994 22.920 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_84_
moveGroupPins -loc 56.994 23.430 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_83_
moveGroupPins -loc 56.994 28.680 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_82_
moveGroupPins -loc 56.994 27.750 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_81_
moveGroupPins -loc 56.994 24.660 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_80_
moveGroupPins -loc 56.994 24.960 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_79_
moveGroupPins -loc 36.570 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_78_
moveGroupPins -loc 36.090 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_77_
moveGroupPins -loc 35.610 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_76_
moveGroupPins -loc 35.550 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_75_
moveGroupPins -loc 35.730 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_74_
moveGroupPins -loc 35.670 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_73_
moveGroupPins -loc 36.300 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_72_
moveGroupPins -loc 36.630 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_71_
moveGroupPins -loc 36.210 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_70_
moveGroupPins -loc 36.252 0.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y1_69_
moveGroupPins -loc 56.994 22.980 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_68_
moveGroupPins -loc 56.994 23.730 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_67_
moveGroupPins -loc 37.350 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_66_
moveGroupPins -loc 38.250 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_65_
moveGroupPins -loc 36.480 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_64_
moveGroupPins -loc 36.420 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_63_
moveGroupPins -loc 56.994 24.360 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_62_
moveGroupPins -loc 56.994 24.090 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_61_
moveGroupPins -loc 38.910 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_60_
moveGroupPins -loc 40.080 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_59_
moveGroupPins -loc 36.360 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_58_
moveGroupPins -loc 36.360 0.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y1_57_
moveGroupPins -loc 56.994 24.030 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_56_
moveGroupPins -loc 56.994 24.300 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_55_
moveGroupPins -loc 40.500 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_54_
moveGroupPins -loc 41.130 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_53_
moveGroupPins -loc 41.730 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_52_
moveGroupPins -loc 42.660 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_51_
moveGroupPins -loc 56.994 23.970 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_50_
moveGroupPins -loc 56.994 25.230 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_49_
moveGroupPins -loc 43.830 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_48_
moveGroupPins -loc 43.200 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_47_
moveGroupPins -loc 56.994 23.670 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_46_
moveGroupPins -loc 56.994 23.790 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_45_
moveGroupPins -loc 56.994 23.850 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_44_
moveGroupPins -loc 56.994 23.490 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_43_
moveGroupPins -loc 56.994 11.340 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_42_
moveGroupPins -loc 56.994 11.280 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_41_
moveGroupPins -loc 44.790 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_40_
moveGroupPins -loc 45.630 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_39_
moveGroupPins -loc 56.994 29.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_38_
moveGroupPins -loc 56.994 28.320 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_37_
moveGroupPins -loc 56.994 11.700 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_36_
moveGroupPins -loc 56.994 11.400 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_35_
moveGroupPins -loc 56.994 12.840 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_34_
moveGroupPins -loc 56.994 12.570 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_33_
moveGroupPins -loc 56.994 30.000 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_32_
moveGroupPins -loc 56.994 30.300 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_31_
moveGroupPins -loc 56.994 14.010 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_30_
moveGroupPins -loc 56.994 13.710 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_29_
moveGroupPins -loc 56.994 13.140 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_28_
moveGroupPins -loc 56.994 13.350 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_27_
moveGroupPins -loc 56.994 25.290 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_26_
moveGroupPins -loc 56.994 24.900 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_25_
moveGroupPins -loc 56.994 20.850 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_24_
moveGroupPins -loc 56.994 21.120 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_23_
moveGroupPins -loc 56.994 22.350 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_22_
moveGroupPins -loc 56.994 22.560 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_21_
moveGroupPins -loc 56.994 29.850 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_20_
moveGroupPins -loc 56.994 30.120 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_19_
moveGroupPins -loc 56.994 23.370 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_18_
moveGroupPins -loc 56.994 23.796 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y1_17_
moveGroupPins -loc 56.994 24.420 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_16_
moveGroupPins -loc 56.994 24.600 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_15_
moveGroupPins -loc 56.994 32.652 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y1_14_
moveGroupPins -loc 56.994 32.370 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_13_
moveGroupPins -loc 56.994 28.110 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_12_
moveGroupPins -loc 56.994 28.380 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_11_
moveGroupPins -loc 56.994 25.530 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_10_
moveGroupPins -loc 56.994 26.040 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_9_
moveGroupPins -loc 56.994 34.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_8_
moveGroupPins -loc 56.994 34.440 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_7_
moveGroupPins -loc 56.994 27.810 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_6_
moveGroupPins -loc 56.994 27.480 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_5_
moveGroupPins -loc 56.994 25.170 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_4_
moveGroupPins -loc 56.994 25.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_3_
moveGroupPins -loc 56.994 33.450 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_2_
moveGroupPins -loc 56.994 32.880 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y1_1_
moveGroupPins -loc 56.994 30.060 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y1_0_
moveGroupPins -loc 56.994 29.910 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin zero1
moveGroupPins -loc 0.000 39.360 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_150_
moveGroupPins -loc 0.000 47.130 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_149_
moveGroupPins -loc 0.000 47.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_148_
moveGroupPins -loc 0.000 48.000 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_147_
moveGroupPins -loc 0.000 48.480 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_146_
moveGroupPins -loc 0.000 48.570 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_145_
moveGroupPins -loc 0.000 48.840 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_144_
moveGroupPins -loc 0.000 48.780 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_143_
moveGroupPins -loc 0.000 48.900 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_142_
moveGroupPins -loc 0.000 49.350 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_141_
moveGroupPins -loc 0.000 50.010 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_140_
moveGroupPins -loc 0.000 50.880 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_139_
moveGroupPins -loc 0.000 51.450 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_138_
moveGroupPins -loc 0.000 51.960 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_137_
moveGroupPins -loc 0.000 51.900 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_136_
moveGroupPins -loc 0.000 51.720 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_135_
moveGroupPins -loc 0.000 51.660 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_134_
moveGroupPins -loc 0.000 52.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_133_
moveGroupPins -loc 0.000 51.948 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_132_
moveGroupPins -loc 0.000 52.320 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_131_
moveGroupPins -loc 0.000 52.590 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_130_
moveGroupPins -loc 0.000 52.800 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_129_
moveGroupPins -loc 0.000 52.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_128_
moveGroupPins -loc 0.000 52.920 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_127_
moveGroupPins -loc 0.000 52.884 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_126_
moveGroupPins -loc 0.000 52.980 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_125_
moveGroupPins -loc 0.000 53.100 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_124_
moveGroupPins -loc 0.000 53.460 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_123_
moveGroupPins -loc 0.000 53.670 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_122_
moveGroupPins -loc 0.000 54.240 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_121_
moveGroupPins -loc 0.000 54.540 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_120_
moveGroupPins -loc 0.000 54.600 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_119_
moveGroupPins -loc 3.210 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_118_
moveGroupPins -loc 3.270 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_117_
moveGroupPins -loc 3.150 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_116_
moveGroupPins -loc 0.000 54.330 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_115_
moveGroupPins -loc 0.000 54.660 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_114_
moveGroupPins -loc 0.000 54.390 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_113_
moveGroupPins -loc 0.000 53.400 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_112_
moveGroupPins -loc 0.000 53.340 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_111_
moveGroupPins -loc 0.000 53.520 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_110_
moveGroupPins -loc 0.000 53.460 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_109_
moveGroupPins -loc 0.000 54.180 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_108_
moveGroupPins -loc 0.000 55.110 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_107_
moveGroupPins -loc 0.000 56.040 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_106_
moveGroupPins -loc 1.140 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_105_
moveGroupPins -loc 0.000 55.770 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_104_
moveGroupPins -loc 1.620 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_103_
moveGroupPins -loc 1.680 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_102_
moveGroupPins -loc 1.560 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_101_
moveGroupPins -loc 1.200 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_100_
moveGroupPins -loc 1.500 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_99_
moveGroupPins -loc 1.620 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_98_
moveGroupPins -loc 2.070 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_97_
moveGroupPins -loc 2.130 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_96_
moveGroupPins -loc 2.820 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_95_
moveGroupPins -loc 2.880 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_94_
moveGroupPins -loc 2.640 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_93_
moveGroupPins -loc 2.700 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_92_
moveGroupPins -loc 3.330 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_91_
moveGroupPins -loc 3.276 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_90_
moveGroupPins -loc 3.930 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_89_
moveGroupPins -loc 3.990 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_88_
moveGroupPins -loc 4.260 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_87_
moveGroupPins -loc 4.320 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_86_
moveGroupPins -loc 4.380 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_85_
moveGroupPins -loc 4.890 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_84_
moveGroupPins -loc 5.760 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_83_
moveGroupPins -loc 6.030 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_82_
moveGroupPins -loc 5.700 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_81_
moveGroupPins -loc 4.830 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_80_
moveGroupPins -loc 4.680 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_79_
moveGroupPins -loc 4.200 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_78_
moveGroupPins -loc 4.620 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_77_
moveGroupPins -loc 5.220 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_76_
moveGroupPins -loc 6.540 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_75_
moveGroupPins -loc 7.110 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_74_
moveGroupPins -loc 5.820 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_73_
moveGroupPins -loc 6.630 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_72_
moveGroupPins -loc 7.170 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_71_
moveGroupPins -loc 6.480 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_70_
moveGroupPins -loc 5.880 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_69_
moveGroupPins -loc 5.430 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_68_
moveGroupPins -loc 4.470 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_67_
moveGroupPins -loc 3.750 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_66_
moveGroupPins -loc 3.810 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_65_
moveGroupPins -loc 3.390 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_64_
moveGroupPins -loc 3.204 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_63_
moveGroupPins -loc 3.090 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_62_
moveGroupPins -loc 2.760 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_61_
moveGroupPins -loc 1.260 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_60_
moveGroupPins -loc 0.000 56.550 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_59_
moveGroupPins -loc 0.000 56.340 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_58_
moveGroupPins -loc 0.000 55.710 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_57_
moveGroupPins -loc 0.000 55.470 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_56_
moveGroupPins -loc 0.000 55.170 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_55_
moveGroupPins -loc 0.000 55.050 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_54_
moveGroupPins -loc 0.000 54.840 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_53_
moveGroupPins -loc 0.000 54.780 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_52_
moveGroupPins -loc 0.000 54.252 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_51_
moveGroupPins -loc 0.000 54.324 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_50_
moveGroupPins -loc 0.000 54.450 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_49_
moveGroupPins -loc 0.000 54.030 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_48_
moveGroupPins -loc 0.000 53.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_47_
moveGroupPins -loc 0.000 53.610 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_46_
moveGroupPins -loc 0.000 53.676 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_45_
moveGroupPins -loc 0.000 52.530 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_44_
moveGroupPins -loc 0.000 51.360 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_43_
moveGroupPins -loc 0.000 51.090 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_42_
moveGroupPins -loc 0.000 51.030 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_41_
moveGroupPins -loc 0.000 51.150 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_40_
moveGroupPins -loc 0.000 50.820 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_39_
moveGroupPins -loc 0.000 50.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_38_
moveGroupPins -loc 0.000 50.520 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_37_
moveGroupPins -loc 0.000 50.460 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_36_
moveGroupPins -loc 0.000 50.220 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_35_
moveGroupPins -loc 0.000 49.920 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_34_
moveGroupPins -loc 0.000 49.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_33_
moveGroupPins -loc 0.000 50.160 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_32_
moveGroupPins -loc 0.000 50.280 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_31_
moveGroupPins -loc 0.000 50.340 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_30_
moveGroupPins -loc 0.000 50.220 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_29_
moveGroupPins -loc 0.000 49.932 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_28_
moveGroupPins -loc 0.000 49.650 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_27_
moveGroupPins -loc 0.000 49.410 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_26_
moveGroupPins -loc 0.000 48.852 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_25_
moveGroupPins -loc 0.000 48.630 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_24_
moveGroupPins -loc 0.000 48.210 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_23_
moveGroupPins -loc 0.000 47.700 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_22_
moveGroupPins -loc 0.000 47.400 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_21_
moveGroupPins -loc 0.000 47.580 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_20_
moveGroupPins -loc 0.000 47.910 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_19_
moveGroupPins -loc 0.000 48.060 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_18_
moveGroupPins -loc 0.000 48.330 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_17_
moveGroupPins -loc 0.000 49.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_16_
moveGroupPins -loc 0.000 49.290 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_15_
moveGroupPins -loc 0.000 49.470 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_14_
moveGroupPins -loc 0.000 49.068 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_13_
moveGroupPins -loc 0.000 47.988 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_12_
moveGroupPins -loc 0.000 47.340 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_11_
moveGroupPins -loc 0.000 47.190 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_10_
moveGroupPins -loc 0.000 46.770 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_9_
moveGroupPins -loc 0.000 46.560 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_8_
moveGroupPins -loc 0.000 46.260 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_7_
moveGroupPins -loc 0.000 45.960 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_6_
moveGroupPins -loc 0.000 46.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_5_
moveGroupPins -loc 0.000 46.200 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_4_
moveGroupPins -loc 0.000 46.410 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_3_
moveGroupPins -loc 0.000 46.710 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_2_
moveGroupPins -loc 0.000 46.836 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin c_1_
moveGroupPins -loc 0.000 46.950 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin c_0_
moveGroupPins -loc 0.000 46.764 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin done
moveGroupPins -loc 0.000 52.440 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_193_
moveGroupPins -loc 0.000 15.690 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_192_
moveGroupPins -loc 0.000 16.140 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_191_
moveGroupPins -loc 0.000 18.480 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_190_
moveGroupPins -loc 0.000 19.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_189_
moveGroupPins -loc 0.000 20.430 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_188_
moveGroupPins -loc 0.000 21.300 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_187_
moveGroupPins -loc 0.000 27.792 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_186_
moveGroupPins -loc 0.000 28.110 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_185_
moveGroupPins -loc 0.000 28.500 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_184_
moveGroupPins -loc 0.000 29.250 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_183_
moveGroupPins -loc 0.000 29.820 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_182_
moveGroupPins -loc 0.000 30.060 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_181_
moveGroupPins -loc 0.000 29.370 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_180_
moveGroupPins -loc 0.000 30.390 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_179_
moveGroupPins -loc 0.000 31.830 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_178_
moveGroupPins -loc 0.000 30.840 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_177_
moveGroupPins -loc 0.000 32.370 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_176_
moveGroupPins -loc 0.000 33.150 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_175_
moveGroupPins -loc 0.000 33.690 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_174_
moveGroupPins -loc 0.000 34.260 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_173_
moveGroupPins -loc 0.000 35.550 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_172_
moveGroupPins -loc 0.000 36.540 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_171_
moveGroupPins -loc 0.000 36.300 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_170_
moveGroupPins -loc 0.000 37.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_169_
moveGroupPins -loc 0.000 37.290 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_168_
moveGroupPins -loc 0.000 37.740 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_167_
moveGroupPins -loc 0.000 41.340 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_166_
moveGroupPins -loc 0.000 39.888 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_165_
moveGroupPins -loc 0.000 42.780 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_164_
moveGroupPins -loc 0.000 41.760 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_163_
moveGroupPins -loc 0.000 44.070 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_162_
moveGroupPins -loc 0.000 44.100 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_161_
moveGroupPins -loc 0.000 41.280 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_160_
moveGroupPins -loc 0.000 42.180 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_159_
moveGroupPins -loc 12.960 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_158_
moveGroupPins -loc 12.360 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_157_
moveGroupPins -loc 23.820 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_156_
moveGroupPins -loc 23.070 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_155_
moveGroupPins -loc 20.880 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_154_
moveGroupPins -loc 21.900 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_153_
moveGroupPins -loc 21.300 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_152_
moveGroupPins -loc 19.620 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_151_
moveGroupPins -loc 25.140 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_150_
moveGroupPins -loc 24.810 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_149_
moveGroupPins -loc 0.000 39.990 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_148_
moveGroupPins -loc 0.000 40.500 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_147_
moveGroupPins -loc 0.000 47.664 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_146_
moveGroupPins -loc 9.240 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_145_
moveGroupPins -loc 0.000 43.950 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_144_
moveGroupPins -loc 0.000 44.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_143_
moveGroupPins -loc 0.000 44.580 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_142_
moveGroupPins -loc 0.000 44.250 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_141_
moveGroupPins -loc 0.000 48.120 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_140_
moveGroupPins -loc 0.000 49.392 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_139_
moveGroupPins -loc 0.000 45.210 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_138_
moveGroupPins -loc 0.000 44.940 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_137_
moveGroupPins -loc 8.700 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_136_
moveGroupPins -loc 9.390 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_135_
moveGroupPins -loc 8.190 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_134_
moveGroupPins -loc 0.000 48.690 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_133_
moveGroupPins -loc 7.590 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_132_
moveGroupPins -loc 0.000 49.710 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_131_
moveGroupPins -loc 10.050 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_130_
moveGroupPins -loc 9.660 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_129_
moveGroupPins -loc 9.570 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_128_
moveGroupPins -loc 0.000 47.376 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_127_
moveGroupPins -loc 13.500 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_126_
moveGroupPins -loc 13.440 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_125_
moveGroupPins -loc 10.590 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_124_
moveGroupPins -loc 12.570 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_123_
moveGroupPins -loc 17.160 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_122_
moveGroupPins -loc 18.060 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_121_
moveGroupPins -loc 13.200 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_120_
moveGroupPins -loc 13.680 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_119_
moveGroupPins -loc 13.020 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_118_
moveGroupPins -loc 13.140 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_117_
moveGroupPins -loc 14.130 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_116_
moveGroupPins -loc 13.212 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_115_
moveGroupPins -loc 15.930 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_114_
moveGroupPins -loc 17.100 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_113_
moveGroupPins -loc 17.220 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_112_
moveGroupPins -loc 19.470 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_111_
moveGroupPins -loc 16.500 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_110_
moveGroupPins -loc 13.860 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_109_
moveGroupPins -loc 12.780 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_108_
moveGroupPins -loc 12.420 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_107_
moveGroupPins -loc 0.000 46.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_106_
moveGroupPins -loc 0.000 46.620 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_105_
moveGroupPins -loc 0.000 43.620 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_104_
moveGroupPins -loc 0.000 43.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_103_
moveGroupPins -loc 0.000 40.890 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_102_
moveGroupPins -loc 0.000 40.320 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_101_
moveGroupPins -loc 0.000 39.450 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_100_
moveGroupPins -loc 0.000 38.160 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_99_
moveGroupPins -loc 0.000 37.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_98_
moveGroupPins -loc 0.000 38.310 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_97_
moveGroupPins -loc 0.000 36.600 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_96_
moveGroupPins -loc 0.000 36.576 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_95_
moveGroupPins -loc 0.000 33.090 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_94_
moveGroupPins -loc 0.000 33.750 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_93_
moveGroupPins -loc 0.000 36.000 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_92_
moveGroupPins -loc 0.000 35.700 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_91_
moveGroupPins -loc 0.000 33.990 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_90_
moveGroupPins -loc 0.000 34.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_89_
moveGroupPins -loc 0.000 32.670 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_88_
moveGroupPins -loc 0.000 31.980 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_87_
moveGroupPins -loc 0.000 31.500 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_86_
moveGroupPins -loc 0.000 30.540 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_85_
moveGroupPins -loc 0.000 28.800 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_84_
moveGroupPins -loc 0.000 29.490 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_83_
moveGroupPins -loc 0.000 27.660 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_82_
moveGroupPins -loc 0.000 28.740 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_81_
moveGroupPins -loc 0.000 18.150 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_80_
moveGroupPins -loc 0.000 17.820 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_79_
moveGroupPins -loc 0.000 15.750 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_78_
moveGroupPins -loc 0.000 15.270 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_77_
moveGroupPins -loc 0.000 14.700 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_76_
moveGroupPins -loc 0.000 14.070 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_75_
moveGroupPins -loc 0.000 12.510 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_74_
moveGroupPins -loc 0.000 11.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_73_
moveGroupPins -loc 0.000 9.660 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_72_
moveGroupPins -loc 0.000 7.530 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_71_
moveGroupPins -loc 0.000 8.070 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_70_
moveGroupPins -loc 0.000 7.620 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_69_
moveGroupPins -loc 0.000 10.950 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_68_
moveGroupPins -loc 0.000 10.530 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_67_
moveGroupPins -loc 0.000 13.650 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_66_
moveGroupPins -loc 0.000 12.270 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_65_
moveGroupPins -loc 0.000 17.430 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_64_
moveGroupPins -loc 0.000 16.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_63_
moveGroupPins -loc 0.000 19.710 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_62_
moveGroupPins -loc 0.000 19.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_61_
moveGroupPins -loc 0.000 21.600 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_60_
moveGroupPins -loc 0.000 21.360 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_59_
moveGroupPins -loc 0.000 26.910 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_58_
moveGroupPins -loc 0.000 25.890 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_57_
moveGroupPins -loc 0.000 26.220 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_56_
moveGroupPins -loc 0.000 27.210 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_55_
moveGroupPins -loc 0.000 24.480 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_54_
moveGroupPins -loc 0.000 24.600 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_53_
moveGroupPins -loc 0.000 24.180 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_52_
moveGroupPins -loc 0.000 23.880 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_51_
moveGroupPins -loc 0.000 23.190 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_50_
moveGroupPins -loc 0.000 23.472 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_49_
moveGroupPins -loc 0.000 21.750 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_48_
moveGroupPins -loc 0.000 19.290 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_47_
moveGroupPins -loc 0.000 22.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_46_
moveGroupPins -loc 0.000 24.330 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_45_
moveGroupPins -loc 0.000 21.456 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_44_
moveGroupPins -loc 0.000 21.660 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_43_
moveGroupPins -loc 0.000 22.620 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_42_
moveGroupPins -loc 0.000 22.896 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_41_
moveGroupPins -loc 0.000 15.630 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_40_
moveGroupPins -loc 0.000 16.230 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_39_
moveGroupPins -loc 0.000 14.220 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_38_
moveGroupPins -loc 0.000 14.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_37_
moveGroupPins -loc 0.000 22.290 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_36_
moveGroupPins -loc 0.000 22.560 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_35_
moveGroupPins -loc 0.000 15.990 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_34_
moveGroupPins -loc 0.000 15.870 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_33_
moveGroupPins -loc 0.000 12.390 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_32_
moveGroupPins -loc 0.000 13.380 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_31_
moveGroupPins -loc 17.220 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_30_
moveGroupPins -loc 16.140 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_29_
moveGroupPins -loc 14.520 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_28_
moveGroupPins -loc 12.300 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_27_
moveGroupPins -loc 17.820 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_26_
moveGroupPins -loc 19.800 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_25_
moveGroupPins -loc 22.830 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_24_
moveGroupPins -loc 22.200 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_23_
moveGroupPins -loc 23.520 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_22_
moveGroupPins -loc 21.270 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_21_
moveGroupPins -loc 17.160 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_20_
moveGroupPins -loc 18.690 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_19_
moveGroupPins -loc 21.720 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_18_
moveGroupPins -loc 20.340 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_17_
moveGroupPins -loc 16.080 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_16_
moveGroupPins -loc 15.270 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_15_
moveGroupPins -loc 11.160 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_14_
moveGroupPins -loc 11.550 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_13_
moveGroupPins -loc 10.920 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_12_
moveGroupPins -loc 10.860 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_11_
moveGroupPins -loc 10.740 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_10_
moveGroupPins -loc 11.640 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_9_
moveGroupPins -loc 6.810 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_8_
moveGroupPins -loc 0.000 7.230 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_7_
moveGroupPins -loc 6.900 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_6_
moveGroupPins -loc 6.570 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_5_
moveGroupPins -loc 0.000 7.632 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin x3_4_
moveGroupPins -loc 0.000 7.440 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_3_
moveGroupPins -loc 7.380 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_2_
moveGroupPins -loc 7.770 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_1_
moveGroupPins -loc 8.940 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin x3_0_
moveGroupPins -loc 8.220 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_193_
moveGroupPins -loc 56.994 28.230 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_192_
moveGroupPins -loc 56.994 27.930 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_191_
moveGroupPins -loc 56.994 34.380 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_190_
moveGroupPins -loc 56.994 34.260 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_189_
moveGroupPins -loc 56.994 29.952 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_188_
moveGroupPins -loc 56.994 29.808 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_187_
moveGroupPins -loc 56.994 32.520 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_186_
moveGroupPins -loc 56.994 32.250 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_185_
moveGroupPins -loc 56.994 43.140 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_184_
moveGroupPins -loc 56.994 43.500 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_183_
moveGroupPins -loc 56.994 35.430 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_182_
moveGroupPins -loc 37.470 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_181_
moveGroupPins -loc 56.994 34.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_180_
moveGroupPins -loc 56.994 34.560 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_179_
moveGroupPins -loc 36.870 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_178_
moveGroupPins -loc 36.504 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_177_
moveGroupPins -loc 36.576 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_176_
moveGroupPins -loc 36.930 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_175_
moveGroupPins -loc 35.964 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_174_
moveGroupPins -loc 36.780 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_173_
moveGroupPins -loc 35.460 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_172_
moveGroupPins -loc 35.040 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_171_
moveGroupPins -loc 34.980 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_170_
moveGroupPins -loc 35.820 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_169_
moveGroupPins -loc 34.560 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_168_
moveGroupPins -loc 34.596 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_167_
moveGroupPins -loc 34.770 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_166_
moveGroupPins -loc 35.400 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_165_
moveGroupPins -loc 35.640 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_164_
moveGroupPins -loc 35.100 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_163_
moveGroupPins -loc 35.280 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_162_
moveGroupPins -loc 32.880 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_161_
moveGroupPins -loc 37.530 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_160_
moveGroupPins -loc 36.720 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_159_
moveGroupPins -loc 36.252 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_158_
moveGroupPins -loc 34.956 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_157_
moveGroupPins -loc 35.220 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_156_
moveGroupPins -loc 35.316 57.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_155_
moveGroupPins -loc 39.150 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_154_
moveGroupPins -loc 38.550 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_153_
moveGroupPins -loc 40.710 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_152_
moveGroupPins -loc 42.870 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_151_
moveGroupPins -loc 45.450 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_150_
moveGroupPins -loc 44.940 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_149_
moveGroupPins -loc 46.500 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_148_
moveGroupPins -loc 46.590 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_147_
moveGroupPins -loc 46.710 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_146_
moveGroupPins -loc 46.080 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_145_
moveGroupPins -loc 43.860 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_144_
moveGroupPins -loc 44.640 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_143_
moveGroupPins -loc 44.730 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_142_
moveGroupPins -loc 43.800 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_141_
moveGroupPins -loc 42.960 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_140_
moveGroupPins -loc 42.420 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_139_
moveGroupPins -loc 56.994 43.770 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_138_
moveGroupPins -loc 56.994 44.070 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_137_
moveGroupPins -loc 48.270 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_136_
moveGroupPins -loc 49.140 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_135_
moveGroupPins -loc 49.080 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_134_
moveGroupPins -loc 49.500 57.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_133_
moveGroupPins -loc 56.994 44.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_132_
moveGroupPins -loc 56.994 45.210 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_131_
moveGroupPins -loc 56.994 49.830 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_130_
moveGroupPins -loc 56.994 49.530 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_129_
moveGroupPins -loc 56.994 43.200 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_128_
moveGroupPins -loc 56.994 44.010 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_127_
moveGroupPins -loc 56.994 40.740 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_126_
moveGroupPins -loc 56.994 40.320 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_125_
moveGroupPins -loc 56.994 42.900 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_124_
moveGroupPins -loc 56.994 42.450 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_123_
moveGroupPins -loc 56.994 41.460 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_122_
moveGroupPins -loc 56.994 41.190 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_121_
moveGroupPins -loc 56.994 37.440 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_120_
moveGroupPins -loc 56.994 38.160 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_119_
moveGroupPins -loc 56.994 36.570 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_118_
moveGroupPins -loc 56.994 36.690 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_117_
moveGroupPins -loc 56.994 39.630 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_116_
moveGroupPins -loc 56.994 38.880 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_115_
moveGroupPins -loc 56.994 33.690 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_114_
moveGroupPins -loc 56.994 33.990 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_113_
moveGroupPins -loc 56.994 37.110 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_112_
moveGroupPins -loc 56.994 37.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_111_
moveGroupPins -loc 56.994 37.620 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_110_
moveGroupPins -loc 56.994 38.010 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_109_
moveGroupPins -loc 56.994 33.270 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_108_
moveGroupPins -loc 56.994 33.390 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_107_
moveGroupPins -loc 56.994 35.856 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_106_
moveGroupPins -loc 56.994 35.550 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_105_
moveGroupPins -loc 56.994 36.420 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_104_
moveGroupPins -loc 56.994 35.280 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_103_
moveGroupPins -loc 56.994 30.180 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_102_
moveGroupPins -loc 56.994 30.384 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_101_
moveGroupPins -loc 56.994 34.500 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_100_
moveGroupPins -loc 56.994 34.800 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_99_
moveGroupPins -loc 56.994 35.370 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_98_
moveGroupPins -loc 56.994 35.208 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_97_
moveGroupPins -loc 56.994 33.210 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_96_
moveGroupPins -loc 56.994 32.976 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_95_
moveGroupPins -loc 56.994 32.190 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_94_
moveGroupPins -loc 56.994 32.820 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_93_
moveGroupPins -loc 56.994 33.552 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_92_
moveGroupPins -loc 56.994 33.870 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_91_
moveGroupPins -loc 56.994 29.700 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_90_
moveGroupPins -loc 56.994 29.370 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_89_
moveGroupPins -loc 56.994 29.880 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_88_
moveGroupPins -loc 56.994 30.960 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_87_
moveGroupPins -loc 56.994 31.980 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_86_
moveGroupPins -loc 56.994 31.410 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_85_
moveGroupPins -loc 56.994 23.910 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_84_
moveGroupPins -loc 56.994 24.180 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_83_
moveGroupPins -loc 56.994 28.080 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_82_
moveGroupPins -loc 56.994 26.940 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_81_
moveGroupPins -loc 56.994 23.610 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_80_
moveGroupPins -loc 56.994 25.770 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_79_
moveGroupPins -loc 36.576 0.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_78_
moveGroupPins -loc 36.150 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_77_
moveGroupPins -loc 35.790 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_76_
moveGroupPins -loc 35.712 0.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_75_
moveGroupPins -loc 35.880 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_74_
moveGroupPins -loc 35.784 0.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_73_
moveGroupPins -loc 36.030 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_72_
moveGroupPins -loc 36.930 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_71_
moveGroupPins -loc 36.432 0.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_70_
moveGroupPins -loc 36.690 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_69_
moveGroupPins -loc 56.994 20.910 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_68_
moveGroupPins -loc 56.994 23.310 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_67_
moveGroupPins -loc 37.440 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_66_
moveGroupPins -loc 38.100 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_65_
moveGroupPins -loc 36.648 0.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_64_
moveGroupPins -loc 36.780 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_63_
moveGroupPins -loc 56.994 23.550 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_62_
moveGroupPins -loc 56.994 23.190 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_61_
moveGroupPins -loc 38.970 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_60_
moveGroupPins -loc 39.630 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_59_
moveGroupPins -loc 36.504 0.000 -layer M5 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_58_
moveGroupPins -loc 36.840 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_57_
moveGroupPins -loc 56.994 23.472 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_56_
moveGroupPins -loc 56.994 23.130 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_55_
moveGroupPins -loc 40.290 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_54_
moveGroupPins -loc 41.040 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_53_
moveGroupPins -loc 41.790 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_52_
moveGroupPins -loc 42.360 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_51_
moveGroupPins -loc 56.994 23.400 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_50_
moveGroupPins -loc 56.994 25.650 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_49_
moveGroupPins -loc 43.560 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_48_
moveGroupPins -loc 44.070 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_47_
moveGroupPins -loc 56.994 22.290 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_46_
moveGroupPins -loc 56.994 22.860 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_45_
moveGroupPins -loc 56.994 22.320 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_44_
moveGroupPins -loc 56.994 22.230 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_43_
moveGroupPins -loc 56.994 11.100 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_42_
moveGroupPins -loc 56.994 10.800 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_41_
moveGroupPins -loc 44.850 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_40_
moveGroupPins -loc 45.450 0.000 -layer M3 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_39_
moveGroupPins -loc 56.994 27.210 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_38_
moveGroupPins -loc 56.994 26.100 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_37_
moveGroupPins -loc 56.994 11.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_36_
moveGroupPins -loc 56.994 11.376 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_35_
moveGroupPins -loc 56.994 11.820 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_34_
moveGroupPins -loc 56.994 11.664 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_33_
moveGroupPins -loc 56.994 28.770 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_32_
moveGroupPins -loc 56.994 29.100 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_31_
moveGroupPins -loc 56.994 12.720 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_30_
moveGroupPins -loc 56.994 12.630 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_29_
moveGroupPins -loc 56.994 12.390 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_28_
moveGroupPins -loc 56.994 12.240 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_27_
moveGroupPins -loc 56.994 23.250 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_26_
moveGroupPins -loc 56.994 23.040 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_25_
moveGroupPins -loc 56.994 21.300 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_24_
moveGroupPins -loc 56.994 21.750 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_23_
moveGroupPins -loc 56.994 22.020 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_22_
moveGroupPins -loc 56.994 22.080 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_21_
moveGroupPins -loc 56.994 28.950 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_20_
moveGroupPins -loc 56.994 28.620 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_19_
moveGroupPins -loc 56.994 23.544 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_18_
moveGroupPins -loc 56.994 23.724 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_17_
moveGroupPins -loc 56.994 24.240 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_16_
moveGroupPins -loc 56.994 25.350 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_15_
moveGroupPins -loc 56.994 32.724 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_14_
moveGroupPins -loc 56.994 32.544 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_13_
moveGroupPins -loc 56.994 29.280 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_12_
moveGroupPins -loc 56.994 29.232 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_11_
moveGroupPins -loc 56.994 26.640 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_10_
moveGroupPins -loc 56.994 26.880 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_9_
moveGroupPins -loc 56.994 33.750 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_8_
moveGroupPins -loc 56.994 34.416 -layer M4 -width 0.018 -depth 0.018 -withOverlap
deselectAll
selectObject IO_Pin y3_7_
moveGroupPins -loc 56.994 28.890 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_6_
moveGroupPins -loc 56.994 28.500 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_5_
moveGroupPins -loc 56.994 25.710 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_4_
moveGroupPins -loc 56.994 25.590 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_3_
moveGroupPins -loc 56.994 33.330 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_2_
moveGroupPins -loc 56.994 33.060 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_1_
moveGroupPins -loc 56.994 29.430 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin y3_0_
moveGroupPins -loc 56.994 29.520 -layer M2 -width 0.012 -depth 0.012 -withOverlap
deselectAll
selectObject IO_Pin zero3
moveGroupPins -loc 0.000 39.210 -layer M2 -width 0.012 -depth 0.012 -withOverlap
##=====================================================================
## END PIN PLACEMENT
##=====================================================================

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
