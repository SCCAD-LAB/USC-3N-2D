

rNsel_1 @={ @ "Nsel.1 : Minimum vertical width of Nsel >= 60 nm";
        internal1( aNsel, distance < 0.060, extension = NONE, direction = VERTICAL);
}

rNsel_2 @={ @ "Nsel.2 : Minimum horizontal width of Nsel >= 84 nm";
        internal1( aNsel, distance < 0.084, extension = NONE, direction = HORIZONTAL);
}

rNsel_3 @={ @ "Nsel.3 : Minimum enclosure of ACT by Nsel in the vertical direction >= 15 nm";
        enclose( aACT, aNsel, distance < 0.010, extension = NONE, direction = VERTICAL);
}


rPsel_1 @={ @ "Psel.1 : Minimum vertical width of Psel >= 60 nm";
        internal1( aPsel, distance < 0.060, extension = NONE, direction = VERTICAL);
}

rPsel_2 @={ @ "Psel.2 : Minimum horizontal width of Psel >= 84 nm";
        internal1( aPsel, distance < 0.084, extension = NONE, direction = HORIZONTAL);
}

rPsel_3 @={ @ "Psel.3 : Minimum enclosure of ACT by Psel in the vertical direction >= 10 nm";
        enclose( aACT, aPsel, distance < 0.010, extension = NONE, direction = VERTICAL);
}


rNsel_Psel_1 @= { @ "Nsel.Psel.1 : Nsel and Psel should not overlap";
        interacting( aNsel, aPsel, include_touch = NONE);
}
