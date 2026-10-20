import sys; sys.path.insert(0,'/tmp/gunwork')
import pm_prep, numpy as np
parts,s=pm_prep.load()
A=lambda n: np.array([[p.co.x,-p.co.y,p.co.z] for p in parts[n].data.vertices])
v=np.vstack([A('Part08'),A('Part01')])
for lo,hi in ((-3,-6),(-6,-9),(-9,-12)):
    m=(v[:,2]<lo)&(v[:,2]>=hi); print('up',lo,hi,'x',v[m,0].min().round(1),v[m,0].max().round(1),'back',v[m,1].min().round(1),v[m,1].max().round(1))
m=(v[:,2]<-2)&(v[:,2]>-10); print('grip centre back',v[m,1].mean().round(1),'up',v[m,2].mean().round(1))
print('trigger guard / front strap back',A('Part05')[:,1].min().round(1))
