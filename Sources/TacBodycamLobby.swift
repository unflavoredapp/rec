import SwiftUI

/// dusk battlefield behind the lobby: sunset sky, mountains, watchtower, helicopter, wet ground
struct BodycamBackdrop: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.03, green: 0.035, blue: 0.045), Color(red: 0.1, green: 0.115, blue: 0.135), Color(red: 0.34, green: 0.3, blue: 0.27), Color(red: 0.7, green: 0.5, blue: 0.32)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.58)))
            // sun glow
            ctx.fill(Path(ellipseIn: CGRect(x: w * 0.3, y: h * 0.1, width: w * 0.7, height: w * 0.7)), with: .radialGradient(
                Gradient(colors: [Color(red: 0.95, green: 0.62, blue: 0.34).opacity(0.4), .clear]), center: CGPoint(x: w * 0.66, y: h * 0.5), startRadius: 0, endRadius: w * 0.32))
            // cloud bands
            for i in 0..<7 {
                let y = h * (0.08 + 0.065 * CGFloat(i))
                let x = w * (0.1 + 0.11 * CGFloat((i * 5) % 7))
                ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: w * 0.5, height: h * 0.035)), with: .color(Color.black.opacity(0.22)))
                ctx.fill(Path(ellipseIn: CGRect(x: x + w * 0.1, y: y + h * 0.012, width: w * 0.4, height: h * 0.02)), with: .color(Color(red: 0.9, green: 0.6, blue: 0.4).opacity(0.07)))
            }
            // mountains
            var m = Path()
            m.move(to: CGPoint(x: 0, y: h * 0.62))
            let peaks: [(CGFloat, CGFloat)] = [(0.08, 0.52), (0.2, 0.46), (0.3, 0.55), (0.42, 0.44), (0.52, 0.5), (0.64, 0.41), (0.76, 0.5), (0.88, 0.45), (1.0, 0.54)]
            for p in peaks { m.addLine(to: CGPoint(x: w * p.0, y: h * p.1)) }
            m.addLine(to: CGPoint(x: w, y: h * 0.66)); m.addLine(to: CGPoint(x: 0, y: h * 0.66)); m.closeSubpath()
            ctx.fill(m, with: .linearGradient(Gradient(colors: [Color(red: 0.11, green: 0.115, blue: 0.13), Color(red: 0.05, green: 0.055, blue: 0.065)]), startPoint: CGPoint(x: 0, y: h * 0.4), endPoint: CGPoint(x: 0, y: h * 0.66)))
            // watchtower
            let tx = w * 0.84, tb = h * 0.7
            ctx.fill(Path(CGRect(x: tx, y: h * 0.2, width: w * 0.07, height: tb - h * 0.2)), with: .color(Color(red: 0.1, green: 0.11, blue: 0.14)))
            ctx.fill(Path(CGRect(x: tx - w * 0.012, y: h * 0.17, width: w * 0.094, height: h * 0.07)), with: .color(Color(red: 0.08, green: 0.09, blue: 0.12)))
            ctx.fill(Path(CGRect(x: tx + w * 0.035, y: h * 0.1, width: 2, height: h * 0.08)), with: .color(Color(red: 0.08, green: 0.09, blue: 0.12)))
            // helicopter
            let hx = w * 0.56, hy = h * 0.5, hs = max(0.9, w / 520)
            let hc = Color(red: 0.05, green: 0.06, blue: 0.08)
            ctx.fill(Path(ellipseIn: CGRect(x: hx, y: hy, width: 70 * hs, height: 22 * hs)), with: .color(hc))
            ctx.fill(Path(CGRect(x: hx + 60 * hs, y: hy + 5 * hs, width: 52 * hs, height: 6 * hs)), with: .color(hc))
            ctx.fill(Path(CGRect(x: hx + 106 * hs, y: hy - 8 * hs, width: 4 * hs, height: 20 * hs)), with: .color(hc))
            ctx.fill(Path(CGRect(x: hx - 24 * hs, y: hy - 4 * hs, width: 118 * hs, height: 2.5 * hs)), with: .color(hc.opacity(0.9)))
            ctx.fill(Path(CGRect(x: hx + 34 * hs, y: hy - 4 * hs, width: 3 * hs, height: 6 * hs)), with: .color(hc))
            // wet ground with a bright reflection streak
            ctx.fill(Path(CGRect(x: 0, y: h * 0.66, width: w, height: h * 0.34)), with: .linearGradient(
                Gradient(colors: [Color(red: 0.19, green: 0.17, blue: 0.16), Color(red: 0.05, green: 0.05, blue: 0.06)]),
                startPoint: CGPoint(x: 0, y: h * 0.66), endPoint: CGPoint(x: 0, y: h)))
            var streak = Path()
            streak.move(to: CGPoint(x: w * 0.6, y: h * 0.66)); streak.addLine(to: CGPoint(x: w * 0.72, y: h * 0.66))
            streak.addLine(to: CGPoint(x: w * 0.68, y: h)); streak.addLine(to: CGPoint(x: w * 0.4, y: h)); streak.closeSubpath()
            ctx.fill(streak, with: .linearGradient(Gradient(colors: [Color(red: 0.9, green: 0.62, blue: 0.38).opacity(0.28), .clear]), startPoint: CGPoint(x: 0, y: h * 0.66), endPoint: CGPoint(x: 0, y: h)))
            // cargo cases in the foreground
            for (x, y, cw, ch) in [(0.74, 0.8, 0.14, 0.14), (0.88, 0.74, 0.13, 0.2), (0.6, 0.9, 0.1, 0.1)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                ctx.fill(Path(CGRect(x: w * x, y: h * y, width: w * cw, height: h * ch)), with: .color(Color(red: 0.07, green: 0.075, blue: 0.09)))
                ctx.fill(Path(CGRect(x: w * x, y: h * y, width: w * cw, height: 2)), with: .color(Color.white.opacity(0.12)))
            }
        }
        .saturation(0.55)
        .overlay(LinearGradient(colors: [Color.black.opacity(0.82), Color.black.opacity(0.15), Color.black.opacity(0.4)], startPoint: .leading, endPoint: .trailing))
        .overlay(LinearGradient(colors: [Color.black.opacity(0.6), .clear, Color.black.opacity(0.6)], startPoint: .top, endPoint: .bottom))
        .overlay(BodycamGrain())
        .overlay(BodycamOSD())
        .ignoresSafeArea()
    }
}

