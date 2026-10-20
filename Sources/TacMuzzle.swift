import SwiftUI
import UIKit

/// first-person muzzle flash: a camera-facing starburst plus a cross of side jets, all textured quads drawn once
enum MuzzleFX {
    private static var fronts: [UIImage] = []
    private static var jet: UIImage?

    private static func render(_ w: CGFloat, _ h: CGFloat, _ draw: (CGContext) -> Void) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        f.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: f).image { draw($0.cgContext) }
    }

    private static func glow(_ g: CGContext, _ c: CGPoint, _ r: CGFloat, _ inner: UIColor, _ outer: UIColor) {
        let cols = [inner.cgColor, outer.cgColor] as CFArray
        if let gr = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) {
            g.drawRadialGradient(gr, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
        }
    }

    private static func star(_ seed: UInt64) -> UIImage {
        render(256, 256) { g in
            var s = seed &* 2862933555777941757 &+ 3037000493
            func rnd() -> CGFloat { s = s &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((s >> 33) & 0xFFFF) / 65535 }
            let c = CGPoint(x: 128, y: 128)
            glow(g, c, 126, UIColor(red: 1, green: 0.62, blue: 0.2, alpha: 0.55), UIColor(red: 1, green: 0.4, blue: 0.05, alpha: 0))
            let n = 7 + Int(rnd() * 4)
            for i in 0..<n {
                let a = (CGFloat(i) / CGFloat(n)) * 2 * .pi + rnd() * 0.5
                let len = 70 + rnd() * 54
                let wd = 5 + rnd() * 9
                g.saveGState()
                g.translateBy(x: c.x, y: c.y)
                g.rotate(by: a)
                g.beginPath()
                g.move(to: CGPoint(x: 0, y: -wd))
                g.addLine(to: CGPoint(x: len, y: 0))
                g.addLine(to: CGPoint(x: 0, y: wd))
                g.closePath()
                g.setFillColor(UIColor(red: 1, green: 0.82 - rnd() * 0.2, blue: 0.35, alpha: 0.92).cgColor)
                g.fillPath()
                g.restoreGState()
            }
            glow(g, c, 46, UIColor(red: 1, green: 1, blue: 0.94, alpha: 1), UIColor(red: 1, green: 0.78, blue: 0.3, alpha: 0))
        }
    }

    private static func jetImage() -> UIImage {
        render(256, 96) { g in
            let c = CGPoint(x: 18, y: 48)
            g.saveGState()
            g.translateBy(x: c.x, y: c.y)
            g.scaleBy(x: 2.6, y: 0.62)
            glow(g, .zero, 90, UIColor(red: 1, green: 0.9, blue: 0.55, alpha: 0.95), UIColor(red: 1, green: 0.45, blue: 0.08, alpha: 0))
            g.restoreGState()
            g.saveGState()
            g.translateBy(x: c.x, y: c.y)
            g.scaleBy(x: 1.5, y: 0.34)
            glow(g, .zero, 70, UIColor(red: 1, green: 1, blue: 0.95, alpha: 1), UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 0))
            g.restoreGState()
        }
    }

    private static func mat(_ img: UIImage) -> MXMaterial {
        let m = MXMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = img
        m.emission.contents = img
        m.isDoubleSided = true
        m.readsFromDepthBuffer = false
        m.writesToDepthBuffer = false
        return m
    }

    /// node placed at the muzzle; the barrel points down -z. Use `pulse` each time a shot starts.
    static func make() -> MXNode {
        if fronts.isEmpty { fronts = (1...3).map { star(UInt64($0) * 977) } }
        if jet == nil { jet = jetImage() }
        let root = MXNode()
        root.castsShadow = false
        for (i, img) in fronts.enumerated() {
            let p = MXPlane(width: 13, height: 13)
            p.firstMaterial = mat(img)
            let n = MXNode(geometry: p)
            n.name = "front\(i)"
            n.position = MXVector3(0, 0, -1.5)
            n.renderingOrder = 2000
            n.castsShadow = false
            n.isHidden = i != 0
            root.addChildNode(n)
        }
        let holder = MXNode()
        holder.eulerAngles = MXVector3(0, Float.pi / 2, 0)
        holder.position = MXVector3(0, 0, -0.5)
        for k in 0..<2 {
            let p = MXPlane(width: 24, height: 9)
            p.firstMaterial = mat(jet!)
            let n = MXNode(geometry: p)
            n.position = MXVector3(10, 0, 0)
            n.eulerAngles = MXVector3(k == 0 ? 0 : Float.pi / 2, 0, 0)
            n.renderingOrder = 2000
            n.castsShadow = false
            holder.addChildNode(n)
        }
        root.addChildNode(holder)
        return root
    }

    /// randomise size, roll and starburst variant
    static func pulse(_ f: MXNode) {
        let s = Float.random(in: 0.75...1.25)
        f.scale = MXVector3(s, s, s)
        f.eulerAngles = MXVector3(0, 0, Float.random(in: 0...6.28))
        let k = Int.random(in: 0..<3)
        for c in f.childNodes where c.name?.hasPrefix("front") == true { c.isHidden = c.name != "front\(k)" }
    }
}
