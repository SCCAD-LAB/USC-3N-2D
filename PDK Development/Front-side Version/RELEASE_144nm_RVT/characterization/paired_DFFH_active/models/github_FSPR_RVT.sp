
** 3-nm-node NSFET (LVT)

.LIB TT
.MODEL NMOS_LVT NMOS ( LEVEL = 72
+version  = 111.2.1        bulkmod  = 1
+geomod   = 5              capmod   = 1
+coremod  = 0              cgeomod  = 0
+igcmod   = 0              igbmod   = 0
+gidlmod  = 0              iimod    = 0
+rdsmod   = 0              rgatemod = 0
+rgeomod  = 0              shmod    = 0
+nqsmod   = 0              tnom     = 25
+eot      = 0.795e-009     epsrox   = 3.9
+epsrsub  = 11.9           epsrsp   = 3.9
+easub    = 4.05           ni0sub   = 1.1e+016
+bg0sub   = 1.12           nc0sub   = 2.86e+025
+nbody    = 1e+021         nsd      = 4e+026
+wgaa     = 3.0e-008       tgaa     = 5.0e-009
+ngaa     = 3              nfin     = 1
+nf       = 1              fpitch   = 3.0e-008
+l        = 1.2e-008       lsp      = 5.0e-9
+sdterm   = 0              devtype  = 1
+cit      = 7.000000e-4              phig     = 4.457000
+rdsw     = 3.607614e+01   cdsc     = 1.869540e-03
+cdscd    = 1.712693e-08   dvt0     = 0.00
+dvt1     = 0.60           dvtp0    = -1.176834e-02
+dvtshift = 0              phin     = 0.05
+eta0     = 1.500000   dsub     = 1.000000
+k1rsce   = 0              lpe0     = 0
+qmfactor = 0.0            etaqm    = 0.54
+qm0      = 8.80479e-02    u0       = 0.340000
+ua       = 1.487874e+01   eu       = 6.714073e-01
+ud       = 0.0            ucs      = 2.067263e+01
+etamob   = 3.475416e+01        up       = 0
+vsat     = 56000   vsat1    = 6.106100e+04
+ksativ   = 2.117747e+00   deltavsat= 0.28
+mexp     = 5.0       ptwg     = 5.790263e-02
+pclm     = 0.013          pclmg    = 0
+pdibl1   = 1.3            pdibl2   = 2.620632e-05
+pvag     = 2.579197e+01           drout    = 1.06
+rshs     = 0              rshd     = 0
+rth0     = 0.01           cth0     = 1.0e-5
+wth0     = 0.0           
+cfs      = 7.29575e-13    cfd      = 7.29575e-13
+cgso     = 1.850000e-10    cgdo     = 1.850000e-10
+cgsl     = 8.000000e-11    cgdl     = 8.000000e-11
+cgbo     = 1.46747e-11    cgbl     = 1.74474e-09
+ckappas  = 0.300000             ckappad  = 0.300000
+qmtcencv = 0.672000        pqm      = 1.16706
+pclmcv   = 0.050000    deltawcv = -5.49129e-13
+aigc     = 0.0136         bigc     = 0.00171
+cigc     = 0.075          dlcigs   = 0.0
+dlcigd   = 0.0            aigs     = 0.0136
+aigd     = 0.0136         bigs     = 0.00171
+bigd     = 0.00171        cigs     = 0.075
+cigd     = 0.075          poxedge  = 1
+agidl    = 6.055e-012     agisl    = 6.055e-012
+bgidl    = 0.3e+9         bgisl    = 0.3e+9
+egidl    = 0.2            egisl    = 0.2
)

.MODEL PMOS_LVT PMOS ( LEVEL = 72
+version  = 111.2.1        bulkmod  = 1
+geomod   = 5              capmod   = 1
+coremod  = 0              cgeomod  = 0
+igcmod   = 0              igbmod   = 0
+gidlmod  = 0              iimod    = 0
+rdsmod   = 0              rgatemod = 0
+rgeomod  = 0              shmod    = 0
+nqsmod   = 0              tnom     = 25
+eot      = 0.795e-009     epsrox   = 3.9
+epsrsub  = 11.9           epsrsp   = 3.9
+easub    = 4.05           ni0sub   = 1.1e+016
+bg0sub   = 1.12           nc0sub   = 2.86e+025
+nbody    = 1e+021         nsd      = 4e+026
+wgaa     = 3.0e-008       tgaa     = 5.0e-009
+ngaa     = 3              nfin     = 1
+nf       = 1              fpitch   = 3.0e-008
+l        = 1.2e-008       lsp      = 5.0e-9
+sdterm   = 0              devtype  = 0
+cit      = 7.000000e-4              phig     = 4.760000
+rdsw     = 3.456865e+02   cdsc     = 3.835592e-03
+cdscd    = 1.000000e-11              dvt0     = 0.00
+dvt1     = 0.60           dvtp0    = -1.109184e-02
+dvtshift = 0              phin     = 0.05
+eta0     = 1.500000   dsub     = 1.000000
+k1rsce   = 0              lpe0     = 0
+qmfactor = 0.0            etaqm    = 0.54
+qm0      = 1.50942        u0       = 0.270000
+ua       = 7.413554e+00   eu       = 1.256490e+00
+ud       = 0.000000e+00   ucs      = 6.968708e+00
+etamob   = 7.644412e+00   up       = 0
+vsat     = 31000   vsat1    = 1.598400e+05
+ksativ   = 1.160156e+00       deltavsat= 0.28
+mexp     = 5.000000e+00       ptwg     = 5.684176e+00
+pclm     = 0.013          pclmg    = 0
+pdibl1   = 1.3            pdibl2   = 3.547093e-08
+pvag     = 8.276459e+00       drout    = 1.06
+rshs     = 0              rshd     = 0
+rth0     = 0.01           cth0     = 1.0e-5
+wth0     = 0.0
+cfs      = 1.02572e-11    cfd      = 1.50266e-10
+cgso     = 3.780000e-10              cgdo     = 3.780000e-10
+cgsl     = 4.670000e-13    cgdl     = 4.670000e-13
+cgbo     = 1.92149e-11    cgbl     = 2.10545e-09
+ckappas  = 0.300000    ckappad  = 0.300000
+qmtcencv = 0.819000    pqm      = 40
+pclmcv   = 0.050000    deltawcv = 5.29316e-08
+aigc     = 0.0136         bigc     = 0.00171
+cigc     = 0.075          dlcigs   = 0.0
+dlcigd   = 0.0            aigs     = 0.0136
+aigd     = 0.0136         bigs     = 0.00171
+bigd     = 0.00171        cigs     = 0.075
+cigd     = 0.075          poxedge  = 1
+agidl    = 6.055e-012     agisl    = 6.055e-012
+bgidl    = 0.3e+9         bgisl    = 0.3e+9
+egidl    = 0.2            egisl    = 0.2
)

.ENDL TT