import SwiftUI
import UIKit

enum LobbyAct {
    case nav(Int), screen(Int), season(Int), avatar, friends, ranks, stats, loadout
}

/// shared look of the new lobby
enum LS {
    static let navy = Color(red: 0.04, green: 0.045, blue: 0.05)
    static let panel = Color(red: 0.065, green: 0.07, blue: 0.075)
    static let card = Color(red: 0.105, green: 0.11, blue: 0.115)
    static let orange = Color(red: 0.93, green: 0.5, blue: 0.1)
    static let orange2 = Color(red: 0.8, green: 0.4, blue: 0.06)
    static let green = Color(red: 0.36, green: 0.62, blue: 0.38)
    static let line = Color.white.opacity(0.16)
    static let navW: CGFloat = 0
    static let topH: CGFloat = 50

    static func area(_ size: CGSize) -> CGSize { CGSize(width: size.width - navW, height: size.height - topH) }
}

// MARK: - perks (apply to the player's own gun)

enum TPerk {
    static let names = ["Quick Hands", "Scavenger", "Hardline", "Tracker"]
    static let icons = ["hand.raised.fill", "shippingbox.fill", "shield.fill", "eye.fill"]
    static let info = ["Reload 15% faster", "+1 spare magazine", "Spawn with 130 armor", "Spot 30% further"]
    private static let key = "ms.perks"
    static var on: Set<Int> {
        get { Set((UserDefaults.standard.array(forKey: key) as? [Int]) ?? [0, 1]) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }
    static var reloadMul: CGFloat { on.contains(0) ? 0.85 : 1 }
    static var spareBonus: Int { on.contains(1) ? 1 : 0 }
    static var armor: CGFloat { on.contains(2) ? 130 : 100 }
    static var spotMul: CGFloat { on.contains(3) ? 1.3 : 1 }
}

// MARK: - backdrop (low-poly harbor at golden hour)

enum HarborArt {
    static let orange = Color(red: 0.9, green: 0.5, blue: 0.1)
    static let boxCols: [Color] = [Color(red: 0.85, green: 0.38, blue: 0.1), Color(red: 0.15, green: 0.38, blue: 0.75), Color(red: 0.72, green: 0.16, blue: 0.16),
                                   Color(red: 0.2, green: 0.55, blue: 0.32), Color(red: 0.85, green: 0.68, blue: 0.2), Color(red: 0.3, green: 0.5, blue: 0.7), Color(red: 0.55, green: 0.2, blue: 0.2)]

