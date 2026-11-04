"""Isolated DFFHQN and latch contact/routing repairs with frozen devices."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import os,shutil,socket,time,traceback
import candidate01 as c
WORK=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/routing_repairs/candidate04')
INPUTS={'DFFHQNx1':(1,'498c7e709c0b4efee425fbc30023df2d8887a0b58b0214ba2b0b4bebaf7705a2'),'DHLx1':(2,'1f31d5ec4fdcc09f8cce4532124e251852fa52e5a86f578f1fbd25d8fa821475')}
def rect(x0,y0,x1,y1,layer=19):return c.gdstk.rectangle((x0/1000,y0/1000),(x1/1000,y1/1000),layer=layer)
def exact(cell,layer,bounds):
    wanted=tuple(v/1000 for v in bounds)
    found=[p for p in cell.polygons if p.layer==layer and p.datatype==0 and all(abs(a-b)<1e-8 for a,b in zip(sum(p.bounding_box(),()),wanted))]
    if len(found)!=1:raise RuntimeError('Ambiguous exact routing polygon '+str((layer,bounds,len(found))))
    return found[0]
def component(m1,point):
    hits=[i for i,p in enumerate(m1) if c.gdstk.inside([(point[0]/1000,point[1]/1000)],[p])[0]]
    if len(hits)!=1:raise RuntimeError('Ambiguous M1 component '+str(point))
    return hits[0]
def modify(name,destination):
    iteration,expected=INPUTS[name];source=c.PHYSICAL/'cells'/name/f'iter{iteration:03d}'/'inputs/cell.gds'
    if c.sha(source)!=expected:raise RuntimeError('Latest owner source changed')
    lib=c.gdstk.read_gds(str(source));cell=lib.cells[0];frozen=c.geometry(cell,{16,18,19});bounds=cell.bounding_box();changes=[]
    old_m1=[p for p in cell.polygons if p.layer==19 and p.datatype==0];m1=c.gdstk.boolean(old_m1,[],'or',precision=.000001,layer=19);count=len(m1)
    if name=='DFFHQNx1':
        old=exact(cell,18,[309,79.25,321,91.25]);new=old.copy();new.translate(0,.00275)
        if c.gdstk.boolean([new],[p for p in cell.polygons if p.layer==17 and p.datatype==0],'not',precision=.000001):raise RuntimeError('Diffusion via leaves unchanged LISD')
        cell.remove(old);cell.add(new);cut=rect(309,70.75,321,78);m1=c.gdstk.boolean(m1,[cut],'not',precision=.000001,layer=19)
        changes.append(dict(kind='move_diffusion_V0_up_2p75nm_and_trim_unused_M1_lower_end',old_bbox=old.bounding_box(),new_bbox=new.bounding_box(),unchanged_LISD_support=True,cut_bbox=cut.bounding_box()))
    else:
        # End trims retain the complete original 12 nm gate-column overlaps.
        for old_bounds,new_bounds in [([246,66,279,78],[246,66,274,78]),([288,37.25,321,49.25],[288,37.25,316,49.25]),([351,80.5,384,92.5],[351,80.5,384,95.5])]:
            old=exact(cell,16,old_bounds);cell.remove(old);cell.add(rect(*new_bounds,layer=16));changes.append(dict(kind='LIG_contact_end_trim_or_extension',before_nm=old_bounds,after_nm=new_bounds))
        for old_bounds,dx,dy in [([267,66,279,78],-5,0),([309,37.25,321,49.25],-5,0),([351,80.5,363,92.5],0,3)]:
            old=exact(cell,18,old_bounds);new=old.copy();new.translate(dx/1000,dy/1000);cell.remove(old);cell.add(new)
            supports=[p for p in cell.polygons if p.layer in [16,17] and p.datatype==0]
            if c.gdstk.boolean([new],supports,'not',precision=.000001):raise RuntimeError('Moved via leaves routing contact support')
            changes.append(dict(kind='V0_supported_relocation',before_nm=old_bounds,dx_nm=dx,dy_nm=dy))
        a=component(m1,(273,72));b=component(m1,(336,115));d=component(m1,(315,55))
        if len({a,b,d})!=3:raise RuntimeError('Expected three separate M1 nets')
        fixed_a=c.gdstk.boolean([rect(267,66,279,96.5),rect(279,76.5,300,96.5),rect(262,62,274,82)],[],'or',precision=.000001,layer=19)
        fixed_b=c.gdstk.boolean([m1[b]],[rect(330,76.25,363,109.25)],'not',precision=.000001,layer=19)
        fixed_b=c.gdstk.boolean(fixed_b,[rect(330,79.5,363,99.5),rect(330,99.5,351,109.25)],'or',precision=.000001,layer=19)
        fixed_d=c.gdstk.boolean([rect(309,33.25,321,64.5),rect(304,33.25,316,53.25)],[],'or',precision=.000001,layer=19)
        if any(len(v)!=1 for v in [fixed_a,fixed_b,fixed_d]):raise RuntimeError('Contact routing became disconnected')
        m1[a]=fixed_a[0];m1[b]=fixed_b[0];m1[d]=fixed_d[0]
        changes.append(dict(kind='rectangularize_same_net_M1_repair_slivers_and_trim_uncontacted_stub',nets=[a,b,d],device_layers_changed=False))
    merged=c.gdstk.boolean(m1,[],'or',precision=.000001,layer=19)
    if len(merged)!=count:raise RuntimeError('M1 net-component count changed')
    cell.remove(*old_m1);cell.add(*merged)
    if c.geometry(cell,{16,18,19})!=frozen or cell.bounding_box()!=bounds:raise RuntimeError('Frozen transistor/other layers or bounds changed')
    for label in cell.labels:
        if label.layer==19 and not any(c.gdstk.inside([label.origin],[p])[0] for p in merged):raise RuntimeError('Lost pin label '+label.text)
    destination.parent.mkdir(parents=True,exist_ok=True);lib.write_gds(str(destination))
    return dict(source_gds=str(source),source_sha256=expected,candidate_sha256=c.sha(destination),source_iteration=iteration,changes=changes,all_layers_except_LIG_V0_M1_preserved=True,transistor_formation_layers_preserved=True,pin_labels_and_bounds_preserved=True,M1_components=count)
def one(name):
    work=WORK/name
    if work.exists():raise RuntimeError('Preserve candidate04 attempt')
    audit=modify(name,work/'inputs/cell.gds');iteration=INPUTS[name][0];shutil.copyfile(c.PHYSICAL/'cells'/name/f'iter{iteration:03d}/inputs/topology.cdl',work/'inputs/topology.cdl');c.save(work/'GEOMETRY_CHANGES.json',audit)
    drc=c.native(name,work,'drc');lvs=c.native(name,work,'lvs');archive=c.HERE/'candidate04'/name;c.copy_tree(work,archive)
    row=dict(cell=name,passed=drc['passed'] and lvs['passed'],candidate_gds=str(archive/'inputs/cell.gds'),candidate_sha256=c.sha(archive/'inputs/cell.gds'),drc=drc,lvs=lvs,audit=audit,final_admission_owner='c1_drc_clean_pilot');c.save(archive/'RESULT.json',row);return row
def main():
    owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],work=str(WORK),started_epoch=time.time());c.save(c.HERE/'BATCH04_LAUNCH.json',dict(owner=owner,stage='native_candidate_DRC_LVS'));rows=[]
    try:
        c.save(c.HERE/'BATCH04_STATUS.json',dict(stage='native_candidate_DRC_LVS',owner=owner))
        with ThreadPoolExecutor(max_workers=2) as pool:
            for f in as_completed([pool.submit(one,n) for n in INPUTS]):rows.append(f.result());c.save(c.HERE/'BATCH04_RESULTS.json',dict(rows=rows))
        c.save(c.HERE/'BATCH04_STATUS.json',dict(stage='complete',owner=owner,completed=2,passed=sum(r['passed'] for r in rows)))
    except Exception:c.save(c.HERE/'BATCH04_STATUS.json',dict(stage='candidate_failed_preserve',owner=owner,traceback=traceback.format_exc()));raise
if __name__=='__main__':main()
