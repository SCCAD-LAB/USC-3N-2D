#!/usr/bin/env python3
"""FSPR-only native PEX adapter; omit only proven-empty unmodeled layer bindings."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,fcntl,json,math,os,re,shutil,socket,subprocess,time,traceback
import scan as s
import repair_common as common
import terminal_connectivity as terminal
ROOT=s.ROOT;WORK=s.WORK

def stage_adapter():
 lib=s.p.gdstk.read_gds(str(ROOT.parent/'sources/input_144nm.gds'));counts={k:dict(polygons=0,labels=0) for k in [3,14,15]}
 for c in lib.cells:
  for p in c.polygons:
   if p.layer in counts:counts[p.layer]['polygons']+=1
  for p in c.labels:
   if p.layer in counts:counts[p.layer]['labels']+=1
 if any(row['polygons'] for row in counts.values()):raise RuntimeError('Unmodeled conducting polygons are NOT empty; do not omit')
 # P_SUB has inherited VSS text labels but no physical polygons. The provided
 # marker expression is text_origin(P_SUB_text) AND P_SUB, hence also empty.
 # Preserve all text and LVS connections; omit only the empty PEX layer bindings.
 for c in lib.cells:
  for label in c.labels:
   if label.layer in [3,14,15] and not (label.layer==3 and label.text=='VSS'):raise RuntimeError('Unmodeled non-body label requires investigation')
 source=ROOT/'rules/matched_144nm/LVS/ICV_3nm.rs';text=source.read_text();changes=[]
 for function,layer in [('pex_conducting_layer_map','MBPR'),('pex_conducting_layer_map','P_SUB'),('pex_via_layer_map','VBPR'),('pex_marker_layer_map','P_SUB_pin'),('pex_marker_layer_map','MBPR_pin')]:
  pattern=r'(?m)^[ \t]*'+function+r'\(pex_matrix,\s*'+layer+r'\s*,[^\n]+\);[ \t]*$';matches=re.findall(pattern,text)
  if len(matches)!=1:raise RuntimeError('PEX adapter mapping missing/ambiguous '+layer)
  changes.append(dict(function=function,layer=layer,original=matches[0],reason='No source144nmconductingpolygons; correspondingpinmarker=textintersectionwithemptypolygonlayer. InheritedP_SUB/VSStextretainedinGDS/LVS. LayerabsentfromfrozenFSPRgrid.'))
  text=re.sub(pattern,'pex_remove_layer_map(pex_matrix, '+layer+', tagname = "EMPTY_FSPR_'+layer+'"); // proven-empty physical polygon/marker layer',text)
 deck=source.with_name('ICV_3nm_FSPR_PEX.rs');deck.write_text(text)
 s.p.save(ROOT/'FSPR_EMPTY_LAYER_AUDIT.json',dict(passed=True,input_gds_sha256=s.p.sha(ROOT.parent/'sources/input_144nm.gds'),cells=57,layer_counts=counts,inherited_P_SUB_VSS_text_retained=True,source_pin_marker_definitions='P_SUB_pin=P_SUB_mark_all and P_SUB; MBPR_pin=MBPR_mark_all and MBPR; bothpolygonlayershavezeroshapesinall57cells',source_LVS_sha256=s.p.sha(source),adapter_sha256=s.p.sha(deck),changes=changes,DRC_rules_changed=False,LVS_connectivity_rules_changed=False,device_extraction_rules_changed=False,actual_conductors_omitted=False,grid=str(ROOT.parent/'sources/github_FSPR.nxtgrd'),grid_sha256=s.p.sha(ROOT.parent/'sources/github_FSPR.nxtgrd')))
 return deck

def quantity(token):
 match=re.fullmatch(r'([-+\d.eE]+)([a-zA-Z]*)',token)
 if not match:raise RuntimeError('Invalid numericdevicequantity '+token)
 suffix=match[2].lower();scale={'':1.,'u':1e-6,'n':1e-9,'p':1e-12,'m':1e-3}.get(suffix)
 if scale is None:raise RuntimeError('Unrecognized deviceunit '+token)
 return float(match[1])*scale*1e9

def binding_receipt(cell,raw,gate,body):
 actual={r['device'].lower():r for r in gate['lvs']['actual_dimension_rows']};rows=[];seen=set()
 for line in raw.splitlines():
  tokens=line.split()
  if not tokens or not tokens[0].lower().startswith('m'):continue
  name=tokens[0];key=name.lower()
  if key not in actual:
   candidates=[k for k in actual if re.sub(r'^m+','',k)==re.sub(r'^m+','',key)]
   if len(candidates)!=1:raise RuntimeError('Cannot bind StarRCMOS identity to nativeGDSdevice '+str((cell,name,candidates)))
   key=candidates[0]
  if key in seen:raise RuntimeError('Merged/duplicate PEXMOS identity '+cell)
  seen.add(key);a=actual[key];properties={k.lower():v for k,v in re.findall(r'(\w+)\s*=\s*([^\s]+)',line)}
  if not all(k in properties for k in ['l','w']):raise RuntimeError('PEXdidnotemitactualL/W '+line)
  l=quantity(properties['l']);w=quantity(properties['w'])
  if abs(l-a['L_nm'])>1e-6 or abs(w-a['W_nm'])>1e-6:raise RuntimeError('PEXdevice dimensions mismatch GDSnativeextract '+str((cell,name,l,w,a)))
  rows.append(dict(PEX_instance=name,ICV_instance=a['device'],model=a['type'],gate_x_nm=a['x_nm'],gate_y_nm=a['y_nm'],source144_L_nm=a['L_nm'],source144_W_nm=a['W_nm'],final_PEX_L_nm=l,final_PEX_W_nm=w,merged=False,multiplicity=properties.get('m','1'),independent_body_rail='VSS' if a['type'].lower().startswith('n') else 'VDD'))
 if len(rows)!=len(actual):raise RuntimeError('Parallelmerge/device-countambiguity '+cell)
 dim=Path(gate['lvs']['report']).parent/'ACTUAL_DEVICE_DIMENSIONS.json';initial=ROOT/'cells'/cell/'INITIAL_DEVICE_DIMENSIONS.json'
 return dict(passed=True,cell=cell,source_GDS_sha256=gate['gds_sha256'],native_dimension_report=str(dim),native_dimension_report_sha256=s.p.sha(dim),initial144_dimension_report=str(initial),initial144_dimension_report_sha256=s.p.sha(initial),native_property_checks_enabled=False,device_geometry_preserved=gate['device_geometry_preserved'],device_layer_change_authorized=gate.get('device_layer_change_authorized',False),device_layer_change_audit=gate.get('device_layer_change_audit'),device_layer_change_audit_sha256=s.p.sha(gate['device_layer_change_audit']) if gate.get('device_layer_change_audit') else None,actual_MOS_dimensions_preserved=gate['actual_MOS_dimensions_preserved'],physical_device_count=len(actual),PEX_device_count=len(rows),parallel_merge_detected=False,rows=rows,body_rail_provenance=body,model_binding_note='ClassicSPICEWmaynotbindpublishedGAA modelWGAA; thisreceiptprovides actualgeometricwidthperMOS. WGAAaliases require independentbackendapproval; NFINmustnotbefractionallyscaled.')

def extract(cell,deck=None):
 deck=deck or ROOT/'rules/matched_144nm/LVS/ICV_3nm_FSPR_PEX.rs';gate=json.loads((ROOT/'cells'/cell/'LATEST.json').read_text());iteration=gate['iteration']
 if not gate['qualified']:raise RuntimeError('FSPRPEXrefused unqualifiedcell '+cell)
 manifest=ROOT/'PEX_MANIFEST.json'
 if manifest.exists():
  old=next((r for r in json.loads(manifest.read_text())['rows'] if r['cell']==cell),None)
  if old and old['gds_sha256']==gate['gds_sha256'] and s.p.sha(old['dspf'])==old['dspf_sha256'] and s.p.sha(old['device_geometry_binding'])==old['device_geometry_binding_sha256']:return old
 inputs=WORK/cell/f'iter{iteration:03d}'/'inputs';attempt=0
 while (inputs.parent/f'pex_lvs_FSPR_attempt{attempt:03d}').exists():attempt+=1
 work=inputs.parent/f'pex_lvs_FSPR_attempt{attempt:03d}';work.mkdir(parents=True,exist_ok=True)
 if s.p.sha(inputs/'cell.gds')!=gate['gds_sha256']:raise RuntimeError('GDSchangedaftercleangate')
 localdeck=work/'source_FSPR_PEX.rs';shutil.copyfile(deck,localdeck)
 cmd=[s.p.ICV,'-i',str(inputs/'cell.gds'),'-c',cell,'-f','GDSII','-host_init',socket.gethostname()+':2','-s',str(inputs/'topology.cdl'),'-sf','SPICE','-stc',cell,str(localdeck)]
 started=time.time()
 with (work/'icv.log').open('w') as f:rc=subprocess.run(cmd,cwd=work,env=s.p.ENV,stdout=f,stderr=subprocess.STDOUT,timeout=1200).returncode
 report=work/(cell+'.LVS_ERRORS')
 if rc or not report.exists() or 'Final comparison result:PASS' not in report.read_text():raise RuntimeError('FSPR-PEXsameGDSLVSfailed '+cell)
 fresh=s.dimension_rows(work/(cell+'.net.gz'))
 if s.dimension_identity(fresh)!=s.dimension_identity(gate['lvs']['actual_dimension_rows']):raise RuntimeError('PEX-onlyadapter changed deviceextraction '+cell)
 grid=ROOT.parent/'sources/github_FSPR.nxtgrd';out=work/'cell.raw.dspf'
 command=['BLOCK: '+cell,'TCAD_GRD_FILE: '+str(grid),'ICV_RUNSET_REPORT_FILE: '+str(work/'pex_runset_report'),'MAPPING_FILE: '+str(work/'starrcxt.mapping'),'STAR_DIRECTORY: '+str(work/'star'),'EXTRACTION: RC','NETLIST_FORMAT: SPF','NETLIST_FILE: '+str(out),'NETLIST_SUBCKT: YES','NETLIST_GROUND_NODE_NAME: VSS','POWER_NETS: *','POWER_EXTRACT: YES','CASE_SENSITIVE: YES','COUPLE_TO_GROUND: NO','REDUCTION: NO','NUM_CORES: 2']
 (work/'starrc.cmd').write_text('\n'.join(command)+'\n')
 with (work/'starrc.log').open('w') as f:rc=subprocess.run(['/tools/software/synopsys/starrc/latest/bin/StarXtract',str(work/'starrc.cmd')],cwd=work,env=s.p.ENV,stdout=f,stderr=subprocess.STDOUT,timeout=1200).returncode
 if rc or not out.exists():raise RuntimeError('NativeFSPRStarRCfailed '+cell)
 target=ROOT/'cells'/cell/f'iter{iteration:03d}'/'pex_FSPR'/f'attempt{attempt:03d}';target.mkdir(parents=True,exist_ok=True)
 explicit,body=common.explicit_bodies(out.read_text(),cell);binding=binding_receipt(cell,out.read_text(),gate,str(target/'BULK_REFERENCE_AUDIT.json'))
 for source in [out,report,work/'starrc.cmd',work/'starrc.log',work/'icv.log']:shutil.copyfile(source,target/source.name)
 (target/'cell.dspf').write_text(explicit);s.p.save(target/'BULK_REFERENCE_AUDIT.json',body);s.p.save(target/'DEVICE_GEOMETRY_BINDING.json',binding)
 s.archive(work,target/'native')
 connectivity_path=target/'TERMINAL_CONNECTIVITY_AUDIT.json';terminal.audit(cell,gate,target/'cell.raw.dspf',binding,connectivity_path)
 row=dict(terminal_connectivity_pass=True,terminal_connectivity_audit=str(connectivity_path),terminal_connectivity_audit_sha256=s.p.sha(connectivity_path),cell=cell,gds=str(ROOT/'cells'/cell/f'iter{iteration:03d}'/'inputs/cell.gds'),gds_sha256=gate['gds_sha256'],cdl=str(ROOT/'cells'/cell/f'iter{iteration:03d}'/'inputs/topology.cdl'),cdl_sha256=gate['topology_reference_sha256'],reference_provenance=str(ROOT/'REFERENCE_ADMISSION.json'),reference_admitted=gate['reference_admitted'],drc_pass=gate['drc_pass'],drc_violations=gate['drc_violations'],drc_report=gate['drc']['report'],drc_report_sha256=gate['drc']['report_sha256'],lvs_pass=True,topology_LVS_pass=True,lvs_report=str(target/report.name),lvs_report_sha256=s.p.sha(target/report.name),native_property_checks_enabled=False,device_geometry_preserved=gate['device_geometry_preserved'],device_layer_change_authorized=gate.get('device_layer_change_authorized',False),device_layer_change_audit=gate.get('device_layer_change_audit'),device_layer_change_audit_sha256=s.p.sha(gate['device_layer_change_audit']) if gate.get('device_layer_change_audit') else None,actual_MOS_dimensions_preserved=gate['actual_MOS_dimensions_preserved'],body_rail_audit_pass=True,body_rail_provenance=str(target/'BULK_REFERENCE_AUDIT.json'),device_geometry_binding=str(target/'DEVICE_GEOMETRY_BINDING.json'),device_geometry_binding_sha256=s.p.sha(target/'DEVICE_GEOMETRY_BINDING.json'),actual_device_dimensions=binding['rows'],parallel_merge_detected=False,dspf=str(target/'cell.dspf'),dspf_sha256=s.p.sha(target/'cell.dspf'),raw_dspf=str(target/'cell.raw.dspf'),raw_dspf_sha256=s.p.sha(target/'cell.raw.dspf'),host=socket.gethostname(),work=str(work),iteration=iteration,grid_sha256=s.p.sha(grid),fresh_native_StarRC=True,gate=str(ROOT/'cells'/cell/f'iter{iteration:03d}'/'GATE.json'),gate_sha256=s.p.sha(ROOT/'cells'/cell/f'iter{iteration:03d}'/'GATE.json'),PEX_wall_s=time.time()-started,PEX_empty_layer_adapter=str(ROOT/'FSPR_EMPTY_LAYER_AUDIT.json'))
 s.p.save(target/'PEX_RECEIPT.json',row);common.publish(row);return row

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--cell');args=parser.parse_args()
 names=[args.cell] if args.cell else [p.parent.name for p in (ROOT/'cells').glob('*/LATEST.json') if json.loads(p.read_text())['qualified']]
 names=sorted(names,key=lambda n:(n!='INVx1',not n.startswith('INV'),n))
 owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().split()[21],epoch=time.time(),work=str(WORK));s.p.save(ROOT/'FSPR_PEX_LAUNCH.json',owner)
 try:
  deck=stage_adapter();rows=[];failed=[]
  with ThreadPoolExecutor(max_workers=8 if not args.cell else 1) as pool:
   tasks={pool.submit(extract,n,deck):n for n in names}
   for future in as_completed(tasks):
    try:rows.append(future.result())
    except Exception:
     cell=tasks[future];error=dict(cell=cell,traceback=traceback.format_exc(),epoch=time.time());failed.append(error);s.p.save(ROOT/'cells'/cell/'FSPR_PEX_FAILED.json',error)
     gate=json.loads((ROOT/'cells'/cell/'LATEST.json').read_text());it=gate['iteration'];attempts=sorted((WORK/cell/f'iter{it:03d}').glob('pex_lvs_FSPR_attempt*'))
     if attempts:
      target=ROOT/'cells'/cell/f'iter{it:03d}'/'pex_FSPR_failures'/attempts[-1].name;s.archive(attempts[-1],target);s.p.save(target/'FAILED.json',error)
    s.p.save(ROOT/'FSPR_PEX_STATUS.json',dict(stage='native_FSPR_PEX',completed=len(rows),failed=failed,total=len(names),epoch=time.time(),owner=owner))
  s.p.save(ROOT/'FSPR_PEX_STATUS.json',dict(stage='complete' if not failed else 'complete_with_failed_cells_preserved',completed=len(rows),failed=failed,total=len(names),epoch=time.time(),owner=owner))
 except Exception:s.p.save(ROOT/'FSPR_PEX_STATUS.json',dict(stage='failed_preserve',traceback=traceback.format_exc(),epoch=time.time(),owner=owner));raise
if __name__=='__main__':main()
