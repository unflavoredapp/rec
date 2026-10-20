import SwiftUI
import UIKit

// MARK: - Rank ladder

enum TacRank {
    enum Kind {
        case smile
        case chev(Int, Int)        // chevrons, rockers
        case bars(Bool, Int)       // gold?, count
        case leaves(Bool, Int)     // gold?, count
        case stars(Int)
    }

    struct Def {
        let name: String
        let xp: Int
        let kind: Kind
    }

    static let ranks: [Def] = [
        Def(name: "Trainee", xp: 0, kind: .smile),
        Def(name: "Private", xp: 100, kind: .chev(1, 0)),
        Def(name: "Private First Class", xp: 300, kind: .chev(1, 1)),
        Def(name: "Corporal", xp: 650, kind: .chev(2, 0)),
        Def(name: "Sergeant", xp: 1250, kind: .chev(3, 0)),
        Def(name: "Staff Sergeant", xp: 3750, kind: .chev(3, 1)),
        Def(name: "Sergeant First Class", xp: 8250, kind: .chev(3, 2)),
        Def(name: "Master Sergeant", xp: 15750, kind: .chev(3, 3)),
        Def(name: "Second Lieutenant", xp: 26750, kind: .bars(true, 1)),
        Def(name: "First Lieutenant", xp: 42750, kind: .bars(false, 1)),
        Def(name: "Captain", xp: 64750, kind: .bars(false, 2)),
        Def(name: "Major", xp: 94750, kind: .leaves(true, 1)),
        Def(name: "Lieutenant Colonel", xp: 134750, kind: .leaves(false, 1)),
        Def(name: "Colonel", xp: 186750, kind: .leaves(false, 2)),
        Def(name: "Brigadier General", xp: 252750, kind: .stars(1)),
        Def(name: "Major General", xp: 334750, kind: .stars(2)),
        Def(name: "Lieutenant General", xp: 434750, kind: .stars(3)),
        Def(name: "General", xp: 559750, kind: .stars(4)),
        Def(name: "Commander", xp: 714750, kind: .stars(5))
    ]

    /// bars under the insignia: each filled bar is a slice of the rank, so a Staff Sergeant with 4 bars has put in a lot of play
    static func pips(_ idx: Int) -> Int { idx == 0 ? 2 : 5 }

    static func pipsFilled(_ xp: Int) -> Int {
        let i = index(xp)
        if i >= ranks.count - 1 { return pips(i) }
        return min(pips(i), Int(progress(xp) * Double(pips(i))))
    }

    /// lifetime XP derived from saved stats (same formula as match rewards)
    static var prestigeCache = 0

    static let maxPrestige = 12

    /// P1 = 3x ... P12 = 14x
    static func mult(_ p: Int) -> Int { p <= 0 ? 1 : 2 + min(p, maxPrestige) }

    static let prestigeCols: [(Color, Color)] = [
        (Color(red: 0.42, green: 0.62, blue: 0.84), Color(red: 0.22, green: 0.38, blue: 0.62)),
        (Color(red: 0.4, green: 0.8, blue: 0.4), Color(red: 0.14, green: 0.45, blue: 0.2)),
        (Color(red: 0.9, green: 0.4, blue: 0.4), Color(red: 0.5, green: 0.12, blue: 0.14)),
        (Color(red: 0.7, green: 0.5, blue: 0.9), Color(red: 0.32, green: 0.16, blue: 0.5)),
        (Color(red: 0.95, green: 0.7, blue: 0.3), Color(red: 0.6, green: 0.35, blue: 0.08)),
        (Color(red: 0.4, green: 0.85, blue: 0.85), Color(red: 0.1, green: 0.4, blue: 0.45)),
        (Color(red: 0.95, green: 0.5, blue: 0.75), Color(red: 0.5, green: 0.15, blue: 0.38)),
        (Color(red: 0.85, green: 0.85, blue: 0.9), Color(red: 0.4, green: 0.42, blue: 0.5)),
        (Color(red: 0.7, green: 0.9, blue: 0.25), Color(red: 0.3, green: 0.5, blue: 0.05)),
        (Color(red: 0.75, green: 0.5, blue: 0.3), Color(red: 0.38, green: 0.2, blue: 0.08)),
        (Color(red: 0.35, green: 0.45, blue: 0.95), Color(red: 0.08, green: 0.12, blue: 0.45)),
        (Color(red: 0.9, green: 0.25, blue: 0.7), Color(red: 0.4, green: 0.05, blue: 0.3)),
        (Color(red: 0.3, green: 0.3, blue: 0.34), Color(red: 0.06, green: 0.06, blue: 0.08))
    ]

