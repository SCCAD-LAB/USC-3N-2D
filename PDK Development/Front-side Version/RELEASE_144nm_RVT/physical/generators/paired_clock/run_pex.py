from pathlib import Path
import sys,os,socket,time,subprocess,shutil,json,traceback,re,gzip
HERE=Path(__file__).resolve().parent;PHYSICAL=HERE.parent
sys.path.insert(0,str(PHYSICAL));import scan as s,repair_common as common,pex_fspr as f
sys.path.insert(0,str(HERE));import terminal_connectivity_scoped as terminal
ITER='iter001';INPUTS=HERE/ITER/'inputs';WORK=Path('/usr/scratch/yhuang861/usc144_github_release_20261103/DFFH_paired_master_clock_candidate')/ITER/'pex';ARCHIVE=HERE/ITER/'pex'
owner=dict(host=socket.gethostname(),pid=os.getpid(),start_ticks=Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[19],epoch=time.time(),work=str(WORK));s.p.save(HERE/'PEX_LAUNCH.json',owner)
try:
 source=json.loads((HERE/ITER/'RESULT.json').read_text());assert source['passed']
 mem=int(next(x.split()[1] for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:')))*1024
 resource=dict(load=os.getloadavg(),cores=os.cpu_count(),memory_available=mem,scratch_free=shutil.disk_usage('/usr/scratch').free)
 s.p.save(HERE/ITER/'PEX_RESOURCE_ADMISSION.json',resource);assert resource['load'][0]+2<=.9*resource['cores'] and mem>8*1024**3 and resource['scratch_free']>4*1024**3
 assert not WORK.exists();WORK.mkdir(parents=True)
 s.p.save(HERE/'STATUS.json',dict(stage='fresh_native_PEX_candidate',owner=owner))
 deck=PHYSICAL/'rules/matched_144nm/LVS/ICV_3nm_FSPR_PEX.rs';local=WORK/'source_FSPR_PEX.rs';shutil.copyfile(deck,local)
 cmd=[s.p.ICV,'-i',str(INPUTS/'cell.gds'),'-c','DFFHx1','-f','GDSII','-host_init',socket.gethostname()+':2','-s',str(INPUTS/'topology.cdl'),'-sf','SPICE','-stc','DFFHx1',str(local)]
 with (WORK/'icv.log').open('w') as out:rc=subprocess.run(cmd,cwd=WORK,env=s.p.ENV,stdout=out,stderr=subprocess.STDOUT,timeout=1200).returncode
 report=WORK/'DFFHx1.LVS_ERRORS';assert rc==0 and 'Final comparison result:PASS' in report.read_text()
 dims=s.dimension_rows(WORK/'DFFHx1.net.gz');assert s.dimension_identity(dims)==s.dimension_identity(json.loads((HERE/ITER/'ACTUAL_DEVICE_DIMENSIONS.json').read_text())['rows'])
 grid=PHYSICAL.parent/'sources/github_FSPR.nxtgrd';raw=WORK/'cell.raw.dspf'
 lines=['BLOCK: DFFHx1','TCAD_GRD_FILE: '+str(grid),'ICV_RUNSET_REPORT_FILE: '+str(WORK/'pex_runset_report'),'MAPPING_FILE: '+str(WORK/'starrcxt.mapping'),'STAR_DIRECTORY: '+str(WORK/'star'),'EXTRACTION: RC','NETLIST_FORMAT: SPF','NETLIST_FILE: '+str(raw),'NETLIST_SUBCKT: YES','NETLIST_GROUND_NODE_NAME: VSS','POWER_NETS: *','POWER_EXTRACT: YES','CASE_SENSITIVE: YES','COUPLE_TO_GROUND: NO','REDUCTION: NO','NUM_CORES: 2']
 (WORK/'starrc.cmd').write_text('\n'.join(lines)+'\n')
 with (WORK/'starrc.log').open('w') as out:rc=subprocess.run(['/tools/software/synopsys/starrc/latest/bin/StarXtract',str(WORK/'starrc.cmd')],cwd=WORK,env=s.p.ENV,stdout=out,stderr=subprocess.STDOUT,timeout=1200).returncode
 assert rc==0 and raw.exists(),'Native StarRC failed'
 explicit,body=common.explicit_bodies(raw.read_text(),'DFFHx1')
 s.p.copy_tree(WORK,ARCHIVE);(ARCHIVE/'cell.dspf').write_text(explicit);s.p.save(ARCHIVE/'BULK_REFERENCE_AUDIT.json',body);s.p.save(ARCHIVE/'ACTUAL_DEVICE_DIMENSIONS.json',dict(rows=dims))
 gate=dict(cell='DFFHx1',iteration=1,candidate_gds=str(INPUTS/'cell.gds'),gds_sha256=s.p.sha(INPUTS/'cell.gds'),lvs=dict(report=str(ARCHIVE/'DFFHx1.LVS_ERRORS'),actual_dimension_rows=dims),device_geometry_preserved=True,actual_MOS_dimensions_preserved=True,device_layer_change_authorized=True,device_layer_change_audit=str(HERE/'GEOMETRY_GENERATION.json'))
 binding=f.binding_receipt('DFFHx1',raw.read_text(),gate,str(ARCHIVE/'BULK_REFERENCE_AUDIT.json'));s.p.save(ARCHIVE/'DEVICE_GEOMETRY_BINDING.json',binding)
 audit=terminal.audit('DFFHx1',gate,ARCHIVE/'cell.raw.dspf',binding,ARCHIVE/'TERMINAL_CONNECTIVITY_AUDIT.json')
 row=dict(cell='DFFHx1',gds=str(INPUTS/'cell.gds'),gds_sha256=gate['gds_sha256'],dspf=str(ARCHIVE/'cell.dspf'),dspf_sha256=s.p.sha(ARCHIVE/'cell.dspf'),raw_dspf=str(ARCHIVE/'cell.raw.dspf'),raw_dspf_sha256=s.p.sha(ARCHIVE/'cell.raw.dspf'),device_geometry_binding=str(ARCHIVE/'DEVICE_GEOMETRY_BINDING.json'),device_geometry_binding_sha256=s.p.sha(ARCHIVE/'DEVICE_GEOMETRY_BINDING.json'),terminal_connectivity_pass=audit['passed'],grid=str(grid),grid_sha256=s.p.sha(grid),drc_pass=True,topology_LVS_pass=True,native_property_checks_enabled=False,all32_L_W_coordinates_preserved=True,derived_topology_reference=str(INPUTS/'topology.cdl'),fresh_native_StarRC=True,canonical_adoption=False,owner=owner)
 s.p.save(ARCHIVE/'PEX_RECEIPT.json',row);s.p.save(HERE/'STATUS.json',dict(stage='fresh_PEX_complete_candidate_unqualified_pending_behavior',expected_terminal=True,owner=owner,pex=row))
except Exception:
 if WORK.exists():s.p.copy_tree(WORK,ARCHIVE/'failed_native')
 s.p.save(HERE/'STATUS.json',dict(stage='candidate_PEX_failed_preserve',expected_terminal=True,owner=owner,traceback=traceback.format_exc()));raise
