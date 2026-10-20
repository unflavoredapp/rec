import UIKit
import simd

// MX: the MainShot scene layer. A small retained scene graph (nodes, primitives, materials, lights,
// camera) that MXRenderer draws with Metal. It replaces SceneKit entirely.

// MARK: - value types

struct MXVector3 {
    var x: Float, y: Float, z: Float
    init(_ x: Float, _ y: Float, _ z: Float) { self.x = x; self.y = y; self.z = z }
    var simd: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}
let MXVector3Zero = MXVector3(0, 0, 0)

struct MXVector4 {
    var x: Float, y: Float, z: Float, w: Float
    init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) { self.x = x; self.y = y; self.z = z; self.w = w }
}

/// Only UV scaling is ever needed from the old SceneKit matrix.
struct MXMatrix4 {
    var sx: Float = 1
    var sy: Float = 1
}
func MXMatrix4MakeScale(_ x: Float, _ y: Float, _ z: Float) -> MXMatrix4 { MXMatrix4(sx: x, sy: y) }

enum MXLightingModel { case blinn, phong, lambert, constant, physicallyBased }
enum MXWrapMode { case `repeat`, clamp }
enum MXTransparencyMode { case aOne, rgbZero }
enum MXLightType { case ambient, directional, omni, spot }
enum MXAntialiasing { case none, multisampling2X, multisampling4X }
enum MXPrimitiveType { case triangles }

// MARK: - color helpers

enum MXColor {
    static func srgbToLinear(_ c: Float) -> Float { c <= 0.04045 ? c / 12.92 : powf((c + 0.055) / 1.055, 2.4) }

    /// linear RGBA from a UIColor / CGColor
    static func linear(_ any: Any?) -> SIMD4<Float>? {
        var ui: UIColor?
        if let u = any as? UIColor { ui = u }
        else if let anyObj = any, CFGetTypeID(anyObj as CFTypeRef) == CGColor.typeID { ui = UIColor(cgColor: anyObj as! CGColor) }
        guard let c = ui else { return nil }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if !c.getRed(&r, green: &g, blue: &b, alpha: &a) {
            var w: CGFloat = 0
            if c.getWhite(&w, alpha: &a) { r = w; g = w; b = w } else { r = 0.5; g = 0.5; b = 0.5; a = 1 }
        }
        return SIMD4<Float>(srgbToLinear(Float(r)), srgbToLinear(Float(g)), srgbToLinear(Float(b)), Float(a))
    }
}

// MARK: - materials

final class MXMaterialProperty {
    var contents: Any? { didSet { contentsChanged() } }
    var intensity: CGFloat = 1
    var wrapS: MXWrapMode = .repeat
    var wrapT: MXWrapMode = .repeat
    var contentsTransform = MXMatrix4()
    /// cached linear color when `contents` is a color
    private(set) var color: SIMD4<Float>? = nil
    /// cached image when `contents` is an image
    private(set) var image: UIImage? = nil
    var gen = 0

    init(_ c: Any? = nil) {
        contents = c
        contentsChanged()
    }

    private func contentsChanged() {
        gen += 1
        color = MXColor.linear(contents)
        if let i = contents as? UIImage { image = i } else { image = nil }
    }
}

final class MXMaterial {
    let diffuse = MXMaterialProperty(UIColor.white)
    let specular = MXMaterialProperty(UIColor.black)
    let emission = MXMaterialProperty(nil)
    let normal = MXMaterialProperty(nil)
    let reflective = MXMaterialProperty(nil)
    let multiply = MXMaterialProperty(nil)
    let ambient = MXMaterialProperty(nil)
    var lightingModel: MXLightingModel = .blinn
    var shininess: CGFloat = 1
    var transparency: CGFloat = 1
    var transparencyMode: MXTransparencyMode = .aOne
    var isDoubleSided = false
    /// light and occlusion are already in the textures: skip the shader's built-in wall/floor shading tricks
    var bakedLighting = false
    var writesToDepthBuffer = true
    var readsFromDepthBuffer = true
    init() {}
}

// MARK: - geometry

struct MXVertex {
    var px: Float, py: Float, pz: Float
    var nx: Float, ny: Float, nz: Float
    var u: Float, v: Float
}

final class MXMeshData {
    var verts: [MXVertex] = []
    var elems: [[UInt32]] = []
    var center = SIMD3<Float>(0, 0, 0)
    var radius: Float = 0
    var bmin = SIMD3<Float>(0, 0, 0)
    var bmax = SIMD3<Float>(0, 0, 0)

