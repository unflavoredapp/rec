import sys; sys.path.insert(0,'/tmp/gunwork')
import pm_prep, numpy as np
parts,s=pm_prep.load()
def pc(n):
    v=np.array([[p.co.x,-p.co.y,p.co.z] for p in parts[n].data.vertices]); c=v.mean(0)
    w,V=np.linalg.eigh(np.cov((v-c).T)); a=V[:,-1]; a=a if a[1]>0 else -a
    return c,a,w
for n in ('Part03','Part04','Part08','Part02'):
    c,a,w=pc(n); print(n,'axis',a.round(3),'eig',np.sqrt(w).round(2))
