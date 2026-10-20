import bpy, math, json, sys, numpy as np
sys.path.insert(0,'/tmp/gunwork')
S='/tmp/claude-0/-home-claude/60b2c50a-b581-5f3b-8c3a-c51e57000c50/scratchpad/stf/Fbx/Special Task Force.blend'
K=100*0.93                                   # metres -> operator cm, scaled to ~1.77 m
def tf(p):                                   # blender-char (faces -y) -> operator (faces +y, right=+x), cm
    p=np.asarray(p,float); q=p.copy(); q[...,0]=-p[...,0]; q[...,1]=-p[...,1]; return q*K
FINGERS=['pinky','ring','middle','index']
class Rig: pass
def load():
    bpy.ops.wm.open_mainfile(filepath=S)
    r=Rig(); arm=bpy.data.objects['rig']; r.arm=arm
    r.joint={}
    for b in arm.data.bones: r.joint[b.name]=(tf(b.head_local),tf(b.tail_local))
    r.obj={}
    for n in ('Object_0','Object_1','Object_2'):
        o=bpy.data.objects[n]; me=o.data; nv=len(me.vertices)
        co=np.empty(nv*3); me.vertices.foreach_get('co',co); co=tf(co.reshape(-1,3))
        names=[g.name for g in o.vertex_groups]; W=np.zeros((nv,len(names)),np.float32)
        for v in me.vertices:
            for g in v.groups: W[v.index,g.group]=g.weight
        r.obj[n]=dict(o=o,co=co,names=names,W=W)
    return r
def rotmat(axis,ang):
    a=np.asarray(axis,float); a=a/np.linalg.norm(a); c,s=math.cos(ang),math.sin(ang); x,y,z=a
    return np.array([[c+x*x*(1-c),x*y*(1-c)-z*s,x*z*(1-c)+y*s],[y*x*(1-c)+z*s,c+y*y*(1-c),y*z*(1-c)-x*s],[z*x*(1-c)-y*s,z*y*(1-c)+x*s,c+z*z*(1-c)]])
def arc(a,b):
    a=np.asarray(a,float)/np.linalg.norm(a); b=np.asarray(b,float)/np.linalg.norm(b); c=np.cross(a,b); s=np.linalg.norm(c); d=a@b
    if s<1e-8:
        if d>0: return np.eye(3)
        p=np.cross(a,[1,0,0]); 
        if np.linalg.norm(p)<1e-3: p=np.cross(a,[0,1,0])
        return rotmat(p,math.pi)
    return rotmat(c/s,math.atan2(s,d))
def frame(f,n):
    f=np.asarray(f,float)/np.linalg.norm(f); n=np.asarray(n,float); n=n-f*(n@f); n/=np.linalg.norm(n); return np.array([f,n,np.cross(f,n)]).T   # columns f,n,f×n
class T:                                      # p' = R p + t
    def __init__(s,R=None,t=None): s.R=np.eye(3) if R is None else R; s.t=np.zeros(3) if t is None else t
    def __call__(s,p): return p@s.R.T+s.t
    def about(s,pivot_rest,Q):                # apply rotation Q about the (already transformed) pivot after this transform
        c=s(np.asarray(pivot_rest,float)); R2=Q@s.R; t2=Q@(s.t-c)+c; return T(R2,t2)
def ik2(S,W,a,b,pole):
    S=np.asarray(S,float);W=np.asarray(W,float); d=np.linalg.norm(W-S); u=(W-S)/d
    mx=(a+b)*0.985
    if d>mx: W=S+u*mx; d=mx
    x=(d*d+a*a-b*b)/(2*d); h=math.sqrt(max(0.01,a*a-x*x)); pv=np.asarray(pole,float); pv=pv-pv.dot(u)*u; pv/=np.linalg.norm(pv)
    return S+u*x+pv*h, W
def pose_arm(r,side,Wt,ft,nt,pole,curl,thumb=0.5,n0=(0,0,-1),base=None):
    """returns ({group: T}, info). Wt wrist target; ft/nt hand direction + palm normal targets; base = torso transform the arm hangs from."""
    J=r.joint; s=side; base=base or T()
    S=J['arm.'+s][0]; E=J['forearm.'+s][0]; Wr=J['hand.'+s][0]; Wtail=J['hand.'+s][1]
    a=np.linalg.norm(E-S); b=np.linalg.norm(Wr-E)
    St=base(S); Et,Wt2=ik2(St,Wt,a,b,pole)
    err=float(np.linalg.norm(np.asarray(Wt,float)-Wt2))
    R1=arc(base(E)-St,Et-St); Tup=base.about(S,R1)
    Ep=Tup(E); R2=arc(Tup(Wr)-Ep,Wt2-Ep); Tfo=Tup.about(E,R2)
    f0=(Wtail-Wr)/np.linalg.norm(Wtail-Wr); Fr0=frame(f0,n0)
    Fc=Tfo.R@Fr0; Ft=frame(ft,nt); Rh=Ft@Fc.T
    Th=Tfo.about(Wr,Rh)
    out={}
    for g in ('arm_stretch.','c_arm_twist_offset.'): out[g+s]=Tup
    for g in ('forearm_stretch.','forearm_twist.'): out[g+s]=Tfo
    out['hand.'+s]=Th
    for g in FINGERS: out['c_%s1_base.%s'%(g,s)]=Th
    fa=np.cross(Th.R@f0,Th.R@np.asarray(n0,float)); fa/=np.linalg.norm(fa)
    ang=(math.radians(62),math.radians(88),math.radians(58))
    for g in FINGERS:
        c=curl.get(g,0.7); Tc=Th
        for grp,sc in (('%s1.%s'%(g,s),ang[0]),('c_%s2.%s'%(g,s),ang[1]),('c_%s3.%s'%(g,s),ang[2])):
            Tc=Tc.about(J[grp][0],rotmat(fa,sc*c)); out[grp]=Tc
    Tc=Th; ta=(math.radians(18),math.radians(34),math.radians(40))
    for i,grp in enumerate(('thumb1.'+s,'c_thumb2.'+s,'c_thumb3.'+s)):
        Q=rotmat(fa,ta[i]*thumb)@rotmat(Th.R@f0,math.radians(22)*thumb*(1 if i==0 else 0))
        Tc=Tc.about(J[grp][0],Q); out[grp]=Tc
    return out,dict(err=err,wrist=Wt2,elbow=Et,Th=Th,fa=fa)
def skin(r,name,Ts):
    d=r.obj[name]; W=d['W']; co=d['co']; n=len(co); acc=np.zeros_like(co); tot=np.zeros(n)
    for gi,g in enumerate(d['names']):
        w=W[:,gi]
        if not w.any(): continue
        t=Ts.get(g); pc=t(co) if t is not None else co
        acc+=w[:,None]*pc; tot+=w
    rest=np.clip(1-tot,0,1)[:,None]
    return (acc+rest*co)/np.maximum(tot,1.0)[:,None]
def emit(r,name,newco,tag='p'):
    d=r.obj[name]; o=d['o']; me=o.data.copy(); me.vertices.foreach_set('co',newco.reshape(-1)); me.update()
    me.calc_normals_split() if hasattr(me,'calc_normals_split') else None
    ob=bpy.data.objects.new(f'{name}_{tag}',me); bpy.context.collection.objects.link(ob); return ob
