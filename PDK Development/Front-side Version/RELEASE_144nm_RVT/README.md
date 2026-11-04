# Matched 144 nm front-side FSPR RVT library

This package provides a synchronized 57-cell silicon library: repaired GDS, vendor LEFs, circuit references, full-RC extraction, native timing/power, compiled DB and matched NDM. All cells use 144 nm height at 0.7 V and 25 °C.

| Validation | Result |
|---|---|
| Native physical QA | 57/57 DRC zero and topology LVS PASS; 121 active checks, no new waiver |
| Fresh extraction | 57/57; separate dimension, body-rail and terminal audits |
| Native characterization | 57/57; seven slews × seven loads, full native cell bodies preserved |
| Sequential behavior | All three state/polarity audits PASS; repaired DFFH also passes 64 actual-RC functional cases |
| Liberty compilation | Native LC PASS on the exact final library |
| Matched NDM | Native build and fresh readback; all 57 names, dimensions, signal/PG pins and `coreSite` checked |

The active repository map is `../selected_collateral.tcl`. It selects `../GDS/3nm_GAA_FSPR_144nm.gds`, the unchanged published RVT model, synchronized vendor LEF/LIB/DB, and `3nm_GAA_FSPR_144nm_rvt.ndm`. It also selects the validated fin-present DRC/LVS/FSPR extraction decks, native StarRC map and frozen grid. Historical OpenAccess, NDM, rules and input snapshots remain evidence; import the selected GDS to use repaired geometry.

Native LVS checks topology. Independent audits establish actual L/W, count and body normalization. The published GEOMOD=5 card consumes WGAA; derived aliases bind verified channel widths of 15/19/20/30 nm while retaining the other source coefficients. Raw StarRC DSPFs and final WGAA-bound simulation inputs are both supplied.

DFFHx1 includes the documented earlier one-NMOS relocation plus two master-clock gate retaps. All 32 repaired channel dimensions remain unchanged. Its derived independent circuit reference, physical proof and functional evidence are explicit. The other 56 selected native cells are preserved. The original full DFFH OS exit code is unavailable after its supervisor failed; its null value and narrow root exception remain alongside complete native output, source, state and LC proofs. Native LC and NDM build/readback have separately recorded zero exit codes.

The supplied active-layer RHO=15 and thickness=0.001 give 15,000 Ω/square; historical extraction used about 1 Ω/square. The supplied process inputs are preserved and have not been newly calibrated. Electrical before/after differences include model binding, geometry/RC, backend and the DFFH clock changes. Old Liberty area=0 means missing metadata; new area comes from fixed cell boundaries.

`electrical/RAW_BEFORE_AFTER.json` and the lossless `.csv.gz` contain matched raw 0D/1D/2D tables. Scalar data, unmatched rows, units and provenance are supplied beside them. `characterization/final57/` is the authoritative actual-used input bundle. Earlier input bundles are historical snapshots. Per-cell GDS hashes and the aggregate GDS hash identify different byte streams; the geometry-equivalence proof connects them.

From the repository root, set `release` to this directory and run:

```bash
python "$release/verify_release.py" --repository-root "$PWD"
python "$release/verify_144nm_maps.py" --repo "$PWD"
python "$release/recharacterize_cell.py" --bundle "$release/characterization/final57" \
  --cell INVx1 --work /tmp/usc144_INV_reproduction
```

The last command prepares inputs. Add `--run` to launch one cell after configuring `LIBERATE_BIN`, `SPECTRE_BIN` and the licensed tool environment. The portable geometry replay API supports an installed `gdstk` or an explicit dependency path. Historical repair scripts may depend on archived lab paths; the verification and recharacterization entrypoints use packaged inputs. No new chip PNR result is claimed.

Actual production numerics were traponly, reltol=1e-3 and maxstep=0.2 ps. Representative strict-solver, HSPICE boundary and notice controls are archived; the requested gear setting was not silently reported as executed. `MATCHED_SOURCE_BINDING.json`, the final electrical export and native NDM evidence pin the selected bytes.
