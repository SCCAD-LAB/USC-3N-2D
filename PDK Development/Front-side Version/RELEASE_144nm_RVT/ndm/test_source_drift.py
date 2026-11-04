"""Synthetic check/copy mutation regression; never invokes a native tool."""
from pathlib import Path
import argparse,contextlib,hashlib,importlib.util,io,json,shutil,sys,tempfile,time

def load(path):
    spec=importlib.util.spec_from_file_location('ndm_builder_under_test',path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def run_mutation(builder):
    module=load(builder)
    with tempfile.TemporaryDirectory(prefix='usc144 source drift ',dir='/tmp') as directory:
        root=Path(directory);repo=root/'repository';release=repo/'PDK Development/Front-side Version/RELEASE_144nm_RVT';syn=repo/'PnR-Synopsys/Front-side Version'
        sources={'ndm_db':syn/'LIB_DB/3nm_GAA_FSPR_rvt_nldm.db','ndm_cell_lef':syn/'LEF/3nm_GAA_FSPR.lef','ndm_tech':syn/'TF/3nm_GAA_FSPR.tf','ndm_tech_lef':syn/'TECH-LEF/3nm_GAA_FSPR.tech.lef'}
        names=['CELL_'+str(i) for i in range(57)]
        for key,path in sources.items():path.parent.mkdir(parents=True,exist_ok=True);path.write_text('SYNTHETIC_'+key+'_A\n')
        sources['ndm_cell_lef'].write_text(''.join('MACRO '+name+'\n SIZE 0.084 BY 0.144 ;\n PIN A\n END A\nEND '+name+'\n' for name in names))
        hashes={key:hashlib.sha256(path.read_bytes()).hexdigest() for key,path in sources.items()}
        release.mkdir(parents=True);(release/'PACKAGE_FILES.json').write_text(json.dumps({'electrical_artifacts_staged':True,'native_cells':57,'native_database_sha256':hashes['ndm_db'],'selected_lef_sha256':hashes['ndm_cell_lef'],'matched_ndm_technology_sha256':{key:hashes[key] for key in ['ndm_tech','ndm_tech_lef']}}))
        evidence=release/'physical/evidence';evidence.mkdir(parents=True);(evidence/'PEX_MANIFEST.json').write_text(json.dumps({'rows':[{'cell':name} for name in names]}))
        original=shutil.copyfile;mutated=False
        def copy_with_mutation(source,target,*args,**kwargs):
            nonlocal mutated
            if Path(source)==sources['ndm_db'] and not mutated:
                mutated=True;sources['ndm_db'].write_text('SYNTHETIC_ndm_db_B\n')
            return original(source,target,*args,**kwargs)
        argv=sys.argv[:];sys.argv=[str(builder),'--repo',str(repo),'--work',str(root/'build_work')]
        shutil.copyfile=copy_with_mutation;rejected=False;reason=None
        try:
            with contextlib.redirect_stdout(io.StringIO()):module.main()
        except (ValueError,SystemExit) as error:rejected=True;reason=type(error).__name__
        finally:shutil.copyfile=original;sys.argv=argv
        result=root/'build_work/RESULT.json'
        return dict(mutation_injected=mutated,rejected=rejected,accepted_result_exists=result.exists(),reason_type=reason,native_tools_invoked=0,synthetic_only=True)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--builder',type=Path,default=Path(__file__).with_name('build_matched_ndm.py'))
    ap.add_argument('--previous-builder',type=Path)
    ap.add_argument('--output',type=Path)
    a=ap.parse_args();current=run_mutation(a.builder.resolve())
    result=dict(passed=current['mutation_injected'] and current['rejected'] and not current['accepted_result_exists'],current=current,epoch=time.time(),native_tools_invoked=0,synthetic_only=True)
    module=load(a.builder.resolve())
    if hasattr(module,'verify_approved_inputs'):
        with tempfile.TemporaryDirectory(prefix='usc144 local drift ',dir='/tmp') as directory:
            root=Path(directory);source=root/'source';local=root/'local';source.write_bytes(b'SYNTHETIC_A');local.write_bytes(source.read_bytes());approved={'input':hashlib.sha256(source.read_bytes()).hexdigest()}
            module.verify_approved_inputs({'input':source},{'input':local},approved)
            local.write_bytes(b'SYNTHETIC_B');rejected=False
            try:module.verify_approved_inputs({'input':source},{'input':local},approved)
            except ValueError:rejected=True
            result['local_post_build_drift_rejected']=rejected;result['passed']=result['passed'] and rejected
    if a.previous_builder:
        previous=run_mutation(a.previous_builder.resolve());result['previous']=previous
        result['passed']=result['passed'] and previous['mutation_injected'] and not previous['rejected'] and previous['accepted_result_exists']
    if a.output:a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
    if not result['passed']:raise SystemExit(1)

if __name__=='__main__':main()
