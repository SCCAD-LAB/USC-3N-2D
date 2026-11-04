#!/usr/bin/env python3
"""Fill measured same-net M1 notches and trim uncontacted dangling metal ends."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor,as_completed
import json,math,os,re,socket,time,traceback
import numpy as np
import scan as s
import repair_common as common
ROOT=s.ROOT;WORK=s.WORK
NAMES=['AOI222x1','DFFHQNx1','DHLx1','NAND2x2','NAND3x2','NOR2x2','NOR3x2','OAI222x1']
EPS=.00025
def inside(point,poly):return bool(s.p.gdstk.inside([tuple(point)],[poly])[0])
def intersection_area(a,b):return sum(p.area() for p in s.p.gdstk.boolean(a,b,'and',precision=EPS))
def pair_for(rule,marker,polys):
 x0,y0,x1,y1,d=marker
 if rule=='M1.3':points=[(x0-EPS/2,(y0+y1)/2),(x1+EPS/2,(y0+y1)/2)]
 elif rule=='M1.4':points=[((x0+x1)/2,y0-EPS/2),((x0+x1)/2,y1+EPS/2)]
 else:
  hits=[]
  for point in [(x0,y0),(x1,y0),(x0,y1),(x1,y1)]:
   for i,p in enumerate(polys):
    if np.any(np.all(np.abs(p.points-np.array(point))<.00016,axis=1)):hits.append((i,point))
  pairs=[(a,b) for i,a in enumerate(hits) for b in hits[i+1:] if abs(math.dist(a[1],b[1])-d)<.00016]
  if not pairs:return None
  return pairs[0][0][0],pairs[0][1][0]
 ids=[]
 for point in points:
  found=[i for i,p in enumerate(polys) if inside(point,p)]
  if len(found)!=1:return None
  ids.append(found[0])
 return tuple(ids)

def safe_cut(poly,cut,via_protection,labels):
 for protected in via_protection:
  if intersection_area([poly],[protected])>1e-12 and intersection_area([poly],[cut,protected])>0:
   # Tripleintersection, rather than cutORprotected.
   shared=s.p.gdstk.boolean([poly],[protected],'and',precision=EPS)
   if intersection_area(shared,[cut])>1e-12:return None
 result=s.p.gdstk.boolean([poly],[cut],'not',precision=EPS,layer=19)
 if len(result)!=1 or result[0].area()<EPS**2:return None
 for label in labels:
  if inside(label,poly) and not inside(label,result[0]):return None
 return result[0]

def candidate(cell):
 lib=s.p.gdstk.read_gds(str(WORK/cell/'iter001/inputs/cell.gds'));c=lib.cells[0]
 source=[p for p in c.polygons if p.layer==19 and p.datatype==0];polys=s.p.gdstk.boolean(source,[],'or',precision=EPS,layer=19);changes=[]
 text=(ROOT/'cells'/cell/'iter001/drc'/(cell+'.LAYOUT_ERRORS')).read_text()
 via_protection=[]
 for p in c.polygons:
  if p.layer in [18,21] and p.datatype==0:
   b=np.array(p.bounding_box());via_protection.append(s.p.gdstk.rectangle((b[0,0],b[0,1]-.004),(b[1,0],b[1,1]+.004)))
 labels=[tuple(l.origin) for l in c.labels if l.layer==19]
 # First close existing notches within a single electrically connected M1polygon.
 for rule in ['M1.3','M1.4','M1.5']:
  for marker in common.marker_rows(text,rule):
   pair=pair_for(rule,marker,polys)
   if not pair or pair[0]!=pair[1]:continue
   x0,y0,x1,y1,d=marker;patch=s.p.gdstk.rectangle((x0-EPS,y0-EPS),(x1+EPS,y1+EPS),layer=19)
   other=[p for i,p in enumerate(polys) if i!=pair[0]]
   if other and intersection_area([patch],other)>1e-12:continue
   polys=s.p.gdstk.boolean(polys+[patch],[],'or',precision=EPS,layer=19);changes.append(dict(kind='fill_same_connected_M1_notch',rule=rule,marker_um=marker))
 # Then trim free global ends. Do not cut an enclosure pad or portlabel.
 for rule in ['M1.4','M1.5']:
  for marker in common.marker_rows(text,rule):
   pair=pair_for(rule,marker,polys)
   if not pair or pair[0]==pair[1]:continue
   x0,y0,x1,y1,d=marker;choices=[]
   for index in set(pair):
    poly=polys[index];b=np.array(poly.bounding_box());other=polys[pair[1] if index==pair[0] else pair[0]]
    # Markers on a global min/max edge permit safe dangling-end clipping.
    tests=[]
    if abs(b[0,1]-y1)<.00016:tests.append(('bottom',s.p.gdstk.rectangle((b[0,0]-EPS,b[0,1]-EPS),(b[1,0]+EPS,y0+.01525))))
    if abs(b[1,1]-y0)<.00016:tests.append(('top',s.p.gdstk.rectangle((b[0,0]-EPS,y1-.01525),(b[1,0]+EPS,b[1,1]+EPS))))
    if rule=='M1.5':
     if abs(b[0,0]-x1)<.00016:tests.append(('left',s.p.gdstk.rectangle((b[0,0]-EPS,b[0,1]-EPS),(x0+.01525,b[1,1]+EPS))))
     if abs(b[1,0]-x0)<.00016:tests.append(('right',s.p.gdstk.rectangle((x1-.01525,b[0,1]-EPS),(b[1,0]+EPS,b[1,1]+EPS))))
    for direction,cut in tests:
     fixed=safe_cut(poly,cut,via_protection,labels)
     if fixed is not None:choices.append((poly.area()-fixed.area(),index,fixed,direction))
   if choices:
    _,index,fixed,direction=min(choices,key=lambda x:x[0]);polys[index]=fixed;changes.append(dict(kind='trim_uncontacted_M1_end',direction=direction,rule=rule,marker_um=marker))
 if not changes:return dict(cell=cell,stage='no_safe_notch_or_free_end_change',changes=[])
 c.remove(*source);c.add(*polys);path=WORK/cell/'prepared_iter002_notches.gds';lib.write_gds(str(path));new=s.stage_iteration(cell,2,1,path);s.p.save(new/'GEOMETRY_CHANGES.json',dict(changes=changes,device_layers_changed=False,method='OnlyactualnativeM1markers; close SAMEconnectedconductor notches or trimuncontactedglobalends; preserveallvia4nmenclosures andM1portlabels. FreshnativeDRC/LVSrequired.'))
 return s.one(cell,2)

def main():
 owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().split()[21],epoch=time.time());s.p.save(ROOT/'NOTCH_REPAIR_LAUNCH.json',owner);rows=[];failed=[]
 with ThreadPoolExecutor(max_workers=4) as pool:
  tasks={pool.submit(candidate,n):n for n in NAMES}
  for f in as_completed(tasks):
   try:rows.append(f.result())
   except Exception:failed.append(dict(cell=tasks[f],traceback=traceback.format_exc()))
   s.p.save(ROOT/'NOTCH_REPAIR_STATUS.json',dict(stage='native_notch_repair',rows=rows,failed=failed,owner=owner,epoch=time.time()))
 s.p.save(ROOT/'NOTCH_REPAIR_STATUS.json',dict(stage='complete_requires_actual_marker_review',rows=rows,failed=failed,owner=owner,epoch=time.time()))
if __name__=='__main__':main()
