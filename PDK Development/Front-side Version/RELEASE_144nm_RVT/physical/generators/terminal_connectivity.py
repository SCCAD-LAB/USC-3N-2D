#!/usr/bin/env python3
"""Compare raw PEX R-collapsed terminal partitions with same-GDS native ICV."""
from pathlib import Path
import collections,gzip,hashlib,json,re,tarfile,time

ROOT=Path(__file__).resolve().parent
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p,d):
 q=Path(str(p)+'.tmp');q.write_text(json.dumps(d,indent=2)+'\n');q.replace(p)
class Union:
 def __init__(self):self.parent={}
 def find(self,x):
  self.parent.setdefault(x,x)
  if self.parent[x]!=x:self.parent[x]=self.find(self.parent[x])
  return self.parent[x]
 def join(self,a,b):
  a=self.find(a);b=self.find(b)
  if a!=b:self.parent[a]=b

def native_net(gate):
 folder=Path(gate['lvs']['report']).parent;direct=folder/(gate['cell']+'.net.gz')
 if direct.exists():data=direct.read_bytes();source=dict(path=str(direct),sha256=sha(direct))
 else:
  archive=folder/'native.tar.gz'
  with tarfile.open(archive) as t:
   members=[m for m in t.getmembers() if m.name.endswith('/'+gate['cell']+'.net.gz')]
   if len(members)!=1:raise RuntimeError('Missing/ambiguous native QA netlist')
   data=t.extractfile(members[0]).read();source=dict(path=str(archive),sha256=sha(archive),member=members[0].name,member_sha256=hashlib.sha256(data).hexdigest())
 return gzip.decompress(data).decode(),source

def partitions(terminals,root=lambda x:x):
 groups=collections.defaultdict(list)
 for terminal,node in terminals.items():groups[root(node)].append(terminal)
 return sorted(tuple(sorted(group)) for group in groups.values())

def audit(cell,gate,raw_path,binding,path=None):
 if sha(ROOT/'cells'/cell/f"iter{gate['iteration']:03d}/inputs/cell.gds")!=gate['gds_sha256']:raise RuntimeError('Same-GDS audit refused changed layout')
 text,source=native_net(gate)
 if path and Path(path).exists():
  previous=json.loads(Path(path).read_text())
  if previous.get('passed') and previous['gds_sha256']==gate['gds_sha256'] and previous['raw_DSPF_sha256']==sha(raw_path) and previous['native_QA_netlist']==source:return previous
 m=re.search(r'\{PORT\s+([^}]+)\}',text,re.I)
 if not m:raise RuntimeError('No native port list')
 ports=m[1].split();native={('PORT:'+p):p for p in ports};devices=set()
 for m in re.finditer(r'\{INST\s+(\S+)=(nmos_rvt|pmos_rvt).*?\{PIN\s+([^}]+)\}',text,re.I|re.S):
  device=m[1];devices.add(device);pins={pin:net for net,pin in re.findall(r'([^\s=]+)=([^\s}]+)',m[3])}
  if set(pins)!={'GATE','DRN','SRC'}:raise RuntimeError('Unexpected native MOS terminal set '+str(pins))
  for pin,net in pins.items():native['MOS:'+device+':'+pin]=net
 physical={r['PEX_instance']:r['ICV_instance'] for r in binding['rows']};u=Union();pex={};resistors=0;seen=set();pexports=None
 statements=[]
 for line in Path(raw_path).read_text().splitlines():
  if line.startswith('+'):
   if not statements:raise RuntimeError('Orphan SPICE continuation')
   statements[-1]+=' '+line[1:]
  else:statements.append(line)
 for line in statements:
  tokens=line.split()
  if not tokens or tokens[0].startswith('*'):continue
  name=tokens[0]
  if name.lower()=='.subckt':
   if pexports is not None:raise RuntimeError('Multiple DSPF subcircuits')
   pexports=tokens[2:]
   for p in pexports:pex['PORT:'+p]=p
  elif name[0].lower()=='r':
   if len(tokens)<4:raise RuntimeError('Malformed DSPF resistor')
   u.join(tokens[1],tokens[2]);resistors+=1
  elif name[0].lower()=='m':
   if name not in physical:raise RuntimeError('DSPF device missing physical bijection '+name)
   device=physical[name]
   if device in seen:raise RuntimeError('Duplicate DSPF MOS identity')
   seen.add(device)
   if len(tokens)<5 or tokens[4].lower() not in ['nmos_rvt','pmos_rvt']:raise RuntimeError('Expected raw three-terminal MOS')
   for pin,node in zip(['DRN','GATE','SRC'],tokens[1:4]):pex['MOS:'+device+':'+pin]=node
 if set(ports)!=set(pexports or []):raise RuntimeError('DSPF/native external ports differ')
 if devices!=seen:raise RuntimeError('DSPF/native physical MOS sets differ')
 n=partitions(native);e=partitions(pex,u.find);native_only=[list(q) for q in n if q not in e];pex_only=[list(q) for q in e if q not in n];passed=n==e
 result=dict(passed=passed,cell=cell,epoch=time.time(),gds_sha256=gate['gds_sha256'],native_QA_netlist=source,raw_DSPF=str(raw_path),raw_DSPF_sha256=sha(raw_path),physical_MOS_count=len(devices),external_port_count=len(ports),resistors_collapsed=resistors,capacitors_ignored=True,body_rails_excluded='Raw three-terminal DSPF; explicit independent body-rail provenance is audited separately.',native_partition_count=len(n),PEX_partition_count=len(e),native_partitions=n,PEX_partitions=e,native_only=native_only,PEX_only=pex_only,renaming_policy='Compare exact canonical sets of external port IDs and physical MOS GATE/SRC/DRN terminal IDs; arbitrary internal net names are irrelevant. No D/S swapping is assumed.')
 if path:write(Path(path),result)
 if not passed:raise RuntimeError('Raw PEX terminal connectivity differs from same-GDS ICV: '+cell+'; see '+str(path))
 return result

def audit_manifest():
 manifest=ROOT/'PEX_MANIFEST.json';data=json.loads(manifest.read_text());rows=[];failures=[]
 for row in data['rows']:
  try:
   gate=json.loads(Path(row['gate']).read_text());binding=json.loads(Path(row['device_geometry_binding']).read_text());path=Path(row['dspf']).parent/'TERMINAL_CONNECTIVITY_AUDIT.json';r=audit(row['cell'],gate,Path(row['raw_dspf']),binding,path)
   row.update(terminal_connectivity_pass=True,terminal_connectivity_audit=str(path),terminal_connectivity_audit_sha256=sha(path));rows.append(dict(cell=row['cell'],passed=True,audit=str(path),sha256=sha(path)))
  except Exception as e:failures.append(dict(cell=row['cell'],error=str(e)))
 if not failures:write(manifest,data)
 write(ROOT/'TERMINAL_CONNECTIVITY_INDEX.json',dict(complete=len(rows)==57 and not failures,passed=len(rows),failures=failures,rows=rows))
 print(json.dumps(dict(passed=len(rows),failures=failures),indent=2))
if __name__=='__main__':audit_manifest()
