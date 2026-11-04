
rVBPR_1 @= { @ "VBPR.1 : Vertical width of VBPR =12 nm";
        gVBPR1_check = internal1( aVBPR, == 0.012, extension = NONE, direction = VERTICAL);
        aVBPR not gVBPR1_check;
}

rVBPR_2 @= { @ "VBPR.2 : HORIZONTAL width of VBPR =20 nm";
        gVBPR2_check = internal1( aVBPR, == 0.020, extension = NONE, direction = HORIZONTAL);
        aVBPR not gVBPR2_check;
}


