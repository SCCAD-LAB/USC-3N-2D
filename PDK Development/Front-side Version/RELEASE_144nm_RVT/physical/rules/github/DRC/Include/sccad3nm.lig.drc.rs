//rLIG_1 @= { @ "LIG.1 : Exact Vertical width of LIG = 12 nm";
//	gLIG1_check = internal1( aLIG, == 0.012, extension = NONE, direction = VERTICAL);	
//        aLIG not gLIG1_check;
//}

rLIG_2 @= { @ "LIG.2 : Minimum Horizontal width of LIG >= 10 nm";
	internal1( aLIG, < 0.010, extension = NONE, direction = HORIZONTAL);
}

rLIG_3 @= { @ "LIG.3 : Minimum Vertical spacing of LIG >= 5.5 nm";
	external1(aLIG, < 0.0055, extension = RADIAL, direction = VERTICAL); 
}

rLIG_4 @= { @ "LIG.4 : Minimum Horizontal (TtT) spacing between two LIG layers on the same track >=9 nm";
        external1(aLIG, < 0.009, extension = NONE, intersecting = { }, direction = HORIZONTAL, orientation = {PARALLEL}, look_thru = NONE);
}

rLIG_5 @= { @ "LIG.5 : LIG corner-to-corner spacing >= 14 nm";
        external_corner1( aLIG, distance < 0.014, type = CONVEX_TO_CONVEX);
}


rLIG_6 @= { @ "LIG.6 : LIG must not bend";
    not_rectangles(aLIG);
}


