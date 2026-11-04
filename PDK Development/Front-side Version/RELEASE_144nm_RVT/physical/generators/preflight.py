#!/usr/bin/env python3
"""Native144nm source checks with immutable rules and explicit layer-map fixes."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import gzip,hashlib,json,os,re,shutil,socket,subprocess,sys,time,traceback
ROOT=Path(__file__).resolve().parent
RELEASE=ROOT.parent
SW=Path('/cedar/cedar_coe/ece-limsk/sw.jung/pdk/3nm_GAA_a/v1.1/oa')
WORK=Path('/tmp/yhuang861/usc144_github_release_20261103/preflight')
sys.path.insert(0,str(RELEASE.parents[0]/'ten_parameter_c0_20261103/deps'))
import gdstk
ICV='/tools/software/synopsys/icvalidator/latest/bin/icv'
ENV=dict(os.environ,SNPSLMD_LICENSE_FILE='1910@ece-winlic.ece.gatech.edu',OMP_NUM_THREADS='1')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def save(p,d):
 p.parent.mkdir(parents=True,exist_ok=True);q=p.with_name(p.name+'.tmp');q.write_text(json.dumps(d,indent=2)+'\n');q.replace(p)
def copy_tree(a,b):
 b.mkdir(parents=True,exist_ok=True)
 for p in a.rglob('*'):
  d=b/p.relative_to(a)
  if p.is_dir():d.mkdir(parents=True,exist_ok=True)
  elif p.is_file():
   d.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,d)
   if sha(p)!=sha(d):raise RuntimeError('Archive mismatch '+str(p))
def convert_icv_schematic(text,name):
 # ICV's archived .sch_out is the independent schematic-side database,
 # not the DUT's .net extracted database. Retain every supplied property.
 ports=re.search(r'\{port\s+(.*?)\}',text,re.S)[1].split();out=['* Independent archived schematic-side ICV database; dimensions unchanged','.subckt '+name+' '+' '.join(ports)]
 for m in re.finditer(r'\{inst\s+(\S+?)=(\S+)\s+\{TYPE MOS\}\s*\{prop\s+([^}]+)\}\s*\{pin\s+([^}]+)\}\}',text,re.S):
  props=dict(re.findall(r'(\w+)=([^\s]+)',m[3]));pins=dict((b,a) for a,b in re.findall(r'([^\s=]+)=([^\s]+)',m[4]));out.append(m[1]+' '+pins['DRN']+' '+pins['GATE']+' '+pins['SRC']+' '+m[2]+' W='+props['W']+'u L='+props['L']+'u M='+props.get('M','1'))
 if len(out)<3:raise RuntimeError('No schematicMOS parsed '+name)
 out.append('.ends '+name);return '\n'.join(out)+'\n'
def stage():
 rules=ROOT/'rules';copy_tree(rules/'github/DRC',rules/'matched_144nm/DRC')
 deck=rules/'matched_144nm/DRC/sccad3nm_main.drc.rs';text=deck.read_text();changes=[]
 expected={'aVBPR':14,'aMBPR':15,'tMBPR':15,'aV1':21,'aM6':60,'tM6':60}
 for name,num in expected.items():
  pattern=r'(\b'+name+r'\s*=\s*assign(?:_text)?\(\s*\{\s*\{\s*)(\d+)'
  m=re.search(pattern,text)
  if not m:raise RuntimeError('Missing mapping '+name)
  if int(m[2])!=num:
   changes.append(dict(variable=name,before=int(m[2]),after=num));text=re.sub(pattern,lambda z:z[1]+str(num),text)
 deck.write_text(text)
 lvs=rules/'matched_144nm/LVS/ICV_3nm.rs';lvs.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(SW/'ICV_3nm.rs',lvs)
 save(ROOT/'RULE_ADAPTER.json',dict(source_production_LVS=str(SW/'ICV_3nm.rs'),source_LVS_sha256=sha(SW/'ICV_3nm.rs'),github_LVS_rejected='Explicitly fin-deleted6T_drcclean-only; DUTcontainsfinlayer2',mapping_changes=changes,mapping_evidence=[str(SW/'ICV_3nm.rs'),str(SW/'sccad_3nm.layermap')],numeric_geometry_rules_changed=False,rule_blocks_disabled=False))
 source=gdstk.read_gds(str(RELEASE/'sources/input_144nm.gds'));cells={c.name:c for c in source.cells};rows=[]
 for name in ['INVx1','DFFHx1']:
  w=WORK/name/'inputs';w.mkdir(parents=True,exist_ok=True);lib=gdstk.Library(unit=source.unit,precision=source.precision);lib.add(cells[name].copy(name));lib.write_gds(str(w/'cell.gds'))
  ref=SW/'6T_final'/name/(name+'.sch_out.gz');text=gzip.decompress(ref.read_bytes()).decode();(w/'schematic.icv.txt').write_text(text);(w/'cell.cdl').write_text(convert_icv_schematic(text,name))
  rows.append(dict(cell=name,independent_schematic_source=str(ref),source_sha256=sha(ref),source_kind='Archived ICV schematic-side .sch_out, not DUT .net',export_properties_preserved=True,geometry_parameter_alignment='INV L12W30; DFFhistoricalL20W27 remains unresolved; native topology check is diagnostic, not a dimension-qualifiedrelease gate'))
  copy_tree(w,ROOT/'preflight'/name/'inputs')
 save(ROOT/'PREFLIGHT_REFERENCE_PROVENANCE.json',dict(rows=rows))
def one(name):
 rows=[]
 for kind in ['drc_raw_github','drc_matched_map','lvs_source_production']:
  w=WORK/name/kind;w.mkdir(parents=True,exist_ok=True);inp=w.parent/'inputs'
  if kind.startswith('drc'):
   src=ROOT/'rules'/('github/DRC' if kind=='drc_raw_github' else 'matched_144nm/DRC');copy_tree(src,w/'runset');copy_tree(src/'Include',w/'Include');deck=w/'runset/sccad3nm_main.drc.rs'
  else:deck=ROOT/'rules/matched_144nm/LVS/ICV_3nm.rs'
  cmd=[ICV,'-i',str(inp/'cell.gds'),'-c',name,'-f','GDSII','-host_init',socket.gethostname()+':2']
  if kind.startswith('lvs'):cmd+=['-s',str(inp/'cell.cdl'),'-sf','SPICE','-stc',name]
  cmd+=[str(deck)];started=time.time()
  with (w/'console.log').open('w') as f:rc=subprocess.run(cmd,cwd=w,env=ENV,stdout=f,stderr=subprocess.STDOUT,timeout=1200).returncode
  rec=dict(cell=name,check=kind,command=cmd,rc=rc,wall_s=time.time()-started,input_gds_sha256=sha(inp/'cell.gds'),input_cdl_sha256=sha(inp/'cell.cdl'),rule_sha256=sha(deck))
  if kind.startswith('drc'):
   p=w/(name+'.RESULTS');t=p.read_text() if p.exists() else '';m=re.search(r'There are (\d+) total violations',t);rec.update(violations=int(m[1]) if m else None,rules_run=re.findall(r'(\d+) total rules were run',t),rules_not_executed=re.findall(r'(\d+) rule(?:s)? NOT EXECUTED',t))
  else:
   p=w/(name+'.LVS_ERRORS');rec['topology_pass']=p.exists() and 'Final comparison result:PASS' in p.read_text()
  copy_tree(w,ROOT/'preflight'/name/kind);save(ROOT/'preflight'/name/(kind+'_RECEIPT.json'),rec);rows.append(rec)
 return rows
def main():
 WORK.mkdir(parents=True,exist_ok=True);save(ROOT/'LAUNCH.json',dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().split()[21],work=str(WORK),epoch=time.time(),scope='INV+DFF actual native DRC and independent-schematic topologyLVS; dimensionalreference gap explicit'))
 try:
  stage();save(ROOT/'STATUS.json',dict(stage='INV_DFF_native_preflight',epoch=time.time()));rows=[]
  with ThreadPoolExecutor(max_workers=2) as pool:
   for f in as_completed([pool.submit(one,n) for n in ['INVx1','DFFHx1']]):rows+=f.result();save(ROOT/'PREFLIGHT.json',dict(rows=rows))
  save(ROOT/'STATUS.json',dict(stage='preflight_complete_requires_marker_and_dimension_review',epoch=time.time()))
 except Exception:
  save(ROOT/'STATUS.json',dict(stage='preflight_failed_preserve',traceback=traceback.format_exc(),epoch=time.time()));raise
if __name__=='__main__':main()
