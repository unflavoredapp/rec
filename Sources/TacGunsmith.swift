import SwiftUI
import UIKit
import simd

// MARK: - camo patterns

struct TacSeedRNG {
    var s: UInt64
    init(_ seed: String) { s = 0x9E3779B97F4A7C15; for u in seed.unicodeScalars { s = (s ^ UInt64(u.value)) &* 0x100000001B3 } }
    mutating func next() -> UInt64 { s &+= 0x9E3779B97F4A7C15; var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
    mutating func f() -> CGFloat { CGFloat(next() % 100000) / 100000 }
}

enum TAttPattern {
    private static var cache: [String: UIImage] = [:]

    private static func ui(_ c: (CGFloat, CGFloat, CGFloat)) -> UIColor { UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1) }

    /// drops cached images of a throw-away (lab draft) camo
    static func forget(_ id: String) { cache[id] = nil; cache[id + "#g"] = nil; cache[id + "#gd"] = nil }

    /// camo tiled across the 512px atlas of a Blender-built gun so every UV island shows the pattern
    static func gunSkin(_ d: TAttDef, dark: Bool = false) -> UIImage? {
        let key = d.id + (dark ? "#gd" : "#g")
        if let c = cache[key] { return c }
        guard let tile = image(d) else { return nil }
        let n: CGFloat = 512, t: CGFloat = 170
        let img = UIGraphicsImageRenderer(size: CGSize(width: n, height: n)).image { _ in
            var y: CGFloat = 0
            while y < n {
                var x: CGFloat = 0
                while x < n { tile.draw(in: CGRect(x: x, y: y, width: t, height: t)); x += t }
                y += t
            }
            if dark {
                UIColor.black.withAlphaComponent(0.42).setFill()
                UIRectFillUsingBlendMode(CGRect(x: 0, y: 0, width: n, height: n), .normal)
            }
        }
        cache[key] = img
        return img
    }

    static func image(_ d: TAttDef) -> UIImage? {
        if d.pat == 0 { return nil }
        if let c = cache[d.id] { return c }
        guard let base = d.color else { return nil }
        let c1 = ui(base)
        let c2 = ui(d.c2 ?? (base.0 * 0.6, base.1 * 0.6, base.2 * 0.6))
        let c3 = ui(d.c3 ?? (base.0 * 0.35, base.1 * 0.35, base.2 * 0.35))
        let n: CGFloat = 128
        var rng = TacSeedRNG(d.id)
        let pat = d.pat
        let img = UIGraphicsImageRenderer(size: CGSize(width: n, height: n)).image { ctx in
            let g = ctx.cgContext
            c1.setFill()
            g.fill(CGRect(x: 0, y: 0, width: n, height: n))
            switch pat {
            case 1:
                for i in 0..<26 {
                    let w = 16 + rng.f() * 34, h = 10 + rng.f() * 22
                    let x = rng.f() * n, y = rng.f() * n
                    (i % 3 == 0 ? c3 : c2).setFill()
                    g.saveGState()
                    g.translateBy(x: x, y: y)
                    g.rotate(by: rng.f() * .pi)
                    g.fillEllipse(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
                    g.restoreGState()
                }
            case 2:
                let cell: CGFloat = 8
                let cols = Int(n / cell)
                var field = [[CGFloat]](repeating: [CGFloat](repeating: 0, count: cols), count: cols)
                for y in 0..<cols { for x in 0..<cols { field[y][x] = rng.f() } }
                for y in 0..<cols {
                    for x in 0..<cols {
                        var v = field[y][x]
                        v = (v + field[(y + 1) % cols][x] + field[y][(x + 1) % cols] + field[(y + cols - 1) % cols][x]) / 4
                        let col: UIColor = v < 0.40 ? c2 : (v > 0.58 ? c3 : c1)
                        col.setFill()
                        g.fill(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell))
                    }
                }
            case 3:
                var y: CGFloat = -20
                var k = 0
                while y < n + 20 {
                    let th = 6 + rng.f() * 9
                    let ph = rng.f() * 6
                    (k % 3 == 2 ? c3 : c2).setFill()
                    let p = UIBezierPath()
                    p.move(to: CGPoint(x: 0, y: y))
                    var x: CGFloat = 0
                    while x <= n { p.addLine(to: CGPoint(x: x, y: y + sin((x + ph * 20) / 14) * 6 + x * 0.25)); x += 4 }
                    x = n
                    while x >= 0 { p.addLine(to: CGPoint(x: x, y: y + th + sin((x + ph * 20) / 14) * 6 + x * 0.25)); x -= 4 }
                    p.close()
                    p.fill()
                    y += th + 7 + rng.f() * 8
                    k += 1
                }
            case 4:
                let cell: CGFloat = 4
                let cols = Int(n / cell)
                for y in 0..<cols { for x in 0..<cols {
                    let on = ((x / 2 + y / 2) % 2 == 0) != ((x + y) % 4 < 2)
                    (on ? c2 : c1).setFill()
                    g.fill(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell))
                } }
            default:
                for i in 0..<70 {
                    let r = 2 + rng.f() * (i < 14 ? 14 : 7)
                    (i % 7 == 0 ? c3 : c2).setFill()
                    g.fillEllipse(in: CGRect(x: rng.f() * n - r, y: rng.f() * n - r, width: r * 2, height: r * 2))
                }
            }
        }
        cache[d.id] = img
        return img
    }
}

