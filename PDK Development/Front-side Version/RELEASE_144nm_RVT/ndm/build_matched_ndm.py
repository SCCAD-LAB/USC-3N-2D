"""Prepare or build/reopen matched144nm NDM; refuses pre-final native timing."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,time

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def copy_approved_source(source,target,expected):
    """Retain the immutable admitted identity across the check/copy boundary."""
    if digest(source)!=expected:raise ValueError('Source changed before NDM copy')
    shutil.copyfile(source,target)
    if digest(target)!=expected or digest(source)!=expected:raise ValueError('NDM copy differs from initial package-approved source')

def verify_approved_inputs(sources,copies,approved):
    for key,expected in approved.items():
        if digest(sources[key])!=expected or digest(copies[key])!=expected:raise ValueError('NDM source/local copy changed from initial approval: '+key)

def quote(value):
    return '"'+str(value).replace('\\','\\\\').replace('"','\\"').replace('$','\\$').replace('[','\\[').replace(']','\\]').replace('\n','\\n').replace('\r','\\r')+'"'

def lef_interfaces(path):
    text=path.read_text(); result={}
    for match in re.finditer(r'^MACRO\s+(\S+)\s*$',text,re.M):
        name=match.group(1); tail=text[match.end():]
        end=re.search(r'^END\s+'+re.escape(name)+r'\s*$',tail,re.M)
        if not end:raise ValueError('Missing LEF macro END '+name)
        block=tail[:end.start()]
        size=re.search(r'^\s*SIZE\s+([\d.]+)\s+BY\s+([\d.]+)\s*;',block,re.M)
        pins=sorted(re.findall(r'^\s*PIN\s+(\S+)\s*$',block,re.M))
        if not size or not pins or name in result:raise ValueError('Invalid LEF interface '+name)
        result[name]=dict(width_um=float(size[1]),height_um=float(size[2]),pins=pins)
    return result

def interface_tcl(interfaces):
    rows=[]
    for name,row in sorted(interfaces.items()):
        rows.append(quote(name)+' [list '+str(row['width_um'])+' '+str(row['height_um'])+' [list '+' '.join(quote(pin) for pin in row['pins'])+']]')
    return 'set ndm_expected_interfaces [dict create '+' '.join(rows)+']\n'

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repo',type=Path,required=True);ap.add_argument('--work',type=Path,required=True)
    ap.add_argument('--run',action='store_true')
    ap.add_argument('--lm-shell',default=os.environ.get('ICC2_LM_BIN','/tools/software/synopsys/icc2/latest/bin/icc2_lm_shell'))
    ap.add_argument('--icc2-shell',default=os.environ.get('ICC2_BIN','/tools/software/synopsys/icc2/latest/bin/icc2_shell'))
    a=ap.parse_args();root=a.repo.resolve();release=root/'PDK Development/Front-side Version/RELEASE_144nm_RVT'
    package=json.loads((release/'PACKAGE_FILES.json').read_text())
    if package.get('electrical_artifacts_staged') is not True or package.get('native_cells')!=57:raise SystemExit('Blocked: final accepted57 native LIB/DB is not staged; no native NDM build.')
    syn=root/'PnR-Synopsys/Front-side Version'
    paths={'ndm_db':syn/'LIB_DB/3nm_GAA_FSPR_rvt_nldm.db','ndm_cell_lef':syn/'LEF/3nm_GAA_FSPR.lef','ndm_tech':syn/'TF/3nm_GAA_FSPR.tf','ndm_tech_lef':syn/'TECH-LEF/3nm_GAA_FSPR.tech.lef'}
    expected={'ndm_db':package['native_database_sha256'],'ndm_cell_lef':package['selected_lef_sha256']}
    for key,value in expected.items():
        if digest(paths[key])!=value:raise SystemExit('Blocked: selected native source hash mismatch '+key)
    # Technology identities must be frozen in the package, not supplied ad hoc.
    frozen=package.get('matched_ndm_technology_sha256',{})
    for key in ['ndm_tech','ndm_tech_lef']:
        if not frozen.get(key) or digest(paths[key])!=frozen[key]:raise SystemExit('Blocked: missing/mismatched frozen NDM technology '+key)
    approved=dict(expected)
    for key in ['ndm_tech','ndm_tech_lef']:approved[key]=frozen[key]
    selected=json.loads((release/'physical/evidence/PEX_MANIFEST.json').read_text());names=sorted(row['cell'] for row in selected['rows'])
    if len(set(names))!=57 or any(not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]*',name) for name in names):raise SystemExit('Expected57 exact safe cell names')
    work=a.work.resolve()
    if work.exists():raise SystemExit('Use a new host-local work directory')
    work.mkdir(parents=True);output=work/'3nm_GAA_FSPR_144nm_rvt.ndm';here=Path(__file__).resolve().parent
    for name in ['build_matched_ndm.tcl','reopen_matched_ndm.tcl','check_ndm_interfaces.tcl']:shutil.copyfile(here/name,work/name)
    # LM's technology argument parser needs a local basename, even when Tcl
    # supplies a spaced repository path as one argument. Copy exact bytes.
    local_names={'ndm_db':'cells.db','ndm_cell_lef':'cells.lef','ndm_tech':'tech.tf','ndm_tech_lef':'tech.lef'}
    local_paths={key:work/name for key,name in local_names.items()}
    for key,name in local_names.items():
        copy_approved_source(paths[key],work/name,approved[key])
    setup='set ndm_final_timing_gate 1\n'+''.join('set '+key+' '+quote(name)+'\n' for key,name in local_names.items())
    interfaces=lef_interfaces(work/local_names['ndm_cell_lef'])
    if sorted(interfaces)!=names:raise SystemExit('Selected LEF interface names differ from physical manifest')
    setup+='set ndm_output '+quote(output.name)+'\nset ndm_expected_site coreSite\nset ndm_expected_cells [list '+' '.join(quote(name) for name in names)+']\n'+interface_tcl(interfaces);(work/'inputs.tcl').write_text(setup)
    hashes=dict(approved)
    verify_approved_inputs(paths,local_paths,approved)
    result={'stage':'prepared_only','native_jobs':0,'source_sha256':hashes,'expected_cells':names,'publication_approved':False,'work':str(work)}
    if a.run:
        env=dict(os.environ,USC144_NDM_WORK=str(work));result['native_jobs']=2
        for binary,tcl,log,marker in [(a.lm_shell,'build_matched_ndm.tcl','BUILD.log','USC144_NDM_BUILD_PASS 57'),(a.icc2_shell,'reopen_matched_ndm.tcl','REOPEN.log','USC144_NDM_REOPEN_PASS 57')]:
            started=time.time()
            with (work/log).open('wb') as stream:p=subprocess.run([binary,'-f',tcl],cwd=work,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=600)
            text=(work/log).read_text(errors='replace');result[log]={'rc':p.returncode,'wall_s':time.time()-started,'sha256':digest(work/log)}
            verify_approved_inputs(paths,local_paths,approved)
            if p.returncode or marker not in text or re.search(r'^Error:',text,re.M):raise SystemExit('Native NDM stage failed; preserve '+str(work/log))
        verify_approved_inputs(paths,local_paths,approved)
        files=[{'path':str(p.relative_to(output)),'sha256':digest(p),'bytes':p.stat().st_size} for p in sorted(output.rglob('*')) if p.is_file()]
        if not files:raise SystemExit('Native NDM output directory is empty')
        result.update(stage='native_build_and_fresh_reopen_passed',passed=True,NDM_directory=str(output),NDM_files=files,NDM_bytes=sum(row['bytes'] for row in files),readback_cells=names,readback_site=(work/'REOPENED_SITE.txt').read_text().strip(),readback_interfaces_sha256=digest(work/'REOPENED_INTERFACES.tsv'),expected_interfaces=interfaces)
    (work/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))

if __name__=='__main__':main()
