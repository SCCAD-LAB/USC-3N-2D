"""Second four-cell routing batch, isolated from final physical admissions."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import json,os,shutil,socket,time,traceback
import candidate01 as c
WORK=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/routing_repairs/candidate03')
NAMES=['AOI222x1','NAND3x2','NOR3x2','OAI222x1']
EXPECTED={'AOI222x1':'8e5c4e15914b64f052cef75d4449df8d28f625d64503f8c701d71df82ac70407','NAND3x2':'9255cfc839ca7c360b6b7b0ba916d3eb72c6a80d6d2557014ae4182be50dda6a','NOR3x2':'b77c3d83db23c9d8e8420fc4632a0199f7096114dd8dd07d175300f8c3108ae0','OAI222x1':'93be53685f9a750b1ac57886345e22622a0b62a197e0be4cad7bf0ad17a72b01'}
def modify(name,destination):
    source=c.PHYSICAL/'cells'/name/'iter001/inputs/cell.gds'
    if c.sha(source)!=EXPECTED[name]:raise RuntimeError('Owner source changed; require coordination')
    lib=c.gdstk.read_gds(str(source));cell=lib.cells[0];frozen=c.geometry(cell,{18,19});bounds=cell.bounding_box();changes=[]
    old=[p for p in cell.polygons if p.layer==19 and p.datatype==0];m1=c.gdstk.boolean(old,[],'or',precision=.000001,layer=19);count=len(m1)
    cuts=[];adds=[]
    if name in ['AOI222x1','OAI222x1']:
        lower=name=='OAI222x1';x=.183;y=.0515 if lower else .0805
        found=[p for p in cell.polygons if p.layer==18 and p.datatype==0 and all(abs(a-b)<1e-8 for a,b in zip(sum(p.bounding_box(),()),(x,y,x+.012,y+.012)))]
        if len(found)!=1:raise RuntimeError('Unique diffusion via not found')
        via=found[0];newvia=via.copy();newvia.translate(.003,0)
        if c.gdstk.boolean([newvia],[p for p in cell.polygons if p.layer==17 and p.datatype==0],'not',precision=.000001):raise RuntimeError('Moved via unsupported by unchanged LISD')
        cell.remove(via);cell.add(newvia)
        oldpad=c.gdstk.rectangle((x,y-.004),(x+.012,y+.016));m1=c.gdstk.boolean(m1,[oldpad],'not',precision=.000001,layer=19)
        adds.append(c.gdstk.rectangle((x+.003,y-.004),(x+.015,y+.016)))
        if lower:
            cuts.append(c.gdstk.rectangle((.099,.0645),(.186,.066)))
            adds.append(c.gdstk.rectangle((.183,.0505),(.186,.0645)))
            # Preserve the middle access via/pin and shorten only its unused lower stub.
            cuts.append(c.gdstk.rectangle((.211,.0505),(.223,.055)))
        else:
            cuts.append(c.gdstk.rectangle((.099,.078),(.186,.0795)))
            adds.append(c.gdstk.rectangle((.183,.0795),(.186,.0935)))
            cuts.append(c.gdstk.rectangle((.211,.089),(.223,.0935)))
        changes.append(dict(kind='diffusion_V0_M1_pad_shift_right_3nm',old_via=via.bounding_box(),new_via=newvia.bounding_box(),unchanged_LISD_support=True))
    elif name=='NAND3x2':
        cuts=[c.gdstk.rectangle((.132,.078),(.204,.0795)),c.gdstk.rectangle((.174,.0645),(.235,.066))]
    else:
        cuts=[c.gdstk.rectangle((.174,.078),(.235,.0795)),c.gdstk.rectangle((.132,.0645),(.204,.066))]
    protected=[]
    for p in cell.polygons:
        if p.layer in [18,21]:
            b=p.bounding_box();protected.append(c.gdstk.rectangle((b[0][0],b[0][1]-.004),(b[1][0],b[1][1]+.004)))
    for cut in cuts:
        if c.gdstk.boolean([cut],protected,'and',precision=.000001):raise RuntimeError('Trim touches a via/enclosure support')
        changes.append(dict(kind='trim_unprotected_M1_body_or_stub',bbox=cut.bounding_box()))
    m1=c.gdstk.boolean(m1,cuts,'not',precision=.000001,layer=19)
    if adds:m1=c.gdstk.boolean(m1,adds,'or',precision=.000001,layer=19)
    if len(m1)!=count:raise RuntimeError('M1 component count changed')
    cell.remove(*old);cell.add(*m1)
    if c.geometry(cell,{18,19})!=frozen or cell.bounding_box()!=bounds:raise RuntimeError('Frozen geometry/bounds changed')
    for label in cell.labels:
        if label.layer==19 and not any(c.gdstk.inside([label.origin],[p])[0] for p in m1):raise RuntimeError('Lost pin-label support '+label.text)
    destination.parent.mkdir(parents=True,exist_ok=True);lib.write_gds(str(destination))
    return dict(source_gds=str(source),source_sha256=c.sha(source),candidate_sha256=c.sha(destination),changes=changes,all_nonV0_M1_geometry_preserved=True,pin_labels_and_bounds_preserved=True,via_enclosure_support_preserved=True,M1_components_before=count,M1_components_after=len(m1))
def one(name):
    work=WORK/name
    if work.exists():raise RuntimeError('Preserve existing attempt')
    audit=modify(name,work/'inputs/cell.gds');shutil.copyfile(c.PHYSICAL/'cells'/name/'iter001/inputs/topology.cdl',work/'inputs/topology.cdl');c.save(work/'GEOMETRY_CHANGES.json',audit)
    drc=c.native(name,work,'drc');lvs=c.native(name,work,'lvs');archive=c.HERE/'candidate03'/name;c.copy_tree(work,archive)
    result=dict(cell=name,passed=drc['passed'] and lvs['passed'],candidate_gds=str(archive/'inputs/cell.gds'),candidate_sha256=c.sha(archive/'inputs/cell.gds'),drc=drc,lvs=lvs,audit=audit,final_admission_owner='c1_drc_clean_pilot')
    c.save(archive/'RESULT.json',result);return result
def main():
    owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],work=str(WORK),started_epoch=time.time())
    c.save(c.HERE/'BATCH03_LAUNCH.json',dict(owner=owner,stage='native_candidate_DRC_LVS'));rows=[]
    try:
        c.save(c.HERE/'BATCH03_STATUS.json',dict(stage='native_candidate_DRC_LVS',owner=owner))
        with ThreadPoolExecutor(max_workers=4) as pool:
            for f in as_completed([pool.submit(one,n) for n in NAMES]):
                rows.append(f.result());c.save(c.HERE/'BATCH03_RESULTS.json',dict(rows=rows))
        c.save(c.HERE/'BATCH03_STATUS.json',dict(stage='complete',owner=owner,completed=4,passed=sum(r['passed'] for r in rows)))
    except Exception:
        c.save(c.HERE/'BATCH03_STATUS.json',dict(stage='candidate_failed_preserve',owner=owner,traceback=traceback.format_exc()));raise
if __name__=='__main__':main()