    func finish() {
        // make triangle winding agree with the vertex normals (counter-clockwise when seen from outside)
        for ei in 0..<elems.count {
            var idx = elems[ei]
            var t = 0
            while t + 2 < idx.count {
                let a = verts[Int(idx[t])], b = verts[Int(idx[t + 1])], c = verts[Int(idx[t + 2])]
                let e1 = SIMD3<Float>(b.px - a.px, b.py - a.py, b.pz - a.pz)
                let e2 = SIMD3<Float>(c.px - a.px, c.py - a.py, c.pz - a.pz)
                let fn = simd_cross(e1, e2)
                let vn = SIMD3<Float>(a.nx + b.nx + c.nx, a.ny + b.ny + c.ny, a.nz + b.nz + c.nz)
                if simd_dot(fn, vn) < 0 { idx.swapAt(t + 1, t + 2) }
                t += 3
            }
            elems[ei] = idx
        }
        guard let f = verts.first else { return }
        var mn = SIMD3<Float>(f.px, f.py, f.pz), mx = mn
        for v in verts {
            let p = SIMD3<Float>(v.px, v.py, v.pz)
            mn = simd_min(mn, p)
            mx = simd_max(mx, p)
        }
        bmin = mn; bmax = mx
        center = (mn + mx) * 0.5
        radius = simd_length(mx - mn) * 0.5
    }
}

class MXGeometry {
    var materials: [MXMaterial] = [] { didSet { } }
    var firstMaterial: MXMaterial? {
        get { materials.first }
        set { if let m = newValue { materials = [m] } else { materials = [] } }
    }
    var meshData: MXMeshData? = nil
    var gpuMesh: AnyObject? = nil
    /// global cap on round-shape segment counts (low-poly look); captured per geometry when it is created
    static var lowPolyCap = 64
    let capAtBuild = MXGeometry.lowPolyCap
    /// geometries with the same key share one GPU mesh and can be drawn instanced
    var cacheKey: String? { nil }

    init() {}

    func invalidate() { meshData = nil; gpuMesh = nil }
    func build() -> MXMeshData { MXMeshData() }

    func mesh() -> MXMeshData {
        if let m = meshData { return m }
        let m = build()
        m.finish()
        meshData = m
        return m
    }

    func material(for element: Int) -> MXMaterial? {
        if materials.isEmpty { return nil }
        return materials[min(element, materials.count - 1)]
    }
}

// MARK: primitives

private func pushQuadGrid(_ md: MXMeshData, _ elem: Int, rows: Int, cols: Int, base: Int) {
    var idx: [UInt32] = []
    for j in 0..<rows {
        for i in 0..<cols {
            let a = UInt32(base + j * (cols + 1) + i), b = a + 1, c = a + UInt32(cols + 1), d = c + 1
            idx += [a, c, b, b, c, d]
        }
    }
    while md.elems.count <= elem { md.elems.append([]) }
    md.elems[elem] += idx
}

final class MXBox: MXGeometry {
    var width: CGFloat { didSet { invalidate() } }
    var height: CGFloat { didSet { invalidate() } }
    var length: CGFloat { didSet { invalidate() } }
    var chamferRadius: CGFloat { didSet { invalidate() } }
    var chamferSegmentCount = 2 { didSet { invalidate() } }
    override var cacheKey: String? { "box|\(width)|\(height)|\(length)|\(chamferRadius)|\(chamferSegmentCount)" }

    init(width: CGFloat, height: CGFloat, length: CGFloat, chamferRadius: CGFloat) {
        self.width = width; self.height = height; self.length = length; self.chamferRadius = chamferRadius
        super.init()
    }

