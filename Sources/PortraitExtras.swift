import SwiftUI

struct PGeo {
    let w: CGFloat
    let ht: CGFloat
    let cx: Double
    let headX: Double
    let headY: Double
    let headW: Double
    let headH: Double
    let ey: Double
    var my: Double { ey + 0.14 }
    func R(_ x: Double, _ y: Double, _ ww: Double, _ hh: Double) -> CGRect { CGRect(x: w * x, y: ht * y, width: w * ww, height: ht * hh) }
    func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: w * x, y: ht * y) }
    var lw: CGFloat { max(1, w * 0.014) }
}

extension PortraitAvatar {
    static let eyeCols: [UInt32] = [0x141414, 0x4A2E1B, 0x2E6FE0, 0x2FA564, 0x8C8C92, 0xB26BFF, 0xE03A3A, 0xFFC93C, 0x00F0FF]
    static let lipCols: [UInt32] = [0xD94F6B, 0xB3262E, 0xF28AA0, 0x7A2E5C, 0x1B1B1B, 0xE8A07A, 0x8B5CF6]
    static let stickers: [String] = ["", "star.fill", "flame.fill", "crown.fill", "diamond.fill", "skull.fill", "bolt.fill", "heart.fill", "rainbow", "moon.stars.fill", "headphones", "paperplane.fill"]

