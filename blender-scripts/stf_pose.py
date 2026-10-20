import sys,math,json,numpy as np
sys.path.insert(0,'/tmp/gunwork')
import stf_lib as L
from stf_lib import T,rotmat,arc
src=open('/tmp/gunwork/qexport.py').read(); ps=src.index('P={'); pe=src.index('\n}\n',ps)+3
exec(src[ps:pe])
xf=json.load(open('/tmp/gunwork/xf.json')); meta=json.load(open('/mnt/user-data/outputs/changed-files/Resources/gunmeta.json'))
LEN={'pistol':21,'eagle':32,'pm':30,'smg':67,'mp7':60,'p90':54,'rifle':86,'m4':73,'ak':88.5,'shotgun':71.5,'pump':83,'awp':99.7}
PIST=('pistol','eagle','pm')
Cgb=np.array([[1,0,0],[0,0,-1],[0,1,0]],float)       # gltf -> blender
def qrot(q,v):
    x,y,z,w=q; u=np.array([x,y,z]); t=2*np.cross(u,v); return v+w*t+np.cross(u,t)
def Rxm(t): c,s=math.cos(t),math.sin(t); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def Rym(t): c,s=math.cos(t),math.sin(t); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
def torso(th_deg):
    th=math.radians(th_deg); Tp=lambda k: T(rotmat((0,0,1),-th*k))
    d={'spine_01.x':Tp(0.25),'spine_02.x':Tp(0.55),'spine_03.x':Tp(0.8),'neck.x':Tp(0.4),'shoulder.r':Tp(0.8),'shoulder.l':Tp(0.8)}
    return d,Tp(0.8)
def place(gid,aim,anchor_c,target):
    """gun placement: canonical point anchor_c lands on target (operator blender cm), bore along aim (blender). returns dict"""
    d=np.asarray(aim,float); d/=np.linalg.norm(d); dg=np.array([d[0],d[2],-d[1]])    # blender->gltf
    phi=-math.asin(max(-1,min(1,dg[0]))); al=math.atan2(dg[1],-dg[2])
    Rg=Rxm(al)@Rym(phi); Ra=Cgb@Rg@Cgb.T
    q=xf[gid]['q']; Tm=np.array(xf[gid]['mz'])
    e=lambda c: qrot(q,np.array(c,float))+Tm
    b=lambda c: Cgb@e(c)
    pa=np.asarray(target,float)-Ra@b(anchor_c)
    pos=[float(x) for x in (Cgb.T@pa)]
    P_=lambda c: Ra@b(c)+pa                                   # canonical point -> operator blender
    D_=lambda v: Ra@(Cgb@qrot(q,np.array(v,float)))           # canonical direction -> operator blender
    return dict(al=al,phi=phi,pos=pos,Ra=Ra,pa=pa,P=P_,D=D_)
def solve(r,gid,blade=None,verbose=True):
    if gid in PIST: return solve1(r,gid,blade,verbose,13.0)
    best=None
    for py in (13.0,11.0,9.0,7.0,5.0,3.0):
        res=solve1(r,gid,blade,False,py)
        if best is None or res[3][1]['err']<best[3][1]['err']: best=res
        if res[3][1]['err']<1.0: break
    if verbose: print(gid,'reach err R %.1f L %.1f'%(best[3][0]['err'],best[3][1]['err']))
    return best
def solve1(r,gid,blade,verbose,py):
    p=P[gid]; pist=gid in PIST; lm=p['lmode']
    th=blade if blade is not None else (14 if pist else 26)
    tdict,base=torso(th)
    St=base(r.joint['arm.r'][0])
    if pist:
        gy,gz=p['rg']; tgt=np.array([5.0,40.0,142.0]); aim=(0.0,1.0,-0.02)
        G=place(gid,aim,(0,gy,gz),tgt)
    else:
        pocket=base(r.joint['arm.r'][0]+np.array([-9.0,py,2.0]))
        aim=(-0.06,1.0,-0.03)
        G=place(gid,aim,(0,-4.0,LEN[gid]),pocket)
    gy,gz=p['rg']; hd=p.get('hd',2.8); pw=p.get('pw',1.7)
    # right hand
    f=G['D']((-0.05,-0.96,0.27)); n=G['D']((-0.62,0.0,-0.78))
    Pc=G['P']((pw+0.2,gy+0.3,gz+hd+0.6))
    Wt=Pc-f/np.linalg.norm(f)*4.6
    TR,iR=L.pose_arm(r,'r',Wt,f,n,(0.5,-0.3,-1),{'index':0.45,'middle':1,'ring':1,'pinky':1},0.6,base=base)
    # left hand
    if lm=='wrap':
        Pl=G['P']((-pw-0.9,gy-0.6,gz+0.3)); fl=G['D']((0.12,-0.95,-0.12)); nl=G['D']((1,0.0,-0.25)); pole=(-0.5,-0.3,-1); cl={'index':0.8,'middle':0.95,'ring':0.95,'pinky':0.95}; tl=0.3
    elif lm=='pole':
        lz,ly=p['lg'][:2]; lp=p.get('lpw',2.0)
        Pl=G['P']((-lp-0.5,ly-1.0,lz+lp*0)); fl=G['D']((0.0,-0.96,0.28)); nl=G['D']((1,0.1,-0.1)); pole=(-0.5,-0.3,-1); cl={'index':0.9,'middle':1,'ring':1,'pinky':1}; tl=0.6
    else:
        lz,ly,lr=p['lg']
        fl=G['D']((0.15,0.12,-1)); nl=G['D']((0.2,1,0.0)); pole=(-0.6,-0.4,-1); cl={'index':0.85,'middle':0.95,'ring':0.95,'pinky':0.95}; tl=0.5
        best=None
        for dz in range(-6,26,2):                       # slide the support hand back along the handguard until the arm can reach it
            Pl=G['P']((0.0,ly-lr-0.8,lz+dz)); Wl=Pl-fl/np.linalg.norm(fl)*4.6
            TLt,iLt=L.pose_arm(r,'l',Wl,fl,nl,pole,cl,tl,base=base)
            if best is None or iLt['err']<best[0]: best=(iLt['err'],Pl)
            if iLt['err']<0.8: break
        Pl=best[1]
    Wl=Pl-fl/np.linalg.norm(fl)*4.6
    TL,iL=L.pose_arm(r,'l',Wl,fl,nl,pole,cl,tl,base=base)
    Ts={}; Ts.update(tdict); Ts.update(TR); Ts.update(TL)
    if verbose: print(gid,'reach err R %.1f L %.1f'%(iR['err'],iL['err']))
    G['Pc']=Pc; G['Pl']=Pl
    hold=dict(al=G['al'],phi=G['phi'],pos=G['pos'])
    return Ts,hold,G,(iR,iL)