/// film grain + scanlines, drawn once (cheap) and flickered slightly
struct BodycamGrain: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.12)) { tl in
            Canvas { ctx, sz in
                var s = UInt64(truncatingIfNeeded: Int(tl.date.timeIntervalSinceReferenceDate * 8) % 5) &+ 17
                func rnd() -> CGFloat { s = s &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((s >> 40) & 1023) / 1023 }
                for _ in 0..<420 {
                    let x = rnd() * sz.width, y = rnd() * sz.height, a = 0.05 + rnd() * 0.08
                    ctx.fill(Path(CGRect(x: x, y: y, width: 1.6, height: 1.6)), with: .color(Color.white.opacity(a)))
                }
                var y: CGFloat = 0
                while y < sz.height { ctx.fill(Path(CGRect(x: 0, y: y, width: sz.width, height: 1)), with: .color(Color.black.opacity(0.16))); y += 3 }
                ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .radialGradient(Gradient(colors: [.clear, Color.black.opacity(0.55)]), center: CGPoint(x: sz.width / 2, y: sz.height / 2), startRadius: sz.width * 0.25, endRadius: sz.width * 0.72))
            }
        }
        .allowsHitTesting(false)
    }
}

/// bodycam on-screen display: camera id, live timestamp, battery
struct BodycamOSD: View {
    private static let f: DateFormatter = { let d = DateFormatter(); d.dateFormat = "yyyy-MM-dd  HH:mm:ss"; return d }()
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    Text("CAM-01  \(Self.f.string(from: tl.date))").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                Text("BATTLECAM  //  AXON-STYLE FEED").font(.system(size: 8, weight: .semibold, design: .monospaced)).foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 14).padding(.bottom, 4)
        }
        .allowsHitTesting(false)
    }
}

