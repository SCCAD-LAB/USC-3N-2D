/*********************************************************************************
* Name:         [ ICV_3nm_drcclean ]
* Owner:        [ GTCAD ]
* Last Change:  [ 2026/05/01 ]
* Synopsis:     [ Scoped LVS deck for the 6T_drcclean trial. Identical to the
*                 production oa/ICV_3nm.rs except: (1) the fin layer assign is
*                 commented out; (2) every `(fin and Active)`, `(nactive and fin)`,
*                 and `(pactive and fin)` term has had the fin intersection
*                 removed, because WS1 deleted all fin shapes from 6T_drcclean
*                 and snapped each ACT polygon's Y range to the fin's Y range
*                 ([0.015,0.045] / [0.075,0.105]). Active alone now occupies the
*                 region fin used to mark, so dropping the intersection
*                 preserves channel/SD geometry.
*                 DO NOT use this deck on any other library — production
*                 oa/ICV_3nm.rs is unchanged. ]
*********************************************************************************/
#include <icv.rh>

library(
        format = GDSII,
        cell = "AND2x1",
        library_name = "inlib"
);

schematic_netlist_db = schematic (
        schematic_file = {{"INV.sp", SPICE}}
);

text_options (
        allow_all_numeric       = true,
        layout_ground           = {"VSS"},
        layout_power            = {"VDD"}
);

net_options (
        schematic_ground = {"VSS"},
        schematic_power  = {"VDD"}
);


well       = assign({{1}});
well_text  = assign_text({{1, 251}});
// fin     = assign({{2}});  // disabled for 6T_drcclean: WS1 deleted fin shapes

P_SUB      = assign({{3}});
P_SUB_text = assign_text({{3, 251}});
Gate       = assign({{7}});
Dummy      = assign({{8}});
GCut       = assign({{10}});
Active     = assign({{11}});
Nselect    = assign({{12}});
Pselect    = assign({{13}});
VBPR       = assign({{14}});
MBPR       = assign({{15}});
MBPR_text  = assign_text({{15, 251}});
LIG        = assign({{16}});
LISD       = assign({{17}});
V0_i       = assign({{18}});
M1         = assign({{19}});
M1_text    = assign_text({{19, 251}});
V1         = assign({{21}});
M2         = assign({{20}});
M2_text    = assign_text({{20, 251}});
V2         = assign({{25}});
M3         = assign({{30}});
M3_text    = assign_text({{30, 251}});
V3         = assign({{35}});
M4         = assign({{40}});
M4_text    = assign_text({{40, 251}});
V4         = assign({{45}});
M5         = assign({{50}});
M5_text    = assign_text({{50, 251}});
V5         = assign({{55}});
M6         = assign({{60}});
M6_text    = assign_text({{60, 251}});
V6         = assign({{65}});
M7         = assign({{70}});
M7_text    = assign_text({{70, 251}});
V7         = assign({{75}});
M8         = assign({{80}});
M8_text    = assign_text({{80, 251}});
V8         = assign({{85}});
M9         = assign({{90}});
M9_text    = assign_text({{90, 251}});
V9         = assign({{95}});
SDT        = assign({{88}});
SLVT       = assign({{97}});
LVT        = assign({{98}});
SRAMDRC    = assign({{99}});
SRAMVT     = assign({{110}});


sub = cell_extent(
        cell_list = {"*"}
);

nactive = Active and Nselect;
pactive = Active and Pselect;

ActGate = Gate not GCut;

// 2026-05-02: Dummy marker support added (Path D in DUMMY_LAYER_FEASIBILITY.md).
// Each dummy gate has a Dummy rectangle drawn over it (same X/Y as the Gate
// stripe). To prevent dummy gates from extracting as transistors when ACT
// happens to overlap them, exclude Dummy from the polysilicon set and from
// source/drain regions — exactly matching the GT3 reference deck pattern
// (gt3_main.lvs.rs lines 164, 168, 174).
//
// Original deck had `(fin and Active)` here; rewritten to `Active` for
// 6T_drcclean because WS1 snapped ACT Y to the former fin Y range and
// deleted fin shapes.
//
// History (kept as commented context):
// ngate = ActGate and nactive;
// pgate = ActGate and pactive;
// ngate = (ActGate interacting nactive) and Nselect and fin;
// pgate = (ActGate interacting pactive) and Pselect and fin;
// ngate = (ActGate interacting nactive) and Nselect and (fin and Active);  // production
// pgate = (ActGate interacting pactive) and Pselect and (fin and Active);  // production
// ngate = (ActGate interacting nactive) and Nselect and Active;            // pre-Dummy
// pgate = (ActGate interacting pactive) and Pselect and Active;            // pre-Dummy

