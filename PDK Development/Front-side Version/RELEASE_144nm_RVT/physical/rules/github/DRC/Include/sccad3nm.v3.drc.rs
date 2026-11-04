
rV3_1 @= { @ "V3.1 : Horizontal width of V3 >= 12 nm";
       internal1( aV3, < 0.012, extension = NONE, direction = HORIZONTAL);
}

rV3_2 @= { @ "V3.2 : Vertical height of V3 >= 12 nm";
       internal1( aV3, < 0.012, extension = NONE, direction = VERTICAL);
}

rV3_3 @= { @ "V3.3 : V3 must interact with M2";
        not_interacting( aV3, aM2, include_touch = NONE);
}


rV3_4 @= { @ "V3.4 : Horizontal edges of V3 should align with M2";
        gV3_horz_edges = angle_edge( aV3, angles = 0);
        not_inside_touching_edge( gV3_horz_edges, aM2);
}

rV3_5 @= { @ "V3.5 : V3 corner-to-corner spacing >= 12 nm";
        external_corner1( aV3, distance < 0.012, type = CONVEX_TO_CONVEX);
}

rV3_6 @= { @ "V3.6 : V3 must interact with M1";
        not_interacting( aV3, aM1, include_touch = NONE);
}

rV3_7 @= { @ "V3.M1.EN : V3 enclosure by M1 on opposite sides in the vertical direction >= 4 nm";
        enclose( aV3, aM1, < 0.004, extension = NONE, direction = VERTICAL);
}

rV3_8 @= { @ "V3.M2.EN : V3 enclosure by M2 on opposite sides in the horizontal direction >= 4 nm";
        enclose( aV3, aM2, < 0.004, extension = NONE, direction = HORIZONTAL);
}