/// thin corner brackets, the viewfinder look used on panels
struct CornerBrackets: ViewModifier {
    var col: Color = Color.white.opacity(0.55)
    var len: CGFloat = 8
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { g in
                Path { p in
                    let w = g.size.width, h = g.size.height
                    for (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                        p.move(to: CGPoint(x: x + dx * len, y: y)); p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + dy * len))
                    }
                }
                .stroke(col, lineWidth: 1.2)
            }
            .allowsHitTesting(false)
        )
    }
}

extension View {
    func tacBrackets(_ col: Color = Color.white.opacity(0.55), len: CGFloat = 8) -> some View { modifier(CornerBrackets(col: col, len: len)) }
}

// MARK: - shell: top navigation around every lobby page

struct LobbyShell<Content: View>: View {
    @EnvironmentObject var game: Game
    let active: Int
    let size: CGSize
    let t: TacData
    let act: (LobbyAct) -> Void
    let content: Content

    init(active: Int, size: CGSize, t: TacData, act: @escaping (LobbyAct) -> Void, @ViewBuilder content: () -> Content) {
        self.active = active; self.size = size; self.t = t; self.act = act; self.content = content()
    }

    /// label, nav index understood by LobbyView
    private let items: [(String, Int)] = [("PLAY", 0), ("LOADOUT", 2), ("ARMORY", 3), ("EDITOR", 8), ("OPERATORS", 1), ("BARRACKS", 4), ("STORE", 6)]

    private func navItem(_ it: (String, Int)) -> some View {
        let on = it.1 == active
        return Button { act(.nav(it.1)) } label: {
            Text(it.0).font(.jk(10, .semibold)).foregroundColor(on ? LS.orange : .white.opacity(0.78)).lineLimit(1).fixedSize()
                .padding(.horizontal, 7).frame(height: LS.topH)
                .overlay(alignment: .bottom) { Rectangle().fill(on ? LS.orange : .clear).frame(height: 2).padding(.horizontal, 6).padding(.bottom, 6) }
        }
        .buttonStyle(TuiPress())
    }

