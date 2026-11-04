"""DFF M1 dogleg and latch V1/M2 enclosure refinement; isolated native QA."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import os,shutil,socket,time,traceback
import candidate01 as c
from candidate04 import rect,exact
WORK=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/routing_repairs/candidate05')
def modify(name,destination):
    source=c.PHYSICAL/'cells'/name/'iter001/inputs/cell.gds' if name=='DFFHQNx1' else c.HERE/'candidate04'/name/'inputs/cell.gds'
    lib=c.gdstk.read_gds(str(source));cell=lib.cells[0];exclude={19} if name=='DFFHQNx1' else {20,21};frozen=c.geometry(cell,exclude);bounds=cell.bounding_box();changes=[]
    if name=='DFFHQNx1':
        old=[p for p in cell.polygons if p.layer==19 and p.datatype==0];count=len(c.gdstk.boolean(old,[],'or',precision=.000001))
        cut=rect(279,50.5,351,66);m1=c.gdstk.boolean(old,[cut],'not',precision=.000001,layer=19)
        m1=c.gdstk.boolean(m1,[rect(279,46.75,351,58.75),rect(351,46.75,363,47.5)],'or',precision=.000001,layer=19)
        if len(m1)!=count:raise RuntimeError('M1 net count changed')
        cell.remove(*old);cell.add(*m1);changes.append(dict(kind='reroute_uncontacted_horizontal_M1_body',old_body_nm=[279,50.5,351,66],new_body_nm=[279,46.75,351,58.75],right_pad_bottom_extended_nm=.75,all_vias_LIG_LISD_preserved=True))
    else:
        for oldbounds,dy in [([309,51.5,321,63.5],-3),([330,80.5,342,92.5],3)]:
            old=exact(cell,21,oldbounds);new=old.copy();new.translate(0,dy/1000);cell.remove(old);cell.add(new);changes.append(dict(kind='V1_shift_on_same_M2_net',before_nm=oldbounds,dy_nm=dy))
        for oldbounds,newbounds in [([15,51.5,321,63.5],[15,48.5,321,63.5]),([330,80.5,447,92.5],[330,80.5,447,95.5])]:
            old=exact(cell,20,oldbounds);cell.remove(old);cell.add(rect(*newbounds,layer=20));changes.append(dict(kind='rectangular_M2_support_extension',before_nm=oldbounds,after_nm=newbounds))
        metal=[p for p in cell.polygons if p.layer==20 and p.datatype==0]
        for p in cell.polygons:
            if p.layer==21 and c.gdstk.boolean([p],metal,'not',precision=.000001):raise RuntimeError('V1 leaves M2 support')
    if c.geometry(cell,exclude)!=frozen or cell.bounding_box()!=bounds:raise RuntimeError('Frozen layers/bounds changed')
    metal=[p for p in cell.polygons if p.layer==19 and p.datatype==0]
    for label in cell.labels:
        if label.layer==19 and not any(c.gdstk.inside([label.origin],[p])[0] for p in metal):raise RuntimeError('Pin label lost')
    destination.parent.mkdir(parents=True,exist_ok=True);lib.write_gds(str(destination))
    return dict(source_gds=str(source),source_sha256=c.sha(source),candidate_sha256=c.sha(destination),changes=changes,only_changed_layers=sorted(exclude),all_other_layers_and_device_formation_preserved=True,pin_labels_and_bounds_preserved=True)
def one(name):
    work=WORK/name
    if work.exists():raise RuntimeError('Preserve candidate05 attempt')
    audit=modify(name,work/'inputs/cell.gds')
    reference=c.PHYSICAL/'cells'/name/'iter001/inputs/topology.cdl' if name=='DFFHQNx1' else c.HERE/'candidate04'/name/'inputs/topology.cdl'
    shutil.copyfile(reference,work/'inputs/topology.cdl');c.save(work/'GEOMETRY_CHANGES.json',audit);drc=c.native(name,work,'drc');lvs=c.native(name,work,'lvs');archive=c.HERE/'candidate05'/name;c.copy_tree(work,archive)
    result=dict(cell=name,passed=drc['passed'] and lvs['passed'],candidate_gds=str(archive/'inputs/cell.gds'),candidate_sha256=c.sha(archive/'inputs/cell.gds'),drc=drc,lvs=lvs,audit=audit,final_admission_owner='c1_drc_clean_pilot');c.save(archive/'RESULT.json',result);return result
def main():
    owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],work=str(WORK),started_epoch=time.time());c.save(c.HERE/'BATCH05_LAUNCH.json',dict(owner=owner,stage='native_candidate_DRC_LVS'));rows=[]
    try:
        c.save(c.HERE/'BATCH05_STATUS.json',dict(stage='native_candidate_DRC_LVS',owner=owner))
        with ThreadPoolExecutor(max_workers=2) as pool:
            for f in as_completed([pool.submit(one,n) for n in ['DFFHQNx1','DHLx1']]):rows.append(f.result());c.save(c.HERE/'BATCH05_RESULTS.json',dict(rows=rows))
        c.save(c.HERE/'BATCH05_STATUS.json',dict(stage='complete',owner=owner,completed=2,passed=sum(x['passed'] for x in rows)))
    except Exception:c.save(c.HERE/'BATCH05_STATUS.json',dict(stage='candidate_failed_preserve',owner=owner,traceback=traceback.format_exc()));raise
if __name__=='__main__':main()
