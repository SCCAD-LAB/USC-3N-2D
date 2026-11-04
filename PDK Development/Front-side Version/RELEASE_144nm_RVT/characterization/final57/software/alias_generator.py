from pathlib import Path
import re,json,argparse
MODEL=Path(__file__).resolve().parents[1]/"models/github_FSPR_RVT.sp"
WIDTHS=[15,19,20,30]
def aliases():
    source=MODEL.read_text();spice=[];spectre=[];proof=[]
    for name,kind,body in re.findall(r'\.MODEL\s+(\w+)\s+(NMOS|PMOS)\s*\((.*?)\)',source,re.I|re.S):
        pairs=re.findall(r'(\w+)\s*=\s*([^\s)]+)',body)
        for width in WIDTHS:
            alias=name+f'_WGAA_{width}nm';hp=[];sp=[]
            changed=[]
            for key,value in pairs:
                actual=format(width*1e-9,'.12g') if key.lower()=='wgaa' else value
                hp.append(key+'='+actual)
                if actual!=value and key.lower()=='wgaa':changed.append(dict(parameter='wgaa',source=value,target=actual))
                if key.lower() in ['level','nf']:continue
                sp.append(key+'='+('111.21' if key.lower()=='version' else actual))
            spice.append('.MODEL '+alias+' '+kind+' ( '+' '.join(hp)+' )')
            spectre.append('model '+alias+' bsimcmg type='+('n' if kind.upper()=='NMOS' else 'p')+' '+' '.join(sp))
            proof.append(dict(alias=alias,source=name,physical_wgaa_nm=width,changed_geometry_parameters=changed,
                all_other_source_coefficient_pairs_unchanged=True,source_parameters=pairs,
                syntax_adapter='level72→bsimcmg;111.2.1→111.21;NFdefault1→instanceNF1only'))
    return '* Candidate WGAA-only geometry aliases\n.LIB TT\n'+'\n'.join(spice)+'\n.ENDL TT\n','* Candidate WGAA-only geometry aliases\nsimulator lang=spectre\n'+'\n'.join(spectre)+'\nsimulator lang=spice\n',proof

if __name__=="__main__":
    a=argparse.ArgumentParser();a.add_argument("--output",type=Path,required=True);q=a.parse_args();q.output.mkdir(parents=True,exist_ok=True);h,s,p=aliases();(q.output/"geometry_aliases.sp").write_text(h);(q.output/"geometry_aliases.scs").write_text(s);(q.output/"coefficient_proof.json").write_text(json.dumps(p,indent=2)+"\n")