    static func box(_ ctx: GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: h)), with: .color(c))
        ctx.fill(Path(CGRect(x: x, y: y, width: w, height: max(1, h * 0.16))), with: .color(Color.white.opacity(0.2)))
        ctx.fill(Path(CGRect(x: x, y: y + h * 0.84, width: w, height: max(1, h * 0.16))), with: .color(Color.black.opacity(0.22)))
        if w > 10 {
            var r = Path()
            var k: CGFloat = 1
            while k < 5 { r.move(to: CGPoint(x: x + w * k / 5, y: y)); r.addLine(to: CGPoint(x: x + w * k / 5, y: y + h)); k += 1 }
            ctx.stroke(r, with: .color(Color.black.opacity(0.16)), lineWidth: 0.6)
        }
    }

    static func crane(_ ctx: GraphicsContext, x: CGFloat, top: CGFloat, base: CGFloat, s: CGFloat) {
        let steel = Color(red: 0.14, green: 0.23, blue: 0.36)
        let lt = Color(red: 0.32, green: 0.45, blue: 0.62)
        let hw = 16 * s
        ctx.fill(Path(CGRect(x: x - hw, y: top, width: 3 * s, height: base - top)), with: .color(steel))
        ctx.fill(Path(CGRect(x: x + hw - 3 * s, y: top, width: 3 * s, height: base - top)), with: .color(steel))
        var p = Path()
        let n = 7
        for i in 0..<n {
            let y0 = top + (base - top) * CGFloat(i) / CGFloat(n)
            let y1 = top + (base - top) * CGFloat(i + 1) / CGFloat(n)
            p.move(to: CGPoint(x: x - hw + 3 * s, y: y0)); p.addLine(to: CGPoint(x: x + hw - 3 * s, y: y1))
            p.move(to: CGPoint(x: x + hw - 3 * s, y: y0)); p.addLine(to: CGPoint(x: x - hw + 3 * s, y: y1))
        }
        ctx.stroke(p, with: .color(lt.opacity(0.7)), lineWidth: max(0.5, s * 0.9))
        ctx.fill(Path(CGRect(x: x - hw * 1.2, y: top - 7 * s, width: hw * 5.4, height: 5 * s)), with: .color(steel))
        ctx.fill(Path(CGRect(x: x - hw * 3.2, y: top - 7 * s, width: hw * 2.0, height: 5 * s)), with: .color(lt))
        ctx.fill(Path(CGRect(x: x - 6 * s, y: top - 14 * s, width: 12 * s, height: 9 * s)), with: .color(orange))
        ctx.fill(Path(CGRect(x: x + hw * 2.4, y: top - 4 * s, width: 7 * s, height: 4 * s)), with: .color(orange))
        var cab = Path()
        cab.move(to: CGPoint(x: x + hw * 2.4 + 3 * s, y: top)); cab.addLine(to: CGPoint(x: x + hw * 2.4 + 3 * s, y: base * 0.8))
        ctx.stroke(cab, with: .color(steel.opacity(0.8)), lineWidth: max(0.4, s * 0.6))
    }

    static func ship(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        var hull = Path()
        hull.move(to: CGPoint(x: x, y: y - h * 0.3))
        hull.addLine(to: CGPoint(x: x + w, y: y - h * 0.3))
        hull.addLine(to: CGPoint(x: x + w * 0.94, y: y))
        hull.addLine(to: CGPoint(x: x + w * 0.04, y: y))
        hull.closeSubpath()
        ctx.fill(hull, with: .color(Color(red: 0.13, green: 0.17, blue: 0.26)))
        ctx.fill(Path(CGRect(x: x + w * 0.04, y: y - h * 0.1, width: w * 0.9, height: h * 0.1)), with: .color(Color(red: 0.62, green: 0.18, blue: 0.16)))
        var i = 0
        var cx = x + w * 0.04
        while cx < x + w * 0.62 {
            for r in 0..<2 { box(ctx, cx, y - h * 0.3 - CGFloat(r + 1) * h * 0.2, w * 0.045, h * 0.19, boxCols[(i + r * 3) % boxCols.count]) }
            cx += w * 0.048; i += 1
        }
        ctx.fill(Path(CGRect(x: x + w * 0.7, y: y - h * 0.95, width: w * 0.2, height: h * 0.65)), with: .color(Color(red: 0.86, green: 0.88, blue: 0.9)))
        ctx.fill(Path(CGRect(x: x + w * 0.72, y: y - h * 0.82, width: w * 0.16, height: h * 0.06)), with: .color(Color(red: 0.2, green: 0.3, blue: 0.45)))
        ctx.fill(Path(CGRect(x: x + w * 0.76, y: y - h * 1.15, width: w * 0.06, height: h * 0.2)), with: .color(Color(red: 0.7, green: 0.2, blue: 0.15)))
    }

    static func heli(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, s: CGFloat) {
        let c = Color(red: 0.12, green: 0.16, blue: 0.22)
        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 26 * s, height: 10 * s)), with: .color(c))
        ctx.fill(Path(CGRect(x: x + 22 * s, y: y + 2 * s, width: 22 * s, height: 3 * s)), with: .color(c))
        ctx.fill(Path(CGRect(x: x + 40 * s, y: y - 3 * s, width: 2 * s, height: 8 * s)), with: .color(c))
        ctx.fill(Path(CGRect(x: x - 8 * s, y: y - 2 * s, width: 42 * s, height: 1.4 * s)), with: .color(c.opacity(0.8)))
    }

    static func cloud(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat, w: CGFloat, a: Double) {
        for (dx, dy, k) in [(0.0, 0.0, 1.0), (0.25, -0.18, 0.7), (0.55, 0.02, 0.85), (0.8, -0.1, 0.5)] as [(CGFloat, CGFloat, CGFloat)] {
            ctx.fill(Path(ellipseIn: CGRect(x: x + w * dx, y: y + w * dy * 0.3, width: w * 0.45 * k, height: w * 0.16 * k)), with: .color(Color.white.opacity(a)))
        }
    }
}

