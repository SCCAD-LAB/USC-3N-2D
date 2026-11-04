This private staged package selects the paired-master-clock 57-cell, 144 nm front-side FSPR RVT physical view. Electrical assembly and publication are pending.

The selected 57-cell physical view passed native DRC, topology LVS, fresh PEX, terminal and geometry audits. The paired DFFHx1 also passed all 64 actual-fresh-RC functional cases, including the four corrected postrelease-capture fixtures. Functional slew labels use the native 10–90% convention: a 160 ps label corresponds to a 200 ps full PWL transition. The sampled functional cases do not replace full 7×7 timing-arc coverage. The other 56 selected physical rows and accepted electrical rows are unchanged. Full new DFFHx1 all-arc 7×7 characterization is still running. Final accepted 57-cell electrical assembly, overlays, native Liberty compilation, raw tables and root review are required before publication. The old vendor Liberty/DB remains unchanged in this snapshot.

| Item | Value | Meaning |
|---|---|---|
| Cell height | 144 nm (0.144 µm) | Cell widths, names, sites and port directions match the source interfaces. |
| Physical channels | L = 12 nm; W = 15/19/20/30 nm | These are channel dimensions, not cell widths. |
| Device model | Published RVT base card, byte-identical | GEOMOD=5 consumes WGAA. Classic instance W alone does not bind the channel width. |
| Derived models | WGAA follows verified final GDS | Generated aliases change WGAA; NGAA=3, TGAA=5 nm and source coefficients are retained. No refit or fractional NFIN. |
| Characterization grid | Slew 2.5/5/10/20/40/80/160 ps; load 0.36/0.72/1.44/2.88/5.76/11.52/23.04 fF | 0.7 V, 25 °C. Final electrical approval is pending. |
| Extraction | Full frozen GitHub grid | Active RHO=15, thickness=0.001 gives 15,000 Ω/square. Zeroed-RC controls are not release inputs. |

Use the selected combined reference at `physical/topology_reference/usc144_topology_reference_57_4t.cdl` for circuit topology. DFFHx1 is an explicitly derived independent reference with exactly two master-clock gate connections changed; the other 56 reference blocks are preserved. Reference dimensions remain historical topology properties. The normalized `native3t` view is the production ICV reference. Native LVS checks topology; it does not check W/L/body properties. Separate native extraction/GDS audits establish all device dimensions and counts. Independent four-terminal source evidence establishes the body rails before the audited normalization to the production three-terminal device signature. This does not imply a native body-property check.

`physical/actual_size_4t_PEX/<cell>/` contains fresh process-name PEX with actual instance dimensions and its binding evidence. It is an input to geometry binding, not a substitute for the final WGAA-bound simulation netlist and alias cards. The final characterization package will include the exact used `cells.sp`, Spectre and HSPICE forms, generator and hashes back to raw PEX/GDS.

The final LEF is rebuilt from actual routed pins and obstructions. It passed the native 57-cell parser and an independent component/coverage review. No new rule waiver or relaxed threshold was used. The matched deck executed 121 active checks; its exact source and coverage are archived.

The earlier DFFHx1 physical repair moved one NMOS from (546,36) to (588,36) nm, retaining L12/W19 and the other 31 positions. The selected paired-master-clock candidate preserves all 32 channels and dimensions of that repaired view. It changes the clock connections of exactly two master gates, M12 and pM29. The other 30 gate connections are preserved. It uses original device widths; discarded strength-trial width changes are excluded. The independent-reference patch, derived four-terminal reference, normalized native reference, actual routing, fresh RC and functional proof are packaged separately. Other documented source contact/cut exceptions remain in the historical physical evidence.

Per-cell hashes identify exact individual GDS byte streams. The selected DFFHx1 is `characterization/paired_DFFH_active/cells/DFFHx1/final_gds.gds`, SHA46473c808103537d8082da21232d1ca1a6fe79a603e01c1491d3b6aed1664184. The unchanged other 56 per-cell files remain in the original input snapshot. The selected aggregate GDS has separate SHA016fd13516b7b580610ef282860fb315251e688cfec776a353c655d32a938b7e. The combined-view audit checks per-layer XOR and label equality for all 57 cells. An aggregate file hash is not the hash of one cell file. Historical manifests describe their original snapshots and are not current selection approvals.

