"""Match native LVS devices to actual gate/fin/active GDS intersections.

This is a geometry correspondence check, not a replacement for native LVS.
"""
from pathlib import Path
import argparse,hashlib,json,re,sys,os,time
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'characterization'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(p):return json.loads(Path(p).read_text())
def save(p,d):
    p=Path(p);p.parent.mkdir(parents=True,exist_ok=True);q=p.with_name(p.name+f'.{os.getpid()}.{time.time_ns()}.tmp');q.write_text(json.dumps(d,indent=2)+'\n');q.replace(p)
try:import gdstk
except ImportError:
    sys.path.insert(0,str(ROOT.parent/'ten_parameter_c0_20261103/deps'))
    import gdstk

def map_geometry(gds,dimensions,cell):
    lib=gdstk.read_gds(str(gds));cells={c.name:c for c in lib.cells};top=cells[cell]
    if top.references:raise ValueError('Geometry mapper requires flattened final per-cell GDS')
    factor=lib.unit*1e9;precision_nm=lib.precision*1e9
    layers={n:[p for p in top.polygons if p.layer==n and p.datatype==0] for n in [2,7,10,11,12,13]}
    if any(not layers[n] for n in [2,7,11,12,13]):raise ValueError('Required fin/gate/active/select layer absent')
    gate=gdstk.boolean(layers[7],layers[10],'not',precision=lib.precision/lib.unit)
    physical=[]
    for type_,selector in [('nmos_rvt',12),('pmos_rvt',13)]:
        shapes=gate
        for layer in [selector,2,11]:shapes=gdstk.boolean(shapes,layers[layer],'and',precision=lib.precision/lib.unit)
        for i,shape in enumerate(shapes):
            box=shape.bounding_box();length=(box[1][0]-box[0][0])*factor;width=(box[1][1]-box[0][1])*factor
            rect=abs(shape.area()*factor*factor-length*width)<=max(1e-6,precision_nm**2/4)
            physical.append(dict(index=len(physical),type=type_,L_nm=round(length,6),W_nm=round(width,6),rectangle=rect,box_nm=[[round(v*factor,6) for v in point] for point in box],points_nm=[[round(v*factor,6) for v in point] for point in shape.points]))
    source=load(dimensions);native=source['rows'];rows=[];used=set();issues=[]
    for device in native:
        x=device['x_nm'];y=device['y_nm'];matches=[]
        for physical_row in physical:
            box=physical_row['box_nm']
            if physical_row['type']==device['type'] and box[0][0]-precision_nm/2<=x<=box[1][0]+precision_nm/2 and box[0][1]-precision_nm/2<=y<=box[1][1]+precision_nm/2:
                matches.append(physical_row)
        ok=len(matches)==1
        if ok:
            shape=matches[0];ok=shape['rectangle'] and abs(shape['L_nm']-device['L_nm'])<=precision_nm/2 and abs(shape['W_nm']-device['W_nm'])<=precision_nm/2 and shape['index'] not in used
            if ok:used.add(shape['index'])
        row=dict(device=device,physical_gate=matches[0] if len(matches)==1 else None,candidates=len(matches),matched=ok)
        if ok:
            row['proposed_model_WGAA_nm']=matches[0]['W_nm'];row['parallel_or_merged_ambiguous']=matches[0]['W_nm']>30+precision_nm/2
            if row['parallel_or_merged_ambiguous']:ok=False;row['matched']=False
        if not ok:issues.append(device['device'])
        rows.append(row)
    leftovers=sorted(set(range(len(physical)))-used)
    return dict(passed=bool(native) and not issues and not leftovers,cell=cell,gds=str(Path(gds).resolve()),gds_sha256=sha(gds),native_dimensions=str(Path(dimensions).resolve()),native_dimensions_sha256=sha(dimensions),gds_precision_nm=precision_nm,
        expression='(Gate minus GCut) intersect N/Pselect intersect Fin intersect Active; identical final channel geometry to production LVS ngate/pgate',
        coordinate_policy='Native extraction gate point must lie inside exactly one corresponding typed channel rectangle; native L/W must match its actual GDS extents withinhalfDBU. No classicW-onlycopy.',
        model_mapping_proposal='WGAA=verified physical channel width. NGAA3,TGAA5nm and all calibrated coefficients unchanged. Hold ambiguous mergedW>30, M>1, nonrectangles, overlaps ormissingcorrespondence.',
        native_devices=len(native),physical_channels=len(physical),widths_nm=sorted(set(r['W_nm'] for r in physical)),unmatched_native_devices=issues,unmatched_physical_channels=leftovers,rows=rows)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--cell');args=parser.parse_args()
    base=ROOT/'physical/cells';results=[]
    for cell in ([args.cell] if args.cell else sorted(p.name for p in base.iterdir() if p.is_dir())):
        latest=base/cell/'LATEST.json'
        if not latest.exists():continue
        gate=load(latest);iteration=gate['iteration'];source=base/cell/f'iter{iteration:03d}'
        gds=source/'inputs/cell.gds';dimensions=source/'lvs/ACTUAL_DEVICE_DIMENSIONS.json'
        if not gds.exists() or not dimensions.exists():continue
        result=map_geometry(gds,dimensions,cell)
        if result['gds_sha256']!=gate['gds_sha256']:raise ValueError('Native GDS receipt differsfromcandidategeometry')
        target=OUT/'geometry_mapping'/cell/result['gds_sha256'][:16]/'MAPPING.json';save(target,result);results.append(dict(cell=cell,passed=result['passed'],widths_nm=result['widths_nm'],native_devices=result['native_devices'],physical_channels=result['physical_channels'],path=str(target),sha256=sha(target),unmatched_native=result['unmatched_native_devices'],unmatched_physical=result['unmatched_physical_channels']))
    save(OUT/'geometry_mapping/CANDIDATE_MANIFEST.json',dict(complete=len(results)==57,rows=results))
    print(json.dumps(results,indent=2))
