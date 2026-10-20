// Metal shading language source for the MX renderer. It is compiled at runtime
// (device.makeLibrary(source:)) so a shader error shows up on screen instead of breaking the build.

enum MXShaderSource {
    static let source = #"""
#include <metal_stdlib>
using namespace metal;

struct FrameU {
    float4x4 viewProj;
    float4x4 lightVP;
    float4 camPos;
    float4 fogColor;     // rgb, w = exponent
    float4 fogParams;    // x start, y end, z enabled
    float4 ambient;      // rgb
    float4 dirDir[2];    // xyz = direction toward the light, w = casts shadow
    float4 dirCol[2];    // rgb = color * intensity
    float4 ptPos[8];     // xyz = position, w = attenuation start
    float4 ptCol[8];     // rgb = color * intensity, w = attenuation end
    float4 counts;       // x = directional count, y = point count, z = shadow on, w = shadow texel
    float4 shadowInfo;   // x = strength, y = radius in texels, z = bias
    float4x4 invVP;
};

struct NodeU {
    float4x4 model;
    float4x4 normalM;
};

struct MatU {
    float4 diffuse;
    float4 emission;
    float4 specular;     // rgb, w = exponent
    float4 mulColor;
    float4 params;       // x alpha, y reflect intensity, z bump intensity, w lighting model (0 blinn, 1 lambert, 2 constant)
    float4 flags;        // x diffuse tex, y bump tex, z multiply tex, w env tex
    float4 uv;           // xy diffuse scale, zw bump scale
    float4 flags2;       // x double sided
};

struct VIn {
    float3 pos [[attribute(0)]];
    float3 nrm [[attribute(1)]];
    float2 uv  [[attribute(2)]];
};

struct VOut {
    float4 pos [[position]];
    float3 wpos;
    float3 nrm;
    float2 uv;
};

vertex VOut vs_main(VIn v [[stage_in]],
                    constant FrameU& f [[buffer(1)]],
                    constant NodeU& n [[buffer(2)]]) {
    VOut o;
    float4 wp = n.model * float4(v.pos, 1.0);
    o.pos = f.viewProj * wp;
    o.wpos = wp.xyz;
    o.nrm = (n.normalM * float4(v.nrm, 0.0)).xyz;
    o.uv = v.uv;
    return o;
}

vertex VOut vs_inst(VIn v [[stage_in]],
                    constant FrameU& f [[buffer(1)]],
                    constant NodeU* ns [[buffer(2)]],
                    uint iid [[instance_id]]) {
    VOut o;
    NodeU n = ns[iid];
    float4 wp = n.model * float4(v.pos, 1.0);
    o.pos = f.viewProj * wp;
    o.wpos = wp.xyz;
    o.nrm = (n.normalM * float4(v.nrm, 0.0)).xyz;
    o.uv = v.uv;
    return o;
}

vertex float4 vs_shadow_inst(VIn v [[stage_in]],
                             constant FrameU& f [[buffer(1)]],
                             constant NodeU* ns [[buffer(2)]],
                             uint iid [[instance_id]]) {
    return f.lightVP * (ns[iid].model * float4(v.pos, 1.0));
}

vertex float4 vs_shadow(VIn v [[stage_in]],
                        constant FrameU& f [[buffer(1)]],
                        constant NodeU& n [[buffer(2)]]) {
    return f.lightVP * (n.model * float4(v.pos, 1.0));
}

constexpr sampler sRep(coord::normalized, address::repeat, filter::linear, mip_filter::linear, max_anisotropy(4));
constexpr sampler sClamp(coord::normalized, address::clamp_to_edge, filter::linear);
constexpr sampler sShadow(coord::normalized, address::clamp_to_edge, filter::linear, compare_func::less_equal);

static float shadowAt(constant FrameU& f, depth2d<float> tShadow, float3 wpos, float3 N) {
    float4 lp = f.lightVP * float4(wpos + N * 0.9, 1.0);
    float3 sc = lp.xyz / lp.w;
    float2 suv = sc.xy * float2(0.5, -0.5) + 0.5;
    if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0 || sc.z > 1.0 || sc.z < 0.0) { return 1.0; }
    float texel = f.counts.w * f.shadowInfo.y;
    float sum = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            sum += tShadow.sample_compare(sShadow, suv + float2(i, j) * texel, sc.z - f.shadowInfo.z);
        }
    }
    return sum / 9.0;
}

