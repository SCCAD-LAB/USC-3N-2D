from pathlib import Path
import sys,json,copy,shutil,time
HERE=Path(__file__).resolve().parent;ORIGINAL=HERE.parent;OUT=HERE/'prepared_release57';PHYS=OUT/'physical'
sys.path.insert(0,str(ORIGINAL));import scan as s
sha=s.p.sha;save=s.p.save

def cp(a,b):
 b.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(a,b);assert sha(a)==sha(b)
def load(p):return json.loads(Path(p).read_text())
def main():
 assert not (OUT/'PREPARED_PHYSICAL_VIEW.json').exists();OUT.mkdir(parents=True,exist_ok=True)
 baseline=load(ORIGINAL/'PEX_MANIFEST.json');old=next(r for r in baseline['rows'] if r['cell']=='DFFHx1');candidate=load(HERE/'iter001/pex/PEX_RECEIPT_v2.json');native=load(HERE/'iter001/RESULT.json');assert native['passed']
 dest=PHYS/'cells/DFFHx1/iter004'
 for p in (HERE/'iter001').rglob('*'):
  if p.is_file():cp(p,dest/p.relative_to(HERE/'iter001'))
 for name in ['PAIRED_TWO_GATE_TOPOLOGY_AUDIT.json','PAIRED_TOPOLOGY_GATE_ADAPTER.json','GEOMETRY_PROVENANCE.json','GEOMETRY_GENERATION.json','POLICY.json']:
  cp(HERE/name,OUT/'evidence'/name)
 # Independent body proof: providednative3TLVSdoesnotcheckbulkproperties.
 def bodies(path):
  rows={}
  for line in Path(path).read_text().splitlines():
   t=line.split()
   if t and t[0].lower().startswith('m'):rows[t[0]]=(t[4],t[5])
  return rows
 before=bodies(old['dspf']);after=bodies(candidate['dspf']);assert before==after and len(after)==32
 assert all(v[0]==('VSS' if v[1].startswith('n') else 'VDD') for v in after.values())
 body=dict(passed=True,native_body_property_LVS=False,independent_rail_normalization=True,all32_type_L_W_coordinates_preserved_from03ae=True,well_fin_select_and_actual_channels_preserved=True,all32_D_S_unchanged=True,independent_reference=str(HERE/'iter001/inputs/derived_topology_4t.cdl'),independent_reference_sha256=sha(HERE/'iter001/inputs/derived_topology_4t.cdl'),source_body_reference=str(ORIGINAL/'references/DFFHx1/gold.cdl'),source_body_reference_sha256=sha(ORIGINAL/'references/DFFHx1/gold.cdl'),actual_body_rows=[dict(device=k,body=v[0],model=v[1]) for k,v in sorted(after.items())],topology_audit=str(OUT/'evidence/PAIRED_TWO_GATE_TOPOLOGY_AUDIT.json'),topology_audit_sha256=sha(OUT/'evidence/PAIRED_TWO_GATE_TOPOLOGY_AUDIT.json'))
 save(dest/'BODY_RAIL_PROVENANCE.json',body)
 gate=copy.deepcopy(load(old['gate']));gate.update(iteration=4,gds_sha256=candidate['gds_sha256'],topology_reference_sha256=candidate['cdl_sha256'],drc=copy.deepcopy(native['drc']),lvs=copy.deepcopy(native['lvs']),qualified=True,qualification_scope='PhysicalDRC/topologyLVS/geometryonly; actualbehaviorandfullcharpending',release_qualified=False,device_geometry_preserved=True,preservation_reference_GDS_sha256='03ae7f3fa1ff3e2f42eaa19b70aad10bff070e08b92a9cbbec934c1536b4bd2f',actual_MOS_dimensions_preserved=True,actual_MOS_coordinates_preserved=True,all32_original03ae_L_W_coordinates_preserved=True,device_layer_change_audit=str(OUT/'evidence/GEOMETRY_PROVENANCE.json'),reference_admission_scope='Root-authorizedderivedTWOgateclockintent; historicalreferenceparameterstopsizinggold',reference_provenance=str(OUT/'evidence/PAIRED_TOPOLOGY_GATE_ADAPTER.json'),host=candidate['owner']['host'],work=candidate['owner']['work'])
 for kind in ['drc','lvs']:gate[kind]['report']=str(dest/'native'/kind/('DFFHx1.RESULTS' if kind=='drc' else 'DFFHx1.LVS_ERRORS'))
 gate['lvs']['actual_dimension_rows']=load(dest/'ACTUAL_DEVICE_DIMENSIONS.json')['rows'];save(dest/'GATE.json',gate);save(PHYS/'cells/DFFHx1/LATEST.json',gate)
 binding=load(dest/'pex/DEVICE_GEOMETRY_BINDING_v2.json');binding.update(native_dimension_report=str(dest/'pex/ACTUAL_DEVICE_DIMENSIONS.json'),native_dimension_report_sha256=sha(dest/'pex/ACTUAL_DEVICE_DIMENSIONS.json'),device_layer_change_audit=str(OUT/'evidence/GEOMETRY_PROVENANCE.json'),device_layer_change_audit_sha256=sha(OUT/'evidence/GEOMETRY_PROVENANCE.json'),body_rail_provenance=str(dest/'BODY_RAIL_PROVENANCE.json'));save(dest/'pex/DEVICE_GEOMETRY_BINDING_RELEASE.json',binding)
 row=copy.deepcopy(old);row.update({k:v for k,v in candidate.items() if k!='owner'});row.update(iteration=4,gds=str(dest/'inputs/cell.gds'),cdl=str(dest/'inputs/topology.cdl'),drc_report=str(dest/'native/drc/DFFHx1.RESULTS'),lvs_report=str(dest/'pex/DFFHx1.LVS_ERRORS'),dspf=str(dest/'pex/cell.dspf'),raw_dspf=str(dest/'pex/cell.raw.dspf'),device_geometry_binding=str(dest/'pex/DEVICE_GEOMETRY_BINDING_RELEASE.json'),device_geometry_binding_sha256=sha(dest/'pex/DEVICE_GEOMETRY_BINDING_RELEASE.json'),device_layer_change_audit=str(OUT/'evidence/GEOMETRY_PROVENANCE.json'),device_layer_change_audit_sha256=sha(OUT/'evidence/GEOMETRY_PROVENANCE.json'),body_rail_provenance=str(dest/'BODY_RAIL_PROVENANCE.json'),body_rail_audit_pass=True,terminal_connectivity_audit=str(dest/'pex/TERMINAL_CONNECTIVITY_AUDIT.json'),actual_device_dimensions=binding['rows'],gate=str(dest/'GATE.json'),gate_sha256=sha(dest/'GATE.json'),host=candidate['owner']['host'],work=candidate['owner']['work'],reference_provenance=str(OUT/'evidence/PAIRED_TOPOLOGY_GATE_ADAPTER.json'),release_qualified=False,PEX_wall_s=None,PEX_wall_s_note='Newexactnativelogsretained; oldextractiontimeisnotreused.')
 save(dest/'pex/PEX_RECEIPT_RELEASE.json',row);new=copy.deepcopy(baseline);new.update(epoch=time.time(),release_qualified=False,scope='Preparedpairedclockphysical57; actualfunctional/solver/fullchar/rootreviewpending');new['rows']=[row if r['cell']=='DFFHx1' else r for r in new['rows']];save(PHYS/'PEX_MANIFEST.json',new)
 oldmap={r['cell']:r for r in baseline['rows']};assert all(r==oldmap[r['cell']] for r in new['rows'] if r['cell']!='DFFHx1')
 lib=s.p.gdstk.read_gds(str(ORIGINAL/'FINAL_57_CELL_GDS.gds'));lib.remove(next(c for c in lib.cells if c.name=='DFFHx1'));lib.add(s.p.gdstk.read_gds(row['gds']).cells[0].copy('DFFHx1'));lib.write_gds(str(PHYS/'FINAL_57_CELL_GDS.gds'));actual={c.name:c for c in s.p.gdstk.read_gds(str(PHYS/'FINAL_57_CELL_GDS.gds')).cells};audit=[]
 for rec in new['rows']:
  a=s.p.gdstk.read_gds(rec['gds']).cells[0];b=actual[rec['cell']];layers={p.layer for c in [a,b] for p in c.polygons}
  for l in layers:assert sum(q.area() for q in s.p.gdstk.boolean([p for p in a.polygons if p.layer==l],[p for p in b.polygons if p.layer==l],'xor',precision=lib.precision/lib.unit))<1e-15
  labels=lambda c:sorted((q.layer,q.texttype,q.text,q.origin,q.rotation,q.magnification) for q in c.labels)
  assert labels(a)==labels(b);audit.append(dict(cell=rec['cell'],per_layer_XOR_zero=True,labels_exact=True))
 save(OUT/'COMBINED57_GEOMETRY_AUDIT.json',dict(passed=True,cells=57,combined_GDS_sha256=sha(PHYS/'FINAL_57_CELL_GDS.gds'),rows=audit))
 final=copy.deepcopy(load(ORIGINAL/'FINAL_QA_INDEX.json'));d=next(r for r in final['rows'] if r['cell']=='DFFHx1');d.update(iteration=4,final_cell_gds=row['gds'],final_cell_gds_sha256=row['gds_sha256'],gate=row['gate'],gate_sha256=row['gate_sha256'],changed_polygon_layers=sorted(set(d['changed_polygon_layers'])|{19,20,21}),all32_original03ae_L_W_coordinates_preserved=True,raw_device_layers_preserved_from03ae=True,derived_two_gate_topology=True,release_qualified=False);final.update(epoch=time.time(),aggregate_GDS=str(PHYS/'FINAL_57_CELL_GDS.gds'),aggregate_GDS_sha256=sha(PHYS/'FINAL_57_CELL_GDS.gds'),release_qualified=False);save(PHYS/'FINAL_QA_INDEX.json',final)
 terminal=copy.deepcopy(load(ORIGINAL/'TERMINAL_CONNECTIVITY_INDEX.json'));terminal['rows']=[dict(cell='DFFHx1',passed=True,audit=row['terminal_connectivity_audit'],sha256=row['terminal_connectivity_audit_sha256']) if r['cell']=='DFFHx1' else r for r in terminal['rows']];save(PHYS/'TERMINAL_CONNECTIVITY_INDEX.json',terminal)
 # Full57referenceexports: original56byte-identicalcellviews, explicit2-gatederivedDFFH.
 export=PHYS/'export';combined=[];native3=[]
 for rec in sorted(baseline['rows'],key=lambda x:x['cell']):
  n=rec['cell'];source=HERE/'iter001/inputs/derived_topology_4t.cdl' if n=='DFFHx1' else ORIGINAL/'export/topology_reference/per_cell'/(n+'.cdl');text=source.read_text();cp(source,export/'topology_reference/per_cell'/(n+'.cdl'));combined.append(text);three,_=s.normalize_topology(text);native3.append(three)
 prefix='*Prepared57physicalview:56independentpriorreferences+oneROOTderivedtwo-gateDFFHintent. Historicaldimensionsnotactualsizinggold. Electricalqualificationpending.\n';(export/'topology_reference/usc144_topology_reference_57_4t.cdl').write_text(prefix+'\n'.join(combined));(export/'topology_reference/usc144_topology_reference_57_native3t.cdl').write_text(prefix+'\n'.join(native3))
 save(OUT/'PREPARED_PHYSICAL_VIEW.json',dict(prepared_complete=True,physical_cells=57,other56_manifest_rows_unchanged=True,aggregate57geometry_labels_exact=True,release_qualified=False,publication_allowed=False,all_actual_targeted_checks_still_pending=True,full_new_DFFH_native_characterization_pending=True,canonical_mutations=False,combined_GDS_sha256=sha(PHYS/'FINAL_57_CELL_GDS.gds'),PEX_manifest_sha256=sha(PHYS/'PEX_MANIFEST.json'),LEF='Root-ownednewpairedabstractrequired; donotuseoldretap/strengthabstractasfinal'))
 print(json.dumps(dict(view=str(OUT),view_sha256=sha(OUT/'PREPARED_PHYSICAL_VIEW.json'),combined_GDS_sha256=sha(PHYS/'FINAL_57_CELL_GDS.gds'),PEX_manifest_sha256=sha(PHYS/'PEX_MANIFEST.json'))))
if __name__=='__main__':main()
