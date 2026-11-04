#!/usr/bin/env python3
"""Rehash release physical evidence and publish actual per-cell before/after data."""
from pathlib import Path
import csv,json,time,re
import scan as s
ROOT=s.ROOT

def main():
 manifest=json.loads((ROOT/'PEX_MANIFEST.json').read_text());pex={r['cell']:r for r in manifest['rows']};rows=[];allcells=[];failures=[]
 for latest in sorted((ROOT/'cells').glob('*/LATEST.json')):
  gate=json.loads(latest.read_text());name=gate['cell'];it=gate['iteration'];initial=ROOT/'cells'/name/'iter000/inputs/cell.gds';current=ROOT/'cells'/name/f'iter{it:03d}/inputs/cell.gds'
  a=s.p.gdstk.read_gds(str(initial)).cells[0];b=s.p.gdstk.read_gds(str(current)).cells[0];layers={p.layer for p in a.polygons}|{p.layer for p in b.polygons};changed=[k for k in sorted(layers) if s.geometry_hash(a,{k})!=s.geometry_hash(b,{k})]
  labels=lambda c:sorted((p.layer,p.texttype,p.text,tuple(p.origin),p.rotation,p.magnification) for p in c.labels)
  label_same=labels(a)==labels(b);boundary_same=s.geometry_hash(a,{100})==s.geometry_hash(b,{100});errors=[]
  if s.p.sha(current)!=gate['gds_sha256']:errors.append('final GDS hash differs from native gate')
  if not label_same:errors.append('source text labels changed')
  if not boundary_same:errors.append('source site boundary layer100 changed')
  for kind in ['drc','lvs']:
   r=gate[kind]
   if s.p.sha(r['report'])!=r['report_sha256']:errors.append(kind+' report hash changed')
  if gate['qualified']:
   if gate['drc_violations']!=0 or not gate['topology_LVS_pass']:errors.append('qualified gate not native DRC0/LVS PASS')
   if list(map(int,gate['drc']['rules_run']))!=[121] or list(map(int,gate['drc']['rules_not_executed']))!=[0]:errors.append('unexpected native rule coverage')
   allcells.append(b.copy(name))
  r=pex.get(name);pex_good=False
  if r:
   for field in ['gds','dspf','raw_dspf','device_geometry_binding','gate','terminal_connectivity_audit']:
    if s.p.sha(r[field])!=r[field+'_sha256']:errors.append('PEX manifest '+field+' hash changed')
   if r['gds_sha256']!=gate['gds_sha256']:errors.append('PEX GDS differs from current gate')
   if r['grid_sha256']!=s.p.sha(ROOT.parent/'sources/github_FSPR.nxtgrd'):errors.append('PEX process grid changed')
   if not r.get('terminal_connectivity_pass'):errors.append('PEX terminal connectivity audit not passed')
   pex_good=not errors and r['fresh_native_StarRC']
  old=json.loads((ROOT/'cells'/name/'iter000/GATE.json').read_text());initial_report=Path(old['drc']['report']);initial_match=re.search(r'There (?:are|is) (\d+) total violation',initial_report.read_text());initial_count=int(initial_match[1]) if initial_match else None
  if initial_count is None:errors.append('Initial native DRC count could not be parsed')
  it1=json.loads((ROOT/'cells'/name/'iter001/GATE.json').read_text())
  rows.append(dict(cell=name,iteration=it,qualified=gate['qualified'],initial_DRC=initial_count,initial_DRC_report=str(initial_report),initial_DRC_report_sha256=s.p.sha(initial_report),legacy_initial_count=old['drc_violations'],final_DRC=gate['drc_violations'],after_enclosure_repair_topology_LVS=it1['topology_LVS_pass'],source_native_LVS_invocation_rc=old['lvs']['rc'],source_LVS_scope='iter000 had three-terminal versus four-terminal reference-format failure. iter001 is the first normalized independent-topology check, after M1 enclosure-only repair; do not call that an exact original-GDS LVS result.',final_topology_LVS=gate['topology_LVS_pass'],changed_polygon_layers=changed,labels_preserved=label_same,site_boundary_preserved=boundary_same,raw_device_layers_preserved=gate['device_geometry_preserved'],device_layer_change_authorized=gate.get('device_layer_change_authorized',False),actual_MOS_dimensions_preserved=gate['actual_MOS_dimensions_preserved'],native_property_checks_enabled=False,source_MOS_count=len(json.loads((ROOT/'cells'/name/'INITIAL_DEVICE_DIMENSIONS.json').read_text())['rows']),final_MOS_count=len(gate['lvs']['actual_dimension_rows']),source_cell_gds=str(initial),source_cell_gds_sha256=s.p.sha(initial),final_cell_gds=str(current),final_cell_gds_sha256=s.p.sha(current),gate=str(ROOT/'cells'/name/f'iter{it:03d}/GATE.json'),gate_sha256=s.p.sha(ROOT/'cells'/name/f'iter{it:03d}/GATE.json'),fresh_PEX_verified=pex_good,terminal_connectivity_pass=bool(r and r.get('terminal_connectivity_pass')),errors=errors))
  failures.extend(dict(cell=name,error=e) for e in errors)
 lib=s.p.gdstk.Library(unit=1e-6,precision=2.5e-10);lib.add(*allcells);output=ROOT/('FINAL_57_CELL_GDS.gds' if len(allcells)==57 else 'QUALIFIED_CELL_GDS.gds')
 if output.exists():
  archived={c.name:c for c in s.p.gdstk.read_gds(str(output)).cells};expected={c.name:c for c in allcells};identical=set(archived)==set(expected)
  for name,c in expected.items():
   other=archived.get(name)
   if other is None:identical=False;continue
   layers={p.layer for p in c.polygons}|{p.layer for p in other.polygons}
   identical=identical and s.geometry_hash(c,layers)==s.geometry_hash(other,layers) and labels(c)==labels(other)
  if not identical:
   if len(allcells)==57:raise RuntimeError('Frozen full57 aggregate geometry changed; preserve and investigate')
   lib.write_gds(str(output))
 else:lib.write_gds(str(output))
 record=dict(epoch=time.time(),complete=len(rows)==57 and len(allcells)==57 and sum(r['fresh_PEX_verified'] for r in rows)==57 and not failures,qualified=len(allcells),fresh_PEX_verified=sum(r['fresh_PEX_verified'] for r in rows),failures=failures,aggregate_GDS=str(output),aggregate_GDS_sha256=s.p.sha(output),rows=rows)
 s.p.save(ROOT/'FINAL_QA_INDEX.json',record)
 with (ROOT/'RAW_PHYSICAL_BEFORE_AFTER.csv').open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
 print(json.dumps({k:v for k,v in record.items() if k!='rows'},indent=2))
if __name__=='__main__':main()