    var body: some View {
        let W = size.width, H = size.height
        let xp = TacRank.totalXP(t)
        let ri = TacRank.index(xp)
        let a = LS.area(size)
        return ZStack {
            BodycamBackdrop()
            content
                .frame(width: a.width, height: a.height)
                .position(x: a.width / 2, y: LS.topH + a.height / 2)
            HStack(spacing: 6) {
                HStack(spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 0.6)) { tl in
                        Rectangle().fill(Color(red: 0.07, green: 0.07, blue: 0.08)).frame(width: 24, height: 24)
                            .overlay(Circle().fill(Color(red: 0.95, green: 0.1, blue: 0.1)).frame(width: 11, height: 11).opacity(Int(tl.date.timeIntervalSinceReferenceDate / 0.6) % 2 == 0 ? 1 : 0.3))
                            .overlay(Rectangle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                    }
                    Text("BATTLECAM").font(.jk(15, .heavy)).foregroundColor(.white).lineLimit(1).fixedSize()
                }
                .padding(.trailing, 6)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) { ForEach(0..<items.count, id: \.self) { navItem(items[$0]) } }
                }
                Spacer(minLength: 0)
                Button { act(.ranks) } label: {
                    HStack(spacing: 7) {
                        PortraitAvatar(key: TacAvatar.myKey, size: 30, look: TacAvatar.look(for: TacAvatar.myKey).faceCopy)
                            .clipShape(Rectangle()).overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(TacProfile.name).font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1).frame(maxWidth: 70, alignment: .leading)
                            HStack(spacing: 4) {
                                Text("LVL \(ri + 1)").font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.75)).fixedSize()
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.white.opacity(0.2))
                                    Rectangle().fill(Color.white).frame(width: 52 * CGFloat(TacRank.progress(xp)))
                                }
                                .frame(width: 52, height: 3)
                            }
                        }
                    }
                }
                .buttonStyle(TuiPress())
                HStack(spacing: 4) {
                    Circle().fill(Color(red: 1, green: 0.7, blue: 0.1)).frame(width: 13, height: 13).overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    Text(game.s.ex.gems.formatted()).font(.jk(11, .semibold)).foregroundColor(.white).monospacedDigit().fixedSize()
                }
                Button { act(.screen(5)) } label: {
                    HStack(spacing: 4) {
                        SF("diamond.fill").font(.system(size: 12, weight: .bold)).foregroundColor(Color(red: 0.3, green: 0.7, blue: 1))
                        Text("\(t.rating)").font(.jk(11, .semibold)).foregroundColor(.white).monospacedDigit().fixedSize()
                    }
                }
                .buttonStyle(TuiPress())
                Button { act(.stats) } label: { SF("gearshape.fill").font(.system(size: 14)).foregroundColor(.white.opacity(0.85)) }.buttonStyle(TuiPress())
            }
            .padding(.horizontal, 12).frame(width: W, height: LS.topH)
            .background(LinearGradient(colors: [Color.black.opacity(0.7), Color.black.opacity(0.25)], startPoint: .top, endPoint: .bottom))
            .position(x: W / 2, y: LS.topH / 2)
            .frame(height: H, alignment: .top)
        }
    }
}

// MARK: - small shared pieces

struct LSPanel<C: View>: View {
    var title: String? = nil
    var trailing: String? = nil
    @ViewBuilder let content: () -> C

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = title {
                HStack {
                    Text(title).font(.jk(10, .heavy)).foregroundColor(.white)
                    Spacer()
                    if let tr = trailing { Text(tr).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.7)) }
                }
                .padding(.horizontal, 8).frame(height: 22)
            }
            content()
        }
        .background(Color(red: 0.05, green: 0.055, blue: 0.06).opacity(0.9))
        .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
        .tacBrackets()
    }
}

// MARK: - PLAY page

