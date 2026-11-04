#!/usr/bin/env python3
"""Actual one-CPP source-ACT diagnostic; independent topology remains frozen."""
from pathlib import Path
import json,os,socket,time,traceback
import numpy as np
import scan as s
ROOT=s.ROOT
def main():
 owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().split()[21],epoch=time.time());s.p.save(ROOT/'DFF_REPAIR_LAUNCH.json',owner)
 try:
  name='DFFHx1';lib=s.p.gdstk.read_gds(str(s.WORK/name/'iter001/inputs/cell.gds'));c=lib.cells[0];matches=[]
  for p in c.polygons:
   if p.layer==11 and p.datatype==0 and np.max(np.abs(np.array(p.bounding_box())-np.array([[.515,.0265],[.577,.0455]])))<1e-8:matches.append(p)
  if len(matches)!=1:raise RuntimeError('Expectedunique19nmNMOSACT')
  matches[0].translate(.042,0);path=s.WORK/name/'probe_one_CPP_ACT.gds';lib.write_gds(str(path));inputs=s.stage_iteration(name,2,1,path)
  s.p.save(inputs/'GEOMETRY_CHANGES.json',dict(diagnostic=True,change='One19nmNMOSACTtranslated42nmright; allotherpolygonsandindependentreferenceunchanged',source_gate_coordinate_nm=[546,36],candidate_gate_coordinate_nm=[588,36],L_nm=12,W_nm=19,published_qualification=False))
  z=s.one(name,2);s.p.save(ROOT/'DFF_REPAIR_STATUS.json',dict(stage='ACT_only_native_diagnostic_complete',owner=owner,result=z,epoch=time.time()))
 except Exception:s.p.save(ROOT/'DFF_REPAIR_STATUS.json',dict(stage='failed_preserve',owner=owner,traceback=traceback.format_exc(),epoch=time.time()));raise
if __name__=='__main__':main()