    override func build() -> MXMeshData {
        let md = MXMeshData()
        let half = SIMD3<Float>(Float(width) / 2, Float(height) / 2, Float(length) / 2)
        let rMax = min(half.x, min(half.y, half.z))
        let r = max(0, min(Float(chamferRadius), rMax * 0.98))
        // faces in SceneKit material order: front(+z) right(+x) back(-z) left(-x) top(+y) bottom(-y)
        // (normal axis, sign, u axis, u sign, v axis, v sign)
        let faces: [(Int, Float, Int, Float, Int, Float)] = [
            (2, 1, 0, 1, 1, -1), (0, 1, 2, -1, 1, -1), (2, -1, 0, -1, 1, -1),
            (0, -1, 2, 1, 1, -1), (1, 1, 0, 1, 2, 1), (1, -1, 0, 1, 2, -1)
        ]
        func samples(_ h: Float) -> [Float] {
            if r <= 0 { return [-h, h] }
            let k = max(1, chamferSegmentCount)
            var s: [Float] = []
            for i in 0...k { s.append(-h + r * Float(i) / Float(k)) }
            for i in 0...k { s.append(h - r + r * Float(i) / Float(k)) }
            return s
        }
        for (fi, f) in faces.enumerated() {
            let (n, ns, ua, us, va, vs) = f
            let sa = samples(half[ua]), sb = samples(half[va])
            let base = md.verts.count
            for cb in sb {
                for ca in sa {
                    var p = SIMD3<Float>(0, 0, 0)
                    p[n] = ns * half[n]; p[ua] = ca; p[va] = cb
                    var pos = p
                    var nrm = SIMD3<Float>(0, 0, 0)
                    nrm[n] = ns
                    if r > 0 {
                        let lo = -half + SIMD3<Float>(repeating: r), hi = half - SIMD3<Float>(repeating: r)
                        let inner = simd_clamp(p, lo, hi)
                        let d = p - inner
                        let l = simd_length(d)
                        if l > 1e-6 { nrm = d / l }
                        pos = inner + nrm * r
                    }
                    var u = (ca + half[ua]) / (2 * half[ua])
                    var v = (cb + half[va]) / (2 * half[va])
                    if us < 0 { u = 1 - u }
                    if vs < 0 { v = 1 - v }
                    md.verts.append(MXVertex(px: pos.x, py: pos.y, pz: pos.z, nx: nrm.x, ny: nrm.y, nz: nrm.z, u: u, v: v))
                }
            }
            pushQuadGrid(md, fi, rows: sb.count - 1, cols: sa.count - 1, base: base)
        }
        return md
    }
}

final class MXPlane: MXGeometry {
    var width: CGFloat { didSet { invalidate() } }
    var height: CGFloat { didSet { invalidate() } }
    override var cacheKey: String? { "plane|\(width)|\(height)" }
    init(width: CGFloat, height: CGFloat) { self.width = width; self.height = height; super.init() }

    override func build() -> MXMeshData {
        let md = MXMeshData()
        let w = Float(width) / 2, h = Float(height) / 2
        md.verts = [
            MXVertex(px: -w, py: h, pz: 0, nx: 0, ny: 0, nz: 1, u: 0, v: 0),
            MXVertex(px: w, py: h, pz: 0, nx: 0, ny: 0, nz: 1, u: 1, v: 0),
            MXVertex(px: -w, py: -h, pz: 0, nx: 0, ny: 0, nz: 1, u: 0, v: 1),
            MXVertex(px: w, py: -h, pz: 0, nx: 0, ny: 0, nz: 1, u: 1, v: 1)
        ]
        md.elems = [[0, 2, 1, 1, 2, 3]]
        return md
    }
}

/// shared lathe builder: profile of (radius, y, normal-r, normal-y, v)
private func lathe(_ md: MXMeshData, elem: Int, profile: [(Float, Float, Float, Float, Float)], segs: Int) {
    let base = md.verts.count
    for (r, y, nr, ny, v) in profile {
        for i in 0...segs {
            let a = Float(i) / Float(segs) * 2 * Float.pi
            let ca = cosf(a), sa = sinf(a)
            md.verts.append(MXVertex(px: r * ca, py: y, pz: r * sa, nx: nr * ca, ny: ny, nz: nr * sa, u: Float(i) / Float(segs), v: v))
        }
    }
    pushQuadGrid(md, elem, rows: profile.count - 1, cols: segs, base: base)
}

final class MXSphere: MXGeometry {
    var radius: CGFloat { didSet { invalidate() } }
    var segmentCount = 24 { didSet { invalidate() } }
    override var cacheKey: String? { "sph|\(radius)|\(segmentCount)|\(capAtBuild)" }
    init(radius: CGFloat) { self.radius = radius; super.init() }