    static func totalXP(_ t: TacData) -> Int {
        prestigeCache = t.prestige ?? 0
        return max(0, (t.wins + t.losses) * 40 + t.kills * 10 + t.wins * 60 + (t.xpExtra ?? 0) - (t.xpBase ?? 0))
    }

    static func index(_ xp: Int) -> Int {
        var r = 0
        for (i, d) in ranks.enumerated() where xp >= d.xp { r = i }
        return r
    }

    /// 0...1 progress toward the next rank (1 at max)
    static func progress(_ xp: Int) -> Double {
        let i = index(xp)
        if i >= ranks.count - 1 { return 1 }
        let a = ranks[i].xp, b = ranks[i + 1].xp
        return min(1, max(0, Double(xp - a) / Double(max(1, b - a))))
    }

    static func toNext(_ xp: Int) -> Int {
        let i = index(xp)
        if i >= ranks.count - 1 { return 0 }
        return ranks[i + 1].xp - xp
    }
}

// MARK: - Player profile (local username)

enum TacProfile {
    private static let key = "ms.username.v1"

    static var name: String {
        if let s = UserDefaults.standard.string(forKey: key), !s.isEmpty { return s }
        let n = "Operator\(Int.random(in: 1000...9999))"
        UserDefaults.standard.set(n, forKey: key)
        return n
    }

    static func set(_ raw: String) {
        let c = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(14))
        if !c.isEmpty { UserDefaults.standard.set(c, forKey: key) }
    }
}

// MARK: - Shapes

struct TStar: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let big = min(r.width, r.height) / 2
        let small = big * 0.42
        for i in 0..<10 {
            let a = -Double.pi / 2 + Double(i) * Double.pi / 5
            let rr = i % 2 == 0 ? big : small
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

struct TChevron: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + h * 0.58))
        p.addLine(to: CGPoint(x: r.minX + w * 0.5, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX + w, y: r.minY + h * 0.58))
        p.addLine(to: CGPoint(x: r.minX + w, y: r.minY + h))
        p.addLine(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 0.42))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + h))
        p.closeSubpath()
        return p
    }
}

struct TRocker: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        let t = h * 0.42
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + w, y: r.minY), control: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 1.6))
        p.addLine(to: CGPoint(x: r.minX + w, y: r.minY + t))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + t), control: CGPoint(x: r.minX + w * 0.5, y: r.minY + h * 1.6 + t))
        p.closeSubpath()
        return p
    }
}

struct TLeaf: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + w * x, y: r.minY + h * y) }
        var p = Path()
        p.move(to: pt(0.5, 0))
        p.addCurve(to: pt(0.9, 0.38), control1: pt(0.62, 0.08), control2: pt(0.92, 0.18))
        p.addCurve(to: pt(0.8, 0.8), control1: pt(0.98, 0.52), control2: pt(0.96, 0.72))
        p.addCurve(to: pt(0.5, 1.0), control1: pt(0.7, 0.92), control2: pt(0.56, 0.96))
        p.addCurve(to: pt(0.2, 0.8), control1: pt(0.44, 0.96), control2: pt(0.3, 0.92))
        p.addCurve(to: pt(0.1, 0.38), control1: pt(0.04, 0.72), control2: pt(0.02, 0.52))
        p.addCurve(to: pt(0.5, 0), control1: pt(0.08, 0.18), control2: pt(0.38, 0.08))
        p.closeSubpath()
        return p
    }
}

struct TSmileMouth: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + r.width * 0.22, y: r.minY + r.height * 0.58))
        p.addQuadCurve(to: CGPoint(x: r.minX + r.width * 0.78, y: r.minY + r.height * 0.58),
                       control: CGPoint(x: r.midX, y: r.minY + r.height * 1.0))
        return p
    }
}

