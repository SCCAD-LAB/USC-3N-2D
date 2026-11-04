"""Verify repository-relative release artifacts without Cedar or native tools."""
import argparse,gzip,hashlib,json
from pathlib import Path

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda:stream.read(1048576),b''):h.update(block)
    return h.hexdigest()

def repository_path(root,relative):
    name=Path(relative)
    if name.is_absolute() or '..' in name.parts:raise ValueError('Expected repository-relative path: '+str(relative))
    result=(root/name).resolve()
    if not result.is_relative_to(root.resolve()):raise ValueError('Artifact escapes repository: '+str(relative))
    return result

def verify(root,manifest):
    errors=[]
    for row in manifest['files']:
        name=row['repository_path']
        try:
            artifact=repository_path(root,name)
            if digest(artifact)!=row['sha256']:errors.append(name+': hash mismatch')
            if row.get('uncompressed_sha256'):
                h=hashlib.sha256();size=0
                with gzip.open(artifact,'rb') as stream:
                    for block in iter(lambda:stream.read(1048576),b''):h.update(block);size+=len(block)
                if h.hexdigest()!=row['uncompressed_sha256'] or size!=row['uncompressed_bytes']:errors.append(name+': raw CSV payload mismatch')
            if artifact.suffix=='.json':
                def nonfinite(value):raise ValueError('Nonstandard JSON number: '+value)
                json.loads(artifact.read_text(),parse_constant=nonfinite)
        except (OSError,ValueError) as exc:errors.append(name+': '+str(exc))
    for name,expected in [
        ('PDK Development/Front-side Version/MODEL/3nm_GAA_FSPR_RVT.sp',manifest['published_model_sha256']),
        ('PnR-Synopsys/Front-side Version/ITF/3nm_GAA_FSPR.nxtgrd',manifest['grid_sha256'])]:
        try:
            if digest(repository_path(root,name))!=expected:errors.append(name+': frozen input mismatch')
        except (OSError,ValueError) as exc:errors.append(name+': '+str(exc))
    return dict(passed=not errors,verified_artifacts=len(manifest['files']),errors=errors,
        scope='Artifact identity only; this command does not rerun DRC/LVS/PEX or approve scientific results.',
        electrical_final_approved=manifest.get('electrical_final_approved',False))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repository-root',type=Path,default=Path(__file__).resolve().parents[3])
    parser.add_argument('--manifest',type=Path,default=Path(__file__).with_name('PACKAGE_FILES.json'))
    args=parser.parse_args()
    result=verify(args.repository_root,json.loads(args.manifest.read_text()))
    print(json.dumps(result,indent=2))
    if not result['passed']:raise SystemExit(1)

if __name__=='__main__':main()
