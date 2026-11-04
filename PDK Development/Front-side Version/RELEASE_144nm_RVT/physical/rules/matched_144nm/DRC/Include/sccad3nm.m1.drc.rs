
rM1_1 @= { @ "M1.1 : Horizontal width of M1 >= 12 nm";
        internal1(aM1, < 0.012, extension = NONE, direction = HORIZONTAL);
}

rM1_2 @= { @ "M1.2 : Vertical length of M1 >= 12 nm";
        internal1(aM1, < 0.012, extension = NONE, direction = VERTICAL);
}

rM1_3 @= { @ "M1.3 : Horizontal spacing between M1 layers >= 12 nm";
        external1(aM1, < 0.012, extension = NONE, direction = HORIZONTAL);
}

rM1_4 @= { @ "M1.4 : Vertical (TtT) spacing between M1 layers on same track >= 12 nm";
        external1(aM1, < 0.012, extension = NONE, direction = VERTICAL);
}

rM1_5 @= { @ "M1.5 : M1 corner-to-corner spacing >= 15 nm";
        external_corner1( aM1, distance < 0.015, type = CONVEX_TO_CONVEX);
}