static float3 pbrSpec(float3 N, float3 V, float3 L, float3 F0, float rough) {
    float3 H = normalize(L + V);
    float a = rough * rough;
    float a2 = a * a;
    float ndh = saturate(dot(N, H));
    float ndl = saturate(dot(N, L));
    float ndv = max(dot(N, V), 0.001);
    float vdh = saturate(dot(V, H));
    float d = ndh * ndh * (a2 - 1.0) + 1.0;
    float D = a2 / (3.14159265 * d * d + 1e-5);
    float k = (rough + 1.0) * (rough + 1.0) / 8.0;
    float G = (ndl / (ndl * (1.0 - k) + k)) * (ndv / (ndv * (1.0 - k) + k));
    float3 F = F0 + (float3(1.0) - F0) * pow(1.0 - vdh, 5.0);
    return D * G * F / (4.0 * ndv) ;
}

fragment float4 fs_main(VOut in [[stage_in]],
                        constant MatU& m [[buffer(0)]],
                        constant FrameU& f [[buffer(1)]],
                        texture2d<float> tDiff [[texture(0)]],
                        texture2d<float> tMul [[texture(1)]],
                        texture2d<float> tEnv [[texture(2)]],
                        depth2d<float> tShadow [[texture(3)]],
                        texture2d<float> tBump [[texture(4)]]) {
    float2 uvD = in.uv * m.uv.xy;
    float4 base = m.diffuse;
    if (m.flags.x > 0.5) { base *= tDiff.sample(sRep, uvD); }
    if (m.flags.z > 0.5) { base.rgb *= tMul.sample(sRep, in.uv).rgb; }
    else { base.rgb *= m.mulColor.rgb; }
    float alpha = base.a * m.params.x;
    float3 Nn = normalize(in.nrm);
    if (m.params.w < 1.5 && in.pos.z > 0.1 && m.flags2.y < 0.5) {
        if (abs(Nn.y) < 0.6) {
            // walls darken toward the ground like baked contact AO
            base.rgb *= mix(0.6, 1.0, smoothstep(0.0, 70.0, in.wpos.y));
        } else if (Nn.y > 0.6) {
            // large soft tonal variation on floors/tops so big flat areas don't read as one colour
            float2 q = in.wpos.xz * 0.012;
            float2 i = floor(q), fr = fract(q);
            fr = fr * fr * (3.0 - 2.0 * fr);
            float a = fract(sin(dot(i, float2(12.9898, 78.233))) * 43758.5453);
            float b = fract(sin(dot(i + float2(1, 0), float2(12.9898, 78.233))) * 43758.5453);
            float c = fract(sin(dot(i + float2(0, 1), float2(12.9898, 78.233))) * 43758.5453);
            float d = fract(sin(dot(i + float2(1, 1), float2(12.9898, 78.233))) * 43758.5453);
            float nz = mix(mix(a, b, fr.x), mix(c, d, fr.x), fr.y);
            base.rgb *= 0.88 + 0.2 * nz;
        }
    }

    float3 N = normalize(in.nrm);
    float3 V = normalize(f.camPos.xyz - in.wpos);
    if (m.flags2.x > 0.5 && dot(N, V) < 0.0) { N = -N; }
    if (f.shadowInfo.w > 0.5) {
        // low-poly look: every face is lit by its true face normal
        float3 fn = normalize(cross(dfdx(in.wpos), dfdy(in.wpos)));
        N = (dot(fn, V) < 0.0) ? -fn : fn;
    }

    int model = int(m.params.w + 0.5);
    float3 col;
    if (model == 2) {
        col = base.rgb + m.emission.rgb;
    } else {
        if (m.flags.y > 0.5) {
            float h = dot(tBump.sample(sRep, in.uv * m.uv.zw).rgb, float3(0.299, 0.587, 0.114));
            float3 dpx = dfdx(in.wpos), dpy = dfdy(in.wpos);
            float3 r1 = cross(dpy, N), r2 = cross(N, dpx);
            float det = dot(dpx, r1);
            float3 grad = sign(det) * (dfdx(h) * r1 + dfdy(h) * r2);
            N = normalize(abs(det) * N - m.params.z * 2.2 * grad);
        }
        float hemi = mix(0.5, 1.2, N.y * 0.5 + 0.5);
        float3 lightSum = f.ambient.rgb * hemi;
        // sky/horizon bounce: upward faces pick up the sky tint, downward faces a little warm ground light
        lightSum += f.fogColor.rgb * 0.10 * (N.y * 0.5 + 0.5) + f.ambient.rgb * 0.06 * (0.5 - N.y * 0.5);
        float3 spec = float3(0.0);
        bool useSpec = (model == 0) && (m.specular.w > 0.0);
        float specMax = max(m.specular.r, max(m.specular.g, m.specular.b));
        float metal = useSpec ? smoothstep(0.5, 0.95, specMax) : 0.0;
        float rough = clamp(sqrt(2.0 / (m.specular.w + 2.0)), 0.06, 1.0);
        float3 F0 = mix(float3(0.04) + m.specular.rgb * 0.08, base.rgb, metal);
        float shadow = 1.0;
        if (f.counts.z > 0.5) { shadow = shadowAt(f, tShadow, in.wpos, N); }
        int nd = int(f.counts.x + 0.5);
        for (int i = 0; i < nd; i++) {
            float3 L = f.dirDir[i].xyz;
            float ndl = max(dot(N, L), 0.0);
            float sh = (f.dirDir[i].w > 0.5) ? mix(1.0, shadow, f.shadowInfo.x) : 1.0;
            lightSum += f.dirCol[i].rgb * (ndl * sh);
            if (useSpec && ndl > 0.0) {
                spec += pbrSpec(N, V, L, F0, rough) * f.dirCol[i].rgb * (ndl * sh);
            }
        }
        // shadowed areas also lose a little ambient so they read as shade
        lightSum -= f.ambient.rgb * (1.0 - shadow) * f.shadowInfo.x * 0.35;
        int np = int(f.counts.y + 0.5);
        for (int i = 0; i < np; i++) {
            float3 d = f.ptPos[i].xyz - in.wpos;
            float dist = length(d);
            float att = saturate((f.ptCol[i].w - dist) / max(f.ptCol[i].w - f.ptPos[i].w, 1.0));
            float3 L = d / max(dist, 1e-4);
            float ndl = max(dot(N, L), 0.0);
            float3 lc = f.ptCol[i].rgb * (att * att);
            lightSum += lc * ndl;
            if (useSpec && ndl > 0.0) {
                spec += pbrSpec(N, V, L, F0, rough) * lc * ndl;
            }
        }
        col = base.rgb * (1.0 - 0.6 * metal) * max(lightSum, float3(0.0)) + spec + m.emission.rgb;
        if (metal > 0.05 && m.flags.w < 0.5) {
            // metals with no environment map reflect the sky/horizon colours
            float3 R0 = reflect(-V, N);
            float3 skyC = mix(f.fogColor.rgb * 0.7, f.ambient.rgb * 2.2 + f.dirCol[0].rgb * 0.15, saturate(R0.y * 0.5 + 0.5));
            float fr0 = pow(1.0 - max(dot(N, V), 0.0), 4.0);
            col += skyC * F0 * (0.35 + 0.65 * fr0) * (1.0 - rough * 0.6);
        }
        if (m.flags.w > 0.5) {
            float3 R = reflect(-V, N);
            float2 euv = float2(atan2(R.z, R.x) * 0.15915494 + 0.5, acos(clamp(R.y, -1.0, 1.0)) * 0.31830989);
            float3 env = tEnv.sample(sRep, euv).rgb;
            float fres = pow(1.0 - max(dot(N, V), 0.0), 3.0);
            col += env * m.params.y * (0.35 + 0.65 * fres);
        }
    }

    if (f.fogParams.z > 0.5) {
        float d = distance(f.camPos.xyz, in.wpos);
        float t = saturate((d - f.fogParams.x) / max(f.fogParams.y - f.fogParams.x, 1.0));
        t = pow(t, f.fogColor.w);
        col = mix(col, f.fogColor.rgb, t);
    }
    return float4(col, alpha);
}

