This is the 57-cell, 144 nm front-side FSPR RVT verification package.

All 57 physical DRC, topology LVS, fresh PEX and terminal audits passed. The actual production solver policy passed the root representative equivalence review. Final electrical assembly and publication still require all 57 characterizations, hash-bound metadata overlays, native Liberty compilation, raw before/after tables and final review. The old published Liberty/DB has not yet been replaced in this staged snapshot.

| Item | Value | Meaning |
|---|---|---|
| Cell height | 144 nm (0.144 µm) | Cell widths, names, sites and port directions match the source interfaces. |
| Physical channels | L = 12 nm; W = 15/19/20/30 nm | These are channel dimensions, not cell widths. |
| Device model | Published RVT base card, byte-identical | GEOMOD=5 consumes WGAA. Classic instance W alone does not bind the channel width. |
| Derived models | WGAA follows verified final GDS | Generated aliases change WGAA; NGAA=3, TGAA=5 nm and source coefficients are retained. No refit or fractional NFIN. |
| Characterization grid | Slew 2.5/5/10/20/40/80/160 ps; load 0.36/0.72/1.44/2.88/5.76/11.52/23.04 fF | 0.7 V, 25 °C. Final electrical approval is pending. |
| Extraction | Full frozen GitHub grid | Active RHO=15, thickness=0.001 gives 15,000 Ω/square. Zeroed-RC controls are not release inputs. |

Use `physical/topology_reference/usc144_topology_reference_57_4t.cdl` for independent circuit topology. Its dimensions are historical reference properties. The normalized `native3t` file is the production ICV reference. Native LVS compares topology; it does not check W/L/body properties. Separate native extraction and GDS audits establish dimensions, device counts and body-rail mapping.

`physical/actual_size_4t_PEX/<cell>/` contains fresh process-name PEX with actual instance dimensions and its binding evidence. It is an input to geometry binding, not a substitute for the final WGAA-bound simulation netlist and alias cards. The final characterization package will include the exact used `cells.sp`, Spectre and HSPICE forms, generator and hashes back to raw PEX/GDS.

The final LEF is rebuilt from actual routed pins and obstructions. It passed the native 57-cell parser and an independent component/coverage review. No new rule waiver or relaxed threshold was used. The matched deck executed 121 active checks; its exact source and coverage are archived.

The DFFHx1 repair includes one approved NMOS translation from (546,36) to (588,36) nm, retaining L12/W19, all 32 W/L values and the other 31 positions. Its source geometry must not be called identical. Other documented source-contact/cut exceptions are in the physical evidence.

Per-cell characterization hashes identify the exact individual files at characterization/cells/<cell>/final_gds.gds. Those 57 byte streams are preserved. The aggregate GDS has its separate ff559ca10f0037ffd5602385fafac6adb495a7f7fe623eaab9b81a077cc393a1 hash. Root review compares all aggregate/per-cell geometries with per-layer XOR and label equality; these are separate levels of provenance.

The repaired physical view is GDS/3nm_GAA_FSPR_144nm.gds under PDK Development/Front-side Version, paired with the three updated vendor LEFs. Existing STD-CELLS OpenAccess directories are original source snapshots; import the new GDS to inspect or use repaired geometry.

The old published Liberty area=0 is unset metadata. New area values come from the fixed 144 nm cell boundaries. Raw zero values are retained; area ratios do not represent a physical area change. Historical fitted-model hashes identify current archived copies, not cryptographic proof of exact model bytes used in a 2024 run.

The large old/new timing difference combines model binding, geometry/RC and native backend changes. The old extraction was about 1 Ω/square; the delivered grid is 15,000 Ω/square. This release preserves the supplied inputs and does not newly validate physical process calibration. Raw matched tables must not be interpreted as an RC-only improvement.

Actual production SPICE2G used traponly/reltol=1e-3 despite requested gear2only/reltol=1e-6. Maxstep=0.2 ps and absolute tolerances applied. The unchanged 1% representative equivalence gate passed: 21 schematic conditions, 12 full-RC conditions, six sequential nominal controls and eight actual/intended boundary searches. The four matched boundary brackets were identical with 0.061 ps resolution, within the declared 0.2 ps target. This is representative coverage, not a strict-solver rerun of every Liberty point. A separate final supplement also passed all four additional strict HSPICE boundary searches:12 total searches and210 samples, with identical final brackets. Final 57-cell metadata overlays and Liberty/DB validation remain required.


The resolved production-notice review covers two saved AOI222 cases and four native replays. Both cases met the unchanged 1% metric and 1 mV rail-difference gates; the largest notice-window voltage difference was 2.28 nV. Prior passing full-RC and sequential controls also exercised the notice class. This is representative coverage; it does not claim every production waveform or the overwritten old C:4 waveform was replayed. Production inputs, model, RC and recipe were preserved.

The repository-relative entrypoint is `verify_release.py` (Python 3.9 or newer). From the repository root, run:

```sh
python3 "PDK Development/Front-side Version/RELEASE_144nm_RVT/verify_release.py"
```

This checks packaged file hashes and frozen model/grid identity without Cedar, SW source directories or native tools. It does not rerun native QA or certify a new result. The `source` entries in PACKAGE_FILES.json are archived provenance only; the validator uses `repository_path`.

For native recharacterization, `recharacterize_cell.py` accepts a packaged cell input directory containing run.tcl, cells.sp and model_native.scs, plus a new host-local `--work` directory. Supply `--liberate`/`--spectre` or LIBERATE_BIN/SPECTRE_BIN and your native license/tool environment. The default prepares inputs only; `--run` launches one cell. Only executable/work/output paths and optional CPU count are changed. Original Tcl is preserved. The wrapper does not schedule a library or claim scientific validation from a process exit code. The packaged characterization/MANIFEST.json labels measured-used, active-used and prepared-only input sets separately. Prepared-only sets are not execution evidence; the native wrapper refuses them. From the repository root, an example is:

```sh
RELEASE="PDK Development/Front-side Version/RELEASE_144nm_RVT"
python3 -m pip install -r "$RELEASE/characterization/requirements.txt"
python3 "$RELEASE/characterization/replay_inputs.py" --bundle "$RELEASE/characterization" --cell INVx1 --output /tmp/usc144_INV_regenerated
python3 "$RELEASE/recharacterize_cell.py" --bundle "$RELEASE/characterization" --cell INVx1 --work /tmp/usc144_INV_native --liberate "$LIBERATE_BIN" --spectre "$SPECTRE_BIN"
```

Use a Python environment for the pinned geometry dependency. The last command prepares a new native work directory; add --run to execute one cell after configuring your native tool and license environment. The archived production versions are Liberate23.26.120 and Spectre25.10.09.367. Execution under another version needs its own actual-settings/result validation.

Historical repair scripts and native receipt snapshots under physical/ retain original campaign paths for provenance. They are not the portable execution entrypoint. Their archived source locations are not runtime dependencies of the validator or the cell wrapper.

The existing BSD 3-Clause license and SCCAD Laboratory/USC attribution apply. See the repository LICENSE. `PACKAGE_FILES.json` maps copied source artifacts to repository paths and verified hashes.