    override func build() -> MXMeshData {
        let md = MXMeshData()
        let seg = max(5, min(capAtBuild, segmentCount))
        let rings = max(4, seg / 2)
        let r = Float(radius)
        var prof: [(Float, Float, Float, Float, Float)] = []
        for j in 0...rings {
            let t = Float(j) / Float(rings)
            let phi = Float.pi * t
            prof.append((r * sinf(phi), r * cosf(phi), sinf(phi), cosf(phi), t))
        }
        lathe(md, elem: 0, profile: prof, segs: seg)
        return md
    }
}

final class MXCylinder: MXGeometry {
    var radius: CGFloat { didSet { invalidate() } }
    var height: CGFloat { didSet { invalidate() } }
    var radialSegmentCount = 24 { didSet { invalidate() } }
    override var cacheKey: String? { "cyl|\(radius)|\(height)|\(radialSegmentCount)|\(capAtBuild)" }
    init(radius: CGFloat, height: CGFloat) { self.radius = radius; self.height = height; super.init() }

    override func build() -> MXMeshData {
        let md = MXMeshData()
        let r = Float(radius), h = Float(height) / 2
        let segs = max(5, min(capAtBuild, radialSegmentCount))
        lathe(md, elem: 0, profile: [(r, h, 1, 0, 0), (r, -h, 1, 0, 1)], segs: segs)
        lathe(md, elem: 1, profile: [(0, h, 0, 1, 0), (r, h, 0, 1, 1)], segs: segs)
        lathe(md, elem: 2, profile: [(r, -h, 0, -1, 0), (0, -h, 0, -1, 1)], segs: segs)
        return md
    }
}

final class MXCone: MXGeometry {
    var topRadius: CGFloat { didSet { invalidate() } }
    var bottomRadius: CGFloat { didSet { invalidate() } }
    var height: CGFloat { didSet { invalidate() } }
    var radialSegmentCount = 24 { didSet { invalidate() } }
    init(topRadius: CGFloat, bottomRadius: CGFloat, height: CGFloat) {
        self.topRadius = topRadius; self.bottomRadius = bottomRadius; self.height = height
        super.init()
    }

    override func build() -> MXMeshData {
        let md = MXMeshData()
        let rt = Float(topRadius), rb = Float(bottomRadius), h = Float(height) / 2
        let segs = max(5, min(capAtBuild, radialSegmentCount))
        let slope = (rb - rt) / (2 * h)
        let nl = sqrtf(1 + slope * slope)
        lathe(md, elem: 0, profile: [(rt, h, 1 / nl, slope / nl, 0), (rb, -h, 1 / nl, slope / nl, 1)], segs: segs)
        if rt > 0 { lathe(md, elem: 1, profile: [(0, h, 0, 1, 0), (rt, h, 0, 1, 1)], segs: segs) }
        if rb > 0 { lathe(md, elem: 2, profile: [(rb, -h, 0, -1, 0), (0, -h, 0, -1, 1)], segs: segs) }
        while md.elems.count < 3 { md.elems.append([]) }
        return md
    }
}

final class MXCapsule: MXGeometry {
    var capRadius: CGFloat { didSet { invalidate() } }
    var height: CGFloat { didSet { invalidate() } }
    var radialSegmentCount = 24 { didSet { invalidate() } }
    var capSegmentCount = 6 { didSet { invalidate() } }
    init(capRadius: CGFloat, height: CGFloat) { self.capRadius = capRadius; self.height = height; super.init() }

    override func build() -> MXMeshData {
        let md = MXMeshData()
        let r = Float(capRadius)
        let hh = max(Float(height) / 2 - r, 0)
        let caps = max(2, capSegmentCount)
        var prof: [(Float, Float, Float, Float, Float)] = []
        let total = Float(height)
        for j in 0...caps {
            let phi = Float.pi / 2 * Float(j) / Float(caps)
            let y = hh + r * cosf(phi)
            prof.append((r * sinf(phi), y, sinf(phi), cosf(phi), (Float(height) / 2 - y) / total))
        }
        for j in 0...caps {
            let phi = Float.pi / 2 + Float.pi / 2 * Float(j) / Float(caps)
            let y = -hh + r * cosf(phi)
            prof.append((r * sinf(phi), y, sinf(phi), cosf(phi), (Float(height) / 2 - y) / total))
        }
        lathe(md, elem: 0, profile: prof, segs: max(5, min(capAtBuild, radialSegmentCount)))
        return md
    }
}

