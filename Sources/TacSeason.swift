import SwiftUI
import UIKit

struct TacSeasonData: Codable, Hashable {
    var xp = 0
    var premium = false
    var claimed: [Int] = []
    var claimedP: [Int] = []
    var owned: [String] = []
    var fx = "fx_none"
    var charm = "charm_none"
    var gloves = "gl_black"
    var map = "map_desert"
    var faction = 0
}

struct TacCos: Identifiable {
    let id: String
    let kind: String
    let label: String
    let sym: String
    let rgb: (CGFloat, CGFloat, CGFloat)
}

enum TacSeason {
    static let name = "FALLEN GRACE"
    static let tiers = 30
    static let xpPerTier = 120

    static let catalog: [TacCos] = [
        TacCos(id: "fx_none", kind: "fx", label: "None", sym: "", rgb: (0, 0, 0)),
        TacCos(id: "fx_gold", kind: "fx", label: "Gold Rush", sym: "dollarsign.circle.fill", rgb: (0, 0, 0)),
        TacCos(id: "fx_bolt", kind: "fx", label: "Lightning", sym: "bolt.fill", rgb: (0, 0, 0)),
        TacCos(id: "fx_skull", kind: "fx", label: "Reaper", sym: "skull.fill", rgb: (0, 0, 0)),
        TacCos(id: "fx_fire", kind: "fx", label: "Inferno", sym: "flame.fill", rgb: (0, 0, 0)),
        TacCos(id: "fx_heart", kind: "fx", label: "Heartbreak", sym: "heart.fill", rgb: (0, 0, 0)),
        TacCos(id: "fx_star", kind: "fx", label: "Supernova", sym: "sparkles", rgb: (0, 0, 0)),
        TacCos(id: "charm_none", kind: "charm", label: "None", sym: "", rgb: (0, 0, 0)),
        TacCos(id: "charm_clover", kind: "charm", label: "Lucky Clover", sym: "leaf.fill", rgb: (0, 0, 0)),
        TacCos(id: "charm_pumpkin", kind: "charm", label: "Jack", sym: "theatermasks.fill", rgb: (0, 0, 0)),
        TacCos(id: "charm_crown", kind: "charm", label: "Crown", sym: "crown.fill", rgb: (0, 0, 0)),
        TacCos(id: "charm_rocket", kind: "charm", label: "Rocket", sym: "paperplane.fill", rgb: (0, 0, 0)),
        TacCos(id: "charm_bunny", kind: "charm", label: "Bunny", sym: "hare.fill", rgb: (0, 0, 0)),
        TacCos(id: "gl_black", kind: "gl", label: "Tactical Black", sym: "", rgb: (0.165, 0.153, 0.137)),
        TacCos(id: "gl_tan", kind: "gl", label: "Desert Tan", sym: "", rgb: (0.62, 0.5, 0.33)),
        TacCos(id: "gl_red", kind: "gl", label: "Crimson", sym: "", rgb: (0.6, 0.1, 0.1)),
        TacCos(id: "gl_camo", kind: "gl", label: "Woodland", sym: "", rgb: (0.25, 0.33, 0.17)),
        TacCos(id: "gl_blue", kind: "gl", label: "Navy", sym: "", rgb: (0.12, 0.2, 0.45)),
        TacCos(id: "map_desert", kind: "map", label: "The House · Day", sym: "", rgb: (0, 0, 0)),
        TacCos(id: "map_station", kind: "map", label: "The House · Night Shift", sym: "", rgb: (0, 0, 0)),
        TacCos(id: "map_grace", kind: "map", label: "The House · Dusk", sym: "", rgb: (0, 0, 0))
    ]
    static func cos(_ id: String) -> TacCos { catalog.first { $0.id == id } ?? catalog[0] }
    static let baseOwned = ["fx_none", "charm_none", "gl_black", "map_desert"]
    static let freeCos = ["fx_gold", "charm_clover", "gl_tan", "fx_bolt", "map_station", "gl_red"]
    static let premCos = ["fx_skull", "charm_pumpkin", "gl_camo", "fx_fire", "charm_crown", "gl_blue", "fx_heart", "map_grace", "charm_rocket", "fx_star"]

    struct Reward { let gems: Int; let cos: String? }
    static func reward(_ t: Int, premium: Bool) -> Reward {
        if premium {
            if t % 3 == 0 { return Reward(gems: 0, cos: premCos[(t / 3 - 1) % premCos.count]) }
            return Reward(gems: 25, cos: nil)
        }
        if t % 5 == 0 { return Reward(gems: 0, cos: freeCos[(t / 5 - 1) % freeCos.count]) }
        return Reward(gems: 10, cos: nil)
    }

    static func tier(_ xp: Int) -> Int { min(tiers, xp / xpPerTier) }
    static func league(_ rating: Int) -> String { TacLeague.name(rating) }