// MARK: - attachment models

final class TAttNodes {
    var byId: [String: [MXNode]] = [:]
    func add(_ id: String, _ n: MXNode) { byId[id, default: []].append(n) }
    func apply(_ gun: String) {
        for (id, ns) in byId {
            guard let slot = TAtt.def(id)?.slot else { continue }
            let on = TAtt.eq(gun, slot).map { TAtt.visualId($0) } == id
            for n in ns { n.isHidden = !on }
        }
    }
}

enum TAttBuild {
    static let QG = MXVector4(0.017, 0.122, -0.002, 0.992)
    static let QB = MXVector4(0.714, 0.085, -0.088, 0.689)

    static func rot(_ q: MXVector4, _ v: SIMD3<Float>) -> SIMD3<Float> {
        let u = SIMD3<Float>(q.x, q.y, q.z)
        let t = 2 * simd_cross(u, v)
        return v + q.w * t + simd_cross(u, t)
    }

    static func qmul(_ a: MXVector4, _ b: MXVector4) -> MXVector4 {
        MXVector4(a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                  a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
                  a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
                  a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z)
    }

    static func qaxis(_ x: Float, _ y: Float, _ z: Float, _ ang: Float) -> MXVector4 {
        let s = sin(ang / 2)
        return MXVector4(x * s, y * s, z * s, cos(ang / 2))
    }

    static func mat(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, sp: CGFloat = 0.3, sh: CGFloat = 0.3, em: UIColor? = nil, constant: Bool = false, alpha: CGFloat = 1) -> MXMaterial {
        let m = MXMaterial()
        m.diffuse.contents = UIColor(red: r, green: g, blue: b, alpha: 1)
        m.specular.contents = UIColor(white: sp, alpha: 1)
        m.shininess = sh
        if constant { m.lightingModel = .constant }
        if let e = em { m.emission.contents = e }
        if alpha < 1 { m.transparency = alpha; m.writesToDepthBuffer = false; m.isDoubleSided = true }
        return m
    }