// ---------------- full-screen helpers

struct FSOut {
    float4 pos [[position]];
    float2 uv;
};

vertex FSOut vs_full(uint vid [[vertex_id]]) {
    float2 p = float2(float((vid << 1) & 2), float(vid & 2));
    FSOut o;
    o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
    o.uv = float2(p.x, 1.0 - p.y);
    return o;
}

fragment float4 fs_sky(FSOut in [[stage_in]], texture2d<float> tSky [[texture(0)]], constant FrameU& f [[buffer(1)]]) {
    float4 clip = float4(in.uv.x * 2.0 - 1.0, 1.0 - in.uv.y * 2.0, 1.0, 1.0);
    float4 wp = f.invVP * clip;
    float3 dir = normalize(wp.xyz / wp.w - f.camPos.xyz);
    float up = saturate(dir.y);
    float v = 1.0 - pow(up, 0.55);
    float3 sky = tSky.sample(sClamp, float2(0.5, v)).rgb;
    // haze band that matches the distance fog
    float haze = pow(1.0 - up, 5.0);
    float3 col = mix(sky, f.fogColor.rgb, saturate(haze * 0.85));
    if (dir.y < 0.0) { col = mix(col, f.fogColor.rgb, saturate(-dir.y * 6.0)); }
    // sun glow
    float3 sd = normalize(f.dirDir[0].xyz);
    float sdot = saturate(dot(dir, sd));
    float3 sc = f.dirCol[0].rgb;
    col += sc * (pow(sdot, 900.0) * 14.0 + pow(sdot, 48.0) * 0.45 + pow(sdot, 6.0) * 0.12);
    return float4(col, 1.0);
}