    static let themes = ["map_desert", "map_station", "map_grace"]
}

extension Game {
    var sx: TacSeasonData { s.ex.tac?.sx ?? TacSeasonData() }
    func updateSX(_ f: (inout TacSeasonData) -> Void) {
        var st = s
        var d = st.ex.tac ?? TacData()
        var x = d.sx ?? TacSeasonData()
        f(&x)
        d.sx = x
        st.ex.tac = d
        s = st
    }
    func tacOwns(_ id: String) -> Bool { TacSeason.baseOwned.contains(id) || sx.owned.contains(id) }
}

struct CosIcon: View {
    let c: TacCos
    var size: CGFloat = 22
    var body: some View {
        if c.kind == "gl" {
            Circle().fill(Color(red: c.rgb.0, green: c.rgb.1, blue: c.rgb.2)).frame(width: size, height: size)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
        } else if c.kind == "map" {
            SF("map.fill").font(.system(size: size, weight: .semibold)).foregroundColor(.white)
        } else {
            SF(c.sym.isEmpty ? "nosign" : c.sym, "sparkles").font(.system(size: size, weight: .semibold))
                .foregroundColor(c.sym.isEmpty ? .white.opacity(0.4) : TUI.gold)
        }
    }
}

struct TacSeasonView: View {
    @EnvironmentObject var game: Game
    @Environment(\.dismiss) private var dismiss
    var startTab: Int = 0
    @State private var tab = 0
    @State private var drawMsg = ""
    @State private var spinning = false
    @State private var carouselPos: Double = 0
    @State private var dragX: CGFloat = 0

    private let lime = TUI.accent

