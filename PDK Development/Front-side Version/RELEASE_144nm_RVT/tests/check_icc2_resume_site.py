"""Exercise actual ICC2 resume and site branches with native-command stubs."""
from pathlib import Path
import argparse,hashlib,json,subprocess,tempfile,time

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--repo',type=Path,required=True)
    ap.add_argument('--sources',type=Path)
    ap.add_argument('--output',type=Path)
    a=ap.parse_args();repo=a.repo.resolve();sources=(a.sources or a.repo).resolve()
    here=Path(__file__).resolve().parent;rows=[]
    for design in ['ECG','OpenPiton']:
        with tempfile.TemporaryDirectory(prefix='usc144 resume site ',dir='/tmp') as directory:
            p=subprocess.run(['tclsh',str(here/'icc2_resume_site.tcl'),str(repo),str(sources),design,directory],capture_output=True,text=True)
            rows.append(dict(design=design,passed=p.returncode==0,rc=p.returncode,stdout=p.stdout,stderr=p.stderr))
    result=dict(passed=all(row['passed'] for row in rows),epoch=time.time(),cases=rows,native_simulations=0,chip_PNR_runs=0,harness_sha256=hashlib.sha256((here/'icc2_resume_site.tcl').read_bytes()).hexdigest(),scope='Actual createLibs and setupConfig procedures with native-command stubs; fresh technology/site, valid resume, legacy refs, changed release/readiness/payloads, missing provenance and absent site.')
    if a.output:a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))
    if not result['passed']:raise SystemExit(1)

if __name__=='__main__':main()