final class MXTorus: MXGeometry {
    var ringRadius: CGFloat { didSet { invalidate() } }
    var pipeRadius: CGFloat { didSet { invalidate() } }
    var ringSegmentCount = 36 { didSet { invalidate() } }
    var pipeSegmentCount = 12 { didSet { invalidate() } }
    init(ringRadius: CGFloat, pipeRadius: CGFloat) { self.ringRadius = ringRadius; self.pipeRadius = pipeRadius; super.init() }

    override func build() -> MXMeshData {
        let md = MXMeshData()
        let R = Float(ringRadius), r = Float(pipeRadius)
        let rs = max(6, ringSegmentCount), ps = max(4, pipeSegmentCount)
        for i in 0...rs {
            let a = Float(i) / Float(rs) * 2 * Float.pi
            let ca = cosf(a), sa = sinf(a)
            for j in 0...ps {
                let b = Float(j) / Float(ps) * 2 * Float.pi
                let cb = cosf(b), sb = sinf(b)
                let nx = cb * ca, ny = sb, nz = cb * sa
                md.verts.append(MXVertex(px: (R + r * cb) * ca, py: r * sb, pz: (R + r * cb) * sa, nx: nx, ny: ny, nz: nz,
                                         u: Float(i) / Float(rs), v: Float(j) / Float(ps)))
            }
        }
        var idx: [UInt32] = []
        for i in 0..<rs {
            for j in 0..<ps {
                let a = UInt32(i * (ps + 1) + j), b = a + 1, c = a + UInt32(ps + 1), d = c + 1
                idx += [a, c, b, b, c, d]
            }
        }
        md.elems = [idx]
        return md
    }
}

final class MXTube: MXGeometry {
    var innerRadius: CGFloat { didSet { invalidate() } }
    var outerRadius: CGFloat { didSet { invalidate() } }
    var height: CGFloat { didSet { invalidate() } }
    var radialSegmentCount = 24 { didSet { invalidate() } }
    init(innerRadius: CGFloat, outerRadius: CGFloat, height: CGFloat) {
        self.innerRadius = innerRadius; self.outerRadius = outerRadius; self.height = height
        super.init()
    }

    override func build() -> MXMeshData {
        let md = MXMeshData()
        let ri = Float(innerRadius), ro = Float(outerRadius), h = Float(height) / 2
        let segs = max(5, min(capAtBuild, radialSegmentCount))
        lathe(md, elem: 0, profile: [(ro, h, 1, 0, 0), (ro, -h, 1, 0, 1)], segs: segs)
        lathe(md, elem: 1, profile: [(ri, h, -1, 0, 0), (ri, -h, -1, 0, 1)], segs: segs)
        lathe(md, elem: 2, profile: [(ri, h, 0, 1, 0), (ro, h, 0, 1, 1)], segs: segs)
        lathe(md, elem: 3, profile: [(ro, -h, 0, -1, 0), (ri, -h, 0, -1, 1)], segs: segs)
        return md
    }
}

final class MXGeometrySource {
    enum Kind { case vertex, normal, uv }
    let kind: Kind
    let floats: [Float]
    init(vertices: [MXVector3]) {
        kind = .vertex
        floats = vertices.flatMap { [$0.x, $0.y, $0.z] }
    }
    init(normals: [MXVector3]) {
        kind = .normal
        floats = normals.flatMap { [$0.x, $0.y, $0.z] }
    }
    init(textureCoordinates: [CGPoint]) {
        kind = .uv
        floats = textureCoordinates.flatMap { [Float($0.x), Float($0.y)] }
    }
}

final class MXGeometryElement {
    let indices: [UInt32]
    init(indices: [Int32], primitiveType: MXPrimitiveType) { self.indices = indices.map { UInt32($0) } }
    init(indices: [UInt32]) { self.indices = indices }
}

final class MXCustomGeometry: MXGeometry {
    private let data: MXMeshData
    init(data: MXMeshData) { self.data = data; super.init() }