    private static func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ m: MXMaterial, _ p: SIMD3<Float>, _ q: MXVector4) -> MXNode {
        let n = MXNode(geometry: MXBox(width: w, height: h, length: l, chamferRadius: min(0.12, min(w, min(h, l)) * 0.3)))
        n.geometry?.firstMaterial = m
        n.position = MXVector3(p.x, p.y, p.z)
        n.orientation = q
        n.castsShadow = false
        return n
    }

    private static func cyl(_ r: CGFloat, _ h: CGFloat, _ m: MXMaterial, _ p: SIMD3<Float>, _ q: MXVector4) -> MXNode {
        let c = MXCylinder(radius: r, height: h)
        c.radialSegmentCount = 20
        let n = MXNode(geometry: c)
        n.geometry?.firstMaterial = m
        n.position = MXVector3(p.x, p.y, p.z)
        n.orientation = q
        n.castsShadow = false
        return n
    }

    private static func v3(_ a: [Double]) -> SIMD3<Float> { SIMD3<Float>(Float(a[0]), Float(a[1]), Float(a[2])) }

    /// builds every attachment model for one gun in gun space. `magHolder` (if given) carries the magazine pieces so they follow the reload animation.
    static func build(_ gid: String, into gun: MXNode, magHolder: MXNode?, order: Int = 0) -> TAttNodes {
        let out = TAttNodes()
        guard let rigs = TwGunLib.rigs, let rig = rigs[gid] as? [String: Any],
              let parts = rig["parts"] as? [[String: Any]], let mzA = rig["muzzle"] as? [Double], mzA.count == 3 else { return out }
        let mz = v3(mzA)
        let arm: Set<String> = ["glove", "sleeve", "sleeveDark", "knuckle", "strap", "skin", "nail"]
        func P(_ p: [String: Any]) -> SIMD3<Float> { v3((p["p"] as? [Double]) ?? [0, 0, 0]) }
        func S(_ p: [String: Any]) -> [Double] { (p["s"] as? [Double]) ?? [1, 1, 1] }
        func Q(_ p: [String: Any]) -> MXVector4 { let q = (p["q"] as? [Double]) ?? [0, 0, 0, 1]; return MXVector4(Float(q[0]), Float(q[1]), Float(q[2]), Float(q[3])) }
        let body = parts.filter { !arm.contains(($0["m"] as? String) ?? "") && ($0["t"] as? String) == "box" && S($0).count == 3 }

        // anchors
        func vol(_ p: [String: Any]) -> Double { let s = S(p); return s[0] * s[1] * s[2] }
        let hgc: [[String: Any]] = body.filter { P($0).z < mz.z * 0.3 && ($0["m"] as? String) != "dark" }
        let hg: [String: Any]? = hgc.max(by: { vol($0) < vol($1) })
        let rail: [String: Any]? = body.first(where: { S($0)[2] > 25 && S($0)[1] < 2.5 })
        let topBase: [String: Any]? = rail ?? hg
        var topPos = SIMD3<Float>(mz.x + 8, mz.y + 2, mz.z * 0.4)
        if let tb = topBase {
            let up = Float(S(tb)[1] / 2)
            topPos = P(tb) + rot(QG, SIMD3<Float>(0, up, 0))
        }
        if let tp = TwGunLib.gmeta[gid]?["top"] as? [Double], tp.count == 3 { topPos = v3(tp) }
        let lens = mat(0.2, 0.5, 0.8, sp: 0.9, sh: 0.8, alpha: 0.75)
        let metal = mat(0.16, 0.17, 0.19, sp: 0.9, sh: 0.55)
        let steel = mat(0.5, 0.52, 0.55, sp: 0.95, sh: 0.7)
        let blk = mat(0.05, 0.05, 0.055, sp: 0.35, sh: 0.3)
        let grp = mat(0.09, 0.09, 0.1, sp: 0.1, sh: 0.1)

        func at(_ base: SIMD3<Float>, _ local: SIMD3<Float>) -> SIMD3<Float> { base + rot(QG, local) }

        // ---- muzzle
        let fwd = rot(QB, SIMD3<Float>(0, -1, 0))
        let pistol = TWeapons.isPistol(gid)
        let sr: CGFloat = pistol ? 1.25 : 1.5
        let sl: Float = pistol ? 9 : 12
        let sc = mz + fwd * (sl / 2 - 2.2)
        let sup = MXNode()
        sup.addChildNode(cyl(sr, CGFloat(sl), metal, sc, QB))
        for i in 0..<4 {
            let t = Float(i) * 0.25 + 0.12
            sup.addChildNode(cyl(sr + 0.22, 0.45, steel, mz + fwd * (sl * t - 2.2 - sl * 0.0), QB))
        }
        sup.addChildNode(cyl(sr * 0.55, 0.3, blk, mz + fwd * (sl - 2.2 + 0.05), QB))
        sup.addChildNode(cyl(sr + 0.12, 0.7, steel, mz + fwd * (-1.4), QB))
        sup.isHidden = true
        gun.addChildNode(sup); out.add("sil", sup)

        let comp = MXNode()
        let cl: Float = 4.2
        comp.addChildNode(cyl(sr * 0.85, CGFloat(cl), metal, mz + fwd * (cl / 2 - 1.6), QB))
        for i in 0..<3 {
            let o = mz + fwd * (Float(i) * 1.1 - 0.4)
            comp.addChildNode(box(0.25, 0.9, 0.7, blk, o + rot(QG, SIMD3<Float>(0, Float(sr) * 0.82, 0)), QG))
            comp.addChildNode(box(0.9, 0.25, 0.7, blk, o + rot(QG, SIMD3<Float>(Float(sr) * 0.82, 0, 0)), QG))
            comp.addChildNode(box(0.9, 0.25, 0.7, blk, o + rot(QG, SIMD3<Float>(-Float(sr) * 0.82, 0, 0)), QG))
        }
        comp.addChildNode(cyl(sr * 0.9, 0.5, steel, mz + fwd * (cl - 1.6), QB))
        comp.isHidden = true
        gun.addChildNode(comp); out.add("comp", comp)

        // ---- optics
        let dot = MXNode()
        dot.addChildNode(box(2.0, 0.6, 4.6, blk, at(topPos, SIMD3<Float>(0, 0.3, 0)), QG))
        dot.addChildNode(box(2.4, 2.4, 3.8, metal, at(topPos, SIMD3<Float>(0, 1.8, 0.2)), QG))
        dot.addChildNode(box(0.3, 2.0, 3.4, blk, at(topPos, SIMD3<Float>(1.0, 1.9, 0.2)), QG))
        dot.addChildNode(box(0.3, 2.0, 3.4, blk, at(topPos, SIMD3<Float>(-1.0, 1.9, 0.2)), QG))
        dot.addChildNode(box(2.1, 0.2, 3.6, blk, at(topPos, SIMD3<Float>(0, 3.1, 0.2)), QG))
        let glass = box(1.9, 1.8, 0.12, lens, at(topPos, SIMD3<Float>(0, 1.9, 1.7)), QG)
        dot.addChildNode(glass)
        let dotM = mat(1, 0.1, 0.1, sp: 0, sh: 0, em: UIColor(red: 1, green: 0.1, blue: 0.1, alpha: 1), constant: true)
        let dn = MXNode(geometry: MXSphere(radius: 0.14))
        dn.geometry?.firstMaterial = dotM
        let dp = at(topPos, SIMD3<Float>(0, 1.9, 1.76))
        dn.position = MXVector3(dp.x, dp.y, dp.z)
        dn.castsShadow = false
        dot.addChildNode(dn)
        dot.isHidden = true
        gun.addChildNode(dot); out.add("dot", dot)

        let x4 = MXNode()
        let lift: Float = 3.0
        x4.addChildNode(box(2.2, 0.7, 6.5, blk, at(topPos, SIMD3<Float>(0, 0.35, 0)), QG))
        x4.addChildNode(box(1.6, CGFloat(lift), 1.0, metal, at(topPos, SIMD3<Float>(0, lift / 2, 3.2)), QG))
        x4.addChildNode(box(1.6, CGFloat(lift), 1.0, metal, at(topPos, SIMD3<Float>(0, lift / 2, -3.2)), QG))
        let tubeC = at(topPos, SIMD3<Float>(0, lift + 1.2, 0))
        x4.addChildNode(cyl(1.15, 11, metal, tubeC, QB))
        x4.addChildNode(cyl(1.7, 3.4, blk, at(topPos, SIMD3<Float>(0, lift + 1.2, -6.2)), QB))
        x4.addChildNode(cyl(1.5, 2.6, blk, at(topPos, SIMD3<Float>(0, lift + 1.2, 6.0)), QB))
        x4.addChildNode(cyl(1.5, 0.12, lens, at(topPos, SIMD3<Float>(0, lift + 1.2, -7.95)), QB))
        x4.addChildNode(cyl(1.25, 0.12, lens, at(topPos, SIMD3<Float>(0, lift + 1.2, 7.35)), QB))
        x4.addChildNode(box(0.8, 0.8, 1.0, steel, at(topPos, SIMD3<Float>(0, lift + 2.6, 0.5)), QG))
        x4.addChildNode(box(0.8, 0.8, 1.0, steel, at(topPos, SIMD3<Float>(1.5, lift + 1.2, 0.5)), QG))
        x4.isHidden = true
        gun.addChildNode(x4); out.add("x4", x4)

        // ---- grips
        var gBase = SIMD3<Float>(mz.x + 8, mz.y - 4, mz.z * 0.55)
        if let h = hg {
            let hs = S(h)
            let gy = -Float(hs[1] / 2)
            let gz = -Float(hs[2]) * 0.22
            gBase = P(h) + rot(QG, SIMD3<Float>(0, gy, gz))
        }
        let vg = MXNode()
        vg.addChildNode(box(2.4, 0.8, 3.4, blk, at(gBase, SIMD3<Float>(0, -0.3, 0)), QG))
        vg.addChildNode(cyl(1.05, 5.4, grp, at(gBase, SIMD3<Float>(0, -3.3, 0)), QG))
        vg.addChildNode(cyl(1.2, 0.5, steel, at(gBase, SIMD3<Float>(0, -6.1, 0)), QG))
        for i in 0..<4 { vg.addChildNode(cyl(1.12, 0.25, blk, at(gBase, SIMD3<Float>(0, -1.7 - Float(i) * 1.1, 0)), QG)) }
        vg.isHidden = true
        gun.addChildNode(vg); out.add("vgrip", vg)

        let ag = MXNode()
        let lean = qaxis(1, 0, 0, 0.55)
        let aq = qmul(QG, lean)
        ag.addChildNode(box(2.4, 0.8, 4.2, blk, at(gBase, SIMD3<Float>(0, -0.3, 0)), QG))
        ag.addChildNode(box(1.8, 5.2, 2.6, grp, at(gBase, SIMD3<Float>(0, -2.5, -1.3)), aq))
        ag.addChildNode(box(1.5, 0.4, 2.3, steel, at(gBase, SIMD3<Float>(0, -4.9, -2.2)), aq))
        ag.isHidden = true
        gun.addChildNode(ag); out.add("agrip", ag)

        // ---- magazines
        let magParts: [[String: Any]] = parts.filter { ($0["g"] as? String) == "mag" && ($0["t"] as? String) == "box" && S($0).count == 3 && !arm.contains(($0["m"] as? String) ?? "") }
        func area(_ p: [String: Any]) -> Double { let s = S(p); return s[1] * s[0] }
        if let mg = magParts.max(by: { area($0) < area($1) }) {
            let ms = S(mg), mp = P(mg), mq = Q(mg)
            let halfH = Float(ms[1] / 2)
            let msx = Float(ms[0])
            let holder = magHolder ?? gun
            let ext = MXNode()
            let w = CGFloat(ms[0]) + 0.35, l = CGFloat(ms[2]) + 0.35
            if ms[2] > 8 || ms[1] < 2.6 {
                // flat / top-fed magazines grow rearward
                let add: CGFloat = 7
                ext.addChildNode(box(CGFloat(ms[0]) + 0.3, CGFloat(ms[1]) + 0.3, CGFloat(ms[2]) + add, mat(0.14, 0.14, 0.16, sp: 0.5, sh: 0.4), mp + rot(mq, SIMD3<Float>(0, 0, Float(add) / 2)), mq))
            } else {
                let eh: CGFloat = 4.6
                let ehf = Float(eh)
                let bodyMat = mat(0.12, 0.12, 0.14, sp: 0.5, sh: 0.4)
                let o1 = SIMD3<Float>(0, -halfH - ehf / 2 + 0.3, 0.1)
                ext.addChildNode(box(w, eh, l, bodyMat, mp + rot(mq, o1), mq))
                let o2 = SIMD3<Float>(0, -halfH - ehf, 0.1)
                ext.addChildNode(box(w + 0.35, 0.55, l + 0.35, steel, mp + rot(mq, o2), mq))
                for i in 0..<3 {
                    let o3 = SIMD3<Float>(0, -halfH - 0.8 - Float(i) * 1.2, 0.1)
                    ext.addChildNode(box(w + 0.08, 0.12, l + 0.08, blk, mp + rot(mq, o3), mq))
                }
            }
            ext.isHidden = true
            holder.addChildNode(ext); out.add("mag_ext", ext)

            let drum = MXNode()
            let dq = qmul(mq, qaxis(0, 0, 1, Float.pi / 2))
            let dr: CGFloat = 4.6
            let drf = Float(dr)
            let dOff = SIMD3<Float>(0, -halfH - drf + 0.6, 0.1)
            let dc = mp + rot(mq, dOff)
            let side = rot(mq, SIMD3<Float>(msx / 2 + 0.8, 0, 0))
            let drumMat = mat(0.1, 0.1, 0.12, sp: 0.5, sh: 0.4)
            drum.addChildNode(cyl(dr, CGFloat(msx) + 1.4, drumMat, dc, dq))
            drum.addChildNode(cyl(dr + 0.15, 0.3, steel, dc + side, dq))
            drum.addChildNode(cyl(dr + 0.15, 0.3, steel, dc - side, dq))
            drum.addChildNode(cyl(1.3, CGFloat(msx) + 2.2, blk, dc, dq))
            for i in 0..<8 {
                let a = Float(i) / 8 * 2 * Float.pi
                let ro = SIMD3<Float>(0, cos(a) * drf, sin(a) * drf)
                drum.addChildNode(box(CGFloat(msx) + 1.5, 0.35, 0.9, blk, dc + rot(mq, ro), qmul(mq, qaxis(1, 0, 0, a))))
            }
            drum.isHidden = true
            holder.addChildNode(drum); out.add("mag_drum", drum)
        }
        if order != 0 {
            for ns in out.byId.values { for n in ns { n.renderingOrder = order; n.childNodes.forEach { $0.renderingOrder = order } } }
        }
        out.apply(gid)
        return out
    }
}

