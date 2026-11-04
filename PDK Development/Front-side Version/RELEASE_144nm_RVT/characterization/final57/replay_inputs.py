"""Portable geometry-bound input verifier; no simulator or historical SW path required."""
from pathlib import Path
import argparse,ast,hashlib,json,re,sys,tempfile

def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def replay(bundle,cell,output,dependency_path=None):
    bundle=Path(bundle).resolve();output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
    if dependency_path:sys.path.insert(0,str(Path(dependency_path).resolve()))
    sys.path.insert(0,str(bundle/'software'))
    from geometry_binding import bind_final_devices
    manifest=json.loads((bundle/'MANIFEST.json').read_text());row=next(r for r in manifest['cells'] if r['cell']==cell)
    def artifact(key):
        item=row['inputs'][key];p=bundle/item['path']
        if digest(p)!=item['sha256']:raise ValueError('Input hash mismatch '+cell+'/'+key)
        return p
    for key in row['inputs']:artifact(key)
    original=artifact('physical_binding');rebased=json.loads(original.read_text());rebased['native_dimension_report']=str(artifact('native_dimensions'))
    with tempfile.TemporaryDirectory(prefix='usc144_geometry_') as tmp:
        receipt=Path(tmp)/'portable_binding.json';receipt.write_text(json.dumps(rebased,indent=2)+'\n')
        derived=dict(cell=cell,gds=str(artifact('final_gds')),gds_sha256=row['inputs']['final_gds']['sha256'],dspf=str(artifact('body_normalized_dspf')),dspf_sha256=row['inputs']['body_normalized_dspf']['sha256'],device_geometry_binding=str(receipt),device_geometry_binding_sha256=digest(receipt))
        binding=bind_final_devices(derived)
    # Reuse exact audited scientific functions without importing campaign globals.
    runner=bundle/'software/input_functions.py';tree=ast.parse(runner.read_text());functions=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['normalize_dspf','spectre_syntax_adapter']]
    namespace=dict(Path=Path,re=re,MODEL=bundle/'models/github_FSPR_RVT.sp')
    exec(compile(ast.Module(body=functions,type_ignores=[]),str(runner),'exec'),namespace)
    cells,transforms=namespace['normalize_dspf'](artifact('body_normalized_dspf'),'spectre_native',binding)
    model,_=namespace['spectre_syntax_adapter']()
    if any(r['model_alias'] not in ['NMOS_LVT','PMOS_LVT'] for r in binding['rows']):model+='\n'+(bundle/'models/geometry_aliases.scs').read_text()
    if hashlib.sha256(cells.encode()).hexdigest()!=row['inputs']['prepared_cells_sp']['sha256'] or hashlib.sha256(model.encode()).hexdigest()!=row['inputs']['prepared_model_native']['sha256']:raise ValueError('Deterministic regeneration differs from retained source inputs')
    (output/'cells.sp').write_text(cells);(output/'model_native.scs').write_text(model)
    result=dict(passed=True,cell=cell,source_physical_binding_sha256=digest(original),portable_rebase='Only proof path fields rebased in a temporary wrapper; original proof and input bytes unchanged',GDS_LVS_PEX_channel_bijection=binding['passed'],actual_solver_policy=manifest['actual_solver_policy'],execution_status=row['execution_status'],cells_sp_sha256=digest(output/'cells.sp'),model_native_sha256=digest(output/'model_native.scs'),passive_RC_unchanged=transforms['passive_records_unchanged'])
    (output/'REPLAY_AUDIT.json').write_text(json.dumps(result,indent=2)+'\n');return result

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--bundle',type=Path,required=True);ap.add_argument('--cell',required=True);ap.add_argument('--output',type=Path,required=True);ap.add_argument('--dependency-path',type=Path);a=ap.parse_args();print(json.dumps(replay(a.bundle,a.cell,a.output,a.dependency_path)))
