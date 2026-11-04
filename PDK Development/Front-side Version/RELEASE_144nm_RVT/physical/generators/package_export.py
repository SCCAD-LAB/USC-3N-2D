#!/usr/bin/env python3
"""Package immutable physical release sources and explicit topology-only references."""
from pathlib import Path
import hashlib,json,re,shutil,time
import scan as s
ROOT=s.ROOT;OUT=ROOT/'export'
def copy(source,destination):
 destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,destination)
 if s.p.sha(source)!=s.p.sha(destination):raise RuntimeError('Export bytecopy mismatch')
def main():
 final=json.loads((ROOT/'FINAL_QA_INDEX.json').read_text());terminal=json.loads((ROOT/'TERMINAL_CONNECTIVITY_INDEX.json').read_text())
 if not final['complete'] or terminal['passed']!=57 or terminal['failures']:raise RuntimeError('Final57 physical gates not complete')
 OUT.mkdir(parents=True,exist_ok=True);refs=json.loads((ROOT/'REFERENCE_ADMISSION.json').read_text());combined=[];normalized=[];reference_rows=[]
 for r in sorted(refs['rows'],key=lambda r:r['cell']):
  name=r['cell'];source=Path(r['gold_cdl'])
  if not r['topology_reference_admitted'] or s.p.sha(source)!=r['gold_sha256']:raise RuntimeError('Independent topology reference identity failed')
  text=source.read_text();header='* ADMITTED INDEPENDENT TOPOLOGY REFERENCE: '+name+'\n* Prior independent2024 dimensions retained; not final144nm sizing gold.\n'
  combined.append(header+text);three,bulk=s.normalize_topology(text);normalized.append(header+three)
  copy(source,OUT/'topology_reference/per_cell'/(name+'.cdl'))
  reference_rows.append(dict(cell=name,reference_cdl=str(source),reference_sha256=s.p.sha(source),prior_circuit_source=r['prior_circuit_source'],prior_circuit_source_sha256=r['prior_circuit_source_sha256'],independent_archive=r['independent_archive'],independent_archive_sha256=r['independent_archive_sha256'],native_property_checks_enabled=False,parametric_gold=False))
 prefix='*57-cell topology-only independent reference. Not extracted from final144nm DUT.\n* Final device sizes and WGAA bindings are independently audited in final4TPEX + perMOS geometry binding receipts.\n* Native topology deck checks3terminals and disables no originally-enabled property checks; original deck has no property checks.\n'
 (OUT/'topology_reference/usc144_topology_reference_57_4t.cdl').write_text(prefix+'\n'.join(combined))
 (OUT/'topology_reference/usc144_topology_reference_57_native3t.cdl').write_text(prefix+'* Explicit independently grounded body rails omitted only to match native3T deck.\n'+'\n'.join(normalized))
 for folder in ['rules/github','rules/matched_144nm']:
  for source in (ROOT/folder).rglob('*'):
   if source.is_file():copy(source,OUT/source.relative_to(ROOT))
 scripts=['preflight.py','scan.py','admit_references.py','repair_common.py','repair_notches.py','repair_buf3.py','dff_act_probe.py','admit_routing_candidate.py','pex_fspr.py','terminal_connectivity.py','final_audit.py','package_export.py']
 for name in scripts:copy(ROOT/name,OUT/'generators'/name)
 for source in sorted((ROOT/'routing_repairs').glob('candidate*.py')):copy(source,OUT/'generators/routing_repairs'/source.name)
 receipts=['RULE_SOURCES.json','RULE_ADAPTER.json','REFERENCE_ADMISSION.json','DEVICE_LAYER_CHANGE_POLICY.json','FSPR_EMPTY_LAYER_AUDIT.json','FINAL_QA_INDEX.json','RAW_PHYSICAL_BEFORE_AFTER.csv','TERMINAL_CONNECTIVITY_INDEX.json','PEX_MANIFEST.json','PHYSICAL_ITERATION_HISTORY.json','PHYSICAL_ITERATION_HISTORY.csv']
 for name in receipts:copy(ROOT/name,OUT/'evidence'/name)
 for name in ['INDEPENDENT_REFERENCE_LOGIC.json','independent_old_circuit_candidates/MANIFEST.json']:
  source=ROOT.parent/'reports'/name
  if source.exists():copy(source,OUT/'evidence'/(Path(name).name))
 pex=json.loads((ROOT/'PEX_MANIFEST.json').read_text())['rows'];actual=[]
 for r in pex:
  cell=r['cell'];dest=OUT/'actual_size_4t_PEX'/cell
  for field,filename in [('dspf','cell.dspf'),('device_geometry_binding','DEVICE_GEOMETRY_BINDING.json'),('terminal_connectivity_audit','TERMINAL_CONNECTIVITY_AUDIT.json')]:
   if s.p.sha(r[field])!=r[field+'_sha256']:raise RuntimeError('Actual-size PEX export hash differs')
   copy(Path(r[field]),dest/filename)
  if r.get('device_layer_change_audit'):copy(Path(r['device_layer_change_audit']),dest/'DEVICE_LAYER_CHANGE_AUDIT.json')
  actual.append(dict(cell=cell,dspf=str(dest/'cell.dspf'),dspf_sha256=r['dspf_sha256'],device_binding=str(dest/'DEVICE_GEOMETRY_BINDING.json'),device_binding_sha256=r['device_geometry_binding_sha256'],terminal_connectivity_pass=True,source='Final same-GDS native StarRC4TPEX; sizing from frozen144nm geometry; independent bodies from topology reference; includes approved fullRC.'))
 copy(ROOT/'FINAL_57_CELL_GDS.gds',OUT/'layout/usc144_drc_lvs_clean_57.gds')
 scope=dict(topology_reference_scope='Independent prior2024 circuit topology; retained prior L/W are NOT final144nm device sizing gold. Native LVS property checks are disabled in original provided production deck and separately reported.',actual_size_source='Use actual_size_4t_PEX per-cell DSPFs and exact final-GDS/native-LVS/PEX perMOS bindings. Classic W alone does not bind GEOMOD5; use approved WGAA geometry aliases from characterization.',physical_exceptions='BUFx3 only out-of-channel bottomGCUT clearance; DFFHx1 exactly one NMOS L12/W19 translates42nm x, all other31 coordinates and all32L/W preserved.',rule_scope='121 implemented official DRC rules, zero not-executed; numeric rules unchanged. Corrected V1/M6/MBPR layer assignments; fin-aware SW production LVS. PEX removes only physically empty unmodeled BPR/P_SUB maps; frozen FSPR RHO15/grid unchanged.',independent_references=reference_rows,actual_size_views=actual)
 s.p.save(OUT/'SCOPE_AND_PROVENANCE.json',scope)
 files=[]
 for f in sorted(OUT.rglob('*')):
  if f.is_file() and f.name!='EXPORT_MANIFEST.json':files.append(dict(path=str(f.relative_to(OUT)),sha256=s.p.sha(f),bytes=f.stat().st_size))
 manifest=dict(complete=True,cells=57,epoch=time.time(),root=str(OUT),topology_reference_4t=str(OUT/'topology_reference/usc144_topology_reference_57_4t.cdl'),topology_reference_native3t=str(OUT/'topology_reference/usc144_topology_reference_57_native3t.cdl'),final_geometry_GDS=str(OUT/'layout/usc144_drc_lvs_clean_57.gds'),files=files)
 s.p.save(OUT/'EXPORT_MANIFEST.json',manifest);print(json.dumps(dict(files=len(files),bytes=sum(r['bytes'] for r in files),topology_reference=manifest['topology_reference_4t'],manifest=str(OUT/'EXPORT_MANIFEST.json')),indent=2))
if __name__=='__main__':main()
