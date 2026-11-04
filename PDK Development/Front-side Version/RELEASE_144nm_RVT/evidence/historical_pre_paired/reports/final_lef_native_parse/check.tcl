create_workspace -technology tech.tf usc144_lef_final
read_lef -include tech tech.lef
read_lef -preserve_lef_cell_site cells.lef
set n [sizeof_collection [get_lib_cells */*]]
puts "USC144_NATIVE_LEF_CELLS $n"
if {$n != 57} {error "Expected 57 cells"}
puts "USC144_NATIVE_LEF_PARSE_PASS"
exit
