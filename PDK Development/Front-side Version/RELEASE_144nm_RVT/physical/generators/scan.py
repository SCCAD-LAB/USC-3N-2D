#!/usr/bin/env python3
"""Sharded native144nm QA with immutable topology references and device geometry."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse,fcntl,gzip,hashlib,json,os,re,shutil,socket,subprocess,sys,tarfile,threading,time,traceback
import preflight as p
ROOT=p.ROOT;RELEASE=ROOT.parent
WORK=Path('/tmp/yhuang861/usc144_github_release_20261103/full57')
DEVICE_LAYERS={1,2,3,7,8,10,11,12,13}
LOCK=threading.Lock()
def geometry_hash(cell,layers):
 data=sorted((q.layer,q.datatype,tuple(tuple(round(float(v),9) for v in pair) for pair in q.points)) for q in cell.polygons if q.layer in layers)
 return hashlib.sha256(repr(data).encode()).hexdigest()
def dimension_rows(path):
 if not path.exists():return []
 t=gzip.decompress(path.read_bytes()).decode();rows=[]
 for m in re.finditer(r'\{INST\s+(\S+)=(nmos_rvt|pmos_rvt)\s+\{TYPE MOS\}\s*\{COORD\s+x=([^\s}]+)\s+y=([^\s}]+)\}\s*\{PROP\s+([^}]+)\}',t,re.I):
  props=dict(re.findall(r'(\w+)=([^\s}]+)',m[5]));rows.append(dict(device=m[1],type=m[2],x_nm=float(m[3])*1000,y_nm=float(m[4])*1000,L_nm=float(props.get('l',props.get('L')))*1000,W_nm=float(props.get('w',props.get('W')))*1000))
 return rows
def dimension_identity(rows):return sorted((r['type'],r['x_nm'],r['y_nm'],r['L_nm'],r['W_nm']) for r in rows)
def mapped_dimension_identity(rows,translations):
 mapped=[]
 for r in rows:
  q=dict(r)
  for t in translations:
   if all(abs(q[k]-t['from'][k])<1e-6 for k in ['x_nm','y_nm']) and q['type']==t['type']:
    if any(abs(q[k]-t[k])>1e-6 for k in ['L_nm','W_nm']):raise RuntimeError('Authorized relocation dimensions differ')
    q.update(t['to'])
  mapped.append(q)
 return dimension_identity(mapped)
def channel_shapes(cell):
 return sorted((kind,tuple(sorted(points))) for kind,points in channel_geometry(cell))
def mapped_channel_shapes(cell,translations):
 rows=[]
 for kind,points in channel_shapes(cell):
  xs=[q[0] for q in points];ys=[q[1] for q in points];cx=(min(xs)+max(xs))*500;cy=(min(ys)+max(ys))*500
  for t in translations:
   if kind==t['type'] and abs(cx-t['from']['x_nm'])<1e-6 and abs(cy-t['from']['y_nm'])<1e-6:
    dx=(t['to']['x_nm']-cx)/1000;dy=(t['to']['y_nm']-cy)/1000;points=tuple(sorted((round(x+dx,9),round(y+dy,9)) for x,y in points))
  rows.append((kind,points))
 return sorted(rows)
def channel_geometry(cell):
 polys=lambda layer:[p for p in cell.polygons if p.layer==layer and p.datatype==0]
 gate=safe_boolean(polys(7),polys(10),'not');active=safe_boolean(polys(11),polys(2),'and');all_channels=safe_boolean(gate,active,'and');rows=[]
 for kind,layer in [('nmos_rvt',12),('pmos_rvt',13)]:
  for p in safe_boolean(all_channels,polys(layer),'and'):
   rows.append((kind,tuple(tuple(round(float(v),9) for v in pair) for pair in p.points)))
 return sorted(rows)
def safe_boolean(a,b,operation):return p.gdstk.boolean(a,b,operation,precision=.000001)
def archive(work,target):
 target.mkdir(parents=True,exist_ok=True);manifest={str(f.relative_to(work)):p.sha(f) for f in work.rglob('*') if f.is_file()}
 bundle=work.parent/(work.name+'.native.tar.gz')
 with tarfile.open(bundle,'w:gz') as t:t.add(work,arcname=work.name)
 shutil.copyfile(bundle,target/'native.tar.gz')
 if p.sha(bundle)!=p.sha(target/'native.tar.gz'):raise RuntimeError('Native archive checksum mismatch')
 p.save(target/'NATIVE_ARCHIVE.json',dict(sha256=p.sha(bundle),files=manifest))
 for f in work.iterdir():
  if f.is_file() and (f.suffix in ['.RESULTS','.LAYOUT_ERRORS','.LVS_ERRORS','.log','.json','.cmd'] or f.name in ['console.log']):shutil.copyfile(f,target/f.name)
def native(cell,iteration,kind):
 work=WORK/cell/f'iter{iteration:03d}'/kind;work.mkdir(parents=True,exist_ok=True);inputs=work.parent/'inputs'
 if kind=='drc':
  source=ROOT/'rules/matched_144nm/DRC';p.copy_tree(source,work/'runset');p.copy_tree(source/'Include',work/'Include');deck=work/'runset/sccad3nm_main.drc.rs'
 else:deck=ROOT/'rules/matched_144nm/LVS/ICV_3nm.rs'
 cmd=[p.ICV,'-i',str(inputs/'cell.gds'),'-c',cell,'-f','GDSII','-host_init',socket.gethostname()+':2']
 if kind=='lvs':cmd+=['-s',str(inputs/'topology.cdl'),'-sf','SPICE','-stc',cell]
 cmd+=[str(deck)];receipt=work/'NATIVE_EXIT.json';identity=dict(gds_sha256=p.sha(inputs/'cell.gds'),topology_sha256=p.sha(inputs/'topology.cdl'),deck_sha256=p.sha(deck),command=cmd)
 if receipt.exists():
  rec=json.loads(receipt.read_text())
  if rec['identity']!=identity:raise RuntimeError('Preserve existing native attempt; identity mismatch')
 else:
  started=time.time()
  with (work/'console.log').open('w') as f:rc=subprocess.run(cmd,cwd=work,env=p.ENV,stdout=f,stderr=subprocess.STDOUT,timeout=1200).returncode
  rec=dict(identity=identity,rc=rc,wall_s=time.time()-started,epoch=time.time());p.save(receipt,rec)
 if kind=='drc':
  f=work/(cell+'.RESULTS');text=f.read_text() if f.exists() else '';m=re.search(r'There (?:are|is) (\d+) total violation',text)
  rec.update(violations=int(m[1]) if m else None,rules_run=re.findall(r'(\d+) total rules were run',text),rules_not_executed=re.findall(r'(\d+) rule(?:s)? NOT EXECUTED',text));rec['passed']=rec['rc']==0 and rec['violations']==0
 else:
  f=work/(cell+'.LVS_ERRORS');rec['passed']=rec['rc']==0 and f.exists() and 'Final comparison result:PASS' in f.read_text();rec['native_property_checks_enabled']=False
 target=ROOT/'cells'/cell/f'iter{iteration:03d}'/kind;archive(work,target)
 rec['report']=str(target/(cell+('.RESULTS' if kind=='drc' else '.LVS_ERRORS')));rec['report_sha256']=p.sha(Path(rec['report'])) if Path(rec['report']).exists() else None
 if kind=='lvs':
  rows=dimension_rows(work/(cell+'.net.gz'));p.save(target/'ACTUAL_DEVICE_DIMENSIONS.json',dict(rows=rows));rec['actual_dimension_rows']=rows
 return rec
def one(cell,iteration=0):
 drc=native(cell,iteration,'drc');lvs=native(cell,iteration,'lvs');inputs=WORK/cell/f'iter{iteration:03d}'/'inputs'
 p.copy_tree(inputs,ROOT/'cells'/cell/f'iter{iteration:03d}'/'inputs')
 baseline=json.loads((ROOT/'INITIAL_GEOMETRY.json').read_text())['cells'][cell]
 gl=p.gdstk.read_gds(str(inputs/'cell.gds')).cells[0];device_unchanged=geometry_hash(gl,DEVICE_LAYERS)==baseline['device_geometry_sha256']
 rows=lvs['actual_dimension_rows'];initial=ROOT/'cells'/cell/'INITIAL_DEVICE_DIMENSIONS.json'
 if iteration==0:p.save(initial,dict(rows=rows,source='Frozen144nmDUT initial native extraction; dimensional-preservation basis, not independent connectivitygold'))
 old=json.loads(initial.read_text())['rows'] if initial.exists() else [];dimensions_preserved=bool(rows) and dimension_identity(rows)==dimension_identity(old)
 coordinates_preserved=dimensions_preserved
 exception_audit=None;exception_pass=False
 policy_path=ROOT/'DEVICE_LAYER_CHANGE_POLICY.json'
 if not device_unchanged and policy_path.exists():
  policy=json.loads(policy_path.read_text()).get(cell)
  if policy:
   source=p.gdstk.read_gds(str(ROOT/'cells'/cell/'iter000/inputs/cell.gds')).cells[0];unchanged=geometry_hash(source,DEVICE_LAYERS-set(policy['allowed_modified_device_layers']))==geometry_hash(gl,DEVICE_LAYERS-set(policy['allowed_modified_device_layers']))
   channels_same=channel_geometry(source)==channel_geometry(gl)
   if policy.get('channel_geometry')=='unchanged':exception_pass=unchanged and channels_same and dimensions_preserved
   elif policy.get('channel_geometry')=='explicit_translation':
    translations=policy['device_translations'];mapped_dims=mapped_dimension_identity(old,translations)==dimension_identity(rows);mapped_channels=mapped_channel_shapes(source,translations)==channel_shapes(gl)
    dimensions_preserved=mapped_dims;exception_pass=unchanged and mapped_dims and mapped_channels
   else:exception_pass=False
   exception_audit=dict(passed=exception_pass,policy=policy,nonexception_device_layers_preserved=unchanged,actual_channel_geometry_preserved=channels_same,actual_L_W_count_coordinate_identity_preserved=coordinates_preserved,actual_L_W_count_preserved=dimensions_preserved,raw_device_layers_unchanged=False,actual_coordinates_preserved=coordinates_preserved,explicit_translation_verified=bool(policy.get('channel_geometry')=='explicit_translation' and exception_pass))
   p.save(ROOT/'cells'/cell/f'iter{iteration:03d}'/'DEVICE_LAYER_CHANGE_AUDIT.json',exception_audit)
 reference=next(r for r in json.loads((ROOT/'REFERENCE_ADMISSION.json').read_text())['rows'] if r['cell']==cell)
 admitted=reference['topology_reference_admitted']
 z=dict(cell=cell,iteration=iteration,gds_sha256=p.sha(inputs/'cell.gds'),topology_reference_sha256=p.sha(inputs/'topology.cdl'),reference_admitted=admitted,drc_pass=drc['passed'],drc_violations=drc.get('violations'),drc=drc,topology_LVS_pass=lvs['passed'],lvs=lvs,native_property_checks_enabled=False,device_geometry_preserved=device_unchanged,device_layer_change_authorized=exception_pass,device_layer_change_audit=str(ROOT/'cells'/cell/f'iter{iteration:03d}'/'DEVICE_LAYER_CHANGE_AUDIT.json') if exception_audit else None,actual_MOS_dimensions_preserved=dimensions_preserved,actual_MOS_coordinates_preserved=coordinates_preserved,qualified=admitted and drc['passed'] and lvs['passed'] and (device_unchanged or exception_pass) and dimensions_preserved,host=socket.gethostname(),work=str(inputs.parent))
 p.save(ROOT/'cells'/cell/f'iter{iteration:03d}'/'GATE.json',z);p.save(ROOT/'cells'/cell/'LATEST.json',z);return z
def stage(names):
 lib=p.gdstk.read_gds(str(RELEASE/'sources/input_144nm.gds'));sources={c.name:c for c in lib.cells};rows={}
 refs={r['cell']:r for r in json.loads((ROOT/'REFERENCE_ADMISSION.json').read_text())['rows']}
 for name in names:
  w=WORK/name/'iter000/inputs';w.mkdir(parents=True,exist_ok=True)
  if not (w/'cell.gds').exists():
   gl=p.gdstk.Library(unit=lib.unit,precision=lib.precision);gl.add(sources[name].copy(name));gl.write_gds(str(w/'cell.gds'))
  reference=Path(refs[name]['gold_cdl']) if refs[name]['topology_reference_admitted'] else RELEASE/'reports/independent_old_circuit_candidates'/(name+'.cdl')
  if not (w/'topology.cdl').exists():shutil.copyfile(reference,w/'topology.cdl')
  elif p.sha(reference)!=p.sha(w/'topology.cdl'):raise RuntimeError('Topology reference identity changed '+name)
  rows[name]=dict(device_geometry_sha256=geometry_hash(sources[name],DEVICE_LAYERS),source_gds_sha256=p.sha(RELEASE/'sources/input_144nm.gds'),initial_cell_gds_sha256=p.sha(w/'cell.gds'))
 p.save(ROOT/'INITIAL_GEOMETRY.json',dict(device_layers=sorted(DEVICE_LAYERS),cells=rows))

def normalize_topology(text):
 lines=[];bulk=[]
 for line in text.splitlines():
  tokens=line.split()
  if tokens and tokens[0].lower().startswith('m'):
   index=next(i for i,t in enumerate(tokens) if t.lower() in ['nmos_rvt','pmos_rvt'])
   if index==5:
    expected='VSS' if tokens[index].lower().startswith('n') else 'VDD'
    if tokens[4]!=expected:raise RuntimeError('Independent MOS bulk is notexpectedrail: '+line)
    bulk.append(dict(device=tokens[0],bulk=tokens[4],type=tokens[index]));del tokens[4];line=' '.join(tokens)
   elif index!=4:raise RuntimeError('Unexpected referenceMOS format: '+line)
  lines.append(line)
 return '\n'.join(lines)+'\n',bulk

def stage_iteration(cell,iteration,previous=0,modified_gds=None):
 old=WORK/cell/f'iter{previous:03d}'/'inputs';new=WORK/cell/f'iter{iteration:03d}'/'inputs';new.mkdir(parents=True,exist_ok=True)
 if (new/'cell.gds').exists():raise RuntimeError('Preserve existingiteration '+str(new))
 shutil.copyfile(modified_gds if modified_gds else old/'cell.gds',new/'cell.gds')
 ref=ROOT/'references'/cell/'gold.cdl';text,bulk=normalize_topology(ref.read_text());(new/'topology.cdl').write_text(text)
 p.save(new/'REFERENCE_FORMAT_ADAPTER.json',dict(source=str(ref),source_sha256=p.sha(ref),topology_sha256=p.sha(new/'topology.cdl'),D_G_S_and_dimensions_changed=False,grounded_bulk_omitted_for_source_three_terminal_LVS=bulk,source_LVS_bulk_property_coverage=False,reason='Nativeproductiondeckdefines3-terminalNMOS/PMOS. Independentlydeclaredbodyrailsretainevidence; noD/G/Srewiringorpropertychanges.'))
 return new
def status(stage,**kw):p.save(ROOT/'STATUS.json',dict(stage=stage,epoch=time.time(),**kw))
def main():
 WORK.mkdir(parents=True,exist_ok=True)
 with (ROOT/'SCAN_OWNER.lock').open('a') as lock:
  fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB);owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().split()[21],work=str(WORK),epoch=time.time());p.save(ROOT/'SCAN_LAUNCH.json',owner)
  try:
   names=[r['cell'] for r in json.loads((ROOT/'REFERENCE_ADMISSION.json').read_text())['rows']];stage(names);results=[]
   for batch,workers in [(names[:8],4),(names[8:],8)]:
    load=os.getloadavg()[0];mem=next(int(l.split()[1]) for l in Path('/proc/meminfo').read_text().splitlines() if l.startswith('MemAvailable:'))
    if load+2*workers>os.cpu_count() or mem<32*1024**2:workers=2
    status('full57_native_DRC_LVS',workers=workers,completed=len(results),load=load,owner=owner)
    with ThreadPoolExecutor(max_workers=workers) as pool:
     for future in as_completed({pool.submit(one,n):n for n in batch}):
      z=future.result();results.append(z);p.save(ROOT/'SCAN.json',dict(complete=len(results)==57,rows=sorted(results,key=lambda r:r['cell'])));status('full57_native_DRC_LVS',workers=workers,completed=len(results),qualified=sum(r['qualified'] for r in results),owner=owner)
   status('initial_scan_complete_actual_repairs_required',completed=57,qualified=sum(r['qualified'] for r in results),failed=[r['cell'] for r in results if not r['qualified']])
  except Exception:status('scan_failed_preserve',traceback=traceback.format_exc());raise
if __name__=='__main__':main()
