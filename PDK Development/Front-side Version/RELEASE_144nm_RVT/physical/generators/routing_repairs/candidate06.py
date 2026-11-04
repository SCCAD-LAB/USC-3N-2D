"""Latch refinement: move complete M2/V1 rows, preserving exact edge alignment."""
from pathlib import Path
import os,shutil,socket,time,traceback
import candidate01 as c
from candidate04 import rect,exact
def main():
    name='DHLx1';work=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/routing_repairs/candidate06')/name
    owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],work=str(work),started_epoch=time.time());c.save(c.HERE/'BATCH06_LAUNCH.json',dict(owner=owner,stage='native_candidate_DRC_LVS'))
    try:
        if work.exists():raise RuntimeError('Preserve candidate06 attempt')
        source=c.HERE/'candidate04'/name/'inputs/cell.gds';lib=c.gdstk.read_gds(str(source));cell=lib.cells[0];frozen=c.geometry(cell,{19,20,21});bounds=cell.bounding_box();changes=[]
        for xs,y,dy in [([15,71,183,309],51.5,-3),([330,435],80.5,3)]:
            for x in xs:
                old=exact(cell,21,[x,y,x+12,y+12]);new=old.copy();new.translate(0,dy/1000);cell.remove(old);cell.add(new);changes.append(dict(kind='move_V1_with_entire_M2_row',old_bbox=old.bounding_box(),dy_nm=dy))
        for oldbounds,dy in [([15,51.5,321,63.5],-3),([330,80.5,447,92.5],3)]:
            old=exact(cell,20,oldbounds);new=old.copy();new.translate(0,dy/1000);cell.remove(old);cell.add(new);changes.append(dict(kind='move_12nm_rectangular_M2_row',before_nm=oldbounds,dy_nm=dy))
        old=[p for p in cell.polygons if p.layer==19 and p.datatype==0];count=len(c.gdstk.boolean(old,[],'or',precision=.000001))
        extensions=[rect(71,44.5,83,47.5),rect(183,44.5,195,47.5),rect(435,96.5,447,99.5)]
        new=c.gdstk.boolean(old,extensions,'or',precision=.000001,layer=19)
        if len(new)!=count:raise RuntimeError('M1 net count changed')
        cell.remove(*old);cell.add(*new)
        supports=[p for p in cell.polygons if p.layer==20]
        for p in cell.polygons:
            if p.layer==21 and c.gdstk.boolean([p],supports,'not',precision=.000001):raise RuntimeError('V1 outside M2 support')
        if c.geometry(cell,{19,20,21})!=frozen or cell.bounding_box()!=bounds:raise RuntimeError('Frozen geometry/bounds changed')
        for label in cell.labels:
            if label.layer==19 and not any(c.gdstk.inside([label.origin],[p])[0] for p in new):raise RuntimeError('Lost pin support')
        (work/'inputs').mkdir(parents=True);lib.write_gds(str(work/'inputs/cell.gds'));shutil.copyfile(c.HERE/'candidate04'/name/'inputs/topology.cdl',work/'inputs/topology.cdl')
        audit=dict(source_gds=str(source),source_sha256=c.sha(source),candidate_sha256=c.sha(work/'inputs/cell.gds'),changes=changes,M1_stub_extension_bboxes=[p.bounding_box() for p in extensions],all_other_layers_preserved=True,device_formation_layers_and_LIG_V0_unchanged_from_candidate04=True,pin_labels_and_bounds_preserved=True)
        c.save(work/'GEOMETRY_CHANGES.json',audit);c.save(c.HERE/'BATCH06_STATUS.json',dict(stage='native_candidate_DRC_LVS',owner=owner));drc=c.native(name,work,'drc');lvs=c.native(name,work,'lvs');archive=c.HERE/'candidate06'/name;c.copy_tree(work,archive)
        result=dict(cell=name,passed=drc['passed'] and lvs['passed'],candidate_gds=str(archive/'inputs/cell.gds'),candidate_sha256=c.sha(archive/'inputs/cell.gds'),drc=drc,lvs=lvs,audit=audit,final_admission_owner='c1_drc_clean_pilot');c.save(archive/'RESULT.json',result);c.save(c.HERE/'BATCH06_STATUS.json',dict(stage='complete',owner=owner,passed=result['passed'],DRC=drc['violations'],LVS=lvs['passed']))
    except Exception:c.save(c.HERE/'BATCH06_STATUS.json',dict(stage='candidate_failed_preserve',owner=owner,traceback=traceback.format_exc()));raise
if __name__=='__main__':main()
