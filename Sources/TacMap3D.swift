import SwiftUI
import UIKit

// MARK: - real 3D view of a workshop map (used by the map builder)

/// Builds the 3D model of one map tile. Plan units: one tile is 75 units (75 cm), walls are 80 high, +x east, +z south.
enum Map3DBuilder {
    static let ts: CGFloat = 75
    static let wallH: CGFloat = 80

    static func ui(_ c: Color) -> UIColor { UIColor(c) }

    private static func shade(_ c: UIColor, _ f: CGFloat) -> UIColor { TacGear.shade(c, f) }

    private static func slab(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ c: UIColor, glow: Bool = false) -> MXNode {
        let n = TwRig.box(w, h, l, c, glow: glow)
        n.position = MXVector3(Float(x), Float(y), Float(z))
        n.castsShadow = false
        return n
    }

    /// height of the object in plan units (cm)
    static func heightCm(_ d: TWorkshop.TileDef) -> CGFloat {
        switch d.k {
        case .wall, .edge: return wallH
        case .prop:
            switch d.pk {
            case .tree: return 98
            case .shelf: return 68
            case .car: return 41
            case .barrel: return 38
            case .sandbag: return 22
            case .table, .counter: return 30
            case .bed, .couch: return 22
            case .crate: return 30
            case .tv: return 24
            case .plant: return 30
            case .rock: return 30
            }
        case .spawn, .spawnA, .spawnD, .loot, .site: return 20
        default: return 0
        }
    }

