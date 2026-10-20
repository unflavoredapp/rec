import numpy as np, os, colorsys
from PIL import Image, ImageDraw, ImageFilter
T='/tmp/claude-0/-home-claude/60b2c50a-b581-5f3b-8c3a-c51e57000c50/scratchpad/stf/Fbx/Texture/'
OUT='/tmp/gunwork/stf_out/tex'; os.makedirs(OUT,exist_ok=True)
def ld(n): return np.asarray(Image.open(T+n).convert('RGB'),np.float32)/255
def hsv(a):
    mx=a.max(-1); mn=a.min(-1); d=mx-mn; s=np.where(mx>1e-6,d/np.maximum(mx,1e-6),0)
    r,g,b=a[...,0],a[...,1],a[...,2]; h=np.zeros_like(mx)
    m=d>1e-6
    h=np.where(m&(mx==r),((g-b)/np.maximum(d,1e-6))%6,h); h=np.where(m&(mx==g),(b-r)/np.maximum(d,1e-6)+2,h); h=np.where(m&(mx==b),(r-g)/np.maximum(d,1e-6)+4,h)
    return h*60,s,mx
def smooth(e0,e1,x):
    t=np.clip((x-e0)/(e1-e0),0,1); return t*t*(3-2*t)
def gmap(Y,cols,lo,hi):
    t=np.clip((Y-lo)/(hi-lo),0,1)[...,None]; d,m,l=[np.array(c,np.float32) for c in cols]
    return np.where(t<0.5,d+(m-d)*(t/0.5),m+(l-m)*((t-0.5)/0.5))
def save(a,name,size=None,q=84):
    im=Image.fromarray((np.clip(a,0,1)*255+0.5).astype(np.uint8))
    if size: im=im.resize(size,Image.LANCZOS)
    im.save(f'{OUT}/{name}.jpg',quality=q)
# ---- uniform camo
body=ld('AF_01_D_baseColor.jpg'); h,s,v=hsv(body); Y=body@np.array([0.299,0.587,0.114],np.float32)
mask=(smooth(0.26,0.17,s)*smooth(0.06,0.12,Y))[...,None]
bodyY=Y
BODY={'std':None,
 'desert':((0.27,0.21,0.13),(0.60,0.50,0.34),(0.84,0.76,0.60)),
 'wood':((0.07,0.10,0.05),(0.22,0.29,0.14),(0.46,0.50,0.30)),
 'urban':((0.07,0.08,0.10),(0.30,0.32,0.36),(0.60,0.62,0.66)),
 'arctic':((0.52,0.58,0.65),(0.80,0.84,0.89),(0.97,0.98,1.0)),
 'night':((0.015,0.02,0.03),(0.06,0.07,0.09),(0.15,0.16,0.19)),
 'crimson':((0.10,0.025,0.025),(0.28,0.065,0.065),(0.50,0.15,0.13))}
for i,(k,c) in enumerate(BODY.items()):
    out=body if c is None else body*(1-mask)+gmap(Y,c,0.10,0.72)*mask
    save(out,f'stf_body_{i}',(768,1536))
# ---- gear (tan nylon)
def tanmask(a):
    h,s,v=hsv(a); Y=a@np.array([0.299,0.587,0.114],np.float32)
    return (smooth(0.07,0.12,s)*smooth(0.62,0.50,s)*smooth(14,24,h)*smooth(70,58,h)*smooth(0.07,0.13,Y))[...,None],Y
GEAR={'coyote':None,
 'olive':((0.05,0.06,0.035),(0.24,0.26,0.15),(0.46,0.48,0.31)),
 'black':((0.012,0.012,0.014),(0.06,0.06,0.065),(0.17,0.17,0.18)),
 'grey':((0.07,0.075,0.08),(0.28,0.29,0.31),(0.52,0.53,0.56)),
 'navy':((0.015,0.025,0.05),(0.07,0.10,0.17),(0.20,0.25,0.36))}
gear=ld('AF_01_etc_D_baseColor.jpg'); gm,gY=tanmask(gear)
for i,(k,c) in enumerate(GEAR.items()):
    out=gear if c is None else gear*(1-gm)+gmap(gY,c,0.10,0.62)*gm
    save(out,f'stf_gear_{i}',(768,768))
helm=ld('AF_Helmet_01_D_baseColor.jpg'); hm,hY=tanmask(helm)
HELM={'coyote':None,'olive':GEAR['olive'],'black':GEAR['black'],'grey':GEAR['grey'],
 'white':((0.55,0.58,0.62),(0.82,0.85,0.88),(0.97,0.98,0.99))}
for i,(k,c) in enumerate(HELM.items()):
    out=helm if c is None else helm*(1-hm)+gmap(hY,c,0.10,0.62)*hm
    save(out,f'stf_helm_{i}',(768,384))
