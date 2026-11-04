"""Stub actual Tcl consumers: list and scalar path contracts, no native tools."""
from pathlib import Path
import argparse,hashlib,json,subprocess,tempfile,time

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repo',type=Path,required=True)
    ap.add_argument('--sources',type=Path)
    ap.add_argument('--output',type=Path)
    a=ap.parse_args();repo=a.repo.resolve();sources=a.sources.resolve() if a.sources else repo
    rows=[];here=Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix='usc144 argument spaces ',dir='/tmp') as directory:
        root=Path(directory)
        for tool,design in [('cadence','ECG'),('cadence','OpenPiton'),('synopsys','ECG'),('synopsys','OpenPiton'),('openroad','ECG')]:
            for macro in [0,1]:
                fixture=root/(tool+' '+design+' '+str(macro));(fixture/'macro files/memory cells.ndm').mkdir(parents=True);(fixture/'cap tables').mkdir()
                for name in ['macro files/memory cell.lef','macro files/memory timing.lib','cap tables/one cap.capTbl']:(fixture/name).write_text('')
                command=['tclsh',str(here/'selector_arguments.tcl'),str(repo),str(sources),tool,design,str(macro),str(fixture)]
                p=subprocess.run(command,capture_output=True,text=True)
                passed=p.returncode==0 and 'USC144_ACTUAL_SELECTOR_ARGUMENTS_PASS' in p.stdout
                rows.append(dict(tool=tool,design=design,optional_macro_and_cap=bool(macro),passed=passed,stdout=p.stdout.strip(),stderr=p.stderr.strip()))
    result=dict(passed=all(row['passed'] for row in rows),epoch=time.time(),repo=str(repo),sources=str(sources),cases=rows,native_tool_jobs=0,scope='Actual setup/MMMC/library Tcl procedures with command stubs. Tests real repository paths plus synthetic optional macro/cap paths containing spaces; no library content or PNR validation.',contracts={'LEF_LIB_NDM':'Tcl lists with exact element count/order/path','QRC_TCH_MAP_CAP_TLU':'Scalar raw filename argument, no serialized list braces'},harness_sha256=hashlib.sha256((here/'selector_arguments.tcl').read_bytes()).hexdigest())
    if a.output:a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
    if not result['passed']:raise SystemExit(1)

if __name__=='__main__':main()