    /// the full node for tile definition `d` whose cell starts at plan position (x0, z0)
    static func node(_ d: TWorkshop.TileDef, x0: CGFloat, z0: CGFloat, props: TwProps) -> MXNode {
        let g = MXNode()
        let c0 = ui(d.col)
        let floorC = ui(TWorkshop.matColor(8))
        let cx = x0 + ts / 2, cz = z0 + ts / 2
        switch d.k {
        case .floor:
            let fc = ui(TWorkshop.matColor(d.mat))
            g.addChildNode(slab(ts - 0.8, 4, ts - 0.8, cx, -2, cz, fc))
            // a few seams so wood / tile / slab read as materials
            let seam = shade(fc, 0.78)
            switch d.mat {
            case 4, 7, 14:   // planks
                for i in 0..<4 { g.addChildNode(slab(ts - 1, 0.25, 0.7, cx, 0.12, z0 + CGFloat(i) * ts / 4 + 1, seam)) }
            case 1, 5, 13, 16, 3:   // tiles
                g.addChildNode(slab(0.7, 0.25, ts - 1, cx, 0.12, cz, seam))
                g.addChildNode(slab(ts - 1, 0.25, 0.7, cx, 0.12, cz, seam))
            case 12:   // metal deck plate studs
                for (dx, dz) in [(-0.25, -0.25), (0.25, -0.25), (-0.25, 0.25), (0.25, 0.25)] as [(CGFloat, CGFloat)] {
                    g.addChildNode(slab(5, 0.6, 5, cx + dx * ts, 0.3, cz + dz * ts, shade(fc, 1.25)))
                }
            case 6:    // grass tufts
                for (dx, dz) in [(-0.3, -0.2), (0.25, 0.3), (0.1, -0.35), (-0.2, 0.28)] as [(CGFloat, CGFloat)] {
                    g.addChildNode(slab(3, 4, 3, cx + dx * ts, 2, cz + dz * ts, shade(fc, 1.3)))
                }
            default: break
            }
        case .water:
            let liquid = TWorkshop.liquidMats.contains(d.mat)
            let wc = ui(TWorkshop.matColor(d.mat))
            g.addChildNode(slab(ts - 0.4, 3, ts - 0.4, cx, -9, cz, shade(wc, 0.45)))
            let top = TwRig.box(ts - 0.4, 1.2, ts - 0.4, wc, glow: d.mat == 18 || d.mat == 19)
            top.position = MXVector3(Float(cx), -6.5, Float(cz))
            if liquid, let m = top.geometry?.materials.first { m.specular.contents = UIColor(white: 0.9, alpha: 1); m.shininess = 0.9 }
            g.addChildNode(top)
        case .bridge:
            let wc = ui(TWorkshop.matColor(9))
            g.addChildNode(slab(ts - 0.4, 3, ts - 0.4, cx, -9, cz, shade(wc, 0.45)))
            let deck = ui(TWorkshop.matColor(d.mat))
            g.addChildNode(slab(ts - 1, 3, ts - 1, cx, 2.5, cz, deck))
            for i in 0..<5 { g.addChildNode(slab(ts - 1, 0.4, 1.0, cx, 4.2, z0 + 6 + CGFloat(i) * 15.5, shade(deck, 0.72))) }
            for sx in [-1, 1] as [CGFloat] {
                g.addChildNode(slab(2.5, 14, 2.5, cx + sx * (ts / 2 - 3), 8, z0 + 4, shade(deck, 0.6)))
                g.addChildNode(slab(2.5, 14, 2.5, cx + sx * (ts / 2 - 3), 8, z0 + ts - 4, shade(deck, 0.6)))
                g.addChildNode(slab(1.5, 1.6, ts - 6, cx + sx * (ts / 2 - 3), 14, cz, shade(deck, 0.68)))
            }
        case .wall:
            g.addChildNode(slab(ts - 0.4, 4, ts - 0.4, cx, -2, cz, floorC))
            g.addChildNode(slab(ts - 0.4, wallH, ts - 0.4, cx, wallH / 2, cz, c0))
            g.addChildNode(slab(ts + 1.4, 3.5, ts + 1.4, cx, wallH + 1.7, cz, shade(c0, 1.15)))      // cap
            g.addChildNode(slab(ts + 0.6, 8, ts + 0.6, cx, 4, cz, shade(c0, 0.7)))                    // skirting
        case .edge:
            g.addChildNode(slab(ts - 0.4, 4, ts - 0.4, cx, -2, cz, floorC))
            for f in d.fr {
                let w = f.width * ts, l = f.height * ts
                let ex = x0 + f.midX * ts, ez = z0 + f.midY * ts
                g.addChildNode(slab(w, wallH, l, ex, wallH / 2, ez, c0))
                g.addChildNode(slab(w + 1.4, 3.5, l + 1.4, ex, wallH + 1.7, ez, shade(c0, 1.15)))
                g.addChildNode(slab(w + 0.6, 8, l + 0.6, ex, 4, ez, shade(c0, 0.7)))
            }
        case .prop:
            g.addChildNode(slab(ts - 0.4, 4, ts - 0.4, cx, -2, cz, floorC))
            let f = d.fr[0]
            let r = CGRect(x: x0 + f.minX * ts, y: z0 + f.minY * ts, width: f.width * ts, height: f.height * ts)
            g.addChildNode(TileArt.prop(d.pk, r) ?? props.build(d.pk, r))
        case .spawn, .spawnA, .spawnD:
            g.addChildNode(slab(ts - 0.4, 4, ts - 0.4, cx, -2, cz, floorC))
            let disc = TwRig.cyl(25, 1.4, c0)
            disc.position = MXVector3(Float(cx), 0.8, Float(cz))
            g.addChildNode(disc)
            let ring = TwRig.cyl(29, 0.8, shade(c0, 0.55))
            ring.position = MXVector3(Float(cx), 0.4, Float(cz))
            g.addChildNode(ring)
            let cone = TwRig.cone(7, 20, c0)
            cone.position = MXVector3(Float(cx), 30, Float(cz))
            cone.eulerAngles = MXVector3(Float.pi, 0, 0)
            g.addChildNode(cone)
        case .loot:
            g.addChildNode(slab(ts - 0.4, 4, ts - 0.4, cx, -2, cz, floorC))
            g.addChildNode(slab(30, 3, 30, cx, 1.5, cz, Color(white: 0.2).uiColor))
            let gem = TwRig.box(14, 14, 14, c0, glow: true)
            gem.position = MXVector3(Float(cx), 20, Float(cz))
            gem.eulerAngles = MXVector3(0.6, 0.78, 0.6)
            g.addChildNode(gem)
        case .site:
            g.addChildNode(slab(ts - 0.4, 4, ts - 0.4, cx, -2, cz, floorC))
            g.addChildNode(slab(ts - 8, 1.2, ts - 8, cx, 0.7, cz, c0, glow: true))
            for (sx, sz) in [(-1, -1), (1, -1), (-1, 1), (1, 1)] as [(CGFloat, CGFloat)] {
                g.addChildNode(slab(3, 16, 3, cx + sx * (ts / 2 - 7), 8, cz + sz * (ts / 2 - 7), shade(c0, 0.8)))
            }
            // block letter A / B laid flat on the pad
            let bar = shade(c0, 0.3)
            g.addChildNode(slab(4, 0.8, 26, cx - 9, 1.5, cz, bar))
            g.addChildNode(slab(4, 0.8, 26, cx + 9, 1.5, cz, bar))
            g.addChildNode(slab(22, 0.8, 4, cx, 1.5, cz - 11, bar))
            g.addChildNode(slab(22, 0.8, 4, cx, 1.5, cz, bar))
            if d.tag == "B" { g.addChildNode(slab(22, 0.8, 4, cx, 1.5, cz + 11, bar)) }
        }
        return g
    }
}

