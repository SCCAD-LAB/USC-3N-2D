# Native attributes and -all PIN queries checked against a private LM fixture.
proc usc144_check_interfaces {expected output} {
    set rows {}
    set seen {}
    foreach_in_collection cell [get_lib_cells */*] {
        set name [get_attribute $cell name]
        if {![dict exists $expected $name]} {error "Unexpected NDM cell $name"}
        if {[lsearch -exact $seen $name]>=0} {error "Duplicate native cell $name"}
        lappend seen $name
        lassign [dict get $expected $name] width height pins
        set actual_width [get_attribute $cell width]
        set actual_height [get_attribute $cell height]
        if {abs($actual_width-$width)>0.000001 || abs($actual_height-$height)>0.000001} {
            error "Native NDM/LEF dimensions differ for $name"
        }
        set actual_pins {}
        foreach_in_collection pin [get_lib_pins -all -of_objects $cell] {
            lappend actual_pins [lindex [split [get_object_name $pin] /] end]
        }
        if {[lsort -unique $actual_pins] ne [lsort -unique $pins]} {error "Native NDM/LEF PIN names differ for $name"}
        lappend rows [list $name $actual_width $actual_height [join [lsort -unique $actual_pins] ,]]
    }
    if {[lsort $seen] ne [lsort [dict keys $expected]]} {error "Native NDM interface cell set differs"}
    set stream [open $output w]
    foreach row [lsort -index 0 $rows] {puts $stream [join $row \t]}
    close $stream
    puts "USC144_NATIVE_INTERFACES_PASS [llength $seen]"
}