The repaired physical view is GDS/3nm_GAA_FSPR_144nm.gds under PDK Development/Front-side Version, paired with the three updated vendor LEFs. Existing STD-CELLS OpenAccess directories are original source snapshots; import the new GDS to inspect or use repaired geometry.

The old published Liberty area=0 is unset metadata. New area values come from the fixed 144 nm cell boundaries. Raw zero values are retained; area ratios do not represent a physical area change. Historical fitted-model hashes identify current archived copies, not cryptographic proof of exact model bytes used in a 2024 run.

The large old/new timing difference combines model binding, geometry/RC and native backend changes. DFFHx1 additionally includes the two master-clock gate changes, so its eventual electrical delta cannot be attributed to RC alone. The old extraction was about 1 Ω/square; the delivered grid is 15,000 Ω/square. This release preserves the supplied inputs and does not newly validate physical process calibration. Raw matched tables must not be interpreted as an RC-only improvement.

Actual production SPICE2G used traponly/reltol=1e-3 despite requested gear2only/reltol=1e-6. Maxstep=0.2 ps and absolute tolerances applied. The unchanged 1% representative equivalence gate passed: 21 schematic conditions, 12 full-RC conditions, six sequential nominal controls and eight actual/intended boundary searches. The four matched boundary brackets were identical with 0.061 ps resolution, within the declared 0.2 ps target. This is representative coverage, not a strict-solver rerun of every Liberty point. A separate final supplement also passed all four additional strict HSPICE boundary searches:12 total searches and210 samples, with identical final brackets. Final 57-cell metadata overlays and Liberty/DB validation remain required.


The resolved production-notice review covers two saved AOI222 cases and four native replays. Both cases met the unchanged 1% metric and 1 mV rail-difference gates; the largest notice-window voltage difference was 2.28 nV. Prior passing full-RC and sequential controls also exercised the notice class. This is representative coverage; it does not claim every production waveform or the overwritten old C:4 waveform was replayed. Production inputs, model, RC and recipe were preserved.

The active Cadence, OpenROAD and ICC2 runfiles source `PDK Development/Front-side Version/selected_collateral.tcl`. Set `PDK_ROOT` to the repository root. The map selects the exact 144 nm GDS, published model and vendor LEF/LIB/DB files. Standard-cell selectors use exact filenames. Original OpenAccess data and the old compiled NDM are retained as historical inputs. They are excluded from matched defaults. Upstream runfiles have no GDS stream command; the common map exposes the explicit GDS source for integration. There is no wildcard GDS selection.

`matched_release_readiness.tcl` keeps active PNR blocked while new electrical artifacts are pending. The explicit new ICC2 reference is `NDM/3nm_GAA_FSPR_144nm_rvt.ndm`. It must be built from the accepted new 57-cell DB, selected LEF and frozen FSPR technology files, then reopened in a fresh native ICC2 process with exactly the expected 57 names. `ndm/build_matched_ndm.py` prepares or runs that procedure and refuses old/pre-final timing. No matched NDM has been built in this snapshot. Final payload sizes determine any scoped LFS rule, and remote objects must be verified before publication.

The path-argument regression test executes the actual setup/MMMC/library procedures with command stubs. It checks exact LEF/LIB/NDM list elements and scalar QRC/TCH/CAP/TLU filenames with repository paths and optional macro paths containing spaces. Run `python3 "$RELEASE/tests/check_selector_arguments.py" --repo "$PDK_ROOT"`. It starts no native tools and does not validate library contents or chip PNR.

The same map selects the native-qualified fin-present 144 nm DRC and LVS decks at `physical/rules/matched_144nm/`, the FSPR PEX extraction deck, native-generated StarRC layer map and frozen extraction grid. Their GDS mapping is V1=21, M6=60 and MBPR=15; LVS retains fin layer2. Numerical DRC include files are unchanged. The historical GitHub decks under `physical/rules/github/` are provenance, and are not the selected 144 nm verification defaults. The empty FSPR substrate/backside extraction bindings are explicitly removed according to the recorded zero-shape audit. Topology-only LVS and the independent dimension/body audits remain separate gates.

