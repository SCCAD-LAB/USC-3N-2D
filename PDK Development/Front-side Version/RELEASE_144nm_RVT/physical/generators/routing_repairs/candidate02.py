"""Second isolated XOR3 candidate: trim one unsupported M1 stub corner."""
import json,os,shutil,socket,time,traceback
from pathlib import Path
import candidate01 as c
def main():
    root=c.HERE;name='XOR3x1';work=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/routing_repairs/candidate02')/name
    owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],work=str(work),started_epoch=time.time())
    c.save(root/'XOR3_CANDIDATE02_LAUNCH.json',dict(owner=owner,stage='native_candidate_DRC_LVS'))
    try:
        if work.exists():raise RuntimeError('Preserve candidate02 attempt')
        source=root/'candidate01'/name/'inputs/cell.gds';lib=c.gdstk.read_gds(str(source));cell=lib.cells[0];frozen=c.geometry(cell,{19});bounds=cell.bounding_box()
        cut=c.gdstk.rectangle((.309,.078),(.321,.0795));m1=[p for p in cell.polygons if p.layer==19 and p.datatype==0]
        protected=[]
        for p in cell.polygons:
            if p.layer in [18,21]:
                b=p.bounding_box();protected.append(c.gdstk.rectangle((b[0][0],b[0][1]-.004),(b[1][0],b[1][1]+.004)))
        if c.gdstk.boolean([cut],protected,'and',precision=.000001):raise RuntimeError('Stub trim intersects via/enclosure support')
        new=c.gdstk.boolean(m1,[cut],'not',precision=.000001,layer=19)
        if len(new)!=len(m1):raise RuntimeError('Connected component count changed')
        cell.remove(*m1);cell.add(*new)
        assert c.geometry(cell,{19})==frozen and cell.bounding_box()==bounds
        for label in cell.labels:
            if label.layer==19:assert any(c.gdstk.inside([label.origin],[p])[0] for p in new)
        (work/'inputs').mkdir(parents=True);lib.write_gds(str(work/'inputs/cell.gds'));shutil.copyfile(root/'candidate01'/name/'inputs/topology.cdl',work/'inputs/topology.cdl')
        audit=dict(source_gds=str(source),source_sha256=c.sha(source),candidate_sha256=c.sha(work/'inputs/cell.gds'),cut_bbox=cut.bounding_box(),all_nonM1_layers_preserved=True,pins_and_bounds_preserved=True,via_enclosure_support_cut=False)
        c.save(work/'GEOMETRY_CHANGES.json',audit);c.save(root/'XOR3_CANDIDATE02_STATUS.json',dict(stage='native_candidate_DRC_LVS',owner=owner))
        drc=c.native(name,work,'drc');lvs=c.native(name,work,'lvs');archive=root/'candidate02'/name;c.copy_tree(work,archive)
        result=dict(cell=name,passed=drc['passed'] and lvs['passed'],candidate_gds=str(archive/'inputs/cell.gds'),candidate_sha256=c.sha(archive/'inputs/cell.gds'),drc=drc,lvs=lvs,audit=audit,final_admission_owner='c1_drc_clean_pilot')
        c.save(archive/'RESULT.json',result);c.save(root/'XOR3_CANDIDATE02_STATUS.json',dict(stage='complete',owner=owner,passed=result['passed'],drc_violations=drc['violations'],LVS_pass=lvs['passed']))
    except Exception:
        c.save(root/'XOR3_CANDIDATE02_STATUS.json',dict(stage='candidate_failed_preserve',owner=owner,traceback=traceback.format_exc()));raise
if __name__=='__main__':main()
