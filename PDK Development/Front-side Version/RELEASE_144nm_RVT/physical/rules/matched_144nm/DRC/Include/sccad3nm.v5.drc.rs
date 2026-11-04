

rV5_1 @= { @ "V5.1 : Horizontal width of V5 >= 12 nm";
       internal1( aV5, < 0.012, extension = NONE, direction = HORIZONTAL);
}

rV5_2 @= { @ "V5.2 : Vertical height of V5 >= 12 nm";
       internal1( aV5, < 0.012, extension = NONE, direction = VERTICAL);
}

rV5_3 @= { @ "V5.3 : V5 must interact with M2";
        not_interacting( aV5, aM2, include_touch = NONE);
}


rV5_4 @= { @ "V5.4 : Horizontal edges of V5 should align with M2";
        gV5_horz_edges = angle_edge( aV5, angles = 0);
        not_inside_touching_edge( gV5_horz_edges, aM2);
}

rV5_5 @= { @ "V5.5 : V5 corner-to-corner spacing >= 12 nm";
        external_corner1( aV5, distance < 0.012, type = CONVEX_TO_CONVEX);
}

rV5_6 @= { @ "V5.6 : V5 must interact with M1";
        not_interacting( aV5, aM1, include_touch = NONE);
}

rV5_7 @= { @ "V5.M1.EN : V5 enclosure by M1 on opposite sides in the vertical direction >= 4 nm";
        enclose( aV5, aM1, < 0.004, extension = NONE, direction = VERTICAL);
}

rV5_8 @= { @ "V5.M2.EN : V5 enclosure by M2 on opposite sides in the horizontal direction >= 4 nm";
        enclose( aV5, aM2, < 0.004, extension = NONE, direction = HORIZONTAL);
}
