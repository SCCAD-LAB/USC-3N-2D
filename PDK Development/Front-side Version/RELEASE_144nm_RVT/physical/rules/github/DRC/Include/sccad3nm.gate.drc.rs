rGATE_1 @= { @ "GATE.1 : Exact horizontal width of GATE = 12 nm";
        gGATE1_check = internal1( aGATE, distance == 0.012, extension = NONE, direction = HORIZONTAL);
        aGATE not gGATE1_check;
}

rGATE_2 @= { @ "GATE.2 : Exact horizontal spacing of GATE = 30 nm";
        gGATE2_check = external1( aGATE, distance == 0.030, extension = NONE, direction = HORIZONTAL);
        gGATE2_check_extent = layer_extent(aGATE);
        gGATE2_check_extent not aGATE not gGATE2_check;
}


rGATE_3 @= { @ "GATE.3 : GATE must not bend";
        not_rectangles(aGATE);
}


rGATE_4 @= { @ "GATE.4 : GATE min extension past ACT in vertical direction >= 15 nm";
	enclose( aACT, aGATE, < 0.015, extension = NONE, direction = VERTICAL);
}


rGATE_5 @= { @ "GATE.5 : GATE minimum vertical length >= 50 nm";
	internal1( aGATE, < 0.050, extension = NONE, extension_look_past = POINT_TO_POINT, intersecting = {  }, projection_filter = MUTUAL_NON_ORTHOGONAL, projection_mode = ASYMMETRIC, direction = VERTICAL, orthogonal = BOTH );
}