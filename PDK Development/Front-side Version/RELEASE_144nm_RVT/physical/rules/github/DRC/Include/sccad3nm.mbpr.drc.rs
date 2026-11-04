rMBPR_1 @= { @ "BRP.1 : MBPR vertical width = 30 nm";
   gMBPR1_check = internal1( aMBPR, == 0.00, extension = NONE, direction = VERTICAL); 
	aMBPR not gMBPR1_check;
}

rMBPR_2 @= { @ "MBPR.2 : Minimum vertical spacing between MBPR layers >= 105 nm";
	external1(aMBPR, < 0.105, extension = NONE, direction = VERTICAL); 

}

rMBPR_3 @= { @ "MBPR.3 : MBPR must be continuous";
	external1(aMBPR, < 10, direction = HORIZONTAL, extension = NONE);
}

rMBPR_4 @= { @ "MBPR.4 : MBPR may not bend";
	not_rectangles(aMBPR);
}

