
rM5_1 @= { @ "M5.1 : Vertical width of M5 >= 12 nm";
        internal1(aM5, < 0.012, extension = NONE, direction = VERTICAL);
}

rM5_2 @= { @ "M5.2 : Horizontal length of M5 >= 24 nm";
        internal1(aM5, < 0.024, extension = NONE, direction = HORIZONTAL);
}

rM5_3 @= { @ "M5.3 : Vertical spacing between M5 layers >= 12 nm";
        external1(aM5, < 0.012, extension = NONE, direction = VERTICAL);
}

rM5_4 @= { @ "M5.4 : Horizontal (TtT) spacing between M5 layers on same track >= 17 nm";
        external1(aM5, < 0.017, extension = NONE, direction = HORIZONTAL);
}

rM5_5 @= { @ "M5.5 : M5 corner-to-corner spacing >= 15 nm";
        external_corner1( aM5, distance < 0.015, type = CONVEX_TO_CONVEX);
}

rM5_6 @= { @ "M5.6 : M5 must not bend";
        not_rectangles(aM5);
}