`verify_144nm_maps.py` performs a static deck/layer/grid/default check without native jobs. The Cadence QRC map binds layer names to names; upstream has no separate active GDS stream-layer map. This static check supplements the saved native reports; it does not rerun DRC/LVS/PEX or approve timing.

The repository-relative entrypoint is `verify_release.py` (Python 3.9 or newer). From the repository root, run:

```sh
python3 "PDK Development/Front-side Version/RELEASE_144nm_RVT/verify_release.py"
python3 "PDK Development/Front-side Version/RELEASE_144nm_RVT/verify_144nm_maps.py"
```

This checks packaged file hashes and frozen model/grid identity without Cedar, SW source directories or native tools. It does not rerun native QA or certify a new result. The `source` entries in PACKAGE_FILES.json are archived provenance only; the validator uses `repository_path`.

For native recharacterization, `recharacterize_cell.py` accepts a packaged cell input directory containing run.tcl, cells.sp and model_native.scs, plus a new host-local `--work` directory. Supply `--liberate`/`--spectre` or LIBERATE_BIN/SPECTRE_BIN and your native license/tool environment. The default prepares inputs only; `--run` launches one cell. Only executable/work/output paths and optional CPU count are changed. Original Tcl is preserved. The wrapper does not schedule a library or claim scientific validation from a process exit code. The frozen `characterization/original57_snapshot/MANIFEST.json` preserves the original measured/active/prepared input labels. Those labels describe that earlier snapshot, not current completion counts. Its old DFFHx1 inputs are historical and do not match the selected paired candidate. Use `characterization/paired_DFFH_active/MANIFEST.json` for the selected DFFHx1: it records active-used inputs matched to the actual full-native launch, electrical-pending status, and no result approval. Prepared-only sets are not execution evidence; the native wrapper refuses them. From the repository root, an example is:

```sh
RELEASE="PDK Development/Front-side Version/RELEASE_144nm_RVT"
python3 -m pip install -r "$RELEASE/characterization/original57_snapshot/requirements.txt"
python3 "$RELEASE/characterization/original57_snapshot/replay_inputs.py" --bundle "$RELEASE/characterization/original57_snapshot" --cell INVx1 --output /tmp/usc144_INV_regenerated
python3 "$RELEASE/recharacterize_cell.py" --bundle "$RELEASE/characterization/original57_snapshot" --cell INVx1 --work /tmp/usc144_INV_native --liberate "$LIBERATE_BIN" --spectre "$SPECTRE_BIN"
```

For the selected DFFHx1, the portable regeneration command is:

```sh
PAIRED="$RELEASE/characterization/paired_DFFH_active"
python3 "$PAIRED/portable_replay_inputs.py" --bundle "$PAIRED" --cell DFFHx1 --output /tmp/usc144_DFFH_paired_regenerated
python3 "$RELEASE/recharacterize_cell.py" --bundle "$PAIRED" --cell DFFHx1 --work /tmp/usc144_DFFH_paired_native --liberate "$LIBERATE_BIN" --spectre "$SPECTRE_BIN"
```

These commands regenerate or prepare inputs. They do not approve an electrical result. The full-native supervisor encountered a shared-file metadata error while its native process continued. An attach-only guard supervises the unchanged native process. The final OS return code may be unavailable; this package makes no rc=0 or full-characterization PASS claim. Final native output and termination evidence require explicit root review.

Use a Python environment for the pinned geometry dependency. The last command prepares a new native work directory; add --run to execute one cell after configuring your native tool and license environment. The archived production versions are Liberate23.26.120 and Spectre25.10.09.367. Execution under another version needs its own actual-settings/result validation.

Historical repair scripts and native receipt snapshots under physical/ retain original campaign paths for provenance. They are not the portable execution entrypoint. Their archived source locations are not runtime dependencies of the validator or the cell wrapper.

The existing BSD 3-Clause license and SCCAD Laboratory/USC attribution apply. See the repository LICENSE. `PACKAGE_FILES.json` maps copied source artifacts to repository paths and verified hashes.
