"""Two measured LIG-corner refinements of the topology-correct DFF candidate."""
from pathlib import Path
import os,shutil,socket,time,traceback
import candidate01 as c
from candidate04 import rect,exact
def main():
    name='DFFHx1';work=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/routing_repairs/candidate09')/name
    owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],work=str(work),started_epoch=time.time());c.save(c.HERE/'BATCH09_LAUNCH.json',dict(owner=owner,stage='native_candidate_DRC_LVS'))
    try:
        if work.exists():raise RuntimeError('Preserve candidate09 attempt')
        source=c.HERE/'candidate08'/name/'inputs/cell.gds';lib=c.gdstk.read_gds(str(source));cell=lib.cells[0];frozen=c.geometry(cell,{16,18,19});bounds=cell.bounding_box()
        old=exact(cell,16,[522,67,572,77]);cell.remove(old);cell.add(rect(524,67,572,77,16))
        old=exact(cell,16,[813,66,846,78]);cell.remove(old);cell.add(rect(818,66,846,78,16))
        via=exact(cell,18,[813,66,825,78]);moved=via.copy();moved.translate(.005,0);cell.remove(via);cell.add(moved)
        if c.gdstk.boolean([moved],[p for p in cell.polygons if p.layer in [16,17]],'not',precision=.000001):raise RuntimeError('Moved V0 unsupported')
        old=[p for p in cell.polygons if p.layer==19 and p.datatype==0];count=len(c.gdstk.boolean(old,[],'or',precision=.000001));new=c.gdstk.boolean(old,[rect(818,62,830,82)],'or',precision=.000001,layer=19)
        if len(new)!=count:raise RuntimeError('M1 component count changed')
        cell.remove(*old);cell.add(*new)
        if c.geometry(cell,{16,18,19})!=frozen or cell.bounding_box()!=bounds:raise RuntimeError('Frozen geometry/bounds changed')
        for label in cell.labels:
            if label.layer==19 and not any(c.gdstk.inside([label.origin],[p])[0] for p in new):raise RuntimeError('Lost pin coverage')
        (work/'inputs').mkdir(parents=True);lib.write_gds(str(work/'inputs/cell.gds'));shutil.copyfile(c.HERE/'candidate08'/name/'inputs/topology.cdl',work/'inputs/topology.cdl')
        audit=dict(source_gds=str(source),source_sha256=c.sha(source),candidate_sha256=c.sha(work/'inputs/cell.gds'),changes=[dict(kind='trim_MS_jumper_left_edge_522_to524nm',retained_MS_LISD_overlap_nm=11),dict(kind='trim_clock_LIG_left_edge_813_to818nm_and_move_supported_V0_right5nm',full_Gate840_overlap_preserved=True,new_M1_pad_nm=[818,62,830,82])],all_other_layers_preserved=True,approved_32_channel_polygons_and_pin_labels_bounds_preserved=True,no_higher_metal_added=True)
        c.save(work/'GEOMETRY_CHANGES.json',audit);c.save(c.HERE/'BATCH09_STATUS.json',dict(stage='native_candidate_DRC_LVS',owner=owner));drc=c.native(name,work,'drc');lvs=c.native(name,work,'lvs');archive=c.HERE/'candidate09'/name;c.copy_tree(work,archive)
        result=dict(cell=name,passed=drc['passed'] and lvs['passed'],candidate_gds=str(archive/'inputs/cell.gds'),candidate_sha256=c.sha(archive/'inputs/cell.gds'),drc=drc,lvs=lvs,audit=audit,final_admission_owner='c1_drc_clean_pilot');c.save(archive/'RESULT.json',result);c.save(c.HERE/'BATCH09_STATUS.json',dict(stage='complete',owner=owner,passed=result['passed'],DRC=drc['violations'],LVS=lvs['passed']))
    except Exception:c.save(c.HERE/'BATCH09_STATUS.json',dict(stage='candidate_failed_preserve',owner=owner,traceback=traceback.format_exc()));raise
if __name__=='__main__':main()
