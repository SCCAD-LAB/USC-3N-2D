

rVG_1 @= { @ "VG.1 : Exact horizontal width of VG = 15 nm";
        gVG1_check = internal1( aVG, == 0.015, extension = NONE, direction = HORIZONTAL);
        aVG not gVG1_check;
}

rVG_2 @= { @ "VG.2 : Exact vertical width of VG = 12 nm";
        gVG2_check = internal1( aVG, == 0.012, extension = NONE, direction = VERTICAL);
        aVG not gVG2_check;
}

rVG_3 @= { @ "VG.3 : VG must not interact with GCUT or DUMMY";
        gVG3_check = or(aGCUT, aDUMMY);
        interacting(aVG, gVG3_check, include_touch = ALL);
}

rVG_4 @= { @ "VG.4 : VG may not exist without GATE";
        not_interacting(aVG, aGATE, include_touch = NONE);
}

// not_inside might be sufficient as they have same min width
rVG_5 @= { @ "VG.5 : VG must completely lie inside GATE and its vertical edges must coincide with those of GATE";
        not_inside(aVG, aGATE, include_touch = ALL);
}


// VG.6 vertical spacing between VG

rVG_7 @= { @ "VG.7 : VG must be rectangle";
        not_rectangles(aVG);
}


// VG.GCUT.1 vertical spacing between VG and GCUT


rVG_9 @= { @ "VG.M0.1 : VG must completely lie inside M0";
        not_inside(aVG, aM0, include_touch = ALL);
}

rVG_10 @= { @ "VG.M0.2 : VG enclosure by M0 on two opposite sides in the horizontal direction: minimum 4 nm";
        enclose(aVG, aM0, < 0.004, extension = NONE, direction = HORIZONTAL);
}

// VG.M0.3 VG horizontal edges must align with M0 (may be redundant)

rVG_12 @= { @ "VG.ACT.1 : VG and ACT vertical spacing >= 6 nm";
        external2( aVG, aACT, distance < 0.006, extension = RADIAL, direction = VERTICAL);
}
