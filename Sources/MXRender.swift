import UIKit
import Metal
import MetalKit
import simd

// MARK: - GPU mesh

final class MXGPUMesh {
    let vbuf: MTLBuffer
    var ibufs: [MTLBuffer?] = []
    var counts: [Int] = []
    let center: SIMD3<Float>
    let radius: Float

    init?(_ md: MXMeshData, device: MTLDevice) {
        guard !md.verts.isEmpty,
              let vb = md.verts.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }) else { return nil }
        vbuf = vb
        center = md.center
        radius = md.radius
        for e in md.elems {
            counts.append(e.count)
            if e.isEmpty { ibufs.append(nil) }
            else { ibufs.append(e.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }) }
        }
    }
}

// MARK: - shared device state

final class MXGPU {
    static let shared = MXGPU()

    let device: MTLDevice?
    let queue: MTLCommandQueue?
    var library: MTLLibrary?
    var error: String?
    let loader: MTKTextureLoader?
    let whiteTex: MTLTexture?
    let blackTex: MTLTexture?
    let dummyDepth: MTLTexture?

    private struct Pipes {
        var opaque: MTLRenderPipelineState?
        var blended: MTLRenderPipelineState?
        var sky: MTLRenderPipelineState?
        var opaqueI: MTLRenderPipelineState?
    }
    private var pipes: [Int: Pipes] = [:]
    var shadowPipe: MTLRenderPipelineState?
    var shadowInstPipe: MTLRenderPipelineState?
    var brightPipe: MTLRenderPipelineState?
    var blurPipe: MTLRenderPipelineState?
    private var compPipes: [UInt: MTLRenderPipelineState] = [:]

    let dsOpaque: MTLDepthStencilState?
    let dsNoWrite: MTLDepthStencilState?
    let dsNoRead: MTLDepthStencilState?

    private var texCache: [String: (UIImage, MTLTexture)] = [:]

    init() {
        let dev = MTLCreateSystemDefaultDevice()
        device = dev
        queue = dev?.makeCommandQueue()
        guard let d = dev else {
            loader = nil; whiteTex = nil; blackTex = nil; dummyDepth = nil
            dsOpaque = nil; dsNoWrite = nil; dsNoRead = nil
            error = "Metal is not available on this device"
            return
        }
        loader = MTKTextureLoader(device: d)

        func solid(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8) -> MTLTexture? {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
            let t = d.makeTexture(descriptor: td)
            var px: [UInt8] = [r, g, b, a]
            t?.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &px, bytesPerRow: 4)
            return t
        }
        whiteTex = solid(255, 255, 255, 255)
        blackTex = solid(0, 0, 0, 255)
        let dd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: 4, height: 4, mipmapped: false)
        dd.usage = [.renderTarget, .shaderRead]
        dd.storageMode = .private
        dummyDepth = d.makeTexture(descriptor: dd)

        func ds(_ cmp: MTLCompareFunction, _ write: Bool) -> MTLDepthStencilState? {
            let x = MTLDepthStencilDescriptor()
            x.depthCompareFunction = cmp
            x.isDepthWriteEnabled = write
            return d.makeDepthStencilState(descriptor: x)
        }
        dsOpaque = ds(.less, true)
        dsNoWrite = ds(.less, false)
        dsNoRead = ds(.always, false)

        do {
            library = try d.makeLibrary(source: MXShaderSource.source, options: nil)
        } catch {
            self.error = "Shader compile failed:\n\(error)"
        }
    }

    private func vertexDescriptor() -> MTLVertexDescriptor {
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3; vd.attributes[0].offset = 0; vd.attributes[0].bufferIndex = 0
        vd.attributes[1].format = .float3; vd.attributes[1].offset = 12; vd.attributes[1].bufferIndex = 0
        vd.attributes[2].format = .float2; vd.attributes[2].offset = 24; vd.attributes[2].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<MXVertex>.stride
        return vd
    }

    private func make(_ name: String, vs: String, fs: String?, color: MTLPixelFormat?, depth: Bool, samples: Int, blend: Bool = false, vertex: Bool = false) -> MTLRenderPipelineState? {
        guard let d = device, let lib = library, let v = lib.makeFunction(name: vs) else { return nil }
        let p = MTLRenderPipelineDescriptor()
        p.label = name
        p.vertexFunction = v
        if let f = fs { p.fragmentFunction = lib.makeFunction(name: f) }
        if vertex { p.vertexDescriptor = vertexDescriptor() }
        if let c = color {
            p.colorAttachments[0].pixelFormat = c
            if blend {
                let a = p.colorAttachments[0]!
                a.isBlendingEnabled = true
                a.sourceRGBBlendFactor = .sourceAlpha
                a.destinationRGBBlendFactor = .oneMinusSourceAlpha
                a.sourceAlphaBlendFactor = .one
                a.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }
        if depth { p.depthAttachmentPixelFormat = .depth32Float }
        p.rasterSampleCount = samples
        do { return try d.makeRenderPipelineState(descriptor: p) }
        catch {
            self.error = "Pipeline \(name) failed:\n\(error)"
            return nil
        }
    }

    func opaquePipe(samples: Int) -> MTLRenderPipelineState? {
        if pipes[samples] == nil { buildPipes(samples) }
        return pipes[samples]?.opaque
    }
    func blendedPipe(samples: Int) -> MTLRenderPipelineState? {
        if pipes[samples] == nil { buildPipes(samples) }
        return pipes[samples]?.blended
    }
    func opaqueInstPipe(samples: Int) -> MTLRenderPipelineState? {
        if pipes[samples] == nil { buildPipes(samples) }
        return pipes[samples]?.opaqueI
    }
    func skyPipe(samples: Int) -> MTLRenderPipelineState? {
        if pipes[samples] == nil { buildPipes(samples) }
        return pipes[samples]?.sky
    }

    private func buildPipes(_ s: Int) {
        var p = Pipes()
        p.opaque = make("opaque", vs: "vs_main", fs: "fs_main", color: .rgba16Float, depth: true, samples: s, vertex: true)
        p.blended = make("blended", vs: "vs_main", fs: "fs_main", color: .rgba16Float, depth: true, samples: s, blend: true, vertex: true)
        p.sky = make("sky", vs: "vs_full", fs: "fs_sky", color: .rgba16Float, depth: true, samples: s)
        p.opaqueI = make("opaqueI", vs: "vs_inst", fs: "fs_main", color: .rgba16Float, depth: true, samples: s, vertex: true)
        pipes[s] = p
        if shadowPipe == nil {
            shadowPipe = make("shadow", vs: "vs_shadow", fs: nil, color: nil, depth: true, samples: 1, vertex: true)
            shadowInstPipe = make("shadowI", vs: "vs_shadow_inst", fs: nil, color: nil, depth: true, samples: 1, vertex: true)
            brightPipe = make("bright", vs: "vs_full", fs: "fs_bright", color: .rgba16Float, depth: false, samples: 1)
            blurPipe = make("blur", vs: "vs_full", fs: "fs_blur", color: .rgba16Float, depth: false, samples: 1)
        }
    }

    func compositePipe(format: MTLPixelFormat) -> MTLRenderPipelineState? {
        if let c = compPipes[format.rawValue] { return c }
        let p = make("composite", vs: "vs_full", fs: "fs_comp", color: format, depth: false, samples: 1)
        if let p = p { compPipes[format.rawValue] = p }
        return p
    }

    /// uploads (and caches) an image as a Metal texture
    func texture(_ image: UIImage, srgb: Bool) -> MTLTexture? {
        let key = "\(UInt(bitPattern: ObjectIdentifier(image).hashValue))_\(srgb)"
        if let c = texCache[key], c.0 === image { return c.1 }
        guard let dev = device, let cg = image.cgImage else { return nil }
        // explicit RGBA8 upload: avoids any red/blue channel swap between CoreGraphics bitmaps and the texture format
        let w = cg.width, h = cg.height
        guard w > 0, h > 0, let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ok: Bool = data.withUnsafeMutableBytes { raw in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: srgb ? .rgba8Unorm_srgb : .rgba8Unorm, width: w, height: h, mipmapped: true)
        td.usage = .shaderRead
        guard let t = dev.makeTexture(descriptor: td) else { return nil }
        data.withUnsafeBytes { t.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: w * 4) }
        if let q = queue, let cb = q.makeCommandBuffer(), let bl = cb.makeBlitCommandEncoder() {
            bl.generateMipmaps(for: t)
            bl.endEncoding()
            cb.commit()
        }
        if texCache.count > 400 { texCache.removeAll() }
        texCache[key] = (image, t)
        return t
    }
}

