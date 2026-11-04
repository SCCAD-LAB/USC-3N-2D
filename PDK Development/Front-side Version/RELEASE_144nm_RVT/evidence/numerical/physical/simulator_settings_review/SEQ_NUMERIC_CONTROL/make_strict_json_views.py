from pathlib import Path
import hashlib,json,math
ROOT=Path(__file__).resolve().parent

def safe(value):
 if isinstance(value,float) and not math.isfinite(value):return None
 if isinstance(value,list):return [safe(v) for v in value]
 if isinstance(value,dict):
  q={k:safe(v) for k,v in value.items()}
  if 'cq_ps' in value and isinstance(value['cq_ps'],float) and not math.isfinite(value['cq_ps']):q['missing_crossing_reason']='No valid CQ crossing reported: capture/degradation FAIL, never zero.'
  return q
 return value
if __name__=='__main__':
 paths=[ROOT/n for n in ['POLICY.json','BASELINES.json','BOUNDARIES.json','RESULT.json'] if (ROOT/n).exists()]+list((ROOT/'curves').glob('*.json'));files=[]
 for source in paths:
  data=source.read_bytes();dest=ROOT/'STRICT_JSON_VIEWS'/source.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);record=dict(original_source=str(source),original_sha256=hashlib.sha256(data).hexdigest(),derivation='Original diagnostics preserved. Map nonfinite values to null with explicit failure reason.',data=safe(json.loads(data)));dest.write_text(json.dumps(record,indent=2,allow_nan=False)+'\n');files.append(dict(path=str(dest.relative_to(ROOT/'STRICT_JSON_VIEWS')),sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),source_sha256=record['original_sha256']))
 (ROOT/'STRICT_JSON_VIEWS/MANIFEST.json').write_text(json.dumps(dict(files=files),indent=2,allow_nan=False)+'\n');print(len(files))