    static func glyph(_ ctx: GraphicsContext, _ name: String, at p: CGPoint, size: CGFloat, color: Color) {
        let n = UIImage(systemName: name) != nil ? name : "star.fill"
        var im = ctx.resolve(Image(systemName: n))
        im.shading = .color(color)
        ctx.draw(im, in: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size))
    }

    static func c(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }

    private static func clipHead(_ ctx: GraphicsContext, _ g: PGeo) -> GraphicsContext {
        var k = ctx
        k.clip(to: Path(ellipseIn: g.R(g.headX, g.headY, g.headW, g.headH)))
        return k
    }

    private static func dome(_ ctx: GraphicsContext, _ g: PGeo, _ hair: Color, bump: Double = 0.005, ctrl: Double = 0.10) {
        var p = Path()
        p.addArc(center: g.P(g.cx, g.headY + 0.20), radius: g.w * (g.headW / 2 + bump), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.addQuadCurve(to: g.P(g.cx - g.headW / 2, g.headY + 0.20), control: g.P(g.cx, g.headY + ctrl))
        ctx.fill(p, with: .color(hair))
    }

    private static func tri(_ a: CGPoint, _ b: CGPoint, _ d: CGPoint) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b); p.addLine(to: d); p.closeSubpath(); return p
    }

    // MARK: hair

    static func hairBehindExtra(_ ctx: GraphicsContext, _ g: PGeo, _ style: Int, _ hair: Color) {
        switch style {
        case 11:
            ctx.fill(Path(ellipseIn: g.R(g.cx + 0.12, g.headY + 0.08, 0.14, 0.34)), with: .color(hair))
        case 12:
            ctx.fill(Path(roundedRect: g.R(g.headX - 0.04, g.headY + 0.12, 0.07, 0.52), cornerRadius: g.w * 0.03), with: .color(hair))
            ctx.fill(Path(roundedRect: g.R(g.headX + g.headW - 0.03, g.headY + 0.12, 0.07, 0.52), cornerRadius: g.w * 0.03), with: .color(hair))
        case 16:
            ctx.fill(Path(roundedRect: g.R(g.headX - 0.02, g.headY + 0.15, g.headW + 0.04, 0.42), cornerRadius: g.w * 0.08), with: .color(hair))
        case 17:
            ctx.fill(Path(ellipseIn: g.R(g.headX - 0.09, g.headY + 0.12, 0.12, 0.36)), with: .color(hair))
            ctx.fill(Path(ellipseIn: g.R(g.headX + g.headW - 0.03, g.headY + 0.12, 0.12, 0.36)), with: .color(hair))
        case 19:
            ctx.fill(Path(ellipseIn: g.R(g.headX - 0.02, g.headY - 0.10, 0.15, 0.15)), with: .color(hair))
            ctx.fill(Path(ellipseIn: g.R(g.headX + g.headW - 0.13, g.headY - 0.10, 0.15, 0.15)), with: .color(hair))
        default: break
        }
    }

    static func hairFrontExtra(_ ctx: GraphicsContext, _ g: PGeo, _ style: Int, _ hair: Color) {
        switch style {
        case 10:
            ctx.fill(Path(roundedRect: g.R(g.cx - 0.04, g.headY - 0.14, 0.08, 0.24), cornerRadius: g.w * 0.03), with: .color(hair))
        case 11, 16, 17, 19:
            dome(ctx, g, hair)
        case 12:
            dome(ctx, g, hair, bump: 0.01)
            var part = Path(); part.move(to: g.P(g.cx, g.headY + 0.01)); part.addLine(to: g.P(g.cx, g.headY + 0.12))
            ctx.stroke(part, with: .color(Color.black.opacity(0.35)), lineWidth: g.lw)
        case 13:
            dome(ctx, g, hair)
            for k in 0..<7 {
                let x = g.cx - 0.17 + Double(k) * 0.057
                let y = g.headY + 0.03 - 0.05 * sin(Double(k) / 6.0 * Double.pi)
                ctx.fill(Path(ellipseIn: g.R(x - 0.055, y - 0.05, 0.11, 0.11)), with: .color(hair))
            }
        case 14:
            dome(ctx, g, hair)
            var part = Path(); part.move(to: g.P(g.cx - 0.06, g.headY + 0.02)); part.addLine(to: g.P(g.cx - 0.10, g.headY + 0.13))
            ctx.stroke(part, with: .color(Color.black.opacity(0.35)), lineWidth: g.lw)
        case 15:
            dome(ctx, g, hair)
            for k in 0..<5 {
                let x = g.cx - 0.15 + 0.075 * Double(k)
                let tip = g.headY - 0.09 - (k == 2 ? 0.03 : 0.0)
                ctx.fill(tri(g.P(x - 0.04, g.headY + 0.07), g.P(x, tip), g.P(x + 0.04, g.headY + 0.07)), with: .color(hair))
            }
        case 18:
            ctx.fill(Path(roundedRect: g.R(g.headX + 0.03, g.headY - 0.015, g.headW - 0.06, 0.12), cornerRadius: g.w * 0.05), with: .color(hair))
        default: break
        }
    }

    static func hairExtras(_ ctx: GraphicsContext, _ g: PGeo, _ lk: AvatarLook, _ style: Int) {
        if let s = lk.streak, style != 9 {
            var p = Path()
            p.move(to: g.P(g.cx - 0.10, g.headY + 0.10))
            p.addQuadCurve(to: g.P(g.cx + 0.02, g.headY + 0.025), control: g.P(g.cx - 0.06, g.headY - 0.01))
            ctx.stroke(p, with: .color(c(hairs[s % hairs.count])), style: StrokeStyle(lineWidth: g.w * 0.035, lineCap: .round))
        }
        let acc = c(paints[(lk.accent ?? 0) % paints.count])
        switch lk.hairAcc ?? 0 {
        case 1: // bow
            ctx.fill(tri(g.P(g.cx + 0.13, g.headY + 0.04), g.P(g.cx + 0.22, g.headY - 0.02), g.P(g.cx + 0.22, g.headY + 0.10)), with: .color(acc))
            ctx.fill(tri(g.P(g.cx + 0.13, g.headY + 0.04), g.P(g.cx + 0.04, g.headY - 0.02), g.P(g.cx + 0.04, g.headY + 0.10)), with: .color(acc))
            ctx.fill(Path(ellipseIn: g.R(g.cx + 0.105, g.headY + 0.015, 0.05, 0.05)), with: .color(c(0xFFFFFF).opacity(0.85)))
        case 2: // clips
            ctx.fill(Path(roundedRect: g.R(g.cx - 0.17, g.headY + 0.07, 0.07, 0.022), cornerRadius: g.w * 0.01), with: .color(acc))
            ctx.fill(Path(roundedRect: g.R(g.cx - 0.15, g.headY + 0.105, 0.07, 0.022), cornerRadius: g.w * 0.01), with: .color(acc))
        case 3: // scrunchie
            ctx.fill(Path(ellipseIn: g.R(g.cx + 0.12, g.headY + 0.06, 0.10, 0.07)), with: .color(acc))
            ctx.stroke(Path(ellipseIn: g.R(g.cx + 0.12, g.headY + 0.06, 0.10, 0.07)), with: .color(Color.white.opacity(0.35)), lineWidth: g.lw * 0.6)
        case 4: // flower
            for k in 0..<5 {
                let a = Double(k) / 5.0 * 2 * Double.pi
                let px = g.cx - 0.13 + 0.035 * cos(a), py = g.headY + 0.05 + 0.035 * sin(a)
                ctx.fill(Path(ellipseIn: g.R(px - 0.025, py - 0.025, 0.05, 0.05)), with: .color(acc))
            }
            ctx.fill(Path(ellipseIn: g.R(g.cx - 0.153, g.headY + 0.027, 0.046, 0.046)), with: .color(c(0xFFD23F)))
        default: break
        }
    }

    // MARK: outfits & neckwear

    static func outfitExtra(_ ctx: GraphicsContext, _ g: PGeo, _ outfit: Int, _ topV: UInt32, _ skinV: UInt32) {
        let w = g.w, ht = g.ht, cx = g.cx
        switch outfit {
        case 8: // overalls
            let denim = c(0x3B6FB6)
            ctx.fill(Path(roundedRect: g.R(cx - 0.14, 0.76, 0.05, 0.24), cornerRadius: w * 0.02), with: .color(denim))
            ctx.fill(Path(roundedRect: g.R(cx + 0.09, 0.76, 0.05, 0.24), cornerRadius: w * 0.02), with: .color(denim))
            ctx.fill(Path(roundedRect: g.R(cx - 0.12, 0.88, 0.24, 0.14), cornerRadius: w * 0.03), with: .color(denim))
            ctx.fill(Path(ellipseIn: g.R(cx - 0.125, 0.885, 0.025, 0.025)), with: .color(c(0xFFD23F)))
            ctx.fill(Path(ellipseIn: g.R(cx + 0.10, 0.885, 0.025, 0.025)), with: .color(c(0xFFD23F)))
        case 9: // hawaiian
            var v = Path(); v.move(to: g.P(cx - 0.09, 0.74)); v.addLine(to: g.P(cx, 0.90)); v.addLine(to: g.P(cx + 0.09, 0.74)); v.closeSubpath()
            ctx.fill(v, with: .color(c(skinV).opacity(0.92)))
            let dots: [(Double, Double, UInt32)] = [(0.22, 0.82, 0xFF4FA3), (0.30, 0.92, 0xFFD23F), (0.72, 0.84, 0xFFD23F), (0.80, 0.94, 0xFF4FA3), (0.15, 0.95, 0xFFFFFF), (0.62, 0.95, 0xFFFFFF)]
            for d in dots { ctx.fill(Path(ellipseIn: g.R(d.0 - 0.03, d.1 - 0.03, 0.06, 0.06)), with: .color(c(d.2).opacity(0.9))) }
        case 10: // armor
            ctx.fill(Path(ellipseIn: g.R(cx - 0.21, 0.73, 0.42, 0.26)), with: .color(c(0x9CA3AF)))
            ctx.stroke(Path(ellipseIn: g.R(cx - 0.21, 0.73, 0.42, 0.26)), with: .color(c(0x4B5563)), lineWidth: g.lw)
            for k in 0..<4 {
                ctx.fill(Path(ellipseIn: g.R(cx - 0.12 + Double(k) * 0.08, 0.80, 0.016, 0.016)), with: .color(c(0xE5E7EB)))
            }
            var l = Path(); l.move(to: g.P(cx, 0.76)); l.addLine(to: g.P(cx, 0.98))
            ctx.stroke(l, with: .color(c(0x4B5563)), lineWidth: g.lw)
        case 11: // lab coat
            ctx.fill(Path(ellipseIn: g.R(0.10, 0.75, 0.80, 0.55)), with: .color(Color.white.opacity(0.96)))
            var l = Path(); l.move(to: g.P(cx - 0.05, 0.75)); l.addLine(to: g.P(cx - 0.02, 0.99)); l.move(to: g.P(cx + 0.05, 0.75)); l.addLine(to: g.P(cx + 0.02, 0.99))
            ctx.stroke(l, with: .color(Color.gray.opacity(0.7)), lineWidth: g.lw)
            ctx.fill(Path(roundedRect: g.R(cx + 0.09, 0.88, 0.09, 0.07), cornerRadius: w * 0.01), with: .color(Color.gray.opacity(0.25)))
        case 12: // varsity
            var s = Path(); s.addArc(center: g.P(0.5, 1.05), radius: w * 0.44, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            ctx.stroke(s, with: .color(Color.white.opacity(0.9)), lineWidth: max(2, w * 0.03))
            ctx.draw(Text("V").font(.system(size: w * 0.13, weight: .black)).foregroundColor(Color.white.opacity(0.92)), at: CGPoint(x: w * 0.5, y: ht * 0.9))
        case 13: // kimono
            var l = Path(); l.move(to: g.P(cx - 0.11, 0.73)); l.addLine(to: g.P(cx + 0.03, 0.99))
            l.move(to: g.P(cx + 0.11, 0.73)); l.addLine(to: g.P(cx - 0.03, 0.99))
            ctx.stroke(l, with: .color(c(0xF5E6C8)), lineWidth: max(2, w * 0.03))
            ctx.fill(Path(CGRect(x: w * 0.1, y: ht * 0.94, width: w * 0.8, height: ht * 0.05)), with: .color(c(0xD62E3A)))
        default: break
        }
    }

    static func neckwear(_ ctx: GraphicsContext, _ g: PGeo, _ kind: Int, _ acc: Color) {
        let cx = g.cx
        switch kind {
        case 1: // scarf
            ctx.fill(Path(roundedRect: g.R(cx - 0.16, 0.69, 0.32, 0.075), cornerRadius: g.w * 0.035), with: .color(acc))
            ctx.fill(Path(roundedRect: g.R(cx + 0.05, 0.74, 0.07, 0.19), cornerRadius: g.w * 0.02), with: .color(acc.opacity(0.85)))
            var st = Path(); st.move(to: g.P(cx + 0.065, 0.78)); st.addLine(to: g.P(cx + 0.065, 0.92))
            ctx.stroke(st, with: .color(Color.white.opacity(0.35)), lineWidth: g.lw * 0.6)
        case 2: // bow tie
            ctx.fill(tri(g.P(cx, 0.77), g.P(cx - 0.08, 0.73), g.P(cx - 0.08, 0.81)), with: .color(acc))
            ctx.fill(tri(g.P(cx, 0.77), g.P(cx + 0.08, 0.73), g.P(cx + 0.08, 0.81)), with: .color(acc))
            ctx.fill(Path(ellipseIn: g.R(cx - 0.02, 0.75, 0.04, 0.04)), with: .color(acc.opacity(0.7)))
        case 3: // bandana
            ctx.fill(tri(g.P(cx - 0.16, 0.69), g.P(cx + 0.16, 0.69), g.P(cx, 0.86)), with: .color(acc))
            for d in [(-0.06, 0.74), (0.05, 0.74), (0.0, 0.80)] {
                ctx.fill(Path(ellipseIn: g.R(cx + d.0 - 0.012, d.1 - 0.012, 0.024, 0.024)), with: .color(Color.white.opacity(0.85)))
            }
        default: break
        }
    }

    // MARK: face

    static func brow(_ ctx: GraphicsContext, _ g: PGeo, _ x: Double, _ kind: Int, _ color: Color) {
        if kind == 4 { return }
        let side: Double = x < g.cx ? -1 : 1
        let y = g.ey - 0.03
        var b = Path()
        var wd = max(0.8, g.w * 0.014)
        switch kind {
        case 1: // thick
            b.move(to: g.P(x - 0.035, y)); b.addLine(to: g.P(x + 0.035, y - 0.005)); wd *= 2.4
        case 2: // angry
            b.move(to: g.P(x - 0.035, y + 0.012 * side)); b.addLine(to: g.P(x + 0.035, y - 0.012 * side)); wd *= 1.7
        case 3: // raised
            b.move(to: g.P(x - 0.035, y - 0.005)); b.addQuadCurve(to: g.P(x + 0.035, y - 0.005), control: g.P(x, y - 0.03))
        default:
            b.move(to: g.P(x - 0.035, y)); b.addLine(to: g.P(x + 0.035, y - 0.005))
        }
        ctx.stroke(b, with: .color(color), style: StrokeStyle(lineWidth: wd, lineCap: .round))
    }

    static func lashes(_ ctx: GraphicsContext, _ g: PGeo, _ x: Double) {
        var p = Path()
        let side: Double = x < g.cx ? -1 : 1
        for k in 0..<3 {
            let dx = Double(k) * 0.014 * side - 0.005 * side
            p.move(to: g.P(x + dx, g.ey + 0.002)); p.addLine(to: g.P(x + dx + 0.012 * side, g.ey - 0.016))
        }
        ctx.stroke(p, with: .color(Color.black.opacity(0.85)), style: StrokeStyle(lineWidth: max(0.8, g.w * 0.008), lineCap: .round))
    }

    static func noseDraw(_ ctx: GraphicsContext, _ g: PGeo, _ kind: Int, _ col: Color) {
        let cx = g.cx, ey = g.ey
        switch kind {
        case 1: // button
            ctx.fill(Path(ellipseIn: g.R(cx - 0.018, ey + 0.065, 0.036, 0.032)), with: .color(col.opacity(0.7)))
        case 2: // wide
            var p = Path(); p.move(to: g.P(cx - 0.035, ey + 0.09)); p.addQuadCurve(to: g.P(cx + 0.035, ey + 0.09), control: g.P(cx, ey + 0.115))
            ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: max(0.8, g.w * 0.012), lineCap: .round))
            ctx.fill(Path(ellipseIn: g.R(cx - 0.028, ey + 0.085, 0.012, 0.012)), with: .color(col))
            ctx.fill(Path(ellipseIn: g.R(cx + 0.016, ey + 0.085, 0.012, 0.012)), with: .color(col))
        default: // pointed
            var p = Path(); p.move(to: g.P(cx - 0.004, ey + 0.02)); p.addLine(to: g.P(cx + 0.02, ey + 0.095)); p.addLine(to: g.P(cx - 0.015, ey + 0.095))
            ctx.stroke(p, with: .color(col), style: StrokeStyle(lineWidth: max(0.8, g.w * 0.012), lineCap: .round, lineJoin: .round))
        }
    }

    static func lips(_ ctx: GraphicsContext, _ g: PGeo, _ idx: Int) {
        ctx.fill(Path(ellipseIn: g.R(g.cx - 0.058, g.my - 0.014, 0.116, 0.042)), with: .color(c(lipCols[idx % lipCols.count]).opacity(0.92)))
    }

    static func facialHair(_ ctx: GraphicsContext, _ g: PGeo, _ kind: Int, _ color: Color) {
        if kind == 0 { return }
        let cx = g.cx, my = g.my
        let k = clipHead(ctx, g)
        func stache() {
            ctx.fill(Path(ellipseIn: g.R(cx - 0.075, my - 0.045, 0.075, 0.032)), with: .color(color))
            ctx.fill(Path(ellipseIn: g.R(cx, my - 0.045, 0.075, 0.032)), with: .color(color))
        }
        switch kind {
        case 1: // stubble
            for i in 0..<46 {
                let x = g.headX + 0.04 + frac(Double(i) * 0.6180339) * (g.headW - 0.08)
                let y = my - 0.05 + frac(Double(i) * 0.7548776) * 0.22
                k.fill(Path(ellipseIn: g.R(x, y, 0.009, 0.009)), with: .color(color.opacity(0.5)))
            }
        case 2: stache()
        case 3:
            stache()
            k.fill(Path(ellipseIn: g.R(cx - 0.05, my + 0.01, 0.10, 0.10)), with: .color(color))
        case 4:
            k.fill(Path(ellipseIn: g.R(g.headX - 0.01, my - 0.075, g.headW + 0.02, 0.32)), with: .color(color))
        case 5:
            k.fill(Path(ellipseIn: g.R(cx - 0.018, my + 0.025, 0.036, 0.04)), with: .color(color))
        case 6: // handlebar
            stache()
            var cu = Path()
            cu.move(to: g.P(cx - 0.07, my - 0.03)); cu.addQuadCurve(to: g.P(cx - 0.125, my - 0.065), control: g.P(cx - 0.12, my - 0.01))
            cu.move(to: g.P(cx + 0.07, my - 0.03)); cu.addQuadCurve(to: g.P(cx + 0.125, my - 0.065), control: g.P(cx + 0.12, my - 0.01))
            ctx.stroke(cu, with: .color(color), style: StrokeStyle(lineWidth: g.w * 0.018, lineCap: .round))
        default: // chinstrap
            var j = Path()
            j.addArc(center: g.P(cx, g.headY + g.headH * 0.5), radius: g.w * (g.headW / 2 - 0.005), startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            k.stroke(j, with: .color(color), lineWidth: g.w * 0.035)
        }
    }

    static func faceDetails(_ ctx: GraphicsContext, _ g: PGeo, _ lk: AvatarLook, _ skinV: UInt32) {
        let cx = g.cx, ey = g.ey
        let dark = c(skinV).opacity(0.55)
        if lk.freckles == true {
            let pts: [(Double, Double)] = [(-0.16, 0.07), (-0.13, 0.095), (-0.105, 0.065), (-0.14, 0.055), (0.16, 0.07), (0.13, 0.095), (0.105, 0.065), (0.14, 0.055), (-0.02, 0.05), (0.02, 0.05)]
            for p in pts { ctx.fill(Path(ellipseIn: g.R(cx + p.0, ey + p.1, 0.010, 0.010)), with: .color(Color(red: 0.55, green: 0.3, blue: 0.18).opacity(0.85))) }
        }
        switch lk.mole ?? 0 {
        case 1: ctx.fill(Path(ellipseIn: g.R(cx + 0.13, ey + 0.09, 0.014, 0.014)), with: .color(Color.black.opacity(0.7)))
        case 2: ctx.fill(Path(ellipseIn: g.R(cx + 0.05, g.my + 0.004, 0.012, 0.012)), with: .color(Color.black.opacity(0.7)))
        case 3: ctx.fill(Path(ellipseIn: g.R(cx - 0.11, ey - 0.06, 0.012, 0.012)), with: .color(Color.black.opacity(0.7)))
        default: break
        }
        switch lk.scar ?? 0 {
        case 1:
            var s = Path(); s.move(to: g.P(cx - 0.105, ey - 0.075)); s.addLine(to: g.P(cx - 0.065, ey + 0.075))
            ctx.stroke(s, with: .color(Color(red: 0.62, green: 0.25, blue: 0.25).opacity(0.9)), style: StrokeStyle(lineWidth: g.w * 0.011, lineCap: .round))
            var t = Path()
            for i in 0..<3 {
                let y = ey - 0.04 + Double(i) * 0.04
                t.move(to: g.P(cx - 0.11 + Double(i) * 0.008, y)); t.addLine(to: g.P(cx - 0.07 + Double(i) * 0.008, y))
            }
            ctx.stroke(t, with: .color(dark), lineWidth: max(0.6, g.w * 0.006))
        case 2:
            var s = Path(); s.move(to: g.P(cx + 0.06, ey + 0.05)); s.addLine(to: g.P(cx + 0.17, ey + 0.14))
            ctx.stroke(s, with: .color(Color(red: 0.62, green: 0.25, blue: 0.25).opacity(0.9)), style: StrokeStyle(lineWidth: g.w * 0.011, lineCap: .round))
        default: break
        }
    }

    static func drawMask(_ ctx: GraphicsContext, _ g: PGeo, _ kind: Int, _ acc: Color, _ skin: Color) {
        if kind == 0 { return }
        let cx = g.cx, ey = g.ey
        let k = clipHead(ctx, g)
        let wide = Path(ellipseIn: g.R(g.headX - 0.012, g.headY - 0.03, g.headW + 0.024, g.headH + 0.045))
        func eyeHole(_ side: Double, _ r: Double) {
            let ex = cx + side * 0.085
            ctx.fill(Path(ellipseIn: g.R(ex - r, ey - r * 0.75, r * 2, r * 1.5)), with: .color(skin))
            ctx.fill(Path(ellipseIn: g.R(ex - 0.03, ey - 0.012, 0.06, 0.05)), with: .color(Color.white))
            ctx.fill(Path(ellipseIn: g.R(ex - 0.014, ey - 0.004, 0.028, 0.034)), with: .color(Color(white: 0.08)))
        }
        switch kind {
        case 1: // surgical
            var loops = Path(); loops.move(to: g.P(cx - 0.17, ey + 0.09)); loops.addLine(to: g.P(g.headX - 0.01, g.headY + 0.27))
            loops.move(to: g.P(cx + 0.17, ey + 0.09)); loops.addLine(to: g.P(g.headX + g.headW + 0.01, g.headY + 0.27))
            ctx.stroke(loops, with: .color(Color.white.opacity(0.8)), lineWidth: g.lw * 0.7)
            ctx.fill(Path(roundedRect: g.R(cx - 0.17, ey + 0.065, 0.34, 0.19), cornerRadius: g.w * 0.03), with: .color(c(0xBFE3F5)))
            var p = Path()
            for i in 0..<3 { let y = ey + 0.10 + Double(i) * 0.05; p.move(to: g.P(cx - 0.15, y)); p.addLine(to: g.P(cx + 0.15, y)) }
            ctx.stroke(p, with: .color(c(0x8EC5E3)), lineWidth: g.lw * 0.7)
        case 2: // ninja wrap
            k.fill(Path(roundedRect: g.R(g.headX - 0.01, ey + 0.06, g.headW + 0.02, 0.30), cornerRadius: g.w * 0.02), with: .color(c(0x16161D)))
            k.fill(Path(CGRect(x: g.w * g.headX, y: g.ht * (ey + 0.062), width: g.w * g.headW, height: g.ht * 0.012)), with: .color(Color.white.opacity(0.18)))
        case 3: // bandana
            k.fill(Path(roundedRect: g.R(g.headX - 0.01, ey + 0.06, g.headW + 0.02, 0.30), cornerRadius: g.w * 0.02), with: .color(c(0xD62E3A)))
            for d in [(-0.09, 0.12), (0.0, 0.17), (0.09, 0.12), (-0.05, 0.22), (0.06, 0.22)] {
                k.fill(Path(ellipseIn: g.R(cx + d.0, ey + d.1, 0.02, 0.02)), with: .color(Color.white.opacity(0.85)))
            }
        case 4: // respirator
            k.fill(Path(roundedRect: g.R(g.headX - 0.01, ey + 0.065, g.headW + 0.02, 0.30), cornerRadius: g.w * 0.03), with: .color(c(0x1D1F27)))
            for i in 0..<4 {
                k.fill(Path(roundedRect: g.R(cx - 0.09 + Double(i) * 0.05, ey + 0.11, 0.016, 0.10), cornerRadius: g.w * 0.006), with: .color(c(0x00F0FF)))
            }
        case 5: // full hero mask (covers the hair too)
            ctx.fill(wide, with: .color(acc))
            var web = ctx
            web.clip(to: wide)
            var lines = Path()
            for i in 0..<9 {
                let a = Double(i - 4) * 0.22
                lines.move(to: g.P(cx, g.headY + 0.03)); lines.addLine(to: g.P(cx + 0.45 * sin(a), g.headY + 0.03 + 0.62 * cos(a)))
            }
            for r in [0.07, 0.14, 0.22, 0.31] {
                let y = g.headY + 0.03 + r
                lines.move(to: g.P(cx - 0.3, y)); lines.addQuadCurve(to: g.P(cx + 0.3, y), control: g.P(cx, y + 0.07))
            }
            web.stroke(lines, with: .color(Color.black.opacity(0.55)), lineWidth: max(0.6, g.w * 0.0065))
            for side in [-1.0, 1.0] {
                let ex = cx + side * 0.085
                var lens = Path()
                lens.move(to: g.P(ex + side * 0.065, ey - 0.03)); lens.addLine(to: g.P(ex + side * 0.01, ey - 0.04)); lens.addLine(to: g.P(ex - side * 0.055, ey + 0.0))
                lens.addLine(to: g.P(ex - side * 0.05, ey + 0.04)); lens.addLine(to: g.P(ex + side * 0.02, ey + 0.047)); lens.addLine(to: g.P(ex + side * 0.065, ey + 0.012)); lens.closeSubpath()
                ctx.fill(lens, with: .color(Color.white.opacity(0.96)))
                ctx.stroke(lens, with: .color(Color.black.opacity(0.9)), style: StrokeStyle(lineWidth: max(1, g.w * 0.012), lineJoin: .round))
            }
            ctx.stroke(wide, with: .color(Color.black.opacity(0.35)), lineWidth: g.lw * 0.8)
        case 6: // luchador
            ctx.fill(wide, with: .color(acc))
            for side in [-1.0, 1.0] {
                let ex = cx + side * 0.085
                let st = starPath(g.P(ex, ey), g.w * 0.115, 0.5)
                ctx.fill(st, with: .color(Color.white.opacity(0.92)))
                ctx.stroke(st, with: .color(Color.black.opacity(0.5)), lineWidth: g.lw * 0.7)
            }
            for side in [-1.0, 1.0] { eyeHole(side, 0.05) }
            ctx.fill(Path(ellipseIn: g.R(cx - 0.065, g.my - 0.025, 0.13, 0.065)), with: .color(skin))
            ctx.stroke(Path(ellipseIn: g.R(cx - 0.065, g.my - 0.025, 0.13, 0.065)), with: .color(Color.white), lineWidth: g.lw)
            ctx.stroke(wide, with: .color(Color.white.opacity(0.85)), lineWidth: g.lw * 1.4)
        default: // ski mask
            ctx.fill(wide, with: .color(c(0x2B2B33)))
            var knit = Path()
            var x = g.headX + 0.01
            while x < g.headX + g.headW { knit.move(to: g.P(x, g.headY)); knit.addLine(to: g.P(x, g.headY + g.headH)); x += 0.018 }
            k.stroke(knit, with: .color(Color.white.opacity(0.07)), lineWidth: max(0.5, g.w * 0.005))
            ctx.fill(Path(roundedRect: g.R(cx - 0.17, ey - 0.04, 0.34, 0.095), cornerRadius: g.w * 0.04), with: .color(skin))
            for side in [-1.0, 1.0] {
                let ex = cx + side * 0.085
                ctx.fill(Path(ellipseIn: g.R(ex - 0.03, ey - 0.012, 0.06, 0.05)), with: .color(Color.white))
                ctx.fill(Path(ellipseIn: g.R(ex - 0.014, ey - 0.004, 0.028, 0.034)), with: .color(Color(white: 0.08)))
            }
            ctx.fill(Path(ellipseIn: g.R(cx - 0.05, g.my - 0.02, 0.10, 0.055)), with: .color(skin))
            ctx.fill(Path(roundedRect: g.R(g.headX - 0.012, ey + 0.2, g.headW + 0.024, 0.04), cornerRadius: g.w * 0.02), with: .color(c(0x2B2B33)))
        }
    }

    // MARK: necklaces

    static let metals: [UInt32] = [0xFFD23F, 0xD1D5DB, 0xE8A090, 0x1B1B1B, 0x00F0FF]

    static func necklace(_ ctx: GraphicsContext, _ g: PGeo, _ kind: Int, _ metal: Int, _ acc: Color) {
        if kind <= 0 { return }
        let m = c(metals[metal % metals.count])
        let cx = g.cx, w = g.w
        func arc(_ depth: Double, _ y0: Double, _ half: Double) -> Path {
            var p = Path()
            p.move(to: g.P(cx - half, y0)); p.addQuadCurve(to: g.P(cx + half, y0), control: g.P(cx, y0 + depth * 2))
            return p
        }
        func onArc(_ t: Double, _ depth: Double, _ y0: Double, _ half: Double) -> CGPoint {
            let x = (1 - t) * (1 - t) * (cx - half) + 2 * (1 - t) * t * cx + t * t * (cx + half)
            let y = (1 - t) * (1 - t) * y0 + 2 * (1 - t) * t * (y0 + depth * 2) + t * t * y0
            return g.P(x, y)
        }
        let round = StrokeStyle(lineWidth: max(1, w * 0.01), lineCap: .round)
        switch kind {
        case 1: // thin chain
            ctx.stroke(arc(0.12, 0.70, 0.085), with: .color(m), style: round)
        case 2: // cuban link
            ctx.stroke(arc(0.11, 0.70, 0.09), with: .color(m), style: StrokeStyle(lineWidth: w * 0.022, lineCap: .butt, dash: [w * 0.02, w * 0.005]))
            ctx.stroke(arc(0.11, 0.70, 0.09), with: .color(Color.white.opacity(0.4)), style: StrokeStyle(lineWidth: w * 0.006, lineCap: .butt, dash: [w * 0.02, w * 0.005]))
        case 3: // layered: three chains and a pendant
            ctx.stroke(arc(0.07, 0.70, 0.075), with: .color(m), style: StrokeStyle(lineWidth: max(0.8, w * 0.007), lineCap: .round))
            ctx.stroke(arc(0.13, 0.70, 0.09), with: .color(m), style: StrokeStyle(lineWidth: w * 0.014, lineCap: .butt, dash: [w * 0.014, w * 0.004]))
            ctx.stroke(arc(0.20, 0.70, 0.10), with: .color(m), style: round)
            ctx.fill(Path(ellipseIn: g.R(cx - 0.022, 0.70 + 0.20 - 0.005, 0.044, 0.044)), with: .color(acc))
            ctx.stroke(Path(ellipseIn: g.R(cx - 0.022, 0.70 + 0.20 - 0.005, 0.044, 0.044)), with: .color(m), lineWidth: max(0.8, w * 0.008))
        case 4: // pearls
            for i in 0...10 {
                let pt = onArc(Double(i) / 10.0, 0.12, 0.70, 0.09)
                let r = w * 0.015
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(Color(white: 0.96)))
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r * 0.4, y: pt.y - r * 0.6, width: r * 0.6, height: r * 0.6)), with: .color(Color.white))
            }
        case 5, 6: // choker, optionally with a pendant
            var band = Path()
            band.move(to: g.P(cx - 0.08, 0.668)); band.addQuadCurve(to: g.P(cx + 0.08, 0.668), control: g.P(cx, 0.73))
            ctx.stroke(band, with: .color(Color(white: 0.07)), style: StrokeStyle(lineWidth: w * 0.022, lineCap: .round))
            ctx.stroke(band, with: .color(Color.white.opacity(0.12)), style: StrokeStyle(lineWidth: w * 0.005, lineCap: .round))
            ctx.stroke(Path(ellipseIn: g.R(cx - 0.012, 0.699, 0.024, 0.024)), with: .color(m), lineWidth: max(0.8, w * 0.008))
            if kind == 6 {
                ctx.fill(Path(ellipseIn: g.R(cx - 0.02, 0.725, 0.04, 0.04)), with: .color(acc))
                ctx.stroke(Path(ellipseIn: g.R(cx - 0.02, 0.725, 0.04, 0.04)), with: .color(m), lineWidth: max(0.8, w * 0.008))
            }
        case 7: // dog tags
            ctx.stroke(arc(0.15, 0.70, 0.09), with: .color(m), style: StrokeStyle(lineWidth: max(0.8, w * 0.008), lineCap: .butt, dash: [w * 0.008, w * 0.004]))
            for (i, off) in [0.0, 0.016].enumerated() {
                let tag = Path(roundedRect: g.R(cx - 0.025 + off, 0.835 + off * 1.5, 0.05, 0.08), cornerRadius: w * 0.014)
                ctx.fill(tag, with: .color(i == 0 ? m.opacity(0.85) : m))
                ctx.stroke(tag, with: .color(Color.black.opacity(0.4)), lineWidth: max(0.6, w * 0.005))
            }
        case 8: // cross pendant
            ctx.stroke(arc(0.12, 0.70, 0.085), with: .color(m), style: round)
            ctx.fill(Path(roundedRect: g.R(cx - 0.007, 0.80, 0.014, 0.075), cornerRadius: w * 0.003), with: .color(m))
            ctx.fill(Path(roundedRect: g.R(cx - 0.025, 0.815, 0.05, 0.014), cornerRadius: w * 0.003), with: .color(m))
        default: // bead necklace
            for i in 0...8 {
                let pt = onArc(Double(i) / 8.0, 0.12, 0.70, 0.09)
                let r = w * 0.017
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(i % 2 == 0 ? acc : Color.white.opacity(0.92)))
            }
        }
    }

    // MARK: face paint (drawn on the skin before hair and eyes, always clipped to the head)

    private static func starPath(_ c: CGPoint, _ r: CGFloat, _ inner: CGFloat = 0.45) -> Path {
        var p = Path()
        for i in 0..<10 {
            let a = Double(i) * Double.pi / 5.0 - Double.pi / 2.0
            let rr = i % 2 == 0 ? r : r * inner
            let pt = CGPoint(x: c.x + rr * CGFloat(cos(a)), y: c.y + rr * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private static func heartPath(_ c: CGPoint, _ s: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + s * 0.9))
        p.addCurve(to: CGPoint(x: c.x - s, y: c.y - s * 0.1), control1: CGPoint(x: c.x - s * 0.4, y: c.y + s * 0.6), control2: CGPoint(x: c.x - s, y: c.y + s * 0.3))
        p.addCurve(to: CGPoint(x: c.x, y: c.y - s * 0.3), control1: CGPoint(x: c.x - s, y: c.y - s * 0.8), control2: CGPoint(x: c.x - s * 0.1, y: c.y - s * 0.8))
        p.addCurve(to: CGPoint(x: c.x + s, y: c.y - s * 0.1), control1: CGPoint(x: c.x + s * 0.1, y: c.y - s * 0.8), control2: CGPoint(x: c.x + s, y: c.y - s * 0.8))
        p.addCurve(to: CGPoint(x: c.x, y: c.y + s * 0.9), control1: CGPoint(x: c.x + s, y: c.y + s * 0.3), control2: CGPoint(x: c.x + s * 0.4, y: c.y + s * 0.6))
        p.closeSubpath()
        return p
    }

    private static func taper(_ g: PGeo, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ t0: Double, _ t1: Double) -> Path {
        var p = Path()
        p.move(to: g.P(x0, y0 - t0)); p.addLine(to: g.P(x1, y1 - t1)); p.addLine(to: g.P(x1, y1 + t1)); p.addLine(to: g.P(x0, y0 + t0)); p.closeSubpath()
        return p
    }

    static func drawPaint(_ ctx: GraphicsContext, _ g: PGeo, _ paint: Int, _ pc: Color, _ skinV: UInt32) {
        if paint <= 0 { return }
        let k = clipHead(ctx, g)
        let cx = g.cx, ey = g.ey, my = g.my
        let ink = Color(white: 0.08)
        let glow = Color.white.opacity(0.55)
        let lwThin = max(0.6, g.w * 0.007)
        switch paint {
        case 1: // war stripes, tapered, with a bone highlight
            for side in [-1.0, 1.0] {
                for i in 0..<3 {
                    let y = ey + 0.05 + Double(i) * 0.034
                    let path = taper(g, cx + side * 0.20, y + 0.012, cx + side * 0.085, y - 0.004, 0.011, 0.003)
                    k.fill(path, with: .color(pc))
                    var hl = Path(); hl.move(to: g.P(cx + side * 0.19, y + 0.002)); hl.addLine(to: g.P(cx + side * 0.10, y - 0.008))
                    k.stroke(hl, with: .color(Color.white.opacity(0.4)), lineWidth: lwThin)
                }
                for d in 0..<3 {
                    k.fill(Path(ellipseIn: g.R(cx + side * (0.075 + Double(d) * 0.03) - 0.005, ey + 0.165, 0.011, 0.011)), with: .color(pc))
                }
            }
        case 2: // star burst
            let big = starPath(g.P(cx - 0.16, ey + 0.065), g.w * 0.055)
            k.fill(big, with: .color(pc)); k.stroke(big, with: .color(glow), lineWidth: lwThin)
            let mid = starPath(g.P(cx + 0.155, ey + 0.095), g.w * 0.038)
            k.fill(mid, with: .color(pc)); k.stroke(mid, with: .color(glow), lineWidth: lwThin)
            let sm = starPath(g.P(cx - 0.115, ey + 0.135), g.w * 0.022)
            k.fill(sm, with: .color(pc.opacity(0.9)))
            for d in [(-0.20, 0.03), (-0.12, 0.02), (0.19, 0.06), (0.12, 0.15), (0.20, 0.13), (-0.19, 0.12)] {
                k.fill(Path(ellipseIn: g.R(cx + d.0, ey + d.1, 0.011, 0.011)), with: .color(Color.white.opacity(0.9)))
            }
        case 3: // lightning with glow, plus sparks
            var bolt = Path()
            bolt.move(to: g.P(cx + 0.15, ey - 0.13)); bolt.addLine(to: g.P(cx + 0.065, ey + 0.02)); bolt.addLine(to: g.P(cx + 0.11, ey + 0.02))
            bolt.addLine(to: g.P(cx + 0.045, ey + 0.14)); bolt.addLine(to: g.P(cx + 0.155, ey - 0.005)); bolt.addLine(to: g.P(cx + 0.105, ey - 0.005)); bolt.closeSubpath()
            k.stroke(bolt, with: .color(pc.opacity(0.35)), lineWidth: g.w * 0.03)
            k.fill(bolt, with: .color(pc)); k.stroke(bolt, with: .color(Color.white.opacity(0.7)), lineWidth: lwThin)
            var sp = Path()
            sp.move(to: g.P(cx - 0.17, ey + 0.05)); sp.addLine(to: g.P(cx - 0.14, ey + 0.085)); sp.addLine(to: g.P(cx - 0.16, ey + 0.085)); sp.addLine(to: g.P(cx - 0.13, ey + 0.13))
            k.stroke(sp, with: .color(pc), style: StrokeStyle(lineWidth: g.w * 0.012, lineCap: .round, lineJoin: .round))
        case 4: // tiger
            k.fill(Path(ellipseIn: g.R(cx - 0.22, ey + 0.03, 0.16, 0.15)), with: .color(pc.opacity(0.35)))
            k.fill(Path(ellipseIn: g.R(cx + 0.06, ey + 0.03, 0.16, 0.15)), with: .color(pc.opacity(0.35)))
            k.fill(Path(ellipseIn: g.R(cx - 0.085, my - 0.03, 0.08, 0.075)), with: .color(Color.white.opacity(0.9)))
            k.fill(Path(ellipseIn: g.R(cx + 0.005, my - 0.03, 0.08, 0.075)), with: .color(Color.white.opacity(0.9)))
            for side in [-1.0, 1.0] {
                for i in 0..<3 {
                    let y = ey + 0.06 + Double(i) * 0.035
                    k.fill(taper(g, cx + side * 0.22, y + 0.01, cx + side * 0.12, y - 0.008, 0.012, 0.003), with: .color(ink))
                }
            }
            for i in 0..<3 {
                let x = cx - 0.07 + Double(i) * 0.07
                k.fill(taper(g, x, g.headY + 0.035, x, g.headY + (i == 1 ? 0.15 : 0.11), 0.012, 0.003), with: .color(ink))
            }
            k.fill(tri(g.P(cx - 0.02, ey + 0.07), g.P(cx + 0.02, ey + 0.07), g.P(cx, ey + 0.095)), with: .color(Color(red: 0.95, green: 0.5, blue: 0.6)))
        case 5: // clown
            for side in [-1.0, 1.0] {
                k.fill(Path(ellipseIn: g.R(cx + side * 0.085 - 0.08, ey - 0.075, 0.16, 0.15)), with: .color(Color.white.opacity(0.94)))
                var dm = Path(); let ex = cx + side * 0.085
                dm.move(to: g.P(ex, ey - 0.10)); dm.addLine(to: g.P(ex + 0.025, ey - 0.065)); dm.addLine(to: g.P(ex, ey - 0.03)); dm.addLine(to: g.P(ex - 0.025, ey - 0.065)); dm.closeSubpath()
                k.fill(dm, with: .color(pc))
                var dn = Path()
                dn.move(to: g.P(ex, ey + 0.035)); dn.addLine(to: g.P(ex + 0.02, ey + 0.065)); dn.addLine(to: g.P(ex, ey + 0.095)); dn.addLine(to: g.P(ex - 0.02, ey + 0.065)); dn.closeSubpath()
                k.fill(dn, with: .color(pc.opacity(0.9)))
            }
            var smile = Path()
            smile.move(to: g.P(cx - 0.19, my - 0.04)); smile.addQuadCurve(to: g.P(cx + 0.19, my - 0.04), control: g.P(cx, my + 0.14))
            k.stroke(smile, with: .color(Color(red: 0.88, green: 0.1, blue: 0.2)), style: StrokeStyle(lineWidth: g.w * 0.03, lineCap: .round))
            k.fill(Path(ellipseIn: g.R(cx - 0.042, ey + 0.058, 0.084, 0.084)), with: .color(Color(red: 0.92, green: 0.12, blue: 0.22)))
            k.fill(Path(ellipseIn: g.R(cx - 0.022, ey + 0.068, 0.02, 0.02)), with: .color(Color.white.opacity(0.7)))
        case 6: // cyber circuitry
            for side in [-1.0, 1.0] {
                var c = Path()
                c.move(to: g.P(cx + side * 0.20, ey - 0.03)); c.addLine(to: g.P(cx + side * 0.155, ey + 0.03)); c.addLine(to: g.P(cx + side * 0.155, ey + 0.10))
                c.addLine(to: g.P(cx + side * 0.10, ey + 0.16)); c.addLine(to: g.P(cx + side * 0.04, ey + 0.16))
                c.move(to: g.P(cx + side * 0.155, ey + 0.065)); c.addLine(to: g.P(cx + side * 0.21, ey + 0.065))
                k.stroke(c, with: .color(pc.opacity(0.3)), lineWidth: g.w * 0.02)
                k.stroke(c, with: .color(pc), style: StrokeStyle(lineWidth: g.w * 0.007, lineCap: .round, lineJoin: .round))
                for n in [(0.20, -0.03), (0.155, 0.10), (0.04, 0.16), (0.21, 0.065)] {
                    k.fill(Path(ellipseIn: g.R(cx + side * n.0 - 0.009, ey + n.1 - 0.009, 0.018, 0.018)), with: .color(pc))
                }
            }
            var f = Path(); f.move(to: g.P(cx - 0.10, g.headY + 0.08)); f.addLine(to: g.P(cx - 0.04, g.headY + 0.08)); f.addLine(to: g.P(cx, g.headY + 0.12)); f.addLine(to: g.P(cx + 0.10, g.headY + 0.12))
            k.stroke(f, with: .color(pc), style: StrokeStyle(lineWidth: g.w * 0.007, lineCap: .round, lineJoin: .round))
        case 7: // hearts
            for h in [(-0.15, 0.085, 0.032), (0.15, 0.085, 0.032), (-0.115, 0.16, 0.016), (0.115, 0.16, 0.016), (0.0, -0.095, 0.014)] {
                let hp = heartPath(g.P(cx + h.0, ey + h.1), g.w * h.2)
                k.fill(hp, with: .color(pc)); k.stroke(hp, with: .color(glow), lineWidth: lwThin)
            }
        case 8, 15: // half skull / full skull
            let full = paint == 15
            var half = k
            if !full { half.clip(to: Path(CGRect(x: g.w * cx, y: g.ht * g.headY, width: g.w * g.headW / 2 + g.w * 0.01, height: g.ht * g.headH))) }
            half.fill(Path(ellipseIn: g.R(g.headX, g.headY, g.headW, g.headH)), with: .color(Color.white.opacity(0.94)))
            half.fill(Path(ellipseIn: g.R(cx + 0.03, ey - 0.045, 0.105, 0.11)), with: .color(ink))
            if full { half.fill(Path(ellipseIn: g.R(cx - 0.135, ey - 0.045, 0.105, 0.11)), with: .color(ink)) }
            half.fill(tri(g.P(cx + 0.002, ey + 0.065), g.P(cx + 0.04, ey + 0.115), g.P(cx - 0.012, ey + 0.115)), with: .color(ink))
            if full { half.fill(tri(g.P(cx - 0.002, ey + 0.065), g.P(cx - 0.04, ey + 0.115), g.P(cx + 0.012, ey + 0.115)), with: .color(ink)) }
            var teeth = Path()
            let tl = full ? cx - 0.075 : cx + 0.005
            for i in 0..<(full ? 8 : 4) {
                let x = tl + Double(i) * 0.019
                teeth.move(to: g.P(x, my - 0.015)); teeth.addLine(to: g.P(x, my + 0.045))
            }
            teeth.move(to: g.P(tl, my + 0.015)); teeth.addLine(to: g.P(tl + (full ? 0.15 : 0.075), my + 0.015))
            half.stroke(teeth, with: .color(ink.opacity(0.85)), lineWidth: lwThin)
            var crack = Path(); crack.move(to: g.P(cx + 0.06, g.headY + 0.03)); crack.addLine(to: g.P(cx + 0.08, g.headY + 0.09)); crack.addLine(to: g.P(cx + 0.065, g.headY + 0.13)); crack.addLine(to: g.P(cx + 0.095, g.headY + 0.17))
            half.stroke(crack, with: .color(ink.opacity(0.7)), lineWidth: lwThin)
            var cheek = Path(); cheek.move(to: g.P(cx + 0.12, ey + 0.075)); cheek.addQuadCurve(to: g.P(cx + 0.075, ey + 0.17), control: g.P(cx + 0.13, ey + 0.14))
            half.stroke(cheek, with: .color(Color.gray.opacity(0.6)), lineWidth: lwThin)
        case 9: // bandit mask with pointed edges and eye holes
            var m = Path()
            m.move(to: g.P(cx - 0.215, ey - 0.06)); m.addLine(to: g.P(cx - 0.10, ey - 0.075)); m.addLine(to: g.P(cx, ey - 0.03)); m.addLine(to: g.P(cx + 0.10, ey - 0.075))
            m.addLine(to: g.P(cx + 0.215, ey - 0.06)); m.addLine(to: g.P(cx + 0.19, ey + 0.045)); m.addLine(to: g.P(cx + 0.09, ey + 0.065)); m.addLine(to: g.P(cx, ey + 0.03))
            m.addLine(to: g.P(cx - 0.09, ey + 0.065)); m.addLine(to: g.P(cx - 0.19, ey + 0.045)); m.closeSubpath()
            k.fill(m, with: .color(pc.opacity(0.95))); k.stroke(m, with: .color(ink.opacity(0.8)), lineWidth: lwThin * 1.2)
            for side in [-1.0, 1.0] {
                k.fill(Path(ellipseIn: g.R(cx + side * 0.085 - 0.04, ey - 0.03, 0.08, 0.075)), with: .color(c(skinV)))
            }
        case 10: // galaxy
            k.fill(Path(ellipseIn: g.R(cx - 0.22, ey - 0.06, 0.2, 0.22)), with: .radialGradient(Gradient(colors: [c(0x7C3AED).opacity(0.55), Color.clear]), center: g.P(cx - 0.12, ey + 0.05), startRadius: 0, endRadius: g.w * 0.11))
            k.fill(Path(ellipseIn: g.R(cx + 0.02, ey - 0.06, 0.2, 0.22)), with: .radialGradient(Gradient(colors: [c(0x2563EB).opacity(0.55), Color.clear]), center: g.P(cx + 0.12, ey + 0.05), startRadius: 0, endRadius: g.w * 0.11))
            k.fill(Path(ellipseIn: g.R(cx - 0.08, ey + 0.08, 0.16, 0.1)), with: .radialGradient(Gradient(colors: [c(0xEC4899).opacity(0.4), Color.clear]), center: g.P(cx, ey + 0.13), startRadius: 0, endRadius: g.w * 0.08))
            for i in 0..<22 {
                let x = g.headX + 0.03 + frac(Double(i) * 0.6180339) * (g.headW - 0.06)
                let y = g.headY + 0.06 + frac(Double(i) * 0.7548776) * 0.34
                let r = 0.006 + 0.006 * frac(Double(i) * 0.37)
                k.fill(Path(ellipseIn: g.R(x, y, r, r)), with: .color(Color.white.opacity(0.9)))
            }
            k.fill(starPath(g.P(cx + 0.16, ey + 0.12), g.w * 0.026), with: .color(Color.white.opacity(0.95)))
        case 11: // flames, layered
            for side in [-1.0, 1.0] {
                for i in 0..<3 {
                    let x = cx + side * (0.12 + Double(i) * 0.045), y = ey + 0.16 - Double(i) * 0.02
                    var f = Path(); f.move(to: g.P(x - 0.025, y)); f.addQuadCurve(to: g.P(x, y - 0.09 - Double(i) * 0.02), control: g.P(x - 0.045, y - 0.05))
                    f.addQuadCurve(to: g.P(x + 0.025, y), control: g.P(x + 0.04, y - 0.05)); f.closeSubpath()
                    k.fill(f, with: .color(Color(red: 0.95, green: 0.2, blue: 0.1)))
                    var inner = Path(); inner.move(to: g.P(x - 0.012, y)); inner.addQuadCurve(to: g.P(x, y - 0.05 - Double(i) * 0.01), control: g.P(x - 0.025, y - 0.03))
                    inner.addQuadCurve(to: g.P(x + 0.012, y), control: g.P(x + 0.02, y - 0.03)); inner.closeSubpath()
                    k.fill(inner, with: .color(Color(red: 1, green: 0.85, blue: 0.2)))
                }
            }
        case 12: // tears with highlights and trails
            for d in [(-0.085, 0.07, 1.0), (0.09, 0.085, 0.8)] {
                let x = cx + d.0, y = ey + d.1, s = d.2
                var trail = Path(); trail.move(to: g.P(x, y - 0.01)); trail.addLine(to: g.P(x + 0.004, y + 0.045 * s))
                k.stroke(trail, with: .color(c(0x5AB8FF).opacity(0.5)), lineWidth: g.w * 0.01)
                var tp = Path(); tp.move(to: g.P(x, y + 0.04 * s)); tp.addQuadCurve(to: g.P(x, y + 0.115 * s), control: g.P(x - 0.03 * s, y + 0.09 * s))
                tp.addQuadCurve(to: g.P(x, y + 0.04 * s), control: g.P(x + 0.03 * s, y + 0.09 * s))
                k.fill(tp, with: .color(c(0x5AB8FF).opacity(0.92)))
                k.fill(Path(ellipseIn: g.R(x - 0.011, y + 0.08 * s, 0.01, 0.015)), with: .color(Color.white.opacity(0.8)))
            }
        case 13: // cat whiskers
            for side in [-1.0, 1.0] {
                for i in 0..<3 {
                    let y = ey + 0.075 + Double(i) * 0.024
                    k.fill(taper(g, cx + side * 0.23, y + (Double(i) - 1) * 0.016, cx + side * 0.09, y, 0.003, 0.006), with: .color(pc))
                }
                for d in 0..<3 {
                    k.fill(Path(ellipseIn: g.R(cx + side * (0.06 + Double(d) * 0.02) - 0.004, ey + 0.11 + Double(d % 2) * 0.012, 0.009, 0.009)), with: .color(pc))
                }
            }
            k.fill(tri(g.P(cx - 0.022, ey + 0.062), g.P(cx + 0.022, ey + 0.062), g.P(cx, ey + 0.092)), with: .color(Color(red: 0.95, green: 0.5, blue: 0.62)))
        case 14: // rainbow band
            let cols: [Color] = [.red, .orange, .yellow, .green, .blue, .purple]
            for i in 0..<cols.count {
                var b = Path(); b.move(to: g.P(cx - 0.22, ey + 0.058 + Double(i) * 0.012)); b.addQuadCurve(to: g.P(cx + 0.22, ey + 0.058 + Double(i) * 0.012), control: g.P(cx, ey + 0.085 + Double(i) * 0.012))
                k.stroke(b, with: .color(cols[i].opacity(0.8)), lineWidth: g.w * 0.013)
            }
            k.fill(starPath(g.P(cx - 0.16, ey + 0.04), g.w * 0.018), with: .color(Color.white.opacity(0.9)))
            k.fill(starPath(g.P(cx + 0.17, ey + 0.045), g.w * 0.014), with: .color(Color.white.opacity(0.9)))
        case 16: // eye black
            for side in [-1.0, 1.0] {
                k.fill(Path(roundedRect: g.R(cx + side * 0.085 - 0.04, ey + 0.045, 0.08, 0.022), cornerRadius: g.w * 0.01), with: .color(ink.opacity(0.9)))
            }
        default: // butterfly wings around the eyes
            for side in [-1.0, 1.0] {
                let ex = cx + side * 0.085
                let ox = side > 0 ? -0.025 : -0.075
                k.fill(Path(ellipseIn: g.R(ex + ox, ey - 0.12, 0.10, 0.11)), with: .color(pc.opacity(0.85)))
                k.fill(Path(ellipseIn: g.R(ex + ox + 0.005, ey + 0.02, 0.08, 0.09)), with: .color(pc.opacity(0.7)))
                k.fill(Path(ellipseIn: g.R(ex + ox + 0.025, ey - 0.095, 0.05, 0.06)), with: .color(Color.white.opacity(0.55)))
                k.fill(Path(ellipseIn: g.R(ex + ox + 0.03, ey + 0.04, 0.035, 0.04)), with: .color(Color.white.opacity(0.5)))
            }
        }
    }

    // MARK: hats

    static func hatExtra(_ ctx: GraphicsContext, _ g: PGeo, _ hat: Int, _ hcol: Color, _ hdark: Color) {
        if hat < 13 { return }
        let cx = g.cx, hy = g.headY, w = g.w
        func capDome(_ extra: Double) -> Path {
            var p = Path()
            p.addArc(center: g.P(cx, hy + 0.17), radius: w * (g.headW / 2 + extra), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            p.closeSubpath()
            return p
        }
        switch hat {
        case 13: // pirate
            ctx.fill(capDome(0.02), with: .color(Color(white: 0.08)))
            ctx.fill(Path(ellipseIn: g.R(cx - 0.25, hy + 0.10, 0.50, 0.12)), with: .color(Color(white: 0.06)))
            ctx.stroke(Path(ellipseIn: g.R(cx - 0.25, hy + 0.10, 0.50, 0.12)), with: .color(c(0xFFD23F)), lineWidth: g.lw * 0.8)
            glyph(ctx, "skull.fill", at: CGPoint(x: w * cx, y: g.ht * (hy + 0.12)), size: w * 0.08, color: Color.white.opacity(0.92))
        case 14: // santa
            ctx.fill(capDome(0.02), with: .color(c(0xD62E3A)))
            ctx.fill(tri(g.P(cx + 0.02, hy + 0.02), g.P(cx + 0.22, hy + 0.14), g.P(cx + 0.10, hy + 0.20)), with: .color(c(0xD62E3A)))
            ctx.fill(Path(roundedRect: g.R(g.headX - 0.02, hy + 0.13, g.headW + 0.04, 0.07), cornerRadius: w * 0.025), with: .color(Color.white))
            ctx.fill(Path(ellipseIn: g.R(cx + 0.17, hy + 0.10, 0.07, 0.07)), with: .color(Color.white))
        case 15: // chef
            ctx.fill(Path(ellipseIn: g.R(cx - 0.18, hy - 0.04, 0.13, 0.13)), with: .color(Color.white))
            ctx.fill(Path(ellipseIn: g.R(cx + 0.05, hy - 0.04, 0.13, 0.13)), with: .color(Color.white))
            ctx.fill(Path(ellipseIn: g.R(cx - 0.065, hy - 0.09, 0.13, 0.13)), with: .color(Color.white))
            ctx.fill(Path(roundedRect: g.R(cx - 0.13, hy, 0.26, 0.2), cornerRadius: w * 0.03), with: .color(Color.white))
            ctx.fill(Path(roundedRect: g.R(cx - 0.14, hy + 0.15, 0.28, 0.05), cornerRadius: w * 0.02), with: .color(Color.gray.opacity(0.3)))
        case 16: // flower crown
            var leaf = Path()
            leaf.addArc(center: g.P(cx, hy + 0.20), radius: w * (g.headW / 2 + 0.01), startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
            ctx.stroke(leaf, with: .color(c(0x2FA564)), lineWidth: g.w * 0.025)
            for i in 0..<7 {
                let a = (190.0 + Double(i) * 26.6) * Double.pi / 180.0
                let rr = g.headW / 2 + 0.01
                let px = cx + rr * cos(a), py = hy + 0.20 + rr * sin(a)
                ctx.fill(Path(ellipseIn: g.R(px - 0.03, py - 0.03, 0.06, 0.06)), with: .color(c(paints[(i * 3) % paints.count])))
                ctx.fill(Path(ellipseIn: g.R(px - 0.01, py - 0.01, 0.02, 0.02)), with: .color(c(0xFFD23F)))
            }
        case 17: // antenna
            var st = Path(); st.move(to: g.P(cx, hy + 0.01)); st.addLine(to: g.P(cx + 0.05, hy - 0.14))
            ctx.stroke(st, with: .color(Color.gray), lineWidth: g.lw)
            ctx.fill(Path(ellipseIn: g.R(cx + 0.02, hy - 0.19, 0.06, 0.06)), with: .color(c(0x00F0FF)))
            ctx.fill(Path(ellipseIn: g.R(cx - 0.005, hy - 0.215, 0.11, 0.11)), with: .color(c(0x00F0FF).opacity(0.25)))
        case 18: // big headphones
            var band = Path(); band.addArc(center: g.P(cx, hy + 0.22), radius: w * (g.headW / 2 + 0.04), startAngle: .degrees(182), endAngle: .degrees(358), clockwise: false)
            ctx.stroke(band, with: .color(hcol), lineWidth: max(2, w * 0.035))
            ctx.fill(Path(roundedRect: g.R(g.headX - 0.07, hy + 0.15, 0.09, 0.19), cornerRadius: w * 0.04), with: .color(hcol))
            ctx.fill(Path(roundedRect: g.R(g.headX + g.headW - 0.02, hy + 0.15, 0.09, 0.19), cornerRadius: w * 0.04), with: .color(hcol))
            ctx.fill(Path(ellipseIn: g.R(g.headX - 0.04, hy + 0.23, 0.025, 0.025)), with: .color(c(0x00F0FF)))
            ctx.fill(Path(ellipseIn: g.R(g.headX + g.headW + 0.015, hy + 0.23, 0.025, 0.025)), with: .color(c(0x00F0FF)))
        case 19: // bucket hat
            ctx.fill(capDome(0.02), with: .color(hcol))
            ctx.fill(Path(ellipseIn: g.R(cx - 0.23, hy + 0.15, 0.46, 0.08)), with: .color(hdark))
            ctx.fill(Path(roundedRect: g.R(cx - 0.15, hy + 0.11, 0.30, 0.04), cornerRadius: w * 0.01), with: .color(hdark.opacity(0.6)))
        case 20: // viking
            for s in [-1.0, 1.0] {
                var hn = Path()
                hn.move(to: g.P(cx + s * 0.16, hy + 0.20))
                hn.addQuadCurve(to: g.P(cx + s * 0.30, hy - 0.02), control: g.P(cx + s * 0.30, hy + 0.17))
                hn.addQuadCurve(to: g.P(cx + s * 0.20, hy + 0.16), control: g.P(cx + s * 0.21, hy + 0.09))
                hn.closeSubpath()
                ctx.fill(hn, with: .color(c(0xF5E6C8)))
            }
            ctx.fill(capDome(0.02), with: .color(c(0xA3A3AD)))
            ctx.fill(Path(roundedRect: g.R(g.headX - 0.02, hy + 0.14, g.headW + 0.04, 0.045), cornerRadius: w * 0.015), with: .color(c(0xFFD23F)))
        case 21: // graduation cap
            ctx.fill(Path(roundedRect: g.R(cx - 0.12, hy + 0.12, 0.24, 0.07), cornerRadius: w * 0.02), with: .color(Color(white: 0.1)))
            var board = Path(); board.move(to: g.P(cx - 0.23, hy + 0.12)); board.addLine(to: g.P(cx, hy + 0.04)); board.addLine(to: g.P(cx + 0.23, hy + 0.12)); board.addLine(to: g.P(cx, hy + 0.20)); board.closeSubpath()
            ctx.fill(board, with: .color(Color(white: 0.06)))
            var ts = Path(); ts.move(to: g.P(cx + 0.19, hy + 0.12)); ts.addLine(to: g.P(cx + 0.19, hy + 0.23))
            ctx.stroke(ts, with: .color(c(0xFFD23F)), lineWidth: g.lw)
            ctx.fill(Path(ellipseIn: g.R(cx + 0.175, hy + 0.225, 0.03, 0.03)), with: .color(c(0xFFD23F)))
        default: break
        }
    }

    // MARK: jewelry

    static func jewelry(_ ctx: GraphicsContext, _ g: PGeo, _ lk: AvatarLook, _ ringDefault: Bool) {
        let gold = Color(red: 1, green: 0.84, blue: 0.3)
        let acc = c(paints[(lk.accent ?? 0) % paints.count])
        let ear = lk.ear ?? (ringDefault ? 1 : 0)
        let lx = g.headX - 0.01, rx = g.headX + g.headW + 0.01, ly = g.headY + 0.30
        switch ear {
        case 1:
            ctx.fill(Path(ellipseIn: g.R(lx - 0.002, ly - 0.005, 0.03, 0.03)), with: .color(gold))
        case 2:
            ctx.stroke(Path(ellipseIn: g.R(lx - 0.025, ly, 0.05, 0.06)), with: .color(gold), lineWidth: max(1, g.w * 0.012))
            ctx.stroke(Path(ellipseIn: g.R(rx - 0.025, ly, 0.05, 0.06)), with: .color(gold), lineWidth: max(1, g.w * 0.012))
        case 3:
            var d = Path(); d.move(to: g.P(lx, ly)); d.addLine(to: g.P(lx, ly + 0.06))
            d.move(to: g.P(rx, ly)); d.addLine(to: g.P(rx, ly + 0.06))
            ctx.stroke(d, with: .color(gold), lineWidth: g.lw * 0.7)
            ctx.fill(Path(ellipseIn: g.R(lx - 0.016, ly + 0.055, 0.032, 0.032)), with: .color(acc))
            ctx.fill(Path(ellipseIn: g.R(rx - 0.016, ly + 0.055, 0.032, 0.032)), with: .color(acc))
        default: break
        }
        let cx = g.cx, ey = g.ey
        switch lk.pierce ?? 0 {
        case 1: ctx.stroke(Path(ellipseIn: g.R(cx + 0.022, ey + 0.083, 0.026, 0.026)), with: .color(gold), lineWidth: max(0.8, g.w * 0.008))
        case 2:
            ctx.stroke(Path(ellipseIn: g.R(cx + 0.095, ey - 0.052, 0.022, 0.022)), with: .color(gold), lineWidth: max(0.8, g.w * 0.008))
        case 3: ctx.stroke(Path(ellipseIn: g.R(cx + 0.025, g.my + 0.012, 0.024, 0.024)), with: .color(gold), lineWidth: max(0.8, g.w * 0.008))
        case 4:
            var s = Path(); s.addArc(center: g.P(cx, ey + 0.10), radius: g.w * 0.02, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            ctx.stroke(s, with: .color(gold), lineWidth: max(0.8, g.w * 0.008))
        default: break
        }
    }

    // MARK: frame, sticker, pattern

    static func drawFrame(_ ctx: GraphicsContext, _ sz: CGSize, _ kind: Int, _ col: Color, _ t: Double) {
        if kind == 0 { return }
        let w = sz.width
        let ins = w * 0.03
        let ring = Path(ellipseIn: CGRect(x: ins, y: ins, width: w - ins * 2, height: w - ins * 2))
        switch kind {
        case 1:
            ctx.stroke(ring, with: .color(Color(red: 1, green: 0.82, blue: 0.25)), lineWidth: w * 0.06)
            ctx.stroke(ring, with: .color(Color.white.opacity(0.4)), lineWidth: w * 0.012)
        case 2:
            let pulse = 0.6 + 0.4 * sin(t * 4)
            ctx.stroke(ring, with: .color(col.opacity(0.35 * pulse)), lineWidth: w * 0.11)
            ctx.stroke(ring, with: .color(col), lineWidth: w * 0.035)
        case 3:
            ctx.stroke(ring, with: .color(Color(red: 1, green: 0.4, blue: 0.05)), lineWidth: w * 0.05)
            for i in 0..<16 {
                let a = Double(i) / 16.0 * 2 * Double.pi
                let r = Double(w) * 0.5 - Double(ins) - Double(w) * 0.02
                let flick = 0.5 + 0.5 * sin(t * 6 + Double(i) * 1.9)
                let s = Double(w) * 0.06 * (0.6 + flick)
                let px = Double(w) / 2 + r * cos(a), py = Double(w) / 2 + r * sin(a)
                ctx.fill(Path(ellipseIn: CGRect(x: px - s / 2, y: py - s / 2, width: s, height: s)), with: .color(Color(red: 1, green: 0.55 + 0.4 * flick, blue: 0.1).opacity(0.9)))
            }
        case 4:
            let cols: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]
            ctx.stroke(ring, with: .conicGradient(Gradient(colors: cols), center: CGPoint(x: w / 2, y: w / 2), angle: .degrees(t * 90)), lineWidth: w * 0.055)
        case 5:
            ctx.stroke(ring, with: .color(col), style: StrokeStyle(lineWidth: w * 0.045, dash: [w * 0.07, w * 0.04]))
        default:
            ctx.stroke(ring, with: .color(col), lineWidth: w * 0.02)
            let inner = Path(ellipseIn: CGRect(x: ins + w * 0.04, y: ins + w * 0.04, width: w - ins * 2 - w * 0.08, height: w - ins * 2 - w * 0.08))
            ctx.stroke(inner, with: .color(Color.white.opacity(0.8)), lineWidth: w * 0.014)
        }
    }

    static func sticker(_ ctx: GraphicsContext, _ sz: CGSize, _ kind: Int) {
        if kind <= 0 || kind >= stickers.count { return }
        let w = sz.width
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.68, y: w * 0.68, width: w * 0.28, height: w * 0.28)), with: .color(Color.black.opacity(0.55)))
        glyph(ctx, stickers[kind], at: CGPoint(x: w * 0.82, y: w * 0.825), size: w * 0.17, color: .white)
    }

    static func drawPattern(_ ctx: GraphicsContext, _ sz: CGSize, _ kind: Int, _ col: Color) {
        if kind == 0 { return }
        let w = sz.width, h = sz.height
        switch kind {
        case 1: // grid
            var p = Path()
            for i in 1..<8 { let x = w * Double(i) / 8; p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h)) }
            for i in 1..<8 { let y = h * Double(i) / 8; p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y)) }
            ctx.stroke(p, with: .color(col.opacity(0.25)), lineWidth: max(0.5, w * 0.006))
        case 2: // dots
            for i in 0..<8 { for j in 0..<8 {
                let r = w * 0.012
                ctx.fill(Path(ellipseIn: CGRect(x: w * (Double(i) + 0.5) / 8 - r, y: h * (Double(j) + 0.5) / 8 - r, width: r * 2, height: r * 2)), with: .color(col.opacity(0.35)))
            } }
        case 3: // stripes
            var p = Path()
            for i in -8..<16 { let x = w * Double(i) / 8; p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x + w * 0.5, y: h)) }
            ctx.stroke(p, with: .color(col.opacity(0.2)), lineWidth: max(1, w * 0.03))
        default: // diamonds
            for i in 0..<5 { for j in 0..<5 {
                let cxp = w * (Double(i) + 0.5) / 5, cyp = h * (Double(j) + 0.5) / 5, r = w * 0.07
                var d = Path(); d.move(to: CGPoint(x: cxp, y: cyp - r)); d.addLine(to: CGPoint(x: cxp + r, y: cyp)); d.addLine(to: CGPoint(x: cxp, y: cyp + r)); d.addLine(to: CGPoint(x: cxp - r, y: cyp)); d.closeSubpath()
                ctx.stroke(d, with: .color(col.opacity(0.3)), lineWidth: max(0.5, w * 0.006))
            } }
        }
    }

    // MARK: more animated backdrops

    static func drawBG2(_ ctx: GraphicsContext, _ sz: CGSize, _ accent: Color, _ anim: Int, _ t: Double) {
        let w = sz.width, h = sz.height
        switch anim {
        case 9: // snow
            for i in 0..<24 {
                let f = frac(Double(i) * 0.37)
                let y = h * (frac(t * 0.12 * (0.6 + f) + Double(i) * 0.17) * 1.1 - 0.05)
                let x = w * (frac(Double(i) * 0.61) + 0.03 * sin(t * 1.3 + Double(i)))
                let r = w * (0.008 + 0.012 * f)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color.white.opacity(0.85)))
            }
        case 10: // confetti
            for i in 0..<20 {
                let f = frac(Double(i) * 0.43)
                let y = h * (frac(t * 0.18 * (0.6 + f) + Double(i) * 0.11) * 1.1 - 0.05)
                let x = w * (frac(Double(i) * 0.53 + 0.1) + 0.04 * sin(t * 2 + Double(i)))
                var c2 = ctx
                c2.translateBy(x: x, y: y)
                c2.rotate(by: .radians(t * 3 + Double(i)))
                c2.fill(Path(CGRect(x: -w * 0.02, y: -w * 0.01, width: w * 0.04, height: w * 0.02)), with: .color(Color(hue: frac(Double(i) * 0.137), saturation: 0.8, brightness: 1)))
            }
        case 11: // storm
            for i in 0..<14 {
                let x = w * frac(Double(i) * 0.31 + 0.07)
                let y = h * frac(t * 1.2 + Double(i) * 0.23)
                var d = Path(); d.move(to: CGPoint(x: x, y: y)); d.addLine(to: CGPoint(x: x - w * 0.02, y: y + h * 0.07))
                ctx.stroke(d, with: .color(Color.white.opacity(0.22)), lineWidth: max(0.6, w * 0.006))
            }
            let ph = frac(t * 0.55)
            if ph < 0.14 {
                ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(Color.white.opacity(0.28 * (1 - ph / 0.14))))
                let seed = floor(t * 0.55)
                let bx = w * (0.2 + 0.6 * frac(seed * 0.618))
                var b = Path(); b.move(to: CGPoint(x: bx, y: 0))
                b.addLine(to: CGPoint(x: bx - w * 0.07, y: h * 0.25)); b.addLine(to: CGPoint(x: bx + w * 0.05, y: h * 0.4))
                b.addLine(to: CGPoint(x: bx - w * 0.05, y: h * 0.65))
                ctx.stroke(b, with: .color(Color(red: 0.9, green: 0.95, blue: 1)), lineWidth: max(1, w * 0.02))
            }
        case 12: // sakura
            for i in 0..<14 {
                let f = frac(Double(i) * 0.47)
                let y = h * (frac(t * 0.1 * (0.6 + f) + Double(i) * 0.21) * 1.1 - 0.05)
                let x = w * (frac(Double(i) * 0.59 + 0.1) + 0.06 * sin(t + Double(i) * 1.4))
                let r = w * (0.016 + 0.014 * f)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 1.2)), with: .color(Color(red: 1, green: 0.72, blue: 0.82).opacity(0.9)))
            }
        case 13: // waves
            for k in 0..<3 {
                var p = Path(); p.move(to: CGPoint(x: 0, y: h))
                var x = 0.0
                while x <= w {
                    let y = h * (0.62 + 0.1 * Double(k)) + h * 0.04 * sin(x / w * 6 + t * (1.2 + Double(k) * 0.4) + Double(k))
                    p.addLine(to: CGPoint(x: x, y: y)); x += w / 24
                }
                p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath()
                ctx.fill(p, with: .color(Color(red: 0.2, green: 0.5 + 0.1 * Double(k), blue: 1).opacity(0.35)))
            }
        case 14: // radar
            let ctr = CGPoint(x: w / 2, y: h / 2)
            for i in 1..<4 {
                let r = w * 0.15 * Double(i)
                ctx.stroke(Path(ellipseIn: CGRect(x: ctr.x - r, y: ctr.y - r, width: r * 2, height: r * 2)), with: .color(Color.green.opacity(0.3)), lineWidth: max(0.6, w * 0.005))
            }
            for k in 0..<14 {
                let a = t * 1.6 - Double(k) * 0.06
                var l = Path(); l.move(to: ctr); l.addLine(to: CGPoint(x: ctr.x + w * cos(a), y: ctr.y + w * sin(a)))
                ctx.stroke(l, with: .color(Color.green.opacity(0.55 * (1 - Double(k) / 14))), lineWidth: max(1, w * 0.02))
            }
        case 15: // hearts
            for i in 0..<10 {
                let f = frac(Double(i) * 0.41)
                let y = h * (1.1 - frac(t * 0.14 * (0.6 + f) + Double(i) * 0.19) * 1.2)
                let x = w * (frac(Double(i) * 0.57 + 0.08) + 0.04 * sin(t * 1.5 + Double(i)))
                glyph(ctx, "heart.fill", at: CGPoint(x: x, y: y), size: w * (0.06 + 0.05 * f), color: Color(red: 1, green: 0.35, blue: 0.55).opacity(0.85))
            }
        case 16: // synthwave
            ctx.fill(Path(CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45)), with: .color(Color(red: 0.12, green: 0.02, blue: 0.2)))
            let sun = CGRect(x: w * 0.3, y: h * 0.25, width: w * 0.4, height: w * 0.4)
            ctx.fill(Path(ellipseIn: sun), with: .linearGradient(Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.2), Color(red: 1, green: 0.2, blue: 0.6)]), startPoint: CGPoint(x: 0, y: sun.minY), endPoint: CGPoint(x: 0, y: sun.maxY)))
            var gl = Path()
            for i in 0..<8 {
                let k = frac(t * 0.3 + Double(i) / 8.0)
                let y = h * (0.55 + 0.45 * k * k)
                gl.move(to: CGPoint(x: 0, y: y)); gl.addLine(to: CGPoint(x: w, y: y))
            }
            for i in -4...4 {
                gl.move(to: CGPoint(x: w / 2, y: h * 0.55)); gl.addLine(to: CGPoint(x: w / 2 + Double(i) * w * 0.28, y: h))
            }
            ctx.stroke(gl, with: .color(Color(red: 1, green: 0.2, blue: 0.8).opacity(0.7)), lineWidth: max(0.6, w * 0.006))
        case 17: // fireflies
            for i in 0..<12 {
                let x = w * (0.5 + 0.42 * sin(t * 0.4 + Double(i) * 1.7))
                let y = h * (0.5 + 0.40 * cos(t * 0.35 + Double(i) * 2.3))
                let pulse = 0.4 + 0.6 * abs(sin(t * 1.5 + Double(i)))
                let r = w * 0.035
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.95, blue: 0.4).opacity(pulse), Color.clear]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
            }
        default: break
        }
    }
}