// MARK: - view

final class MXView: UIView, MTKViewDelegate {
    var scene: MXScene?
    var pointOfView: MXNode?
    var antialiasingMode: MXAntialiasing = .multisampling4X
    var rendersContinuously = true
    var allowsCameraControl = false
    var isPlaying: Bool { get { !mtk.isPaused } set { mtk.isPaused = !newValue } }
    var preferredFramesPerSecond = 60 { didSet { mtk.preferredFramesPerSecond = preferredFramesPerSecond } }
    /// called once per frame before drawing (used for simple procedural animation)
    var preRender: ((Double) -> Void)?

    private let mtk: MTKView
    private let renderer = MXRenderer()
    private let errorLabel = UILabel()
    private(set) var lastViewProj = matrix_identity_float4x4

    override init(frame: CGRect) {
        mtk = MTKView(frame: frame, device: MXGPU.shared.device)
        super.init(frame: frame)
        mtk.colorPixelFormat = .bgra8Unorm
        mtk.framebufferOnly = true
        mtk.enableSetNeedsDisplay = false
        mtk.isPaused = false
        mtk.preferredFramesPerSecond = 60
        mtk.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mtk.contentScaleFactor = min(UIScreen.main.scale, MXRenderer.maxScale)
        mtk.delegate = self
        mtk.isOpaque = true
        addSubview(mtk)

        errorLabel.numberOfLines = 0
        errorLabel.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
        errorLabel.textColor = .systemRed
        errorLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        errorLabel.isHidden = true
        errorLabel.autoresizingMask = [.flexibleWidth]
        addSubview(errorLabel)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        mtk.frame = bounds
        errorLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: min(bounds.height, 260))
    }

    /// screen position (points) + depth (0...1) of a world point
    func projectPoint(_ p: MXVector3) -> MXVector3 {
        let c = lastViewProj * SIMD4<Float>(p.x, p.y, p.z, 1)
        if c.w <= 0.0001 { return MXVector3(0, 0, 2) }
        let n = SIMD3<Float>(c.x, c.y, c.z) / c.w
        let w = Float(bounds.width), h = Float(bounds.height)
        return MXVector3((n.x * 0.5 + 0.5) * w, (1 - (n.y * 0.5 + 0.5)) * h, n.z)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        if let e = MXGPU.shared.error {
            errorLabel.text = e
            errorLabel.isHidden = false
            return
        }
        guard let scene = scene, let pov = pointOfView, let cam = pov.camera else { return }
        preRender?(CACurrentMediaTime())
        let wantOpaque = scene.background.contents != nil
        if mtk.isOpaque != wantOpaque { mtk.isOpaque = wantOpaque }
        mtk.layer.isOpaque = wantOpaque
        let samples: Int
        switch antialiasingMode {
        case .none: samples = 1
        case .multisampling2X: samples = 2
        case .multisampling4X: samples = 4
        }
        if let vp = renderer.render(view: mtk, scene: scene, camNode: pov, camera: cam, samples: samples) { lastViewProj = vp }
    }
}

// MARK: - renderer

final class MXRenderer {
    static var maxScale: CGFloat = 2.0
    static var flatShade = false
    static var flipWinding: Bool = UserDefaults.standard.bool(forKey: "ms.mx.flip")
    static var shadowSize = 2048

    private let gpu = MXGPU.shared

