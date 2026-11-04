

rM6_1 @= { @ "M6.1 : Vertical width of M6 >= 12 nm";
        internal1(aM6, < 0.012, extension = NONE, direction = VERTICAL);
}

rM6_2 @= { @ "M6.2 : Horizontal length of M6 >= 24 nm";
        internal1(aM6, < 0.024, extension = NONE, direction = HORIZONTAL);
}

rM6_3 @= { @ "M6.3 : Vertical spacing between M6 layers >= 12 nm";
        external1(aM6, < 0.012, extension = NONE, direction = VERTICAL);
}

rM6_4 @= { @ "M6.4 : Horizontal (TtT) spacing between M6 layers on same track >= 17 nm";
        external1(aM6, < 0.017, extension = NONE, direction = HORIZONTAL);
}

rM6_5 @= { @ "M6.5 : M6 corner-to-corner spacing >= 15 nm";
        external_corner1( aM6, distance < 0.015, type = CONVEX_TO_CONVEX);
}

rM6_6 @= { @ "M6.6 : M6 must not bend";
        not_rectangles(aM6);
}
