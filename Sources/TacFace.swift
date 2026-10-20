import UIKit

/// Draws the soldier's face texture directly with Core Graphics (no SwiftUI render step).
/// The image is a planar projection of the front of the head: x = 0.5 - z/span, y = 0.5 - height/span.
enum TacFace {
    private static func rgb(_ v: UInt32, _ f: CGFloat = 1) -> UIColor {
        UIColor(red: min(1, CGFloat((v >> 16) & 255) / 255 * f), green: min(1, CGFloat((v >> 8) & 255) / 255 * f), blue: min(1, CGFloat(v & 255) / 255 * f), alpha: 1)
    }

    private static func pal(_ a: [UInt32], _ i: Int?, _ d: Int) -> UInt32 {
        a[((i ?? d) % a.count + a.count) % a.count]
    }

    private static var cache: [String: UIImage] = [:]

    /// Cached face texture for a style (main thread).
    static func cached(_ s: TwStyle) -> UIImage {
        let k = s.key + "|" + ((try? JSONEncoder().encode(s.look)).flatMap { String(data: $0, encoding: .utf8) } ?? "") + "|\(s.skin.hashValue)|\(s.hairCol.hashValue)"
        if let c = cache[k] { return c }
        let img = image(s)
        if cache.count > 200 { cache.removeAll() }
        cache[k] = img
        return img
    }

