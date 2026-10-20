import bpy,sys,math,json,os
sys.path.insert(0,'/tmp/gunwork')
import numpy as np
from mathutils import Matrix, Vector
SCR='/tmp/claude-0/-home-claude/60b2c50a-b581-5f3b-8c3a-c51e57000c50/scratchpad/pm/blend/makarov-pm.blend'
LEN=float(os.environ.get('PMLEN','30'))
def load():
    bpy.ops.wm.open_mainfile(filepath=SCR)
    parts={o.name[-6:]:o for o in bpy.data.objects if o.type=='MESH'}
    bpy.data.objects.remove(parts.pop('Part07'),do_unlink=True)      # display stand
    for o in parts.values():                                         # bake object transforms into the mesh
        o.data.transform(o.matrix_world); o.matrix_world=Matrix.Identity(4)
        o.data.update()
    def arr(o): return np.array([[p.co.x,-p.co.y,p.co.z] for p in o.data.vertices])  # x, back(-y), up(z)
    sl=arr(parts['Part03']); c=sl.mean(0); w,V=np.linalg.eigh(np.cov((sl-c).T)); a=V[:,-1]; a=a if a[1]>0 else -a
    mg=arr(parts['Part01']).mean(0)
    u=c-mg; u=u-a*(u@a); u/=np.linalg.norm(u); r=np.cross(u,a)   # a=back, u=up, r= x? fix handedness below
    # target basis: x right, back, up. right = up x back... choose r so (r,a,u) is right-handed in (x,back,up) coords
    r=np.cross(a,u)
    Rm=np.array([r,a,u])   # rows map world->(x,back,up)
    if np.linalg.det(Rm)<0: Rm[0]*=-1
    # to blender: x, y=-back, z=up
    Cb=np.array([[1,0,0],[0,-1,0],[0,0,1]]); Rb=Cb@Rm@Cb
    M4=Matrix(((*Rb[0],0),(*Rb[1],0),(*Rb[2],0),(0,0,0,1)))
    for o in parts.values(): o.data.transform(M4); o.data.update()
    allv=np.array([[v.co.x,v.co.y,v.co.z] for o in parts.values() for v in o.data.vertices])
    ymin,ymax=allv[:,1].min(),allv[:,1].max(); L=ymax-ymin; s=LEN/L
    sup=np.array([[v.co.x,v.co.y,v.co.z] for v in parts['Part04'].data.vertices]); fr=sup[sup[:,1]<ymin+0.04*L]
    bx,bz=fr[:,0].mean(),fr[:,2].mean()
    M=Matrix.Scale(s,4)@Matrix.Rotation(math.pi,4,'Z')@Matrix.Translation((-bx,-ymin,-bz))
    for o in parts.values(): o.data.transform(M); o.data.update()
    return parts,s
if __name__=='__main__':
    parts,s=load(); print('scale',s)
    for n,o in sorted(parts.items()):
        v=np.array([[p.co.x,p.co.y,p.co.z] for p in o.data.vertices])
        # canonical game coords: (x, up=z, back=-y)
        print(n,'x',v[:,0].min().round(1),v[:,0].max().round(1),'up',v[:,2].min().round(1),v[:,2].max().round(1),'back',(-v[:,1]).min().round(1),(-v[:,1]).max().round(1))
