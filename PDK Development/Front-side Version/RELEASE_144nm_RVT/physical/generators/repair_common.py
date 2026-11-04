#!/usr/bin/env python3
"""Repair measured via enclosures, rerun native QA, publish qualified fresh PEX."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import csv,fcntl,hashlib,json,math,os,re,shutil,socket,subprocess,threading,time,traceback
import numpy as np
import scan as s
ROOT=s.ROOT;WORK=s.WORK
MANIFEST_LOCK=threading.Lock()

def marker_rows(text,rule):
 text=text.split('ERROR DETAILS',1)[-1]
 sections=re.split(r'\n-{20,}\n',text);rows=[]
 for i in range(len(sections)-1):
  if sections[i].strip().startswith(rule+' :'):
   for m in re.finditer(r'(?m)^\S+\s+\(\s*([-\d.]+),\s*([-\d.]+)\)\s+\(\s*([-\d.]+),\s*([-\d.]+)\)\s+([-\d.]+)',sections[i+1]):rows.append([float(v) for v in m.groups()])
 return rows

def repair(cell,previous=0,iteration=1):
 inputs=WORK/cell/f'iter{previous:03d}'/'inputs';lib=s.p.gdstk.read_gds(str(inputs/'cell.gds'));c=lib.cells[0]
 report=ROOT/'cells'/cell/f'iter{previous:03d}'/'drc'/(cell+'.LAYOUT_ERRORS');text=report.read_text();changes=[];patches=[]
 for rule,layer in [('V0.M1.1',18),('V1.M1.EN',21)]:
  for marker in marker_rows(text,rule):
   x0,y0,x1,y1,distance=marker;matches=[]
   for index,p in enumerate(c.polygons):
    if p.layer!=layer or p.datatype:continue
    b=np.array(p.bounding_box())
    if abs(b[0,0]-x0)<.00016 and abs(b[1,0]-x1)<.00016 and any(y0-.00016<=v<=y1+.00016 for v in [b[0,1],b[1,1]]):matches.append((index,b))
   if len(matches)!=1:raise RuntimeError('Measured marker association ambiguous '+str((cell,rule,marker,matches)))
   index,b=matches[0];patch=s.p.gdstk.rectangle((b[0,0],b[0,1]-.004),(b[1,0],b[1,1]+.004),layer=19)
   patches.append(patch);changes.append(dict(rule=rule,marker_um=marker,via_polygon_index=index,M1_enclosure_patch_um=np.array(patch.bounding_box()).tolist()))
 if patches:
  original=[p for p in c.polygons if p.layer==19 and p.datatype==0]
  merged=s.p.gdstk.boolean(original+patches,[],'or',precision=lib.precision/lib.unit,layer=19)
  c.remove(*original);c.add(*merged)
 target=WORK/cell/f'prepared_iter{iteration:03d}.gds'
 if patches:lib.write_gds(str(target))
 else:shutil.copyfile(inputs/'cell.gds',target)
 dest=s.stage_iteration(cell,iteration,previous,target);s.p.save(dest/'GEOMETRY_CHANGES.json',dict(changes=changes,device_layers_changed=False,rule_values_changed=False,method='Add4nmverticalM1enclosureonlyatactualnativeV0/V1violationmarkers; unionwithsameM1layer. FreshnativeDRC/LVSrequired.'))
 return s.one(cell,iteration)

def explicit_bodies(raw,cell):
 reference=(ROOT/'references'/cell/'gold.cdl').read_text();_,bulk=s.normalize_topology(reference)
 bytype={}
 for row in bulk:
  bytype.setdefault(row['type'].lower(),set()).add(row['bulk'])
 if bytype!={'nmos_rvt':{'VSS'},'pmos_rvt':{'VDD'}}:raise RuntimeError('Independent body-rail provenance incomplete '+cell)
 lines=[];MOS=[]
 for line in raw.splitlines():
  tokens=line.split()
  if tokens and tokens[0].lower().startswith('m'):
   index=next((i for i,t in enumerate(tokens) if t.lower() in bytype),None)
   if index==4:
    model=tokens[index].lower();rail=next(iter(bytype[model]));tokens.insert(4,rail);line=' '.join(tokens);MOS.append(dict(device=tokens[0],model=model,bulk=rail))
   elif index==5:
    model=tokens[index].lower()
    if tokens[4] not in bytype[model]:raise RuntimeError('FreshPEXbulk differsindependentrail '+line)
    MOS.append(dict(device=tokens[0],model=model,bulk=tokens[4]))
   else:raise RuntimeError('Unexpected rawPEX MOS signature '+line)
  lines.append(line)
 if not MOS:raise RuntimeError('No native extracted MOS '+cell)
 return '\n'.join(lines)+'\n',dict(passed=True,independent_reference=str(ROOT/'references'/cell/'gold.cdl'),independent_reference_sha256=s.p.sha(ROOT/'references'/cell/'gold.cdl'),source_bulk_records=bulk,emitted_bulk_records=MOS,only_bulk_terminal_added=True,actual_L_W_and_RC_unchanged=True)

def publish(row):
 with MANIFEST_LOCK:
  path=ROOT/'PEX_MANIFEST.json';old=json.loads(path.read_text()) if path.exists() else dict(schema='usc144_native_pex_v1',complete=False,rows=[])
  rows={r['cell']:r for r in old['rows']};rows[row['cell']]=row;old.update(complete=len(rows)==57,rows=sorted(rows.values(),key=lambda r:r['cell']),epoch=time.time(),scope='Native topologyLVSplusindependentcircuitreference, sameGDSDRC0, frozen144nmdeviceL/W/countpreservation; nativepropertychecksdisabledbyprovideddeck,explicitbodyprovenance')
  s.p.save(path,old)

def extract(cell,iteration):
 gatepath=ROOT/'cells'/cell/f'iter{iteration:03d}'/'GATE.json';gate=json.loads(gatepath.read_text())
 if not gate['qualified']:raise RuntimeError('FreshPEX refused unqualified cell '+cell)
 work=WORK/cell/f'iter{iteration:03d}'/'lvs';inputs=work.parent/'inputs';out=work/'cell.raw.dspf'
 if s.p.sha(inputs/'cell.gds')!=gate['gds_sha256']:raise RuntimeError('GDSchangedafterQA')
 grid=ROOT.parent/'sources/github_FSPR.nxtgrd'
 command=['BLOCK: '+cell,'TCAD_GRD_FILE: '+str(grid),'ICV_RUNSET_REPORT_FILE: '+str(work/'pex_runset_report'),'MAPPING_FILE: '+str(work/'starrcxt.mapping'),'STAR_DIRECTORY: '+str(work/'star'),'EXTRACTION: RC','NETLIST_FORMAT: SPF','NETLIST_FILE: '+str(out),'NETLIST_SUBCKT: YES','NETLIST_GROUND_NODE_NAME: VSS','POWER_NETS: *','POWER_EXTRACT: YES','CASE_SENSITIVE: YES','COUPLE_TO_GROUND: NO','REDUCTION: NO','NUM_CORES: 2']
 (work/'starrc.cmd').write_text('\n'.join(command)+'\n');started=time.time()
 with (work/'starrc.log').open('w') as f:rc=subprocess.run(['/tools/software/synopsys/starrc/latest/bin/StarXtract',str(work/'starrc.cmd')],cwd=work,env=s.p.ENV,stdout=f,stderr=subprocess.STDOUT,timeout=1200).returncode
 if rc or not out.exists():raise RuntimeError('NativeStarRCfailed '+cell)
 explicit,body=explicit_bodies(out.read_text(),cell)
 if len(body['emitted_bulk_records'])!=len(gate['lvs']['actual_dimension_rows']):raise RuntimeError('NativePEX/MOScountmismatch '+cell)
 target=ROOT/'cells'/cell/f'iter{iteration:03d}'/'pex';target.mkdir(parents=True,exist_ok=True)
 for f in [out,work/'starrc.cmd',work/'starrc.log']:shutil.copyfile(f,target/f.name)
 (target/'cell.dspf').write_text(explicit);s.p.save(target/'BULK_REFERENCE_AUDIT.json',body)
 row=dict(cell=cell,gds=str(ROOT/'cells'/cell/f'iter{iteration:03d}'/'inputs/cell.gds'),gds_sha256=gate['gds_sha256'],cdl=str(ROOT/'cells'/cell/f'iter{iteration:03d}'/'inputs/topology.cdl'),cdl_sha256=gate['topology_reference_sha256'],reference_provenance=str(ROOT/'REFERENCE_ADMISSION.json'),reference_admitted=gate['reference_admitted'],drc_pass=gate['drc_pass'],drc_violations=gate['drc_violations'],drc_report=gate['drc']['report'],drc_report_sha256=gate['drc']['report_sha256'],lvs_pass=gate['topology_LVS_pass'],topology_LVS_pass=gate['topology_LVS_pass'],lvs_report=gate['lvs']['report'],lvs_report_sha256=gate['lvs']['report_sha256'],native_property_checks_enabled=False,device_geometry_preserved=gate['device_geometry_preserved'],actual_MOS_dimensions_preserved=gate['actual_MOS_dimensions_preserved'],body_rail_audit_pass=body['passed'],body_rail_provenance=str(target/'BULK_REFERENCE_AUDIT.json'),dspf=str(target/'cell.dspf'),dspf_sha256=s.p.sha(target/'cell.dspf'),raw_dspf=str(target/'cell.raw.dspf'),raw_dspf_sha256=s.p.sha(target/'cell.raw.dspf'),host=socket.gethostname(),work=str(work),iteration=iteration,grid_sha256=s.p.sha(grid),fresh_native_StarRC=True,gate=str(gatepath),gate_sha256=s.p.sha(gatepath),PEX_wall_s=time.time()-started)
 s.p.save(target/'PEX_RECEIPT.json',row);publish(row);return row

def main():
 with (ROOT/'REPAIR_OWNER.lock').open('a') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().split()[21],work=str(WORK),epoch=time.time());s.p.save(ROOT/'REPAIR_LAUNCH.json',owner)
  try:
   names=[r['cell'] for r in json.loads((ROOT/'REFERENCE_ADMISSION.json').read_text())['rows']];rows=[];pexfutures=[]
   with ThreadPoolExecutor(max_workers=4) as pex_pool:
    with ThreadPoolExecutor(max_workers=8) as qa_pool:
     for f in as_completed({qa_pool.submit(repair,n):n for n in names}):
      z=f.result();rows.append(z);s.p.save(ROOT/'COMMON_REPAIR_SCAN.json',dict(complete=len(rows)==57,rows=sorted(rows,key=lambda r:r['cell'])))
      s.status('native_common_repairs_and_fresh_PEX',completed=len(rows),qualified=sum(r['qualified'] for r in rows),qa_workers=8,PEX_workers=4,owner=owner)
      if z['qualified']:pexfutures.append(pex_pool.submit(extract,z['cell'],z['iteration']))
    for f in as_completed(pexfutures):f.result()
   s.status('common_repair_complete_remaining_actual_markers',completed=57,qualified=sum(r['qualified'] for r in rows),remaining=[r['cell'] for r in rows if not r['qualified']],PEX_complete=len(pexfutures))
  except Exception:s.status('common_repair_failed_preserve',traceback=traceback.format_exc());raise
if __name__=='__main__':main()