fragment float4 fs_bright(FSOut in [[stage_in]],
                          texture2d<float> src [[texture(0)]],
                          constant float4& p [[buffer(0)]]) {
    float2 t = 1.0 / float2(src.get_width(), src.get_height());
    float3 c = src.sample(sClamp, in.uv + t * float2(-0.5, -0.5)).rgb
             + src.sample(sClamp, in.uv + t * float2(0.5, -0.5)).rgb
             + src.sample(sClamp, in.uv + t * float2(-0.5, 0.5)).rgb
             + src.sample(sClamp, in.uv + t * float2(0.5, 0.5)).rgb;
    c *= 0.25;
    float l = max(c.r, max(c.g, c.b));
    float k = saturate((l - p.x) / max(p.x * 0.6, 0.001));
    return float4(c * k, 1.0);
}

fragment float4 fs_blur(FSOut in [[stage_in]],
                        texture2d<float> src [[texture(0)]],
                        constant float4& p [[buffer(0)]]) {
    // p.xy = step in uv units
    const float w[5] = {0.2270270, 0.1945946, 0.1216216, 0.0540541, 0.0162162};
    float3 c = src.sample(sClamp, in.uv).rgb * w[0];
    for (int i = 1; i < 5; i++) {
        float2 o = p.xy * float(i);
        c += src.sample(sClamp, in.uv + o).rgb * w[i];
        c += src.sample(sClamp, in.uv - o).rgb * w[i];
    }
    return float4(c, 1.0);
}

static float3 aces(float3 x) {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), 0.0, 1.0);
}

static float3 toSRGB(float3 c) {
    c = clamp(c, 0.0, 1.0);
    float3 lo = c * 12.92;
    float3 hi = 1.055 * pow(c, float3(1.0 / 2.4)) - 0.055;
    return select(hi, lo, c <= 0.0031308);
}

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float dirtMask(float2 uv) {
    float s = 0.0, a = 0.5;
    float2 p = uv * float2(5.0, 3.0);
    for (int i = 0; i < 3; i++) {
        float2 ip = floor(p), fp = fract(p);
        fp = fp * fp * (3.0 - 2.0 * fp);
        float v = mix(mix(hash21(ip), hash21(ip + float2(1, 0)), fp.x), mix(hash21(ip + float2(0, 1)), hash21(ip + float2(1, 1)), fp.x), fp.y);
        s += v * a; a *= 0.5; p *= 2.1;
    }
    return smoothstep(0.35, 0.8, s);
}

