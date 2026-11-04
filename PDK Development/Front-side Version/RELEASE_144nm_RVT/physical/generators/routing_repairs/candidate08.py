"""DFFH isolated post-relocation contact reroute; unchanged approved channels."""
from pathlib import Path
import os,shutil,socket,time,traceback
import candidate01 as c
from candidate04 import rect,exact
def main():
    name='DFFHx1';work=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/routing_repairs/candidate08')/name
    owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],work=str(work),started_epoch=time.time());c.save(c.HERE/'BATCH08_LAUNCH.json',dict(owner=owner,stage='native_candidate_DRC_LVS'))
    try:
        if work.exists():raise RuntimeError('Preserve candidate08 attempt')
        source=c.PHYSICAL/'cells'/name/'iter002/inputs/cell.gds'
        assert c.sha(source)=='9afd231017238c364facd8cd0ca7db8579ee0570f8b09d011bb04a124fb2058f'
        lib=c.gdstk.read_gds(str(source));cell=lib.cells[0];formation=c.geometry(cell,{16,17,18,19,20,21,25,30,88});bounds=cell.bounding_box();changes=[]
        broad=exact(cell,17,[557,42,619,102]);cell.remove(broad)
        cell.add(rect(557,42,577,78,17),rect(599,42,619,102,17),rect(557,92,577,102,17))
        cell.add(rect(522,67,572,77,16),rect(553,90,610,100,16))
        changes.append(dict(kind='separate_new_N588_MS_and_SH_contacts_and_restore_P567_SH',LISD_before_nm=[557,42,619,102],LISD_after_nm=[[557,42,577,78],[599,42,619,102],[557,92,577,102]],MS_LIG_jumper_nm=[522,67,572,77],SH_LIG_jumper_nm=[553,90,610,100]))
        # Retire the old unused lower-gate contact; reconnect its clock to Gate588N.
        for layer,b in [(16,[540,22.75,558,34.75]),(18,[546,22.75,558,34.75])]:cell.remove(exact(cell,layer,b))
        cell.add(rect(582,22.75,594,34.75,16),rect(582,22.75,594,34.75,18))
        metal=[p for p in cell.polygons if p.layer==19 and p.datatype==0];clock=[p for p in metal if c.gdstk.inside([(.552,.02875)],[p])[0]]
        if len(clock)!=1:raise RuntimeError('Ambiguous old clock3 M1 conductor')
        cell.remove(clock[0]);metal.remove(clock[0]);clock_new=c.gdstk.boolean([rect(576,22.75,588,96.5),rect(582,18.75,594,38.75)],[],'or',precision=.000001,layer=19);metal+=clock_new
        changes.append(dict(kind='new_gate588N_clock3_contact_using_existing_M2_clock_row',new_LIG_V0_nm=[582,22.75,594,34.75],old_clock_V1_retained=True))
        # Preserve the existing SH14 connection while increasing its corner clearance.
        via=exact(cell,18,[606,80.5,618,92.5]);moved=via.copy();moved.translate(-.002,0);cell.remove(via);cell.add(moved)
        metal=c.gdstk.boolean(metal,[rect(606,76.5,618,96.5)],'not',precision=.000001,layer=19)
        metal=c.gdstk.boolean(metal,[rect(604,76.5,616,96.5),rect(616,78,618,93.5)],'or',precision=.000001,layer=19)
        cell.remove(*[p for p in cell.polygons if p.layer==19 and p.datatype==0]);cell.add(*metal)
        changes.append(dict(kind='SH14_supported_V0_pad_left_2nm',old_nm=[606,80.5,618,92.5],new_nm=[604,80.5,616,92.5]))
        sdt=[p for p in cell.polygons if p.layer==88 and abs(p.bounding_box()[0][0]-.263)<1e-8 and abs(p.bounding_box()[1][0]-.283)<1e-8 and abs(p.bounding_box()[1][1]-.03725)<1e-8]
        if len(sdt)!=1:raise RuntimeError('Ambiguous measured SDT.ACT contact')
        old=sdt[0];b=old.bounding_box();cell.remove(old);cell.add(c.gdstk.rectangle(b[0],(b[1][0],.041),layer=88));changes.append(dict(kind='extend_SDT_contact_to_cover_actual_ACT_edge',before_bbox=old.bounding_box(),new_upper_y_nm=41))
        if c.geometry(cell,{16,17,18,19,20,21,25,30,88})!=formation or cell.bounding_box()!=bounds:raise RuntimeError('Approved formation geometry/bounds changed')
        for label in cell.labels:
            if label.layer==19 and not any(c.gdstk.inside([label.origin],[p])[0] for p in metal):raise RuntimeError('Pin-label coverage lost '+label.text)
        (work/'inputs').mkdir(parents=True);lib.write_gds(str(work/'inputs/cell.gds'));shutil.copyfile(c.PHYSICAL/'cells'/name/'iter002/inputs/topology.cdl',work/'inputs/topology.cdl')
        audit=dict(source_gds=str(source),source_sha256=c.sha(source),candidate_sha256=c.sha(work/'inputs/cell.gds'),changes=changes,all_approved_32_channel_polygons_preserved=True,authorized_prior_M7_translation_nm=42,pin_labels_and_bounds_preserved=True,no_M3_or_V2_added=True)
        c.save(work/'GEOMETRY_CHANGES.json',audit);c.save(c.HERE/'BATCH08_STATUS.json',dict(stage='native_candidate_DRC_LVS',owner=owner));drc=c.native(name,work,'drc');lvs=c.native(name,work,'lvs');archive=c.HERE/'candidate08'/name;c.copy_tree(work,archive)
        result=dict(cell=name,passed=drc['passed'] and lvs['passed'],candidate_gds=str(archive/'inputs/cell.gds'),candidate_sha256=c.sha(archive/'inputs/cell.gds'),drc=drc,lvs=lvs,audit=audit,final_admission_owner='c1_drc_clean_pilot');c.save(archive/'RESULT.json',result);c.save(c.HERE/'BATCH08_STATUS.json',dict(stage='complete',owner=owner,passed=result['passed'],DRC=drc['violations'],LVS=lvs['passed']))
    except Exception:c.save(c.HERE/'BATCH08_STATUS.json',dict(stage='candidate_failed_preserve',owner=owner,traceback=traceback.format_exc()));raise
if __name__=='__main__':main()
