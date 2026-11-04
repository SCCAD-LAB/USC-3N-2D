from pathlib import Path
import sys,os,socket,time,json,shutil,traceback
HERE=Path(__file__).resolve().parent;PHYSICAL=HERE.parent
sys.path.insert(0,str(PHYSICAL/'routing_repairs'));import candidate01 as q
sys.path.insert(0,str(PHYSICAL));import scan as s
ITER=sys.argv[1] if len(sys.argv)>1 else 'iter001'
WORK=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/DFFH_paired_master_clock_candidate')/ITER
owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],epoch=time.time(),work=str(WORK))
q.save(HERE/'LAUNCH.json',owner)
try:
 mem=int(next(x.split()[1] for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:')))*1024
 resource=dict(load=os.getloadavg(),cores=os.cpu_count(),memory_available=mem,scratch_free=shutil.disk_usage('/usr/scratch').free)
 q.save(HERE/ITER/'RESOURCE_ADMISSION.json',resource)
 assert resource['load'][0]+2<=.9*resource['cores'] and mem>8*1024**3 and resource['scratch_free']>4*1024**3
 assert not WORK.exists();q.copy_tree(HERE/ITER/'inputs',WORK/'inputs')
 q.save(HERE/'STATUS.json',dict(stage='native_DRC_LVS_candidate',owner=owner,iteration=ITER))
 drc=q.native('DFFHx1',WORK,'drc');lvs=q.native('DFFHx1',WORK,'lvs')
 q.copy_tree(WORK,HERE/ITER/'native')
 dims=s.dimension_rows(WORK/'lvs/DFFHx1.net.gz')
 initial=json.loads((HERE/'frozen_original/ACTUAL_DEVICE_DIMENSIONS.json').read_text())['rows']
 dimensional=s.dimension_identity(dims)==s.dimension_identity(initial)
 q.save(HERE/ITER/'ACTUAL_DEVICE_DIMENSIONS.json',dict(rows=dims,preserved=dimensional))
 result=dict(passed=drc['passed'] and lvs['passed'] and dimensional,drc=drc,lvs=lvs,all32_L_W_coordinates_preserved=dimensional,gds_sha256=q.sha(WORK/'inputs/cell.gds'),derived_reference_sha256=q.sha(WORK/'inputs/topology.cdl'),owner=owner)
 q.save(HERE/ITER/'RESULT.json',result);q.save(HERE/'STATUS.json',dict(stage='native_candidate_complete_requires_review',expected_terminal=True,owner=owner,result=result))
except Exception:
 q.save(HERE/'STATUS.json',dict(stage='native_candidate_exception_preserve',expected_terminal=True,owner=owner,traceback=traceback.format_exc()));raise
