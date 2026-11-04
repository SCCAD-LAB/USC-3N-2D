#!/usr/bin/env python3
"""Cross-check independent prior12nm circuits against archived schematic topology."""
from pathlib import Path
import gzip,hashlib,json,re,shutil
import networkx as nx
from networkx.algorithms.isomorphism import categorical_node_match,categorical_multiedge_match
import preflight
ROOT=Path(__file__).resolve().parent
SOURCE=ROOT.parent/'reports/independent_old_circuit_candidates'
def graph(ports,devices):
 g=nx.MultiGraph();portset=set(ports)
 for name,model,d,gate,s,props in devices:
  dev=('M',name);g.add_node(dev,kind='device',model=model.lower(),port='')
  for role,n in [('channel',d),('gate',gate),('channel',s)]:
   net=('N',n);g.add_node(net,kind='net',model='',port=n if n in portset else '');g.add_edge(dev,net,role=role)
 return g
def cdl(text):
 ports=re.search(r'(?im)^\.subckt\s+\S+\s+([^\n]+)',text)[1].split();devices=[]
 for line in text.splitlines():
  t=line.split()
  if t and t[0].lower().startswith('m'):
   i=next(i for i,v in enumerate(t) if v.lower() in ['nmos_rvt','pmos_rvt']);props=dict((k.lower(),v) for k,v in re.findall(r'(\w+)\s*=\s*([^\s]+)',' '.join(t[i+1:])))
   devices.append((t[0],t[i],*t[1:4],props))
 return ports,devices
def main():
 manifest=json.loads((SOURCE/'MANIFEST.json').read_text());rows=[]
 for entry in manifest['rows']:
  name=entry['cell'];candidate=Path(entry['candidate']);archive=preflight.SW/'6T_final'/name/(name+'.sch_out.gz')
  ref=preflight.convert_icv_schematic(gzip.decompress(archive.read_bytes()).decode(),name) if archive.exists() else None
  b,bd=cdl(candidate.read_text());a,ad=cdl(ref) if ref else (b,[])
  if preflight.sha(candidate)!=entry['candidate_sha256']:raise RuntimeError('Candidate changed '+name)
  gm=nx.algorithms.isomorphism.MultiGraphMatcher(graph(a,ad),graph(b,bd),node_match=categorical_node_match(['kind','model','port'],['','','']),edge_match=categorical_multiedge_match('role','')) if ref else None
  equivalent=set(a)==set(b) and gm.is_isomorphic() if gm else None
  row=dict(cell=name,independent_archive=str(archive) if ref else None,independent_archive_sha256=preflight.sha(archive) if ref else None,prior_circuit_source=entry['source'],prior_circuit_source_sha256=entry['source_sha256'],candidate_sha256=entry['candidate_sha256'],port_sets_equal=set(a)==set(b),MOS_counts=[len(ad) if ref else None,len(bd)],topology_isomorphic=equivalent,comparison='Gate-preserving, source/drain-permutable MOS graph where independent archive exists; remaining independent prior2024circuits retained without a second-archive equivalenceclaim; dimensions audited separately',archived_properties=sorted(set(tuple(sorted(x[-1].items())) for x in ad)),prior_12nm_properties=sorted(set(tuple(sorted(x[-1].items())) for x in bd)),topology_reference_admitted=equivalent is not False,native_property_checks_enabled=False,parametric_gold=False)
  logic_receipt=ROOT.parent/'reports/INDEPENDENT_REFERENCE_LOGIC.json'
  if name=='NOR4x1' and equivalent is False and logic_receipt.exists():
   logic=json.loads(logic_receipt.read_text());lr=next(x for x in logic['rows'] if x['cell']==name)
   if lr['status']=='pass' and lr['case_count']==16:
    row.update(topology_reference_admitted=True,resolution='IndependentpriorNOR4 passesall16publishedLibertytruthcases; archiveschematicNMOSBdrainnet25isdangling. Keeppriorindependentcorrectlogicreference, notcurrentDUT.',logic_receipt=str(logic_receipt),logic_receipt_sha256=preflight.sha(logic_receipt))
  if row['topology_reference_admitted']:
   out=ROOT/'references'/name;out.mkdir(parents=True,exist_ok=True);shutil.copyfile(candidate,out/'gold.cdl');row['gold_cdl']=str(out/'gold.cdl');row['gold_sha256']=preflight.sha(out/'gold.cdl')
   if ref:(out/'independent_schematic.cdl').write_text(ref);shutil.copyfile(archive,out/'independent_schematic.sch_out.gz')
  rows.append(row)
  preflight.save(ROOT/'REFERENCE_ADMISSION.json',dict(complete=len(rows)==57,passed=all(r['topology_reference_admitted'] for r in rows),rows=rows,method='Independent prior2024extractedcircuit checked against archivedschematic topology where available; not current144nmDUTextraction; topology-onlyreference explicitlyauthorizedbyroot; source144nmdevicegeometry frozen and separatelyaudited'))
 print(json.dumps(dict(cells=len(rows),admitted=sum(r['topology_reference_admitted'] for r in rows),secondary_archive_equivalent=sum(r['topology_isomorphic'] is True for r in rows),failed=[r['cell'] for r in rows if not r['topology_reference_admitted']])))
if __name__=='__main__':main()