struct LobbyHome: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    @Binding var diff: Int
    let act: (LobbyAct) -> Void

    private let diffNames = ["EASY", "NORMAL", "HARD"]

    private var gunName: String { TWeapons.all.first(where: { $0.id == nav.tacGun })?.name ?? nav.tacGun.uppercased() }
    private var mapName: String { nav.tacMap == 5 ? TWorkshop.currentMap.name.uppercased() : TMap.mapNames[nav.tacMap == 6 ? 6 : 7] }

    private func mapCard(_ id: Int, _ title: String, _ tag: String, _ h: CGFloat) -> some View {
        let on = nav.tacMap == id
        return Button { nav.tacMap = id } label: {
            VStack(spacing: 2) {
                mapGlyph(id).frame(height: h * 0.46)
                Text(title).font(.jk(8, .heavy)).foregroundColor(on ? .black : .white).lineLimit(1).minimumScaleFactor(0.6)
                Text(tag).font(.jk(6, .semibold)).foregroundColor(on ? .black.opacity(0.7) : .white.opacity(0.6))
            }
            .padding(.horizontal, 3).frame(maxWidth: .infinity).frame(height: h)
            .background(on ? Color.white : Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.92))
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: on ? 1.5 : 1))
        }
        .buttonStyle(TuiPress())
    }

    /// tiny floor-plan glyph so each map reads at a glance
    private func mapGlyph(_ id: Int) -> some View {
        let on = nav.tacMap == id
        let c: Color = on ? .black.opacity(0.8) : .white.opacity(0.75)
        return Canvas { ctx, sz in
            var p = Path()
            let w = sz.width, h = sz.height
            switch id {
            case 7:   // 3x3 rooms with a stair column
                let x0 = w * 0.14, x1 = w * 0.86, y0 = 1.0, y1 = h - 1
                p.addRect(CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0))
                for i in 1...2 { let x = x0 + (x1 - x0) * CGFloat(i) / 3; p.move(to: CGPoint(x: x, y: y0)); p.addLine(to: CGPoint(x: x, y: y1)) }
                for i in 1...2 { let y = y0 + (y1 - y0) * CGFloat(i) / 3; p.move(to: CGPoint(x: x0, y: y)); p.addLine(to: CGPoint(x: x1, y: y)) }
            case 6:
                p.addRect(CGRect(x: 1, y: 1, width: w - 2, height: h - 2))
                p.move(to: CGPoint(x: w * 0.33, y: 1)); p.addLine(to: CGPoint(x: w * 0.33, y: h * 0.62))
                p.move(to: CGPoint(x: w * 0.66, y: h * 0.3)); p.addLine(to: CGPoint(x: w * 0.66, y: h - 1))
                p.move(to: CGPoint(x: 1, y: h * 0.62)); p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.62))
                p.move(to: CGPoint(x: w * 0.5, y: h * 0.3)); p.addLine(to: CGPoint(x: w - 1, y: h * 0.3))
            default:
                p.addRect(CGRect(x: w * 0.2, y: 1, width: w * 0.6, height: h - 2))
                p.move(to: CGPoint(x: w * 0.5, y: h * 0.3)); p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.7))
                p.move(to: CGPoint(x: w * 0.35, y: h * 0.5)); p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.5))
            }
            ctx.stroke(p, with: .color(c), lineWidth: 1.3)
        }
    }

    private var mapPicker: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("OPERATION").font(.jk(7, .semibold)).foregroundColor(.white.opacity(0.65))
                Spacer()
                Text(mapName).font(.jk(8, .heavy)).foregroundColor(LS.orange).lineLimit(1).minimumScaleFactor(0.6)
            }
            HStack(spacing: 4) {
                mapCard(7, "ANNEX", "CQC · 2 FLOORS", 52)
                mapCard(6, "BLOCK 9", "LARGE", 52)
                mapCard(5, "CUSTOM", "EDITOR", 52)
            }
        }
        .padding(6)
        .background(Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.92))
        .overlay(Rectangle().stroke(LS.orange.opacity(0.8), lineWidth: 1))
    }

    private func modeRow(_ mode: Int, _ icon: String, _ title: String, _ sub: String, art: Int, _ h: CGFloat) -> some View {
        let on = nav.tacMode == mode
        return Button { nav.tacMode = mode } label: {
            HStack(spacing: 0) {
                MiniArt(variant: art).frame(width: h * 1.7).clipped().overlay(Color.black.opacity(0.35))
                HStack(spacing: 9) {
                    SF(icon, "circle.fill").font(.system(size: 15, weight: .bold)).foregroundColor(.white.opacity(0.9)).frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.jk(12, .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                        Text(sub).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    SF("chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 10)
            }
            .frame(height: h)
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.92))
            .overlay(Rectangle().stroke(on ? Color.white.opacity(0.9) : LS.line, lineWidth: on ? 1.5 : 1))
            .overlay(alignment: .leading) { Rectangle().fill(on ? LS.orange : .clear).frame(width: 3) }
        }
        .buttonStyle(TuiPress())
    }

    private func hero(_ h: CGFloat) -> some View {
        let on = nav.tacMode == 0
        return Button { nav.tacMode = 0 } label: {
            ZStack(alignment: .bottomLeading) {
                MiniArt(variant: 1).saturation(0.4).opacity(0.65)
                LinearGradient(colors: [Color.black.opacity(0.1), Color.black.opacity(0.88)], startPoint: .top, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        Circle().fill(Color(red: 0.95, green: 0.1, blue: 0.1)).frame(width: 8, height: 8)
                        Text("REC").font(.jk(10, .semibold)).foregroundColor(.white)
                    }
                    Spacer(minLength: 0)
                    Text("BODY CAM").font(.jk(h * 0.27, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                    Text("LIVE FEED  //  TACTICAL  //  NO RESPAWN").font(.jk(9, .medium)).foregroundColor(.white.opacity(0.78)).lineLimit(1)
                    HStack(spacing: 8) {
                        Label("5v5", systemImage: "person.3.fill")
                        Text("|").opacity(0.4)
                        Label("TACTICAL", systemImage: "scope")
                        Text("|").opacity(0.4)
                        Label("OBJECTIVE", systemImage: "flag.fill")
                    }
                    .font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.85)).padding(.top, 3)
                }
                .padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                SF("chevron.right").font(.system(size: 14, weight: .semibold)).foregroundColor(.white.opacity(0.9)).padding(10).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
            .frame(height: h).clipped()
            .overlay(Rectangle().stroke(on ? Color.white : LS.line, lineWidth: on ? 1.5 : 1))
            .tacBrackets(on ? LS.orange : Color.white.opacity(0.5))
            .overlay(alignment: .leading) { Rectangle().fill(on ? LS.orange : .clear).frame(width: 3) }
        }
        .buttonStyle(TuiPress())
    }

    private func challenge(_ title: String, _ have: Int, _ need: Int, _ xp: Int, _ rh: CGFloat) -> some View {
        HStack(spacing: 9) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 2.5)
                Circle().trim(from: 0, to: CGFloat(have) / CGFloat(max(1, need))).stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(have)/\(need)").font(.jk(7, .semibold)).foregroundColor(.white.opacity(0.9))
            }
            .frame(width: rh * 0.78, height: rh * 0.78)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.jk(10, .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                Text("\(have)/\(need)").font(.jk(8, .medium)).foregroundColor(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Text("\(xp)").font(.jk(10, .medium)).foregroundColor(.white.opacity(0.85))
            Text("XP").font(.jk(7, .heavy)).foregroundColor(.white.opacity(0.9)).padding(.horizontal, 4).padding(.vertical, 2).overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1))
        }
        .padding(.horizontal, 10).frame(height: rh)
    }

    private func friend(_ name: String, _ status: String, _ col: Color, _ rh: CGFloat) -> some View {
        Button { act(.friends) } label: {
            HStack(spacing: 8) {
                PortraitAvatar(key: name, size: rh * 0.78).clipShape(Circle()).overlay(alignment: .bottomTrailing) { Circle().fill(LS.green).frame(width: 6, height: 6).overlay(Circle().stroke(Color.black, lineWidth: 1)) }
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).font(.jk(10, .semibold)).foregroundColor(.white).lineLimit(1)
                    Text("● \(status)").font(.jk(7, .medium)).foregroundColor(col)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).frame(height: rh)
        }
        .buttonStyle(TuiPress())
    }

    var body: some View {
        let W = size.width, H = size.height
        let lw = max(220, min(300, W * 0.34))
        let rw = max(210, min(270, W * 0.29))
        let gap: CGFloat = 5
        let heroH = max(78, H * 0.3)
        let rowH = max(40, H * 0.135)
        let loadH = max(60, H * 0.2)
        let rh = max(26, min(32, H * 0.085))
        let xp = TacRank.totalXP(t)
        return ZStack(alignment: .topLeading) {
            AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: TacRank.index(xp), gun: nav.tacGun)
                .frame(width: W * 0.42, height: H * 1.02)
                .position(x: W * 0.5, y: H * 0.5)
                .allowsHitTesting(false)
            // left column
            VStack(spacing: gap) {
                hero(heroH)
                modeRow(1, "person.2.fill", "TEAM DEATHMATCH", "5v5  |  FAST PACED", art: 2, rowH)
                modeRow(5, "flag.fill", "CONTROL POINT", "5v5  |  HOLD THREE ZONES", art: 0, rowH)
                Button { act(.loadout) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("SELECTED LOADOUT").font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.65))
                                Text(gunName).font(.jk(11, .semibold)).foregroundColor(.white)
                            }
                            Spacer()
                            SF("chevron.right").font(.system(size: 11, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                        }
                        HStack(spacing: 14) {
                            SF("scope").font(.system(size: 20)).foregroundColor(.white.opacity(0.9))
                            SF("smallcircle.filled.circle").font(.system(size: 15)).foregroundColor(.white.opacity(0.6))
                            SF("shield.lefthalf.filled").font(.system(size: 15)).foregroundColor(.white.opacity(0.6))
                            SF("bolt.fill").font(.system(size: 15)).foregroundColor(.white.opacity(0.6))
                            Spacer()
                        }
                    }
                    .padding(10).frame(height: loadH)
                    .background(Color(red: 0.05, green: 0.06, blue: 0.08).opacity(0.92)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                }
                .buttonStyle(TuiPress())
            }
            .frame(width: lw)
            .fixedSize(horizontal: false, vertical: true)
            .position(x: 8 + lw / 2, y: (heroH + rowH * 2 + loadH + gap * 3) / 2 + 4)
            // right column
            VStack(spacing: gap) {
                LSPanel(title: "DAILY CHALLENGES", trailing: "RESETS 12h") {
                    VStack(spacing: 0) {
                        challenge("Get 25 Kills", t.kills % 25, 25, 1000, rh)
                        challenge("Win 3 Matches", t.wins % 3, 3, 1500, rh)
                        challenge("Play 5 Matches", (t.wins + t.losses) % 5, 5, 1000, rh)
                    }
                }
                mapPicker
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Button { diff = i } label: {
                            Text(diffNames[i]).font(.jk(8, .semibold)).foregroundColor(diff == i ? .black : .white.opacity(0.85))
                                .frame(maxWidth: .infinity).frame(height: 20).background(diff == i ? Color.white : Color.white.opacity(0.12))
                        }
                        .buttonStyle(TuiPress())
                    }
                }
                Button { act(.screen(2)) } label: {
                    HStack {
                        Spacer()
                        Text("DEPLOY").font(.jk(20, .heavy)).foregroundColor(.black)
                        Spacer()
                        SF("chevron.right").font(.system(size: 15, weight: .black)).foregroundColor(.black)
                    }
                    .padding(.horizontal, 14).frame(height: max(34, H * 0.11))
                    .background(LS.orange)
                    .overlay(alignment: .leading) { Rectangle().fill(Color.black.opacity(0.4)).frame(width: 4) }
                    .tacBrackets(Color.black.opacity(0.5), len: 7)
                }
                .buttonStyle(TuiPress())
            }
            .frame(width: rw)
            .position(x: W - 8 - rw / 2, y: H / 2)
            // footer
            HStack(spacing: 10) {
                Button { act(.stats) } label: {
                    HStack(spacing: 5) { SF("gearshape.fill").font(.system(size: 10)); Text("Settings").font(.jk(9, .medium)) }.foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(TuiPress())
                Rectangle().fill(LS.line).frame(width: 1, height: 12)
                Button { act(.friends) } label: {
                    HStack(spacing: 5) { SF("bubble.left.fill").font(.system(size: 10)); Text("Tap to chat").font(.jk(9, .medium)) }.foregroundColor(.white.opacity(0.75))
                }
                .buttonStyle(TuiPress())
            }
            .position(x: 8 + 70, y: H - 10)
        }
        .onAppear {
            if ![0, 1, 5].contains(nav.tacMode) { nav.tacMode = 0 }
            if ![5, 6, 7].contains(nav.tacMap) { nav.tacMap = 7 }
        }
    }
}