    // targets
    private var tw = 0, th = 0, tSamples = 0
    private var msaaColor: MTLTexture?
    private var msaaDepth: MTLTexture?
    private var hdr: MTLTexture?
    private var bloom1: MTLTexture?
    private var bloom2: MTLTexture?
    private var bloom3: MTLTexture?
    private var shadowMap: MTLTexture?

    // scratch uniform memory
    private let frameU = UnsafeMutablePointer<SIMD4<Float>>.allocate(capacity: 44)
    private let nodeU = UnsafeMutablePointer<simd_float4x4>.allocate(capacity: 2)
    private let nodeI = UnsafeMutablePointer<simd_float4x4>.allocate(capacity: 64)
    private let matU = UnsafeMutablePointer<SIMD4<Float>>.allocate(capacity: 8)
    private let post0 = UnsafeMutablePointer<SIMD4<Float>>.allocate(capacity: 4)

    private struct Item {
        var mesh: MXGPUMesh
        var elem: Int
        var mat: MXMaterial
        var model: simd_float4x4
        var normalM: simd_float4x4
        var alpha: Float
        var order: Int
        var dist: Float
        var blended: Bool
        var matKey: Int
        var meshKey: Int = 0
    }

    private var opaque: [Item] = []
    private var blended: [Item] = []
    private var wOpaque: [Item] = []
    private var wBlended: [Item] = []
    private var shadowItems: [(MXGPUMesh, Int, simd_float4x4)] = []
    private var lightNodes: [(MXLight, simd_float4x4)] = []

    private var planes: [SIMD4<Float>] = []
    private var camPos = SIMD3<Float>(0, 0, 0)
    private var shadowFocus = SIMD3<Float>(0, 0, 0)
    private var shadowRange: Float = 0
    private var shadowOn = false

    deinit {
        frameU.deallocate(); nodeU.deallocate(); nodeI.deallocate(); matU.deallocate(); post0.deallocate()
    }

    // MARK: matrices

    private func perspective(_ fovy: Float, _ aspect: Float, _ n: Float, _ f: Float) -> simd_float4x4 {
        let y = 1 / tanf(fovy * 0.5), x = y / aspect
        let z = f / (n - f)
        return simd_float4x4(columns: (SIMD4<Float>(x, 0, 0, 0), SIMD4<Float>(0, y, 0, 0), SIMD4<Float>(0, 0, z, -1), SIMD4<Float>(0, 0, z * n, 0)))
    }

    private func ortho(_ l: Float, _ r: Float, _ b: Float, _ t: Float, _ n: Float, _ f: Float) -> simd_float4x4 {
        simd_float4x4(columns: (SIMD4<Float>(2 / (r - l), 0, 0, 0), SIMD4<Float>(0, 2 / (t - b), 0, 0),
                                SIMD4<Float>(0, 0, 1 / (n - f), 0), SIMD4<Float>(-(r + l) / (r - l), -(t + b) / (t - b), n / (n - f), 1)))
    }

    private func lookAt(_ eye: SIMD3<Float>, _ target: SIMD3<Float>, _ up0: SIMD3<Float>) -> simd_float4x4 {
        let z = simd_normalize(eye - target)
        var up = up0
        if abs(simd_dot(z, up)) > 0.999 { up = SIMD3<Float>(0, 0, 1) }
        let x = simd_normalize(simd_cross(up, z))
        let y = simd_cross(z, x)
        return simd_float4x4(columns: (SIMD4<Float>(x.x, y.x, z.x, 0), SIMD4<Float>(x.y, y.y, z.y, 0), SIMD4<Float>(x.z, y.z, z.z, 0),
                                       SIMD4<Float>(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1)))
    }

    private func row(_ m: simd_float4x4, _ i: Int) -> SIMD4<Float> {
        SIMD4<Float>(m.columns.0[i], m.columns.1[i], m.columns.2[i], m.columns.3[i])
    }

    private func buildPlanes(_ vp: simd_float4x4) {
        let r0 = row(vp, 0), r1 = row(vp, 1), r2 = row(vp, 2), r3 = row(vp, 3)
        var ps = [r3 + r0, r3 - r0, r3 + r1, r3 - r1, r2, r3 - r2]
        for i in 0..<ps.count {
            let l = simd_length(SIMD3<Float>(ps[i].x, ps[i].y, ps[i].z))
            if l > 0 { ps[i] /= l }
        }
        planes = ps
    }

    private func visible(_ c: SIMD3<Float>, _ r: Float) -> Bool {
        for p in planes {
            if p.x * c.x + p.y * c.y + p.z * c.z + p.w < -r { return false }
        }
        return true
    }

    // MARK: targets