fragment float4 fs_comp(FSOut in [[stage_in]],
                        texture2d<float> hdr [[texture(0)]],
                        texture2d<float> bloom [[texture(1)]],
                        constant float4& p0 [[buffer(0)]],
                        constant float4& p1 [[buffer(1)]],
                        constant float4& p2 [[buffer(2)]],
                        constant float4& p3 [[buffer(3)]]) {
    // p3: x lens dirt strength
    // p0: x bloom intensity, y saturation, z contrast, w tone map on
    // p1: x vignette intensity, y vignette power, z exposure, w bodycam strength
    // p2: x time, y aspect, zw target size
    float k = p1.w;
    float2 uv = in.uv;
    float3 c;
    float a;
    float edge = 1.0;
    if (k > 0.001) {
        // fisheye: normalise so the screen edge still maps inside the image
        float asp = max(p2.y, 0.5);
        float2 q = (uv - 0.5) * float2(asp, 1.0);
        float rmax = 0.25 * asp * asp + 0.25;
        float amt = 0.32 * k;
        float r2 = dot(q, q);
        float2 qd = q * (1.0 + amt * r2) / (1.0 + amt * rmax);
        float2 uvd = 0.5 + qd / float2(asp, 1.0);
        // chromatic fringing grows toward the edges
        float2 dir = normalize(q + 1e-5);
        float ca = 0.0035 * k * sqrt(r2);
        float2 uvr = clamp(uvd + dir * ca * float2(1.0 / asp, 1.0), 0.0, 1.0);
        float2 uvb = clamp(uvd - dir * ca * float2(1.0 / asp, 1.0), 0.0, 1.0);
        float4 sg = hdr.sample(sClamp, uvd);
        float3 raw = float3(hdr.sample(sClamp, uvr).r, sg.g, hdr.sample(sClamp, uvb).b);
        float3 bl = bloom.sample(sClamp, uvd).rgb * p0.x * (1.0 + p3.x * 2.2 * dirtMask(uv));
        c = (raw + bl) * p1.z * 1.12;
        a = sg.a;
        edge = 1.0;
    } else {
        float4 s = hdr.sample(sClamp, uv);
        c = s.rgb + bloom.sample(sClamp, uv).rgb * p0.x * (1.0 + p3.x * 2.2 * dirtMask(uv));
        c *= p1.z;
        a = s.a;
    }
    if (p0.w > 0.5) { c = aces(c); } else { c = saturate(c); }
    c = toSRGB(c);
    c = (c - 0.5) * (1.0 + p0.z) + 0.5;
    float l = dot(c, float3(0.299, 0.587, 0.114));
    c = mix(float3(l), c, p0.y);
    float2 q2 = uv - 0.5;
    float v = 1.0 - p1.x * pow(saturate(length(q2) * 1.45), p1.y);
    c *= clamp(v, 0.0, 1.0);
    if (k > 0.001) {
        float t = p2.x;
        // cheap sensor look: muted colour, cool-green cast, crushed blacks, clipped highlights
        float lm = dot(c, float3(0.299, 0.587, 0.114));
        c = mix(float3(lm), c, 0.8);
        c *= float3(0.97, 1.02, 0.98);
        c = (c - 0.04) * 1.08;
        // low-bitrate video: coarse blocks that shimmer, banded colour
        float2 blk = floor(uv * float2(p2.z, p2.w) / 14.0);
        float bn = hash21(blk + floor(t * 9.0));
        c *= 1.0 + (bn - 0.5) * 0.045 * k;
        c = floor(c * 40.0 + 0.5) / 40.0;
        // sensor grain and scanlines
        float g = hash21(uv * float2(p2.z, p2.w) * 0.5 + t * 37.0);
        c += (g - 0.5) * 0.085 * k * (1.1 - lm);
        c *= 0.965 + 0.035 * sin(uv.y * p2.w * 1.57);
        // tiny exposure flicker
        c *= 1.0 + 0.012 * sin(t * 23.0);
    }
    c = saturate(c);
    return float4(c * a, a);
}
"""#
}
