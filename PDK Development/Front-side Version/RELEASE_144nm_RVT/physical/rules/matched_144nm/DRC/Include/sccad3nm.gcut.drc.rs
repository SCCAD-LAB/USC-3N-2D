rGCUT_1 @= { @ "GCUT.1 : GCUT vertical width >= 10 nm";
        internal1( aGCUT, distance < 0.010, extension = NONE, direction = VERTICAL);
}

rGCUT_2 @= { @ "GCUT.2 : GCUT horizontal length >= 15 nm";
        internal1( aGCUT, distance < 0.015, extension = NONE, direction = HORIZONTAL);
}

rGCUT_3 @= { @ "GCUT.3 : GCUT may not bend";
        not_rectangles( aGCUT);
}

rGCUT_4 @= { @ "GCUT.4 : GCUT may not exist without GATE";
        not_interacting( aGCUT, aGATE, include_touch = NONE);
}

rGCUT_5 @= { @ "GCUT.ACT.1 : Vertical spacing between GCUT and ACT >= 2 nm";
        external2( aGCUT, aACT, distance < 0.002, extension = NONE, direction = VERTICAL);
}

