import SwiftUI
import UIKit

// MARK: - SwiftUI host

struct TacSceneView: UIViewRepresentable {
    let bridge: TacScene
    func makeUIView(context: Context) -> MXView { bridge.view }
    func updateUIView(_ uiView: MXView, context: Context) {}
}

private struct LCG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFF) / 65535
    }
}

private func ui(_ c: (CGFloat, CGFloat, CGFloat), _ k: CGFloat = 1) -> UIColor {
    UIColor(red: min(1, c.0 * k), green: min(1, c.1 * k), blue: min(1, c.2 * k), alpha: 1)
}

// MARK: - Scene bridge

final class TacScene {
    var dollhouse = false
    let scene = MXScene()
    let view = MXView(frame: .zero)
    let camNode = MXNode()
    let vm = TwViewModel()
    var camX: CGFloat = 0
    var camZ: CGFloat = 0
    var started = false
    let floorRoot = [MXNode(), MXNode(), MXNode()]
    var breakNodes: [Int: (MXNode, MXNode)] = [:]
    var brokenSet: Set<Int> = []
    var debris: [MXNode] = []
    var debrisV: [SIMD3<Float>] = []
    var debrisLife: [Float] = []
    var debrisFloor: [Int] = []
    var debrisMats: [MXMaterial] = []
    var lastResetTick = 0
    var focusFloor = 0
    var stackAnim: Float = 0
    var stackPrev = -1
    var liftF: Float = 0
    var impactFX: TacImpactFX?
    var muzzleLight: MXNode?
    var expoCur: Float = 1
    var stairWas = false
    var stackT: Double = 0
    let stackH: Float = 82
    var linkedFloors = Set<Int>()
    var stairNodes: [Int: [MXNode]] = [:]
    var rubbleNodes: [Int: MXNode] = [:]
    var camFloor = 0
    var fpMode = false
    var fpFwd = CGPoint(x: 1, y: 0)
    var fpEye = CGPoint.zero
    var ceilNodes: [MXNode] = []

    var roots: [MXNode] = []
    var bodies: [MXNode] = []
    var heads: [MXNode] = []
    var guns: [MXNode] = []
    var flashes: [MXNode] = []
    var headKey: [String] = []
    var shirts: [MXMaterial] = []
    var kevs: [MXNode] = []
    var helms: [MXNode] = []
    var heavies: [MXNode] = []
    var hats: [MXNode] = []
    var faceMats: [MXMaterial] = []
    var preset = 1
    var lookOn = false
    var yaw: CGFloat = 0
    var pitch: CGFloat = 1.0
    var dist: CGFloat = 430
    var legLs: [MXNode] = []
    var deadK = [Float](repeating: 0, count: 64)
    var mvK = [Float](repeating: 0, count: 64)
    var legRs: [MXNode] = []
    var gunVars: [[MXNode]] = []
    var gunShown: [Int] = []
    var walkPh: [CGFloat] = []
    var lastPos: [CGPoint] = []
    var bulletPool: [MXNode] = []
    var nadePool: [MXNode] = []
    var boomPool: [MXNode] = []
    var smokePool: [MXNode] = []
    var packNodes: [MXNode] = []
    var lootNodes: [MXNode] = []
    var dynNodes: [MXNode] = []
    var evGas: MXNode? = nil
    var evBeam: MXNode? = nil
    var stormSegs: [[MXNode]] = [[], [], []]
    var lastStormRad: CGFloat = -1
    var lastStormC = CGPoint.zero
    let bombNode = MXNode()

    private var texCache: [String: UIImage] = [:]
    private let props = TwProps()
    private var doorLeaves: [[MXNode]] = []
    private var doorHoriz: [Bool] = []
    private var doorAngShown: [Float] = []
    private var sunNode: MXNode? = nil
    private var lamps: [(MXLight, CGFloat)] = []
    private var lastT = CACurrentMediaTime()
    private var fpsEMA: CGFloat = 60
    private var lowT: CGFloat = 0
    private var qual = 2

    // MARK: textures

