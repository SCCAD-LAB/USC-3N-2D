from pathlib import Path
import sys,json,shutil,gzip,re,time,copy
HERE=Path(__file__).resolve().parent;P=HERE.parent;RELEASE=P.parent;VIEW=HERE/'prepared_release57';PHYS=VIEW/'physical';EXPORT=PHYS/'export'
sys.path.insert(0,str(P));import scan as s,terminal_connectivity as term
sha=s.p.sha;save=s.p.save

def cp(a,b):
 a=Path(a);b=Path(b);b.parent.mkdir(parents=True,exist_ok=True)
 if b.exists():assert sha(a)==sha(b),'Preserve existing different preparedfile '+str(b)
 else:shutil.copyfile(a,b)
 assert sha(a)==sha(b)
def load(p):return json.loads(Path(p).read_text())
def main():
 assert not (EXPORT/'EXPORT_MANIFEST.json').exists(),'Export already frozen'
 old_export=P/'export';manifest=load(PHYS/'PEX_MANIFEST.json');rows=manifest['rows'];assert len(rows)==57
 for folder in ['rules','generators']:
  for f in (old_export/folder).rglob('*'):
   if f.is_file():cp(f,EXPORT/f.relative_to(old_export))
 for name in ['RULE_SOURCES.json','RULE_ADAPTER.json','REFERENCE_ADMISSION.json','DEVICE_LAYER_CHANGE_POLICY.json','FSPR_EMPTY_LAYER_AUDIT.json','RAW_PHYSICAL_BEFORE_AFTER.csv','PHYSICAL_ITERATION_HISTORY.json','PHYSICAL_ITERATION_HISTORY.csv']:
  cp(P/name,EXPORT/'evidence/historical_original57'/name)
 for name in ['PEX_MANIFEST.json','FINAL_QA_INDEX.json','TERMINAL_CONNECTIVITY_INDEX.json']:cp(PHYS/name,EXPORT/'evidence'/name)
 actual=[]
 for r in rows:
  name=r['cell'];dest=EXPORT/'actual_size_4t_PEX'/name
  for field,filename in [('gds','cell.gds'),('dspf','cell.dspf'),('raw_dspf','cell.raw.dspf'),('device_geometry_binding','DEVICE_GEOMETRY_BINDING.json'),('terminal_connectivity_audit','TERMINAL_CONNECTIVITY_AUDIT.json')]:
   assert sha(r[field])==r[field+'_sha256'];cp(r[field],dest/filename)
  binding=load(r['device_geometry_binding']);cp(binding['native_dimension_report'],dest/'ACTUAL_DEVICE_DIMENSIONS.json');cp(r['body_rail_provenance'],dest/'BODY_RAIL_PROVENANCE.json')
  if r.get('device_layer_change_audit'):cp(r['device_layer_change_audit'],dest/'DEVICE_LAYER_CHANGE_AUDIT.json')
  cp(r['drc_report'],dest/'native'/(name+'.RESULTS'));cp(r['lvs_report'],dest/'native'/(name+'.LVS_ERRORS'))
  gate=load(r['gate']);text,source=term.native_net(gate);q=dest/'native'/(name+'.net.txt');q.write_text(text);save(dest/'native/NATIVE_NET_SOURCE.json',source)
  actual.append(dict(cell=name,dspf=str(dest/'cell.dspf'),dspf_sha256=r['dspf_sha256'],raw_dspf_sha256=r['raw_dspf_sha256'],gds_sha256=r['gds_sha256'],device_binding_sha256=r['device_geometry_binding_sha256'],actual_MOS_dimensions_preserved=True,terminal_connectivity_pass=True))
  # Real directory with copied latest; stable old iteration payloads remain read-only links.
  cell=PHYS/'cells'/name;cell.mkdir(parents=True,exist_ok=True)
  if name!='DFFHx1':cp(P/'cells'/name/'LATEST.json',cell/'LATEST.json')
  for original in (P/'cells'/name).iterdir():
   dst=cell/original.name
   if original.name=='LATEST.json' or dst.exists() or dst.is_symlink():continue
   dst.symlink_to(original)
 # Preserve the measured-used physical binding separately from relocated metadata.
 cp(HERE/'iter001/pex/DEVICE_GEOMETRY_BINDING_v2.json',EXPORT/'actual_size_4t_PEX/DFFHx1/MEASURED_USED_PHYSICAL_BINDING.json')
 cp(P/'cells/DFFHx1/iter003/DEVICE_LAYER_CHANGE_AUDIT.json',EXPORT/'actual_size_4t_PEX/DFFHx1/INHERITED_ORIGINAL144NM_DEVICE_TRANSLATION_AUDIT.json')
 cp(PHYS/'FINAL_57_CELL_GDS.gds',EXPORT/'layout/usc144_drc_lvs_clean_57.gds')
 for name in ['generate_candidate.py','run_native.py','run_pex.py','audit_paired_topology.py','terminal_connectivity_scoped.py','prepare_view57.py','finalize_export57.py']:cp(HERE/name,EXPORT/'generators/paired_clock'/name)
 for name in ['PAIRED_TWO_GATE_TOPOLOGY_AUDIT.json','PAIRED_TOPOLOGY_GATE_ADAPTER.json','GEOMETRY_PROVENANCE.json','GEOMETRY_GENERATION.json','BODY_RAIL_PROVENANCE.json','PRODUCTION_SOLVER_CORRELATION.json','RAW_BEFORE_IDEAL_AFTER_WINDOW_COMPARISON.json','UNCHANGED_NATIVE_PROCESS_INPUT_AUDIT.json','ORIGINAL_UNCHANGED_RECHECK.json']:
  cp(HERE/name,EXPORT/'evidence/paired_clock'/name)
 for name in ['DFFH_PAIRED_CLOCK_REFERENCE_REVIEW.json']:
  cp(RELEASE/'reports'/name,EXPORT/'evidence/paired_clock'/name)
 functional=RELEASE/'characterization/failure_review_DFFH_removal/clock_retap_functional_screen/actual_paired_master_freshPEX_r1/FINAL_SCREEN_AUDIT.json';assert sha(functional)=='fd2eb5b23634cc17d77108a82a6961f68f54f43f2cf2cad6e5840975da880b7f';f=load(functional);assert f['complete'] and f['passed'] and f['completed']==64
 cp(functional,EXPORT/'evidence/paired_clock/FUNCTIONAL64_FINAL_SCREEN_AUDIT.json')
 lef=RELEASE/'reports/CANDIDATE_paired_clock_144nm_complete_abstract.lef';assert sha(lef)=='ae772af34907bf4b6e99107a01df19a90485d06f0fd57973668ab0b8557cde53'
 cp(lef,VIEW/'reports/FINAL_144nm_complete_abstract.lef');cp(RELEASE/'reports/CANDIDATE_paired_clock_144nm_complete_abstract.json',VIEW/'reports/FINAL_144nm_complete_abstract.json')
 for name in ['RESULT.json','check.tcl','native.log']:cp(RELEASE/'reports/candidate_paired_clock_iter001_lef_native_parse'/name,VIEW/'reports/final_lef_native_parse'/name)
 native_lef=load(VIEW/'reports/final_lef_native_parse/RESULT.json');assert native_lef['native_parse_pass'] and native_lef['lef_sha256']==sha(lef)
 cp(lef,EXPORT/'abstract/usc144_complete_abstract.lef');cp(VIEW/'reports/FINAL_144nm_complete_abstract.json',EXPORT/'abstract/usc144_complete_abstract.json');cp(VIEW/'reports/final_lef_native_parse/RESULT.json',EXPORT/'abstract/NATIVE_LEF_PARSE_RESULT.json')
 refs=[]
 for r in rows:
  q=EXPORT/'topology_reference/per_cell'/(r['cell']+'.cdl');assert q.exists();refs.append(dict(cell=r['cell'],path=str(q),sha256=sha(q),scope='Explicit root-authorized two-gate derived intent' if r['cell']=='DFFHx1' else 'Independent prior2024 topology',parametric_gold=False))
 save(EXPORT/'SCOPE_AND_PROVENANCE.json',dict(physical_cells=57,physical_DRC_LVS_PEX_complete=True,functional64_passed=True,full_new_DFFH_characterization_pending=True,release_qualified=False,publication_allowed=False,topology_reference_scope='56 independent prior circuits and one explicitly approved DFFH two-gate clock-routing candidate. Historical reference sizes are not final physical sizing gold.',actual_size_source='Final GDS/native extraction/PEX bijections. WGAA geometry aliases are required; classic W alone does not bind this model.',dimensions='All32 DFFH L/W and coordinates match the original qualified03ae GDS. Its earlier authorized M7 42nm translation from the raw144nm source remains documented separately.',body_scope='Independent type/well/D/S/body-rail provenance. The supplied native3T deck does not check bulk or W/L properties.',rule_scope='121 native DRC checks, zero not-executed; unchanged numeric rules and frozen process grid/model.',reference_views=refs,actual_size_views=actual))
 save(EXPORT/'RAW_PHYSICAL_BEFORE_AFTER.json',load(PHYS/'FINAL_QA_INDEX.json'))
 files=[dict(path=str(q.relative_to(EXPORT)),sha256=sha(q),bytes=q.stat().st_size) for q in sorted(EXPORT.rglob('*')) if q.is_file() and q.name!='EXPORT_MANIFEST.json']
 selected=dict(complete=True,scope='Physical export and64-case functional evidence complete; full native DFFH and final approval remain pending.',cells=57,root=str(EXPORT),release_qualified=False,publication_allowed=False,topology_reference_4t=str(EXPORT/'topology_reference/usc144_topology_reference_57_4t.cdl'),topology_reference_native3t=str(EXPORT/'topology_reference/usc144_topology_reference_57_native3t.cdl'),final_geometry_GDS=str(EXPORT/'layout/usc144_drc_lvs_clean_57.gds'),LEF=str(EXPORT/'abstract/usc144_complete_abstract.lef'),LEF_sha256=sha(lef),functional_audit=str(EXPORT/'evidence/paired_clock/FUNCTIONAL64_FINAL_SCREEN_AUDIT.json'),functional_audit_sha256=sha(functional),selected_DFFH_GDS_sha256='46473c808103537d8082da21232d1ca1a6fe79a603e01c1491d3b6aed1664184',selected_DFFH_DSPF_sha256='8023a990312d40652e4705f709d971af27a33098624e108c99b47d2c5395c25d',files=files)
 save(EXPORT/'EXPORT_MANIFEST.json',selected)
 save(VIEW/'SELECTED_EXPORT_API.json',dict(export_manifest=str(EXPORT/'EXPORT_MANIFEST.json'),export_manifest_sha256=sha(EXPORT/'EXPORT_MANIFEST.json'),selected_export_root=str(EXPORT),GDS=selected['final_geometry_GDS'],GDS_sha256=sha(selected['final_geometry_GDS']),topology_reference_4t=selected['topology_reference_4t'],topology_reference_native3t=selected['topology_reference_native3t'],DFFH_4t=str(EXPORT/'topology_reference/per_cell/DFFHx1.cdl'),DFFH_actual_size_4t=str(EXPORT/'actual_size_4t_PEX/DFFHx1/cell.dspf'),DFFH_body_proof=str(EXPORT/'actual_size_4t_PEX/DFFHx1/BODY_RAIL_PROVENANCE.json'),LEF=selected['LEF'],LEF_sha256=selected['LEF_sha256'],publication_allowed=False,full_native_DFFH_pending=True))
 # Bind dependencies without copying or mutating global consumer state.
 for name in ['sources','control','characterization']:
  dst=VIEW/name
  if not dst.exists() and not dst.is_symlink():dst.symlink_to(RELEASE/name)
 for name in ['rules','references']:
  dst=PHYS/name
  if not dst.exists() and not dst.is_symlink():dst.symlink_to(P/name)
 print(json.dumps(dict(export_manifest_sha256=sha(EXPORT/'EXPORT_MANIFEST.json'),api_sha256=sha(VIEW/'SELECTED_EXPORT_API.json'),files=len(files),LEF_sha256=sha(lef))))
if __name__=='__main__':main()