// MARK: - Insignia

struct TacInsignia: View {
    let idx: Int
    var size: CGFloat = 40

    private let gold = Color(red: 0.98, green: 0.82, blue: 0.27)
    private let goldEdge = Color(red: 0.45, green: 0.32, blue: 0.04)
    private let silver = Color(red: 0.88, green: 0.90, blue: 0.94)
    private let silverEdge = Color(red: 0.32, green: 0.35, blue: 0.40)
    private let green = Color(red: 0.05, green: 0.32, blue: 0.14)

    var body: some View {
        let d = TacRank.ranks[max(0, min(TacRank.ranks.count - 1, idx))]
        ZStack {
            switch d.kind {
            case .smile: smile
            case .chev(let c, let r): chevrons(c, r)
            case .bars(let g, let n): bars(g, n)
            case .leaves(let g, let n): leaves(g, n)
            case .stars(let n): stars(n)
            }
        }
        .frame(width: size, height: size)
    }

    private var smile: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.9, blue: 0.35), Color(red: 0.9, green: 0.68, blue: 0.1)], startPoint: .top, endPoint: .bottom))
            Circle().stroke(goldEdge.opacity(0.7), lineWidth: max(1, size * 0.03))
            Circle().fill(goldEdge).frame(width: size * 0.1, height: size * 0.13).offset(x: -size * 0.14, y: -size * 0.1)
            Circle().fill(goldEdge).frame(width: size * 0.1, height: size * 0.13).offset(x: size * 0.14, y: -size * 0.1)
            TSmileMouth().stroke(goldEdge, style: StrokeStyle(lineWidth: max(1.5, size * 0.055), lineCap: .round))
                .frame(width: size * 0.62, height: size * 0.5).offset(y: size * 0.08)
        }
        .frame(width: size * 0.82, height: size * 0.82)
    }

    private func chevrons(_ c: Int, _ r: Int) -> some View {
        let w = size * 0.74
        return VStack(spacing: size * 0.012) {
            ForEach(0..<c, id: \.self) { _ in
                ZStack {
                    TChevron().fill(LinearGradient(colors: [gold, Color(red: 0.84, green: 0.62, blue: 0.12)], startPoint: .top, endPoint: .bottom))
                    TChevron().stroke(green, lineWidth: max(1, size * 0.028))
                }
                .frame(width: w, height: size * 0.17)
            }
            ForEach(0..<r, id: \.self) { _ in
                ZStack {
                    TRocker().fill(gold)
                    TRocker().stroke(green, lineWidth: max(1, size * 0.024))
                }
                .frame(width: w, height: size * 0.075)
            }
        }
    }

    private func bars(_ g: Bool, _ n: Int) -> some View {
        HStack(spacing: size * 0.1) {
            ForEach(0..<n, id: \.self) { _ in
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.025, style: .continuous)
                        .fill(LinearGradient(colors: g ? [Color(red: 1, green: 0.92, blue: 0.4), Color(red: 0.9, green: 0.7, blue: 0.12)] : [Color.white, Color(red: 0.7, green: 0.73, blue: 0.78)], startPoint: .leading, endPoint: .trailing))
                    RoundedRectangle(cornerRadius: size * 0.025, style: .continuous)
                        .stroke(g ? goldEdge : silverEdge, lineWidth: max(1, size * 0.02))
                }
                .frame(width: size * 0.16, height: size * 0.62)
            }
        }
    }

    private func leaf(_ g: Bool, _ w: CGFloat) -> some View {
        ZStack {
            TLeaf().fill(LinearGradient(colors: g ? [Color(red: 1, green: 0.92, blue: 0.45), Color(red: 0.86, green: 0.62, blue: 0.1)] : [Color.white, Color(red: 0.66, green: 0.7, blue: 0.76)], startPoint: .topLeading, endPoint: .bottomTrailing))
            TLeaf().stroke(g ? goldEdge : silverEdge, lineWidth: max(1, size * 0.022))
            Path { p in
                p.move(to: CGPoint(x: w * 0.5, y: w * 0.16))
                p.addLine(to: CGPoint(x: w * 0.5, y: w * 0.9))
            }
            .stroke((g ? goldEdge : silverEdge).opacity(0.55), lineWidth: max(1, size * 0.018))
        }
        .frame(width: w, height: w)
    }

    private func leaves(_ g: Bool, _ n: Int) -> some View {
        HStack(spacing: -size * 0.02) {
            ForEach(0..<n, id: \.self) { _ in
                leaf(g, n == 1 ? size * 0.66 : size * 0.44)
            }
        }
    }

    private func star(_ s: CGFloat) -> some View {
        ZStack {
            TStar().fill(LinearGradient(colors: [Color.white, Color(red: 0.68, green: 0.72, blue: 0.78)], startPoint: .top, endPoint: .bottom))
            TStar().stroke(silverEdge, lineWidth: max(1, size * 0.02))
        }
        .frame(width: s, height: s)
    }

    private func stars(_ n: Int) -> some View {
        let s = size * (n == 1 ? 0.5 : (n == 2 ? 0.4 : 0.34))
        return Group {
            switch n {
            case 1: star(s)
            case 2: HStack(spacing: size * 0.04) { star(s); star(s) }
            case 3:
                VStack(spacing: -size * 0.02) {
                    star(s)
                    HStack(spacing: size * 0.04) { star(s); star(s) }
                }
            case 4:
                VStack(spacing: size * 0.02) {
                    HStack(spacing: size * 0.04) { star(s); star(s) }
                    HStack(spacing: size * 0.04) { star(s); star(s) }
                }
            default:
                VStack(spacing: -size * 0.02) {
                    HStack(spacing: size * 0.04) { star(s); star(s) }
                    star(s)
                    HStack(spacing: size * 0.04) { star(s); star(s) }
                }
            }
        }
    }
}

