import sys; sys.path.insert(0,'/tmp/gunwork')
import stf_lib as L, numpy as np
r=L.load()
for n,d in r.obj.items(): print(n,d['co'].shape,d['co'].min(0).round(1),d['co'].max(0).round(1),'groups',len([1 for i,g in enumerate(d['names']) if d['W'][:,i].any()]))
for k in ('arm_stretch.r','forearm_stretch.r','hand.r','pinky1.r','c_pinky2.r','thumb1.r','neck.x','head.x','shoulder.r'): print(k,r.joint[k][0].round(1),r.joint[k][1].round(1))
