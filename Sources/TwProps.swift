import SwiftUI
import UIKit

private func pCol(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: a) }

private struct PLCG {
    var s: UInt64
    mutating func n() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFF) / 65535
    }
}

/// Detailed prop / door / decal models shared by the 5v5 scene.
final class TwProps {
    private var matCache: [String: MXMaterial] = [:]
    private var texCache: [String: UIImage] = [:]

    private func tex(_ key: String, _ draw: (CGContext, CGFloat) -> Void) -> UIImage {
        if let t = texCache[key] { return t }
        let s: CGFloat = 256
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: fmt).image { c in draw(c.cgContext, s) }
        texCache[key] = img
        return img
    }

    private func grime(_ g: CGContext, _ s: CGFloat, _ seed: UInt64, _ amt: CGFloat) {
        var r = PLCG(s: seed)
        for _ in 0..<Int(14 * amt) {
            let w = 30 + r.n() * 90, h = 20 + r.n() * 70
            g.setFillColor(pCol(0, 0, 0, 0.025 + r.n() * 0.05).cgColor)
            g.fillEllipse(in: CGRect(x: r.n() * s - w / 2, y: r.n() * s - h / 2, width: w, height: h))
        }
        for _ in 0..<Int(600 * amt) {
            g.setFillColor(pCol(0, 0, 0, 0.08 + r.n() * 0.14).cgColor)
            let d = 0.8 + r.n() * 1.5
            g.fill(CGRect(x: r.n() * s, y: r.n() * s, width: d, height: d))
        }
        for _ in 0..<Int(200 * amt) {
            g.setFillColor(pCol(1, 1, 1, 0.05 + r.n() * 0.1).cgColor)
            g.fill(CGRect(x: r.n() * s, y: r.n() * s, width: 1, height: 1))
        }
    }

    private func woodTex() -> UIImage {
        tex("wood") { g, s in
            var r = PLCG(s: 9)
            for k in 0..<4 {
                let v = 0.72 + r.n() * 0.25
                g.setFillColor(pCol(v, v * 0.9, v * 0.8).cgColor)
                g.fill(CGRect(x: 0, y: CGFloat(k) * s / 4, width: s, height: s / 4))
                g.setStrokeColor(pCol(0.25, 0.18, 0.12, 0.8).cgColor)
                g.setLineWidth(1.2)
                g.stroke(CGRect(x: 0, y: CGFloat(k) * s / 4, width: s, height: s / 4))
                let jx = r.n() * s
                g.move(to: CGPoint(x: jx, y: CGFloat(k) * s / 4))
                g.addLine(to: CGPoint(x: jx, y: CGFloat(k + 1) * s / 4))
                g.strokePath()
                for _ in 0..<14 {
                    g.setStrokeColor(pCol(0.3, 0.2, 0.1, 0.18).cgColor)
                    let y = CGFloat(k) * s / 4 + r.n() * s / 4
                    let x = r.n() * s
                    g.move(to: CGPoint(x: x, y: y))
                    g.addLine(to: CGPoint(x: x + 20 + r.n() * 40, y: y + 0.5))
                    g.strokePath()
                }
            }
            grime(g, s, 71, 0.5)
        }
    }

    private func carpetTex() -> UIImage {
        tex("carpet") { g, s in
            var r = PLCG(s: 5)
            g.setFillColor(pCol(0.82, 0.82, 0.84).cgColor)
            g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            for _ in 0..<1800 {
                let v = 0.62 + r.n() * 0.34
                g.setFillColor(pCol(v, v, v, 0.55).cgColor)
                g.fill(CGRect(x: r.n() * s, y: r.n() * s, width: 2, height: 2))
            }
        }
    }

    private func woodMat(_ su: CGFloat, _ sv: CGFloat, _ tint: UIColor) -> MXMaterial {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        tint.getRed(&r, green: &g, blue: &b, alpha: &a)
        let key = "w\(Int(su * 20))_\(Int(sv * 20))_\(Int(r * 100))_\(Int(g * 100))_\(Int(b * 100))"
        if let m = matCache[key] { return m }
        let m = MXMaterial()
        let img = woodTex()
        m.diffuse.contents = img
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = MXMatrix4MakeScale(Float(su), Float(sv), 1)
        m.normal.contents = img
        m.normal.intensity = 0.7
        m.normal.wrapS = .repeat
        m.normal.wrapT = .repeat
        m.normal.contentsTransform = MXMatrix4MakeScale(Float(su), Float(sv), 1)
        m.multiply.contents = tint
        m.lightingModel = .blinn
        m.specular.contents = UIColor(white: 0.3, alpha: 1)
        m.shininess = 0.35
        matCache[key] = m
        return m
    }

    private func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, glow: Bool = false) -> MXNode {
        let g = MXBox(width: w, height: h, length: l, chamferRadius: 0)
        let m = MXMaterial()
        m.diffuse.contents = c
        if glow { m.emission.contents = c; m.lightingModel = .constant }
        g.materials = [m]
        return MXNode(geometry: g)
    }

    private func ghost(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, _ a: CGFloat) -> MXNode {
        let g = MXBox(width: w, height: h, length: l, chamferRadius: 0)
        let m = MXMaterial()
        m.diffuse.contents = c
        m.emission.contents = c
        m.emission.intensity = 0.5
        m.transparency = a
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        g.materials = [m]
        return MXNode(geometry: g)
    }


    private func mat(_ c: UIColor, spec: CGFloat = 0.2, shin: CGFloat = 0.3, fabric: Bool = false) -> MXMaterial {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        let key = "m\(Int(r * 255))_\(Int(g * 255))_\(Int(b * 255))_\(Int(spec * 100))_\(Int(shin * 100))_\(fabric)"
        if let m = matCache[key] { return m }
        let m = MXMaterial()
        m.diffuse.contents = c
        m.lightingModel = .blinn
        m.specular.contents = UIColor(white: spec, alpha: 1)
        m.shininess = shin
        if fabric {
            m.normal.contents = carpetTex()
            m.normal.intensity = 1.0
            m.normal.wrapS = .repeat
            m.normal.wrapT = .repeat
            m.normal.contentsTransform = MXMatrix4MakeScale(4, 4, 1)
        }
        matCache[key] = m
        return m
    }

    private func rb(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ c: UIColor, _ rad: CGFloat = 2.2, spec: CGFloat = 0.2, shin: CGFloat = 0.3, fabric: Bool = false) -> MXNode {
        let ww = max(0.2, w), hh = max(0.2, h), ll = max(0.2, l)
        let g = MXBox(width: ww, height: hh, length: ll, chamferRadius: min(rad, min(ww, hh, ll) * 0.45))
        g.chamferSegmentCount = 3
        g.materials = [mat(c, spec: spec, shin: shin, fabric: fabric)]
        return MXNode(geometry: g)
    }

    private func wd(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ tint: UIColor = pCol(0.85, 0.7, 0.55)) -> MXNode {
        let ww = max(0.2, w), hh = max(0.2, h), ll = max(0.2, l)
        let g = MXBox(width: ww, height: hh, length: ll, chamferRadius: min(0.8, min(ww, hh, ll) * 0.4))
        g.chamferSegmentCount = 2
        g.materials = [woodMat(max(0.3, max(ww, ll) / 52), max(0.3, hh / 52), tint)]
        return MXNode(geometry: g)
    }

    private func cy(_ r: CGFloat, _ h: CGFloat, _ c: UIColor, spec: CGFloat = 0.3, shin: CGFloat = 0.5) -> MXNode {
        let g = MXCylinder(radius: max(0.1, r), height: max(0.1, h))
        g.radialSegmentCount = 28
        g.materials = [mat(c, spec: spec, shin: shin)]
        return MXNode(geometry: g)
    }

    private func cn(_ top: CGFloat, _ bot: CGFloat, _ h: CGFloat, _ c: UIColor, spec: CGFloat = 0.25) -> MXNode {
        let g = MXCone(topRadius: top, bottomRadius: bot, height: h)
        g.radialSegmentCount = 24
        g.materials = [mat(c, spec: spec, shin: 0.4)]
        return MXNode(geometry: g)
    }

    private func tr(_ ring: CGFloat, _ pipe: CGFloat, _ c: UIColor) -> MXNode {
        let g = MXTorus(ringRadius: ring, pipeRadius: pipe)
        g.ringSegmentCount = 36
        g.pipeSegmentCount = 8
        g.materials = [mat(c, spec: 0.5, shin: 0.8)]
        return MXNode(geometry: g)
    }

    private func tb(_ inner: CGFloat, _ outer: CGFloat, _ h: CGFloat, _ c: UIColor) -> MXNode {
        let g = MXTube(innerRadius: inner, outerRadius: outer, height: h)
        g.radialSegmentCount = 20
        g.materials = [mat(c, spec: 0.4, shin: 0.6)]
        return MXNode(geometry: g)
    }

    private func sp(_ r: CGFloat, _ c: UIColor, spec: CGFloat = 0.3) -> MXNode {
        let g = MXSphere(radius: r)
        g.segmentCount = 18
        g.materials = [mat(c, spec: spec, shin: 0.5)]
        return MXNode(geometry: g)
    }

    private func put(_ g: MXNode, _ n: MXNode, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, rx: CGFloat = 0, ry: CGFloat = 0, rz: CGFloat = 0) {
        n.position = MXVector3(Float(x), Float(y), Float(z))
        n.eulerAngles = MXVector3(Float(rx), Float(ry), Float(rz))
        g.addChildNode(n)
    }

    // MARK: doors

    /// hinged door leaf/leaves. Returns containers positioned at the hinges; rotate .eulerAngles.y to swing.
    func door(_ d: CGRect) -> [MXNode] {
        let horiz = d.width > d.height
        let len = horiz ? d.width : d.height
        let dbl = len > 70
        let leafLen = dbl ? len / 2 : len
        let tint = pCol(0.78, 0.6, 0.42)
        func leaf(_ sgn: CGFloat) -> MXNode {
            let panel = MXNode()
            panel.addChildNode(horiz ? wd(leafLen - 1, 70, 4.5, tint) : wd(4.5, 70, leafLen - 1, tint))
            for side in [-1.0, 1.0] as [CGFloat] {
                for k in 0..<2 {
                    let iy: CGFloat = k == 0 ? 17 : -17
                    let n2 = horiz ? rb(leafLen - 12, 26, 0.7, pCol(0.0, 0.0, 0.0, 0.2), 0.3) : rb(0.7, 26, leafLen - 12, pCol(0.0, 0.0, 0.0, 0.2), 0.3)
                    n2.position = horiz ? MXVector3(0, Float(iy), Float(side * 2.5)) : MXVector3(Float(side * 2.5), Float(iy), 0)
                    panel.addChildNode(n2)
                }
                let knob = sp(1.7, pCol(0.85, 0.68, 0.3), spec: 0.8)
                let kx = sgn * (leafLen - 6)
                knob.position = horiz ? MXVector3(Float(sgn * (leafLen / 2 - 6)), -2, Float(side * 3.6)) : MXVector3(Float(side * 3.6), -2, Float(sgn * (leafLen / 2 - 6)))
                _ = kx
                panel.addChildNode(knob)
            }
            panel.position = horiz ? MXVector3(Float(sgn * leafLen / 2), 36, 0) : MXVector3(0, 36, Float(sgn * leafLen / 2))
            let c = MXNode()
            c.addChildNode(panel)
            if sgn > 0 {
                c.position = horiz ? MXVector3(Float(d.minX), 0, Float(d.midY)) : MXVector3(Float(d.midX), 0, Float(d.minY))
            } else {
                c.position = horiz ? MXVector3(Float(d.maxX), 0, Float(d.midY)) : MXVector3(Float(d.midX), 0, Float(d.maxY))
            }
            return c
        }
        return dbl ? [leaf(1), leaf(-1)] : [leaf(1)]
    }

    // MARK: decals

    private func decalMat(_ k: Int) -> MXMaterial {
        let key = "decal\(k)"
        if let m = matCache[key] { return m }
        let img = tex("decal\(k)") { g, s in
            var r = PLCG(s: UInt64(k * 31 + 7))
            switch k {
            case 0:
                for _ in 0..<7 {
                    let w = 40 + r.n() * 110
                    g.setFillColor(pCol(0.05, 0.04, 0.03, 0.10 + r.n() * 0.10).cgColor)
                    g.fillEllipse(in: CGRect(x: s / 2 - w / 2 + (r.n() - 0.5) * 50, y: s / 2 - w * 0.35 + (r.n() - 0.5) * 40, width: w, height: w * 0.7))
                }
            case 1:
                let cols = [pCol(0, 0, 0, 0.5).cgColor, pCol(0, 0, 0, 0).cgColor] as CFArray
                if let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
                    g.drawRadialGradient(gr, startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0, endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: s / 2, options: [])
                }
            case 2:
                for _ in 0..<9 {
                    g.saveGState()
                    g.translateBy(x: s / 2 + (r.n() - 0.5) * 150, y: s / 2 + (r.n() - 0.5) * 120)
                    g.rotate(by: r.n() * 6.28)
                    let v = 0.78 + r.n() * 0.2
                    g.setFillColor(pCol(v, v, v * 0.95, 0.92).cgColor)
                    g.fill(CGRect(x: -12, y: -16, width: 24, height: 32))
                    g.setFillColor(pCol(0.3, 0.3, 0.35, 0.5).cgColor)
                    for l in 0..<4 { g.fill(CGRect(x: -9, y: -11 + CGFloat(l) * 6, width: 16, height: 1.5)) }
                    g.restoreGState()
                }
            default:
                g.setStrokeColor(pCol(0, 0, 0, 0.7).cgColor)
                g.setLineWidth(2)
                var p = CGPoint(x: 10, y: s * 0.3 + r.n() * s * 0.4)
                g.move(to: p)
                while p.x < s - 10 {
                    p = CGPoint(x: p.x + 10 + r.n() * 24, y: p.y + (r.n() - 0.5) * 36)
                    g.addLine(to: p)
                }
                g.strokePath()
            }
        }
        let m = MXMaterial()
        m.diffuse.contents = img
        m.lightingModel = .lambert
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        m.transparencyMode = .aOne
        matCache[key] = m
        return m
    }

    func decals(in rooms: [CGRect], avoid: [CGRect], seed: Int) -> MXNode {
        let out = MXNode()
        var dr = PLCG(s: UInt64(seed * 977 + 13))
        for rm in rooms {
            for _ in 0..<7 {
                let p = CGPoint(x: rm.minX + 30 + dr.n() * (rm.width - 60), y: rm.minY + 30 + dr.n() * (rm.height - 60))
                if avoid.contains(where: { $0.insetBy(dx: -10, dy: -10).contains(p) }) { continue }
                let k = Int(dr.n() * 3.99)
                let sz = 26 + dr.n() * 64
                let pl = MXPlane(width: sz, height: sz)
                pl.materials = [decalMat(k)]
                let inner = MXNode(geometry: pl)
                inner.eulerAngles = MXVector3(-Float.pi / 2, 0, 0)
                let outer = MXNode()
                outer.addChildNode(inner)
                outer.eulerAngles = MXVector3(0, Float(dr.n() * 6.28), 0)
                outer.position = MXVector3(Float(p.x), 0.4, Float(p.y))
                outer.castsShadow = false
                out.addChildNode(outer)
            }
        }
        return out
    }

    // MARK: props

    func build(_ kind: PropKind, _ r: CGRect) -> MXNode {
        let long = r.width >= r.height
        let L = max(r.width, r.height), D = min(r.width, r.height)
        let hv = abs(Int(r.minX * 7 + r.minY * 13)) % 97
        var rg = PLCG(s: UInt64(hv * 7919 + 131 + 11))
        let g = MXNode()
        let steel = pCol(0.55, 0.58, 0.62)
        let dark = pCol(0.1, 0.1, 0.12)
        let brass = pCol(0.85, 0.68, 0.3)
        let white = pCol(0.93, 0.93, 0.95)
        let palette: [UIColor] = [pCol(0.7, 0.2, 0.2), pCol(0.2, 0.4, 0.7), pCol(0.82, 0.7, 0.22), pCol(0.25, 0.6, 0.38), pCol(0.9, 0.9, 0.84), pCol(0.45, 0.25, 0.55), pCol(0.85, 0.5, 0.2)]
        switch kind {
        case .crate:
            let H: CGFloat = 27 + CGFloat(hv % 3) * 3
            let planks = pCol(0.82, 0.66, 0.5)
            let beam = pCol(0.55, 0.42, 0.3)
            put(g, wd(L, H, D, planks), 0, H / 2, 0)
            for sx in [-1.0, 1.0] as [CGFloat] {
                for sz in [-1.0, 1.0] as [CGFloat] {
                    put(g, wd(3.4, H + 0.6, 3.4, beam), sx * (L / 2 - 1.2), H / 2, sz * (D / 2 - 1.2))
                }
            }
            for y in [2.6, H - 2.6] as [CGFloat] { put(g, wd(L + 0.9, 2.8, D + 0.9, beam), 0, y, 0) }
            let bl = hypot(L - 8, H - 8), ba = atan2(H - 8, L - 8)
            put(g, wd(bl, 2.4, 0.9, beam), 0, H / 2, D / 2 + 0.5, rz: ba)
            put(g, wd(bl, 2.4, 0.9, beam), 0, H / 2, -D / 2 - 0.5, rz: -ba)
            put(g, box(L * 0.3, 4.5, 0.3, pCol(0.08, 0.08, 0.08)), -L * 0.18, H * 0.62, D / 2 + 0.8)
            put(g, wd(L - 0.8, 1.6, D - 0.8, planks), 0, H + 0.6, 0)
            if hv % 3 == 0 && L > 30 { put(g, wd(L * 0.5, 17, D * 0.7, planks), 2, H + 9.4, 0, ry: 0.25) }
        case .couch:
            let cols: [UIColor] = [pCol(0.46, 0.16, 0.22), pCol(0.2, 0.3, 0.45), pCol(0.28, 0.33, 0.27), pCol(0.45, 0.34, 0.24)]
            let c1 = cols[hv % 4]
            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            c1.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
            let c2 = pCol(min(1, cr * 1.25 + 0.05), min(1, cg * 1.25 + 0.05), min(1, cb * 1.25 + 0.05))
            put(g, rb(L, 8, D, c1, 3.5, fabric: true), 0, 7, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] { put(g, cy(1.2, 3, brass, spec: 0.6, shin: 1), sx * (L / 2 - 4), 1.5, sz * (D / 2 - 4)) } }
            put(g, rb(L, 17, 8, c1, 4.5, fabric: true), 0, 15.5, -D / 2 + 4)
            for sx in [-1.0, 1.0] as [CGFloat] { put(g, rb(7, 13, D, c1, 3.5, fabric: true), sx * (L / 2 - 3.5), 14.5, 0) }
            let n = L > 90 ? 3 : 2
            let cw = (L - 14) / CGFloat(n)
            for k in 0..<n {
                let x = -L / 2 + 7 + cw * (CGFloat(k) + 0.5)
                put(g, rb(cw - 1, 5.5, D - 9, c2, 3, fabric: true), x, 13.7, 2)
                put(g, rb(cw - 1, 11, 5, c2, 3.4, fabric: true), x, 19.5, -D / 2 + 10, rx: -0.14)
            }
            put(g, rb(8, 8, 3, palette[(hv + 2) % palette.count], 2.5, fabric: true), -L / 2 + 13, 19, 0, ry: 0.4, rz: 0.5)

        case .plant:
            let rr = min(L, D) / 2
            let terr = pCol(0.72, 0.4, 0.26)
            put(g, cn(rr, rr * 0.68, 13, terr), 0, 6.5, 0)
            put(g, tr(rr * 0.98, 0.9, pCol(0.62, 0.32, 0.2)), 0, 13, 0)
            put(g, cy(rr * 0.92, 0.8, pCol(0.16, 0.1, 0.07), spec: 0.05), 0, 12.6, 0)
            for i in 0..<3 {
                let a = CGFloat(i) * 2.1
                put(g, cy(0.55, 17, pCol(0.3, 0.22, 0.12)), sin(a) * 1.6, 21, cos(a) * 1.6, rx: cos(a) * 0.18, rz: -sin(a) * 0.18)
            }
            for i in 0..<16 {
                let a = CGFloat(i) * 0.62
                let ringR = 3 + CGFloat(i % 4) * 2.2
                let lf = sp(1, pCol(0.1 + rg.n() * 0.08, 0.42 + rg.n() * 0.25, 0.14 + rg.n() * 0.08), spec: 0.4)
                lf.scale = MXVector3(5.5, 0.8, 2.4)
                put(g, lf, sin(a) * ringR, 17 + CGFloat(i % 5) * 3.6, cos(a) * ringR, ry: a, rz: 0.45)
            }
        case .shelf:
            let wood = pCol(0.62, 0.45, 0.32)
            let H: CGFloat = 66
            for s in [-1.0, 1.0] as [CGFloat] { put(g, wd(2, H, D, wood), s * (L / 2 - 1), H / 2, 0) }
            put(g, wd(L, 2.4, D + 1, wood), 0, H + 0.6, 0)
            put(g, wd(L, 3.5, D, wood), 0, 1.8, 0)
            put(g, wd(L - 2, H, 1.4, pCol(0.5, 0.36, 0.26)), 0, H / 2, -D / 2 + 0.7)
            for k in 0..<3 { put(g, wd(L - 3, 1.5, D - 1.5, wood), 0, 15 + CGFloat(k) * 16, 0) }
            for row in 0..<4 {
                let top: CGFloat = row == 0 ? 3.5 : 15.75 + CGFloat(row - 1) * 16
                var x = -L / 2 + 3.2
                while x < L / 2 - 4 {
                    let w = 2.0 + rg.n() * 2.4
                    let h = 6.5 + rg.n() * 5
                    if rg.n() < 0.07 { x += 5; continue }
                    let lean = rg.n() < 0.05
                    let c = palette[Int(rg.n() * 6.99)]
                    put(g, rb(w, h, D * 0.62, c, 0.5, spec: 0.1), x + w / 2, top + h / 2, 0.8, rz: lean ? -0.3 : 0)
                    x += w + 0.25
                }
            }
        case .table:
            let wood = pCol(0.82, 0.62, 0.45)
            put(g, wd(L, 2.4, D, wood), 0, 22, 0)
            put(g, wd(L - 6, 3, D - 6, pCol(0.55, 0.4, 0.3)), 0, 19.8, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] { put(g, cn(1.4, 0.8, 19, pCol(0.5, 0.36, 0.26)), sx * (L / 2 - 3.5), 9.5, sz * (D / 2 - 3.5)) } }
            if hv % 2 == 0 {
                put(g, rb(11, 0.8, 8, pCol(0.75, 0.77, 0.8), 0.5, spec: 0.7, shin: 1), -L * 0.15, 23.6, D * 0.1)
                put(g, rb(11, 7, 0.6, pCol(0.75, 0.77, 0.8), 0.4, spec: 0.7, shin: 1), -L * 0.15, 27, D * 0.1 - 4, rx: -0.2)
                put(g, box(9.8, 5.8, 0.2, pCol(0.3, 0.7, 1.0), glow: true), -L * 0.15, 27, D * 0.1 - 3.6, rx: -0.2)
            } else {
                put(g, rb(8, 0.3, 11, white, 0.1), -L * 0.15, 23.4, 0, ry: 0.3)
                put(g, rb(6, 0.3, 8, pCol(0.9, 0.85, 0.6), 0.1), -L * 0.15 + 3, 23.7, 1, ry: -0.2)
            }
            put(g, tb(1.1, 1.7, 3.2, palette[hv % palette.count]), L * 0.25, 24.2, D * 0.1)
            put(g, cy(2, 5, pCol(0.25, 0.4, 0.6), spec: 0.6, shin: 1), L * 0.3, 25.5, -D * 0.15)
            for i in 0..<4 {
                let lf = sp(1, pCol(0.15, 0.5, 0.2))
                lf.scale = MXVector3(3.2, 0.6, 1.4)
                put(g, lf, L * 0.3 + sin(CGFloat(i) * 1.6) * 1.5, 29 + CGFloat(i % 2), -D * 0.15 + cos(CGFloat(i) * 1.6) * 1.5, ry: CGFloat(i) * 1.6, rz: 0.5)
            }
        case .barrel:
            let rr = min(L, D) / 2
            let cols: [UIColor] = [pCol(0.68, 0.14, 0.1), pCol(0.15, 0.3, 0.6), pCol(0.18, 0.45, 0.25), pCol(0.45, 0.46, 0.5)]
            put(g, cy(rr, 30, cols[hv % 4], spec: 0.5, shin: 0.9), 0, 15, 0)
            for y in [4.0, 15.0, 26.0] as [CGFloat] { put(g, tr(rr + 0.05, 0.9, pCol(0.3, 0.31, 0.34)), 0, y, 0) }
            put(g, cy(rr - 0.4, 0.8, pCol(0.5, 0.52, 0.56), spec: 0.7, shin: 1), 0, 30.2, 0)
            put(g, tr(rr - 0.4, 0.6, pCol(0.4, 0.42, 0.46)), 0, 30.5, 0)
            put(g, cy(1.4, 1.2, pCol(0.2, 0.2, 0.22)), rr * 0.45, 31, 0)
            put(g, cy(1.1, 1.0, pCol(0.2, 0.2, 0.22)), -rr * 0.3, 31, rr * 0.3)
            put(g, rb(rr * 1.0, 8, 0.5, pCol(0.95, 0.8, 0.15), 0.2), 0, 17, rr + 0.1)
            put(g, rb(3, 3, 0.4, pCol(0.08, 0.08, 0.08), 0.1), 0, 17, rr + 0.5, rz: .pi / 4)
        case .bed:
            let wood = pCol(0.6, 0.44, 0.32)
            let sheet = pCol(0.93, 0.93, 0.95)
            put(g, rb(L, 7, D, wood, 2), 0, 5.5, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { for sz in [-1.0, 1.0] as [CGFloat] { put(g, cy(1.4, 3, pCol(0.3, 0.2, 0.14)), sx * (L / 2 - 3), 1.5, sz * (D / 2 - 3)) } }
            put(g, rb(L - 4, 9, D - 4, sheet, 4.2, fabric: true), 0, 12.5, 0)
            put(g, rb((L - 4) * 0.62, 3.6, D - 3, palette[hv % palette.count], 3.4, fabric: true), L * 0.17, 17.4, 0)
            put(g, rb(7, 4.8, D - 2, palette[hv % palette.count], 3, fabric: true), -L * 0.12, 17.6, 0)
            for s in [-1.0, 1.0] as [CGFloat] { put(g, rb(12, 5, D * 0.42, white, 3.4, fabric: true), -L / 2 + 11, 17.8, s * D * 0.23, ry: s * 0.06) }
            put(g, wd(3.2, 26, D + 1, wood), -L / 2 + 1.6, 13, 0)
            put(g, wd(2.6, 13, D, wood), L / 2 - 1.3, 6.5, 0)

        case .counter:
            let H: CGFloat = 34
            let cab = pCol(0.88, 0.86, 0.82)
            put(g, rb(L - 2, 3, D - 4, dark, 0.8), 0, 1.5, -1)
            put(g, rb(L, H - 3, D - 2, pCol(0.45, 0.34, 0.26), 1.2), 0, 3 + (H - 3) / 2, -1)
            let n = max(2, Int(L / 24))
            let w = L / CGFloat(n)
            for k in 0..<n {
                let x = -L / 2 + w * (CGFloat(k) + 0.5)
                put(g, rb(w - 1.4, H - 8, 0.9, cab, 0.6), x, 3 + (H - 3) / 2, D / 2 - 1.6)
                put(g, rb(0.8, 5, 0.9, steel, 0.3, spec: 0.8, shin: 1), x + w * 0.3, H - 6, D / 2 - 0.8)
            }
            put(g, rb(L + 2, 3, D + 3, pCol(0.86, 0.87, 0.9), 1, spec: 0.7, shin: 1.2), 0, H + 0.5, 0.5)
            put(g, rb(L, 8, 1.2, pCol(0.8, 0.84, 0.86), 0.4, spec: 0.5), 0, H + 6.5, -D / 2 + 0.8)
            if hv % 2 == 0 {
                put(g, rb(7, 5, 4, steel, 1.2, spec: 0.8, shin: 1.2), -L * 0.3, H + 4, 0)
                put(g, wd(11, 1.2, 8, pCol(0.9, 0.75, 0.55)), L * 0.1, H + 2.6, 1, ry: 0.2)
            } else {
                put(g, cy(2.8, 6, steel, spec: 0.8, shin: 1.2), -L * 0.28, H + 5, 0)
                put(g, cn(4, 2.4, 3, pCol(0.9, 0.9, 0.92)), L * 0.2, H + 3.5, 1)
            }
        case .car:
            let body = [pCol(0.2, 0.38, 0.62), pCol(0.7, 0.14, 0.14), pCol(0.85, 0.85, 0.88), pCol(0.15, 0.15, 0.17)][hv % 4]
            let glass = pCol(0.07, 0.1, 0.15)
            put(g, rb(L, 11, D, body, 6, spec: 0.8, shin: 1.4), 0, 12, 0)
            put(g, rb(L * 0.3, 4, D - 8, body, 4, spec: 0.8, shin: 1.4), L * 0.33, 18, 0)
            put(g, rb(L * 0.22, 4, D - 8, body, 4, spec: 0.8, shin: 1.4), -L * 0.38, 18, 0)
            put(g, rb(L * 0.42, 10, D - 9, glass, 4, spec: 0.9, shin: 1.5), -L * 0.02, 24, 0)
            put(g, rb(L * 0.36, 1.8, D - 12, body, 1.2, spec: 0.8, shin: 1.4), -L * 0.02, 29.6, 0)
            for sx in [-1.0, 1.0] as [CGFloat] {
                for sz in [-1.0, 1.0] as [CGFloat] {
                    let wx = sx * L * 0.31, wz = sz * (D / 2 - 1)
                    put(g, cy(8, 6, pCol(0.04, 0.04, 0.05), spec: 0.1), wx, 8, wz, rx: .pi / 2)
                    put(g, cy(4.6, 6.2, steel, spec: 0.9, shin: 1.5), wx, 8, wz, rx: .pi / 2)
                }
            }
            for sz in [-1.0, 1.0] as [CGFloat] {
                put(g, box(1.4, 3, 8, pCol(1, 0.96, 0.8), glow: true), L / 2 - 0.2, 15, sz * (D / 2 - 9))
                put(g, box(1.4, 3, 8, pCol(1, 0.15, 0.1), glow: true), -L / 2 + 0.2, 15, sz * (D / 2 - 9))
                put(g, rb(4, 2.4, 1.6, body, 0.6, spec: 0.8), L * 0.13, 22, sz * (D / 2 + 0.6))
            }
            put(g, rb(2.4, 4, D - 2, steel, 1, spec: 0.9, shin: 1.5), L / 2, 8, 0)
            put(g, rb(2.4, 4, D - 2, steel, 1, spec: 0.9, shin: 1.5), -L / 2, 8, 0)
        case .sandbag:
            let tan = pCol(0.78, 0.7, 0.48)
            let rows = 3
            for row in 0..<rows {
                let cnt = max(1, Int(L / 15) - (row == 2 ? 1 : 0))
                let bw = L / CGFloat(max(1, Int(L / 15)))
                for i in 0..<cnt {
                    let x = -L / 2 + bw * (CGFloat(i) + 0.5) + (row % 2 == 1 ? bw * 0.5 : 0) - (row == 2 ? 0 : 0)
                    if abs(x) > L / 2 - 2 && row % 2 == 1 { continue }
                    let shade = 0.9 + rg.n() * 0.18
                    put(g, rb(bw - 0.6, 6.6, D * 0.96, pCol(0.78 * shade, 0.7 * shade, 0.48 * shade), 3.2, spec: 0.05, fabric: true), x, 3.6 + CGFloat(row) * 6.2, 0, ry: (rg.n() - 0.5) * 0.12)
                }
            }
            _ = tan
        case .tv:
            let wood = pCol(0.45, 0.33, 0.25)
            put(g, rb(L, 17, D, wood, 1.4), 0, 9.5, 0)
            for sx in [-1.0, 1.0] as [CGFloat] { put(g, cy(1.2, 3, steel, spec: 0.6), sx * (L / 2 - 4), 1.5, 0) }
            put(g, rb(L * 0.8, 24, 2.2, pCol(0.03, 0.03, 0.04), 1.1, spec: 0.8, shin: 1.5), 0, 30.5, -D * 0.1)
            put(g, box(L * 0.76, 21, 0.3, pCol(0.25, 0.55, 0.95), glow: true), 0, 30.5, -D * 0.1 + 1.3)
            put(g, rb(L * 0.16, 3, 8, dark, 1, spec: 0.7), 0, 19.5, -D * 0.1)
            put(g, rb(L * 0.5, 2.6, 6, dark, 1.2, spec: 0.6), 0, 10, D / 2 + 1.2)
        case .tree:
            let trunk = pCol(0.3, 0.21, 0.13)
            let h = 190 + CGFloat(hv % 5) * 12
            put(g, cy(L * 0.36, h * 0.6, trunk, spec: 0.04, shin: 0.1), 0, h * 0.3, 0)
            let leaf: [UIColor] = [pCol(0.13, 0.33, 0.15), pCol(0.17, 0.4, 0.17), pCol(0.11, 0.29, 0.14)]
            put(g, rb(100, 52, 100, leaf[hv % 3], 9, spec: 0.04, shin: 0.1), 0, h * 0.5 + 26, 0, ry: CGFloat(hv % 7) * 0.2)
            put(g, rb(76, 48, 76, leaf[(hv + 1) % 3], 8, spec: 0.04, shin: 0.1), 0, h * 0.5 + 66, 0, ry: 0.7)
            put(g, rb(50, 44, 50, leaf[(hv + 2) % 3], 7, spec: 0.04, shin: 0.1), 0, h * 0.5 + 104, 0, ry: 0.3)
        case .rock:
            let gray = pCol(0.46, 0.47, 0.5)
            put(g, rb(L, 34, D, gray, 10, spec: 0.1, shin: 0.2), 0, 17, 0)
            put(g, rb(L * 0.62, 26, D * 0.62, pCol(0.52, 0.53, 0.55), 9, spec: 0.1, shin: 0.2), L * 0.1, 40, -D * 0.08, ry: 0.5)
        default:
            break
        }
        g.position = MXVector3(Float(r.midX), 0, Float(r.midY))
        if !long { g.eulerAngles = MXVector3(0, Float.pi / 2, 0) }
        let n = MXNode()
        n.addChildNode(g)
        return n
    }

}
