import SwiftUI
import UIKit

/// bullet holes, dust puffs, sparks, blood and glass chips, spawned from the engine's impact queue.
/// Everything is a pooled textured quad parented to its floor, so the stair lift and floor glide apply for free.
final class TacImpactFX {
    private struct Decal { let node: MXNode }
    private struct Part {
        let node: MXNode
        var vel: MXVector3
        var life: Float
        var max: Float
        var grow: Float
        var base: Float
        var gravity: Float
    }

    private let roots: [MXNode]
    private var holes: [[MXNode]] = [[], [], []]
    private var holeNext = [0, 0, 0]
    private var bloods: [[MXNode]] = [[], [], []]
    private var bloodNext = [0, 0, 0]
    private var parts: [Part] = []
    private var free: [MXNode] = []
    private var dustMat: MXMaterial
    private var sparkMat: MXMaterial
    private var bloodMat: MXMaterial
    private var holeMat: MXMaterial
    private var poolMat: MXMaterial
    private var chipMat: MXMaterial

    private static func img(_ size: CGFloat, _ draw: (CGContext, CGFloat) -> Void) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        f.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: f).image { draw($0.cgContext, size) }
    }

    private static func radial(_ g: CGContext, _ s: CGFloat, _ inner: UIColor, _ outer: UIColor, _ r: CGFloat) {
        let cols = [inner.cgColor, outer.cgColor] as CFArray
        if let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
            g.drawRadialGradient(gr, startCenter: CGPoint(x: s / 2, y: s / 2), startRadius: 0, endCenter: CGPoint(x: s / 2, y: s / 2), endRadius: r, options: [])
        }
    }

    private static func mat(_ image: UIImage, constant: Bool) -> MXMaterial {
        let m = MXMaterial()
        m.diffuse.contents = image
        m.lightingModel = constant ? .constant : .lambert
        if constant { m.emission.contents = image }
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        return m
    }

    init(roots: [MXNode]) {
        self.roots = roots
        dustMat = TacImpactFX.mat(TacImpactFX.img(64) { g, s in
            TacImpactFX.radial(g, s, UIColor(white: 0.78, alpha: 0.55), UIColor(white: 0.7, alpha: 0), s / 2)
        }, constant: false)
        sparkMat = TacImpactFX.mat(TacImpactFX.img(32) { g, s in
            TacImpactFX.radial(g, s, UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1), UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 0), s / 2)
        }, constant: true)
        bloodMat = TacImpactFX.mat(TacImpactFX.img(32) { g, s in
            TacImpactFX.radial(g, s, UIColor(red: 0.6, green: 0.03, blue: 0.03, alpha: 0.95), UIColor(red: 0.4, green: 0.02, blue: 0.02, alpha: 0), s / 2)
        }, constant: false)
        chipMat = TacImpactFX.mat(TacImpactFX.img(32) { g, s in
            TacImpactFX.radial(g, s, UIColor(red: 0.85, green: 0.95, blue: 1, alpha: 0.95), UIColor(red: 0.7, green: 0.85, blue: 1, alpha: 0), s / 2)
        }, constant: true)
        holeMat = TacImpactFX.mat(TacImpactFX.img(64) { g, s in
            let c = CGPoint(x: s / 2, y: s / 2)
            TacImpactFX.radial(g, s, UIColor(white: 0.1, alpha: 0.55), UIColor(white: 0.1, alpha: 0), s / 2)
            g.setFillColor(UIColor(white: 0.02, alpha: 0.98).cgColor)
            g.fillEllipse(in: CGRect(x: c.x - 5, y: c.y - 5, width: 10, height: 10))
            g.setStrokeColor(UIColor(white: 0.05, alpha: 0.7).cgColor)
            g.setLineWidth(1.2)
            for i in 0..<7 {
                let a = CGFloat(i) * 0.9 + 0.3
                g.move(to: c)
                g.addLine(to: CGPoint(x: c.x + cos(a) * (12 + CGFloat(i % 3) * 6), y: c.y + sin(a) * (12 + CGFloat(i % 3) * 6)))
            }
            g.strokePath()
        }, constant: false)
        poolMat = TacImpactFX.mat(TacImpactFX.img(64) { g, s in
            TacImpactFX.radial(g, s, UIColor(red: 0.42, green: 0.02, blue: 0.02, alpha: 0.9), UIColor(red: 0.3, green: 0.02, blue: 0.02, alpha: 0), s / 2)
        }, constant: false)
    }

    private func quad(_ m: MXMaterial, _ size: CGFloat) -> MXNode {
        let p = MXPlane(width: size, height: size)
        p.firstMaterial = m
        let n = MXNode(geometry: p)
        n.castsShadow = false
        n.renderingOrder = 40
        return n
    }

    private func put(_ n: MXNode, floor: Int) {
        n.removeFromParentNode()
        roots[max(0, min(roots.count - 1, floor))].addChildNode(n)
    }

    private func particle(_ m: MXMaterial, floor: Int, at p: MXVector3, vel: MXVector3, life: Float, size: Float, grow: Float, gravity: Float) {
        let n: MXNode
        if parts.count > 90 { return }
        n = quad(m, 1)
        n.position = p
        n.scale = MXVector3(size, size, size)
        n.renderingOrder = 41
        put(n, floor: floor)
        parts.append(Part(node: n, vel: vel, life: life, max: life, grow: grow, base: size, gravity: gravity))
    }

    func spawn(_ im: TacticalEngine.Impact) {
        let fl = TMap.floorOf(im.pos)
        let x = Float(im.pos.x), z = Float(im.pos.y)
        func r(_ a: Float, _ b: Float) -> Float { Float.random(in: a...b) }
        switch im.kind {
        case 0, 2:
            let nx = Float(im.nx), nz = Float(im.ny)
            let y = r(22, 52)
            // hole decal flat on the wall face, facing out along the normal
            if im.kind == 0 {
                if holes[fl].count < 40 {
                    let h = quad(holeMat, CGFloat(r(5, 8)))
                    h.renderingOrder = 30
                    holes[fl].append(h)
                }
                let list = holes[fl]
                if !list.isEmpty {
                    let h = list[holeNext[fl] % list.count]
                    holeNext[fl] += 1
                    put(h, floor: fl)
                    h.position = MXVector3(x + nx * 0.5, y, z + nz * 0.5)
                    h.eulerAngles = MXVector3(0, atan2(nx, nz), 0)
                    h.isHidden = false
                }
            }
            // dust and sparks / glass chips
            for _ in 0..<2 { particle(dustMat, floor: fl, at: MXVector3(x + nx, y, z + nz), vel: MXVector3(nx * r(4, 10) + r(-3, 3), r(1, 6), nz * r(4, 10) + r(-3, 3)), life: r(0.5, 0.9), size: r(3, 5), grow: r(7, 12), gravity: -2) }
            for _ in 0..<(im.kind == 0 ? 4 : 6) {
                particle(im.kind == 0 ? sparkMat : chipMat, floor: fl, at: MXVector3(x + nx, y, z + nz), vel: MXVector3(nx * r(40, 110) + r(-40, 40), r(10, 60), nz * r(40, 110) + r(-40, 40)), life: r(0.12, 0.3), size: r(1.2, 2.2), grow: -3, gravity: 220)
            }
        case 1:
            for _ in 0..<5 { particle(bloodMat, floor: fl, at: MXVector3(x, r(26, 46), z), vel: MXVector3(r(-35, 35), r(10, 55), r(-35, 35)), life: r(0.25, 0.55), size: r(2, 3.5), grow: 2, gravity: 160) }
        default:
            // pool on the floor under a fallen player
            if bloods[fl].count < 16 {
                let p = quad(poolMat, 1)
                p.renderingOrder = 29
                bloods[fl].append(p)
            }
            let list = bloods[fl]
            if !list.isEmpty {
                let p = list[bloodNext[fl] % list.count]
                bloodNext[fl] += 1
                put(p, floor: fl)
                let s = r(16, 26)
                p.scale = MXVector3(s, s, s)
                p.position = MXVector3(x, 0.45, z)
                p.eulerAngles = MXVector3(-Float.pi / 2, 0, 0)
                p.isHidden = false
            }
        }
    }

    func update(_ dt: Float, camPlan: CGPoint) {
        var i = 0
        while i < parts.count {
            parts[i].life -= dt
            if parts[i].life <= 0 {
                parts[i].node.removeFromParentNode()
                parts.remove(at: i)
                continue
            }
            let p = parts[i]
            let k = p.life / p.max
            let n = p.node
            n.position = MXVector3(n.position.x + p.vel.x * dt, n.position.y + p.vel.y * dt, n.position.z + p.vel.z * dt)
            parts[i].vel = MXVector3(p.vel.x * (1 - 2 * dt), p.vel.y - p.gravity * dt, p.vel.z * (1 - 2 * dt))
            let s = max(0.2, p.base + p.grow * (1 - k))
            n.scale = MXVector3(s, s, s)
            n.opacity = CGFloat(min(1, k * 1.6))
            // billboard toward the viewer around the vertical axis
            n.eulerAngles = MXVector3(0, Float(atan2(camPlan.x - CGFloat(n.position.x), camPlan.y - CGFloat(n.position.z))), 0)
            i += 1
        }
    }

    func clear() {
        for p in parts { p.node.removeFromParentNode() }
        parts = []
        for l in holes + bloods { for n in l { n.removeFromParentNode() } }
        holes = [[], [], []]; bloods = [[], [], []]
    }
}
