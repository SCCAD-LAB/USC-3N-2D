
rLISD_1 @= { @ "LISD.1 : Minimum Horizontal width of LISD >= 20 nm";
	internal1( aLISD, < 0.020, extension = NONE, direction = HORIZONTAL);
}

rLISD_2 @= { @ "LISD.2 : Minimum Vertical spacing of LISD >= 10 nm";
	external1(aLISD, < 0.010, extension = RADIAL, direction = VERTICAL); 
}

rLISD_3 @= { @ "LISD.3 : Minimum Horizontal (TtT) spacing between two LISD layers on the same track >=17 nm";
        external1(aLISD, < 0.017, extension = NONE, intersecting = { }, direction = HORIZONTAL, orientation = {PARALLEL}, look_thru = NONE);
}

rLISD_4 @= { @ "LISD.4 : LISD corner-to-corner spacing >= 15 nm";
        external_corner1( aLISD, distance < 0.015, type = CONVEX_TO_CONVEX);
}

rLISD_5 @= { @ "LISD.5 : LISD must not bend";
    not_rectangles(aLISD);
}