gPolyReal = ActGate not Dummy;
ngate = (gPolyReal interacting nactive) and Nselect and Active;
pgate = (gPolyReal interacting pactive) and Pselect and Active;
fpoly = gPolyReal not (ngate or pgate);

// History (pre-Dummy):
// nsd = (nactive and fin) not ngate;  // production
// psd = (pactive and fin) not pgate;  // production
// nsd = nactive not ngate;             // pre-Dummy
// psd = pactive not pgate;             // pre-Dummy
nsd = (nactive not ngate) not Dummy;
psd = (pactive not pgate) not Dummy;

well_mark_all  = text_origin(well_text, cells  = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
P_SUB_mark_all = text_origin(P_SUB_text, cells = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
 MBPR_mark_all  = text_origin(MBPR_text, cells  = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
M1_mark_all    = text_origin(M1_text, cells    = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
M2_mark_all    = text_origin(M2_text, cells    = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
M3_mark_all    = text_origin(M3_text, cells    = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
M4_mark_all    = text_origin(M4_text, cells    = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
M5_mark_all    = text_origin(M5_text, cells    = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
M6_mark_all    = text_origin(M6_text, cells    = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
M7_mark_all    = text_origin(M7_text, cells    = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
M8_mark_all    = text_origin(M8_text, cells    = {get_top_cell()}, text = {"*"}, shape_size = 0.002);
M9_mark_all    = text_origin(M9_text, cells    = {get_top_cell()}, text = {"*"}, shape_size = 0.002);

well_mark  = well_mark_all interacting well;
P_SUB_mark = P_SUB_mark_all interacting P_SUB;
 MBPR_mark  = MBPR_mark_all interacting MBPR;
M1_mark    = M1_mark_all interacting M1;
M2_mark    = M2_mark_all interacting M2;
M3_mark    = M3_mark_all interacting M3;
M4_mark    = M4_mark_all interacting M4;
M5_mark    = M5_mark_all interacting M5;
M6_mark    = M6_mark_all interacting M6;
M7_mark    = M7_mark_all interacting M7;
M8_mark    = M8_mark_all interacting M8;
M9_mark    = M9_mark_all interacting M9;

well_pin  = well_mark_all and well;
 P_SUB_pin = P_SUB_mark_all and P_SUB;
 MBPR_pin  = MBPR_mark_all and MBPR;
M1_pin    = M1_mark_all and M1;
M2_pin    = M2_mark_all and M2;
M3_pin    = M3_mark_all and M3;
M4_pin    = M4_mark_all and M4;
M5_pin    = M5_mark_all and M5;
M6_pin    = M6_mark_all and M6;
M7_pin    = M7_mark_all and M7;
M8_pin    = M8_mark_all and M8;
M9_pin    = M9_mark_all and M9;

V0LIG     = V0_i interacting LIG;
V0LISD    = V0_i interacting LISD;

input_cdb = connect (
        connect_items = {
                {{M9, M8}, V8},
                {{M8, M7}, V7},
                {{M7, M6}, V6},
                {{M6, M5}, V5},
                {{M5, M4}, V4},
                {{M4, M3}, V3},
                {{M3, M2}, V2},
                {{M2, M1}, V1},
                {{M1, LIG}, V0LIG},
                {{M1, LISD}, V0LISD},
                {{LISD}, LIG},
                {{V0LISD, SDT}, LISD},
                {{MBPR, SDT}, VBPR},
                {{V0LIG, ngate, pgate, fpoly}, LIG},
                {{ngate, pgate}, fpoly},
                {{LISD, nsd, psd}, SDT},
                {{Pselect}, well},
                {{Nselect}, sub},
                {{well_pin}, well},
                {{P_SUB_pin}, P_SUB},
                {{MBPR_pin}, MBPR},
                {{M1_pin}, M1},
                {{M2_pin}, M2},
                {{M3_pin}, M3},
                {{M4_pin}, M4},
                {{M5_pin}, M5},
                {{M6_pin}, M6},
                {{M7_pin}, M7},
                {{M8_pin}, M8},
                {{M9_pin}, M9}
        }
);

netlist_cdb = text_net(
        connect_sequence = input_cdb,
        text_layer_items = {
                {well, well_text},
                {sub, P_SUB_text},
                {MBPR, MBPR_text},
                {M1_pin, M1_text},
                {M2_pin, M2_text},
                {M3_pin, M3_text},
                {M4_pin, M4_text},
                {M5_pin, M5_text},
                {M6_pin, M6_text},
                {M7_pin, M7_text},
                {M8_pin, M8_text},
                {M9_pin, M9_text},
                {M1, M1_text},
                {M2, M2_text},
                {M3, M3_text},
                {M4, M4_text},
                {M5, M5_text},
                {M6, M6_text},
                {M7, M7_text},
                {M8, M8_text},
                {M9, M9_text},
        },
        attach_text= ALL,
        report_errors = {UNUSED}
	// use_text = ALL,
	// attach_text = TOP,
	// shorts = KEEP_ONE,
	// opens = MERGE_CONNECTED_AND_TOP
);

netlist_cdb = create_ports(
    netlist_cdb,
    port_items = {
        {well_pin, well_mark},
         {P_SUB_pin, P_SUB_mark},
         {MBPR_pin, MBPR_mark},
        {M1_pin, M1_mark},
        {M2_pin, M2_mark},
        {M3_pin, M3_mark},
        {M4_pin, M4_mark},
        {M5_pin, M5_mark},
        {M6_pin, M6_mark},
        {M7_pin, M7_mark},
        {M8_pin, M8_mark},
        {M9_pin, M9_mark}
    }
);

dev_matrix = init_device_matrix(connect_sequence = netlist_cdb);

//nmos(dev_matrix, "nmos_rvt", nsd, ngate, nsd, {{sub}});
//pmos(dev_matrix, "pmos_rvt", psd, pgate, psd, {{well}});

nmos(dev_matrix, "nmos_rvt", nsd, ngate, nsd);
pmos(dev_matrix, "pmos_rvt", psd, pgate, psd);




device_db = extract_devices(dev_matrix);

layout_netlist_db = netlist(device_db);

compare_settings = init_compare_matrix();


// PEX

pex_matrix = init_pex_layer_matrix(device_db);
pex_conducting_layer_map(pex_matrix, M9     , "M9"    , tagname = "m9");
pex_conducting_layer_map(pex_matrix, M8     , "M8"    , tagname = "m8");
pex_conducting_layer_map(pex_matrix, M7     , "M7"    , tagname = "m7");
pex_conducting_layer_map(pex_matrix, M6     , "M6"    , tagname = "m6");
pex_conducting_layer_map(pex_matrix, M5     , "M5"    , tagname = "m5");
pex_conducting_layer_map(pex_matrix, M4     , "M4"    , tagname = "m4");
pex_conducting_layer_map(pex_matrix, M3     , "M3"    , tagname = "m3");
pex_conducting_layer_map(pex_matrix, M2     , "M2"    , tagname = "m2");
pex_conducting_layer_map(pex_matrix, M1     , "M1"    , tagname = "m1");
pex_conducting_layer_map(pex_matrix, MBPR   , "MBPR"  , tagname = "mbpr");
pex_conducting_layer_map(pex_matrix, fpoly  , "Gate"  , tagname = "fpoly");
pex_conducting_layer_map(pex_matrix, ngate  , "Gate"  , tagname = "ngate");
pex_conducting_layer_map(pex_matrix, pgate  , "Gate"  , tagname = "pgate");
pex_conducting_layer_map(pex_matrix, LISD   , "LISD"  , tagname = "lisd");
pex_conducting_layer_map(pex_matrix, LIG    , "LIG"   , tagname = "lig");
pex_conducting_layer_map(pex_matrix, SDT    , "SDT"   , tagname = "sdt");
pex_conducting_layer_map(pex_matrix, nsd    , "Active", tagname = "nsd");
pex_conducting_layer_map(pex_matrix, psd    , "Active", tagname = "psd");
pex_conducting_layer_map(pex_matrix, Pselect, "Active", tagname = "pselect");
pex_conducting_layer_map(pex_matrix, well   , "Active", tagname = "well");
pex_conducting_layer_map(pex_matrix, sub    , "Active", tagname = "sub");
pex_conducting_layer_map(pex_matrix, Nselect, "Active", tagname = "nselect");
 pex_conducting_layer_map(pex_matrix, P_SUB  , "P_SUB" , tagname = "p_sub");

pex_via_layer_map(pex_matrix, V8    , "V8"    , tagname = "v8");
pex_via_layer_map(pex_matrix, V7    , "V7"    , tagname = "v7");
pex_via_layer_map(pex_matrix, V6    , "V6"    , tagname = "v6");
pex_via_layer_map(pex_matrix, V5    , "V5"    , tagname = "v5");
pex_via_layer_map(pex_matrix, V4    , "V4"    , tagname = "v4");
pex_via_layer_map(pex_matrix, V3    , "V3"    , tagname = "v3");
pex_via_layer_map(pex_matrix, V2    , "V2"    , tagname = "v2");
pex_via_layer_map(pex_matrix, V1    , "V1"    , tagname = "v1");
pex_via_layer_map(pex_matrix, V0LIG , "V0LIG" , tagname = "v0lig");
pex_via_layer_map(pex_matrix, V0LISD, "V0LISD", tagname = "v0lisd");
pex_via_layer_map(pex_matrix, VBPR  , "VBPR"  , tagname = "vbpr");

pex_marker_layer_map(pex_matrix, well_pin, tagname = "well_pin");
 pex_marker_layer_map(pex_matrix, P_SUB_pin, tagname = "P_SUB_pin");
 pex_marker_layer_map(pex_matrix, MBPR_pin, tagname = "MBPR_pin");
pex_marker_layer_map(pex_matrix, M1_pin, tagname = "M1_pin");
pex_marker_layer_map(pex_matrix, M2_pin, tagname = "M2_pin");
pex_marker_layer_map(pex_matrix, M3_pin, tagname = "M3_pin");
pex_marker_layer_map(pex_matrix, M4_pin, tagname = "M4_pin");
pex_marker_layer_map(pex_matrix, M5_pin, tagname = "M5_pin");
pex_marker_layer_map(pex_matrix, M6_pin, tagname = "M6_pin");
pex_marker_layer_map(pex_matrix, M7_pin, tagname = "M7_pin");
pex_marker_layer_map(pex_matrix, M8_pin, tagname = "M8_pin");
pex_marker_layer_map(pex_matrix, M9_pin, tagname = "M9_pin");

// pex_process_handle = pex_process_map_file("process_map");
pex_process_handle = pex_process_map_file("starrcxt.mapping");
pex_report_handle = pex_runset_report_file("pex_runset_report");
mw_handle = milkyway_library("XTROUT");

xref = compare(
        state=compare_settings,
        schematic = schematic_netlist_db,
        layout = layout_netlist_db
);

pex_generate_results(
        pex_matrix = pex_matrix,
        layout_database = mw_handle,
        pex_process_map_file = pex_process_handle,
        pex_runset_report_file = pex_report_handle
);

spice_fh = spice_netlist_file(get_top_cell() + "_LPE.sp");

// write_spice(
//     device_db = device_db,
//     output_file = spice_fh
// );

write_pex_spice(
    device_db = device_db,
    output_file = spice_fh
);

// write_xref_spice(
//     device_db = device_db,
//     xref_db = xref,
//     output_file = spice_fh
// );
