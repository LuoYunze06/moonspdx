"""Reproducible synthetic workloads; elapsed time includes Node startup, not a speed claim."""
import argparse,json,subprocess,time,statistics,pathlib
ATOMS=['0BSD','AFL-3.0','AGPL-3.0-only','AGPL-3.0-or-later','Apache-2.0','Artistic-2.0','BSD-2-Clause','BSD-3-Clause','BSD-3-Clause-Clear','BSL-1.0','BUSL-1.1','BlueOak-1.0.0']
def workloads():
    out=[]
    for n in (4,8,12):
        a=ATOMS[:n]
        out.append(dict(name='reverse-and-'+str(n),left=' AND '.join(a),right=' AND '.join(reversed(a))))
        out.append(dict(name='reverse-or-'+str(n),left=' OR '.join(a),right=' OR '.join(reversed(a))))
        pairs=['('+a[i]+' OR '+a[i+1]+')' for i in range(0,n,2)]
        out.append(dict(name='pair-conjunction-'+str(n),left=' AND '.join(pairs),right=' AND '.join(reversed(pairs))))
    repeated=' OR '.join(['(MIT AND Apache-2.0)']*40)
    out.append(dict(name='repeated-subexpression-40',left=repeated,right='Apache-2.0 AND MIT'))
    out.append(dict(name='distributivity',left='MIT AND (Apache-2.0 OR BSD-3-Clause)',right='MIT AND Apache-2.0 OR MIT AND BSD-3-Clause'))
    out.append(dict(name='negative-witness',left='MIT OR Apache-2.0',right='MIT AND Apache-2.0'))
    return out

def main():
    p=argparse.ArgumentParser();p.add_argument('--cli',required=True);p.add_argument('--output',required=True);p.add_argument('--revision',required=True);p.add_argument('--repeat',type=int,default=3);a=p.parse_args()
    results=[]
    for case in workloads():
        times=[];outputs=[]
        for _ in range(a.repeat):
            start=time.perf_counter()
            r=subprocess.run(['node',a.cli,'equivalent','--left',case['left'],'--right',case['right'],'--json'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,encoding='utf-8',timeout=30)
            times.append((time.perf_counter()-start)*1000)
            try: payload=json.loads(r.stdout)
            except ValueError: payload={'diagnostic':r.stdout.strip(),'stderr':r.stderr.strip()}
            outputs.append((r.returncode,payload))
        assert all(o==outputs[0] for o in outputs),'Nondeterministic result'
        results.append(dict(case,exit_code=outputs[0][0],result=outputs[0][1],median_process_ms=round(statistics.median(times),3)))
    report=dict(revision=a.revision,target='js release',node=subprocess.check_output(['node','--version'],text=True).strip(),repeat=a.repeat,timing_note='Includes process startup; not an in-process benchmark or cross-engine speed comparison.',results=results)
    pathlib.Path(a.output).write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    for c in results: print(c['name'],c['exit_code'],c['result'].get('operations',c['result']))
if __name__=='__main__':main()
