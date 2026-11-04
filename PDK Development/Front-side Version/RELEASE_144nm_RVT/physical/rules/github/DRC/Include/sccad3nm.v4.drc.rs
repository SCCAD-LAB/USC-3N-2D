
rV4_1 @= { @ "V4.1 : Horizontal width of V4 >= 12 nm";
       internal1( aV4, < 0.012, extension = NONE, direction = HORIZONTAL);
}

rV4_2 @= { @ "V4.2 : Vertical height of V4 >= 12 nm";
       internal1( aV4, < 0.012, extension = NONE, direction = VERTICAL);
}

rV4_3 @= { @ "V4.3 : V4 must interact with M2";
        not_interacting( aV4, aM2, include_touch = NONE);
}


rV4_4 @= { @ "V4.4 : Horizontal edges of V4 should align with M2";
        gV4_horz_edges = angle_edge( aV4, angles = 0);
        not_inside_touching_edge( gV4_horz_edges, aM2);
}

rV4_5 @= { @ "V4.5 : V4 corner-to-corner spacing >= 12 nm";
        external_corner1( aV4, distance < 0.012, type = CONVEX_TO_CONVEX);
}

rV4_6 @= { @ "V4.6 : V4 must interact with M1";
        not_interacting( aV4, aM1, include_touch = NONE);
}

rV4_7 @= { @ "V4.M1.EN : V4 enclosure by M1 on opposite sides in the vertical direction >= 4 nm";
        enclose( aV4, aM1, < 0.004, extension = NONE, direction = VERTICAL);
}

rV4_8 @= { @ "V4.M2.EN : V4 enclosure by M2 on opposite sides in the horizontal direction >= 4 nm";
        enclose( aV4, aM2, < 0.004, extension = NONE, direction = HORIZONTAL);
}