    convenience init(sources: [MXGeometrySource], elements: [MXGeometryElement]) {
        let md = MXMeshData()
        let pos = sources.first { $0.kind == .vertex }?.floats ?? []
        let nrm = sources.first { $0.kind == .normal }?.floats ?? []
        let uv = sources.first { $0.kind == .uv }?.floats ?? []
        let n = pos.count / 3
        for i in 0..<n {
            md.verts.append(MXVertex(px: pos[i * 3], py: pos[i * 3 + 1], pz: pos[i * 3 + 2],
                                     nx: nrm.count >= (i + 1) * 3 ? nrm[i * 3] : 0,
                                     ny: nrm.count >= (i + 1) * 3 ? nrm[i * 3 + 1] : 1,
                                     nz: nrm.count >= (i + 1) * 3 ? nrm[i * 3 + 2] : 0,
                                     u: uv.count >= (i + 1) * 2 ? uv[i * 2] : 0,
                                     v: uv.count >= (i + 1) * 2 ? uv[i * 2 + 1] : 0))
        }
        md.elems = elements.map { $0.indices }
        self.init(data: md)
    }

    override func build() -> MXMeshData { data }
}
typealias MXGeometryCustom = MXCustomGeometry

// MARK: - lights, camera, scene

enum MXShadowMode { case forward, deferred, modulated }

final class MXLight {
    var shadowMode: MXShadowMode = .forward
    var type: MXLightType = .omni
    var intensity: CGFloat = 1000
    var color: Any = UIColor.white
    var castsShadow = false
    var shadowRadius: CGFloat = 3
    var shadowSampleCount = 8
    var shadowColor: Any = UIColor(white: 0, alpha: 0.5)
    var maximumShadowDistance: CGFloat = 100
    var attenuationStartDistance: CGFloat = 0
    var attenuationEndDistance: CGFloat = 0
    init() {}
}

final class MXCamera {
    var fieldOfView: CGFloat = 60
    var zNear: Double = 1
    var zFar: Double = 100
    var wantsHDR = false
    var bloomIntensity: CGFloat = 0
    var bloomThreshold: CGFloat = 0.5
    var bloomBlurRadius: CGFloat = 4
    var vignettingIntensity: CGFloat = 0
    var vignettingPower: CGFloat = 1
    var screenSpaceAmbientOcclusionIntensity: CGFloat = 0
    var screenSpaceAmbientOcclusionRadius: CGFloat = 0
    var saturation: CGFloat = 1
    var contrast: CGFloat = 0
    /// bodycam lens strength (0 = off) and animation clock, read by the composite pass
    var bodycam: CGFloat = 0
    var camTime: Float = 0
    /// scene exposure multiplier and lens-dirt strength on the bloom (0 = clean lens)
    var exposure: CGFloat = 1
    var lensDirt: CGFloat = 0
    init() {}
}

final class MXScene {
    let rootNode = MXNode()
    let background = MXMaterialProperty(nil)
    var fogColor: Any = UIColor.black
    var fogStartDistance: CGFloat = 0
    var fogEndDistance: CGFloat = 0
    var fogDensityExponent: CGFloat = 1
    init() {}
}

// MARK: - nodes

final class MXNode {
    var name: String? = nil
    var geometry: MXGeometry? = nil
    var light: MXLight? = nil
    var camera: MXCamera? = nil
    var isHidden = false
    var opacity: CGFloat = 1
    var castsShadow = true
    var renderingOrder = 0
    /// continuous yaw spin in rad/s (applied by the renderer)
    var spinY: Float = 0
    private(set) var childNodes: [MXNode] = []
    private(set) weak var parent: MXNode? = nil

    private var _pos = SIMD3<Float>(0, 0, 0)
    private var _scale = SIMD3<Float>(1, 1, 1)
    private var _rot = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    private var localCache = matrix_identity_float4x4
    private var localDirty = true

    // per-frame render state
    var world = matrix_identity_float4x4

    init(geometry: MXGeometry? = nil) { self.geometry = geometry }

    var position: MXVector3 {
        get { MXVector3(_pos.x, _pos.y, _pos.z) }
        set { _pos = SIMD3<Float>(newValue.x, newValue.y, newValue.z); localDirty = true }
    }

    var scale: MXVector3 {
        get { MXVector3(_scale.x, _scale.y, _scale.z) }
        set { _scale = SIMD3<Float>(newValue.x, newValue.y, newValue.z); localDirty = true }
    }

    /// quaternion as (x, y, z, w)
    var orientation: MXVector4 {
        get { MXVector4(_rot.imag.x, _rot.imag.y, _rot.imag.z, _rot.real) }
        set {
            let q = simd_quatf(ix: newValue.x, iy: newValue.y, iz: newValue.z, r: newValue.w)
            _rot = simd_length(q.vector) > 0 ? simd_normalize(q) : simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            localDirty = true
        }
    }

