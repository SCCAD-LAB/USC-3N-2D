"""Static matched144nm deck/map identity check. No native verification job."""
from pathlib import Path
import argparse,hashlib,json,re

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path)
    args=parser.parse_args()
    root=args.repo.resolve() if args.repo else Path(__file__).resolve().parents[3]
    release=root/'PDK Development/Front-side Version/RELEASE_144nm_RVT'
    rules=release/'physical/rules';matched=rules/'matched_144nm';checks=[]
    def check(name,passed,**extra):checks.append(dict(check=name,passed=bool(passed),**extra))
    for relative in ['DRC/sccad3nm_main.drc.rs','LVS/ICV_3nm.rs','LVS/ICV_3nm_FSPR_PEX.rs']:
        text=(matched/relative).read_text()
        for layer,number in [('V1',21),('M6',60),('MBPR',15)]:
            values=re.findall(r'\b'+('a' if relative.startswith('DRC') else '')+layer+r'\s*=\s*assign\s*\(\s*\{\s*\{\s*(\d+)',text)
            check('selected_native_GDS_layer',values==[str(number)],deck=relative,layer=layer,expected=number)
        if relative.startswith('LVS'):
            check('fin_present_layer2',bool(re.search(r'^\s*fin\s*=\s*assign\s*\(\s*\{\s*\{\s*2\b',text,re.M)),deck=relative)
    for path in sorted((matched/'DRC/Include').glob('*.rs')):
        check('numerical_DRC_include_unchanged',path.read_bytes()==(rules/'github/DRC/Include'/path.name).read_bytes(),file=path.name)
    mapping=(matched/'StarRC/starrcxt.mapping').read_text()
    check('native_StarRC_layer_names',bool(re.search(r'^m6\s+M6\s*$',mapping,re.M)) and bool(re.search(r'^v1\s+V1\s*$',mapping,re.M)))
    check('empty_MBPR_binding_removed_explicitly','EMPTY_FSPR_MBPR' in mapping and not re.search(r'^mbpr\s+MBPR\s*$',mapping,re.M))
    grid=root/'PnR-Synopsys/Front-side Version/ITF/3nm_GAA_FSPR.nxtgrd'
    check('frozen_grid',hashlib.sha256(grid.read_bytes()).hexdigest()=='425ddaa74bdb6fd44752c73175404742927ab8312060b701783210731b92e805')
    selected=(root/'PDK Development/Front-side Version/selected_collateral.tcl').read_text()
    check('explicit_144nm_GDS_default','3nm_GAA_FSPR_144nm.gds' in selected and not re.search(r'\bglob\b[^\n]*gds',selected,re.I))
    check('matched_verification_decks_selected',all(name in selected for name in ['fspr_drc_deck','fspr_lvs_deck','fspr_pex_deck','fspr_starrc_map','fspr_extraction_grid']))
    result=dict(passed=all(c['passed'] for c in checks),native_jobs=0,scope='Static input identity and layer-name/number checks only. Native LVS is topology-only; dimensions/body/functional/electrical approval are separate.',checks=checks)
    print(json.dumps(result,indent=2))
    if not result['passed']:raise SystemExit(1)

if __name__=='__main__':main()
