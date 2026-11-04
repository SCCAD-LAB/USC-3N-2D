from pathlib import Path
import sys,json,gzip,re
HERE=Path(__file__).resolve().parent;P=HERE.parent
sys.path.insert(0,str(P));import scan as s,terminal_connectivity as t
old=HERE/'frozen_original/native_lvs.net.gz';new=HERE/'iter001/native/lvs/DFFHx1.net.gz'
def terminals(p):
 text=gzip.decompress(p.read_bytes()).decode();ports=re.search(r'\{PORT\s+([^}]+)\}',text,re.I)[1].split();out={'PORT:'+q:q for q in ports};types={}
 for m in re.finditer(r'\{INST\s+(\S+)=(nmos_rvt|pmos_rvt).*?\{PIN\s+([^}]+)\}',text,re.I|re.S):
  types[m[1]]=m[2]
  for net,pin in re.findall(r'([^\s=]+)=([^\s}]+)',m[3]):out['MOS:'+m[1]+':'+pin]=net
 return out,types
before,bt=terminals(old);after,at=terminals(new);assert bt==at and len(bt)==32
changed=['MOS:M12:GATE','MOS:M29:GATE'];assert before[changed[0]]==before[changed[1]]
for key in changed:assert after[key]==after['PORT:CK']
b=dict(before);a=dict(after)
for key in changed:del b[key];del a[key]
assert t.partitions(a)==t.partitions(b),'Other30gates/D/S/portpartitionschanged'
old_dims=json.loads((HERE/'frozen_original/ACTUAL_DEVICE_DIMENSIONS.json').read_text())['rows'];new_dims=json.loads((HERE/'iter001/ACTUAL_DEVICE_DIMENSIONS.json').read_text())['rows'];assert s.dimension_identity(old_dims)==s.dimension_identity(new_dims)
c0=s.p.gdstk.read_gds(str(HERE/'frozen_original/cell.gds')).cells[0];c1=s.p.gdstk.read_gds(str(HERE/'iter001/inputs/cell.gds')).cells[0];layers={p.layer for c in [c0,c1] for p in c.polygons}
assert s.geometry_hash(c0,layers-{19,20,21})==s.geometry_hash(c1,layers-{19,20,21});assert s.channel_shapes(c0)==s.channel_shapes(c1)
s.p.save(HERE/'PAIRED_TWO_GATE_TOPOLOGY_AUDIT.json',dict(passed=True,physical_MOS_count=32,changed_gate_terminals=changed,all32_D_S_unchanged=True,all30_other_gate_connections_unchanged=True,all_external_port_partitions_unchanged=True,all32_original03ae_L_W_coordinates_preserved=True,raw_device_layers_preserved_from_03ae=True,only_M1_M2_V1_changed=True,shared_gate_continuous_not_split=True,old_native=str(old),old_native_sha256=s.p.sha(old),new_native=str(new),new_native_sha256=s.p.sha(new),old_shared_clock_gate_group=sorted(k for k,v in before.items() if v==before[changed[0]]),new_clock_gate_group=sorted(k for k,v in after.items() if v==after['PORT:CK']),native_property_checks_enabled=False,native_body_property_checks_enabled=False,inherited_original144nm_M7_translation='Originalqualified03aepointalreadyincludesapprovedM7(546,36)to(588,36),L12W19; thiscandidatepreservesall32tuplesof03ae.',qualification='Physicaltopologyauditonly; actualRCbehavior/fullcharstillpending'))