    /// pitch / yaw / roll; rotation order matches SceneKit (roll first, then yaw, then pitch)
    var eulerAngles: MXVector3 {
        get {
            let m = simd_float3x3(_rot)
            // R = Rx * Ry * Rz
            let sy = max(-1, min(1, m[2][0]))
            let y = asinf(sy)
            var x: Float, z: Float
            if abs(sy) < 0.9999 {
                x = atan2f(-m[2][1], m[2][2])
                z = atan2f(-m[1][0], m[0][0])
            } else {
                x = atan2f(m[1][2], m[1][1])
                z = 0
            }
            return MXVector3(x, y, z)
        }
        set {
            let qx = simd_quatf(angle: newValue.x, axis: SIMD3<Float>(1, 0, 0))
            let qy = simd_quatf(angle: newValue.y, axis: SIMD3<Float>(0, 1, 0))
            let qz = simd_quatf(angle: newValue.z, axis: SIMD3<Float>(0, 0, 1))
            _rot = simd_normalize(qx * qy * qz)
            localDirty = true
        }
    }

    var localTransform: simd_float4x4 {
        if localDirty {
            var m = simd_float4x4(_rot)
            m.columns.0 *= _scale.x
            m.columns.1 *= _scale.y
            m.columns.2 *= _scale.z
            m.columns.3 = SIMD4<Float>(_pos.x, _pos.y, _pos.z, 1)
            localCache = m
            localDirty = false
        }
        return localCache
    }

