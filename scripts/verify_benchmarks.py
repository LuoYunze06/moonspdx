"""Check recorded results and (optionally) rerun every workload against a built CLI."""
import argparse,json,pathlib,subprocess

def main():
 p=argparse.ArgumentParser();p.add_argument('--cli');a=p.parse_args()
 root=pathlib.Path(__file__).resolve().parent.parent
 before=json.loads((root/'docs/benchmarks/baseline.json').read_text(encoding='utf-8'))['results']
 after=json.loads((root/'docs/benchmarks/optimized.json').read_text(encoding='utf-8'))['results']
 assert len(before)==len(after)==12
 for old,new in zip(before,after):
  for k in ('name','left','right','exit_code'): assert old[k]==new[k]
  for k in old['result']:
   if k not in ('operations','decision_nodes'): assert old['result'][k]==new['result'][k],(new['name'],k)
  assert new['result']['operations'] < old['result']['operations']
  if a.cli:
   args=['node',a.cli,'equivalent','--left',new['left'],'--right',new['right'],'--json']
   r=subprocess.run(args,capture_output=True,encoding='utf-8',timeout=30)
   assert r.returncode==new['exit_code'],r.stderr
   assert json.loads(r.stdout)==new['result'],new['name']
   if new['name']=='reverse-and-12':
    bounded=subprocess.run(args+['--max-operations','1000'],capture_output=True,encoding='utf-8',timeout=30)
    assert bounded.returncode==0 and json.loads(bounded.stdout)['holds']
 print('12/12 benchmark proof outputs and work counters verified; baseline semantic results preserved.')
if __name__=='__main__':main()
