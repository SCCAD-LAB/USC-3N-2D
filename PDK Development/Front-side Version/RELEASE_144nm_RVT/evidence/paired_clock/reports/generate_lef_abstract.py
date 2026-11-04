"""Generate routing pin access and obstructions from native-qualified GDS.

Preserve names, directions, sites, symmetry and layer100 cell dimensions. Expose
only actual routing material connected to each original pin label. Block other
routing material, retaining conservative original obstructions outside pins.
This supplements native LVS; it does not infer nets through transistor channels.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import check_lef_pin_coverage as audit
from repair_lef_pin_rectangles import rectangles, number

ROOT = Path(__file__).resolve().parents[1]
gdstk = audit.gdstk
REVERSE_LAYERS = {v: k for k, v in audit.LAYERS.items()}

def parse_rectangles(text):
    rows = {}
    layer = None
    pattern = r'\bLAYER\s+(\w+)\s*;|\bRECT\s+([-+.\deE]+)\s+([-+.\deE]+)\s+([-+.\deE]+)\s+([-+.\deE]+)\s*;'
    for match in re.finditer(pattern, text):
        if match.group(1):
            layer = match.group(1)
        else:
            v = list(map(float, match.groups()[1:]))
            rows.setdefault(layer, []).append(gdstk.rectangle(v[:2], v[2:]))
    assert 'POLYGON' not in text, 'Explicit polygon parsing is required before changing this source'
    return rows

def geometry_text(geometry, precision, indent):
    result = ''
    count = 0
    for layer in sorted(geometry, key=lambda x: audit.LAYERS.get(x, 999)):
        boxes = rectangles(geometry[layer], precision)
        if not boxes:
            continue
        result += ' '*indent + f'LAYER {layer} ;\n'
        for box in boxes:
            result += ' '*(indent+2) + 'RECT ' + ' '.join(number(v) for v in box) + ' ;\n'
            count += 1
    return result, count

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, default=ROOT/'reports/INTERIM_144nm_complete_abstract.lef')
    parser.add_argument('--require-all', action='store_true')
    parser.add_argument('--candidate-overrides', type=Path,
                        help='Explicit native-qualified candidate GDS/gate hashes; canonical inputs stay unchanged')
    args = parser.parse_args()
    overrides = json.loads(args.candidate_overrides.read_text()) if args.candidate_overrides else {}
    assert set(overrides) <= {'DFFHx1'}, 'Only the authorized clock-routing candidate may override inputs'
    source = ROOT/'sources/github_FSPR.lef'
    text = source.read_text()
    definitions = audit.lef_cells(source)
    generated = {}
    receipts = []
    for path in sorted((ROOT/'physical/cells').glob('*/LATEST.json')):
        row = json.loads(path.read_text())
        if not row.get('qualified'):
            continue
        name = row['cell']
        gds = ROOT/'physical/cells'/name/f"iter{row['iteration']:03d}"/'inputs/cell.gds'
        native_gate = path
        expected_gds_sha = row['gds_sha256']
        if name in overrides:
            override = overrides[name]
            gds = Path(override['gds'])
            native_gate = Path(override['native_gate'])
            assert hashlib.sha256(native_gate.read_bytes()).hexdigest() == override['native_gate_sha256']
            gate = json.loads(native_gate.read_text())
            assert gate['passed'] and gate['drc']['passed'] and gate['lvs']['passed']
            assert gate['drc']['violations'] == 0 and gate['drc']['rules_not_executed'] == ['0']
            expected_gds_sha = override['gds_sha256']
            assert expected_gds_sha == gate['gds_sha256']
        assert hashlib.sha256(gds.read_bytes()).hexdigest() == expected_gds_sha, name
        library = gdstk.read_gds(str(gds))
        cell = next(c for c in library.cells if c.name == name)
        scale = library.unit/1e-6
        precision = library.precision/1e-6
        nodes, polygons, find = audit.routing_network(cell, scale, precision)
        roots_by_pin = {}
        primary_roots = {}
        ports = {}
        for pin in definitions[name]:
            labels, roots = audit.pin_roots(cell, pin, scale, nodes, polygons, find)
            assert labels and roots, (name, pin, 'no routing conductor at label')
            for root in roots:
                assert root not in primary_roots or primary_roots[root] == pin, (name, pin, primary_roots.get(root), 'two named pins share routing metal')
                primary_roots[root] = pin
            roots_by_pin[pin] = roots
            ports[pin] = {}
            for layer, indices in polygons.items():
                shapes = [nodes[i][1] for i in indices if find(i) in roots]
                if shapes:
                    ports[pin][REVERSE_LAYERS[layer]] = shapes
        match = re.search(r'^MACRO\s+'+re.escape(name)+r'\s*\n(.*?)^END\s+'+re.escape(name)+r'\s*$', text, re.M|re.S)
        body = match.group(1)
        obs_match = re.search(r'^\s*OBS\s*\n(.*?)^\s*END\s*$', body, re.M|re.S)
        old_obs = parse_rectangles(obs_match.group(1)) if obs_match else {}
        obs = {}
        routing_unrepresented = {}
        for layer, indices in polygons.items():
            layer_name = REVERSE_LAYERS[layer]
            actual = [nodes[i][1] for i in indices]
            pin_shapes = [p for geometries in ports.values() for p in geometries.get(layer_name, [])]
            material = actual + old_obs.get(layer_name, [])
            remainder = gdstk.boolean(material, pin_shapes, 'not', precision=precision) if material else []
            if remainder:
                obs[layer_name] = remainder
            missing = gdstk.boolean(actual, pin_shapes+remainder, 'not', precision=precision) if actual else []
            routing_unrepresented[layer_name] = sum(p.area() for p in missing)
            assert routing_unrepresented[layer_name] <= 1e-12, (name, layer_name)
        for layer_name, shapes in old_obs.items():
            if layer_name not in audit.LAYERS:
                obs[layer_name] = shapes
        def replace_pin(pin_match):
            pin = pin_match.group(1)
            original = pin_match.group()
            matches = list(re.finditer(r'(^\s*PORT\s*\n)(.*?)(^\s*END\s*$)', original, re.M|re.S))
            assert len(matches) == 1, (name, pin, 'expected one original PORT')
            port = matches[0]
            geometry, _ = geometry_text(ports[pin], precision, 6)
            return original[:port.start(2)] + geometry + original[port.end(2):]
        changed = re.sub(r'^\s*PIN\s+(\S+)\s*\n.*?^\s*END\s+\1\s*$', replace_pin, body, flags=re.M|re.S)
        obs_text, _ = geometry_text(obs, precision, 4)
        obs_block = '  OBS\n' + obs_text + '  END\n' if obs_text else ''
        if obs_match:
            changed = re.sub(r'^\s*OBS\s*\n.*?^\s*END\s*$', lambda _: '\n'+obs_block, changed, flags=re.M|re.S)
        else:
            changed = changed.rstrip()+'\n'+obs_block
        def strip_geometry(value):
            value = re.sub(r'^\s*PORT\s*\n.*?^\s*END\s*$', ' PORT_GEOMETRY ', value, flags=re.M|re.S)
            value = re.sub(r'^\s*OBS\s*\n.*?^\s*END\s*$', '', value, flags=re.M|re.S)
            return re.sub(r'\s+', '', value)
        assert strip_geometry(changed) == strip_geometry(body), (name, 'nongeometry LEF metadata changed')
        generated[name] = changed
        receipts.append({'cell': name, 'gds': str(gds.resolve()), 'gds_sha256': expected_gds_sha,
                         'native_gate': str(native_gate.resolve()), 'native_gate_sha256': hashlib.sha256(native_gate.read_bytes()).hexdigest(),
                         'routing_unrepresented_area_um2': routing_unrepresented,
                         'port_layers': {p: sorted(g) for p, g in ports.items()}})
    if args.require_all:
        assert len(generated) == 57, 'Final abstract requires all57 native-qualified cells'
    def replace_cell(match):
        if match.group(1) in generated:
            return match.group().replace(match.group(2), generated[match.group(1)], 1)
        return match.group()
    result = re.sub(r'^MACRO\s+(\S+)\s*\n(.*?)^END\s+\1\s*$', replace_cell, text, flags=re.M|re.S)
    args.output.write_text(result)
    checks = []
    new_defs = audit.lef_cells(args.output)
    for receipt in receipts:
        name = receipt['cell']
        assert set(new_defs[name]) == set(definitions[name]), name
        check = audit.check(Path(receipt['gds']), args.output, name)
        assert check['cells_passed'] == 1, name
        checks.append({'cell': name, 'all_pin_regions_connected_and_covered': True})
    report = {'scope': __doc__, 'complete': len(generated) == 57, 'cells_verified': len(generated), 'total': 57,
              'candidate_overrides': overrides,
              'canonical_inputs_modified': False,
              'source_lef': str(source.resolve()), 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'output_lef': str(args.output.resolve()), 'output_sha256': hashlib.sha256(args.output.read_bytes()).hexdigest(),
              'source_dimensions_names_directions_sites_symmetry_preserved': True,
              'all_physical_routing_material_represented_by_pin_or_obstruction': True,
              'rows': receipts, 'checks': checks}
    args.output.with_suffix('.json').write_text(json.dumps(report, indent=2)+'\n')
    print('Complete:', report['complete'], 'verified cells:', len(generated), 'bytes:', len(result))

if __name__ == '__main__':
    main()
