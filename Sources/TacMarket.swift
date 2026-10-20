import SwiftUI
import UIKit

// MARK: - marketplace data (rotating listings, fluctuating sell prices)

struct MarketListing: Codable, Identifiable, Hashable {
    var id: String
    var kind: String        // gun, part, supply
    var gun: RaidItem?
    var ref: String
    var qty: Int
    var price: Int
    var sold: Bool
}

struct MarketState: Codable {
    var epoch: Int
    var items: [MarketListing]
}

enum TacMarket {
    private static let key = "ms.market.v1"
    static let window: TimeInterval = 1800

    static var epoch: Int { Int(Date().timeIntervalSince1970 / window) }

    static var minutesLeft: Int {
        let left = Double(epoch + 1) * window - Date().timeIntervalSince1970
        return max(1, Int(left / 60) + 1)
    }

    static func load() -> MarketState {
        if let d = UserDefaults.standard.data(forKey: key), let s = try? JSONDecoder().decode(MarketState.self, from: d), s.epoch == epoch { return s }
        return roll("")
    }

    static func save(_ s: MarketState) {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
    }

    private static func pick(_ rng: inout TacSeedRNG, _ n: Int) -> Int {
        Int(rng.next() % UInt64(max(1, n)))
    }

    @discardableResult
    static func roll(_ salt: String) -> MarketState {
        var rng = TacSeedRNG("mkt\(epoch)\(salt)")
        var items: [MarketListing] = []
        let guns = TWeapons.all.filter { !TWeapons.isPistol($0.id) }
        for i in 0..<4 {
            let g = guns[pick(&rng, guns.count)]
            let f = rng.f()
            var t = 0
            if f >= 0.94 { t = 4 } else if f >= 0.78 { t = 3 } else if f >= 0.45 { t = 2 } else if f >= 0.15 { t = 1 }
            let dur = 60 + pick(&rng, 41)
            let base = max(40, g.price / 5)
            let value = Int(Double(base) * TacRarity.mult(t))
            let item = RaidItem(kind: "gun", name: g.name, value: value, ref: g.id, tier: t, dur: dur)
            let price = Int(Double(value) * 2.0 * (0.6 + 0.4 * Double(dur) / 100))
            items.append(MarketListing(id: "g\(i)", kind: "gun", gun: item, ref: g.id, qty: 1, price: price, sold: false))
        }
        let parts = TAtt.baseDefs.filter { $0.slot != .camo }
        for i in 0..<2 {
            let d = parts[pick(&rng, parts.count)]
            items.append(MarketListing(id: "p\(i)", kind: "part", gun: nil, ref: d.id, qty: 1, price: d.cost * 2, sold: false))
        }
        let sup = ["med", "plate", "kit", "band"]
        for i in 0..<2 {
            let k = sup[pick(&rng, sup.count)]
            let unit = TacMeta.stock.first(where: { $0.id == k })?.price ?? 20
            items.append(MarketListing(id: "s\(i)", kind: "supply", gun: nil, ref: k, qty: 3, price: unit * 3 - unit / 2, sold: false))
        }
        let s = MarketState(epoch: epoch, items: items)
        save(s)
        return s
    }

    /// how much the market currently pays for something (0.8x - 1.3x)
    static func sellMult(_ it: RaidItem) -> Double {
        var rng = TacSeedRNG("sell\(epoch)\(it.kind == "gun" ? it.ref : it.kind)")
        return 0.8 + Double(rng.f()) * 0.5
    }

    static func sellPrice(_ it: RaidItem) -> Int {
        var v = Double(it.value) * sellMult(it)
        if it.kind == "gun" { v *= 0.6 + 0.4 * Double(it.dur) / 100 }
        return max(1, Int(v))
    }
}

// MARK: - marketplace screen

struct CSMarket: View {
    @EnvironmentObject var game: Game
    let back: () -> Void
    @State private var tab = 0
    @State private var tick = 0
    @State private var note = ""

    private func spend(_ n: Int) -> Bool {
        guard game.s.ex.gems >= n else { return false }
        var st = game.s
        st.ex.gems -= n
        game.s = st
        return true
    }

    private func earn(_ n: Int) {
        var st = game.s
        st.ex.gems += n
        game.s = st
    }

    private func card<Content: View>(@ViewBuilder _ c: () -> Content) -> some View {
        c().padding(10).background(Color.black.opacity(0.6)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private func buy(_ l: MarketListing) {
        var s = TacMarket.load()
        guard let i = s.items.firstIndex(where: { $0.id == l.id }), !s.items[i].sold else { return }
        if l.kind == "gun" && TacStash.items.count >= TacStash.cap { note = "STASH FULL"; return }
        guard spend(l.price) else { note = "NOT ENOUGH GEMS"; return }
        switch l.kind {
        case "gun":
            if var g = l.gun {
                g.id = UUID().uuidString
                var cur = TacStash.items
                cur.append(g)
                TacStash.items = cur
            }
        case "part":
            TAtt.own(l.ref)
        default:
            TacMeta.addLoadout(l.ref, l.qty)
        }
        s.items[i].sold = true
        TacMarket.save(s)
        note = "PURCHASED"
        tick += 1
    }

    private func sell(_ it: RaidItem) {
        earn(TacMarket.sellPrice(it))
        TacStash.remove(it.id)
        if TacStash.kitId == it.id { TacStash.kitId = nil }
        note = "SOLD"
        tick += 1
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Button { tab = i } label: {
                    Text(i == 0 ? "BUY" : "SELL").font(.jk(11, .heavy)).foregroundColor(tab == i ? .black : .white)
                        .padding(.horizontal, 18).frame(height: 28)
                        .background(Rectangle().fill(tab == i ? CS.gold : Color.white.opacity(0.14)))
                }
                .buttonStyle(TuiPress())
            }
            Spacer()
            if !note.isEmpty { Text(note).font(.jk(10, .heavy)).foregroundColor(TUI.accent) }
        }
        .padding(.horizontal, 28).padding(.top, 8)
    }

