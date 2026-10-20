import SwiftUI

/// Player-chosen overrides for the illustrated avatar. nil = keep the generated default.
struct AvatarLook: Codable, Equatable {
    var skin: Int? = nil
    var hair: Int? = nil
    var hairStyle: Int? = nil
    var top: Int? = nil
    var outfit: Int? = nil
    var eyes: Int? = nil
    var mouth: Int? = nil
    var specs: Int? = nil       // 0 none, 1 round, 2 shades, 3 visor
    var hat: Int = 0
    var hatColor: Int = 3
    var paint: Int = 0
    var paintColor: Int = 0
    var chain: Bool = false
    var earring: Bool? = nil
    var phones: Bool? = nil
    var bg: Int? = nil
    var anim: Int = 0
    // extended customisation (optional so older saves still decode)
    var faceShape: Int? = nil
    var brow: Int? = nil
    var browColor: Int? = nil
    var eyeColor: Int? = nil
    var lashes: Bool? = nil
    var nose: Int? = nil
    var lips: Int? = nil
    var beard: Int? = nil
    var beardColor: Int? = nil
    var freckles: Bool? = nil
    var mole: Int? = nil
    var scar: Int? = nil
    var blush: Int? = nil
    var streak: Int? = nil
    var hairAcc: Int? = nil
    var accent: Int? = nil
    var ear: Int? = nil
    var pierce: Int? = nil
    var mask: Int? = nil
    var neck: Int? = nil
    var frame: Int? = nil
    var pattern: Int? = nil
    var sticker: Int? = nil
    var necklace: Int? = nil
    var metal: Int? = nil
    // full-body customisation for the 3D soldier
    var build: Int? = nil       // 0 slim, 1 average, 2 athletic, 3 heavy
    var height: Int? = nil      // 0 short, 1 average, 2 tall
    var pants: Int? = nil       // colour index
    var pantsStyle: Int? = nil  // 0 cargo, 1 jeans, 2 tactical, 3 shorts
    var shoes: Int? = nil       // colour index
    var gloves: Int? = nil      // 0 none, 1 fingerless, 2 full
    var gloveCol: Int? = nil
    var vestCol: Int? = nil     // armor colour
    var pack: Int? = nil        // 0 none, 1 small, 2 large
    var packCol: Int? = nil
    // operator kit (TacGear): 0/nil = classic outfit, 1... = kit; slot overrides are nil until the player swaps a piece
    var kit: Int? = nil
    var kSkin: Int? = nil
    var kHelm: Int? = nil
    var kFace: Int? = nil
    var kEyes: Int? = nil
    var kRig: Int? = nil
    var kGlove: Int? = nil
    // Special Task Force operator pieces (TacGear.stf*); nil = the kit's own preset
    var sBody: Int? = nil       // uniform camo
    var sGear: Int? = nil       // vest colour
    var sVest: Bool? = nil      // vest on / off
    var sHead: Int? = nil       // 0 bare head, 1 helmet, 2 helmet + NVG
    var sHelmCol: Int? = nil
    var sFace: Int? = nil
    var sLens: Int? = nil       // 0 none, 1 smoke, 2 amber, 3 blue, 4 red
}

extension AvatarLook {
    /// face-only variant used for the 3D head texture (hair, hats and clothing are real geometry)
    var faceCopy: AvatarLook {
        var l = self
        l.hairStyle = 9; l.hat = 0; l.hairAcc = 0; l.streak = nil; l.phones = false
        l.bg = nil; l.anim = 0; l.frame = 0; l.sticker = 0; l.pattern = 0
        l.necklace = 0; l.chain = false; l.neck = 0
        return l
    }
}

enum HK {
    static func h(_ s: String) -> UInt32 {
        var x: UInt32 = 5381
        for u in s.unicodeScalars { x = x &* 33 &+ u.value }
        return x
    }
}

enum AvatarLooks {
    static var version = 0
    static var handle: String = UserDefaults.standard.string(forKey: "ms.look.h") ?? ""
    static var mine: AvatarLook? = {
        guard let d = UserDefaults.standard.data(forKey: "ms.look.v1") else { return nil }
        return try? JSONDecoder().decode(AvatarLook.self, from: d)
    }()

    static func look(for key: String) -> AvatarLook? {
        guard mine != nil, !handle.isEmpty, key.lowercased() == handle.lowercased() else { return nil }
        return mine
    }

    static func save(_ l: AvatarLook?, handle h: String) {
        mine = l
        handle = h
        version += 1
        let u = UserDefaults.standard
        if let l = l, let d = try? JSONEncoder().encode(l) { u.set(d, forKey: "ms.look.v1") } else { u.removeObject(forKey: "ms.look.v1") }
        u.set(h, forKey: "ms.look.h")
    }

    static func rename(to h: String) {
        guard mine != nil, !h.isEmpty, h != handle else { return }
        handle = h
        version += 1
        UserDefaults.standard.set(h, forKey: "ms.look.h")
    }
}

/// Illustrated person portrait, unique per handle (skin, hair, outfit, face, accessories, background).
struct PortraitAvatar: View {
    let key: String
    var size: CGFloat = 40
    var look: AvatarLook? = nil
    var faceOnly = false
    let ver: Int = AvatarLooks.version

