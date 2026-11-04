"""Isolated XOR/XNOR routing candidates; never writes final cell gates/manifests."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import hashlib,json,os,re,shutil,socket,subprocess,sys,time,traceback
HERE=Path(__file__).resolve().parent
PHYSICAL=HERE.parent
RELEASE=PHYSICAL.parent
sys.path.insert(0,str(RELEASE.parent/'ten_parameter_c0_20261103/deps'))
import gdstk
WORK=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/routing_repairs/candidate01')
CELLS=['XOR2x1','XOR3x1','XNOR2x1','XNOR3x1']
ENV=dict(os.environ,SNPSLMD_LICENSE_FILE='1910@ece-winlic.ece.gatech.edu',OMP_NUM_THREADS='1')
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True);temp=path.with_name(path.name+f'.{os.getpid()}.tmp');temp.write_text(json.dumps(data,indent=2)+'\n');os.replace(temp,path)
def copy_tree(source,target):
    target.mkdir(parents=True,exist_ok=True)
    for p in source.rglob('*'):
        q=target/p.relative_to(source)
        if p.is_dir():q.mkdir(parents=True,exist_ok=True)
        elif p.is_file():q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
def geometry(cell,exclude):
    return sorted((p.layer,p.datatype,tuple(tuple(round(float(x),9) for x in a) for a in p.points)) for p in cell.polygons if p.layer not in exclude)
def marker_rows(text):
    sections=re.split(r'\n-{20,}\n',text.split('ERROR DETAILS',1)[-1]);rows=[]
    for i in range(len(sections)-1):
        if sections[i].strip().startswith('M1.3 :'):
            for m in re.finditer(r'(?m)^\S+\s+\(\s*([-\d.]+),\s*([-\d.]+)\)\s+\(\s*([-\d.]+),\s*([-\d.]+)\)\s+([-\d.]+)',sections[i+1]):rows.append(list(map(float,m.groups())))
    return rows
def modify(name,destination):
    source=PHYSICAL/'cells'/name/'iter001/inputs/cell.gds';lib=gdstk.read_gds(str(source));c=lib.cells[0]
    frozen=geometry(c,{18,19});before_bounds=c.bounding_box();changes=[]
    original=[p for p in c.polygons if p.layer==19 and p.datatype==0]
    m1=gdstk.boolean(original,[],'or',precision=.000001,layer=19);component_count=len(m1)
    upper_x=[.183] if name in ['XOR2x1','XNOR2x1'] else [.141,.435]
    for x in upper_x:
        matches=[p for p in c.polygons if p.layer==18 and p.datatype==0 and all(abs(a-b)<1e-8 for a,b in zip(sum(p.bounding_box(),()),(x,.0805,x+.012,.0925)))]
        if len(matches)!=1:raise RuntimeError('Expected unique upper diffusion V0 '+str((name,x,len(matches))))
        old=matches[0];new=old.copy();new.translate(.003,0)
        supports=[p for p in c.polygons if p.layer==17 and p.datatype==0]
        if gdstk.boolean([new],supports,'not',precision=.000001):raise RuntimeError('Shifted V0 leaves unchanged LISD support')
        c.remove(old);c.add(new)
        # Shift only the diffusion-supported via/pad sideways, retaining its y clearances.
        old_pad=gdstk.rectangle((x,.0765),(x+.012,.0965))
        m1=gdstk.boolean(m1,[old_pad],'not',precision=.000001,layer=19)
        upper_trim=gdstk.rectangle((x-.063,.078),(x+.003,.0795))
        lower_trim=gdstk.rectangle((x-.009,.0645),(x+.042,.066))
        m1=gdstk.boolean(m1,[upper_trim,lower_trim],'not',precision=.000001,layer=19)
        pad=gdstk.rectangle((x+.003,.0765),(x+.015,.0965))
        bridge=gdstk.rectangle((x,.0795),(x+.003,.0935))
        m1=gdstk.boolean(m1,[pad,bridge],'or',precision=.000001,layer=19)
        changes.append(dict(kind='move_diffusion_supported_V0_and_M1_pad_right_3nm',old_via_bbox=old.bounding_box(),new_via_bbox=new.bounding_box(),LISD_unchanged=True,upper_body_trim_bbox=upper_trim.bounding_box(),lower_body_trim_bbox=lower_trim.bounding_box()))
    text=(PHYSICAL/'cells'/name/'iter001/drc'/f'{name}.LAYOUT_ERRORS').read_text()
    for marker in marker_rows(text):
        x0,y0,x1,y1,_=marker;touch=gdstk.rectangle((x0-.0001,y0-.0001),(x1+.0001,y1+.0001))
        touched=[p for p in m1 if gdstk.boolean([p],[touch],'and',precision=.000001)]
        if len(touched)!=1:raise RuntimeError('Notch fill must remain on one connected M1 component')
        fill=gdstk.rectangle((x0,y0),(x1,y1));m1=gdstk.boolean(m1,[fill],'or',precision=.000001,layer=19)
        changes.append(dict(kind='fill_same_component_M1_notch',marker_um=marker))
    if len(m1)!=component_count:raise RuntimeError('M1 connected component count changed')
    c.remove(*original);c.add(*m1)
    if geometry(c,{18,19})!=frozen:raise RuntimeError('Non-routing geometry changed')
    if c.bounding_box()!=before_bounds:raise RuntimeError('Cell boundary/bounds changed')
    for label in c.labels:
        if label.layer==19 and not any(gdstk.inside([label.origin],[p])[0] for p in m1):raise RuntimeError('Lost M1 pin-label coverage '+label.text)
    destination.parent.mkdir(parents=True,exist_ok=True);lib.write_gds(str(destination))
    return dict(cell=name,source_gds=str(source),source_sha256=sha(source),candidate_gds=str(destination),candidate_sha256=sha(destination),changes=changes,all_device_and_other_routing_layers_preserved=True,labels_preserved=True,bounds_preserved=True,M1_components_before=component_count,M1_components_after=len(m1))
def native(name,work,kind):
    target=work/kind;target.mkdir(parents=True,exist_ok=True)
    if kind=='drc':
        rules=PHYSICAL/'rules/matched_144nm/DRC';copy_tree(rules,target/'runset');copy_tree(rules/'Include',target/'Include');deck=target/'runset/sccad3nm_main.drc.rs'
    else:deck=PHYSICAL/'rules/matched_144nm/LVS/ICV_3nm.rs'
    cmd=['/tools/software/synopsys/icvalidator/latest/bin/icv','-i',str(work/'inputs/cell.gds'),'-c',name,'-f','GDSII','-host_init',socket.gethostname()+':2']
    if kind=='lvs':cmd+=['-s',str(work/'inputs/topology.cdl'),'-sf','SPICE','-stc',name]
    cmd+=[str(deck)];started=time.time()
    with (target/'console.log').open('w') as out:rc=subprocess.run(cmd,cwd=target,env=ENV,stdout=out,stderr=subprocess.STDOUT,timeout=1200).returncode
    report=target/(name+('.RESULTS' if kind=='drc' else '.LVS_ERRORS'));text=report.read_text() if report.exists() else ''
    record=dict(kind=kind,rc=rc,command=cmd,wall_s=time.time()-started,report=str(report),report_sha256=sha(report) if report.exists() else None,deck_sha256=sha(deck))
    if kind=='drc':
        m=re.search(r'There (?:are|is) (\d+) total violation',text);record.update(violations=int(m[1]) if m else None,rules_run=re.findall(r'(\d+) total rules were run',text),rules_not_executed=re.findall(r'(\d+) rules? NOT EXECUTED',text));record['passed']=rc==0 and record['violations']==0
    else:record.update(passed=rc==0 and 'Final comparison result:PASS' in text,native_property_checks_enabled=False)
    save(target/'RECEIPT.json',record);return record
def one(name):
    work=WORK/name
    if work.exists():raise RuntimeError('Preserve existing candidate attempt '+str(work))
    changes=modify(name,work/'inputs/cell.gds');shutil.copyfile(PHYSICAL/'cells'/name/'iter001/inputs/topology.cdl',work/'inputs/topology.cdl')
    changes['reference_sha256']=sha(work/'inputs/topology.cdl');save(work/'GEOMETRY_CHANGES.json',changes)
    drc=native(name,work,'drc');lvs=native(name,work,'lvs')
    archive=HERE/'candidate01'/name;copy_tree(work,archive)
    row=dict(cell=name,passed=drc['passed'] and lvs['passed'],candidate_gds=str(archive/'inputs/cell.gds'),candidate_sha256=sha(archive/'inputs/cell.gds'),drc=drc,lvs=lvs,changes=changes,host=socket.gethostname(),work=str(work),final_admission_owner='c1_drc_clean_pilot',final_physical_library_modified=False)
    save(archive/'RESULT.json',row);return row
def main():
    owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],started_epoch=time.time(),work=str(WORK))
    save(HERE/'LAUNCH.json',owner);rows=[]
    try:
        save(HERE/'STATUS.json',dict(stage='native_candidate_DRC_LVS',owner=owner))
        with ThreadPoolExecutor(max_workers=4) as pool:
            for f in as_completed([pool.submit(one,n) for n in CELLS]):
                rows.append(f.result());save(HERE/'RESULTS.json',dict(rows=rows));save(HERE/'STATUS.json',dict(stage='native_candidate_DRC_LVS',owner=owner,completed=len(rows),passed=sum(r['passed'] for r in rows)))
        save(HERE/'STATUS.json',dict(stage='complete',owner=owner,completed=4,passed=sum(r['passed'] for r in rows)))
    except Exception:
        save(HERE/'STATUS.json',dict(stage='candidate_failed_preserve',owner=owner,traceback=traceback.format_exc()));raise
if __name__=='__main__':main()