    var body: some View {
        let x = game.sx
        let tier = TacSeason.tier(x.xp)
        let rating = game.s.ex.tac?.rating ?? 1000
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.09, blue: 0.14), Color(red: 0.03, green: 0.04, blue: 0.07)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        SF("chevron.left").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(width: 36, height: 36).tuiGlass(18, fill: 0.4)
                    }
                    .buttonStyle(TuiPress())
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SEASON  \(TacSeason.name)").font(.jk(18, .heavy)).foregroundColor(.white)
                        HStack(spacing: 6) {
                            Text("TIER \(tier)/\(TacSeason.tiers)").font(.jk(11, .heavy)).foregroundColor(lime)
                            Text("\(TacSeason.league(rating))  \(rating)").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.65))
                        }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        SF("diamond.fill").font(.system(size: 13)).foregroundColor(TUI.gold)
                        Text("\(game.s.ex.gems)").font(.jk(14, .heavy)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 12).frame(height: 34).tuiGlass(17, fill: 0.4)
                }
                .padding(.horizontal, 16).padding(.top, 8)
                HStack(spacing: 6) {
                    ForEach(Array([("BATTLE PASS", "rosette"), ("LOCKER", "tshirt.fill"), ("LUCKY DRAW", "gift.fill")].enumerated()), id: \.offset) { i, n in
                        Button { tab = i } label: {
                            HStack(spacing: 6) {
                                SF(n.1, "star.fill").font(.system(size: 12, weight: .bold))
                                Text(n.0).font(.jk(12, .heavy))
                            }
                            .foregroundColor(tab == i ? .black : .white.opacity(0.8))
                            .frame(maxWidth: .infinity).frame(height: 34)
                            .background(Capsule().fill(tab == i ? lime : Color.white.opacity(0.08)))
                        }
                        .buttonStyle(TuiPress())
                    }
                }
                .padding(.horizontal, 16)
                if tab == 0 { passTab(x, tier) } else if tab == 1 { lockerTab(x) } else { drawTab() }
                Spacer(minLength: 0)
            }
        }
        .statusBarHidden(true)
        .onAppear { tab = startTab }
    }

    private func passTab(_ x: TacSeasonData, _ tier: Int) -> some View {
        VStack(spacing: 8) {
            let into = x.xp - tier * TacSeason.xpPerTier
            HStack(spacing: 10) {
                Capsule().fill(Color.white.opacity(0.15)).frame(height: 8)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in Capsule().fill(lime).frame(width: g.size.width * CGFloat(tier >= TacSeason.tiers ? 1 : Double(into) / Double(TacSeason.xpPerTier))) }
                    }
                Text("\(x.xp) XP").font(.jk(11, .bold)).foregroundColor(.white.opacity(0.8))
                if !x.premium {
                    Button {
                        if game.s.ex.gems >= 300 {
                            var st = game.s; st.ex.gems -= 300; game.s = st
                            game.updateSX { $0.premium = true }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            SF("crown.fill", "star.fill").font(.system(size: 11, weight: .bold))
                            Text("PREMIUM").font(.jk(11, .heavy))
                            SF("diamond.fill").font(.system(size: 9))
                            Text("300").font(.jk(11, .heavy))
                        }
                        .foregroundColor(.black).padding(.horizontal, 12).frame(height: 28).background(Capsule().fill(TUI.gold))
                    }
                    .buttonStyle(TuiPress())
                } else {
                    HStack(spacing: 5) {
                        SF("crown.fill", "star.fill").font(.system(size: 11, weight: .bold))
                        Text("PREMIUM").font(.jk(11, .heavy))
                    }
                    .foregroundColor(TUI.gold)
                }
            }
            .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(1...TacSeason.tiers, id: \.self) { t in
                        let reached = tier >= t
                        VStack(spacing: 6) {
                            Text("\(t)").font(.jk(12, .heavy)).foregroundColor(reached ? lime : .white.opacity(0.5))
                            cell(TacSeason.reward(t, premium: true), locked: !x.premium, got: x.claimedP.contains(t), can: reached && x.premium && !x.claimedP.contains(t), prem: true) { claim(t, true) }
                            cell(TacSeason.reward(t, premium: false), locked: false, got: x.claimed.contains(t), can: reached && !x.claimed.contains(t), prem: false) { claim(t, false) }
                        }
                        .frame(width: 62)
                    }
                }
                .padding(.horizontal, 16)
            }
            Text("Earn XP from every match: 40 base + 10 per kill + 60 for a win.").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.6))
        }
    }

    private func cell(_ r: TacSeason.Reward, locked: Bool, got: Bool, can: Bool, prem: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            VStack(spacing: 3) {
                if let cid = r.cos {
                    let k = TacSeason.cos(cid)
                    CosIcon(c: k, size: 20)
                    Text(k.label).font(.jk(8, .bold)).foregroundColor(.white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.6)
                } else {
                    SF("diamond.fill").font(.system(size: 18)).foregroundColor(TUI.gold)
                    Text("\(r.gems)").font(.jk(12, .heavy)).foregroundColor(.white)
                }
                HStack(spacing: 2) {
                    if got { SF("checkmark", "circle.fill").font(.system(size: 8, weight: .black)) }
                    else if locked { SF("lock.fill").font(.system(size: 8)) }
                    Text(got ? "CLAIMED" : (can ? "CLAIM" : (locked ? "LOCKED" : "")))
                }
                .font(.jk(8, .heavy)).foregroundColor(can ? .black : .white.opacity(0.6))
                .padding(.horizontal, 5).background(can ? lime : Color.clear).clipShape(Capsule())
            }
            .frame(width: 58, height: 72)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(prem ? TUI.gold.opacity(got ? 0.05 : 0.12) : Color.white.opacity(got ? 0.04 : 0.1)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(can ? lime : Color.white.opacity(0.15), lineWidth: can ? 2 : 1))
        }
        .buttonStyle(TuiPress())
        .disabled(!can)
    }

    private func claim(_ t: Int, _ prem: Bool) {
        let r = TacSeason.reward(t, premium: prem)
        game.updateSX { d in
            if prem { if d.claimedP.contains(t) { return }; d.claimedP.append(t) } else { if d.claimed.contains(t) { return }; d.claimed.append(t) }
            if let c = r.cos, !d.owned.contains(c) { d.owned.append(c) }
        }
        if r.gems > 0 { var st = game.s; st.ex.gems += r.gems; game.s = st }
    }

    private func lockerTab(_ x: TacSeasonData) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array([("fx", "KILL EFFECT", "sparkles"), ("charm", "CHARM", "key.fill"), ("gl", "GLOVES", "hand.raised.fill"), ("map", "MAP", "map.fill")].enumerated()), id: \.offset) { _, grp in
                    HStack(spacing: 6) {
                        SF(grp.2, "circle.fill").font(.system(size: 11, weight: .bold))
                        Text(grp.1).font(.jk(12, .heavy))
                    }
                    .foregroundColor(lime)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TacSeason.catalog.filter { $0.kind == grp.0 }) { c in
                                let own = game.tacOwns(c.id)
                                let sel = (grp.0 == "fx" ? x.fx : (grp.0 == "charm" ? x.charm : (grp.0 == "gl" ? x.gloves : x.map))) == c.id
                                Button {
                                    guard own else { return }
                                    game.updateSX { d in
                                        if grp.0 == "fx" { d.fx = c.id } else if grp.0 == "charm" { d.charm = c.id } else if grp.0 == "gl" { d.gloves = c.id } else { d.map = c.id }
                                    }
                                } label: {
                                    VStack(spacing: 5) {
                                        ZStack {
                                            CosIcon(c: c, size: 22)
                                            if !own { SF("lock.fill").font(.system(size: 10)).foregroundColor(.white.opacity(0.8)).offset(x: 16, y: 12) }
                                        }
                                        .frame(height: 26)
                                        Text(c.label).font(.jk(10, .bold)).foregroundColor(.white).lineLimit(1)
                                    }
                                    .frame(width: 96, height: 66)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(own ? 0.1 : 0.03)))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(sel ? lime : Color.white.opacity(0.12), lineWidth: sel ? 2 : 1))
                                    .opacity(own ? 1 : 0.45)
                                }
                                .buttonStyle(TuiPress())
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var drawItems: [TacCos] { TacSeason.catalog.filter { !$0.id.hasSuffix("_none") } }

    private func rarity(_ c: TacCos) -> (String, Color) {
        if TacSeason.premCos.contains(c.id) { return ("EPIC", Color(red: 0.75, green: 0.45, blue: 1)) }
        if TacSeason.freeCos.contains(c.id) { return ("RARE", TUI.blue) }
        return ("COMMON", Color.white.opacity(0.6))
    }

    private func drawCell(_ c: TacCos, w: CGFloat) -> some View {
        let r = rarity(c)
        let owned = game.tacOwns(c.id)
        return VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(r.1.opacity(0.16))
                CosIcon(c: c, size: 28)
            }
            .frame(width: w - 14, height: 50)
            Text(c.label).font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(owned ? "OWNED" : r.0).font(.jk(9, .heavy)).foregroundColor(owned ? .white.opacity(0.35) : r.1)
        }
        .frame(width: w, height: 94)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(r.1.opacity(0.45), lineWidth: 1))
        .opacity(owned ? 0.55 : 1)
    }

    private func spinDraw() {
        guard !spinning else { return }
        let pool = drawItems.filter { !game.tacOwns($0.id) }
        guard game.s.ex.gems >= 40 else { drawMsg = "Not enough gems"; return }
        guard let win = pool.randomElement(), let wi = drawItems.firstIndex(where: { $0.id == win.id }) else {
            drawMsg = "Collection complete"
            return
        }
        var st = game.s; st.ex.gems -= 40; game.s = st
        spinning = true
        drawMsg = ""
        let n = drawItems.count
        let base = (Int(carouselPos.rounded()) / n + 1) * n
        let target = Double(base + n * 6 + wi)
        withAnimation(.timingCurve(0.12, 0.62, 0.08, 1.0, duration: 4.2)) { carouselPos = target }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.4) {
            game.updateSX { $0.owned.append(win.id) }
            drawMsg = "You got: \(win.label)"
            spinning = false
            // park the strip back near the start so the offset stays small
            var tx = Transaction(); tx.disablesAnimations = true
            withTransaction(tx) { carouselPos = Double(n * 2 + wi) }
        }
    }

    private func drawTab() -> some View {
        let items = drawItems
        let n = max(1, items.count)
        let cw: CGFloat = 92, gap: CGFloat = 8
        let step = cw + gap
        return VStack(spacing: 8) {
            GeometryReader { geo in
                let W = geo.size.width
                ZStack {
                    HStack(spacing: gap) {
                        ForEach(0..<(n * 14), id: \.self) { k in drawCell(items[k % n], w: cw) }
                    }
                    .offset(x: W / 2 - cw / 2 - CGFloat(carouselPos) * step + dragX)
                    .frame(width: W, alignment: .leading)
                    RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(TUI.accent, lineWidth: 3)
                        .frame(width: cw + 8, height: 104).allowsHitTesting(false)
                    Image(systemName: "arrowtriangle.down.fill").font(.system(size: 14)).foregroundColor(TUI.accent)
                        .offset(y: -58).allowsHitTesting(false)
                }
                .frame(width: W, height: 112)
                .clipped()
                .contentShape(Rectangle())
                .gesture(DragGesture()
                    .onChanged { v in if !spinning { dragX = v.translation.width } }
                    .onEnded { v in
                        guard !spinning else { return }
                        let moved = Double(-v.predictedEndTranslation.width / step)
                        let t = (carouselPos + moved).rounded()
                        withAnimation(.easeOut(duration: 0.35)) { carouselPos = t; dragX = 0 }
                    })
            }
            .frame(height: 112)
            Text("Spend 40 gems for a random cosmetic you don't own yet.").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.7))
            Button { spinDraw() } label: {
                HStack(spacing: 8) {
                    Text(spinning ? "..." : "DRAW").font(.jk(18, .heavy))
                    SF("diamond.fill").font(.system(size: 13))
                    Text("40").font(.jk(18, .heavy))
                }
                .foregroundColor(.black).frame(width: 200, height: 44).background(Capsule().fill(TUI.gold))
                .opacity(spinning ? 0.6 : 1)
            }
            .buttonStyle(TuiPress())
            Text(drawMsg).font(.jk(15, .bold)).foregroundColor(lime).frame(height: 20)
        }
        .padding(.top, 4)
        .onAppear { if carouselPos < 1 { carouselPos = Double(n * 2) } }
    }
}
