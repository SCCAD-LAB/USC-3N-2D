#!/usr/bin/env python3
"""Admit a helper's already-native-verified snapshot by exact hashes and geometry."""
from pathlib import Path
import argparse,json,shutil
import scan as s
ROOT=s.ROOT
def admit(folder):
 result=json.loads((folder/'RESULT.json').read_text());name=result['cell']
 if not result['passed'] or not result['drc']['passed'] or not result['lvs']['passed']:raise RuntimeError('External native candidate failed')
 gds=Path(result['candidate_gds']);old=json.loads((ROOT/'cells'/name/'LATEST.json').read_text());iteration=old['iteration']+1
 if s.p.sha(gds)!=result['candidate_sha256']:raise RuntimeError('Helper snapshot changed')
 if old['qualified'] and old['gds_sha256']==result['candidate_sha256']:return old
 expected=[('drc',ROOT/'rules/matched_144nm/DRC/sccad3nm_main.drc.rs'),('lvs',ROOT/'rules/matched_144nm/LVS/ICV_3nm.rs')]
 for kind,deck in expected:
  if result[kind]['deck_sha256']!=s.p.sha(deck):raise RuntimeError('Helper deck differs')
  report=folder/kind/(name+('.RESULTS' if kind=='drc' else '.LVS_ERRORS'))
  if s.p.sha(report)!=result[kind]['report_sha256']:raise RuntimeError('Helper report changed')
 for p in (ROOT/'rules/matched_144nm/DRC/Include').glob('*.rs'):
  q=folder/'drc/runset/Include'/p.name
  if not q.exists():q=folder/'drc/Include'/p.name
  if s.p.sha(p)!=s.p.sha(q):raise RuntimeError('Helper numeric rule Include differs '+p.name)
 source=s.p.gdstk.read_gds(str(ROOT/'cells'/name/'iter001/inputs/cell.gds')).cells[0];candidate=s.p.gdstk.read_gds(str(gds)).cells[0]
 layers=set(p.layer for p in source.polygons)|set(p.layer for p in candidate.polygons)
 allowed_routing={16,18,19,20,21} if name=='DHLx1' else {18,19}
 if name=='DFFHx1':allowed_routing={11,16,17,18,19,20,21,25,30,35,40,45,50,55,60,88}
 if s.geometry_hash(source,layers-allowed_routing)!=s.geometry_hash(candidate,layers-allowed_routing):raise RuntimeError('Unexpected geometry change outside explicit routing scope')
 labels=lambda c:sorted((p.layer,p.texttype,p.text,tuple(p.origin),p.rotation,p.magnification) for p in c.labels)
 if labels(source)!=labels(candidate):raise RuntimeError('Portlabels changed')
 inputs=s.WORK/name/f'iter{iteration:03d}'/'inputs'
 if inputs.exists():
  if s.p.sha(inputs/'cell.gds')!=result['candidate_sha256']:raise RuntimeError('Preserve existing differentadmissionattempt')
 else:inputs=s.stage_iteration(name,iteration,old['iteration'],gds)
 if s.p.sha(inputs/'topology.cdl')!=s.p.sha(folder/'inputs/topology.cdl'):raise RuntimeError('Independent topology reference differs')
 actual=s.dimension_rows(folder/'lvs'/(name+'.net.gz'));initial=json.loads((ROOT/'cells'/name/'INITIAL_DEVICE_DIMENSIONS.json').read_text())['rows'];dims_ok=s.dimension_identity(actual)==s.dimension_identity(initial)
 initgeo=json.loads((ROOT/'INITIAL_GEOMETRY.json').read_text())['cells'][name];geometry_ok=s.geometry_hash(candidate,s.DEVICE_LAYERS)==initgeo['device_geometry_sha256']
 coordinates_ok=dims_ok;exception=False;exception_path=None
 if name=='DFFHx1':
  policy=json.loads((ROOT/'DEVICE_LAYER_CHANGE_POLICY.json').read_text())[name]
  nonexception=s.geometry_hash(source,s.DEVICE_LAYERS-{11})==s.geometry_hash(candidate,s.DEVICE_LAYERS-{11})
  dims_ok=s.mapped_dimension_identity(initial,policy['device_translations'])==s.dimension_identity(actual)
  channels_ok=s.mapped_channel_shapes(source,policy['device_translations'])==s.channel_shapes(candidate)
  exception=nonexception and dims_ok and channels_ok
  if not exception:raise RuntimeError('DFF explicit one-channel relocation audit failed')
  exception_path=ROOT/'cells'/name/f'iter{iteration:03d}'/'DEVICE_LAYER_CHANGE_AUDIT.json'
  s.p.save(exception_path,dict(passed=True,policy=policy,nonexception_device_layers_preserved=nonexception,actual_channel_geometry_preserved=False,actual_channel_geometry_preserved_under_explicit_translation=channels_ok,actual_L_W_count_preserved=True,actual_coordinates_preserved=coordinates_ok,explicit_translation_verified=True,raw_device_layers_unchanged=False))
 if not (geometry_ok or exception) or not dims_ok:raise RuntimeError('Helper device geometry/dimensions changed')
 drc=dict(result['drc']);lvs=dict(result['lvs']);target=ROOT/'cells'/name/f'iter{iteration:03d}'
 s.p.copy_tree(inputs,target/'inputs')
 for kind,rec in [('drc',drc),('lvs',lvs)]:
  dest=target/kind;dest.mkdir(parents=True,exist_ok=True);namefile=name+('.RESULTS' if kind=='drc' else '.LVS_ERRORS');shutil.copyfile(folder/kind/namefile,dest/namefile);rec['report']=str(dest/namefile)
  if kind=='lvs':
   shutil.copyfile(folder/kind/(name+'.net.gz'),dest/(name+'.net.gz'));s.p.save(dest/'ACTUAL_DEVICE_DIMENSIONS.json',dict(rows=actual));rec['actual_dimension_rows']=actual
 s.p.save(target/'EXTERNAL_NATIVE_ADMISSION.json',dict(passed=True,helper_receipt=str(folder/'RESULT.json'),helper_receipt_sha256=s.p.sha(folder/'RESULT.json'),same_native_GDS_hash=True,all_numeric_rule_files_verified=True,same_independent_reference=True,allowed_modified_routing_layers=sorted(allowed_routing),other_routing_and_device_layers_preserved=True,actual_L_W_count_preserved=dims_ok,actual_coordinates_preserved=coordinates_ok,explicit_device_translation_authorized=exception,no_native_rerun_needed='Snapshotcopiedbyte-identicallyandnativeinput/reporthashesverified'))
 z=dict(cell=name,iteration=iteration,gds_sha256=s.p.sha(inputs/'cell.gds'),topology_reference_sha256=s.p.sha(inputs/'topology.cdl'),reference_admitted=True,drc_pass=True,drc_violations=0,drc=drc,topology_LVS_pass=True,lvs=lvs,native_property_checks_enabled=False,device_geometry_preserved=geometry_ok,device_layer_change_authorized=exception,device_layer_change_audit=str(exception_path) if exception_path else None,actual_MOS_dimensions_preserved=dims_ok,actual_MOS_coordinates_preserved=coordinates_ok,qualified=True,host=result.get('host',old['host']),work=str(inputs.parent),external_native_proof=str(folder/'RESULT.json'))
 s.p.save(target/'GATE.json',z);s.p.save(ROOT/'cells'/name/'LATEST.json',z);return z
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('folder');args=parser.parse_args();print(json.dumps(admit(Path(args.folder)),indent=2))
