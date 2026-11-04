"""Prepare or run one packaged Liberate cell; no scheduler or campaign controller."""
import argparse,hashlib,json,os,re,shutil,subprocess,time
from pathlib import Path

def digest(data):return hashlib.sha256(data).hexdigest()

def tcl_word(value):
    text=str(value)
    if any(c in text for c in ['{','}','\n','\r']):raise ValueError('Unsupported Tcl path characters')
    return '{'+text+'}'

def relocate_tcl(source,work,spectre,threads=None):
    """Replace only explicit tool/file locations and optional CPU count."""
    targets=[
        (r'^set_var extsim_cmd\s+.*$', 'set_var extsim_cmd '+tcl_word(spectre)),
        (r'^set_var extsim_deck_dir\s+.*$', 'set_var extsim_deck_dir '+tcl_word(work/'DECK')),
        (r'^set_var extsim_model_include\s+.*$', 'set_var extsim_model_include '+tcl_word(work/'model_native.scs')),
        (r'^read_spice -format spice\s+.*$', 'read_spice -format spice '+tcl_word(work/'cells.sp')),
        (r'^write_library -overwrite\s+.*$', 'write_library -overwrite '+tcl_word(work/'candidate.lib'))]
    text=source
    for pattern,replacement in targets:
        text,count=re.subn(pattern,lambda match:replacement,text,flags=re.MULTILINE)
        if count!=1:raise ValueError('Unexpected native Tcl structure: '+pattern)
    if threads is not None:
        text,count=re.subn(r'^(char_library\s+.*?-thread\s+)\d+',lambda m:m[1]+str(threads),text,flags=re.MULTILINE)
        if count!=1:raise ValueError('Expected one char_library thread declaration')
    if re.search(r'^\s*(source|exec)\s',text,re.MULTILINE):raise ValueError('External Tcl dependencies are not admitted')
    scientific='\n'.join(line for line in text.splitlines() if not line.startswith(('set_var extsim_cmd ','set_var extsim_deck_dir ','set_var extsim_model_include ','read_spice -format spice ','write_library -overwrite ')))
    if any(path in scientific for path in ['/cedar/','/nethome/','/tools/software/','/tmp/','/usr/scratch/']):
        raise ValueError('Unrelocated archived source dependency remains')
    return text

def main():
    p=argparse.ArgumentParser(description=__doc__)
    group=p.add_mutually_exclusive_group(required=True)
    group.add_argument('--inputs',type=Path,help='Directory containing run.tcl, cells.sp, model_native.scs')
    group.add_argument('--bundle',type=Path,help='Portable characterization bundle containing MANIFEST.json')
    p.add_argument('--cell',help='Exact cell name when --bundle is used')
    p.add_argument('--work',required=True,type=Path,help='New host-local output directory')
    p.add_argument('--spectre',default=os.environ.get('SPECTRE_BIN','spectre'))
    p.add_argument('--liberate',default=os.environ.get('LIBERATE_BIN','liberate'))
    p.add_argument('--threads',type=int)
    p.add_argument('--run',action='store_true',help='Launch one native cell; otherwise only prepare and print the command')
    args=p.parse_args()
    if args.threads is not None and not 1<=args.threads<=64:p.error('--threads must be 1..64')
    work=args.work.absolute()
    if work.exists():p.error('--work must be a new directory, preserving all previous native outputs')
    if args.bundle:
        if not args.cell:p.error('--cell is required with --bundle')
        inputs=args.bundle.resolve();manifest=json.loads((inputs/'MANIFEST.json').read_text())
        matches=[row for row in manifest['cells'] if row['cell']==args.cell]
        if len(matches)!=1:p.error('Expected one exact cell in bundle')
        row=matches[0]
        if row['execution_status'] not in ['measured_native_inputs_verified','active_native_inputs_verified']:
            p.error('Prepared-only cell has no verified actually-used Tcl; refresh the bundle after native admission')
        source={}
        for name,key in [('run.tcl','actual_run_tcl'),('cells.sp','actual_cells_sp'),('model_native.scs','actual_model_native')]:
            item=row['inputs'][key];relative=Path(item['path']);path=(inputs/relative).resolve()
            if relative.is_absolute() or '..' in relative.parts or not path.is_relative_to(inputs):p.error('Invalid bundle path')
            data=path.read_bytes()
            if digest(data)!=item['sha256']:p.error('Bundle input hash mismatch: '+key)
            source[name]=data
    else:
        inputs=args.inputs.resolve();source={name:(inputs/name).read_bytes() for name in ['run.tcl','cells.sp','model_native.scs']}
    executable=shutil.which(args.spectre) or args.spectre
    script=relocate_tcl(source['run.tcl'].decode(),work,executable,args.threads)
    work.mkdir(parents=True)
    for name in ['cells.sp','model_native.scs']:(work/name).write_bytes(source[name])
    (work/'ORIGINAL_USED_RUN.tcl').write_bytes(source['run.tcl'])
    (work/'run.tcl').write_text(script)
    (work/'tmp').mkdir()
    command=[args.liberate,str(work/'run.tcl')]
    receipt=dict(stage='prepared_only',created_epoch=time.time(),inputs=str(inputs),work=str(work),command=command,
        input_sha256={name:digest(data) for name,data in source.items()},relocated_tcl_sha256=digest(script.encode()),
        substitutions='Native executable/work/output paths and optional CPU count only. Original Tcl preserved.',
        solver_note='Approved production recipe actually used traponly/reltol1e-3/maxstep0.2ps in the archived native tool version. Legacy requested options in Tcl are retained; inspect actual simulator logs if using another version.',
        scientific_pass=False)
    (work/'REPRODUCTION.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2),flush=True)
    if args.run:
        env=dict(os.environ,TMPDIR=str(work/'tmp'))
        for key,value in [('OMP_NUM_THREADS','1'),('OPENBLAS_NUM_THREADS','1'),('LIBERATE_LORDER','TOKENS'),('ALTOS_64','1'),('CDS_AUTO_64BIT','ALL')]:env.setdefault(key,value)
        with (work/'liberate.log').open('wb') as log:
            rc=subprocess.run(command,cwd=work,env=env,stdout=log,stderr=subprocess.STDOUT).returncode
        receipt.update(stage='native_process_ended_requires_result_validation',native_rc=rc,ended_epoch=time.time())
        (work/'REPRODUCTION.json').write_text(json.dumps(receipt,indent=2)+'\n')
        raise SystemExit(rc)

if __name__=='__main__':main()