private extension Color {
    var uiColor: UIColor { UIColor(self) }
}

/// the editor talks to the 3D view through this (tap → cell lookup)
final class Map3DHandle {
    weak var view: MXView?
    let mw = TWorkshop.mw, mh = TWorkshop.mh

    /// cell under a screen point, found by projecting every ground cell to the screen
    func cell(at p: CGPoint) -> Int? {
        guard let v = view else { return nil }
        let ts = Map3DBuilder.ts
        func pr(_ x: CGFloat, _ z: CGFloat) -> CGPoint {
            let q = v.projectPoint(MXVector3(Float(x), 0, Float(z)))
            return CGPoint(x: CGFloat(q.x), y: CGFloat(q.y))
        }
        func inside(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
            let pts = [a, b, c, d]
            var sign = 0
            for i in 0..<4 {
                let p0 = pts[i], p1 = pts[(i + 1) % 4]
                let cr = (p1.x - p0.x) * (p.y - p0.y) - (p1.y - p0.y) * (p.x - p0.x)
                let s = cr > 0 ? 1 : -1
                if sign == 0 { sign = s } else if s != sign { return false }
            }
            return true
        }
        for r in 0..<mh {
            for c in 0..<mw {
                let x = CGFloat(c) * ts, z = CGFloat(r) * ts
                if inside(pr(x, z), pr(x + ts, z), pr(x + ts, z + ts), pr(x, z + ts)) { return r * mw + c }
            }
        }
        return nil
    }
}

struct MapView3D: UIViewRepresentable {
    let cells: [UInt8]
    let sel: Int?
    let yaw: Double        // degrees
    let pitch: Double      // degrees above the horizon
    let dist: Double
    let target: CGPoint    // plan x / z the camera looks at
    let handle: Map3DHandle

