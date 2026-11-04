from pathlib import Path
import sys,json,difflib,shutil
HERE=Path(__file__).resolve().parent;PHYSICAL=HERE.parent
sys.path.insert(0,str(PHYSICAL));import scan as s
gdstk=s.p.gdstk
def rect(a,b,l):return gdstk.rectangle(tuple(v/1000 for v in a),tuple(v/1000 for v in b),layer=l)
def generate():
 source=HERE/'frozen_original/cell.gds';lib=gdstk.read_gds(str(source));c=lib.cells[0];before=c.copy('DFFHx1');changes=[]
 def find(l,box):
  out=[p for p in c.polygons if p.layer==l and all(abs(v-q/1000)<1e-8 for v,q in zip([*p.bounding_box()[0],*p.bounding_box()[1]],box))];assert len(out)==1,(l,box,len(out));return out[0]
 def replace(l,box,new):
  c.remove(find(l,box));c.add(rect(new[:2],new[2:],l));changes.append(dict(layer=l,before=box,after=new))
 # The original continuous shared gate and existing LIG/V0 stay exact.
 # Remove just its C2 M2 via, then connect its M1 stub to externalCK above both buses.
 c.remove(find(21,[225,80.5,237,92.5]));changes.append(dict(layer=21,removed=[225,80.5,237,92.5],purpose='DisconnectonlysharedmastergatefromC2'))
 replace(19,[225,66,237,96.5],[225,66,237,126])
 replace(19,[43,22.75,55,121.25],[43,22.75,55,126])
 c.add(rect((37,110),(243,122),20),rect((43,110),(55,122),21),rect((225,110),(237,122),21))
 for l in [19,20,21]:
  old=[p for p in c.polygons if p.layer==l];c.remove(*old);c.add(*gdstk.boolean(old,[],'or',precision=lib.precision/lib.unit,layer=l))
 assert s.channel_shapes(before)==s.channel_shapes(c)
 layers={p.layer for a in [before,c] for p in a.polygons};assert s.geometry_hash(before,layers-{19,20,21})==s.geometry_hash(c,layers-{19,20,21})
 assert sorted((q.layer,q.texttype,q.text,q.origin,q.rotation,q.magnification) for q in before.labels)==sorted((q.layer,q.texttype,q.text,q.origin,q.rotation,q.magnification) for q in c.labels)
 target=HERE/'iter001/inputs';target.mkdir(parents=True,exist_ok=True);lib.write_gds(str(target/'cell.gds'))
 ref=HERE/'frozen_original/independent_prior_4t.cdl';original=ref.read_text();out=[];changed=[]
 for line in original.splitlines():
  t=line.split()
  if t and t[0] in ['MMM24','MMM16']:assert t[2]=='MM13:DRN';t[2]='CK';line=' '.join(t);changed.append(t[0])
  out.append(line)
 assert set(changed)=={'MMM24','MMM16'};derived='\n'.join(out)+'\n';(target/'derived_topology_4t.cdl').write_text(derived);three,bulk=s.normalize_topology(derived);(target/'topology.cdl').write_text(three)
 (HERE/'INDEPENDENT_TWO_GATE_DIFF.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True),derived.splitlines(True),fromfile='frozen_independent_prior_2024',tofile='root_authorized_paired_clock_candidate')))
 s.p.save(HERE/'GEOMETRY_GENERATION.json',dict(source=str(source),source_sha256=s.p.sha(source),candidate=str(target/'cell.gds'),candidate_sha256=s.p.sha(target/'cell.gds'),allowed_changed_layers=[19,20,21],all32_channel_rectangles_L_W_positions_preserved=True,all_other_routing_device_layers_preserved=True,labels_and_boundary_preserved=True,changes=changes,shared_gate_not_split=True,derived_reference_sha256=s.p.sha(target/'topology.cdl'),derived_4T_reference_sha256=s.p.sha(target/'derived_topology_4t.cdl'),no_canonical_writes=True))
if __name__=='__main__':generate()