    static let skins: [UInt32] = [0xFBDDC8, 0xF3C9A8, 0xE2AE86, 0xC98B5B, 0xA9693D, 0x8A5128, 0x6A3B1E, 0x4B2813]
    static let hairs: [UInt32] = [0x16110E, 0x2B1A12, 0x4A2E1B, 0x7A4B24, 0xC9A15A, 0xE3C98A, 0xA3341F, 0x8C8C92, 0xE6E6EA, 0xFF4FA3, 0x3AA0FF, 0x37D67A, 0x9B5CFF]
    static let tops: [UInt32] = [0x1F2937, 0x374151, 0x7C3AED, 0x2563EB, 0x059669, 0xDC2626, 0xF59E0B, 0xE5E7EB, 0x0F172A, 0xDB2777, 0x0EA5E9, 0x84CC16]
    static let bgs: [(UInt32, UInt32)] = [(0x3B2A5C, 0x120A24), (0x14405A, 0x07141F), (0x5A2A3B, 0x200A12), (0x1F4D3A, 0x08190F), (0x5A4A1F, 0x1E1707),
                                                  (0x2A3B5C, 0x0A1224), (0x4C1F5A, 0x180724), (0x1F5A56, 0x07201E), (0x5A3A1F, 0x241507), (0x3A3A44, 0x111116)]

    static let paints: [UInt32] = [0xFF3B5C, 0x3AA0FF, 0x37D67A, 0xFFD23F, 0xB26BFF, 0xFFFFFF, 0xFF8A00, 0x00F0FF]
    static func frac(_ x: Double) -> Double { x - floor(x) }