    final class Coord {
        let scene = MXScene()
        let cam = MXNode()
        let root = MXNode()
        let marker = MXNode()
        let props = TwProps()
        var nodes: [MXNode?] = Array(repeating: nil, count: TWorkshop.mw * TWorkshop.mh)
        var cached: [UInt8] = []
        var lastSel = -2
    }

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> MXView {
        let co = context.coordinator
        let v = MXView()
        v.backgroundColor = .black
        v.antialiasingMode = .multisampling4X
        v.isUserInteractionEnabled = false
        v.scene = co.scene
        let cam = co.cam
        cam.camera = MXCamera()
        cam.camera?.fieldOfView = 42
        cam.camera?.zNear = 8
        cam.camera?.zFar = 14000
        co.scene.rootNode.addChildNode(cam)
        v.pointOfView = cam

        let amb = MXNode()
        amb.light = MXLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 700
        co.scene.rootNode.addChildNode(amb)
        let sun = MXNode()
        sun.light = MXLight()
        sun.light?.type = .directional
        sun.light?.intensity = 950
        sun.eulerAngles = MXVector3(-0.9, 0.7, 0)
        co.scene.rootNode.addChildNode(sun)

        // ground under the whole map
        let ts = Map3DBuilder.ts
        let W = CGFloat(TWorkshop.mw) * ts, H = CGFloat(TWorkshop.mh) * ts
        let ground = TwRig.box(W + 160, 6, H + 160, UIColor(white: 0.08, alpha: 1))
        ground.position = MXVector3(Float(W / 2), -14, Float(H / 2))
        ground.castsShadow = false
        co.scene.rootNode.addChildNode(ground)
        co.scene.rootNode.addChildNode(co.root)
        co.scene.rootNode.addChildNode(co.marker)
        handle.view = v
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {
        let co = context.coordinator
        handle.view = v
        // camera orbit
        let a = Float(yaw * .pi / 180), p = Float(pitch * .pi / 180), d = Float(dist)
        let tx = Float(target.x), tz = Float(target.y)
        co.cam.position = MXVector3(tx + d * sin(a) * cos(p), d * sin(p), tz + d * cos(a) * cos(p))
        co.cam.look(at: MXVector3(tx, 0, tz))

        // changed cells only
        let n = TWorkshop.mw * TWorkshop.mh
        guard cells.count == n else { return }
        let ts = Map3DBuilder.ts
        for i in 0..<n {
            if co.cached.count == n && co.cached[i] == cells[i] { continue }
            co.nodes[i]?.removeFromParentNode()
            let c = i % TWorkshop.mw, r = i / TWorkshop.mw
            let nd = Map3DBuilder.node(TWorkshop.tile(Int(cells[i])), x0: CGFloat(c) * ts, z0: CGFloat(r) * ts, props: co.props)
            co.root.addChildNode(nd)
            co.nodes[i] = nd
        }
        co.cached = cells

        // selection frame
        let s = sel ?? -1
        if s != co.lastSel {
            co.lastSel = s
            co.marker.childNodes.forEach { $0.removeFromParentNode() }
            if s >= 0 && s < n {
                let c = CGFloat(s % TWorkshop.mw), r = CGFloat(s / TWorkshop.mw)
                let h = max(6, Map3DBuilder.heightCm(TWorkshop.tile(Int(cells[s])))) + 4
                let red = UIColor(red: 1, green: 0.1, blue: 0.2, alpha: 1)
                let cx = c * ts + ts / 2, cz = r * ts + ts / 2
                for (dx, dz, w, l) in [(0, -1, ts, 2.4), (0, 1, ts, 2.4), (-1, 0, 2.4, ts), (1, 0, 2.4, ts)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                    let b = TwRig.box(w + 2.4, 2.4, l, red, glow: true)
                    b.position = MXVector3(Float(cx + dx * ts / 2), Float(h), Float(cz + dz * ts / 2))
                    co.marker.addChildNode(b)
                }
            }
        }
    }
}

// MARK: - asset viewer (one tile, turntable, zoom)

struct AssetView3D: UIViewRepresentable {
    let tileId: Int
    let yaw: Double
    let zoom: Double

