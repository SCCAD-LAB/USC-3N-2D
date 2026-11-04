

rSDT_1 @= { @ "SDT.1 : Horizontal width of SDT = 20 nm";
        gSDT1_check = internal1( aSDT, == 0.020, extension = NONE, direction = HORIZONTAL);
        aSDT not gSDT1_check;
}

rSDT_2 @= { @ "SDT.2 : Vertical (TtT) spacing between SDT >= 10 nm";
        external1( aSDT, < 0.010, extension = NONE, direction = VERTICAL, connectivity = DIFFERENT_NET, connect_sequence = CONNECT_DB );
}

rSDT_3 @= { @ "SDT.3 : SDT may not bend";
        not_rectangles( aSDT);
}

rSDT_4 @= { @ "SDT.ACT.1 : Vertical extension of SDT past ACT >= 5 nm";
        enclose( aACT, aSDT, < 0.005, extension = NONE, direction = VERTICAL);
}

rSDT_5 @= { @ "SDT.GATE.1 : Horizonal spacing between SDT and GATE = 5 nm";
        external2( aSDT, aGATE, < 0.005, extension = NONE, direction = HORIZONTAL);
}