    private func makeTex(_ key: String, _ draw: (CGContext, CGFloat) -> Void) -> UIImage {
        if let t = texCache[key] { return t }
        let s: CGFloat = 128
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 2
        fmt.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: s, height: s), format: fmt).image { c in
            draw(c.cgContext, s)
            grimeOverlay(c.cgContext, s, key)
        }
        texCache[key] = img
        return img
    }

    private func grimeOverlay(_ g: CGContext, _ s: CGFloat, _ key: String) {
        var r = LCG(s: UInt64(abs(key.hashValue) % 100000) + 17)
        for _ in 0..<18 {
            let w = 18 + r.next() * 70, h = 12 + r.next() * 50
            g.setFillColor(UIColor.black.withAlphaComponent(0.05 + r.next() * 0.09).cgColor)
            g.fillEllipse(in: CGRect(x: r.next() * s - w / 2, y: r.next() * s - h / 2, width: w, height: h))
        }
        for _ in 0..<7 {
            g.setFillColor(UIColor(red: 0.12, green: 0.09, blue: 0.05, alpha: 0.05 + r.next() * 0.08).cgColor)
            g.fill(CGRect(x: r.next() * s, y: r.next() * s * 0.5, width: 1 + r.next() * 3, height: 20 + r.next() * 70))
        }
        for _ in 0..<260 {
            g.setFillColor(UIColor.black.withAlphaComponent(0.08 + r.next() * 0.14).cgColor)
            let d = 0.5 + r.next() * 0.9
            g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: d, height: d))
        }
        for _ in 0..<90 {
            g.setFillColor(UIColor.white.withAlphaComponent(0.05 + r.next() * 0.09).cgColor)
            g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: 0.6, height: 0.6))
        }
    }

    private func woodTex(_ base: (CGFloat, CGFloat, CGFloat), _ key: String) -> UIImage {
        makeTex(key) { g, s in
            ui(base).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 7)
            for row in 0..<4 {
                let y = CGFloat(row) * 32
                let shade = 0.9 + r.next() * 0.2
                ui(base, shade).setFill(); g.fill(CGRect(x: 0, y: y, width: s, height: 32))
                UIColor.black.withAlphaComponent(0.35).setFill(); g.fill(CGRect(x: 0, y: y, width: s, height: 2))
                let sx = CGFloat(row % 2) * 64 + r.next() * 20
                g.fill(CGRect(x: sx, y: y, width: 2, height: 32))
                for _ in 0..<5 {
                    UIColor.black.withAlphaComponent(0.08).setFill()
                    g.fill(CGRect(x: r.next() * s, y: y + 4 + r.next() * 24, width: 20 + r.next() * 30, height: 1))
                }
            }
        }
    }

    private func tileTex(_ base: (CGFloat, CGFloat, CGFloat), _ key: String) -> UIImage {
        makeTex(key) { g, s in
            ui(base).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 11)
            for i in 0..<2 {
                for j in 0..<2 {
                    ui(base, 0.94 + r.next() * 0.12).setFill()
                    g.fill(CGRect(x: CGFloat(i) * 64, y: CGFloat(j) * 64, width: 64, height: 64))
                }
            }
            UIColor.black.withAlphaComponent(0.4).setFill()
            g.fill(CGRect(x: 0, y: 0, width: s, height: 3)); g.fill(CGRect(x: 0, y: 64, width: s, height: 3))
            g.fill(CGRect(x: 0, y: 0, width: 3, height: s)); g.fill(CGRect(x: 64, y: 0, width: 3, height: s))
        }
    }

    private func noiseTex(_ base: (CGFloat, CGFloat, CGFloat), _ key: String, dots: Int, grid: Bool) -> UIImage {
        makeTex(key) { g, s in
            ui(base).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 23)
            for _ in 0..<dots {
                (r.next() > 0.5 ? UIColor.white : UIColor.black).withAlphaComponent(0.07).setFill()
                g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: 2, height: 2))
            }
            if grid {
                UIColor.black.withAlphaComponent(0.3).setFill()
                g.fill(CGRect(x: 0, y: 0, width: s, height: 2)); g.fill(CGRect(x: 0, y: 0, width: 2, height: s))
            }
        }
    }

    private func brickTex() -> UIImage {
        makeTex("brick") { g, s in
            UIColor(red: 0.2, green: 0.22, blue: 0.27, alpha: 1).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 5)
            for row in 0..<8 {
                let y = CGFloat(row) * 16
                let off: CGFloat = row % 2 == 0 ? 0 : 16
                for k in -1..<5 {
                    let x = CGFloat(k) * 32 + off
                    let t = 0.85 + r.next() * 0.3
                    UIColor(red: 0.42 * t, green: 0.45 * t, blue: 0.52 * t, alpha: 1).setFill()
                    g.fill(CGRect(x: x + 1, y: y + 1, width: 30, height: 14))
                }
            }
        }
    }

    private func sandBlockTex() -> UIImage {
        makeTex("sandblock") { g, s in
            UIColor(red: 0.55, green: 0.43, blue: 0.29, alpha: 1).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 41)
            for row in 0..<6 {
                let y = CGFloat(row) * s / 6
                var x: CGFloat = -r.next() * 30
                while x < s {
                    let w = 34 + r.next() * 34
                    let t = 0.88 + r.next() * 0.24
                    UIColor(red: 0.84 * t, green: 0.70 * t, blue: 0.50 * t, alpha: 1).setFill()
                    g.fill(CGRect(x: x + 1.5, y: y + 1.5, width: w - 3, height: s / 6 - 3))
                    UIColor.black.withAlphaComponent(0.06 + r.next() * 0.08).setFill()
                    g.fill(CGRect(x: x + 1.5, y: y + s / 6 - 9, width: w - 3, height: 6))
                    x += w
                }
            }
            for _ in 0..<900 {
                (r.next() > 0.5 ? UIColor.white : UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1)).withAlphaComponent(0.06).setFill()
                g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: 2 + r.next() * 3, height: 2))
            }
            UIColor(red: 0.25, green: 0.17, blue: 0.1, alpha: 0.35).setStroke()
            for _ in 0..<5 {
                let p = UIBezierPath(); var cx = r.next() * s, cy = r.next() * s
                p.move(to: CGPoint(x: cx, y: cy))
                for _ in 0..<4 { cx += (r.next() - 0.5) * 14; cy += r.next() * 12; p.addLine(to: CGPoint(x: cx, y: cy)) }
                p.lineWidth = 1; p.stroke()
            }
        }
    }

    private func plasterTex() -> UIImage {
        makeTex("sandplaster") { g, s in
            UIColor(red: 0.82, green: 0.69, blue: 0.5, alpha: 1).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 77)
            for _ in 0..<40 {
                UIColor(red: 0.6 + r.next() * 0.3, green: 0.5 + r.next() * 0.2, blue: 0.35, alpha: 0.1).setFill()
                g.fillEllipse(in: CGRect(x: r.next() * s, y: r.next() * s, width: 20 + r.next() * 50, height: 20 + r.next() * 50))
            }
            for _ in 0..<1200 {
                (r.next() > 0.5 ? UIColor.white : UIColor.black).withAlphaComponent(0.06).setFill()
                g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: 2, height: 2))
            }
        }
    }

    private func cinderTex() -> UIImage {
        makeTex("cinder") { g, s in
            UIColor(red: 0.30, green: 0.31, blue: 0.33, alpha: 1).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 91)
            for row in 0..<4 {
                let y = CGFloat(row) * 32
                let o: CGFloat = row % 2 == 0 ? 0 : 32
                for k in -1..<3 {
                    let t = 0.86 + r.next() * 0.28
                    UIColor(red: 0.52 * t, green: 0.53 * t, blue: 0.55 * t, alpha: 1).setFill()
                    g.fill(CGRect(x: CGFloat(k) * 64 + o + 1.5, y: y + 1.5, width: 61, height: 29))
                    UIColor.black.withAlphaComponent(0.1).setFill()
                    g.fill(CGRect(x: CGFloat(k) * 64 + o + 1.5, y: y + 24, width: 61, height: 6))
                }
            }
        }
    }

    private func paperTex() -> UIImage {
        makeTex("paper") { g, s in
            UIColor(red: 0.86, green: 0.8, blue: 0.68, alpha: 1).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var x: CGFloat = 0
            while x < s {
                UIColor(red: 0.74, green: 0.62, blue: 0.5, alpha: 0.35).setFill(); g.fill(CGRect(x: x, y: 0, width: 5, height: s))
                UIColor.white.withAlphaComponent(0.12).setFill(); g.fill(CGRect(x: x + 9, y: 0, width: 2, height: s))
                x += 21.3
            }
            var r = LCG(s: 5)
            for _ in 0..<30 {
                UIColor(red: 0.6, green: 0.4, blue: 0.3, alpha: 0.12).setFill()
                g.fillEllipse(in: CGRect(x: r.next() * s, y: r.next() * s, width: 5, height: 8))
            }
        }
    }

    private func grassTex() -> UIImage {
        makeTex("grass") { g, s in
            UIColor(red: 0.2, green: 0.34, blue: 0.15, alpha: 1).setFill(); g.fill(CGRect(x: 0, y: 0, width: s, height: s))
            var r = LCG(s: 313)
            for _ in 0..<40 {
                UIColor(red: 0.3, green: 0.24, blue: 0.14, alpha: 0.18).setFill()
                g.fillEllipse(in: CGRect(x: r.next() * s, y: r.next() * s, width: 8 + r.next() * 18, height: 6 + r.next() * 12))
            }
            for _ in 0..<520 {
                let t = 0.7 + r.next() * 0.6
                UIColor(red: 0.18 * t, green: 0.36 * t, blue: 0.14 * t, alpha: 0.85).setFill()
                g.fill(CGRect(x: r.next() * s, y: r.next() * s, width: 1.5, height: 3 + r.next() * 4))
            }
        }
    }

    private func siteTex(_ letter: String, _ w: CGFloat, _ h: CGFloat) -> UIImage {
        let sz = CGSize(width: w * 2, height: h * 2)
        return UIGraphicsImageRenderer(size: sz).image { c in
            let g = c.cgContext
            UIColor(red: 0.15, green: 0.45, blue: 0.85, alpha: 0.28).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: 20).fill()
            let p = UIBezierPath(roundedRect: CGRect(x: 14, y: 14, width: sz.width - 28, height: sz.height - 28), cornerRadius: 16)
            p.lineWidth = 7
            p.setLineDash([28, 16], count: 2, phase: 0)
            UIColor(red: 0.98, green: 0.8, blue: 0.08, alpha: 0.95).setStroke()
            p.stroke()
            let cr = CGRect(x: sz.width / 2 - 48, y: sz.height / 2 - 48, width: 96, height: 96)
            UIColor.black.withAlphaComponent(0.55).setFill(); g.fillEllipse(in: cr)
            UIColor.white.setStroke(); g.setLineWidth(5); g.strokeEllipse(in: cr)
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 56, weight: .heavy), .foregroundColor: UIColor.white]
            let tsz = (letter as NSString).size(withAttributes: attrs)
            (letter as NSString).draw(at: CGPoint(x: cr.midX - tsz.width / 2, y: cr.midY - tsz.height / 2), withAttributes: attrs)
        }
    }

    private func ringed(_ img: UIImage?, emoji: String, color: UIColor) -> UIImage {
        let s: CGFloat = 96
        return UIGraphicsImageRenderer(size: CGSize(width: s, height: s)).image { c in
            let g = c.cgContext
            let rect = CGRect(x: 4, y: 4, width: s - 8, height: s - 8)
            g.saveGState()
            UIBezierPath(ovalIn: rect).addClip()
            if let i = img {
                i.draw(in: rect)
            } else {
                color.withAlphaComponent(0.5).setFill(); g.fill(rect)
                (emoji as NSString).draw(in: rect.insetBy(dx: 18, dy: 14), withAttributes: [.font: UIFont.systemFont(ofSize: 52, weight: .heavy), .foregroundColor: UIColor.white])
            }
            g.restoreGState()
            color.setStroke()
            let p = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            p.lineWidth = 6
            p.stroke()
        }
    }

    // MARK: materials / nodes

    private func mat(_ img: UIImage?, color: UIColor = .gray, sx: CGFloat = 1, sy: CGFloat = 1, emission: UIColor? = nil) -> MXMaterial {
        let m = MXMaterial()
        if let i = img {
            m.diffuse.contents = i
            m.diffuse.wrapS = .repeat
            m.diffuse.wrapT = .repeat
            m.diffuse.contentsTransform = MXMatrix4MakeScale(Float(sx), Float(sy), 1)
            m.normal.contents = i
            m.normal.intensity = 0.7
            m.normal.wrapS = .repeat
            m.normal.wrapT = .repeat
            m.normal.contentsTransform = MXMatrix4MakeScale(Float(sx), Float(sy), 1)
        } else {
            m.diffuse.contents = color
        }
        m.lightingModel = .blinn
        m.specular.contents = UIColor(white: img == nil ? 0.15 : 0.22, alpha: 1)
        m.shininess = 0.3
        if let e = emission { m.emission.contents = e }
        return m
    }

    /// splits a rect into the pieces left after removing the holes
    private func carve(_ r: CGRect, _ holes: [CGRect]) -> [CGRect] {
        var pieces = [r]
        for h in holes {
            var next: [CGRect] = []
            for p in pieces {
                let i = p.intersection(h)
                if i.isNull || i.width < 0.5 || i.height < 0.5 { next.append(p); continue }
                if i.minY > p.minY { next.append(CGRect(x: p.minX, y: p.minY, width: p.width, height: i.minY - p.minY)) }
                if i.maxY < p.maxY { next.append(CGRect(x: p.minX, y: i.maxY, width: p.width, height: p.maxY - i.maxY)) }
                if i.minX > p.minX { next.append(CGRect(x: p.minX, y: i.minY, width: i.minX - p.minX, height: i.height)) }
                if i.maxX < p.maxX { next.append(CGRect(x: i.maxX, y: i.minY, width: p.maxX - i.maxX, height: i.height)) }
            }
            pieces = next
        }
        return pieces
    }

    private func stairHoles(_ floor: Int, upper: Bool) -> [CGRect] {
        TMap.stairs.indices.filter { upper ? TMap.stairLo[$0] + 1 == floor : TMap.stairLo[$0] == floor }.map { TMap.stairRect($0, floor: floor) }
    }

    private func box(_ r: CGRect, h: CGFloat, y0: CGFloat = 0, mats: [MXMaterial], chamfer: CGFloat = 0) -> MXNode {
        let g = MXBox(width: r.width, height: h, length: r.height, chamferRadius: chamfer)
        g.materials = mats
        let n = MXNode(geometry: g)
        n.position = MXVector3(Float(r.midX), Float(y0 + h / 2), Float(r.midY))
        return n
    }

    private func solid(_ r: CGRect, h: CGFloat, y0: CGFloat = 0, color: UIColor, top: UIColor? = nil, chamfer: CGFloat = 0, emission: UIColor? = nil) -> MXNode {
        let side = mat(nil, color: color, emission: emission)
        let t = mat(nil, color: top ?? color, emission: emission)
        return box(r, h: h, y0: y0, mats: [side, side, side, side, t, side], chamfer: chamfer)
    }

    // MARK: build

    func build(_ e: TacticalEngine) {
        MXRenderer.flatShade = TMap.kind == 4
        MXGeometry.lowPolyCap = TMap.kind == 4 ? 10 : 64
        defer { MXGeometry.lowPolyCap = 64 }
        let th = e.theme
        func C(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
        let skyCols: [UIColor] = TMap.look == 2 ? [C(0.35, 0.4, 0.5), C(0.65, 0.62, 0.6), C(0.9, 0.72, 0.5)] : TMap.look == 3 ? [C(0.3, 0.55, 0.9), C(0.72, 0.84, 0.95), C(0.98, 0.9, 0.7)] : TMap.look == 1 ? [C(0.42, 0.5, 0.58), C(0.66, 0.74, 0.78), C(0.82, 0.85, 0.8)] : th == 1 ? [C(0.02, 0.04, 0.12), C(0.05, 0.09, 0.2), C(0.12, 0.16, 0.3)] : (th == 2 ? [C(0.18, 0.07, 0.28), C(0.65, 0.25, 0.2), C(0.95, 0.55, 0.2)] : [C(0.25, 0.52, 0.9), C(0.62, 0.8, 0.96), C(0.95, 0.88, 0.72)])
        let fogC: UIColor = TMap.look == 2 ? C(0.55, 0.52, 0.5) : TMap.look == 3 ? C(0.85, 0.76, 0.6) : TMap.look == 1 ? C(0.6, 0.67, 0.65) : th == 1 ? C(0.04, 0.06, 0.12) : (th == 2 ? C(0.2, 0.11, 0.1) : C(0.2, 0.19, 0.18))
        let ambI: CGFloat = th == 1 ? 360 : (th == 2 ? 380 : 330)
        let ambC: UIColor = th == 1 ? C(0.55, 0.65, 0.95) : (th == 2 ? C(0.9, 0.65, 0.7) : C(0.78, 0.8, 0.9))
        let sunI: CGFloat = (th == 1 ? 500 : (th == 2 ? 900 : 1500)) * 0.4
        let sunC: UIColor = th == 1 ? C(0.6, 0.75, 1) : (th == 2 ? C(1, 0.55, 0.3) : C(1, 0.93, 0.78))
        let skyImg = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 256)).image { c in
            let cs = CGColorSpaceCreateDeviceRGB()
            if let gr = CGGradient(colorsSpace: cs, colors: skyCols.map { $0.cgColor } as CFArray, locations: [0, 0.6, 1]) {
                c.cgContext.drawLinearGradient(gr, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
            }
        }
        scene.background.contents = skyImg
        scene.fogColor = fogC
        scene.fogStartDistance = fpMode ? (TMap.look == 1 ? 400 : (TMap.look >= 2 ? 700 : 650)) : 1400
        scene.fogEndDistance = fpMode ? (TMap.look == 1 ? 1800 : (TMap.look >= 2 ? 2500 : 2300)) : 4200
        scene.fogDensityExponent = 1.4
        let root = scene.rootNode
        lamps = []
        for i in 0..<3 {
            floorRoot[i].position = MXVector3(-Float(TMap.origin(i)), 0, 0)
            floorRoot[i].isHidden = i != 0
            root.addChildNode(floorRoot[i])
        }
        func fr(_ x: CGFloat) -> MXNode { floorRoot[TMap.floorOfX(x)] }

        let amb = MXNode()
        amb.light = MXLight()
        amb.light?.type = .ambient
        amb.light?.intensity = ambI
        amb.light?.color = ambC
        root.addChildNode(amb)

        let sun = MXNode()
        let sl = MXLight()
        sl.type = .directional
        sl.intensity = sunI
        sl.color = sunC
        sl.castsShadow = true
        sl.shadowMode = .deferred
        sl.shadowRadius = 5
        sl.shadowSampleCount = 8
        sl.shadowColor = UIColor(white: 0, alpha: 0.72)
        sl.maximumShadowDistance = 1200
        sun.light = sl
        sun.position = MXVector3(-300, 650, -300)
        root.addChildNode(sun)
        sun.look(at: MXVector3(0, 0, 0))
        sunNode = sun
        let fill = MXNode()
        let fl = MXLight()
        fl.type = .directional
        fl.intensity = 260
        fl.color = UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1)
        fill.light = fl
        fill.position = MXVector3(400, 500, 500)
        root.addChildNode(fill)
        fill.look(at: MXVector3(0, 0, 0))

        let lampCols: [UIColor] = [C(0.75, 0.86, 1), C(1, 0.84, 0.58), C(1, 0.72, 0.46)]
        for rm in TMap.rooms where rm.mat < 6 {
            let n = TMap.kind == 7 ? max(1, Int(rm.r.width / 350)) : max(1, Int(rm.r.width / 600))
            for j in 0..<n {
                let lx = rm.r.minX + rm.r.width * (CGFloat(j) + 0.5) / CGFloat(n)
                let nd = MXNode()
                let li = MXLight()
                li.type = .omni
                li.intensity = 430
                lamps.append((li, 430))
                li.color = lampCols[rm.fl]
                li.attenuationStartDistance = 50
                li.attenuationEndDistance = 500
                nd.light = li
                nd.position = MXVector3(Float(lx), 64, Float(rm.r.midY))
                floorRoot[rm.fl].addChildNode(nd)
                let fix = MXNode(geometry: MXCylinder(radius: 9, height: 2.5))
                fix.geometry?.firstMaterial = mat(nil, color: C(1, 0.95, 0.8), emission: lampCols[rm.fl])
                fix.position = MXVector3(Float(lx), 78, Float(rm.r.midY))
                fix.castsShadow = false
                floorRoot[rm.fl].addChildNode(fix)
            }
        }

        let cam = MXCamera()
        cam.fieldOfView = 52
        cam.zNear = 10
        cam.zFar = 3000
        cam.wantsHDR = true
        cam.bloomIntensity = 0.7
        cam.bloomThreshold = 0.75
        cam.bloomBlurRadius = 6
        cam.vignettingIntensity = 0.7
        cam.vignettingPower = 1.2
        cam.screenSpaceAmbientOcclusionIntensity = 0.9
        cam.screenSpaceAmbientOcclusionRadius = 10
        cam.saturation = 1.28
        cam.contrast = 0.24
        if TMap.kind == 7 {
            cam.lensDirt = 0.35
            cam.bloomIntensity = 0.6
            cam.saturation = 1.12
            cam.contrast = 0.18
        }
        camNode.camera = cam
        root.addChildNode(camNode)
        camNode.addChildNode(vm.root)

        // modelled shell for the annex (Blender: PBR surfaces, trim, baked light and occlusion)
        var annex: [Int: [String: MXNode]] = [:]
        if TMap.kind == 7 {
            for f in 1...2 {
                guard let a = MXModel.load("annex_f\(f)") else { continue }
                var d: [String: MXNode] = [:]
                func scan(_ n: MXNode) {
                    for c in n.childNodes {
                        if let nm = c.name, ["shell", "ceil", "stairs", "fence"].contains(nm) { d[nm] = c } else { scan(c) }
                    }
                }
                scan(a)
                annex[f] = d
            }
            func noShadow(_ n: MXNode) { n.castsShadow = false; for c in n.childNodes { noShadow(c) } }
            for (f, d) in annex {
                for key in ["shell", "stairs", "fence"] {
                    guard let n = d[key] else { continue }
                    if key == "stairs" { noShadow(n) }
                    floorRoot[f].addChildNode(n)
                }
            }
        }

        // ceilings (only shown in first person)
        for i in 0..<3 {
            if TMap.kind == 7, let cn = annex[i]?["ceil"] {
                cn.isHidden = true
                floorRoot[i].addChildNode(cn)
                ceilNodes.append(cn)
                continue
            }
            let cm = MXMaterial()
            cm.diffuse.contents = UIColor(red: 0.72, green: 0.7, blue: 0.66, alpha: 1)
            cm.emission.contents = UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1)
            cm.isDoubleSided = true
            let cn = MXNode()
            let full = CGRect(x: TMap.origin(i), y: 0, width: TMap.W, height: TMap.H)
            for pc in carve(full, stairHoles(i, upper: false)) {
                let pl = MXPlane(width: pc.width, height: pc.height)
                pl.firstMaterial = cm
                let pn = MXNode(geometry: pl)
                pn.position = MXVector3(Float(pc.midX), Float(TMap.wallH) + 0.5, Float(pc.midY))
                pn.eulerAngles = MXVector3(Float.pi / 2, 0, 0)
                pn.castsShadow = false
                cn.addChildNode(pn)
            }
            cn.isHidden = true
            floorRoot[i].addChildNode(cn)
            ceilNodes.append(cn)
        }

        // floors
        let floorCols = TWorkshop.floorMatCols
        for rm in TMap.floorTiles {
            if TMap.kind == 7 && !annex.isEmpty && rm.name != "Yard" { continue }
            let b = floorCols[rm.mat]
            let img: UIImage
            switch rm.mat {
            case 6: img = grassTex()
            case 7: img = noiseTex(b, "dirt7", dots: 2200, grid: false)
            case 8: img = noiseTex(b, "asph8", dots: 3000, grid: true)
            case 0: img = noiseTex(b, "sand0", dots: 2600, grid: false)
            case 4: img = woodTex(b, "wood4")
            case 3, 5: img = tileTex(b, "tile\(rm.mat)")
            case 1: img = noiseTex(b, "slab", dots: 1800, grid: false)
            case 9, 17, 18, 19, 20, 21, 22, 23, 24, 25: img = noiseTex(b, "liq\(rm.mat)", dots: 700, grid: false)
            case 10, 11, 14, 15: img = noiseTex(b, "fx\(rm.mat)", dots: 2000, grid: false)
            case 12, 13, 16: img = tileTex(b, "tile\(rm.mat)")
            default: img = noiseTex(b, "carpet", dots: 1400, grid: false)
            }
            let tile: CGFloat = rm.mat == 6 ? 170 : (rm.mat == 1 ? 140 : (rm.mat == 3 || rm.mat == 5 ? 112 : 128))
            let side = mat(nil, color: ui(b, 0.5))
            let ffl = TMap.floorOfX(rm.r.midX)
            for pc in carve(rm.r, stairHoles(ffl, upper: true)) {
                let top = mat(img, sx: pc.width / tile, sy: pc.height / tile)
                let n = box(pc, h: 1, y0: ["Woods", "Yard", "Desert", "Harbor"].contains(rm.name) ? -2 : (rm.name == "Water" ? -6 : (rm.name == "Ground" ? -1.5 : -1)), mats: [side, side, side, side, top, side])
                fr(pc.midX).addChildNode(n)
            }
        }
        // rugs
        for rg in TMap.rugs {
            let c = UIColor(cgColor: UIColor(rg.1).cgColor)
            let n = solid(rg.0, h: 1.6, color: c, top: c)
            n.castsShadow = false
            fr(rg.0.midX).addChildNode(n)
        }
        // decals: stains, puddles, papers, debris, cracks (seeded per map so every match looks the same)
        var dr = LCG(s: UInt64(TMap.kind + 3) &* 7919 &+ 13)
        for rm in TMap.rooms where rm.mat != 6 {
            let area = rm.r.width * rm.r.height
            let n = min(60, max(3, Int(area / 26000)))
            for _ in 0..<n {
                let kind = Int(dr.next() * 7)
                let cx = rm.r.minX + 24 + dr.next() * max(1, rm.r.width - 60)
                let cy = rm.r.minY + 24 + dr.next() * max(1, rm.r.height - 60)
                var rects: [(CGRect, UIColor)] = []
                switch kind {
                case 0:
                    let w = 30 + dr.next() * 60
                    rects.append((CGRect(x: cx, y: cy, width: w, height: w * (0.55 + dr.next() * 0.5)), UIColor(white: 0.03, alpha: 0.26)))
                case 1:
                    let w = 24 + dr.next() * 50
                    rects.append((CGRect(x: cx, y: cy, width: w, height: w * (0.5 + dr.next() * 0.4)), UIColor(red: 0.1, green: 0.16, blue: 0.22, alpha: 0.4)))
                case 2:
                    for _ in 0..<3 { rects.append((CGRect(x: cx + dr.next() * 22, y: cy + dr.next() * 22, width: 7 + dr.next() * 5, height: 9 + dr.next() * 6), UIColor(white: 0.85, alpha: 0.8))) }
                case 3:
                    for _ in 0..<5 { rects.append((CGRect(x: cx + dr.next() * 26, y: cy + dr.next() * 26, width: 2 + dr.next() * 4, height: 2 + dr.next() * 4), UIColor(white: 0.32 + dr.next() * 0.2, alpha: 0.9))) }
                case 4:
                    rects.append((CGRect(x: cx, y: cy, width: 40 + dr.next() * 70, height: 1.3), UIColor(white: 0, alpha: 0.4)))
                case 5:
                    rects.append((CGRect(x: cx, y: cy, width: 16 + dr.next() * 10, height: 12 + dr.next() * 8), UIColor(red: 0.5, green: 0.38, blue: 0.22, alpha: 0.85)))
                default:
                    if dr.next() < 0.4 {
                        for _ in 0..<4 { rects.append((CGRect(x: cx + dr.next() * 14, y: cy + dr.next() * 14, width: 3 + dr.next() * 7, height: 3 + dr.next() * 6), UIColor(red: 0.28, green: 0.03, blue: 0.03, alpha: 0.7))) }
                    }
                }
                for (r, col) in rects {
                    let nd = solid(r, h: 0.4, y0: 0.05, color: col, top: col)
                    nd.castsShadow = false
                    fr(r.midX).addChildNode(nd)
                }
            }
        }
        // sites
        for i in 0..<2 where TMap.look != 1 && TMap.kind != 4 {
            let r = TMap.site(i)
            let m = mat(siteTex(i == 0 ? "A" : "B", r.width, r.height))
            m.lightingModel = .constant
            m.writesToDepthBuffer = false
            let clear = mat(nil, color: .clear)
            clear.transparency = 0
            let n = box(r, h: 0.4, y0: 2, mats: [clear, clear, clear, clear, m, clear])
            n.castsShadow = false
            n.renderingOrder = 5
            fr(r.midX).addChildNode(n)
        }
        // doors
        let doorTop = UIColor(red: 0.62, green: 0.5, blue: 0.32, alpha: 1)
        let frame = UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1)
        _ = doorTop
        for d in TMap.doors {
            let leaves = props.door(d)
            for lf in leaves { fr(d.midX).addChildNode(lf) }
            doorLeaves.append(leaves)
            doorHoriz.append(d.width > d.height)
            doorAngShown.append(-9)
            let horiz = d.width > d.height
            let p1 = horiz ? CGRect(x: d.minX - 3, y: d.midY - 6, width: 8, height: 12) : CGRect(x: d.midX - 6, y: d.minY - 3, width: 12, height: 8)
            let p2 = horiz ? CGRect(x: d.maxX - 5, y: d.midY - 6, width: 8, height: 12) : CGRect(x: d.midX - 6, y: d.maxY - 5, width: 12, height: 8)
            fr(d.midX).addChildNode(solid(p1, h: TMap.wallH, color: frame, top: frame, chamfer: 1.5))
            fr(d.midX).addChildNode(solid(p2, h: TMap.wallH, color: frame, top: frame, chamfer: 1.5))
            let lin = horiz ? CGRect(x: d.minX, y: d.midY - 6, width: d.width, height: 12) : CGRect(x: d.midX - 6, y: d.minY, width: 12, height: d.height)
            fr(d.midX).addChildNode(solid(lin, h: 10, y0: 71, color: frame, top: frame, chamfer: 1))
        }
        // walls (interior partitions are individual nodes so they can be shot out)
        let cinder = cinderTex()
        let paper = paperTex()
        let plank = woodTex((0.46, 0.33, 0.21), "attic")
        let wallH = TMap.wallH
        let capMats = [C(0.4, 0.41, 0.44), C(0.92, 0.88, 0.8), C(0.5, 0.38, 0.26)].map { mat(nil, color: $0) }
        let solidWalls = [MXNode(), MXNode(), MXNode()]
        let woodsMap = TMap.look >= 1
        let bark = TMap.look == 3 ? noiseTex((0.78, 0.66, 0.46), "sandstone", dots: 2400, grid: false) : (TMap.look == 2 ? cinder : woodTex((0.34, 0.24, 0.15), "bark"))
        for (k, o) in TMap.walls.enumerated() {
            if TMap.kind == 7 && !annex.isEmpty { continue }
            let wf = TMap.floorOfX(o.midX)
            let img = wf == 0 ? cinder : (wf == 1 ? (woodsMap ? bark : paper) : plank)
            let tile: CGFloat = wf == 1 ? 160 : 128
            let tall = woodsMap && wf == 1 && min(o.width, o.height) > 40
            let hh: CGFloat = tall ? 260 : wallH
            let front = mat(img, sx: o.width / tile, sy: hh / tile)
            let side = mat(img, sx: o.height / tile, sy: hh / tile)
            let n = box(o, h: hh, mats: [front, side, front, side, capMats[wf], front])
            if TMap.hp[k] > 0 { floorRoot[wf].addChildNode(n); breakNodes[k] = (n, floorRoot[wf]) }
            else { solidWalls[wf].addChildNode(n) }
        }
        for f in 0..<3 { chunked(solidWalls[f], into: floorRoot[f]) }
        // debris pool
        debrisMats = [C(0.88, 0.84, 0.74), C(0.55, 0.38, 0.22), C(0.42, 0.43, 0.46), C(0.3, 0.55, 0.25)].map { mat(nil, color: $0) }
        for i in 0..<56 {
            let d = MXNode(geometry: MXBox(width: 5, height: 5, length: 5, chamferRadius: 0))
            d.geometry?.firstMaterial = debrisMats[i % 4]
            d.isHidden = true
            d.castsShadow = false
            root.addChildNode(d)
            debris.append(d)
            debrisV.append(.zero)
            debrisLife.append(0)
            debrisFloor.append(0)
        }
        // stairs
        impactFX?.clear(); impactFX = nil
        stairNodes = [:]
        rubbleNodes = [:]
        for i in TMap.stairs.indices {
            var stepNodes: [MXNode] = []
            let lr = TMap.stairRect(i, floor: TMap.stairLo[i])
            let rub = solid(lr.insetBy(dx: 3, dy: 3), h: 26, color: UIColor(red: 0.32, green: 0.29, blue: 0.26, alpha: 1), top: UIColor(red: 0.4, green: 0.37, blue: 0.33, alpha: 1))
            rub.isHidden = true
            fr(lr.midX).addChildNode(rub)
            rubbleNodes[i] = rub
            if TMap.kind == 7, let sn = annex[TMap.stairLo[i]]?["stairs"] {
                stairNodes[i] = [sn]
                continue
            }
            if TMap.smooth {
                // one straight flight: 14 risers from the foot (maxY) to the head (minY), rising through the opening above
                let r0 = TMap.stairRect(i, floor: TMap.stairLo[i])
                let n = Int(TMap.stairSteps)
                let tread = r0.height / TMap.stairSteps
                let rise = TMap.riseH / TMap.stairSteps
                let wood = UIColor(red: 0.5, green: 0.37, blue: 0.24, alpha: 1)
                let riserC = UIColor(red: 0.34, green: 0.25, blue: 0.17, alpha: 1)
                let steel = UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
                for k in 0..<n {
                    let sr = CGRect(x: r0.minX, y: r0.maxY - CGFloat(k + 1) * tread, width: r0.width, height: tread + 0.4)
                    let top = CGFloat(k + 1) * rise
                    let tone = CGFloat(k % 2) * 0.03
                    let tc = UIColor(red: 0.5 + tone, green: 0.37 + tone, blue: 0.24 + tone, alpha: 1)
                    let st = solid(sr, h: top, color: riserC, top: tc)
                    st.castsShadow = false
                    fr(r0.midX).addChildNode(st)
                    stepNodes.append(st)
                    // handrails on both sides, stepped to follow the flight, with a post every third tread
                    for sx0 in [r0.minX + 1.5, r0.maxX - 4.5] {
                        let rl = solid(CGRect(x: sx0, y: sr.minY, width: 3, height: tread + 0.4), h: 3, y0: top + 26, color: steel, top: steel)
                        rl.castsShadow = false
                        fr(r0.midX).addChildNode(rl)
                        stepNodes.append(rl)
                        if k % 3 == 0 {
                            let po = solid(CGRect(x: sx0, y: sr.minY + tread * 0.4, width: 3, height: 3), h: 26, y0: top, color: steel, top: steel)
                            po.castsShadow = false
                            fr(r0.midX).addChildNode(po)
                            stepNodes.append(po)
                        }
                    }
                }
                _ = wood
                stairNodes[i] = stepNodes
                continue
            }
            for fl in TMap.stairLo[i]...(TMap.stairLo[i] + 1) {
                let r = TMap.stairRect(i, floor: fl)
                if fl == TMap.stairLo[i] {
                    let steps = 7
                    let sh = r.height / CGFloat(steps)
                    for k in 0..<steps {
                        let sr = CGRect(x: r.minX, y: r.maxY - CGFloat(k + 1) * sh, width: r.width, height: sh + 0.5)
                        let c = UIColor(red: 0.5 + 0.03 * CGFloat(k), green: 0.42 + 0.03 * CGFloat(k), blue: 0.3, alpha: 1)
                        let n = solid(sr, h: 3 + CGFloat(k) * 4.5, color: c, top: c)
                        n.castsShadow = false
                        fr(r.midX).addChildNode(n)
                        stepNodes.append(n)
                    }
                } else {
                    // open stairwell: descending steps below the floor line, dark walls around
                    let wallC = UIColor(red: 0.2, green: 0.17, blue: 0.14, alpha: 1)
                    let t: CGFloat = 3
                    let deep = CGFloat(stackH) - 2
                    for wr in [CGRect(x: r.minX - t, y: r.minY - t, width: r.width + 2 * t, height: t),
                               CGRect(x: r.minX - t, y: r.maxY, width: r.width + 2 * t, height: t),
                               CGRect(x: r.minX - t, y: r.minY, width: t, height: r.height),
                               CGRect(x: r.maxX, y: r.minY, width: t, height: r.height)] {
                        let w = solid(wr, h: deep, y0: -deep, color: wallC)
                        w.castsShadow = false
                        fr(r.midX).addChildNode(w)
                    }
                    let steps = 7
                    let sh = r.height / CGFloat(steps)
                    for k in 0..<steps {
                        let sr = CGRect(x: r.minX, y: r.minY + CGFloat(k) * sh, width: r.width, height: sh + 0.5)
                        let top = -(6 + CGFloat(k) * 11)
                        let c = UIColor(red: 0.5 - 0.02 * CGFloat(k), green: 0.42 - 0.02 * CGFloat(k), blue: 0.3, alpha: 1)
                        let n = solid(sr, h: 5, y0: top - 5, color: c, top: c)
                        n.castsShadow = false
                        fr(r.midX).addChildNode(n)
                        stepNodes.append(n)
                    }

                }
                let rail = UIColor(red: 0.95, green: 0.82, blue: 0.2, alpha: 1)
                let glow = UIColor(red: 0.5, green: 0.42, blue: 0.08, alpha: 1)
                let l = solid(CGRect(x: r.minX - 3, y: r.minY, width: 4, height: r.height), h: 22, color: rail, top: rail, emission: glow)
                let rr = solid(CGRect(x: r.maxX - 1, y: r.minY, width: 4, height: r.height), h: 22, color: rail, top: rail, emission: glow)
                l.castsShadow = false; rr.castsShadow = false
                fr(r.midX).addChildNode(l)
                fr(r.midX).addChildNode(rr)
                stepNodes.append(l); stepNodes.append(rr)
            }
            stairNodes[i] = stepNodes
        }
        // harbor skyline: cranes, silos and towers rising behind the boundary
        if TMap.kind == 4 {
            var sr = SystemRandomNumberGenerator()
            var seed: UInt64 = 91
            func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) & 0xFFFF) / 65535 }
            _ = sr.next()
            let W = TMap.W, H = TMap.H, off = TMap.off
            for i in 0..<110 {
                let side = i % 4
                let t = rnd()
                let w = 90 + rnd() * 240, d = 90 + rnd() * 240
                let hgt = 260 + rnd() * 760
                var x: CGFloat, y: CGFloat
                switch side {
                case 0: x = t * W; y = -60 - rnd() * 500
                case 1: x = t * W; y = H + 60 + rnd() * 500
                case 2: x = -60 - rnd() * 500; y = t * H
                default: x = W + 60 + rnd() * 500; y = t * H
                }
                let g = 0.22 + rnd() * 0.22
                let col = i % 5 == 0 ? UIColor(red: 0.55, green: 0.25, blue: 0.15, alpha: 1) : UIColor(red: g, green: g * 1.05, blue: g * 1.2, alpha: 1)
                let n = solid(CGRect(x: x + off, y: y, width: w, height: d), h: hgt, color: col, top: col)
                n.castsShadow = false
                floorRoot[1].addChildNode(n)
                if i % 3 == 0 {
                    let boom = solid(CGRect(x: x + off - w, y: y + d / 2 - 8, width: w * 3.2, height: 16), h: 18, y0: hgt, color: col, top: col)
                    boom.castsShadow = false
                    floorRoot[1].addChildNode(boom)
                }
            }
        }
        // props
        let prG = [MXNode(), MXNode(), MXNode()]
        let wc = TMap.walls.count
        for (i, pr) in TMap.props.enumerated() {
            let f = TMap.floorOfX(pr.r.midX)
            // the same Blender models the map editor shows; the code-built prop is only a fallback
            let nd = TileArt.prop(pr.k, pr.r) ?? props.build(pr.k, pr.r)
            if TMap.hp[wc + i] > 0 { floorRoot[f].addChildNode(nd); breakNodes[wc + i] = (nd, floorRoot[f]) }
            else { prG[f].addChildNode(nd) }
        }
        for f in 0..<3 { chunked(prG[f], into: floorRoot[f]) }
        for f in 0..<3 {
            let rr = TMap.rooms.filter { $0.fl == f && $0.mat < 6 }.map { $0.r }
            floorRoot[f].addChildNode(props.decals(in: rr, avoid: TMap.baseSolid, seed: f + 1).flattenedClone())
        }
        // health packs
        for k in e.packs {
            let g = MXNode()
            let ball = MXNode(geometry: MXSphere(radius: 10))
            ball.geometry?.firstMaterial = mat(nil, color: UIColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1), emission: UIColor(red: 0.1, green: 0.5, blue: 0.2, alpha: 1))
            let h = MXNode(geometry: MXBox(width: 14, height: 4, length: 4, chamferRadius: 0))
            h.geometry?.firstMaterial = mat(nil, color: .white, emission: .white)
            let v = MXNode(geometry: MXBox(width: 4, height: 4, length: 14, chamferRadius: 0))
            v.geometry?.firstMaterial = h.geometry?.firstMaterial
            h.position = MXVector3(0, 10, 0)
            v.position = MXVector3(0, 10, 0)
            ball.position = MXVector3(0, 10, 0)
            ball.scale = MXVector3(1, 0.3, 1)
            g.addChildNode(ball); g.addChildNode(h); g.addChildNode(v)
            g.position = MXVector3(Float(k.pos.x), 4, Float(k.pos.y))
            g.spinY = 3.14159
            fr(k.pos.x).addChildNode(g)
            packNodes.append(g)
        }
        // cabin roofs
        for rf in TMap.roofs {
            let top = UIColor(red: 0.3, green: 0.21, blue: 0.14, alpha: 1)
            let n = solid(rf.insetBy(dx: -8, dy: -8), h: 8, y0: TMap.wallH, color: UIColor(red: 0.38, green: 0.27, blue: 0.18, alpha: 1), top: top, chamfer: 1)
            fr(rf.midX).addChildNode(n)
        }
        // battle royale: loot pickups and the storm wall
        func lootColor(_ id: String) -> UIColor {
            if id == "g:awp" || id == "g:ak" || id == "g:m4" || id == "armor:3" { return C(1, 0.78, 0.2) }
            if id.hasPrefix("g:") || id.hasPrefix("armor") { return C(0.35, 0.65, 1) }
            if id.hasPrefix("val") || id.hasPrefix("part") || id == "intel" || id == "key" { return C(1, 0.82, 0.2) }
            if id.hasPrefix("vault") { return C(1, 0.45, 0.1) }
            if id == "plate" { return C(0.3, 0.55, 1) }
            if id == "band" || id == "kit" { return C(0.9, 0.95, 1) }
            if id == "med" { return C(0.3, 0.95, 0.45) }
            if id == "nade" { return C(1, 0.55, 0.2) }
            return C(0.92, 0.92, 0.92)
        }
        let lootHold = [MXNode(), MXNode(), MXNode()]
        for f in 0..<3 { floorRoot[f].addChildNode(lootHold[f]) }
        for l in (e.gameMode == 6 ? Array(e.loot.prefix(TMap.lootSpots.count)) : e.loot) {
            let g = MXNode()
            let col = lootColor(l.id)
            let isGun = l.id.hasPrefix("g:")
            let body = MXNode(geometry: MXBox(width: isGun ? 24 : 12, height: isGun ? 5 : 12, length: isGun ? 7 : 12, chamferRadius: 1.5))
            body.geometry?.firstMaterial = mat(nil, color: col, emission: col)
            body.position = MXVector3(0, 16, 0)
            body.castsShadow = false
            let pad = MXNode(geometry: MXCylinder(radius: 15, height: 0.8))
            let pm = mat(nil, color: col, emission: col)
            pm.lightingModel = .constant
            pad.geometry?.firstMaterial = pm
            pad.position = MXVector3(0, 1, 0)
            pad.castsShadow = false
            g.addChildNode(body); g.addChildNode(pad)
            g.position = MXVector3(Float(l.pos.x), 0, Float(l.pos.y))
            g.spinY = 2.2
            lootHold[TMap.floorOf(l.pos)].addChildNode(g)
            lootNodes.append(g)
        }
        if e.gameMode == 6 {
            for z in TacticalEngine.raidZones {
                let col = z.key ? C(1, 0.75, 0.2) : C(0.2, 1, 0.5)
                let bm = mat(nil, color: col, emission: col)
                bm.lightingModel = .constant
                bm.isDoubleSided = true
                bm.transparency = 0.22
                bm.writesToDepthBuffer = false
                let beam = MXNode(geometry: MXCylinder(radius: 52, height: 260))
                beam.geometry?.firstMaterial = bm
                beam.position = MXVector3(Float(z.pos.x), 130, Float(z.pos.y))
                beam.castsShadow = false
                beam.renderingOrder = 8
                let pm = mat(nil, color: col, emission: col)
                pm.lightingModel = .constant
                let pad = MXNode(geometry: MXCylinder(radius: 55, height: 0.8))
                pad.geometry?.firstMaterial = pm
                pad.position = MXVector3(Float(z.pos.x), 1, Float(z.pos.y))
                pad.castsShadow = false
                floorRoot[TMap.floorOf(z.pos)].addChildNode(beam)
                floorRoot[TMap.floorOf(z.pos)].addChildNode(pad)
            }
        }
        if e.gameMode == 6 {
            // dropped loot pool (bot drops, supply drops), one set of slots per floor
            let dcol = C(0.4, 1, 0.95)
            for f in 0..<3 {
                for _ in 0..<12 {
                    let g = MXNode()
                    let body = MXNode(geometry: MXBox(width: 14, height: 8, length: 12, chamferRadius: 1.5))
                    body.geometry?.firstMaterial = mat(nil, color: dcol, emission: dcol)
                    body.position = MXVector3(0, 14, 0)
                    body.castsShadow = false
                    let pad = MXNode(geometry: MXCylinder(radius: 14, height: 0.8))
                    let pm = mat(nil, color: dcol, emission: dcol)
                    pm.lightingModel = .constant
                    pad.geometry?.firstMaterial = pm
                    pad.position = MXVector3(0, 1, 0)
                    pad.castsShadow = false
                    g.addChildNode(body); g.addChildNode(pad)
                    g.spinY = 2.2
                    g.isHidden = true
                    lootHold[f].addChildNode(g)
                    dynNodes.append(g)
                }
            }
            let gcol = C(0.3, 1, 0.3)
            let gm = mat(nil, color: gcol, emission: gcol)
            gm.lightingModel = .constant
            gm.isDoubleSided = true
            gm.transparency = 0.28
            gm.writesToDepthBuffer = false
            let gas = MXNode(geometry: MXCylinder(radius: 230, height: 70))
            gas.geometry?.firstMaterial = gm
            gas.castsShadow = false
            gas.renderingOrder = 9
            gas.isHidden = true
            floorRoot[1].addChildNode(gas)
            evGas = gas
            let bcol = C(1, 0.8, 0.2)
            let bm2 = mat(nil, color: bcol, emission: bcol)
            bm2.lightingModel = .constant
            bm2.isDoubleSided = true
            bm2.transparency = 0.3
            bm2.writesToDepthBuffer = false
            let sb = MXNode(geometry: MXCylinder(radius: 9, height: 320))
            sb.geometry?.firstMaterial = bm2
            sb.castsShadow = false
            sb.renderingOrder = 9
            sb.isHidden = true
            floorRoot[1].addChildNode(sb)
            evBeam = sb
        }
        // bomb
        let bb = MXNode(geometry: MXBox(width: 18, height: 10, length: 14, chamferRadius: 2))
        bb.geometry?.firstMaterial = mat(nil, color: UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1), emission: UIColor(red: 0.6, green: 0, blue: 0, alpha: 1))
        bb.position = MXVector3(0, 5, 0)
        let bl = MXNode()
        bl.light = MXLight()
        bl.light?.type = .omni
        bl.light?.color = UIColor.red
        bl.light?.intensity = 500
        bl.light?.attenuationEndDistance = 200
        bl.position = MXVector3(0, 30, 0)
        bombNode.addChildNode(bb)
        bombNode.addChildNode(bl)
        bombNode.isHidden = true
        root.addChildNode(bombNode)
        // players
                TAtt.resetCamo()
                for p in e.players {
            let rt = MXNode()
            let col: UIColor = p.isPlayer ? UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1) : (p.team == e.me.team ? UIColor(red: 0.25, green: 0.6, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.25, blue: 0.3, alpha: 1))
            let teamC: UIColor = p.team == e.me.team ? UIColor(red: 0.25, green: 0.6, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1)
            let sol = TwRig.soldier(team: p.isPlayer ? col : teamC, style: TacAvatar.style(p.isPlayer ? TacAvatar.myKey : p.handle), rank: p.rank)
            kevs.append(sol.kev); helms.append(sol.helm); heavies.append(sol.heavy); hats.append(sol.hat)
            let body = sol.root
            let gun = sol.holder
            let fl = sol.flash
            shirts.append(sol.shirt)
            legLs.append(sol.legL)
            legRs.append(sol.legR)
            gunVars.append(sol.variants)
            gunShown.append(0)
            walkPh.append(0)
            lastPos.append(.zero)
            let head = sol.face
            faceMats.append(sol.faceMat)
            let blob = MXNode(geometry: MXCylinder(radius: 13, height: 0.2))
            let bm = MXMaterial()
            bm.lightingModel = .constant
            bm.diffuse.contents = UIColor.black
            bm.transparency = 0.42
            bm.writesToDepthBuffer = false
            blob.geometry?.firstMaterial = bm
            blob.position = MXVector3(0, 0.3, 0)
            blob.castsShadow = false
            rt.addChildNode(blob)
            rt.addChildNode(body)
            root.addChildNode(rt)
            roots.append(rt); bodies.append(body); heads.append(head); guns.append(gun); flashes.append(fl)
            headKey.append("")
        }
        // pools
        for _ in 0..<60 {
            let b = MXNode(geometry: MXBox(width: 26, height: 2.4, length: 2.4, chamferRadius: 0))
            b.geometry?.firstMaterial = mat(nil, color: .white, emission: .white)
            b.castsShadow = false
            b.isHidden = true
            root.addChildNode(b)
            bulletPool.append(b)
        }
        for _ in 0..<6 {
            let g = MXNode(geometry: MXSphere(radius: 5))
            g.geometry?.firstMaterial = mat(nil, color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1))
            g.isHidden = true
            root.addChildNode(g)
            nadePool.append(g)
        }
        for _ in 0..<6 {
            let g = MXNode(geometry: MXSphere(radius: 1))
            let m = mat(nil, color: .orange, emission: UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1))
            m.lightingModel = .constant
            g.geometry?.firstMaterial = m
            g.castsShadow = false
            g.isHidden = true
            root.addChildNode(g)
            boomPool.append(g)
        }
        var r = LCG(s: 99)
        for _ in 0..<4 {
            let g = MXNode()
            for i in 0..<9 {
                let s = MXNode(geometry: MXSphere(radius: i == 0 ? 60 : 44))
                let m = mat(nil, color: UIColor(white: 0.8, alpha: 1))
                m.lightingModel = .lambert
                s.geometry?.firstMaterial = m
                let a = CGFloat(i) * 0.7
                let d: CGFloat = i == 0 ? 0 : 42
                s.position = MXVector3(Float(cos(a) * d), Float(40 + r.next() * 40), Float(sin(a) * d))
                s.castsShadow = false
                g.addChildNode(s)
            }
            g.isHidden = true
            root.addChildNode(g)
            smokePool.append(g)
        }

        view.scene = scene
        view.pointOfView = camNode
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.backgroundColor = .black
        view.isUserInteractionEnabled = false
        view.allowsCameraControl = false
    }

    // MARK: props

    private func buildProp(_ pr: TProp) -> MXNode {
        let r = pr.r
        let g = MXNode()
        let colors: (CGFloat, CGFloat, CGFloat)
        switch pr.k {
        case .bed: colors = (0.32, 0.4, 0.62)
        case .couch: colors = (0.55, 0.26, 0.3)
        case .table: colors = (0.62, 0.44, 0.26)
        case .counter: colors = (0.78, 0.8, 0.82)
        case .crate: colors = (0.52, 0.38, 0.22)
        case .car: colors = (0.2, 0.38, 0.62)
        case .shelf: colors = (0.3, 0.22, 0.15)
        case .barrel: colors = (0.5, 0.2, 0.14)
        case .sandbag: colors = (0.76, 0.68, 0.44)
        case .tv: colors = (0.1, 0.12, 0.16)
        case .plant: colors = (0.16, 0.45, 0.22)
        case .tree: colors = (0.2, 0.4, 0.16)
        case .rock: colors = (0.45, 0.46, 0.48)
        }
        let c = ui(colors)
        let cl = ui(colors, 1.2)
        switch pr.k {
        case .bed:
            g.addChildNode(solid(r, h: 14, color: ui((0.35, 0.25, 0.15)), top: ui((0.35, 0.25, 0.15))))
            g.addChildNode(solid(r.insetBy(dx: 2, dy: 2), h: 8, y0: 14, color: c, top: cl, chamfer: 3))
            g.addChildNode(solid(CGRect(x: r.minX + 8, y: r.minY + 8, width: r.width - 16, height: 26), h: 7, y0: 22, color: .white, top: .white, chamfer: 3))
        case .couch:
            g.addChildNode(solid(r, h: 18, color: c, top: cl, chamfer: 4))
            if r.width >= r.height {
                g.addChildNode(solid(CGRect(x: r.minX, y: r.minY, width: r.width, height: min(16, r.height * 0.35)), h: 34, color: ui(colors, 0.8), top: c, chamfer: 4))
            } else {
                g.addChildNode(solid(CGRect(x: r.minX, y: r.minY, width: min(16, r.width * 0.35), height: r.height), h: 34, color: ui(colors, 0.8), top: c, chamfer: 4))
            }
        case .table:
            g.addChildNode(solid(r, h: 5, y0: 24, color: c, top: cl, chamfer: 1.5))
            for (lx, ly) in [(r.minX + 4, r.minY + 4), (r.maxX - 9, r.minY + 4), (r.minX + 4, r.maxY - 9), (r.maxX - 9, r.maxY - 9)] {
                g.addChildNode(solid(CGRect(x: lx, y: ly, width: 5, height: 5), h: 24, color: ui(colors, 0.7)))
            }
        case .counter:
            g.addChildNode(solid(r, h: 36, color: ui((0.35, 0.28, 0.2)), top: ui((0.35, 0.28, 0.2))))
            g.addChildNode(solid(r.insetBy(dx: -1.5, dy: -1.5), h: 4, y0: 36, color: c, top: cl, chamfer: 1))
        case .crate:
            g.addChildNode(solid(r, h: 38, color: c, top: cl, chamfer: 2))
            g.addChildNode(solid(CGRect(x: r.minX - 1, y: r.minY - 1, width: r.width + 2, height: 5), h: 38, color: ui(colors, 0.6), top: ui(colors, 0.6)))
            g.addChildNode(solid(CGRect(x: r.minX - 1, y: r.maxY - 4, width: r.width + 2, height: 5), h: 38, color: ui(colors, 0.6), top: ui(colors, 0.6)))
        case .car:
            g.addChildNode(solid(r, h: 22, y0: 6, color: c, top: cl, chamfer: 8))
            g.addChildNode(solid(CGRect(x: r.minX + r.width * 0.3, y: r.minY + 8, width: r.width * 0.4, height: r.height - 16), h: 16, y0: 28, color: ui((0.1, 0.14, 0.2)), top: ui((0.1, 0.14, 0.2)), chamfer: 5))
            for ly in [r.minY + 10, r.maxY - 18] {
                g.addChildNode(solid(CGRect(x: r.maxX - 3, y: ly, width: 4, height: 8), h: 5, y0: 14, color: .yellow, top: .yellow, emission: UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)))
            }
        case .shelf:
            g.addChildNode(solid(r, h: 66, color: c, top: cl, chamfer: 1))
            var rr = LCG(s: UInt64(r.minX * 7 + r.minY))
            var yy: CGFloat = 12
            while yy < 62 {
                let horiz = r.width >= r.height
                let strip = horiz ? CGRect(x: r.minX + 2, y: r.maxY - 1, width: r.width - 4, height: 3) : CGRect(x: r.maxX - 1, y: r.minY + 2, width: 3, height: r.height - 4)
                let bk = UIColor(hue: rr.next(), saturation: 0.45, brightness: 0.6, alpha: 1)
                g.addChildNode(solid(strip, h: 7, y0: yy, color: bk, top: bk))
                yy += 14
            }
        case .barrel:
            let n = MXNode(geometry: MXCylinder(radius: r.width / 2, height: 34))
            n.geometry?.firstMaterial = mat(nil, color: c)
            n.position = MXVector3(Float(r.midX), 17, Float(r.midY))
            g.addChildNode(n)
        case .sandbag:
            g.addChildNode(solid(r, h: 18, color: c, top: cl, chamfer: 6))
        case .tv:
            g.addChildNode(solid(r, h: 40, color: c, top: c, chamfer: 2))
            g.addChildNode(solid(CGRect(x: r.minX + 6, y: r.maxY - 2, width: r.width - 12, height: 3), h: 26, y0: 8, color: UIColor(red: 0.2, green: 0.45, blue: 0.7, alpha: 1), top: UIColor(red: 0.2, green: 0.45, blue: 0.7, alpha: 1), emission: UIColor(red: 0.15, green: 0.35, blue: 0.6, alpha: 1)))
        case .plant:
            let pot = MXNode(geometry: MXCylinder(radius: r.width * 0.28, height: 14))
            pot.geometry?.firstMaterial = mat(nil, color: ui((0.4, 0.28, 0.18)))
            pot.position = MXVector3(Float(r.midX), 7, Float(r.midY))
            let leaf = MXNode(geometry: MXSphere(radius: r.width * 0.45))
            leaf.geometry?.firstMaterial = mat(nil, color: c)
            leaf.position = MXVector3(Float(r.midX), 30, Float(r.midY))
            g.addChildNode(pot); g.addChildNode(leaf)
        case .tree:
            let tr = MXNode(geometry: MXCylinder(radius: r.width * 0.46, height: 70))
            tr.geometry?.firstMaterial = mat(nil, color: ui((0.3, 0.2, 0.12)))
            tr.position = MXVector3(Float(r.midX), 35, Float(r.midY))
            let top = MXNode(geometry: MXSphere(radius: r.width * 0.75))
            top.geometry?.firstMaterial = mat(nil, color: c)
            top.position = MXVector3(Float(r.midX), 100, Float(r.midY))
            g.addChildNode(tr); g.addChildNode(top)
        case .rock:
            g.addChildNode(solid(r, h: TMap.propH(.rock), color: c, top: cl, chamfer: 8))
        }
        return g
    }

    // MARK: per-frame

    func project(_ p: CGPoint, _ h: CGFloat) -> CGPoint? {
        if TMap.floorOf(p) != focusFloor { return nil }
        if fpMode {
            let dx = sx(p) - fpEye.x, dz = p.y - fpEye.y
            if dx * fpFwd.x + dz * fpFwd.y <= 2 { return nil }
        }
        let v = view.projectPoint(MXVector3(Float(sx(p)), Float(h), Float(p.y)))
        if v.z > 1 || v.z < 0 { return nil }
        return CGPoint(x: CGFloat(v.x), y: CGFloat(v.y))
    }

    func sx(_ p: CGPoint) -> CGFloat { p.x - TMap.origin(TMap.floorOf(p)) }

    // MARK: destruction

    var lastDestroyT = CACurrentMediaTime()

    private func debrisColor(_ k: Int) -> Int {
        if k < TMap.walls.count { return TMap.floorOfX(TMap.walls[k].midX) == 0 ? 2 : 0 }
        switch TMap.props[k - TMap.walls.count].k {
        case .barrel, .counter, .tv: return 2
        case .plant: return 3
        default: return 1
        }
    }

    private func applyDestruction(_ dt: Float) {
        if TMap.resetTick != lastResetTick {
            lastResetTick = TMap.resetTick
            for k in brokenSet { if let v = breakNodes[k] { v.1.addChildNode(v.0) } }
            brokenSet = []
            for (_, v) in stairNodes { for n in v { n.isHidden = false } }
            for (_, v) in rubbleNodes { v.isHidden = true }
        }
        if !TMap.stairBroken.isEmpty {
            let sl = TMap.stairBroken
            TMap.stairBroken = []
            for i in sl {
                for n in stairNodes[i] ?? [] { n.isHidden = true }
                rubbleNodes[i]?.isHidden = false
            }
        }
        if !TMap.broken.isEmpty {
            let list = TMap.broken
            TMap.broken = []
            for k in list {
                guard let v = breakNodes[k], !brokenSet.contains(k) else { continue }
                brokenSet.insert(k)
                v.0.removeFromParentNode()
                let r = TMap.origBase[k]
                let fl = TMap.floorOfX(r.midX)
                let n = k < TMap.walls.count ? min(9, max(4, Int(max(r.width, r.height) / 14))) : 7
                let ci = debrisColor(k)
                var made = 0
                for i in debris.indices where debrisLife[i] <= 0 {
                    let d = debris[i]
                    d.geometry?.firstMaterial = debrisMats[(ci + (made % 3 == 0 ? 0 : 0)) % 4]
                    let px = Float(r.minX + r.width * CGFloat.random(in: 0.1...0.9)) - Float(TMap.origin(fl))
                    let pz = Float(r.minY + r.height * CGFloat.random(in: 0.1...0.9))
                    let py = Float.random(in: 8...(Float(TMap.wallH) * (k < TMap.walls.count ? 0.9 : 0.5)))
                    d.position = MXVector3(px, py, pz)
                    let sc = Float.random(in: 0.5...1.7)
                    d.scale = MXVector3(sc, sc, sc)
                    debrisV[i] = SIMD3<Float>(Float.random(in: -140...140), Float.random(in: 60...220), Float.random(in: -140...140))
                    debrisLife[i] = Float.random(in: 1.0...1.8)
                    debrisFloor[i] = fl
                    d.isHidden = fl != focusFloor
                    made += 1
                    if made >= n { break }
                }
            }
        }
        for i in debris.indices where debrisLife[i] > 0 {
            debrisLife[i] -= dt
            let d = debris[i]
            if debrisLife[i] <= 0 { d.isHidden = true; continue }
            var v = debrisV[i]
            v.y -= 760 * dt
            var p = SIMD3<Float>(d.position.x, d.position.y, d.position.z) + v * dt
            if p.y < 2.5 { p.y = 2.5; v.y = abs(v.y) * 0.25; v.x *= 0.6; v.z *= 0.6 }
            debrisV[i] = v
            d.position = MXVector3(p.x, p.y, p.z)
            d.isHidden = debrisFloor[i] != focusFloor
        }
    }

    private func updateStormRing(_ e: TacticalEngine, force: Bool) {
        if !force && abs(e.stormRad - lastStormRad) < 1.5 && abs(e.stormC.x - lastStormC.x) < 1.5 && abs(e.stormC.y - lastStormC.y) < 1.5 { return }
        lastStormRad = e.stormRad
        lastStormC = e.stormC
        let R = e.stormRad
        let w = Float(2 * CGFloat.pi * R / 64) * 1.2 + 6
        for f in 0..<3 {
            for (i, n) in stormSegs[f].enumerated() {
                let a = Double(i) / 64 * 2 * Double.pi
                n.position = MXVector3(Float(e.stormC.x + TMap.origin(f) + CGFloat(cos(a)) * R), 200, Float(e.stormC.y + CGFloat(sin(a)) * R))
                n.scale = MXVector3(w, 1, w)
            }
        }
    }

    // MARK: streaming (distance + view culling)

    struct CullItem { let node: MXNode; let c: CGPoint; let r: CGFloat }
    var cull: [CullItem] = []
    var cullBuilt = false
    var lastCull: CGFloat = -1
    var lastVmT: CGFloat = 0

    private func chunked(_ src: MXNode, into dst: MXNode, cell: Float = 700) {
        var cells: [Int: MXNode] = [:]
        for ch in src.childNodes {
            let (mn, mx) = ch.boundingBox
            let c = ch.convertPosition(MXVector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2), to: src)
            let key = Int(floor(c.x / cell)) * 1000 + Int(floor(c.z / cell))
            let n = cells[key] ?? MXNode()
            cells[key] = n
            ch.removeFromParentNode()
            n.addChildNode(ch)
        }
        for (_, n) in cells { dst.addChildNode(n.flattenedClone()) }
    }

    private func registerCull() {
        cull = []
        for n in floorRoot.flatMap({ $0.childNodes }) {
            if ceilNodes.contains(where: { $0 === n }) { continue }
            let (mn, mx) = n.boundingBox
            if mx.x - mn.x <= 0 && mx.z - mn.z <= 0 { continue }
            let c = n.convertPosition(MXVector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2), to: nil)
            let r = CGFloat(hypot(mx.x - mn.x, mx.z - mn.z) / 2)
            if r > 1400 { continue }
            cull.append(CullItem(node: n, c: CGPoint(x: CGFloat(c.x), y: CGFloat(c.z)), r: r))
        }
    }

    private func updateCull(_ ex: CGFloat, _ ez: CGFloat, _ fx: CGFloat, _ fz: CGFloat) {
        let range: CGFloat = 1800
        for it in cull {
            let vx = it.c.x - ex, vz = it.c.y - ez
            let d = max(1, hypot(vx, vz))
            var vis = d - it.r < range
            if vis && d > 500 + it.r {
                let dot = (vx * fx + vz * fz) / d
                if dot < -(it.r / d) * 1.2 { vis = false }
            }
            if it.node.isHidden == vis { it.node.isHidden = !vis }
        }
    }

    func sync(_ e: TacticalEngine) {
        guard !e.players.isEmpty, roots.count == e.players.count else { return }
        // tired tungsten tubes: a few buzz, a few cut out for a moment
        let ft = Double(e.time)
        for (i, l) in lamps.enumerated() {
            var k = 0.97 + 0.03 * sin(ft * 7 + Double(i))
            if i % 4 == 0 {
                k = 0.84 + 0.16 * sin(ft * 29 + Double(i) * 1.3)
                if sin(ft * 0.8 + Double(i) * 1.7) > 0.965 { k *= 0.2 }
            }
            l.0.intensity = l.1 * CGFloat(k)
        }
        let rsv = e.beginReplayView()
        defer { e.endReplayView(rsv) }
        let focus: TPlayer = e.replayOn ? (e.players.first { $0.id == e.replayKiller } ?? e.me) : e.me.alive ? e.me : (e.gameMode != 6 ? e.players.first { $0.id == e.lastKiller && $0.alive && !$0.isPlayer } : nil) ?? (e.players.first { $0.team == e.me.team && $0.alive } ?? e.me)
        // floors are stacked vertically, so taking stairs glides the world up/down instead of cutting to another floor
        let nf = TMap.floorOf(focus.pos)
        let focusLift: CGFloat? = TMap.smooth ? TMap.stairLift(focus.pos) : nil
        liftF = Float(focusLift ?? 0)
        let stairNow = focusLift != nil
        if stackPrev >= 0 && nf != stackPrev && !e.replayOn && !(TMap.smooth && (stairNow || stairWas)) { stackAnim = Float(nf - stackPrev) * stackH }
        stairWas = stairNow
        if e.replayOn { stackAnim = 0 }
        stackPrev = nf
        let nowT = CACurrentMediaTime()
        let sdt = Float(max(0.001, min(0.1, nowT - stackT)))
        stackT = nowT
        stackAnim -= stackAnim * min(1, sdt * 7)
        if abs(stackAnim) < 0.5 { stackAnim = 0 }
        focusFloor = nf
        var linked = Set<Int>()
        if fpMode && !e.replayOn {
            let fpl = TMap.planOf(focus.pos)
            for i in TMap.stairs.indices where TMap.stairIntact(i) || true {
                let lo = TMap.stairLo[i]
                guard nf == lo || nf == lo + 1 else { continue }
                if TMap.rectDist(TMap.stairs[i], fpl) < 560 { linked.insert(nf == lo ? lo + 1 : lo) }
            }
        }
        for i in 0..<3 {
            let dy = Float(i - nf) * stackH + stackAnim - liftF
            floorRoot[i].position = MXVector3(-Float(TMap.origin(i)), dy, 0)
            floorRoot[i].isHidden = i != nf && !linked.contains(i) && (stackAnim == 0 || abs(i - nf) != 1)
        }
        linkedFloors = linked
        applyDestruction(Float(max(0.001, min(0.05, CACurrentMediaTime() - lastDestroyT))))
        lastDestroyT = CACurrentMediaTime()
        for (i, l) in e.loot.enumerated() where i < lootNodes.count { lootNodes[i].isHidden = l.taken }
        if e.gameMode == 6 {
            for (j, n) in dynNodes.enumerated() {
                let idx = e.dynBase + j
                if idx < e.loot.count && !e.loot[idx].taken && !e.loot[idx].id.isEmpty {
                    n.isHidden = false
                    n.position = MXVector3(Float(e.loot[idx].pos.x), 0, Float(e.loot[idx].pos.y))
                } else {
                    n.isHidden = true
                }
            }
            if let g = evGas {
                g.isHidden = e.evKind != 4
                g.position = MXVector3(Float(e.evPos.x), 35, Float(e.evPos.y))
            }
            if let b = evBeam {
                b.isHidden = e.evKind != 1
                b.position = MXVector3(Float(e.evPos.x), 160, Float(e.evPos.y))
            }
        }
        for i in doorLeaves.indices where i < TMap.doorOpen.count {
            let ang = Float(TMap.doorOpen[i]) * 1.65
            if abs(doorAngShown[i] - ang) > 0.004 {
                doorAngShown[i] = ang
                for (k, lf) in doorLeaves[i].enumerated() {
                    let sg: Float = k == 0 ? 1 : -1
                    lf.eulerAngles = MXVector3(0, (doorHoriz[i] ? -ang : ang) * sg, 0)
                }
            }
        }
        let tnow = CACurrentMediaTime()
        let fdt = CGFloat(min(0.1, max(0.001, tnow - lastT)))
        lastT = tnow
        fpsEMA = fpsEMA * 0.95 + (1 / fdt) * 0.05
        if fpsEMA < 42 { lowT += fdt } else { lowT = max(0, lowT - fdt) }
        if lowT > 2.5 && qual > 0 {
            qual -= 1
            lowT = 0
            fpsEMA = 60
            if qual <= 1 { camNode.camera?.screenSpaceAmbientOcclusionIntensity = 0 }
            if qual <= 0 {
                camNode.camera?.wantsHDR = false
                camNode.camera?.bloomIntensity = 0
                sunNode?.light?.shadowSampleCount = 2
            }
        }
        let fx = sx(focus.pos)
        if !started || camFloor != focusFloor { camX = fx; camZ = focus.pos.y; started = true; camFloor = focusFloor }
        if e.replayOn { camX = fx; camZ = focus.pos.y } else { camX += (fx - camX) * 0.2; camZ += (focus.pos.y - camZ) * 0.2 }
        let sh = e.shake
        let jx: CGFloat = sh > 0 ? CGFloat.random(in: -sh...sh) * 0.6 : 0
        let jz: CGFloat = sh > 0 ? CGFloat.random(in: -sh...sh) * 0.6 : 0
        for c in ceilNodes { c.isHidden = true }
        if fpMode {
            if focusFloor < ceilNodes.count && (TMap.look == 0 || focusFloor == 0) { ceilNodes[focusFloor].isHidden = false }
            let ex = fx, ez = focus.pos.y
            let dxv = cos(focus.aim), dzv = sin(focus.aim)
            let eh = CGFloat(TMap.eyeH) + CGFloat(sin(Double(min(1, e.jumpT / 0.55)) * Double.pi)) * 22 + (sh > 0 ? CGFloat.random(in: -sh...sh) * 0.25 : 0)
            fpFwd = CGPoint(x: dxv, y: dzv)
            fpEye = CGPoint(x: ex, y: ez)
            if !cullBuilt { cullBuilt = true; registerCull() }
            if abs(e.time - lastCull) > 0.1 { lastCull = e.time; updateCull(ex, ez, dxv, dzv) }
            camNode.camera?.zNear = 0.6
            camNode.camera?.zFar = 2200
            vm.show(focus.knife ? "knife" : TWeapons.model(focus.gun))
            vm.root.isHidden = !(focus.alive && !e.scoped)
            let gw = TWeapons.w(focus.gun)
            let rprog: Float? = focus.reloadT > 0 ? Float(max(0, min(1, 1 - focus.reloadT / max(0.1, gw.reload)))) : nil
            let vdt = Float(max(0.001, min(0.05, e.time - lastVmT)))
            lastVmT = e.time
            vm.update(dt: vdt, t: Float(e.time), move: e.replayOn ? 0.6 : Float(min(1, hypot(e.move.dx, e.move.dy))), kick: e.replayOn ? (focus.flash > 0 ? 6 : 0) : Float(e.kick), reload: rprog, flashing: focus.flash > 0, recoilScale: TWeapons.recoil(focus.gun), ads: (e.ads && !e.replayOn) ? 1 : 0)
            vm.flash(focus.flash > 0)
            // the muzzle lights the room for the length of the flash
            if muzzleLight == nil {
                let ln = MXNode()
                let li = MXLight()
                li.type = .omni
                li.color = UIColor(red: 1, green: 0.78, blue: 0.45, alpha: 1)
                li.intensity = 900
                li.attenuationStartDistance = 10
                li.attenuationEndDistance = 320
                ln.light = li
                ln.position = MXVector3(4, -2, -26)
                ln.isHidden = true
                camNode.addChildNode(ln)
                muzzleLight = ln
            }
            if let ln = muzzleLight {
                let on = focus.flash > 0 && focus.alive
                if on { ln.light?.intensity = CGFloat.random(in: 650...1250) }
                ln.isHidden = !on
            }
            camNode.camera?.fieldOfView += ((e.scoped ? TAtt.mods(e.me.gun).zoomFOV : (e.ads ? TBody.fov * 0.78 : TBody.fov)) - (camNode.camera?.fieldOfView ?? TBody.fov)) * 0.3
            // bodycam: strapped to the chest, so it breathes, rolls with every step and lags the aim
            let bt = Double(e.time)
            let mv = CGFloat(min(1, hypot(e.move.dx, e.move.dy)))
            let calm: CGFloat = e.scoped ? 0.25 : (e.ads ? 0.5 : 1)
            let swayX = CGFloat(sin(bt * 1.35) * 0.45 + sin(bt * 0.57) * 0.6 + sin(bt * 4.1) * 0.12) * (1 + 2.2 * mv) * calm
            let swayY = CGFloat(sin(bt * 2.05) * 0.3 + abs(sin(bt * 6.2)) * 0.9 * Double(mv)) * calm
            camNode.camera?.bodycam = e.scoped ? 0.55 : 1
            camNode.camera?.camTime = Float(bt)
            camNode.camera?.saturation = 0.9
            camNode.camera?.contrast = 0.12
            camNode.camera?.vignettingIntensity = 0.55
            camNode.camera?.vignettingPower = 2.0
            camNode.position = MXVector3(Float(ex + jx * 0.3), Float(eh + swayY * 0.9), Float(ez + jz * 0.3))
            camNode.look(at: MXVector3(Float(ex + dxv * 100 - dzv * swayX), Float(eh + swayY * 1.4 + tan(e.pitch) * 100), Float(ez + dzv * 100 + dxv * swayX)))
        } else {
            vm.root.isHidden = true
            camNode.camera?.zNear = 10
            camNode.camera?.zFar = 3000
            camNode.camera?.fieldOfView = 52
            camNode.camera?.bodycam = 0
            let pr: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(300, 170, 60, 30), (400, 250, 70, 40), (520, 70, 70, 50), (640, 400, 90, 60)]
            let c = pr[max(0, min(3, preset))]
            // always the same top-down pitch; yaw just spins the view around the player
            let lx = camX + cos(focus.aim) * c.2, lz = camZ + sin(focus.aim) * c.3
            camNode.position = MXVector3(Float(lx + jx + c.1 * sin(yaw)), Float(c.0), Float(lz + jz + c.1 * cos(yaw)))
            camNode.look(at: MXVector3(Float(lx), 0, Float(lz)))
        }

        for (i, p) in e.players.enumerated() {
            let rt = roots[i]
            let show = (e.replayOn || p.team == e.me.team || p.spotted || (!p.alive && p.seenEver)) && (TMap.floorOf(p.pos) == focusFloor || (fpMode && linkedFloors.contains(TMap.floorOf(p.pos)) && TMap.crossLink(focus.pos, p.pos)))
            rt.isHidden = !show || (fpMode && p.id == focus.id)
            if !show { continue }
            let ks: Float = fpMode ? 1.18 : 1
            rt.scale = MXVector3(ks, ks * (p.crouch ? 0.74 : 1), ks)
            rt.position = MXVector3(Float(sx(p.pos)), Float(TMap.floorOf(p.pos) - focusFloor) * stackH + stackAnim - liftF + Float(TMap.smooth ? (TMap.stairLift(p.pos) ?? 0) : 0), Float(p.pos.y))
            rt.eulerAngles = MXVector3(0, Float(-p.aim), 0)
            heads[i].eulerAngles = MXVector3(0, Float(p.aim), 0)
            if p.alive {
                deadK[i] = 0
                heads[i].isHidden = true
                guns[i].isHidden = false
                flashes[i].isHidden = !(p.flash > 0)
                shirts[i].emission.contents = p.hurt > 0 ? UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1) : UIColor.black
                let dpx = p.pos.x - lastPos[i].x, dpy = p.pos.y - lastPos[i].y
                let moved = hypot(dpx, dpy)
                if moved < 40 { walkPh[i] += moved * 0.12 }
                lastPos[i] = p.pos
                mvK[i] += ((moved > 0.12 ? 1 : 0) - mvK[i]) * 0.18
                let sw = Float(sin(walkPh[i])) * (0.2 + 0.65 * mvK[i])
                legLs[i].eulerAngles = MXVector3(0, 0, sw)
                legRs[i].eulerAngles = MXVector3(0, 0, -sw)
                let bob = abs(Float(cos(walkPh[i]))) * 0.9 * mvK[i] + sin(Float(e.time) * 1.6 + Float(i)) * 0.12
                let lean: Float = -0.1 * mvK[i] + (p.flash > 0 ? 0.045 : 0)
                bodies[i].eulerAngles = MXVector3(0, 0, lean)
                bodies[i].position = MXVector3(0, bob, 0)
                var ek = 0
                if p.rank == 0 && p.armor > 0 {
                    ek = p.armorKind > 0 ? p.armorKind : (e.gameMode != 0 ? [1, 2, 3, 1, 2][p.id % 5] : 0)
                }
                kevs[i].isHidden = ek < 1
                helms[i].isHidden = ek < 2
                heavies[i].isHidden = ek < 3
                hats[i].isHidden = ek >= 2
                let gi = TwRig.gunIdx(p.gun)
                if gunShown[i] != gi {
                    for (k, g) in gunVars[i].enumerated() { g.isHidden = k != gi }
                    flashes[i].position = MXVector3(TwGunLib.muzzleX(p.gun) + 1, 1, 0)
                    gunShown[i] = gi
                }
            } else {
                deadK[i] = min(1, deadK[i] + 1 / 22)
                let dk = 1 - pow(1 - deadK[i], 3)
                bodies[i].eulerAngles = MXVector3(0, 0, dk * Float.pi / 2)
                bodies[i].position = MXVector3(-dk * 3, dk * 8, 0)
                heads[i].isHidden = true
                flashes[i].isHidden = true
                shirts[i].emission.contents = UIColor.black
            }
        }
        // bullets
        for (i, node) in bulletPool.enumerated() {
            if !e.replayOn, i < e.bullets.count, TMap.floorOf(e.bullets[i].pos) == focusFloor {
                let b = e.bullets[i]
                node.isHidden = false
                node.position = MXVector3(Float(sx(b.pos)), Float(b.h) - 18 - liftF, Float(b.pos.y))
                node.eulerAngles = MXVector3(Float(atan2(b.vh, 1100)), Float(-atan2(b.vel.dy, b.vel.dx)), 0)
                let c: UIColor = b.team == e.me.team ? UIColor(red: 0.7, green: 0.9, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.55, blue: 0.35, alpha: 1)
                node.geometry?.firstMaterial?.emission.contents = c
                node.geometry?.firstMaterial?.diffuse.contents = c
            } else { node.isHidden = true }
        }
        for (i, node) in nadePool.enumerated() {
            if !e.replayOn, i < e.nades.count, TMap.floorOf(e.nades[i].pos) == focusFloor {
                let g = e.nades[i]
                node.isHidden = false
                node.position = MXVector3(Float(sx(g.pos)), 8 - liftF, Float(g.pos.y))
                node.geometry?.firstMaterial?.diffuse.contents = g.kind == 1 ? UIColor(white: 0.75, alpha: 1) : UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)
            } else { node.isHidden = true }
        }
        if impactFX == nil { impactFX = TacImpactFX(roots: floorRoot) }
        if !e.impacts.isEmpty {
            if !e.replayOn { for im in e.impacts where TMap.floorOf(im.pos) < floorRoot.count { impactFX?.spawn(im) } }
            e.impacts.removeAll()
        }
        impactFX?.update(sdt, camPlan: focus.pos)
        // slow eye adaptation: brighter inside, a touch darker in the open yard, dipping under a muzzle flash
        var tgt: Float = 1
        if TMap.kind == 7 {
            let o = TMap.origin(TMap.floorOf(focus.pos))
            let pl = CGPoint(x: focus.pos.x - o, y: focus.pos.y)
            let inside = TMap.floorOf(focus.pos) == 2 || CGRect(x: 125, y: 100, width: 750, height: 600).contains(pl)
            tgt = inside ? 1.12 : 0.92
        }
        if focus.flash > 0 { tgt *= 0.93 }
        expoCur += (tgt - expoCur) * min(1, sdt * 1.6)
        camNode.camera?.exposure = CGFloat(expoCur)
        for (i, node) in boomPool.enumerated() {
            if i < e.booms.count, TMap.floorOf(e.booms[i].pos) == focusFloor {
                let b = e.booms[i]
                let total: CGFloat = b.r > 150 ? 0.8 : 0.45
                let k = min(1, max(0, 1 - b.life / total))
                let rr = b.r * (0.35 + k * 0.7)
                node.isHidden = false
                node.position = MXVector3(Float(sx(b.pos)), 20, Float(b.pos.y))
                node.scale = MXVector3(Float(rr), Float(rr * 0.6), Float(rr))
                node.opacity = CGFloat(0.65 * (1 - k))
            } else { node.isHidden = true }
        }
        for (i, node) in smokePool.enumerated() {
            if i < e.smokeClouds.count, TMap.floorOf(e.smokeClouds[i].pos) == focusFloor {
                let s = e.smokeClouds[i]
                node.isHidden = false
                node.position = MXVector3(Float(sx(s.pos)), 0, Float(s.pos.y))
                let sc = Float(s.r / 85)
                node.scale = MXVector3(sc, sc, sc)
                node.opacity = min(1, s.life / 1.5) * 0.93
                node.eulerAngles = MXVector3(0, Float(e.time * 0.2), 0)
            } else { node.isHidden = true }
        }
        for (i, node) in packNodes.enumerated() where i < e.packs.count {
            node.isHidden = e.packs[i].taken
        }
        let bombHere = e.planted && TMap.floorOf(e.bombPos) == focusFloor
        bombNode.isHidden = !bombHere
        if bombHere {
            bombNode.position = MXVector3(Float(sx(e.bombPos)), 0, Float(e.bombPos.y))
        }
    }
}