// MARK: - 3D preview

struct GunPreview3D: UIViewRepresentable {
    let gid: String
    let sig: String
    var yaw: Double = 0

    final class Coord {
        var last = ""
        let holder = MXNode()
        let spin = MXNode()
        var yaw: Float = 0
    }

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> MXView {
        let v = MXView()
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.isUserInteractionEnabled = false
        let sc = MXScene()
        v.scene = sc
        let cam = MXNode()
        cam.camera = MXCamera()
        cam.camera?.fieldOfView = 26
        cam.camera?.zNear = 1
        cam.camera?.zFar = 1000
        cam.position = MXVector3(200, 8, 26)
        sc.rootNode.addChildNode(cam)
        v.pointOfView = cam
        cam.look(at: MXVector3(0, 0, 0))
        let amb = MXNode()
        amb.light = MXLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 700
        sc.rootNode.addChildNode(amb)
        let sun = MXNode()
        sun.light = MXLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1100
        sun.eulerAngles = MXVector3(-0.7, 0.9, 0)
        sc.rootNode.addChildNode(sun)
        let rim = MXNode()
        rim.light = MXLight()
        rim.light?.type = .directional
        rim.light?.intensity = 500
        rim.eulerAngles = MXVector3(-0.3, -2.4, 0)
        sc.rootNode.addChildNode(rim)
        let c = context.coordinator
        c.spin.addChildNode(c.holder)
        sc.rootNode.addChildNode(c.spin)
        v.preRender = { [weak c] t in
            c?.spin.eulerAngles = MXVector3(0, (c?.yaw ?? 0) + Float(sin(t * 0.7)) * 0.38, 0)
        }
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {
        context.coordinator.yaw = Float(yaw)
        let key = gid + "#" + sig
        guard context.coordinator.last != key else { return }
        context.coordinator.last = key
        let h = context.coordinator.holder
        h.childNodes.forEach { $0.removeFromParentNode() }
        guard let rigs = TwGunLib.rigs, let rig = rigs[gid] as? [String: Any], let parts = rig["parts"] as? [[String: Any]] else { return }
        let arm: Set<String> = ["glove", "sleeve", "sleeveDark", "knuckle", "strap", "skin", "nail"]
        TwGunLib.setIdx = 2
        TwGunLib.load()
        let gun = MXNode()
        if let gg = TwGunLib.glbGun(gid, arms: false) {
            gun.addChildNode(gg.node)
        } else {
            for p in parts {
                if arm.contains((p["m"] as? String) ?? "") { continue }
                if let n = TwGunLib.makePart(p) { gun.addChildNode(n) }
            }
        }
        let att = TAttBuild.build(gid, into: gun, magHolder: nil)
        att.apply(gid)
        TAtt.applyCamo(gid, set: 2)
        TwGunLib.setIdx = 0
        // centre the gun (muzzle forward = -z) and turn it so the muzzle points right on screen
        let mz = (rig["muzzle"] as? [Double]) ?? [0, 0, -60]
        let cx = Float((mz[0] + 14) / 2), cy = Float((mz[1] - 4) / 2), cz = Float((mz[2] - 10) / 2)
        gun.position = MXVector3(-cx, -cy, -cz)
        h.addChildNode(gun)
        let len = Float(abs(mz[2]) + 10)
        let s = min(1.7, 112 / max(60, len))
        h.scale = MXVector3(s, s, s)
    }
}

// MARK: - Gunsmith screen (3D preview, try before you buy)

struct CSGunsmith: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let back: () -> Void
    @State private var gid = "rifle"
    @State private var slot: TAttSlot = .camo
    @State private var tick = 0
    @State private var yaw: Double = 0
    @State private var dragBase: Double = 0
    @State private var msg = ""