struct HarborBackdrop: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.2, green: 0.42, blue: 0.76), Color(red: 0.55, green: 0.7, blue: 0.88), Color(red: 0.98, green: 0.8, blue: 0.58)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.6)))
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.5, y: h * 0.25, width: w * 0.6, height: w * 0.6)), with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.88, blue: 0.62).opacity(0.65), .clear]), center: CGPoint(x: w * 0.82, y: h * 0.52), startRadius: 0, endRadius: w * 0.3))
            HarborArt.cloud(ctx, x: w * 0.08, y: h * 0.12, w: w * 0.28, a: 0.32)
            HarborArt.cloud(ctx, x: w * 0.4, y: h * 0.07, w: w * 0.22, a: 0.22)
            HarborArt.cloud(ctx, x: w * 0.62, y: h * 0.2, w: w * 0.3, a: 0.2)
            HarborArt.heli(ctx, x: w * 0.3, y: h * 0.18, s: max(0.8, w / 900))
            // water
            ctx.fill(Path(CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.14)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.36, green: 0.5, blue: 0.62), Color(red: 0.14, green: 0.28, blue: 0.42)]),
                startPoint: CGPoint(x: 0, y: h * 0.55), endPoint: CGPoint(x: 0, y: h * 0.69)))
            for i in 0..<14 {
                let yy = h * (0.57 + 0.008 * CGFloat(i))
                ctx.fill(Path(CGRect(x: w * (0.5 + 0.03 * CGFloat(i % 5)), y: yy, width: w * 0.12, height: 1)), with: .color(Color(red: 1, green: 0.9, blue: 0.7).opacity(0.18)))
            }
            HarborArt.ship(ctx, x: w * 0.2, y: h * 0.59, w: w * 0.3, h: h * 0.16)
            // cranes (far to near)
            let u = max(1.0, w / 700)
            for (i, cx) in ([0.18, 0.5, 0.66, 0.84, 0.97] as [CGFloat]).enumerated() {
                HarborArt.crane(ctx, x: w * cx, top: h * (0.14 + 0.03 * CGFloat(i % 3)), base: h * 0.69, s: u * (0.9 + 0.1 * CGFloat(i % 2)))
            }
            // background container yard
            var s: UInt64 = 11
            func rnd() -> Int { s = s &* 6364136223846793005 &+ 1442695040888963407; return Int(s >> 33) }
            let bw = 30 * u, bh = 15 * u
            for gx in stride(from: CGFloat(-8), to: w + 40, by: bw + 2) {
                let rows = 1 + rnd() % 3
                for r in 0..<rows {
                    HarborArt.box(ctx, gx, h * 0.69 - CGFloat(r + 1) * (bh + 1), bw, bh, HarborArt.boxCols[rnd() % HarborArt.boxCols.count].opacity(0.92))
                }
            }
            // foreground container stacks at the sides
            let fw = 54 * u, fh = 26 * u
            for (x0, cols) in [(CGFloat(-6), 4), (w - fw * 3.2, 3)] as [(CGFloat, Int)] {
                for c in 0..<3 {
                    let rows = max(1, cols - c)
                    for r in 0..<rows {
                        HarborArt.box(ctx, x0 + CGFloat(c) * (fw + 2), h * 0.78 - CGFloat(r + 1) * (fh + 1), fw, fh, HarborArt.boxCols[rnd() % HarborArt.boxCols.count])
                    }
                }
            }
            // paved ground
            ctx.fill(Path(CGRect(x: 0, y: h * 0.69, width: w, height: h * 0.31)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.6, green: 0.48, blue: 0.36), Color(red: 0.34, green: 0.28, blue: 0.23)]),
                startPoint: CGPoint(x: 0, y: h * 0.69), endPoint: CGPoint(x: 0, y: h)))
            var gp = Path()
            var yy = h * 0.69
            var step: CGFloat = 5
            while yy < h { gp.move(to: CGPoint(x: 0, y: yy)); gp.addLine(to: CGPoint(x: w, y: yy)); yy += step; step *= 1.35 }
            for k in -8...8 {
                gp.move(to: CGPoint(x: w * 0.5 + CGFloat(k) * w * 0.02, y: h * 0.69))
                gp.addLine(to: CGPoint(x: w * 0.5 + CGFloat(k) * w * 0.14, y: h))
            }
            ctx.stroke(gp, with: .color(Color.black.opacity(0.1)), lineWidth: 1)
        }
        .saturation(0.55)
        .overlay(LinearGradient(colors: [Color.black.opacity(0.1), Color.black.opacity(0.45)], startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
    }
}

struct LSTab: View {
    let icon: String?
    let label: String
    let on: Bool
    let act: () -> Void

    var body: some View {
        Button(action: act) {
            HStack(spacing: 6) {
                if let i = icon { SF(i, "circle.fill").font(.system(size: 12, weight: .bold)) }
                Text(label).font(.jk(12, .heavy))
            }
            .foregroundColor(on ? LS.orange : .white.opacity(0.65))
            .padding(.horizontal, 14).frame(height: 28)
            .background(on ? LS.orange.opacity(0.18) : Color.black.opacity(0.35))
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(TuiPress())
    }
}

struct LSTitle: View {
    let title: String
    let sub: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.jk(24, .heavy)).foregroundColor(.white)
            Text(sub).font(.jk(10, .medium)).foregroundColor(.white.opacity(0.75))
        }
        .shadow(color: .black.opacity(0.7), radius: 3)
    }
}

struct LSSmallButton: View {
    let icon: String
    let label: String
    var on = false
    let act: () -> Void

    var body: some View {
        Button(action: act) {
            HStack(spacing: 5) {
                SF(icon, "circle.fill").font(.system(size: 11, weight: .bold))
                Text(label).font(.jk(10, .semibold))
            }
            .foregroundColor(on ? LS.orange : .white.opacity(0.85))
            .padding(.horizontal, 9).frame(height: 26)
            .background(on ? LS.orange.opacity(0.18) : Color.black.opacity(0.45))
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [text], applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct RenameOverlay: View {
    @Binding var text: String
    let done: (Bool) -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { done(false) }
            VStack(spacing: 8) {
                Text("RENAME").font(.jk(12, .heavy)).foregroundColor(.white)
                TextField("Name", text: $text).textFieldStyle(.roundedBorder).frame(width: 240)
                HStack(spacing: 8) {
                    LSSmallButton(icon: "xmark", label: "CANCEL") { done(false) }
                    LSSmallButton(icon: "checkmark", label: "OK", on: true) { done(true) }
                }
            }
            .padding(14).background(LS.panel).overlay(Rectangle().stroke(LS.orange, lineWidth: 1))
        }
    }
}