// MARK: - Overlay drawn above the 3D view

extension TacticalEngine {
    func drawOverlay3D(_ ctx: inout GraphicsContext, _ size: CGSize) {
        guard let pr = project, !replayOn else { return }
        let focus: TPlayer = me.alive ? me : (players.first { $0.team == me.team && $0.alive } ?? me)
        // fog of war (top-down view only)
        let vp = focus.pos
        var poly = Path()
        var ok = true
        let n = 120
        for i in 0...(fp ? 0 : n) {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi
            let d = TMap.rayDist(vp, a, 700)
            let hit = d < 699
            guard let pt = pr(CGPoint(x: vp.x + cos(a) * d, y: vp.y + sin(a) * d), hit ? TMap.wallH - 8 : 0) else { ok = false; break }
            if i == 0 { poly.move(to: pt) } else { poly.addLine(to: pt) }
        }
        if ok && !fp {
            poly.closeSubpath()
            var dark = Path(CGRect(x: -60, y: -60, width: size.width + 120, height: size.height + 120))
            dark.addPath(poly)
            ctx.fill(dark, with: .color(.black.opacity(0.6)), style: FillStyle(eoFill: true))
        }
        // stair labels
        let ff = TMap.floorOf(focus.pos)
        for i in TMap.stairs.indices where !fp {
            let r = TMap.stairRect(i, floor: ff)
            guard ff == TMap.stairLo[i] || ff == TMap.stairLo[i] + 1 else { continue }
            if let pt = pr(CGPoint(x: r.midX, y: r.midY), 56) {
                ctx.draw(Text(ff == TMap.stairLo[i] ? "UP" : "DOWN").font(.system(size: 12, weight: .heavy)).foregroundColor(Color(red: 1, green: 0.88, blue: 0.25)), at: pt)
            }
        }
        // lane callouts
        for rm in TMap.rooms where rm.fl == ff && !fp {
            let dd = hypot(rm.r.midX - focus.pos.x, rm.r.midY - focus.pos.y)
            if fp && dd > 900 { continue }
            guard let pt = pr(CGPoint(x: rm.r.midX, y: rm.r.midY), fp ? 74 : 4) else { continue }
            let al = fp ? Double(max(0.15, min(0.7, 1.1 - dd / 900))) : 0.5
            ctx.draw(Text(rm.name.uppercased()).font(.system(size: fp ? 14 : 11, weight: .heavy)).foregroundColor(Color(red: 1, green: 0.93, blue: 0.7).opacity(al)), at: pt)
        }
        // name tags: every visible player gets a name, health and armor bar; staff/admin are marked
        let gold = Color(red: 1, green: 0.82, blue: 0.25)
        for p in players where p.alive && !p.isPlayer && p.id != focus.id {
            let ally = p.team == me.team
            if !(ally || p.spotted) { continue }
            let dx0 = p.pos.x - focus.pos.x, dy0 = p.pos.y - focus.pos.y
            let dist = hypot(dx0, dy0)
            if fp && dist > 1100 { continue }
            if TMap.floorOf(p.pos) != TMap.floorOf(focus.pos) { continue }
            if fp && TMap.rayDist(focus.pos, atan2(dy0, dx0), dist + 1) < dist - 24 { continue }
            guard let pt = pr(p.pos, 74) else { continue }
            let k = max(0.72, min(1.15, 1.25 - dist / 900))
            let nameCol: Color = p.rank == 2 ? Color(red: 1, green: 0.22, blue: 0.22)
                : (p.rank == 1 ? Color(red: 0.45, green: 0.95, blue: 0.65)
                : (ally ? Color(red: 0.42, green: 0.72, blue: 1) : Color(red: 1, green: 0.68, blue: 0.28)))
            let fs = 12 * k
            let main = ctx.resolve(Text(p.name).font(.system(size: fs, weight: .heavy)).foregroundColor(nameCol))
            let shade = ctx.resolve(Text(p.name).font(.system(size: fs, weight: .heavy)).foregroundColor(.black.opacity(0.75)))
            let nsz = main.measure(in: CGSize(width: 320, height: 40))
            let crownW: CGFloat = p.rank == 2 ? 15 * k : 0
            let badgeW: CGFloat = p.rank == 1 ? 34 * k : 0
            let gap: CGFloat = 4 * k
            let showL = TacLeague.shows(p.trophies)
            let lgW: CGFloat = showL ? 11 * k : 0
            let total = (crownW > 0 ? crownW + gap : 0) + nsz.width + (badgeW > 0 ? badgeW + gap : 0) + (showL ? lgW + gap : 0)
            var x0 = pt.x - total / 2
            let yMid = pt.y - 8 * k
            if crownW > 0 {
                let h = 11 * k
                var c = Path()
                c.move(to: CGPoint(x: x0, y: yMid + h / 2))
                c.addLine(to: CGPoint(x: x0, y: yMid - h * 0.3))
                c.addLine(to: CGPoint(x: x0 + crownW * 0.26, y: yMid + h * 0.05))
                c.addLine(to: CGPoint(x: x0 + crownW * 0.5, y: yMid - h / 2))
                c.addLine(to: CGPoint(x: x0 + crownW * 0.74, y: yMid + h * 0.05))
                c.addLine(to: CGPoint(x: x0 + crownW, y: yMid - h * 0.3))
                c.addLine(to: CGPoint(x: x0 + crownW, y: yMid + h / 2))
                c.closeSubpath()
                ctx.fill(c, with: .color(gold))
                ctx.stroke(c, with: .color(Color(red: 0.45, green: 0.3, blue: 0.05)), lineWidth: 1)
                ctx.fill(Path(CGRect(x: x0, y: yMid + h * 0.28, width: crownW, height: h * 0.22)), with: .color(Color(red: 0.8, green: 0.55, blue: 0.1)))
                for jx in [0.0, 0.5, 1.0] as [CGFloat] {
                    let r: CGFloat = 1.5 * k
                    let jy = jx == 0.5 ? yMid - h / 2 : yMid - h * 0.3
                    ctx.fill(Path(ellipseIn: CGRect(x: x0 + crownW * jx - r, y: jy - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.9)))
                }
                x0 += crownW + gap
            }
            ctx.draw(shade, at: CGPoint(x: x0 + 1, y: yMid + 1), anchor: .leading)
            ctx.draw(main, at: CGPoint(x: x0, y: yMid), anchor: .leading)
            x0 += nsz.width + gap
            if badgeW > 0 {
                let br = CGRect(x: x0, y: yMid - 6 * k, width: badgeW, height: 12 * k)
                ctx.fill(Path(roundedRect: br, cornerRadius: 3 * k), with: .color(Color(red: 0.1, green: 0.55, blue: 0.4)))
                ctx.draw(Text("STAFF").font(.system(size: 8 * k, weight: .heavy)).foregroundColor(.white), at: CGPoint(x: br.midX, y: br.midY))
                x0 += badgeW + gap
            }
            if showL {
                let sr = CGRect(x: x0, y: yMid - 7 * k, width: lgW, height: 14 * k)
                let sh = LeagueShield().path(in: sr)
                ctx.fill(sh, with: .color(TacLeague.color(p.trophies)))
                ctx.stroke(sh, with: .color(.black.opacity(0.75)), lineWidth: 1)
                ctx.draw(Text("\(TacLeague.index(p.trophies) - 1)").font(.system(size: 7 * k, weight: .heavy)).foregroundColor(.black.opacity(0.85)), at: CGPoint(x: sr.midX, y: sr.midY - 0.5 * k))
            }
            let bw: CGFloat = 54 * k, bh: CGFloat = 5 * k
            let bar = CGRect(x: pt.x - bw / 2, y: pt.y + 2 * k, width: bw, height: bh)
            let frac = max(0, min(1, p.hp / 100))
            let hpCol: Color = frac > 0.6 ? Color(red: 0.35, green: 0.9, blue: 0.4) : (frac > 0.3 ? Color(red: 1, green: 0.8, blue: 0.2) : Color(red: 1, green: 0.28, blue: 0.25))
            ctx.fill(Path(roundedRect: bar.insetBy(dx: -1, dy: -1), cornerRadius: bh / 2 + 1), with: .color(.black.opacity(0.7)))
            if frac > 0 { ctx.fill(Path(roundedRect: CGRect(x: bar.minX, y: bar.minY, width: bw * frac, height: bh), cornerRadius: bh / 2), with: .color(hpCol)) }
            if p.armor > 0 {
                let ab = CGRect(x: bar.minX, y: bar.maxY + 2 * k, width: bw, height: 2.5 * k)
                ctx.fill(Path(roundedRect: ab, cornerRadius: 1.2 * k), with: .color(.black.opacity(0.6)))
                ctx.fill(Path(roundedRect: CGRect(x: ab.minX, y: ab.minY, width: bw * max(0, min(1, p.armor / 100)), height: ab.height), cornerRadius: 1.2 * k), with: .color(Color(red: 0.4, green: 0.7, blue: 1)))
            }
            if p.reloadT > 0 {
                ctx.draw(Text("reloading").font(.system(size: 9 * k, weight: .semibold)).foregroundColor(.white.opacity(0.85)), at: CGPoint(x: pt.x, y: bar.maxY + 12 * k))
            }
        }
        if autoTarget >= 0, let tp = players.first(where: { $0.id == autoTarget }), tp.alive, let pt = pr(tp.pos, 30) {
            let r: CGFloat = 26 + 3 * CGFloat(sin(Double(time) * 8))
            ctx.stroke(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(Color(red: 1, green: 0.3, blue: 0.3).opacity(0.9)), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            var cx = Path()
            cx.move(to: CGPoint(x: pt.x - 8, y: pt.y)); cx.addLine(to: CGPoint(x: pt.x + 8, y: pt.y))
            cx.move(to: CGPoint(x: pt.x, y: pt.y - 8)); cx.addLine(to: CGPoint(x: pt.x, y: pt.y + 8))
            ctx.stroke(cx, with: .color(Color(red: 1, green: 0.3, blue: 0.3)), lineWidth: 1.5)
        }
        // pings
        for pg in pings {
            guard let pt = pr(pg.pos, 40) else { continue }
            let al = Double(min(1, pg.life))
            var dm = Path()
            dm.move(to: CGPoint(x: pt.x, y: pt.y - 12)); dm.addLine(to: CGPoint(x: pt.x + 8, y: pt.y - 22))
            dm.addLine(to: CGPoint(x: pt.x, y: pt.y - 32)); dm.addLine(to: CGPoint(x: pt.x - 8, y: pt.y - 22)); dm.closeSubpath()
            ctx.fill(dm, with: .color(Color.orange.opacity(al)))
            if !fp { ctx.draw(Text(pg.text).font(.system(size: 12, weight: .heavy)).foregroundColor(Color.yellow.opacity(al)), at: CGPoint(x: pt.x, y: pt.y - 44)) }
        }
        for pp in pops {
            guard let pt = pr(pp.pos, 50 + (1 - pp.life) * 40) else { continue }
            ctx.draw(Text(pp.text).font(.system(size: 16, weight: .heavy)).foregroundColor(pp.color.opacity(Double(pp.life))), at: pt)
        }
        if planted, let pt = pr(bombPos, 36) {
            ctx.draw(Text(String(format: "%.0f", max(0, bombT))).font(.system(size: 14, weight: .heavy)).foregroundColor(.white), at: pt)
        }
        let vg = Gradient(colors: [Color.clear, Color.black.opacity(fp ? 0.18 : 0.5)])
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(vg, center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: min(size.width, size.height) * 0.45, endRadius: max(size.width, size.height) * 0.72))
        if fp {
            var inSmoke: CGFloat = 0
            for sm in smokeClouds where hypot(sm.pos.x - focus.pos.x, sm.pos.y - focus.pos.y) < sm.r * 0.8 {
                inSmoke = max(inSmoke, min(1, sm.life / 1.5))
            }
            if inSmoke > 0 {
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(white: 0.72).opacity(0.92 * Double(inSmoke))))
            }
            let cx = size.width / 2, hz = size.height / 2
            // no crosshair: hip fire is spread, ADS lines the weapon's own sights up with the view
            if hitT > 0 {
                var hm = Path()
                hm.move(to: CGPoint(x: cx - 9, y: hz - 9)); hm.addLine(to: CGPoint(x: cx + 9, y: hz + 9))
                hm.move(to: CGPoint(x: cx + 9, y: hz - 9)); hm.addLine(to: CGPoint(x: cx - 9, y: hz + 9))
                ctx.stroke(hm, with: .color(.red), lineWidth: 3)
            }
            if scoped && me.alive {
                let r = min(size.width, size.height) * 0.46
                var sc = Path(CGRect(origin: .zero, size: size))
                sc.addEllipse(in: CGRect(x: cx - r, y: hz - r, width: r * 2, height: r * 2))
                ctx.fill(sc, with: .color(.black), style: FillStyle(eoFill: true))
                var ln = Path()
                ln.move(to: CGPoint(x: cx - r, y: hz)); ln.addLine(to: CGPoint(x: cx + r, y: hz))
                ln.move(to: CGPoint(x: cx, y: hz - r)); ln.addLine(to: CGPoint(x: cx, y: hz + r))
                ctx.stroke(ln, with: .color(.black.opacity(0.9)), lineWidth: 1.5)
            }
            if me.blind > 0 {
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(Double(min(1, me.blind * 1.2)))))
            }
        }
        drawMinimapPublic(&ctx)
        if me.hurt > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.red.opacity(Double(me.hurt) * 0.45)))
        }
        if !me.alive {
            ctx.draw(Text("SPECTATING " + focus.name.uppercased()).font(.system(size: 12, weight: .heavy)).foregroundColor(.white.opacity(0.7)), at: CGPoint(x: size.width / 2, y: size.height - 70))
        }
    }
}

extension TacScene {

    /// lobby hero shot: all three floors stacked like a cutaway dollhouse, slowly orbiting
    func orbit(_ time: Double) {
        if !dollhouse {
            dollhouse = true
            for i in 0..<3 {
                floorRoot[i].position = MXVector3(-Float(TMap.origin(i)), Float(i) * 125, 0)
                floorRoot[i].isHidden = false
            }
            vm.root.isHidden = true
            camNode.camera?.zNear = 10
            camNode.camera?.zFar = 7000
            camNode.camera?.fieldOfView = 44
            scene.fogStartDistance = 2600
            scene.fogEndDistance = 7000
        }
        let a = time * 0.1
        let cx: Double = 1500, cz: Double = Double(TMap.H) / 2
        camNode.position = MXVector3(Float(cx + cos(a) * 2500), 1750 + Float(sin(a * 0.7)) * 160, Float(cz + sin(a) * 2000))
        camNode.look(at: MXVector3(Float(cx), 150, Float(cz)))
    }
}