# ---- faces
head=ld('Head_101_D_baseColor.jpg'); h,s,v=hsv(head); Y=head@np.array([0.299,0.587,0.114],np.float32)
sk=(smooth(0.06,0.14,s)*smooth(60,40,h)*smooth(0.10,0.22,Y))[...,None]
def tone(g,add=0.0): return np.clip(head*np.array(g,np.float32)+add,0,1)
FACES={'std':head,
 'fair':head*(1-sk)+tone((1.22,1.14,1.08),0.05)*sk,
 'tan':head*(1-sk)+tone((1.00,0.90,0.72),0.0)*sk,
 'deep':head*(1-sk)+tone((0.60,0.52,0.45),-0.01)*sk}
def paint(base,kind):
    W,H=base.shape[1],base.shape[0]
    L=Image.new('L',(W,H),0); d=ImageDraw.Draw(L); C=Image.new('RGB',(W,H),(0,0,0)); dc=ImageDraw.Draw(C)
    rng=np.random.default_rng(5)
    def band(p0,p1,w,col):
        d.line([p0,p1],fill=255,width=w); dc.line([p0,p1],fill=tuple(int(x*255) for x in col),width=w)
    if kind=='wood':
        cols=[(0.04,0.04,0.04),(0.16,0.22,0.09),(0.22,0.15,0.08)]
        for k,(y0) in enumerate((165,215,262)):
            for sx in (1,-1):
                xa=250 if sx==1 else 774; xb=xa+sx*105
                band((xa,y0+30),(xb,y0-18),26,cols[k%3])
        for k,x0 in enumerate((330,480,640)):                       # forehead
            band((x0,362),(x0+60,405),22,cols[(k+1)%3])
        band((470,120),(560,135),14,cols[0])                          # chin
    elif kind=='night':
        for cx in (385,640): d.ellipse([cx-50,243,cx+50,269],fill=255); dc.ellipse([cx-50,243,cx+50,269],fill=(8,8,8))
        band((330,350),(700,350),13,(0.03,0.03,0.03))
        band((470,122),(550,131),10,(0.03,0.03,0.03))
    elif kind=='scar':
        band((262,310),(338,196),5,(0.64,0.38,0.34)); band((255,306),(331,192),2,(0.30,0.15,0.13)); band((270,314),(346,200),2,(0.30,0.15,0.13))
        for t in np.linspace(0.15,0.85,5): x=262+76*t; y=310-114*t; band((x-7,y-3),(x+7,y+3),2,(0.58,0.30,0.28))
    Lm=L.filter(ImageFilter.GaussianBlur(2.2)); a=np.asarray(Lm,np.float32)/255
    noise=np.asarray(Image.fromarray((rng.random((H//8,W//8))*255).astype(np.uint8)).resize((W,H),Image.BICUBIC),np.float32)/255
    a=np.clip(a*(0.82+0.5*noise),0,1)[...,None]*smooth(0.15,0.6,sk)
    c=np.asarray(C.filter(ImageFilter.GaussianBlur(1.2)),np.float32)/255
    return base*(1-a)+c*a
FACES['wood']=paint(head,'wood'); FACES['night']=paint(head,'night'); FACES['scar']=paint(head,'scar')
for i,(k,a) in enumerate(FACES.items()): save(a,f'stf_head_{i}',None,86)
print(sorted(os.listdir(OUT)))
# ---- small swatches for the customize screen
def sw(a,box,name,flip=False):
    x0,y0,x1,y1=box; c=(np.clip(a[y0:y1,x0:x1],0,1)*255+0.5).astype(np.uint8); im=Image.fromarray(c)
    if flip: im=im.transpose(Image.FLIP_TOP_BOTTOM)
    im=im.resize((120,100),Image.LANCZOS); im.save(f'{OUT}/{name}.png')
for i,(k,c) in enumerate(BODY.items()):
    a=body if c is None else body*(1-mask)+gmap(bodyY,c,0.10,0.72)*mask; sw(a,(60,60,380,320),f'stfsw_body_{i}')
for i,(k,c) in enumerate(GEAR.items()):
    a=gear if c is None else gear*(1-gm)+gmap(gY,c,0.10,0.62)*gm; sw(a,(330,380,650,630),f'stfsw_gear_{i}')
for i,(k,c) in enumerate(HELM.items()):
    a=helm if c is None else helm*(1-hm)+gmap(hY,c,0.10,0.62)*hm; sw(a,(60,30,420,230),f'stfsw_helm_{i}')
for i,(k,a) in enumerate(FACES.items()): sw(a,(290,100,730,380),f'stfsw_face_{i}',True)