    private func ensureTargets(_ w: Int, _ h: Int, _ samples: Int) {
        guard let d = gpu.device else { return }
        if w == tw && h == th && samples == tSamples && hdr != nil { return }
        tw = w; th = h; tSamples = samples
        func tex(_ fmt: MTLPixelFormat, _ w: Int, _ h: Int, _ usage: MTLTextureUsage, ms: Int = 1, memoryless: Bool = false) -> MTLTexture? {
            let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: fmt, width: max(1, w), height: max(1, h), mipmapped: false)
            td.usage = usage
            if ms > 1 { td.textureType = .type2DMultisample; td.sampleCount = ms }
            td.storageMode = memoryless ? .memoryless : .private
            return d.makeTexture(descriptor: td)
        }
        hdr = tex(.rgba16Float, w, h, [.renderTarget, .shaderRead])
        if samples > 1 {
            msaaColor = tex(.rgba16Float, w, h, .renderTarget, ms: samples, memoryless: true)
            msaaDepth = tex(.depth32Float, w, h, .renderTarget, ms: samples, memoryless: true)
        } else {
            msaaColor = nil
            msaaDepth = tex(.depth32Float, w, h, .renderTarget)
        }
        bloom1 = tex(.rgba16Float, w / 2, h / 2, [.renderTarget, .shaderRead])
        bloom2 = tex(.rgba16Float, w / 4, h / 4, [.renderTarget, .shaderRead])
        bloom3 = tex(.rgba16Float, w / 4, h / 4, [.renderTarget, .shaderRead])
    }

    private func ensureShadow() {
        guard let d = gpu.device else { return }
        if shadowMap != nil && shadowMap!.width == MXRenderer.shadowSize { return }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: MXRenderer.shadowSize, height: MXRenderer.shadowSize, mipmapped: false)
        td.usage = [.renderTarget, .shaderRead]
        td.storageMode = .private
        shadowMap = d.makeTexture(descriptor: td)
    }

    // MARK: scene gather

    private var meshCache: [String: MXGPUMesh] = [:]

    private func gpuMesh(_ g: MXGeometry) -> MXGPUMesh? {
        if let m = g.gpuMesh as? MXGPUMesh { return m }
        if let k = g.cacheKey, let m = meshCache[k] { g.gpuMesh = m; return m }
        guard let d = gpu.device, let m = MXGPUMesh(g.mesh(), device: d) else { return nil }
        g.gpuMesh = m
        if let k = g.cacheKey { meshCache[k] = m }
        return m
    }

    /// identical materials (same colours, textures and flags) hash the same so their draws can be merged
    private func matSig(_ m: MXMaterial) -> Int {
        var h = Hasher()
        func prop(_ p: MXMaterialProperty) {
            if let c = p.color { h.combine(c.x); h.combine(c.y); h.combine(c.z); h.combine(c.w) } else { h.combine(-1.0 as Float) }
            if let i = p.image { h.combine(ObjectIdentifier(i)) }
            h.combine(Float(p.intensity))
            h.combine(p.contentsTransform.sx)
            h.combine(p.contentsTransform.sy)
        }
        prop(m.diffuse); prop(m.normal); prop(m.multiply); prop(m.reflective); prop(m.emission); prop(m.specular)
        h.combine(Float(m.shininess))
        h.combine(Float(m.transparency))
        h.combine(m.lightingModel)
        h.combine(m.isDoubleSided)
        h.combine(m.writesToDepthBuffer)
        h.combine(m.readsFromDepthBuffer)
        return h.finalize()
    }

    private func normalMatrix(_ m: simd_float4x4) -> simd_float4x4 {
        let r = simd_float3x3(SIMD3<Float>(m.columns.0.x, m.columns.0.y, m.columns.0.z),
                              SIMD3<Float>(m.columns.1.x, m.columns.1.y, m.columns.1.z),
                              SIMD3<Float>(m.columns.2.x, m.columns.2.y, m.columns.2.z))
        let n = simd_transpose(simd_inverse(r))
        return simd_float4x4(columns: (SIMD4<Float>(n.columns.0, 0), SIMD4<Float>(n.columns.1, 0), SIMD4<Float>(n.columns.2, 0), SIMD4<Float>(0, 0, 0, 1)))
    }

    private var cullDist: Float = .infinity

    private func gather(_ n: MXNode, _ pw: simd_float4x4, _ op: Float, _ weapon: Bool, _ cam: MXNode) {
        if n.isHidden { return }
        var lt = n.localTransform
        if n.spinY != 0 {
            let a = n.spinY * Float(CACurrentMediaTime().truncatingRemainder(dividingBy: 1000))
            let c = cosf(a), sn = sinf(a)
            let r = simd_float4x4(columns: (SIMD4<Float>(c, 0, -sn, 0), SIMD4<Float>(0, 1, 0, 0), SIMD4<Float>(sn, 0, c, 0), SIMD4<Float>(0, 0, 0, 1)))
            lt = lt * r
        }
        let w = pw * lt
        n.world = w
        let o = op * Float(n.opacity)
        if let l = n.light { lightNodes.append((l, w)) }
        if let g = n.geometry, o > 0.003, let mesh = gpuMesh(g) {
            let c4 = w * SIMD4<Float>(mesh.center, 1)
            let c = SIMD3<Float>(c4.x, c4.y, c4.z)
            let sc = max(simd_length(SIMD3<Float>(w.columns.0.x, w.columns.0.y, w.columns.0.z)),
                         max(simd_length(SIMD3<Float>(w.columns.1.x, w.columns.1.y, w.columns.1.z)),
                             simd_length(SIMD3<Float>(w.columns.2.x, w.columns.2.y, w.columns.2.z))))
            let rad = mesh.radius * sc
            if shadowOn && n.castsShadow && !weapon {
                let dx = c.x - shadowFocus.x, dz = c.z - shadowFocus.z
                if dx * dx + dz * dz < shadowRange * shadowRange {
                    for e in 0..<mesh.counts.count where mesh.counts[e] > 0 {
                        if let m = g.material(for: e), m.writesToDepthBuffer, m.transparency >= 0.999, (m.diffuse.color?.w ?? 1) > 0.5 {
                            shadowItems.append((mesh, e, w))
                        }
                    }
                }
            }
            let dist = simd_length(c - camPos)
            if weapon || (dist - rad < cullDist && visible(c, rad)) {
                let nm = normalMatrix(w)
                for e in 0..<mesh.counts.count where mesh.counts[e] > 0 {
                    guard let m = g.material(for: e) else { continue }
                    let alpha = Float(m.transparency) * o * (m.diffuse.color?.w ?? 1)
                    if alpha <= 0.003 { continue }
                    let bl = alpha < 0.999 || !m.writesToDepthBuffer
                    let it = Item(mesh: mesh, elem: e, mat: m, model: w, normalM: nm, alpha: alpha, order: n.renderingOrder, dist: dist,
                                  blended: bl, matKey: matSig(m) &+ Int(alpha * 1000), meshKey: ObjectIdentifier(mesh).hashValue)
                    if weapon { if bl { wBlended.append(it) } else { wOpaque.append(it) } }
                    else { if bl { blended.append(it) } else { opaque.append(it) } }
                }
            }
        }
        let wp = weapon || n === cam
        for c in n.childNodes { gather(c, w, o, wp, cam) }
    }

    // MARK: material binding

    private func bind(_ enc: MTLRenderCommandEncoder, _ m: MXMaterial, alpha: Float) {
        let diff = m.diffuse.color ?? SIMD4<Float>(1, 1, 1, 1)
        var dTex: MTLTexture? = nil
        if let img = m.diffuse.image { dTex = gpu.texture(img, srgb: true) }
        var bTex: MTLTexture? = nil
        if let img = m.normal.image, m.normal.intensity > 0 { bTex = (img === m.diffuse.image) ? dTex : gpu.texture(img, srgb: false) }
        var mTex: MTLTexture? = nil
        if let img = m.multiply.image { mTex = gpu.texture(img, srgb: false) }
        var eTex: MTLTexture? = nil
        if let img = m.reflective.image, m.reflective.intensity > 0 { eTex = gpu.texture(img, srgb: true) }

        let em = m.emission.color ?? SIMD4<Float>(0, 0, 0, 0)
        let ei = Float(m.emission.intensity)
        let sp = m.specular.color ?? SIMD4<Float>(0, 0, 0, 1)
        let mul = m.multiply.color ?? SIMD4<Float>(1, 1, 1, 1)
        let model: Float
        switch m.lightingModel {
        case .blinn, .phong, .physicallyBased: model = 0
        case .lambert: model = 1
        case .constant: model = 2
        }
        let exponent = max(2, Float(m.shininess) * 128)
        let ds = m.diffuse.contentsTransform, bs = m.normal.contentsTransform
        matU[0] = SIMD4<Float>(diff.x, diff.y, diff.z, 1)   // alpha is applied via params.x
        matU[1] = SIMD4<Float>(em.x * ei, em.y * ei, em.z * ei, 0)
        matU[2] = SIMD4<Float>(sp.x, sp.y, sp.z, exponent)
        matU[3] = SIMD4<Float>(mul.x, mul.y, mul.z, 1)
        matU[4] = SIMD4<Float>(alpha / max(diff.w, 0.0001), Float(m.reflective.intensity), Float(m.normal.intensity), model)
        matU[5] = SIMD4<Float>(dTex != nil ? 1 : 0, bTex != nil ? 1 : 0, mTex != nil ? 1 : 0, eTex != nil ? 1 : 0)
        matU[6] = SIMD4<Float>(ds.sx, ds.sy, bs.sx, bs.sy)
        matU[7] = SIMD4<Float>(m.isDoubleSided ? 1 : 0, m.bakedLighting ? 1 : 0, 0, 0)
        enc.setFragmentBytes(matU, length: 8 * MemoryLayout<SIMD4<Float>>.stride, index: 0)
        enc.setFragmentTexture(dTex ?? gpu.whiteTex, index: 0)
        enc.setFragmentTexture(mTex ?? gpu.whiteTex, index: 1)
        enc.setFragmentTexture(eTex ?? gpu.whiteTex, index: 2)
        enc.setFragmentTexture(bTex ?? gpu.whiteTex, index: 4)
    }

    // MARK: render

    /// returns the view-projection matrix used for the frame
    func render(view mtk: MTKView, scene: MXScene, camNode: MXNode, camera: MXCamera, samples reqSamples: Int) -> simd_float4x4? {
        guard let drawable = mtk.currentDrawable else { return nil }
        return renderCore(target: drawable.texture, drawable: drawable, scene: scene, camNode: camNode, camera: camera, samples: reqSamples, wait: false)
    }

    func renderCore(target: MTLTexture, drawable: CAMetalDrawable?, scene: MXScene, camNode: MXNode, camera: MXCamera, samples reqSamples: Int, wait: Bool) -> simd_float4x4? {
        guard let dev = gpu.device, let queue = gpu.queue else { return nil }
        let W = target.width, H = target.height
        if W < 8 || H < 8 { return nil }
        let samples = (reqSamples > 1 && dev.supportsTextureSampleCount(reqSamples)) ? reqSamples : 1
        guard let opaquePipe = gpu.opaquePipe(samples: samples), let blendPipe = gpu.blendedPipe(samples: samples),
              let skyPipe = gpu.skyPipe(samples: samples), let compPipe = gpu.compositePipe(format: target.pixelFormat) else { return nil }
        ensureTargets(W, H, samples)
        guard let hdr = hdr, let depthTex = msaaDepth, let cmd = queue.makeCommandBuffer() else { return nil }

        // camera
        let camWorld = camNode.worldTransform()
        let view = simd_inverse(camWorld)
        let aspect = Float(W) / Float(H)
        let proj = perspective(Float(camera.fieldOfView) * Float.pi / 180, aspect, Float(camera.zNear), Float(camera.zFar))
        let vp = proj * view
        buildPlanes(vp)
        camPos = SIMD3<Float>(camWorld.columns.3.x, camWorld.columns.3.y, camWorld.columns.3.z)
        let fwd = simd_normalize(-SIMD3<Float>(camWorld.columns.2.x, camWorld.columns.2.y, camWorld.columns.2.z))

        // lights first (the shadow range decides which casters to collect)
        lightNodes.removeAll(keepingCapacity: true)
        opaque.removeAll(keepingCapacity: true); blended.removeAll(keepingCapacity: true)
        wOpaque.removeAll(keepingCapacity: true); wBlended.removeAll(keepingCapacity: true)
        shadowItems.removeAll(keepingCapacity: true)

        // pre-scan for the shadow-casting sun so casters outside the view are still collected
        var sunLight: (MXLight, simd_float4x4)? = nil
        func scanLights(_ n: MXNode, _ pw: simd_float4x4) {
            if n.isHidden { return }
            let w = pw * n.localTransform
            if let l = n.light, l.type == .directional, l.castsShadow, sunLight == nil { sunLight = (l, w) }
            for c in n.childNodes { scanLights(c, w) }
        }
        scanLights(scene.rootNode, matrix_identity_float4x4)
        shadowOn = sunLight != nil && MXRenderer.shadowSize > 0
        var lightVP = matrix_identity_float4x4
        if let (sl, sw) = sunLight, shadowOn {
            var t: Float = 300
            if fwd.y < -0.05 { t = min(-camPos.y / fwd.y, 900) }
            var focus = camPos + fwd * t
            focus.y = 0
            shadowFocus = focus
            shadowRange = min(Float(sl.maximumShadowDistance) * 0.6, 760)
            let toLight = simd_normalize(SIMD3<Float>(sw.columns.2.x, sw.columns.2.y, sw.columns.2.z))
            let eye = focus + toLight * 1600
            let lv = lookAt(eye, focus, SIMD3<Float>(0, 1, 0))
            let half = shadowRange * 1.15
            lightVP = ortho(-half, half, -half, half, 1, 3600) * lv
            ensureShadow()
        }

        cullDist = scene.fogEndDistance > scene.fogStartDistance ? Float(scene.fogEndDistance) * 1.1 : .infinity
        gather(scene.rootNode, matrix_identity_float4x4, 1, false, camNode)

        // sort
        opaque.sort {
            if $0.order != $1.order { return $0.order < $1.order }
            if $0.matKey != $1.matKey { return $0.matKey < $1.matKey }
            if $0.meshKey != $1.meshKey { return $0.meshKey < $1.meshKey }
            return $0.elem < $1.elem
        }
        shadowItems.sort {
            let a = ObjectIdentifier($0.0).hashValue, b = ObjectIdentifier($1.0).hashValue
            return a != b ? a < b : $0.1 < $1.1
        }
        blended.sort { $0.order != $1.order ? $0.order < $1.order : $0.dist > $1.dist }
        wOpaque.sort { $0.order != $1.order ? $0.order < $1.order : $0.matKey < $1.matKey }
        wBlended.sort { $0.order != $1.order ? $0.order < $1.order : $0.dist > $1.dist }

        // frame uniforms
        var amb = SIMD3<Float>(0, 0, 0)
        var dirs: [(SIMD3<Float>, SIMD3<Float>, Float)] = []
        var pts: [(SIMD3<Float>, SIMD3<Float>, Float, Float)] = []
        for (l, w) in lightNodes {
            let c = MXColor.linear(l.color) ?? SIMD4<Float>(1, 1, 1, 1)
            let col = SIMD3<Float>(c.x, c.y, c.z) * Float(l.intensity) / 1000
            switch l.type {
            case .ambient: amb += col
            case .directional:
                if dirs.count < 2 {
                    let d = simd_normalize(SIMD3<Float>(w.columns.2.x, w.columns.2.y, w.columns.2.z))
                    dirs.append((d, col, l.castsShadow && shadowOn ? 1 : 0))
                }
            case .omni, .spot:
                pts.append((SIMD3<Float>(w.columns.3.x, w.columns.3.y, w.columns.3.z), col, Float(l.attenuationStartDistance), Float(max(l.attenuationEndDistance, l.attenuationStartDistance + 1))))
            }
        }
        if pts.count > 8 {
            pts.sort { simd_distance($0.0, camPos) < simd_distance($1.0, camPos) }
            pts = Array(pts.prefix(8))
        }
        let fog = MXColor.linear(scene.fogColor) ?? SIMD4<Float>(0, 0, 0, 1)
        let fogOn: Float = scene.fogEndDistance > scene.fogStartDistance ? 1 : 0
        func put(_ i: Int, _ m: simd_float4x4) {
            frameU[i] = m.columns.0; frameU[i + 1] = m.columns.1; frameU[i + 2] = m.columns.2; frameU[i + 3] = m.columns.3
        }
        put(0, vp)
        put(4, lightVP)
        frameU[8] = SIMD4<Float>(camPos, 1)
        frameU[9] = SIMD4<Float>(fog.x, fog.y, fog.z, Float(max(0.1, scene.fogDensityExponent)))
        frameU[10] = SIMD4<Float>(Float(scene.fogStartDistance), Float(scene.fogEndDistance), fogOn, 0)
        frameU[11] = SIMD4<Float>(amb, 0)
        for i in 0..<2 {
            frameU[12 + i] = i < dirs.count ? SIMD4<Float>(dirs[i].0, dirs[i].2) : SIMD4<Float>(0, 1, 0, 0)
            frameU[14 + i] = i < dirs.count ? SIMD4<Float>(dirs[i].1, 0) : SIMD4<Float>(0, 0, 0, 0)
        }
        for i in 0..<8 {
            frameU[16 + i] = i < pts.count ? SIMD4<Float>(pts[i].0, pts[i].2) : SIMD4<Float>(0, 0, 0, 0)
            frameU[24 + i] = i < pts.count ? SIMD4<Float>(pts[i].1, pts[i].3) : SIMD4<Float>(0, 0, 0, 1)
        }
        frameU[32] = SIMD4<Float>(Float(dirs.count), Float(pts.count), shadowOn ? 1 : 0, 1 / Float(max(1, MXRenderer.shadowSize)))
        frameU[33] = SIMD4<Float>(0.72, 1.4, 0.0012, MXRenderer.flatShade ? 1 : 0)
        if let sl = sunLight?.0, let sc = MXColor.linear(sl.shadowColor) { frameU[33].x = max(0.2, min(1, sc.w)) }
        put(34, simd_inverse(vp))
        let frameBytes = 38 * MemoryLayout<SIMD4<Float>>.stride

        let winding: MTLWinding = MXRenderer.flipWinding ? .clockwise : .counterClockwise

        // ---- shadow pass
        if shadowOn, let sm = shadowMap, let sp = gpu.shadowPipe {
            let pd = MTLRenderPassDescriptor()
            pd.depthAttachment.texture = sm
            pd.depthAttachment.loadAction = .clear
            pd.depthAttachment.storeAction = .store
            pd.depthAttachment.clearDepth = 1
            if let enc = cmd.makeRenderCommandEncoder(descriptor: pd) {
                enc.setRenderPipelineState(sp)
                enc.setDepthStencilState(gpu.dsOpaque)
                enc.setFrontFacing(winding)
                enc.setCullMode(.front)   // render back faces into the map to avoid acne
                enc.setDepthBias(1.5, slopeScale: 2.5, clamp: 0.02)
                enc.setVertexBytes(frameU, length: frameBytes, index: 1)
                var instOn = false
                var si = 0
                while si < shadowItems.count {
                    let (mesh, e, _) = shadowItems[si]
                    var sj = si + 1
                    while sj < shadowItems.count && sj - si < 32 && shadowItems[sj].0 === mesh && shadowItems[sj].1 == e { sj += 1 }
                    defer { si = sj }
                    guard let ib = mesh.ibufs[e] else { continue }
                    let useInst = sj - si >= 2 && gpu.shadowInstPipe != nil
                    if useInst != instOn, let ip = gpu.shadowInstPipe {
                        enc.setRenderPipelineState(useInst ? ip : sp)
                        instOn = useInst
                    }
                    enc.setVertexBuffer(mesh.vbuf, offset: 0, index: 0)
                    if useInst {
                        var n = 0
                        for k in si..<sj {
                            nodeI[n * 2] = shadowItems[k].2
                            nodeI[n * 2 + 1] = matrix_identity_float4x4
                            n += 1
                        }
                        enc.setVertexBytes(nodeI, length: n * 2 * MemoryLayout<simd_float4x4>.stride, index: 2)
                        enc.drawIndexedPrimitives(type: .triangle, indexCount: mesh.counts[e], indexType: .uint32, indexBuffer: ib, indexBufferOffset: 0, instanceCount: n)
                    } else {
                        nodeU[0] = shadowItems[si].2
                        nodeU[1] = matrix_identity_float4x4
                        enc.setVertexBytes(nodeU, length: 2 * MemoryLayout<simd_float4x4>.stride, index: 2)
                        enc.drawIndexedPrimitives(type: .triangle, indexCount: mesh.counts[e], indexType: .uint32, indexBuffer: ib, indexBufferOffset: 0)
                    }
                }
                enc.endEncoding()
            }
        }

        // ---- main pass
        let pass = MTLRenderPassDescriptor()
        let hasBG = scene.background.contents != nil
        if samples > 1, let mc = msaaColor {
            pass.colorAttachments[0].texture = mc
            pass.colorAttachments[0].resolveTexture = hdr
            pass.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            pass.colorAttachments[0].texture = hdr
            pass.colorAttachments[0].storeAction = .store
        }
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.depthAttachment.texture = depthTex
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.storeAction = .dontCare
        guard let enc = cmd.makeRenderCommandEncoder(descriptor: pass) else { return nil }

        let full = MTLViewport(originX: 0, originY: 0, width: Double(hdr.width), height: Double(hdr.height), znear: 0.1, zfar: 1.0)
        enc.setViewport(full)
        enc.setFrontFacing(winding)

        if hasBG, let img = scene.background.image, let st = gpu.texture(img, srgb: true) {
            enc.setFragmentBytes(frameU, length: frameBytes, index: 1)
            enc.setRenderPipelineState(skyPipe)
            enc.setDepthStencilState(gpu.dsNoRead)
            enc.setCullMode(.none)
            enc.setFragmentTexture(st, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        } else if hasBG, let c = scene.background.color {
            // plain colour background: clear via a sky draw of the white texture tinted is overkill, use the clear colour instead
            _ = c
        }

        enc.setVertexBytes(frameU, length: frameBytes, index: 1)
        enc.setFragmentBytes(frameU, length: frameBytes, index: 1)
        enc.setFragmentTexture(shadowOn ? shadowMap : gpu.dummyDepth, index: 3)

        var lastPipe: MTLRenderPipelineState? = nil
        var lastDS: MTLDepthStencilState? = nil
        var lastCull: MTLCullMode? = nil

        func draw(_ it: Item) {
            guard let ib = it.mesh.ibufs[it.elem] else { return }
            let p = it.blended ? blendPipe : opaquePipe
            if lastPipe !== p { enc.setRenderPipelineState(p); lastPipe = p }
            let ds: MTLDepthStencilState?
            if !it.mat.readsFromDepthBuffer { ds = gpu.dsNoRead }
            else if !it.mat.writesToDepthBuffer || it.blended { ds = gpu.dsNoWrite }
            else { ds = gpu.dsOpaque }
            if lastDS !== ds { enc.setDepthStencilState(ds); lastDS = ds }
            let cull: MTLCullMode = it.mat.isDoubleSided ? .none : .back
            if lastCull != cull { enc.setCullMode(cull); lastCull = cull }
            nodeU[0] = it.model
            nodeU[1] = it.normalM
            enc.setVertexBuffer(it.mesh.vbuf, offset: 0, index: 0)
            enc.setVertexBytes(nodeU, length: 2 * MemoryLayout<simd_float4x4>.stride, index: 2)
            bind(enc, it.mat, alpha: it.alpha)
            enc.drawIndexedPrimitives(type: .triangle, indexCount: it.mesh.counts[it.elem], indexType: .uint32, indexBuffer: ib, indexBufferOffset: 0)
        }

        let instPipe = gpu.opaqueInstPipe(samples: samples)
        func drawInst(_ a: Int, _ b: Int) {
            let it = opaque[a]
            guard let ib = it.mesh.ibufs[it.elem], let ip = instPipe else { for k in a..<b { draw(opaque[k]) }; return }
            if lastPipe !== ip { enc.setRenderPipelineState(ip); lastPipe = ip }
            let ds: MTLDepthStencilState?
            if !it.mat.readsFromDepthBuffer { ds = gpu.dsNoRead }
            else if !it.mat.writesToDepthBuffer { ds = gpu.dsNoWrite }
            else { ds = gpu.dsOpaque }
            if lastDS !== ds { enc.setDepthStencilState(ds); lastDS = ds }
            let cull: MTLCullMode = it.mat.isDoubleSided ? .none : .back
            if lastCull != cull { enc.setCullMode(cull); lastCull = cull }
            var n = 0
            for k in a..<b {
                nodeI[n * 2] = opaque[k].model
                nodeI[n * 2 + 1] = opaque[k].normalM
                n += 1
            }
            enc.setVertexBuffer(it.mesh.vbuf, offset: 0, index: 0)
            enc.setVertexBytes(nodeI, length: n * 2 * MemoryLayout<simd_float4x4>.stride, index: 2)
            bind(enc, it.mat, alpha: it.alpha)
            enc.drawIndexedPrimitives(type: .triangle, indexCount: it.mesh.counts[it.elem], indexType: .uint32, indexBuffer: ib, indexBufferOffset: 0, instanceCount: n)
        }
        var oi = 0
        while oi < opaque.count {
            let it = opaque[oi]
            var oj = oi + 1
            while oj < opaque.count && oj - oi < 32 && opaque[oj].matKey == it.matKey && opaque[oj].meshKey == it.meshKey && opaque[oj].elem == it.elem && opaque[oj].order == it.order { oj += 1 }
            if oj - oi >= 2 { drawInst(oi, oj) } else { draw(it) }
            oi = oj
        }
        for it in blended { draw(it) }

        // first-person weapon: its own depth range so it never clips into walls
        if !wOpaque.isEmpty || !wBlended.isEmpty {
            enc.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(hdr.width), height: Double(hdr.height), znear: 0.0, zfar: 0.1))
            for it in wOpaque { draw(it) }
            for it in wBlended { draw(it) }
        }
        enc.endEncoding()

        // ---- bloom
        var bloomTex: MTLTexture? = gpu.blackTex
        let bloomOn = camera.wantsHDR && camera.bloomIntensity > 0.001 && bloom1 != nil && bloom2 != nil && bloom3 != nil
        if bloomOn, let b1 = bloom1, let b2 = bloom2, let b3 = bloom3, let bp = gpu.brightPipe, let blp = gpu.blurPipe {
            func fullPass(_ target: MTLTexture, _ pipe: MTLRenderPipelineState, _ src: MTLTexture, _ p: SIMD4<Float>) {
                let pd = MTLRenderPassDescriptor()
                pd.colorAttachments[0].texture = target
                pd.colorAttachments[0].loadAction = .dontCare
                pd.colorAttachments[0].storeAction = .store
                guard let e = cmd.makeRenderCommandEncoder(descriptor: pd) else { return }
                e.setRenderPipelineState(pipe)
                e.setFragmentTexture(src, index: 0)
                post0[0] = p
                e.setFragmentBytes(post0, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
                e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                e.endEncoding()
            }
            let rad = Float(max(1, camera.bloomBlurRadius)) / 6
            fullPass(b1, bp, hdr, SIMD4<Float>(Float(camera.bloomThreshold), 0, 0, 0))
            let sx = rad / Float(b2.width), sy = rad / Float(b2.height)
            fullPass(b2, blp, b1, SIMD4<Float>(sx, 0, 0, 0))
            fullPass(b3, blp, b2, SIMD4<Float>(0, sy, 0, 0))
            fullPass(b2, blp, b3, SIMD4<Float>(sx * 2, 0, 0, 0))
            fullPass(b3, blp, b2, SIMD4<Float>(0, sy * 2, 0, 0))
            bloomTex = b3
        }

        // ---- composite to the drawable
        let cd = MTLRenderPassDescriptor()
        cd.colorAttachments[0].texture = target
        cd.colorAttachments[0].loadAction = .dontCare
        cd.colorAttachments[0].storeAction = .store
        if let ce = cmd.makeRenderCommandEncoder(descriptor: cd) {
            ce.setRenderPipelineState(compPipe)
            ce.setFragmentTexture(hdr, index: 0)
            ce.setFragmentTexture(bloomTex, index: 1)
            post0[0] = SIMD4<Float>(bloomOn ? Float(camera.bloomIntensity) : 0, Float(camera.saturation == 0 ? 1 : camera.saturation), Float(camera.contrast), camera.wantsHDR ? 1 : 0)
            post0[1] = SIMD4<Float>(Float(camera.vignettingIntensity), Float(max(0.1, camera.vignettingPower)), Float(max(0.05, camera.exposure)), Float(camera.bodycam))
            post0[3] = SIMD4<Float>(Float(camera.lensDirt), 0, 0, 0)
            post0[2] = SIMD4<Float>(camera.camTime, Float(target.width) / Float(max(1, target.height)), Float(target.width), Float(target.height))
            ce.setFragmentBytes(post0, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
            ce.setFragmentBytes(post0 + 1, length: MemoryLayout<SIMD4<Float>>.stride, index: 1)
            ce.setFragmentBytes(post0 + 2, length: MemoryLayout<SIMD4<Float>>.stride, index: 2)
            ce.setFragmentBytes(post0 + 3, length: MemoryLayout<SIMD4<Float>>.stride, index: 3)
            ce.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            ce.endEncoding()
        }
        if let d = drawable { cmd.present(d) }
        cmd.commit()
        if wait { cmd.waitUntilCompleted() }
        return vp
    }
}


// MARK: - offscreen snapshots (used for 3D item thumbnails)

final class MXOffscreen {
    private let renderer = MXRenderer()

    /// Renders the scene into a transparent square image.
    func image(scene: MXScene, camNode: MXNode, size: Int, samples: Int = 4) -> UIImage? {
        guard let dev = MXGPU.shared.device, let cam = camNode.camera, MXGPU.shared.error == nil else { return nil }
        let td = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: size, height: size, mipmapped: false)
        td.usage = [.renderTarget, .shaderRead]
        td.storageMode = .shared
        guard let tex = dev.makeTexture(descriptor: td) else { return nil }
        guard renderer.renderCore(target: tex, drawable: nil, scene: scene, camNode: camNode, camera: cam, samples: samples, wait: true) != nil else { return nil }
        let bpr = size * 4
        var buf = [UInt8](repeating: 0, count: bpr * size)
        tex.getBytes(&buf, bytesPerRow: bpr, from: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0)
        let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let ctx = CGContext(data: &buf, width: size, height: size, bitsPerComponent: 8, bytesPerRow: bpr,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: info),
              let cg = ctx.makeImage() else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }
}