    private func col(_ v: UInt32) -> Color { Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255) }
    private func shade(_ v: UInt32, _ f: Double) -> Color {
        Color(red: min(1, Double((v >> 16) & 255) / 255 * f), green: min(1, Double((v >> 8) & 255) / 255 * f), blue: min(1, Double(v & 255) / 255 * f))
    }

    var body: some View {
        let lk = look ?? AvatarLooks.look(for: key) ?? AvatarLook()
        let inner = Group {
            if lk.anim > 0 || [2, 3, 4].contains(lk.frame ?? 0) {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { tl in
                    portrait(lk, t: tl.date.timeIntervalSinceReferenceDate)
                }
            } else {
                portrait(lk, t: 0)
            }
        }
        .frame(width: size, height: size)
        return faceOnly
            ? AnyView(inner)
            : AnyView(inner.clipShape(Circle()).overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: max(0.8, size * 0.015))))
    }

    private func portrait(_ lk0: AvatarLook, t: Double) -> some View {
        let lk = faceOnly ? lk0.faceCopy : lk0
        let h = HK.h(key.lowercased()), h2 = h &* 2654435761, h3 = h2 &* 40503 &+ 977
        let skinV = Self.skins[(lk.skin ?? Int(h % 8)) % Self.skins.count]
        let hairV = Self.hairs[(lk.hair ?? Int((h >> 3) % UInt32(Self.hairs.count))) % Self.hairs.count]
        let topV = Self.tops[(lk.top ?? Int((h2 >> 5) % UInt32(Self.tops.count))) % Self.tops.count]
        let bg = Self.bgs[(lk.bg ?? Int((h3 >> 4) % UInt32(Self.bgs.count))) % Self.bgs.count]
        let styleRaw = lk.hairStyle ?? Int((h2 >> 9) % 10)
        let style = (lk.hat > 0 && (styleRaw == 7 || styleRaw == 8)) ? 0 : styleRaw
        let outfit = lk.outfit ?? Int((h3 >> 11) % 4)
        let eyeKind = (lk.eyes ?? Int((h >> 14) % 3)) % 3
        let mouth = (lk.mouth ?? Int((h2 >> 17) % 4)) % 4
        let specKind = lk.specs ?? (((h3 >> 19) % 100 < 30) ? 1 : 0)
        let ring = lk.earring ?? ((h >> 21) % 100 < 22)
        let phones = lk.phones ?? ((h2 >> 23) % 100 < 14)
        let fs = (lk.faceShape ?? 0) % 5
        let wide = 0.36 + Double((h >> 25) % 5) * 0.012 + [0.0, -0.035, 0.03, 0.055, 0.0][fs]
        let hH = [0.46, 0.50, 0.44, 0.44, 0.49][fs]
        let blushA = [0.14, 0.0, 0.32][(lk.blush ?? 0) % 3]
        let accentCol = col(Self.paints[(lk.accent ?? 0) % Self.paints.count])
        let browCol = lk.browColor.map { col(Self.hairs[$0 % Self.hairs.count]) } ?? col(hairV)
        let beardCol = lk.beardColor.map { col(Self.hairs[$0 % Self.hairs.count]) } ?? col(hairV)
        let skin = col(skinV), hair = col(hairV), top = col(topV)
        return Canvas { ctx, sz in
            let w = sz.width, ht = sz.height
            func R(_ x: Double, _ y: Double, _ ww: Double, _ hh: Double) -> CGRect { CGRect(x: w * x, y: ht * y, width: w * ww, height: ht * hh) }
            // background
            if !faceOnly {
                Self.drawBG(ctx, sz, col(bg.0), col(bg.1), shade(bg.0, 2.4), lk.anim, t)
                Self.drawPattern(ctx, sz, lk.pattern ?? 0, shade(bg.0, 3.0))
            }
            let cx = 0.5
            let headW = wide + 0.02, headH = hH, headX = cx - headW / 2, headY = 0.2
            let g = PGeo(w: w, ht: ht, cx: cx, headX: headX, headY: headY, headW: headW, headH: headH, ey: headY + 0.25)
            // hair behind
            switch style {
            case 1, 6: // long
                ctx.fill(Path(roundedRect: R(headX - 0.05, headY + 0.02, headW + 0.10, 0.62), cornerRadius: w * 0.12), with: .color(hair))
            case 3: // afro
                ctx.fill(Path(ellipseIn: R(cx - 0.29, headY - 0.14, 0.58, 0.58)), with: .color(hair))
            case 4: // bun
                ctx.fill(Path(ellipseIn: R(cx - 0.09, headY - 0.17, 0.18, 0.18)), with: .color(hair))
            default: Self.hairBehindExtra(ctx, g, style, hair)
            }
            if !faceOnly {
            // shoulders
            ctx.fill(Path(ellipseIn: R(0.06, 0.74, 0.88, 0.62)), with: .color(top))
            if outfit == 1 { // hoodie hood
                ctx.fill(Path(ellipseIn: R(0.16, 0.62, 0.68, 0.30)), with: .color(shade(topV, 0.72)))
            }
            // neck
            ctx.fill(Path(roundedRect: R(cx - 0.075, 0.60, 0.15, 0.18), cornerRadius: w * 0.04), with: .color(shade(skinV, 0.86)))
            // collar
            switch outfit {
            case 0: ctx.fill(Path(ellipseIn: R(cx - 0.10, 0.70, 0.20, 0.10)), with: .color(shade(skinV, 0.9)))
            case 2:
                var l = Path(); l.move(to: CGPoint(x: w * 0.40, y: ht * 0.74)); l.addLine(to: CGPoint(x: w * 0.5, y: ht * 0.92)); l.addLine(to: CGPoint(x: w * 0.60, y: ht * 0.74)); l.closeSubpath()
                ctx.fill(l, with: .color(.white.opacity(0.9)))
            case 3:
                // turtleneck: a knitted roll that wraps the whole neck
                ctx.fill(Path(roundedRect: R(cx - 0.092, 0.585, 0.184, 0.19), cornerRadius: w * 0.045), with: .color(shade(topV, 0.9)))
                var folds = Path()
                for k in 0..<3 {
                    let y = 0.62 + Double(k) * 0.045
                    folds.move(to: CGPoint(x: w * (cx - 0.085), y: ht * y))
                    folds.addQuadCurve(to: CGPoint(x: w * (cx + 0.085), y: ht * y), control: CGPoint(x: w * cx, y: ht * (y + 0.02)))
                }
                ctx.stroke(folds, with: .color(shade(topV, 0.62)), lineWidth: max(1, w * 0.011))
            case 4: // open jacket over white tee
                var v = Path(); v.move(to: CGPoint(x: w * 0.42, y: ht * 0.74)); v.addLine(to: CGPoint(x: w * 0.5, y: ht * 0.86)); v.addLine(to: CGPoint(x: w * 0.58, y: ht * 0.74)); v.closeSubpath()
                ctx.fill(v, with: .color(.white.opacity(0.92)))
                var lp = Path(); lp.move(to: CGPoint(x: w * 0.40, y: ht * 0.74)); lp.addLine(to: CGPoint(x: w * 0.47, y: ht * 0.99))
                lp.move(to: CGPoint(x: w * 0.60, y: ht * 0.74)); lp.addLine(to: CGPoint(x: w * 0.53, y: ht * 0.99))
                ctx.stroke(lp, with: .color(shade(topV, 0.6)), lineWidth: max(1, w * 0.02))
            case 5: // jersey
                ctx.stroke(Path(ellipseIn: R(cx - 0.11, 0.70, 0.22, 0.11)), with: .color(.white.opacity(0.9)), lineWidth: max(1, w * 0.03))
                ctx.draw(Text("07").font(.system(size: w * 0.12, weight: .black)).foregroundColor(.white.opacity(0.92)), at: CGPoint(x: w * 0.5, y: ht * 0.91))
            case 6: // suit and tie
                var v = Path(); v.move(to: CGPoint(x: w * 0.41, y: ht * 0.74)); v.addLine(to: CGPoint(x: w * 0.5, y: ht * 0.9)); v.addLine(to: CGPoint(x: w * 0.59, y: ht * 0.74)); v.closeSubpath()
                ctx.fill(v, with: .color(.white.opacity(0.95)))
                var tie = Path(); tie.move(to: CGPoint(x: w * 0.48, y: ht * 0.78)); tie.addLine(to: CGPoint(x: w * 0.52, y: ht * 0.78)); tie.addLine(to: CGPoint(x: w * 0.535, y: ht * 0.95)); tie.addLine(to: CGPoint(x: w * 0.5, y: ht * 0.98)); tie.addLine(to: CGPoint(x: w * 0.465, y: ht * 0.95)); tie.closeSubpath()
                ctx.fill(tie, with: .color(Color(red: 0.85, green: 0.12, blue: 0.2)))
            case 7: // tank top
                ctx.fill(Path(ellipseIn: R(cx - 0.20, 0.72, 0.40, 0.30)), with: .color(shade(skinV, 0.95)))
                ctx.fill(Path(ellipseIn: R(cx - 0.12, 0.72, 0.24, 0.12)), with: .color(shade(skinV, 0.86)))
            case 8, 9, 10, 11, 12, 13:
                Self.outfitExtra(ctx, g, outfit, topV, skinV)
            default:
                var s = Path(); s.move(to: CGPoint(x: w * 0.45, y: ht * 0.8)); s.addLine(to: CGPoint(x: w * 0.45, y: ht * 0.95))
                s.move(to: CGPoint(x: w * 0.55, y: ht * 0.8)); s.addLine(to: CGPoint(x: w * 0.55, y: ht * 0.95))
                ctx.stroke(s, with: .color(.white.opacity(0.7)), lineWidth: max(0.8, w * 0.012))
            }
            Self.necklace(ctx, g, lk.necklace ?? (lk.chain ? 1 : 0), lk.metal ?? 0, accentCol)
            Self.neckwear(ctx, g, lk.neck ?? 0, accentCol)
            }
            // ears
            ctx.fill(Path(ellipseIn: R(headX - 0.025, headY + 0.20, 0.05, 0.09)), with: .color(skin))
            ctx.fill(Path(ellipseIn: R(headX + headW - 0.025, headY + 0.20, 0.05, 0.09)), with: .color(skin))
            // head
            ctx.fill(Path(ellipseIn: R(headX, headY, headW, headH)), with: .color(skin))
            let ey = headY + 0.25
            let pc = col(Self.paints[lk.paintColor % Self.paints.count])
            Self.drawPaint(ctx, g, lk.paint, pc, skinV)
            // hair front
            switch style {
            case 0: // short crop
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.20)), radius: w * (headW / 2 + 0.005), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2), y: ht * (headY + 0.20)), control: CGPoint(x: w * cx, y: ht * (headY + 0.10)))
                ctx.fill(p, with: .color(hair))
            case 1, 6:
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.20)), radius: w * (headW / 2 + 0.01), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2), y: ht * (headY + 0.20)), control: CGPoint(x: w * (cx + 0.05), y: ht * (headY + 0.06)))
                ctx.fill(p, with: .color(hair))
            case 2: // buzz
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.20)), radius: w * (headW / 2), startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2 + 0.03), y: ht * (headY + 0.12)), control: CGPoint(x: w * cx, y: ht * (headY + 0.14)))
                ctx.fill(p, with: .color(hair.opacity(0.9)))
            case 3:
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.18)), radius: w * (headW / 2), startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2 + 0.01), y: ht * (headY + 0.16)), control: CGPoint(x: w * cx, y: ht * (headY + 0.08)))
                ctx.fill(p, with: .color(hair))
            case 4, 5:
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.20)), radius: w * (headW / 2 + 0.005), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.addQuadCurve(to: CGPoint(x: w * (cx - headW / 2), y: ht * (headY + 0.20)), control: CGPoint(x: w * (cx - 0.08), y: ht * (headY + 0.11)))
                ctx.fill(p, with: .color(hair))
                if style == 5 { // side swoop
                    ctx.fill(Path(ellipseIn: R(cx - 0.20, headY + 0.00, 0.30, 0.16)), with: .color(hair))
                }
            case 7: // beanie
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.17)), radius: w * (headW / 2 + 0.02), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.closeSubpath()
                ctx.fill(p, with: .color(shade(topV, 1.15)))
                ctx.fill(Path(roundedRect: R(headX - 0.02, headY + 0.13, headW + 0.04, 0.07), cornerRadius: w * 0.02), with: .color(shade(topV, 0.8)))
            case 8: // cap
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.17)), radius: w * (headW / 2 + 0.015), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.closeSubpath()
                ctx.fill(p, with: .color(shade(topV, 0.95)))
                ctx.fill(Path(roundedRect: R(cx - 0.02, headY + 0.145, headW / 2 + 0.12, 0.04), cornerRadius: w * 0.02), with: .color(shade(topV, 0.7)))
            default: Self.hairFrontExtra(ctx, g, style, hair)
            }
            Self.hairExtras(ctx, g, lk, style)
            // eyes
            let eyeColor = col(Self.eyeCols[(lk.eyeColor ?? 0) % Self.eyeCols.count])
            func eye(_ x: Double) {
                switch eyeKind {
                case 0: ctx.fill(Path(ellipseIn: R(x - 0.018, ey, 0.036, 0.045)), with: .color(eyeColor))
                case 1:
                    ctx.fill(Path(ellipseIn: R(x - 0.03, ey - 0.005, 0.06, 0.05)), with: .color(.white))
                    ctx.fill(Path(ellipseIn: R(x - 0.015, ey, 0.03, 0.04)), with: .color(eyeColor))
                default:
                    var p = Path(); p.move(to: CGPoint(x: w * (x - 0.028), y: ht * (ey + 0.03)))
                    p.addQuadCurve(to: CGPoint(x: w * (x + 0.028), y: ht * (ey + 0.03)), control: CGPoint(x: w * x, y: ht * (ey - 0.02)))
                    ctx.stroke(p, with: .color(eyeColor), lineWidth: max(1, w * 0.018))
                }
                Self.brow(ctx, g, x, (lk.brow ?? 0) % 5, browCol)
                if lk.lashes == true { Self.lashes(ctx, g, x) }
            }
            eye(cx - 0.085); eye(cx + 0.085)
            // cheeks + nose
            ctx.fill(Path(ellipseIn: R(cx - 0.17, ey + 0.07, 0.07, 0.04)), with: .color(Color.pink.opacity(blushA)))
            ctx.fill(Path(ellipseIn: R(cx + 0.10, ey + 0.07, 0.07, 0.04)), with: .color(Color.pink.opacity(blushA)))
            var nose = Path(); nose.move(to: CGPoint(x: w * cx, y: ht * (ey + 0.03))); nose.addQuadCurve(to: CGPoint(x: w * (cx + 0.015), y: ht * (ey + 0.10)), control: CGPoint(x: w * (cx - 0.012), y: ht * (ey + 0.085)))
            if (lk.nose ?? 0) % 4 == 0 {
                ctx.stroke(nose, with: .color(shade(skinV, 0.7)), lineWidth: max(0.8, w * 0.012))
            } else {
                Self.noseDraw(ctx, g, (lk.nose ?? 0) % 4, shade(skinV, 0.7))
            }
            Self.facialHair(ctx, g, lk.beard ?? 0, beardCol)
            if let lp = lk.lips { Self.lips(ctx, g, lp) }
            // mouth
            let my = ey + 0.14
            var m = Path()
            switch mouth {
            case 0: m.move(to: CGPoint(x: w * (cx - 0.05), y: ht * my)); m.addQuadCurve(to: CGPoint(x: w * (cx + 0.05), y: ht * my), control: CGPoint(x: w * cx, y: ht * (my + 0.05)))
            case 1: m.move(to: CGPoint(x: w * (cx - 0.04), y: ht * my)); m.addLine(to: CGPoint(x: w * (cx + 0.04), y: ht * my))
            case 2: m.move(to: CGPoint(x: w * (cx - 0.04), y: ht * (my + 0.01))); m.addQuadCurve(to: CGPoint(x: w * (cx + 0.06), y: ht * (my - 0.01)), control: CGPoint(x: w * (cx + 0.02), y: ht * (my + 0.04)))
            default:
                ctx.fill(Path(ellipseIn: R(cx - 0.045, my - 0.01, 0.09, 0.055)), with: .color(Color(red: 0.35, green: 0.1, blue: 0.12)))
                ctx.fill(Path(CGRect(x: w * (cx - 0.035), y: ht * (my - 0.005), width: w * 0.07, height: ht * 0.016)), with: .color(.white))
            }
            ctx.stroke(m, with: .color(Color(red: 0.45, green: 0.15, blue: 0.15)), lineWidth: max(1, w * 0.018))
            Self.faceDetails(ctx, g, lk, skinV)
            Self.drawMask(ctx, g, lk.mask ?? 0, accentCol, skin)
            // hats
            let hcV = Self.tops[lk.hatColor % Self.tops.count]
            let hcol = col(hcV), hdark = shade(hcV, 0.7)
            let gold = Color(red: 1, green: 0.82, blue: 0.25)
            switch lk.hat {
            case 1:
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.17)), radius: w * (headW / 2 + 0.02), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.closeSubpath()
                ctx.fill(p, with: .color(hcol))
                ctx.fill(Path(roundedRect: R(headX - 0.02, headY + 0.13, headW + 0.04, 0.07), cornerRadius: w * 0.02), with: .color(hdark))
                ctx.fill(Path(ellipseIn: R(cx - 0.025, headY - 0.07, 0.05, 0.05)), with: .color(hdark))
            case 2:
                var p = Path(); p.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.17)), radius: w * (headW / 2 + 0.015), startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                p.closeSubpath()
                ctx.fill(p, with: .color(hcol))
                ctx.fill(Path(roundedRect: R(cx - 0.02, headY + 0.145, headW / 2 + 0.12, 0.04), cornerRadius: w * 0.02), with: .color(hdark))
            case 3:
                var c = Path()
                c.move(to: CGPoint(x: w * (cx - 0.14), y: ht * 0.25)); c.addLine(to: CGPoint(x: w * (cx - 0.14), y: ht * 0.10))
                c.addLine(to: CGPoint(x: w * (cx - 0.07), y: ht * 0.17)); c.addLine(to: CGPoint(x: w * cx, y: ht * 0.07))
                c.addLine(to: CGPoint(x: w * (cx + 0.07), y: ht * 0.17)); c.addLine(to: CGPoint(x: w * (cx + 0.14), y: ht * 0.10))
                c.addLine(to: CGPoint(x: w * (cx + 0.14), y: ht * 0.25)); c.closeSubpath()
                ctx.fill(c, with: .color(gold))
                ctx.stroke(c, with: .color(Color(red: 0.7, green: 0.5, blue: 0.1)), lineWidth: max(0.8, w * 0.01))
                ctx.fill(Path(ellipseIn: R(cx - 0.018, 0.19, 0.036, 0.036)), with: .color(Color(red: 0.9, green: 0.15, blue: 0.3)))
            case 4:
                var c = Path(); c.move(to: CGPoint(x: w * (cx - 0.12), y: ht * 0.26)); c.addLine(to: CGPoint(x: w * (cx + 0.03), y: ht * 0.0)); c.addLine(to: CGPoint(x: w * (cx + 0.12), y: ht * 0.26)); c.closeSubpath()
                ctx.fill(c, with: .color(hcol))
                for k in 0..<3 {
                    ctx.fill(Path(ellipseIn: R(cx - 0.04 + Double(k) * 0.035, 0.17 - Double(k) * 0.05, 0.022, 0.022)), with: .color(.white.opacity(0.9)))
                }
                ctx.fill(Path(ellipseIn: R(cx + 0.005, -0.02, 0.05, 0.05)), with: .color(gold))
            case 5:
                ctx.fill(Path(roundedRect: R(cx - 0.13, 0.08, 0.26, 0.14), cornerRadius: w * 0.05), with: .color(hcol))
                ctx.fill(Path(CGRect(x: w * (cx - 0.13), y: ht * 0.17, width: w * 0.26, height: ht * 0.025)), with: .color(hdark))
                ctx.fill(Path(ellipseIn: R(cx - 0.27, 0.185, 0.54, 0.075)), with: .color(shade(hcV, 0.85)))
            case 6:
                var b = Path(); b.move(to: CGPoint(x: w * (cx - headW / 2 - 0.005), y: ht * (headY + 0.14)))
                b.addQuadCurve(to: CGPoint(x: w * (cx + headW / 2 + 0.005), y: ht * (headY + 0.14)), control: CGPoint(x: w * cx, y: ht * (headY + 0.08)))
                ctx.stroke(b, with: .color(hcol), lineWidth: max(2, w * 0.05))
                ctx.fill(Path(ellipseIn: R(cx + headW / 2 - 0.02, headY + 0.12, 0.05, 0.05)), with: .color(hdark))
            case 7:
                ctx.stroke(Path(ellipseIn: R(cx - 0.14, 0.07, 0.28, 0.07)), with: .color(gold.opacity(0.3)), lineWidth: max(3, w * 0.05))
                ctx.stroke(Path(ellipseIn: R(cx - 0.14, 0.07, 0.28, 0.07)), with: .color(gold), lineWidth: max(1.5, w * 0.022))
            case 8:
                ctx.fill(Path(ellipseIn: R(cx - 0.16, -0.08, 0.10, 0.30)), with: .color(.white.opacity(0.95)))
                ctx.fill(Path(ellipseIn: R(cx + 0.06, -0.08, 0.10, 0.30)), with: .color(.white.opacity(0.95)))
                ctx.fill(Path(ellipseIn: R(cx - 0.135, -0.03, 0.05, 0.2)), with: .color(Color(red: 1, green: 0.7, blue: 0.8)))
                ctx.fill(Path(ellipseIn: R(cx + 0.085, -0.03, 0.05, 0.2)), with: .color(Color(red: 1, green: 0.7, blue: 0.8)))
            case 9:
                var l = Path(); l.move(to: CGPoint(x: w * (cx - 0.19), y: ht * 0.28)); l.addLine(to: CGPoint(x: w * (cx - 0.15), y: ht * 0.07)); l.addLine(to: CGPoint(x: w * (cx - 0.03), y: ht * 0.2)); l.closeSubpath()
                var r = Path(); r.move(to: CGPoint(x: w * (cx + 0.19), y: ht * 0.28)); r.addLine(to: CGPoint(x: w * (cx + 0.15), y: ht * 0.07)); r.addLine(to: CGPoint(x: w * (cx + 0.03), y: ht * 0.2)); r.closeSubpath()
                ctx.fill(l, with: .color(hcol)); ctx.fill(r, with: .color(hcol))
                var li = Path(); li.move(to: CGPoint(x: w * (cx - 0.16), y: ht * 0.24)); li.addLine(to: CGPoint(x: w * (cx - 0.145), y: ht * 0.12)); li.addLine(to: CGPoint(x: w * (cx - 0.07), y: ht * 0.2)); li.closeSubpath()
                var ri = Path(); ri.move(to: CGPoint(x: w * (cx + 0.16), y: ht * 0.24)); ri.addLine(to: CGPoint(x: w * (cx + 0.145), y: ht * 0.12)); ri.addLine(to: CGPoint(x: w * (cx + 0.07), y: ht * 0.2)); ri.closeSubpath()
                ctx.fill(li, with: .color(Color(red: 1, green: 0.7, blue: 0.8))); ctx.fill(ri, with: .color(Color(red: 1, green: 0.7, blue: 0.8)))
            case 10:
                ctx.fill(Path(roundedRect: R(cx - 0.14, -0.04, 0.28, 0.24), cornerRadius: w * 0.02), with: .color(Color(white: 0.1)))
                ctx.fill(Path(CGRect(x: w * (cx - 0.14), y: ht * 0.14, width: w * 0.28, height: ht * 0.035)), with: .color(hcol))
                ctx.fill(Path(roundedRect: R(cx - 0.23, 0.18, 0.46, 0.05), cornerRadius: w * 0.02), with: .color(Color(white: 0.08)))
            case 11:
                var c = Path(); c.move(to: CGPoint(x: w * (cx - 0.17), y: ht * 0.23)); c.addLine(to: CGPoint(x: w * (cx + 0.05), y: ht * -0.12)); c.addLine(to: CGPoint(x: w * (cx + 0.17), y: ht * 0.23)); c.closeSubpath()
                ctx.fill(c, with: .color(hcol))
                ctx.fill(Path(ellipseIn: R(cx - 0.25, 0.19, 0.50, 0.07)), with: .color(hdark))
                Self.glyph(ctx, "star.fill", at: CGPoint(x: w * (cx - 0.01), y: ht * 0.13), size: w * 0.07, color: gold)
                Self.glyph(ctx, "star.fill", at: CGPoint(x: w * (cx + 0.07), y: ht * 0.05), size: w * 0.04, color: gold)
            case 12:
                var l = Path(); l.move(to: CGPoint(x: w * (cx - 0.15), y: ht * 0.25)); l.addLine(to: CGPoint(x: w * (cx - 0.17), y: ht * 0.09)); l.addLine(to: CGPoint(x: w * (cx - 0.06), y: ht * 0.2)); l.closeSubpath()
                var r = Path(); r.move(to: CGPoint(x: w * (cx + 0.15), y: ht * 0.25)); r.addLine(to: CGPoint(x: w * (cx + 0.17), y: ht * 0.09)); r.addLine(to: CGPoint(x: w * (cx + 0.06), y: ht * 0.2)); r.closeSubpath()
                ctx.fill(l, with: .color(Color(red: 0.85, green: 0.12, blue: 0.15))); ctx.fill(r, with: .color(Color(red: 0.85, green: 0.12, blue: 0.15)))
            default: break
            }
            Self.hatExtra(ctx, g, lk.hat, hcol, hdark)
            // accessories
            if specKind == 1 {
                let lw = max(1, w * 0.014)
                ctx.stroke(Path(ellipseIn: R(cx - 0.135, ey - 0.012, 0.10, 0.07)), with: .color(.black.opacity(0.85)), lineWidth: lw)
                ctx.stroke(Path(ellipseIn: R(cx + 0.035, ey - 0.012, 0.10, 0.07)), with: .color(.black.opacity(0.85)), lineWidth: lw)
                var br = Path(); br.move(to: CGPoint(x: w * (cx - 0.035), y: ht * (ey + 0.02))); br.addLine(to: CGPoint(x: w * (cx + 0.035), y: ht * (ey + 0.02)))
                ctx.stroke(br, with: .color(.black.opacity(0.85)), lineWidth: lw)
            } else if specKind == 2 {
                ctx.fill(Path(roundedRect: R(cx - 0.145, ey - 0.015, 0.115, 0.07), cornerRadius: w * 0.025), with: .color(Color(white: 0.04).opacity(0.94)))
                ctx.fill(Path(roundedRect: R(cx + 0.03, ey - 0.015, 0.115, 0.07), cornerRadius: w * 0.025), with: .color(Color(white: 0.04).opacity(0.94)))
                var br = Path(); br.move(to: CGPoint(x: w * (cx - 0.03), y: ht * (ey + 0.01))); br.addLine(to: CGPoint(x: w * (cx + 0.03), y: ht * (ey + 0.01)))
                ctx.stroke(br, with: .color(Color(white: 0.04)), lineWidth: max(1, w * 0.016))
                var sh = Path(); sh.move(to: CGPoint(x: w * (cx - 0.12), y: ht * (ey + 0.005))); sh.addLine(to: CGPoint(x: w * (cx - 0.09), y: ht * (ey + 0.005)))
                sh.move(to: CGPoint(x: w * (cx + 0.055), y: ht * (ey + 0.005))); sh.addLine(to: CGPoint(x: w * (cx + 0.085), y: ht * (ey + 0.005)))
                ctx.stroke(sh, with: .color(.white.opacity(0.35)), lineWidth: max(0.8, w * 0.01))
            } else if specKind == 3 {
                let vis = Path(roundedRect: R(cx - 0.20, ey - 0.02, 0.40, 0.075), cornerRadius: w * 0.037)
                ctx.fill(vis, with: .linearGradient(Gradient(colors: [Color.cyan.opacity(0.85), Color(red: 0.7, green: 0.3, blue: 1).opacity(0.85)]), startPoint: CGPoint(x: w * (cx - 0.2), y: ht * ey), endPoint: CGPoint(x: w * (cx + 0.2), y: ht * ey)))
                ctx.stroke(vis, with: .color(.white.opacity(0.5)), lineWidth: max(0.8, w * 0.01))
            }
            Self.jewelry(ctx, g, lk, ring)
            if phones {
                var band = Path(); band.addArc(center: CGPoint(x: w * cx, y: ht * (headY + 0.22)), radius: w * (headW / 2 + 0.03), startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
                ctx.stroke(band, with: .color(Color(white: 0.12)), lineWidth: max(1.5, w * 0.03))
                ctx.fill(Path(roundedRect: R(headX - 0.055, headY + 0.17, 0.065, 0.14), cornerRadius: w * 0.03), with: .color(Color(white: 0.12)))
                ctx.fill(Path(roundedRect: R(headX + headW - 0.01, headY + 0.17, 0.065, 0.14), cornerRadius: w * 0.03), with: .color(Color(white: 0.12)))
            }
            if !faceOnly {
                Self.drawFrame(ctx, sz, lk.frame ?? 0, accentCol, t)
                Self.sticker(ctx, sz, lk.sticker ?? 0)
            }
        }
    }

    static func drawBG(_ ctx: GraphicsContext, _ sz: CGSize, _ c0: Color, _ c1: Color, _ accent: Color, _ anim: Int, _ t: Double) {
        let w = sz.width, h = sz.height
        let full = Path(CGRect(origin: .zero, size: sz))
        if anim == 8 {
            let a = t * 0.12
            var cols: [Color] = []
            for i in 0..<4 { cols.append(Color(hue: frac(a + Double(i) * 0.18), saturation: 0.7, brightness: 0.8)) }
            ctx.fill(full, with: .linearGradient(Gradient(colors: cols), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
            return
        }
        ctx.fill(full, with: .linearGradient(Gradient(colors: [c0, c1]), startPoint: .zero, endPoint: CGPoint(x: w, y: h)))
        switch anim {
        case 1: // aurora
            for i in 0..<3 {
                let p = t * 0.5 + Double(i) * 2.1
                let cx = w * (0.5 + 0.35 * sin(p)), cy = h * (0.4 + 0.25 * cos(p * 0.8))
                let hue = frac(0.45 + Double(i) * 0.17 + t * 0.03)
                let r = w * 0.55
                let c = Color(hue: hue, saturation: 0.8, brightness: 1).opacity(0.55)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [c, Color.clear]), center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r))
            }
        case 2: // twinkling stars
            for i in 0..<20 {
                let sx = frac(Double(i) * 0.618 + 0.13) * w, sy = frac(Double(i) * 0.371 + 0.27) * h
                let tw = 0.5 + 0.5 * sin(t * 2.2 + Double(i) * 1.7)
                let r = w * (0.008 + 0.014 * tw)
                ctx.fill(Path(ellipseIn: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)), with: .color(Color.white.opacity(0.3 + 0.7 * tw)))
            }
        case 3: // matrix rain
            for i in 0..<9 {
                let x = w * (Double(i) + 0.5) / 9
                let sp = 0.35 * (0.6 + frac(Double(i) * 0.37))
                let head = (frac(t * sp + Double(i) * 0.31) * 1.4 - 0.2) * h
                for k in 0..<6 {
                    let y = head - Double(k) * h * 0.07
                    let a = 1.0 - Double(k) / 6.0
                    ctx.fill(Path(CGRect(x: x - w * 0.015, y: y, width: w * 0.03, height: h * 0.05)), with: .color(Color(red: 0.2, green: 1, blue: 0.4).opacity(a * 0.8)))
                }
            }
        case 4: // bubbles
            for i in 0..<10 {
                let f = frac(Double(i) * 0.53)
                let y = h * (1.1 - frac(t * 0.12 * (0.5 + f) + Double(i) * 0.19) * 1.2)
                let x = w * (frac(Double(i) * 0.47 + 0.1) + 0.03 * sin(t + Double(i)))
                let r = w * (0.025 + 0.03 * f)
                ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color.white.opacity(0.5)), lineWidth: max(0.8, w * 0.008))
            }
        case 5: // pulse rings
            for i in 0..<3 {
                let k = frac(t * 0.4 + Double(i) / 3.0)
                let r = k * w * 0.9
                ctx.stroke(Path(ellipseIn: CGRect(x: w / 2 - r, y: h / 2 - r, width: r * 2, height: r * 2)), with: .color(accent.opacity(1 - k)), lineWidth: max(1, w * 0.02))
            }
        case 6: // scanlines + glitch
            var y = 0.0
            var ln = Path()
            while y < h { ln.move(to: CGPoint(x: 0, y: y)); ln.addLine(to: CGPoint(x: w, y: y)); y += h * 0.045 }
            ctx.stroke(ln, with: .color(Color.white.opacity(0.07)), lineWidth: 1)
            let by = frac(t * 0.3) * h
            ctx.fill(Path(CGRect(x: 0, y: by, width: w, height: h * 0.12)), with: .color(Color.white.opacity(0.08)))
            if frac(t * 0.7) < 0.12 {
                let gy = frac(t * 3.1) * h
                ctx.fill(Path(CGRect(x: w * 0.1, y: gy, width: w * 0.8, height: h * 0.04)), with: .color(Color.cyan.opacity(0.35)))
                ctx.fill(Path(CGRect(x: -w * 0.05, y: gy + h * 0.05, width: w * 0.7, height: h * 0.025)), with: .color(Color.pink.opacity(0.35)))
            }
        case 7: // embers
            ctx.fill(full, with: .linearGradient(Gradient(colors: [Color.clear, Color(red: 1, green: 0.3, blue: 0.05).opacity(0.45)]), startPoint: CGPoint(x: 0, y: h * 0.4), endPoint: CGPoint(x: 0, y: h)))
            for i in 0..<16 {
                let f = frac(Double(i) * 0.53)
                let k = frac(t * 0.2 * (0.6 + f) + Double(i) * 0.13)
                let y = h * (1.05 - k * 1.1)
                let x = w * (frac(Double(i) * 0.53 + 0.07) + 0.05 * sin(t * 2 + Double(i)))
                let r = w * (0.008 + 0.014 * f)
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color(red: 1, green: 0.55 + 0.4 * f, blue: 0.1).opacity(1 - k)))
            }
        default: drawBG2(ctx, sz, accent, anim, t)
        }
    }
}
