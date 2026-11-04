"""Require final GDS↔native LVS↔fresh DSPF device correspondence."""
from pathlib import Path
import re
from map_device_geometry import map_geometry,sha,load

NUMBER=r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?'

def scalar(value):
    m=re.fullmatch('('+NUMBER+r')([numfp]?)',value,re.I)
    if not m:raise ValueError('Unsupported explicit instance dimension '+value)
    return float(m[1])*{'':1,'n':1e-9,'u':1e-6,'m':1e-3,'f':1e-15,'p':1e-12}[m[2].lower()]

def identifier(name):
    # StarRC emits MM1 for ICV M1; preserve every other character.
    return re.sub(r'^m+','',name,flags=re.I).lower()

def bind_final_devices(row):
    source_binding=Path(row['device_geometry_binding'])
    if sha(source_binding)!=row['device_geometry_binding_sha256']:raise ValueError('Physical device binding receipt changed')
    provenance=load(source_binding)
    if not provenance.get('passed') or provenance.get('source_GDS_sha256')!=row['gds_sha256'] or provenance.get('parallel_merge_detected'):
        raise ValueError('Physical device binding gate doesnotmatch final GDS')
    dimensions=Path(provenance['native_dimension_report'])
    if sha(dimensions)!=provenance['native_dimension_report_sha256']:raise ValueError('Native device dimension receipt changed')
    if not dimensions.exists():raise ValueError('Missing native same-GDS L/W/coordinate receipt')
    geometry=map_geometry(row['gds'],dimensions,row['cell'])
    if not geometry['passed'] or geometry['gds_sha256']!=row['gds_sha256']:raise ValueError('Final GDS/native-device geometry mapping failed')
    text=Path(row['dspf']).read_text();gate_points={}
    for line in text.splitlines():
        if not line.startswith('*|I'):continue
        m=re.match(r'^\*\|I\s+\(\s*\S+\s+(\S+)\s+(\S+)\s+\S+\s+\S+\s+('+NUMBER+r')\s+('+NUMBER+r')\s*\)',line)
        if m and m[2].upper() in ['G','GATE']:
            key=identifier(m[1]);point=[float(m[3])*1000,float(m[4])*1000]
            if key in gate_points and gate_points[key]!=point:raise ValueError('Multiple DSPF gate coordinates for one MOS')
            gate_points[key]=point
    native={identifier(r['device']['device']):r for r in geometry['rows']}
    if len(native)!=len(geometry['rows']):raise ValueError('Ambiguous native MOS identifiers')
    rows=[];used=set();precision=geometry['gds_precision_nm']/2
    for line in text.splitlines():
        if not re.match(r'^\s*[mM]\S+\s',line):continue
        tokens=line.split();name=tokens[0];key=identifier(name)
        index=next((i for i,t in enumerate(tokens) if t.lower() in ['nmos_rvt','pmos_rvt','nmos_lvt','pmos_lvt']),None)
        if index!=5 or key not in native or key in used:raise ValueError('DSPF/native MOS identity or body-format mismatch: '+name)
        ref=native[key];device=ref['device'];type_='nmos_rvt' if tokens[index].lower().startswith('n') else 'pmos_rvt'
        props={k.lower():v for k,v in re.findall(r'\b(l|w|m|nf|nfin)\s*=\s*([^\s$]+)',line,re.I)}
        if 'l' not in props or 'w' not in props:raise ValueError('Missing DSPF device dimensions')
        length=scalar(props['l'])*1e9;width=scalar(props['w'])*1e9
        if type_!=device['type'] or abs(length-device['L_nm'])>precision or abs(width-device['W_nm'])>precision:raise ValueError('Fresh DSPF model/L/W differs from physical channel: '+name)
        for prop in ['m','nf','nfin']:
            if prop in props and abs(scalar(props[prop])-1)>1e-12:raise ValueError('Physical multiplicity needs explicit merged-device proof: '+name+'/'+prop)
        if key not in gate_points:raise ValueError('Missing independent DSPF gate coordinate: '+name)
        point=gate_points[key]
        if abs(point[0]-device['x_nm'])>precision or abs(point[1]-device['y_nm'])>precision:raise ValueError('Fresh DSPF coordinate differsfrom native LVS: '+name)
        physical=ref['physical_gate'];wg=physical['W_nm']
        if wg<=0 or wg>30+precision:raise ValueError('Ambiguous physical WGAA/finger merge')
        alias=('NMOS_LVT' if type_.startswith('n') else 'PMOS_LVT')+(f'_WGAA_{int(round(wg))}nm' if abs(wg-30)>precision else '')
        if abs(wg-round(wg))>1e-6:raise ValueError('Unqualified WGAA not in validated whole-nm alias set')
        rows.append(dict(dspf_device=name,native_device=device['device'],type=type_,L_nm=length,classic_W_nm=width,physical_WGAA_nm=wg,model_alias=alias,nfin=1,nf=1,m=1,dspf_gate_coordinate_nm=point,native_gate_coordinate_nm=[device['x_nm'],device['y_nm']],gds_channel=physical))
        used.add(key)
    if len(rows)!=len(native) or set(native)!=used:raise ValueError('DSPF/native/physical MOS coverage differs')
    return dict(passed=True,cell=row['cell'],gds_sha256=row['gds_sha256'],dspf_sha256=row['dspf_sha256'],native_dimensions_sha256=sha(dimensions),physical_device_binding=str(source_binding),physical_device_binding_sha256=sha(source_binding),geometry_mapping=geometry,
        DSPF_coordinates_unit='micrometersconvertedtoNM; exact native-LVS gate-coordinate correspondence verified',
        coefficient_policy='WGAA geometry only may differ; NGAA3,TGAA5nm and all fitted coefficients remain as published; classicW preserved but notmistakenfor modelinput',rows=rows)
