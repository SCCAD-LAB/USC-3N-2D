#!/usr/bin/env python3
"""Remove the proven bottom-rail gate contact, leaving every channel unchanged."""
from pathlib import Path
import json,os,socket,time,traceback
import numpy as np
import scan as s
ROOT=s.ROOT
def main():
 owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().split()[21],epoch=time.time());s.p.save(ROOT/'BUF_REPAIR_LAUNCH.json',owner)
 try:
  name='BUFx3';lib=s.p.gdstk.read_gds(str(s.WORK/name/'iter001/inputs/cell.gds'));c=lib.cells[0];matches=[]
  for p in c.polygons:
   b=np.array(p.bounding_box())
   if p.layer==10 and p.datatype==0 and abs(b[0,1]+.006)<1e-8 and abs(b[1,1]-.006)<1e-8 and b[1,0]-b[0,0]>.2:matches.append((p,b))
  if len(matches)!=1:raise RuntimeError('Expected one bottomGCutrailingroundtouch')
  old,b=matches[0];new=s.p.gdstk.rectangle((b[0,0],-.010),(b[1,0],.010),layer=10);c.remove(old);c.add(new)
  path=s.WORK/name/'prepared_iter002_bottom_cut.gds';lib.write_gds(str(path));inputs=s.stage_iteration(name,2,1,path)
  policy_path=ROOT/'DEVICE_LAYER_CHANGE_POLICY.json';policy=json.loads(policy_path.read_text()) if policy_path.exists() else {}
  policy[name]=dict(allowed_modified_device_layers=[10],channel_geometry='unchanged',reason='GCutbottom originallyends6nmexactlytouchinggroundLIGtop6nm. Extendonlyrailcutto10nmclearance; NMOSchannelstarts21nm, soallGAAchannels/L/W/count/coordsunchanged. Existinguserrecursivephysicalrepairauthorization; noelectricalpointchange.',site_boundary_layer100_unchanged=True,pin_labels_unchanged=True,old_GCut_bbox_um=b.tolist(),new_GCut_bbox_um=np.array(new.bounding_box()).tolist())
  s.p.save(policy_path,policy);s.p.save(inputs/'GEOMETRY_CHANGES.json',policy[name]);z=s.one(name,2);s.p.save(ROOT/'BUF_REPAIR_STATUS.json',dict(stage='native_complete',owner=owner,result=z,epoch=time.time()))
 except Exception:s.p.save(ROOT/'BUF_REPAIR_STATUS.json',dict(stage='failed_preserve',owner=owner,traceback=traceback.format_exc(),epoch=time.time()));raise
if __name__=='__main__':main()