    static func image(_ s: TwStyle, size: CGFloat = 256) -> UIImage {
        let l = s.look
        let N = size, span: CGFloat = 10.5
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        if #available(iOS 12.0, *) { fmt.preferredRange = .standard }
        let skin = s.skin
        var sr: CGFloat = 0, sg: CGFloat = 0, sb: CGFloat = 0, sa: CGFloat = 0
        skin.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
        func shade(_ f: CGFloat, _ a: CGFloat = 1) -> UIColor { UIColor(red: min(1, sr * f), green: min(1, sg * f), blue: min(1, sb * f), alpha: a) }
        let hairC = s.hairCol
        let browC = l.browColor.map { rgb(pal(PortraitAvatar.hairs, $0, 0)) } ?? hairC
        let beardC = l.beardColor.map { rgb(pal(PortraitAvatar.hairs, $0, 0)) } ?? hairC
        let eyeC = rgb(pal(PortraitAvatar.eyeCols, l.eyeColor, 1))
        let lipC: UIColor = l.lips.map { rgb(pal(PortraitAvatar.lipCols, $0, 0)) } ?? UIColor(red: min(1, sr * 0.84 + 0.1), green: sg * 0.62, blue: sb * 0.6, alpha: 1)
        let paintC = rgb(pal(PortraitAvatar.paints, l.paintColor, 0))
        let fs = (l.faceShape ?? 0) % 5

        return UIGraphicsImageRenderer(size: CGSize(width: N, height: N), format: fmt).image { rc in
            let c = rc.cgContext
            func P(_ z: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (0.5 - z / span) * N, y: (0.5 - y / span) * N) }
            func U(_ v: CGFloat) -> CGFloat { v / span * N }
            func ell(_ z: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ col: UIColor) {
                col.setFill()
                c.fillEllipse(in: CGRect(x: P(z, y).x - U(w) / 2, y: P(z, y).y - U(h) / 2, width: U(w), height: U(h)))
            }
            /// soft radial blob that fades to nothing at its rim (no hard edges near the patch border)
            func soft(_ z: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ col: UIColor, _ a: CGFloat) {
                var r0: CGFloat = 0, g0: CGFloat = 0, b0: CGFloat = 0, a0: CGFloat = 0
                col.getRed(&r0, green: &g0, blue: &b0, alpha: &a0)
                let cs = CGColorSpaceCreateDeviceRGB()
                guard let g = CGGradient(colorsSpace: cs, colors: [UIColor(red: r0, green: g0, blue: b0, alpha: a).cgColor, UIColor(red: r0, green: g0, blue: b0, alpha: 0).cgColor] as CFArray, locations: [0, 1]) else { return }
                c.saveGState()
                c.translateBy(x: P(z, y).x, y: P(z, y).y)
                c.scaleBy(x: U(w) / 2, y: U(h) / 2)
                c.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
                c.restoreGState()
            }
            func rect(_ z: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ col: UIColor, _ r: CGFloat = 0.15) {
                col.setFill()
                UIBezierPath(roundedRect: CGRect(x: P(z, y).x - U(w) / 2, y: P(z, y).y - U(h) / 2, width: U(w), height: U(h)), cornerRadius: U(r)).fill()
            }
            func stroke(_ pts: [(CGFloat, CGFloat)], _ w: CGFloat, _ col: UIColor, curve: Bool = true) {
                guard pts.count >= 2 else { return }
                let p = UIBezierPath()
                p.move(to: P(pts[0].0, pts[0].1))
                if curve && pts.count == 3 {
                    p.addQuadCurve(to: P(pts[2].0, pts[2].1), controlPoint: P(pts[1].0, pts[1].1))
                } else {
                    for q in pts.dropFirst() { p.addLine(to: P(q.0, q.1)) }
                }
                p.lineWidth = U(w)
                p.lineCapStyle = .round
                p.lineJoinStyle = .round
                col.setStroke()
                p.stroke()
            }
            func poly(_ pts: [(CGFloat, CGFloat)], _ col: UIColor) {
                let p = UIBezierPath()
                p.move(to: P(pts[0].0, pts[0].1))
                for q in pts.dropFirst() { p.addLine(to: P(q.0, q.1)) }
                p.close()
                col.setFill()
                p.fill()
            }

            // base skin + soft form shading (jaw and temples slightly darker, forehead and cheeks lighter)
            skin.setFill()
            c.fill(CGRect(x: 0, y: 0, width: N, height: N))
            soft(0, 1.6, 7.0, 6.0, shade(1.08), 0.55)
            soft(0, -2.8, 6.0, 3.6, shade(0.84), 0.5)

            // blush
            let ba: CGFloat = [0.16, 0.0, 0.34][(l.blush ?? 0) % 3]
            if ba > 0 { for sgn in [-1.0, 1.0] as [CGFloat] { soft(sgn * 2.55, -1.15, 2.6, 1.7, UIColor(red: 0.95, green: 0.35, blue: 0.4, alpha: 1), ba * 1.5) } }

            // nose
            let nk = (l.nose ?? 0) % 4
            let nw: CGFloat = [0.9, 1.3, 1.8, 0.9][nk]
            stroke([(0.2, 0.9), (0.55, -0.4), (0.2, -1.1)], 0.18, shade(0.78, 0.7))
            soft(0, -1.25, nw + 1.6, 1.3, shade(0.8), 0.6)
            ell(-nw / 2 - 0.05, -1.4, 0.3, 0.2, shade(0.5, 0.8))
            ell(nw / 2 + 0.05, -1.4, 0.3, 0.2, shade(0.5, 0.8))
            soft(0, -0.7, 1.0, 1.8, shade(1.14), 0.5)

            // freckles / mole / scar
            if l.freckles == true {
                var seed: UInt64 = 7
                func nx() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 1000) / 1000 }
                for _ in 0..<26 {
                    let z = (nx() - 0.5) * 6.2
                    let y = -0.4 - nx() * 1.4
                    if abs(z) < 0.8 { continue }
                    ell(z, y, 0.17, 0.17, shade(0.62, 0.8))
                }
            }
            switch l.mole ?? 0 {
            case 1: ell(-2.7, -1.9, 0.3, 0.3, shade(0.35))
            case 2: ell(0.9, -2.9, 0.28, 0.28, shade(0.35))
            case 3: ell(2.1, 2.5, 0.28, 0.28, shade(0.35))
            default: break
            }

            // eyes
            let ek = (l.eyes ?? 0) % 3
            for sgn in [-1.0, 1.0] as [CGFloat] {
                let ez = sgn * 1.85, ey: CGFloat = 0.9
                if ek == 2 {
                    // happy: closed arcs
                    stroke([(ez - 0.95, ey - 0.2), (ez, ey + 0.8), (ez + 0.95, ey - 0.2)], 0.28, UIColor(white: 0.08, alpha: 1))
                } else {
                    let w: CGFloat = ek == 1 ? 2.25 : 1.9, h: CGFloat = ek == 1 ? 1.25 : 1.05
                    soft(ez, ey - 0.02, w + 1.0, h + 0.9, shade(0.78), 0.65)      // socket shadow
                    ell(ez, ey, w, h, UIColor(white: 0.97, alpha: 1))
                    ell(ez, ey + h * 0.28, w, h * 0.5, UIColor(white: 0.8, alpha: 0.35))   // lid shadow on the white
                    ell(ez - sgn * 0.05, ey - 0.02, 0.98, 0.98, eyeC)
                    ell(ez - sgn * 0.05, ey - 0.02, 0.98, 0.98, UIColor(white: 0, alpha: 0.18))
                    ell(ez - sgn * 0.05, ey - 0.02, 0.58, 0.58, eyeC)
                    ell(ez - sgn * 0.05, ey - 0.02, 0.34, 0.34, UIColor(white: 0.03, alpha: 1))
                    ell(ez + 0.22, ey + 0.22, 0.24, 0.24, UIColor(white: 1, alpha: 0.95))
                    stroke([(ez - w / 2 - 0.05, ey + 0.05), (ez, ey + h / 2 + 0.12), (ez + w / 2 + 0.05, ey + 0.05)], 0.2, UIColor(white: 0.07, alpha: 0.95))
                    if l.lashes == true {
                        stroke([(ez + sgn * (w / 2), ey + 0.15), (ez + sgn * (w / 2 + 0.5), ey + 0.5)], 0.14, UIColor(white: 0.05, alpha: 1))
                    }
                }
                // eyebrows
                let bk = (l.brow ?? 0) % 5
                let bz = sgn * 1.95
                let by: CGFloat = 2.35
                switch bk {
                case 0: stroke([(bz - 1.1, by), (bz, by + 0.18), (bz + 1.1, by - 0.05)], 0.22, browC)
                case 1: stroke([(bz - 1.15, by - 0.05), (bz, by + 0.15), (bz + 1.15, by - 0.1)], 0.42, browC)
                case 2: stroke([(bz - sgn * 1.2, by + 0.28), (bz + sgn * 1.2, by - 0.32)], 0.38, browC, curve: false)
                case 3: stroke([(bz - 1.1, by + 0.1), (bz, by + 0.7), (bz + 1.1, by + 0.1)], 0.3, browC)
                default: break
                }
            }

            // face shape cheek tweak (slim / round / wide / long are mostly silhouette, nudge the jaw tone)
            if fs == 1 { for sgn in [-1.0, 1.0] as [CGFloat] { soft(sgn * 2.8, -2.4, 2.4, 3.4, shade(0.88), 0.3) } }

            // mouth
            let mk = (l.mouth ?? 0) % 4
            let my: CGFloat = -2.55
            switch mk {
            case 0:
                stroke([(-1.35, my + 0.1), (0, my - 0.5), (1.35, my + 0.1)], 0.3, lipC)
                ell(0, my - 0.62, 1.7, 0.4, lipC.withAlphaComponent(0.5))
            case 1:
                stroke([(-1.3, my), (1.3, my)], 0.3, lipC, curve: false)
                ell(0, my - 0.28, 2.0, 0.42, lipC.withAlphaComponent(0.45))
            case 2:
                stroke([(-1.3, my - 0.1), (0.1, my - 0.15), (1.3, my + 0.35)], 0.3, lipC)
            default:
                let p = UIBezierPath()
                p.move(to: P(-1.45, my + 0.15))
                p.addQuadCurve(to: P(1.45, my + 0.15), controlPoint: P(0, my - 1.5))
                p.addQuadCurve(to: P(-1.45, my + 0.15), controlPoint: P(0, my + 0.15))
                UIColor(red: 0.28, green: 0.08, blue: 0.1, alpha: 1).setFill(); p.fill()
                rect(0, my - 0.12, 2.3, 0.4, UIColor(white: 0.97, alpha: 1), 0.1)
                stroke([(-1.45, my + 0.15), (0, my - 1.5), (1.45, my + 0.15)], 0.16, lipC)
            }

            // facial hair
            let bd = l.beard ?? 0
            switch bd {
            case 1:   // stubble
                var seed: UInt64 = 21
                func nx() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 1000) / 1000 }
                for _ in 0..<420 {
                    let z = (nx() - 0.5) * 7.4, y = -1.3 - nx() * 3.6
                    let edge = (z / 3.9) * (z / 3.9) + ((y + 0.6) / 4.6) * ((y + 0.6) / 4.6)
                    if edge > 1 || y > -1.4 { continue }
                    ell(z, y, 0.1, 0.1, beardC.withAlphaComponent(0.55))
                }
            case 2:   // mustache
                poly([(-1.9, -1.55), (0, -1.9), (1.9, -1.55), (1.5, -2.15), (0, -2.0), (-1.5, -2.15)], beardC)
            case 3:   // goatee
                ell(0, -3.5, 1.9, 1.5, beardC)
                poly([(-1.5, -1.6), (0, -1.9), (1.5, -1.6), (1.0, -2.2), (-1.0, -2.2)], beardC)
            case 4:   // full beard
                let p = UIBezierPath()
                p.move(to: P(-3.9, -0.6)); p.addLine(to: P(-3.5, -4.6)); p.addQuadCurve(to: P(3.5, -4.6), controlPoint: P(0, -5.0)); p.addLine(to: P(3.9, -0.6))
                p.addLine(to: P(2.6, -1.4)); p.addQuadCurve(to: P(-2.6, -1.4), controlPoint: P(0, -1.0)); p.close()
                beardC.setFill(); p.fill()
                // mouth cut-out
                stroke([(-1.3, my + 0.05), (0, my - 0.4), (1.3, my + 0.05)], 0.34, lipC)
            case 5:   // soul patch
                ell(0, -3.45, 0.8, 0.9, beardC)
            case 6:   // handlebar
                poly([(-2.0, -1.55), (0, -1.9), (2.0, -1.55), (2.6, -1.0), (1.9, -1.9), (0, -2.2), (-1.9, -1.9), (-2.6, -1.0)], beardC)
            case 7:   // chinstrap
                stroke([(-3.6, -0.6), (-3.3, -3.6), (0, -4.4), (3.3, -3.6), (3.6, -0.6)], 0.5, beardC, curve: false)
            default: break
            }

            // scar
            switch l.scar ?? 0 {
            case 1:
                stroke([(2.5, 3.2), (1.3, 1.6)], 0.14, UIColor(red: 0.62, green: 0.25, blue: 0.25, alpha: 0.9), curve: false)
                for k in 0..<3 { let t = CGFloat(k) * 0.32; stroke([(2.2 - t * 0.9 + 0.25, 2.8 - t * 1.0), (2.2 - t * 0.9 - 0.25, 2.8 - t * 1.0 - 0.1)], 0.08, UIColor(white: 0.95, alpha: 0.7), curve: false) }
            case 2:
                stroke([(-3.0, -0.1), (-2.0, -1.6)], 0.14, UIColor(red: 0.62, green: 0.25, blue: 0.25, alpha: 0.9), curve: false)
            default: break
            }

            // face paint
            let pk = l.paint
            if pk > 0 {
                let a = paintC.withAlphaComponent(0.9)
                switch pk {
                case 1: for sgn in [-1.0, 1.0] as [CGFloat] { for k in 0..<3 { stroke([(sgn * 2.2, -0.4 - CGFloat(k) * 0.35), (sgn * 3.6, -0.6 - CGFloat(k) * 0.35)], 0.16, a, curve: false) } }
                case 2: for sgn in [-1.0, 1.0] as [CGFloat] { ell(sgn * 2.8, -1.1, 0.8, 0.8, a) }
                case 3: for sgn in [-1.0, 1.0] as [CGFloat] { stroke([(sgn * 2.4, 0.2), (sgn * 3.0, -0.6), (sgn * 2.6, -0.6), (sgn * 3.2, -1.6)], 0.2, a, curve: false) }
                case 4: for sgn in [-1.0, 1.0] as [CGFloat] { for k in 0..<3 { stroke([(sgn * 2.2, 0.3 - CGFloat(k) * 0.5), (sgn * 3.7, 0.5 - CGFloat(k) * 0.7)], 0.2, UIColor(white: 0.08, alpha: 0.85), curve: false) } }
                case 5: ell(0, -1.3, 1.1, 1.1, UIColor(red: 0.95, green: 0.15, blue: 0.2, alpha: 1))
                case 8, 15: for sgn in [-1.0, 1.0] as [CGFloat] { ell(sgn * 1.85, 0.9, 2.3, 2.1, UIColor(white: 0.05, alpha: 0.85)) }; poly([(0, -0.9), (-0.4, -1.7), (0.4, -1.7)], UIColor(white: 0.05, alpha: 0.85))
                case 9: rect(0, 0.9, 6.6, 1.5, UIColor(white: 0.05, alpha: 0.9), 0.5)
                case 13: for sgn in [-1.0, 1.0] as [CGFloat] { for k in 0..<3 { stroke([(sgn * 2.3, -1.2 - CGFloat(k) * 0.35 + 0.35), (sgn * 3.9, -1.5 - CGFloat(k) * 0.7 + 0.7)], 0.1, UIColor(white: 0.1, alpha: 0.85), curve: false) } }
                case 16: for sgn in [-1.0, 1.0] as [CGFloat] { rect(sgn * 1.85, -0.35, 2.3, 0.45, UIColor(white: 0.05, alpha: 0.85), 0.2) }
                case 12: for sgn in [-1.0, 1.0] as [CGFloat] { stroke([(sgn * 1.85, 0.1), (sgn * 2.0, -1.8)], 0.18, UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 0.9), curve: false) }
                case 7: for sgn in [-1.0, 1.0] as [CGFloat] { ell(sgn * 2.9, -1.0, 0.9, 0.85, a) }
                default: for sgn in [-1.0, 1.0] as [CGFloat] { for k in 0..<3 { ell(sgn * (2.3 + CGFloat(k) * 0.55), -0.6 - CGFloat(k % 2) * 0.5, 0.35, 0.35, a) } }
                }
            }

            // eyewear
            switch l.specs ?? 0 {
            case 1:
                for sgn in [-1.0, 1.0] as [CGFloat] {
                    c.setLineWidth(U(0.16)); UIColor(white: 0.1, alpha: 1).setStroke()
                    c.strokeEllipse(in: CGRect(x: P(sgn * 1.85, 0.9).x - U(1.3), y: P(sgn * 1.85, 0.9).y - U(1.3), width: U(2.6), height: U(2.6)))
                }
                stroke([(-0.55, 1.0), (0.55, 1.0)], 0.14, UIColor(white: 0.1, alpha: 1), curve: false)
            case 2:
                for sgn in [-1.0, 1.0] as [CGFloat] { rect(sgn * 1.85, 0.9, 2.9, 1.7, UIColor(white: 0.04, alpha: 0.94), 0.5) }
                stroke([(-0.5, 1.2), (0.5, 1.2)], 0.2, UIColor(white: 0.04, alpha: 1), curve: false)
            case 3:
                rect(0, 0.9, 7.6, 1.9, UIColor(red: 0.2, green: 0.8, blue: 1, alpha: 0.78), 0.6)
                rect(0, 1.3, 7.2, 0.35, UIColor(white: 1, alpha: 0.4), 0.2)
            default: break
            }

            // masks
            switch l.mask ?? 0 {
            case 1:
                rect(0, -2.5, 7.4, 4.3, UIColor(red: 0.62, green: 0.82, blue: 0.95, alpha: 1), 1.2)
                for k in 0..<3 { stroke([(-3.5, -1.6 - CGFloat(k) * 0.8), (3.5, -1.6 - CGFloat(k) * 0.8)], 0.08, UIColor(white: 1, alpha: 0.45), curve: false) }
            case 2: rect(0, -2.5, 7.6, 4.4, UIColor(white: 0.08, alpha: 1), 1.2); rect(0, 0.9, 7.8, 1.8, UIColor(white: 0.08, alpha: 1), 0.3)
            case 3: rect(0, -2.5, 7.6, 4.4, rgb(pal(PortraitAvatar.paints, l.accent, 0)), 1.2)
            case 4:
                rect(0, -2.6, 6.6, 3.6, UIColor(white: 0.25, alpha: 1), 1.2)
                for sgn in [-1.0, 1.0] as [CGFloat] { ell(sgn * 2.4, -2.8, 1.5, 1.5, UIColor(white: 0.45, alpha: 1)) }
            case 5: rect(0, 0.9, 7.6, 2.4, UIColor(red: 0.85, green: 0.1, blue: 0.2, alpha: 1), 0.9)
                for sgn in [-1.0, 1.0] as [CGFloat] { ell(sgn * 1.85, 0.9, 1.9, 1.05, UIColor(white: 0.97, alpha: 1)); ell(sgn * 1.85, 0.9, 0.9, 0.9, eyeC) }
            case 6:
                UIColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: N, height: N))
                for sgn in [-1.0, 1.0] as [CGFloat] { ell(sgn * 1.85, 0.9, 2.6, 1.8, UIColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1)); ell(sgn * 1.85, 0.9, 1.7, 0.95, UIColor(white: 0.97, alpha: 1)); ell(sgn * 1.85, 0.9, 0.8, 0.8, eyeC) }
                rect(0, -2.5, 3.2, 1.2, UIColor(red: 0.95, green: 0.2, blue: 0.2, alpha: 1), 0.5)
            case 7:
                UIColor(white: 0.07, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: N, height: N))
                for sgn in [-1.0, 1.0] as [CGFloat] { ell(sgn * 1.85, 0.9, 2.2, 1.3, skin); ell(sgn * 1.85, 0.9, 1.7, 0.95, UIColor(white: 0.97, alpha: 1)); ell(sgn * 1.85, 0.9, 0.8, 0.8, eyeC) }
                rect(0, -2.5, 2.8, 1.0, skin, 0.5)
            default: break
            }
        }
    }
}
