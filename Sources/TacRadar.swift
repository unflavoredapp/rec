import SwiftUI
import UIKit

/// Pre-baked top-down map image used by the first-person radar. Built once, drawn as one image per frame.
enum TacRadar {
    static var k: CGFloat { TMap.kind == 4 ? 0.09 : 0.35 }

    private static var cache: [UIImage] = []
    private static var cacheKind = -1

    /// map image for a floor of the currently loaded map (rebuilt when the map changes)
    static func image(_ fl: Int) -> UIImage {
        if cacheKind != TMap.kind || cache.isEmpty {
            cache = (0..<TMap.nFloors).map { make($0) }
            cacheKind = TMap.kind
        }
        return cache[fl]
    }

    static func make(_ fl: Int) -> UIImage {
        let ox = TMap.origin(fl)
        func here(_ r: CGRect) -> Bool { TMap.floorOfX(r.midX) == fl }
        let size = CGSize(width: TMap.floorW * k, height: TMap.H * k)
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { rc in
            let g = rc.cgContext
            g.scaleBy(x: k, y: k)
            g.translateBy(x: -ox, y: 0)
            func col(_ r: CGFloat, _ gg: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: gg, blue: b, alpha: a) }
            g.setFillColor(col(0.07, 0.075, 0.09))
            g.fill(CGRect(x: ox, y: 0, width: TMap.floorW, height: TMap.H))
            let floors: [(CGFloat, CGFloat, CGFloat)] = [(0.55, 0.43, 0.3), (0.5, 0.47, 0.42), (0.42, 0.36, 0.3), (0.6, 0.55, 0.46), (0.4, 0.3, 0.22), (0.52, 0.5, 0.48), (0.2, 0.36, 0.17), (0.38, 0.3, 0.2), (0.33, 0.34, 0.37)]
            for rm in TMap.floorTiles where rm.fl == fl {
                let wc = TWorkshop.floorMatCols[min(rm.mat, TWorkshop.floorMatCols.count - 1)]
                let f = rm.mat < floors.count ? floors[rm.mat] : (wc.0 * 0.85, wc.1 * 0.85, wc.2 * 0.85)
                g.setFillColor(col(f.0, f.1, f.2))
                g.fill(rm.r)
                // soft inner shade so rooms read as sunken floor
                g.setStrokeColor(col(0, 0, 0, 0.25))
                g.setLineWidth(14)
                g.stroke(rm.r.insetBy(dx: 7, dy: 7))
            }
            // tile grid + grit
            g.setStrokeColor(col(0, 0, 0, 0.07))
            g.setLineWidth(2)
            var gx: CGFloat = ox
            while gx < ox + TMap.floorW { g.move(to: CGPoint(x: gx, y: 0)); g.addLine(to: CGPoint(x: gx, y: TMap.H)); gx += 100 }
            var gy: CGFloat = 0
            while gy < TMap.H { g.move(to: CGPoint(x: ox, y: gy)); g.addLine(to: CGPoint(x: ox + TMap.floorW, y: gy)); gy += 100 }
            g.strokePath()
            var seed: UInt64 = 7
            func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) & 0xFFFF) / 65535 }
            for _ in 0..<2600 {
                let p = CGPoint(x: ox + rnd() * TMap.floorW, y: rnd() * TMap.H)
                g.setFillColor(rnd() > 0.5 ? col(1, 1, 1, 0.05) : col(0, 0, 0, 0.07))
                g.fill(CGRect(x: p.x, y: p.y, width: 10 + rnd() * 16, height: 8 + rnd() * 10))
            }
            // sites
            for i in 0..<2 where TMap.kind != 1 && TMap.kind != 4 && here(TMap.site(i)) {
                let r = TMap.site(i)
                g.setFillColor(col(0.98, 0.8, 0.1, 0.22))
                g.fill(r)
                g.setStrokeColor(col(0.98, 0.8, 0.1, 0.9))
                g.setLineWidth(10)
                g.setLineDash(phase: 0, lengths: [40, 26])
                g.stroke(r.insetBy(dx: 8, dy: 8))
                g.setLineDash(phase: 0, lengths: [])
                let t = (i == 0 ? "A" : "B") as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 120, weight: .heavy), .foregroundColor: UIColor(red: 0.98, green: 0.8, blue: 0.1, alpha: 0.9)]
                let sz = t.size(withAttributes: attrs)
                t.draw(at: CGPoint(x: r.midX - sz.width / 2, y: r.midY - sz.height / 2), withAttributes: attrs)
            }
            // props with drop shadow
            for pr in TMap.props where here(pr.r) {
                g.setFillColor(col(0, 0, 0, 0.35))
                g.fill(pr.r.offsetBy(dx: 7, dy: 9))
                let c: (CGFloat, CGFloat, CGFloat) = pr.k == .tree ? (0.1, 0.27, 0.1) : (pr.k == .rock ? (0.45, 0.46, 0.48) : pr.k == .car ? (0.6, 0.2, 0.15) : (pr.k == .sandbag ? (0.7, 0.6, 0.4) : (pr.k == .barrel ? (0.35, 0.28, 0.2) : (0.5, 0.36, 0.2))))
                g.setFillColor(col(c.0, c.1, c.2))
                g.fill(pr.r)
                g.setStrokeColor(col(0, 0, 0, 0.5))
                g.setLineWidth(4)
                g.stroke(pr.r)
            }
            // stairs
            for (i, sr) in TMap.stairs.enumerated() where fl == TMap.stairLo[i] || fl == TMap.stairLo[i] + 1 {
                let r = sr.offsetBy(dx: ox, dy: 0)
                g.setFillColor(col(0.98, 0.85, 0.2, 0.85))
                g.fill(r)
                g.setStrokeColor(col(0.1, 0.08, 0.02, 0.8))
                g.setLineWidth(4)
                var y = r.minY + 15
                while y < r.maxY { g.move(to: CGPoint(x: r.minX, y: y)); g.addLine(to: CGPoint(x: r.maxX, y: y)); y += 20 }
                g.strokePath()
            }
            // doors
            for d in TMap.doors where here(d) {
                g.setFillColor(col(0.75, 0.55, 0.28))
                g.fill(d)
            }
            // walls: shadow, body, lit top edge
            for (i, w) in TMap.walls.enumerated() where here(w) {
                g.setFillColor(col(0, 0, 0, 0.45))
                g.fill(w.offsetBy(dx: 10, dy: 12))
                let m = TMap.wallMats[i]
                let c: (CGFloat, CGFloat, CGFloat) = m == .glass ? (0.5, 0.7, 0.8) : (m == .wood ? (0.35, 0.24, 0.14) : (m == .brick ? (0.28, 0.2, 0.17) : (0.22, 0.22, 0.24)))
                g.setFillColor(col(c.0, c.1, c.2))
                g.fill(w)
                g.setFillColor(col(1, 1, 1, 0.16))
                g.fill(CGRect(x: w.minX, y: w.minY, width: w.width, height: min(10, w.height)))
            }
        }
    }
}