    private func listingTitle(_ l: MarketListing) -> String {
        switch l.kind {
        case "gun": return l.gun?.name ?? "Weapon"
        case "part": return TAtt.def(l.ref)?.name ?? l.ref
        default: return "\(l.qty)x \(TacMeta.stock.first(where: { $0.id == l.ref })?.name ?? l.ref)"
        }
    }

    private func listingSub(_ l: MarketListing) -> String {
        switch l.kind {
        case "gun": return "\(TacRarity.name(l.gun?.tier ?? 0))  ·  \(l.gun?.dur ?? 100)%"
        case "part": return TAtt.def(l.ref)?.desc ?? "Attachment"
        default: return "Supply bundle  ·  goes to your raid kit"
        }
    }

    private func listingRow(_ l: MarketListing) -> some View {
        let afford = game.s.ex.gems >= l.price
        let col: Color = l.kind == "gun" ? TacRarity.color(l.gun?.tier ?? 0) : .white
        return card {
            HStack(spacing: 10) {
                SF(l.kind == "gun" ? "scope" : (l.kind == "part" ? "wrench.and.screwdriver.fill" : "shippingbox.fill"), "circle.fill")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(col).frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(listingTitle(l)).font(.jk(13, .heavy)).foregroundColor(col).lineLimit(1)
                    Text(listingSub(l)).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                }
                Spacer(minLength: 0)
                if l.sold {
                    Text("SOLD").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.45))
                } else {
                    Button { buy(l) } label: {
                        HStack(spacing: 3) {
                            Text("BUY").font(.jk(10, .heavy))
                            SF("diamond.fill").font(.system(size: 9))
                            Text("\(l.price)").font(.jk(10, .heavy))
                        }
                        .foregroundColor(afford ? .black : .white.opacity(0.5))
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(Rectangle().fill(afford ? CS.gold : Color.white.opacity(0.14)))
                    }
                    .buttonStyle(TuiPress())
                }
            }
        }
        .opacity(l.sold ? 0.5 : 1)
    }

    private var buyView: some View {
        let s = TacMarket.load()
        return VStack(spacing: 6) {
            HStack {
                Text("NEW STOCK IN \(TacMarket.minutesLeft) MIN").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.6))
                Spacer()
                Button {
                    guard spend(20) else { note = "NOT ENOUGH GEMS"; return }
                    TacMarket.roll(UUID().uuidString)
                    note = "STOCK REFRESHED"
                    tick += 1
                } label: {
                    HStack(spacing: 3) {
                        Text("REFRESH").font(.jk(10, .heavy))
                        SF("diamond.fill").font(.system(size: 9))
                        Text("20").font(.jk(10, .heavy))
                    }
                    .foregroundColor(.white).padding(.horizontal, 10).frame(height: 24).background(Rectangle().fill(Color.white.opacity(0.18)))
                }
                .buttonStyle(TuiPress())
            }
            ForEach(s.items) { l in listingRow(l) }
        }
        .padding(.horizontal, 28).padding(.top, 10)
    }

    private func sellRow(_ it: RaidItem) -> some View {
        let m = TacMarket.sellMult(it)
        let tag: String = m >= 1.15 ? "HOT" : (m < 0.9 ? "LOW" : "FAIR")
        let tagCol: Color = m >= 1.15 ? TUI.green : (m < 0.9 ? TUI.red : .white.opacity(0.6))
        let col: Color = it.kind == "gun" ? TacRarity.color(it.tier) : .white
        return card {
            HStack(spacing: 10) {
                SF(it.kind == "gun" ? "scope" : (it.kind == "part" ? "wrench.and.screwdriver.fill" : "diamond.fill"), "circle.fill")
                    .font(.system(size: 17, weight: .bold)).foregroundColor(col).frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(it.name).font(.jk(13, .heavy)).foregroundColor(col).lineLimit(1)
                    Text(it.kind == "gun" ? "\(TacRarity.name(it.tier))  ·  \(it.dur)%" : "VALUABLE").font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Text("\(tag) \(Int((m * 100).rounded()))%").font(.jk(10, .heavy)).foregroundColor(tagCol)
                Button { sell(it) } label: {
                    HStack(spacing: 3) {
                        Text("SELL").font(.jk(10, .heavy))
                        SF("diamond.fill").font(.system(size: 9))
                        Text("\(TacMarket.sellPrice(it))").font(.jk(10, .heavy))
                    }
                    .foregroundColor(.black).padding(.horizontal, 10).frame(height: 26).background(Rectangle().fill(CS.gold))
                }
                .buttonStyle(TuiPress())
            }
        }
    }

    private var sellView: some View {
        let items = TacStash.items
        return VStack(spacing: 6) {
            if items.isEmpty {
                Text("Nothing to sell. Extract loot from a raid to fill your stash.").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.6)).padding(.top, 30)
            } else {
                Text("Prices shift every 30 minutes. HOT items pay the most.").font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.5))
                ForEach(items) { it in sellRow(it) }
            }
        }
        .padding(.horizontal, 28).padding(.top, 10)
    }

    var body: some View {
        _ = tick
        return GeometryReader { geo in
            VStack(spacing: 0) {
                CSHeader(title: "MARKET", cash: game.s.ex.gems, coins: (game.s.ex.tac ?? TacData()).wins, back: back).padding(.top, 8)
                tabBar
                ScrollView(showsIndicators: false) {
                    Group {
                        if tab == 0 { buyView } else { sellView }
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