    func setLocalTransform(_ m: simd_float4x4) {
        let sx = simd_length(SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z))
        let sy = simd_length(SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z))
        let sz = simd_length(SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z))
        _pos = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
        _scale = SIMD3<Float>(sx, sy, sz)
        let r = simd_float3x3(columns: (
            SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z) / max(sx, 1e-6),
            SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z) / max(sy, 1e-6),
            SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z) / max(sz, 1e-6)))
        _rot = simd_normalize(simd_quatf(r))
        localDirty = true
    }

    // MARK: hierarchy

    func addChildNode(_ n: MXNode) {
        n.removeFromParentNode()
        n.parent = self
        childNodes.append(n)
    }

    func removeFromParentNode() {
        if let p = parent, let i = p.childNodes.firstIndex(where: { $0 === self }) { p.childNodes.remove(at: i) }
        parent = nil
    }

    func childNode(withName name: String, recursively: Bool) -> MXNode? {
        for c in childNodes {
            if c.name == name { return c }
            if recursively, let r = c.childNode(withName: name, recursively: true) { return r }
        }
        return nil
    }

    func worldTransform() -> simd_float4x4 {
        var m = localTransform
        var p = parent
        while let q = p { m = q.localTransform * m; p = q.parent }
        return m
    }

    var worldPosition: MXVector3 {
        let w = worldTransform().columns.3
        return MXVector3(w.x, w.y, w.z)
    }

    func convertPosition(_ v: MXVector3, to other: MXNode?) -> MXVector3 {
        let w = worldTransform() * SIMD4<Float>(v.x, v.y, v.z, 1)
        if let o = other {
            let l = simd_inverse(o.worldTransform()) * w
            return MXVector3(l.x, l.y, l.z)
        }
        return MXVector3(w.x, w.y, w.z)
    }

    /// orient so the node's -z axis points at a world-space target (up = +y)
    func look(at target: MXVector3) {
        let wp = worldTransform().columns.3
        let from = SIMD3<Float>(wp.x, wp.y, wp.z)
        var z = from - target.simd
        if simd_length(z) < 1e-6 { return }
        z = simd_normalize(z)
        var up = SIMD3<Float>(0, 1, 0)
        if abs(simd_dot(z, up)) > 0.9999 { up = SIMD3<Float>(0, 0, 1) }
        let x = simd_normalize(simd_cross(up, z))
        let y = simd_cross(z, x)
        var worldRot = simd_quatf(simd_float3x3(columns: (x, y, z)))
        if let p = parent {
            let pw = p.worldTransform()
            let pr = simd_float3x3(columns: (
                simd_normalize(SIMD3<Float>(pw.columns.0.x, pw.columns.0.y, pw.columns.0.z)),
                simd_normalize(SIMD3<Float>(pw.columns.1.x, pw.columns.1.y, pw.columns.1.z)),
                simd_normalize(SIMD3<Float>(pw.columns.2.x, pw.columns.2.y, pw.columns.2.z))))
            worldRot = simd_quatf(pr).inverse * worldRot
        }
        _rot = simd_normalize(worldRot)
        localDirty = true
    }

    // MARK: bounds

    /// local-space bounding box of this node's geometry and all visible descendants
    var boundingBox: (min: MXVector3, max: MXVector3) {
        var mn = SIMD3<Float>(repeating: .greatestFiniteMagnitude), mx = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        var any = false
        func visit(_ n: MXNode, _ m: simd_float4x4) {
            if let g = n.geometry {
                let md = g.mesh()
                if !md.verts.isEmpty {
                    for cx in [md.bmin.x, md.bmax.x] { for cy in [md.bmin.y, md.bmax.y] { for cz in [md.bmin.z, md.bmax.z] {
                        let p = m * SIMD4<Float>(cx, cy, cz, 1)
                        mn = simd_min(mn, SIMD3<Float>(p.x, p.y, p.z))
                        mx = simd_max(mx, SIMD3<Float>(p.x, p.y, p.z))
                        any = true
                    } } }
                }
            }
            for c in n.childNodes { visit(c, m * c.localTransform) }
        }
        visit(self, matrix_identity_float4x4)
        if !any { return (MXVector3Zero, MXVector3Zero) }
        return (MXVector3(mn.x, mn.y, mn.z), MXVector3(mx.x, mx.y, mx.z))
    }

    // MARK: copies

    /// deep copy of the hierarchy; geometry and materials are shared
    func clone() -> MXNode {
        let n = MXNode(geometry: geometry)
        n.name = name
        n.light = light
        n.camera = camera
        n.isHidden = isHidden
        n.opacity = opacity
        n.castsShadow = castsShadow
        n.renderingOrder = renderingOrder
        n._pos = _pos; n._scale = _scale; n._rot = _rot; n.localDirty = true
        for c in childNodes { n.addChildNode(c.clone()) }
        return n
    }

    /// bakes this node and all visible descendants into one node with one mesh per material
    func flattenedClone() -> MXNode {
        final class Bucket { var verts: [MXVertex] = []; var idx: [UInt32] = []; let mat: MXMaterial; init(_ m: MXMaterial) { mat = m } }
        var buckets: [ObjectIdentifier: Bucket] = [:]
        var order: [Bucket] = []
        func visit(_ n: MXNode, _ m: simd_float4x4) {
            if n.isHidden { return }
            if let g = n.geometry {
                let md = g.mesh()
                let nm = simd_transpose(simd_inverse(simd_float3x3(
                    SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                    SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                    SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z))))
                for (ei, el) in md.elems.enumerated() where !el.isEmpty {
                    guard let mat = g.material(for: ei) else { continue }
                    let key = ObjectIdentifier(mat)
                    let b: Bucket
                    if let e = buckets[key] { b = e } else { b = Bucket(mat); buckets[key] = b; order.append(b) }
                    var remap: [UInt32: UInt32] = [:]
                    for i in el {
                        if let r = remap[i] { b.idx.append(r); continue }
                        let v = md.verts[Int(i)]
                        let p = m * SIMD4<Float>(v.px, v.py, v.pz, 1)
                        var nn = nm * SIMD3<Float>(v.nx, v.ny, v.nz)
                        let l = simd_length(nn)
                        if l > 1e-8 { nn /= l }
                        let ni = UInt32(b.verts.count)
                        b.verts.append(MXVertex(px: p.x, py: p.y, pz: p.z, nx: nn.x, ny: nn.y, nz: nn.z, u: v.u, v: v.v))
                        remap[i] = ni
                        b.idx.append(ni)
                    }
                }
            }
            for c in n.childNodes { visit(c, m * c.localTransform) }
        }
        visit(self, matrix_identity_float4x4)
        let out = MXNode()
        out._pos = _pos; out._scale = _scale; out._rot = _rot; out.localDirty = true
        out.name = name
        out.castsShadow = castsShadow
        guard !order.isEmpty else { return out }
        let md = MXMeshData()
        var mats: [MXMaterial] = []
        for (ei, b) in order.enumerated() {
            let base = UInt32(md.verts.count)
            md.verts += b.verts
            md.elems.append(b.idx.map { $0 + base })
            mats.append(b.mat)
            _ = ei
        }
        let g = MXCustomGeometry(data: md)
        g.materials = mats
        out.geometry = g
        return out
    }
}
