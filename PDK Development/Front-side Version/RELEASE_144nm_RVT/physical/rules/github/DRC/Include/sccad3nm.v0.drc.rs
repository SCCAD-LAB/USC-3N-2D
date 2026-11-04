

rV0_1 @= { @ "V0.1 : Exact horizontal width of V0 = 12 nm";
       gV01_check = internal1( aV0, == 0.012, extension = NONE, direction = HORIZONTAL);
       aV0 not gV01_check;
}

rV0_2 @= { @ "V0.2 : Exact vertical width of V0 = 12 nm";
       gV02_check = internal1( aV0, == 0.012, extension = NONE, direction = VERTICAL);
       aV0 not gV02_check;
}

rV0_3 @= { @ "V0.3 : V0 must be rectangle";
        not_rectangles(aV0);
}

rV0_4 @= { @ "V0.M1.1 : V0 enclosure by M1 on opposite sides in vertical direction >= 4 nm";
        enclose(aV0, aM1, < 0.004, extension = NONE, direction = VERTICAL);
}


rV0_5 @= { @ "V0.5 : V0 must not be outside M1";
        not_inside(aV0, aM1, include_touch = ALL);
}

rV0_6 @= { @ "V0.6 : V0 corner-to-corner spacing >= 12 nm";
        external_corner1( aV0, distance < 0.012, type = CONVEX_TO_CONVEX);
}
