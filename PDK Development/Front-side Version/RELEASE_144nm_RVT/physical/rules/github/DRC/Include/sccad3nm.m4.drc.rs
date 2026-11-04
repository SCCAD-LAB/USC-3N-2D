

rM4_1 @= { @ "M4.1 : Vertical width of M4 >= 12 nm";
        internal1(aM4, < 0.012, extension = NONE, direction = VERTICAL);
}

rM4_2 @= { @ "M4.2 : Horizontal length of M4 >= 24 nm";
        internal1(aM4, < 0.024, extension = NONE, direction = HORIZONTAL);
}

rM4_3 @= { @ "M4.3 : Vertical spacing between M4 layers >= 12 nm";
        external1(aM4, < 0.012, extension = NONE, direction = VERTICAL);
}

rM4_4 @= { @ "M4.4 : Horizontal (TtT) spacing between M4 layers on same track >= 17 nm";
        external1(aM4, < 0.017, extension = NONE, direction = HORIZONTAL);
}

rM4_5 @= { @ "M4.5 : M4 corner-to-corner spacing >= 15 nm";
        external_corner1( aM4, distance < 0.015, type = CONVEX_TO_CONVEX);
}

rM4_6 @= { @ "M4.6 : M4 must not bend";
        not_rectangles(aM4);
}
