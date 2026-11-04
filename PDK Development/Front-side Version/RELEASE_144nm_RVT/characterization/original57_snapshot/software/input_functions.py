def spectre_syntax_adapter():
    """Change syntax only. Keep delivered model, including GEOMOD=5/111.2.1.

    Spectre spells version111.2.1 as111.21. NF is an instance parameter;
    its model default1 is explicitly applied on every MOS lacking NF.
    """
    original=MODEL.read_text();lines=[];proof=[]
    for name,kind,body in re.findall(r'\.MODEL\s+(\w+)\s+(NMOS|PMOS)\s*\((.*?)\)',original,re.I|re.S):
        pairs=re.findall(r'(\w+)\s*=\s*([^\s)]+)',body)
        values={k.lower():v for k,v in pairs}
        assert values['level']=='72' and values['version']=='111.2.1' and values['geomod']=='5'
        assert float(values['nf'])==1
        native=[]
        for key,value in pairs:
            if key.lower() in ['level','nf']:continue
            if key.lower()=='version':value='111.21'
            native.append(key+'='+value)
        lines.append('model '+name+' bsimcmg type='+('n' if kind.upper()=='NMOS' else 'p')+' '+' '.join(native))
        proof.append(dict(model=name,source_parameters=pairs,
            transformations=dict(level='72→nativebsimcmg',version='111.2.1→111.21',nf='modeldefault1→explicitinstanceNF1'),
            all_other_coefficients_retained=True))
    assert len(lines)==2
    return '* Syntax-only adapter of pinned published card; no parameter fitting\nsimulator lang=spectre\n'+'\n'.join(lines)+'\nsimulator lang=spice\n',proof

def normalize_dspf(path,backend,physical_binding=None):
    lines=[];changes=[];count=0
    bound={r['dspf_device']:r for r in physical_binding['rows']} if physical_binding else {}
    for raw in Path(path).read_text().splitlines():
        line=raw
        if re.match(r'^\s*[mM]\S+\s',line):
            values=line.split()
            index=next((i for i,v in enumerate(values) if v.lower() in ['nmos_rvt','pmos_rvt','nmos_lvt','pmos_lvt']),None)
            if index is None:raise ValueError('Unrecognized PEX MOS model: '+line)
            n=values[index].lower().startswith('n')
            if index!=5:raise ValueError('PEX MOS needs independently justified explicit bulk terminal: '+line)
            old=values[index]
            mapped=bound.get(values[0])
            if physical_binding and mapped is None:raise ValueError('Unmapped fresh DSPF MOS')
            values[index]=mapped['model_alias'] if mapped else ('NMOS_LVT' if n else 'PMOS_LVT')
            dimensions={key.lower():value for key,value in re.findall(r'\b(l|w|nfin|nf|m)\s*=\s*([^\s$]+)',raw,re.I)}
            if backend=='spectre_native' and not re.search(r'\bnf\s*=',line,re.I):
                # Before the first dollar comment; all coordinate comments retained.
                comment=next((i for i,v in enumerate(values) if v.startswith('$')),len(values))
                values.insert(comment,'NF=1')
            line=' '.join(values);count+=1
            changes.append(dict(instance=values[0],old_model=old,new_model=values[index],preserved_instance_dimensions=dimensions,
                published_base_model_wgaa_m=30e-9,actual_physical_model_wgaa_m=mapped['physical_WGAA_nm']*1e-9 if mapped else 30e-9,published_model_tgaa_m=5e-9,published_model_ngaa=3,
                classic_w_not_model_channel_width=True,
                explicit_nf1=backend=='spectre_native' and not re.search(r'\bnf\s*=',raw,re.I)))
        lines.append(line)
    if not count:raise ValueError('No MOS devices in final native DSPF')
    return '\n'.join(lines)+'\n',dict(mos_devices=count,changes=changes,
        passive_records_unchanged=[r for r in Path(path).read_text().splitlines() if re.match(r'^\s*[rRcC]\S+\s',r)]==[r for r in lines if re.match(r'^\s*[rRcC]\S+\s',r)])