// MARK: - Tile (blue plate with name label + xp bar)

struct TacRankTile: View {
    let idx: Int
    var size: CGFloat = 64
    var progress: Double? = nil
    var locked = false
    var showName = true

    var body: some View {
        let d = TacRank.ranks[max(0, min(TacRank.ranks.count - 1, idx))]
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                
                .fill(LinearGradient(colors: [TacRank.prestigeCols[TacRank.prestigeCache % TacRank.prestigeCols.count].0, TacRank.prestigeCols[TacRank.prestigeCache % TacRank.prestigeCols.count].1], startPoint: .top, endPoint: .bottom))
            Canvas { ctx, sz in
                let step = sz.width / 5
                for i in 0..<5 {
                    for j in 0..<5 {
                        let r = CGRect(x: CGFloat(i) * step + step * 0.3, y: CGFloat(j) * step + step * 0.3, width: step * 0.4, height: step * 0.4)
                        ctx.fill(TStar().path(in: r), with: .color(.white.opacity(0.07)))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: size * 0.05, style: .continuous))
            VStack(spacing: 0) {
                if showName {
                    Text(d.name.uppercased())
                        .font(.system(size: max(5, size * 0.085), weight: .heavy))
                        .foregroundColor(Color(red: 0.08, green: 0.14, blue: 0.24).opacity(0.85))
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                        .frame(height: size * 0.22).padding(.horizontal, size * 0.04)
                } else {
                    Spacer().frame(height: size * 0.06)
                }
                TacInsignia(idx: idx, size: size * (showName ? 0.62 : 0.82))
                    .frame(maxHeight: .infinity)
                if let p = progress {
                    let n = TacRank.pips(idx)
                    HStack(spacing: max(1, size * 0.02)) {
                        ForEach(0..<n, id: \.self) { k in
                            let f = max(0, min(1, p * Double(n) - Double(k)))
                            ZStack(alignment: .leading) {
                                Rectangle().fill(Color.black.opacity(0.6))
                                GeometryReader { gg in
                                    Rectangle().fill(LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.3), Color(red: 0.9, green: 0.6, blue: 0.1)], startPoint: .top, endPoint: .bottom))
                                        .frame(width: gg.size.width * CGFloat(f))
                                }
                            }
                        }
                    }
                    .frame(width: size * 0.84, height: max(3, size * 0.055)).padding(.bottom, size * 0.05)
                } else {
                    Spacer().frame(height: size * 0.06)
                }
            }
            RoundedRectangle(cornerRadius: size * 0.05, style: .continuous).stroke(Color.black.opacity(0.7), lineWidth: 1.5)
            RoundedRectangle(cornerRadius: size * 0.05, style: .continuous).inset(by: 1.5).stroke(Color.white.opacity(0.18), lineWidth: 1)
            if TacRank.prestigeCache > 0 && size >= 40 {
                Text("P\(TacRank.prestigeCache)").font(.system(size: max(7, size * 0.14), weight: .black)).foregroundColor(.white)
                    .padding(.horizontal, 3).background(Capsule().fill(Color.black.opacity(0.65)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(2)
            }
            if locked {
                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous).fill(Color.black.opacity(0.55))
                SF("lock.fill").font(.system(size: size * 0.2, weight: .bold)).foregroundColor(.white.opacity(0.55))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Ranks sheet (all ranks + username editor)

struct TacRankSheet: View {
    let t: TacData
    @Binding var username: String
    var onPrestige: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    private func stat(_ label: String, _ value: String, _ col: Color = .white) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.jk(20, .heavy)).foregroundColor(col).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.jk(9, .heavy)).tracking(1).foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(Color.white.opacity(0.07))
        .overlay(Rectangle().stroke(Color.white.opacity(0.15), lineWidth: 1))
    }

    /// rank, league, record and the last matches
    @ViewBuilder private func profileCard(_ t: TacData) -> some View {
        let games = t.wins + t.losses
        let pct = games == 0 ? 0 : Int((Double(t.wins) / Double(games) * 100).rounded())
        let li = TacLeague.index(t.rating)
        let nextLeague: (String, Int)? = li + 1 < TacLeague.all.count ? (TacLeague.all[li + 1].0, TacLeague.all[li + 1].1) : nil
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    LeagueShield().fill(TacLeague.color(t.rating)).frame(width: 44, height: 52)
                    LeagueShield().stroke(Color.black.opacity(0.6), lineWidth: 1.5).frame(width: 44, height: 52)
                    Text("\(li + 1)").font(.jk(16, .heavy)).foregroundColor(.black.opacity(0.8))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("LEAGUE").font(.jk(9, .heavy)).tracking(1).foregroundColor(.white.opacity(0.55))
                    Text(TacLeague.name(t.rating)).font(.jk(20, .heavy)).foregroundColor(TacLeague.color(t.rating))
                    Text("\(t.rating) RATING" + (nextLeague.map { "  ·  \($0.1 - t.rating) TO \($0.0)" } ?? "  ·  TOP LEAGUE"))
                        .font(.jk(11, .bold)).foregroundColor(.white.opacity(0.65))
                }
            }
            HStack(spacing: 6) {
                stat("WINS", "\(t.wins)", TUI.green)
                stat("LOSSES", "\(t.losses)", TUI.red)
                stat("WIN %", "\(pct)%")
                stat("KILLS", "\(t.kills)")
                stat("K / MATCH", games == 0 ? "0.0" : String(format: "%.1f", Double(t.kills) / Double(games)))
            }
            Text("RECENT MATCHES").font(.jk(11, .heavy)).tracking(1).foregroundColor(.white.opacity(0.7)).padding(.top, 2)
            if (t.recent ?? []).isEmpty {
                Text("No matches yet. Finish a game and it shows up here.").font(.jk(11, .medium)).foregroundColor(.white.opacity(0.5))
            } else {
                VStack(spacing: 4) {
                    ForEach(Array((t.recent ?? []).prefix(10).enumerated()), id: \.offset) { _, m in
                        HStack(spacing: 10) {
                            Text(m.won ? "WIN" : "LOSS").font(.jk(11, .heavy)).foregroundColor(.black)
                                .frame(width: 46, height: 22).background(Rectangle().fill(m.won ? TUI.green : TUI.red))
                            VStack(alignment: .leading, spacing: 1) {
                                Text((m.map >= 0 && m.map < TMap.mapNames.count ? TMap.mapNames[m.map] : "MAP").uppercased()).font(.jk(12, .heavy)).foregroundColor(.white)
                                Text(((m.mode >= 0 && m.mode < TWeapons.modeNames.count) ? TWeapons.modeNames[m.mode] : "MODE").uppercased() + "  ·  " + Self.ago(m.date))
                                    .font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.55))
                            }
                            Spacer(minLength: 0)
                            Text("\(m.kills) K").font(.jk(12, .heavy)).foregroundColor(.white.opacity(0.85))
                            Text(m.delta >= 0 ? "+\(m.delta)" : "\(m.delta)").font(.jk(12, .heavy)).foregroundColor(m.delta >= 0 ? TUI.green : TUI.red).frame(width: 36, alignment: .trailing)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.white.opacity(0.06))
                        .overlay(Rectangle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                }
            }
        }
    }

    private static func ago(_ t: Double) -> String {
        let s = max(0, Date().timeIntervalSince1970 - t)
        if s < 3600 { return "\(Int(s / 60))M AGO" }
        if s < 86400 { return "\(Int(s / 3600))H AGO" }
        return "\(Int(s / 86400))D AGO"
    }

    var body: some View {
        let xp = TacRank.totalXP(t)
        let cur = TacRank.index(xp)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    TacRankTile(idx: cur, size: 92, progress: TacRank.progress(xp))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(TacRank.ranks[cur].name.uppercased()).font(.jk(20, .heavy)).foregroundColor(.white)
                        Text("\(xp) XP" + (TacRank.toNext(xp) > 0 ? "  ·  \(TacRank.toNext(xp)) to \(TacRank.ranks[min(TacRank.ranks.count - 1, cur + 1)].name)" : "  ·  MAX RANK"))
                            .font(.jk(12, .bold)).foregroundColor(.white.opacity(0.65))
                        HStack(spacing: 8) {
                            TextField("Username", text: $draft)
                                .font(.jk(16, .heavy)).foregroundColor(.white)
                                .textInputAutocapitalization(.never).disableAutocorrection(true)
                                .padding(.horizontal, 12).frame(height: 38)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.1)))
                            Button {
                                TacProfile.set(draft)
                                username = TacProfile.name
                                draft = username
                            } label: {
                                Text("SAVE").font(.jk(12, .heavy)).foregroundColor(.black)
                                    .padding(.horizontal, 14).frame(height: 38).background(Capsule().fill(TUI.accent))
                            }
                            .buttonStyle(TuiPress())
                        }
                    }
                }
                profileCard(t)
                if cur >= TacRank.ranks.count - 1, (t.prestige ?? 0) < TacRank.maxPrestige, let go = onPrestige {
                    let np = (t.prestige ?? 0) + 1
                    Button { go(); dismiss() } label: {
                        Text("PRESTIGE  →  P\(np)  ·  \(TacRank.mult(np))x CASH & RANK XP").font(.jk(14, .heavy)).foregroundColor(.black)
                            .frame(maxWidth: .infinity).frame(height: 46).background(Capsule().fill(TUI.gold))
                    }
                    .buttonStyle(TuiPress())
                }
                Text("XP: 40 per match + 10 per kill + 60 per win" + ((t.prestige ?? 0) > 0 ? "  ·  \(TacRank.mult(t.prestige ?? 0))x prestige bonus." : ".")).font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.55))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(0..<TacRank.ranks.count, id: \.self) { i in
                        VStack(spacing: 3) {
                            TacRankTile(idx: i, size: 82, progress: i < cur ? 1 : (i == cur ? TacRank.progress(xp) : 0), locked: i > cur)
                            Text("\(TacRank.ranks[i].xp) XP").font(.jk(9, .heavy)).foregroundColor(i == cur ? TUI.accent : .white.opacity(0.5))
                        }
                    }
                }
            }
            .padding(18)
        }
        .background(Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                SF("xmark.circle.fill").font(.system(size: 26)).foregroundColor(.white.opacity(0.7)).padding(14)
            }
        }
        .onAppear { draft = username }
    }
}
