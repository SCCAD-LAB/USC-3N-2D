

rM3_1 @= { @ "M3.1 : Vertical width of M3 >= 12 nm";
        internal1(aM3, < 0.012, extension = NONE, direction = VERTICAL);
}

rM3_2 @= { @ "M3.2 : Horizontal length of M3 >= 24 nm";
        internal1(aM3, < 0.024, extension = NONE, direction = HORIZONTAL);
}

rM3_3 @= { @ "M3.3 : Vertical spacing between M3 layers >= 12 nm";
        external1(aM3, < 0.012, extension = NONE, direction = VERTICAL);
}

rM3_4 @= { @ "M3.4 : Horizontal (TtT) spacing between M3 layers on same track >= 17 nm";
        external1(aM3, < 0.017, extension = NONE, direction = HORIZONTAL);
}

rM3_5 @= { @ "M3.5 : M3 corner-to-corner spacing >= 15 nm";
        external_corner1( aM3, distance < 0.015, type = CONVEX_TO_CONVEX);
}

rM3_6 @= { @ "M3.6 : M3 must not bend";
        not_rectangles(aM3);
}