    private var ids: [String] { TWeapons.all.map { $0.id } }
    private let panel = Color(red: 0.045, green: 0.055, blue: 0.075).opacity(0.92)

    private func key(_ g: String, _ s: TAttSlot) -> String { "\(g)|\(s.rawValue)" }

    /// what is shown on the gun right now (the try-on if there is one, else what is equipped)
    private var shown: String? { TAtt.eq(gid, slot) }
    private var worn: String? { TAtt.realEq(gid, slot) }

    private func tryOn(_ id: String?) {
        TAtt.pv[key(gid, slot)] = id ?? ""
        msg = ""
        tick += 1
    }

    private func clearTry() {
        TAtt.pv = [:]
        tick += 1
    }

    private func commit() {
        let gems = game.s.ex.gems
        if let id = shown, let d = TAtt.def(id), !TAtt.owned.contains(id) {
            guard gems >= d.cost else { msg = "Not enough gems"; return }
            var st = game.s
            st.ex.gems -= d.cost
            game.s = st
            TAtt.own(id)
        }
        TAtt.setEq(gid, slot, shown)
        TAtt.pv[key(gid, slot)] = nil
        msg = ""
        tick += 1
    }

    private func stat(_ label: String, _ a: String, _ b: String, _ up: Bool?) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.6)).frame(width: 58, alignment: .leading)
            Text(a).font(.jk(11, .semibold)).foregroundColor(.white)
            if a != b {
                SF("arrow.right").font(.system(size: 8)).foregroundColor(.white.opacity(0.6))
                Text(b).font(.jk(11, .semibold)).foregroundColor(up == true ? Color(red: 0.4, green: 0.95, blue: 0.4) : (up == false ? TUI.red : .white))
            }
            Spacer(minLength: 0)
        }
    }

    private func gunRow(_ id: String) -> some View {
        let w = TWeapons.w(id)
        let on = gid == id
        return Button { gid = id; tick += 1 } label: {
            HStack(spacing: 6) {
                Rectangle().fill(on ? LS.orange : .clear).frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(w.name).font(.jk(11, .semibold)).foregroundColor(.white).lineLimit(1)
                    Text(w.cls.uppercased()).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.55))
                }
                Spacer(minLength: 0)
                if nav.tacGun == id { Text("USING").font(.jk(7, .heavy)).foregroundColor(.black).padding(.horizontal, 4).frame(height: 14).background(LS.orange) }
            }
            .padding(.trailing, 6).frame(height: 38)
            .background(on ? Color.white.opacity(0.1) : Color.black.opacity(0.45))
            .overlay(Rectangle().stroke(on ? Color.white.opacity(0.7) : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    @ViewBuilder private func optionRow(_ d: TAttDef?) -> some View {
        let isShown = d == nil ? shown == nil : shown == d?.id
        let isWorn = d == nil ? worn == nil : worn == d?.id
        let own = d == nil || TAtt.owned.contains(d?.id ?? "")
        Button { tryOn(d?.id) } label: {
            HStack(spacing: 8) {
                if let dd = d {
                    if let img = TAttPattern.image(dd) { Image(uiImage: img).resizable().frame(width: 28, height: 28).overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1)) }
                    else if let c = dd.color { Rectangle().fill(Color(red: c.0, green: c.1, blue: c.2)).frame(width: 28, height: 28).overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1)) }
                    else { SF(dd.slot.icon, "circle.fill").font(.system(size: 15, weight: .bold)).foregroundColor(.white.opacity(0.85)).frame(width: 28, height: 28).background(Color.white.opacity(0.1)) }
                } else {
                    SF("nosign").font(.system(size: 15)).foregroundColor(.white.opacity(0.6)).frame(width: 28, height: 28).background(Color.white.opacity(0.08))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(d?.name ?? "None").font(.jk(11, .semibold)).foregroundColor(.white).lineLimit(1)
                    if let d = d { Text(d.desc).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.6)).lineLimit(1) }
                }
                Spacer(minLength: 0)
                if isWorn { Text("ON").font(.jk(8, .heavy)).foregroundColor(.black).padding(.horizontal, 5).frame(height: 15).background(Color(red: 0.4, green: 0.95, blue: 0.4)) }
                else if let d = d, !own { HStack(spacing: 2) { SF("diamond.fill").font(.system(size: 8)); Text("\(d.cost)").font(.jk(9, .semibold)) }.foregroundColor(.white.opacity(0.7)) }
            }
            .padding(7).frame(maxWidth: .infinity)
            .background(Color.black.opacity(isShown ? 0.8 : 0.5))
            .overlay(Rectangle().stroke(isShown ? LS.orange : LS.line, lineWidth: isShown ? 1.5 : 1))
        }
        .buttonStyle(TuiPress())
    }

    private var actionLabel: String {
        if shown == worn { return worn == nil ? "NOTHING EQUIPPED" : "EQUIPPED" }
        guard let id = shown, let d = TAtt.def(id) else { return "REMOVE" }
        return TAtt.owned.contains(id) ? "EQUIP" : "BUY  \(d.cost) GEMS"
    }

    var body: some View {
        _ = tick
        let g = TWeapons.w(gid)
        let m = TAtt.mods(gid)
        let gems = game.s.ex.gems
        return GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            let lw: CGFloat = 130, rw = max(210, min(250, W * 0.28))
            let cw = W - lw - rw - 36
            ZStack(alignment: .topLeading) {
                // header
                HStack(spacing: 10) {
                    Button { clearTry(); back() } label: {
                        SF("chevron.left").font(.system(size: 16, weight: .bold)).foregroundColor(.white).frame(width: 34, height: 30).background(Color.white.opacity(0.12)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    }
                    .buttonStyle(TuiPress())
                    Text("GUNSMITH").font(.jk(20, .heavy)).foregroundColor(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(Color(red: 1, green: 0.7, blue: 0.1)).frame(width: 13, height: 13)
                        Text(gems.formatted()).font(.jk(12, .semibold)).foregroundColor(.white).monospacedDigit()
                    }
                }
                .padding(.horizontal, 14).frame(width: W, height: 44).background(LinearGradient(colors: [Color.black.opacity(0.7), .clear], startPoint: .top, endPoint: .bottom))
                // gun list
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 3) { ForEach(ids, id: \.self) { gunRow($0) } }
                }
                .frame(width: lw, height: H - 56)
                .offset(x: 10, y: 48)
                // centre: 3D preview, stats, slot tabs
                VStack(spacing: 5) {
                    GunPreview3D(gid: gid, sig: TAtt.viewSig(gid), yaw: yaw)
                        .frame(width: cw, height: max(110, H * 0.4))
                        .background(RadialGradient(colors: [Color(red: 0.2, green: 0.2, blue: 0.24).opacity(0.7), Color.black.opacity(0.45)], center: .center, startRadius: 5, endRadius: 220))
                        .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                        .overlay(alignment: .bottomTrailing) { Text("DRAG TO TURN").font(.jk(7, .semibold)).foregroundColor(.white.opacity(0.45)).padding(4) }
                        .contentShape(Rectangle())
                        .gesture(DragGesture().onChanged { v in yaw = dragBase + Double(v.translation.width) * 0.012 }.onEnded { _ in dragBase = yaw })
                    Text(g.name).font(.jk(16, .heavy)).foregroundColor(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        stat("DAMAGE", "\(Int(g.dmg * CGFloat(g.pellets)))", "\(Int(g.dmg * CGFloat(g.pellets) * m.dmgMul))", m.dmgMul >= 1 ? (m.dmgMul > 1 ? true : nil) : false)
                        stat("RANGE", "\(Int(g.range))", "\(Int(g.range * m.rangeMul))", m.rangeMul > 1 ? true : nil)
                        stat("MAGAZINE", "\(g.mag)", "\(Int(CGFloat(g.mag) * m.magMul))", m.magMul > 1 ? true : nil)
                        stat("RECOIL", "100%", "\(Int(m.recoilMul * 100))%", m.recoilMul < 1 ? true : nil)
                        stat("RELOAD", String(format: "%.1fs", g.reload), String(format: "%.1fs", g.reload * m.reloadMul), m.reloadMul < 1 ? true : (m.reloadMul > 1 ? false : nil))
                        stat("NOISE", "LOUD", m.silenced ? "SILENT" : "LOUD", m.silenced ? true : nil)
                    }
                    .padding(7).frame(width: cw).background(panel).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    HStack(spacing: 3) {
                        ForEach(TAttSlot.allCases, id: \.self) { s in
                            Button { slot = s; tick += 1 } label: {
                                VStack(spacing: 1) {
                                    SF(s.icon, "circle.fill").font(.system(size: 13, weight: .bold))
                                    Text(s.title).font(.jk(7, .semibold))
                                }
                                .foregroundColor(slot == s ? .black : .white)
                                .frame(maxWidth: .infinity).frame(height: 34)
                                .background(Rectangle().fill(slot == s ? LS.orange : Color.white.opacity(0.1)))
                                .overlay(alignment: .topTrailing) { if TAtt.eq(gid, s) != nil { Circle().fill(Color.green).frame(width: 6, height: 6).padding(3) } }
                            }
                            .buttonStyle(TuiPress())
                        }
                    }
                    .frame(width: cw)
                }
                .offset(x: lw + 22, y: 48)
                // options + action
                VStack(spacing: 5) {
                    HStack {
                        Text(slot.title).font(.jk(13, .heavy)).foregroundColor(.white)
                        Spacer()
                        Text("TAP TO TRY ON").font(.jk(8, .semibold)).foregroundColor(LS.orange)
                    }
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            optionRow(nil)
                            ForEach(TAtt.defs.filter { $0.slot == slot }, id: \.id) { d in optionRow(d) }
                        }
                    }
                    if !msg.isEmpty { Text(msg).font(.jk(9, .semibold)).foregroundColor(TUI.red) }
                    Button { commit() } label: {
                        Text(actionLabel).font(.jk(12, .heavy)).foregroundColor(shown == worn ? .white.opacity(0.6) : .white).frame(maxWidth: .infinity).frame(height: 32)
                            .background(shown == worn ? Color.white.opacity(0.1) : LS.orange)
                    }
                    .buttonStyle(TuiPress())
                    .disabled(shown == worn)
                    Button { nav.tacGun = gid } label: {
                        Text(nav.tacGun == gid ? "USING THIS GUN" : "USE THIS GUN").font(.jk(11, .heavy)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 30)
                            .background(nav.tacGun == gid ? LS.green.opacity(0.6) : Color.white.opacity(0.16)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    }
                    .buttonStyle(TuiPress())
                }
                .padding(7).frame(width: rw, height: H - 56).background(panel).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                .offset(x: W - rw - 10, y: 48)
            }
            .frame(width: W, height: H, alignment: .topLeading)
        }
        .onAppear { gid = nav.tacGun; TAtt.pv = [:] }
        .onChange(of: gid) { _ in TAtt.pv = [:]; tick += 1 }
        .onDisappear { TAtt.pv = [:] }
    }
}