    final class Coord {
        let holder = MXNode()
        var last = -1
        var yaw: Float = 0
        var zoom: Float = 1
        let props = TwProps()
    }

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> MXView {
        let co = context.coordinator
        let v = MXView()
        v.backgroundColor = .black
        v.antialiasingMode = .multisampling4X
        v.isUserInteractionEnabled = false
        let sc = MXScene()
        v.scene = sc
        let cam = MXNode()
        cam.camera = MXCamera()
        cam.camera?.fieldOfView = 34
        cam.camera?.zNear = 2
        cam.camera?.zFar = 2000
        cam.position = MXVector3(130, 95, 150)
        sc.rootNode.addChildNode(cam)
        cam.look(at: MXVector3(0, 22, 0))
        v.pointOfView = cam
        let amb = MXNode(); amb.light = MXLight(); amb.light?.type = .ambient; amb.light?.intensity = 700
        sc.rootNode.addChildNode(amb)
        let sun = MXNode(); sun.light = MXLight(); sun.light?.type = .directional; sun.light?.intensity = 1000
        sun.eulerAngles = MXVector3(-0.7, 0.9, 0)
        sc.rootNode.addChildNode(sun)
        sc.rootNode.addChildNode(co.holder)
        v.preRender = { [weak co] t in
            guard let co = co else { return }
            co.holder.eulerAngles = MXVector3(0, co.yaw + Float(t) * 0.35, 0)
            co.holder.scale = MXVector3(co.zoom, co.zoom, co.zoom)
        }
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {
        let co = context.coordinator
        co.yaw = Float(yaw * .pi / 180)
        co.zoom = Float(zoom)
        if co.last == tileId { return }
        co.last = tileId
        co.holder.childNodes.forEach { $0.removeFromParentNode() }
        let ts = Map3DBuilder.ts
        let d = TWorkshop.tile(tileId)
        // centred on the origin so it turns on the spot
        co.holder.addChildNode(Map3DBuilder.node(d, x0: -ts / 2, z0: -ts / 2, props: co.props))
    }
}

// MARK: - Blender-made art: prop models and asset icons

enum TileArt {
    private static var icons: [String: UIImage?] = [:]
    private static var models: [String: MXNode?] = [:]

    static func slug(_ n: String) -> String {
        var out = ""
        var dash = false
        for ch in n.lowercased() {
            if ch.isLetter || ch.isNumber { if dash && !out.isEmpty { out += "_" }; out.append(ch); dash = false } else { dash = true }
        }
        return out
    }

    /// Blender-rendered icon for a tile (nil if the file isn't in the bundle)
    static func icon(_ name: String) -> UIImage? {
        let k = slug(name)
        if let c = icons[k] { return c }
        var img: UIImage? = nil
        if let u = Bundle.main.url(forResource: "ic_" + k, withExtension: "png") { img = UIImage(contentsOfFile: u.path) }
        icons[k] = img
        return img
    }

    private static let fileOf: [PropKind: (String, CGFloat)] = [
        .crate: ("crate", 70), .barrel: ("barrel", 36), .sandbag: ("sandbag", 75), .car: ("car", 75), .table: ("table", 65), .shelf: ("shelf", 75),
        .counter: ("counter", 75), .couch: ("couch", 67), .bed: ("bed", 71), .tv: ("tv", 37), .plant: ("plant", 30), .tree: ("tree", 60), .rock: ("rock", 45)
    ]

    /// the Blender model of a prop sized and turned to fill `r` (plan units); nil falls back to the code-built prop
    static func prop(_ k: PropKind, _ r: CGRect) -> MXNode? {
        guard let (file, base) = fileOf[k] else { return nil }
        var m = models[file] ?? nil
        if m == nil && models[file] == nil {
            m = MXModel.load("prop_" + file)
            models[file] = m
        }
        guard let src = m else { return nil }
        let wrap = MXNode()
        let s = Float(max(r.width, r.height) / base)
        let inner = src.clone()
        inner.scale = MXVector3(s, s, s)
        wrap.addChildNode(inner)
        wrap.position = MXVector3(Float(r.midX), 0, Float(r.midY))
        if r.height > r.width + 0.01 { wrap.eulerAngles = MXVector3(0, Float.pi / 2, 0) }
        return wrap
    }
}
