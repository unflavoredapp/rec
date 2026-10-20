import SwiftUI
import UIKit

// MARK: - rarity

enum TacRarity {
    static let names = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC"]

    static func color(_ t: Int) -> Color {
        switch t {
        case 1: return Color(red: 0.4, green: 0.9, blue: 0.45)
        case 2: return Color(red: 0.3, green: 0.62, blue: 1)
        case 3: return Color(red: 0.75, green: 0.4, blue: 1)
        case 4: return Color(red: 1, green: 0.78, blue: 0.2)
        case 5: return Color(red: 1, green: 0.2, blue: 0.55)
        default: return Color.white.opacity(0.85)
        }
    }

    static func name(_ t: Int) -> String { names[max(0, min(5, t))] }
    static func mult(_ t: Int) -> Double { 1 + Double(max(0, min(5, t))) * 0.6 }

    static func roll() -> Int {
        let r = Int.random(in: 0..<100)
        if r < 55 { return 0 }
        if r < 80 { return 1 }
        if r < 93 { return 2 }
        if r < 98 { return 3 }
        return 4
    }
}

// MARK: - persistent meta: loadout, contracts, trader, mastery

struct RaidContract: Hashable {
    let kind: Int
    let title: String
    let detail: String
    let reward: Int
}

struct TraderItem {
    let id: String
    let name: String
    let desc: String
    let price: Int
    let level: Int
}

enum TacMeta {
    static let contracts: [RaidContract] = [
        RaidContract(kind: 0, title: "PURGE", detail: "Eliminate 4 hostiles", reward: 40),
        RaidContract(kind: 1, title: "DEAD DROP", detail: "Recover the intel from the office", reward: 60),
        RaidContract(kind: 2, title: "SCAVENGER", detail: "Secure 3 valuables", reward: 50),
        RaidContract(kind: 3, title: "HIGH VALUE TARGET", detail: "Eliminate a commander", reward: 80),
        RaidContract(kind: 4, title: "HOLD THE YARD", detail: "Hold Central Yard for 20 seconds", reward: 70),
        RaidContract(kind: 5, title: "SAFECRACKER", detail: "Open a vault with an access card", reward: 90)
    ]

    static let stock: [TraderItem] = [
        TraderItem(id: "ammo", name: "Ammo Box", desc: "+2 spare magazines", price: 15, level: 0),
        TraderItem(id: "band", name: "Bandage", desc: "Stops bleeding", price: 10, level: 0),
        TraderItem(id: "med", name: "Medkit", desc: "+45 HP, cures bleeding and leg wounds", price: 30, level: 1),
        TraderItem(id: "plate", name: "Armor Plate", desc: "+50 armor (needs a vest)", price: 40, level: 1),
        TraderItem(id: "kit", name: "Repair Kit", desc: "+50 weapon durability", price: 35, level: 2),
        TraderItem(id: "card", name: "Access Card", desc: "Opens vaults and the South Dock exit", price: 150, level: 3)
    ]

    private static let loadKey = "ms.loadout"
    private static let mastKey = "ms.mast"
    private static let doneKey = "ms.contracts.done"
    private static let boardKey = "ms.contracts.board"
    private static let pickKey = "ms.contracts.pick"
    private static var mastCache: [String: Int]? = nil

    private static func dict(_ key: String) -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    private static func save(_ key: String, _ d: [String: Int]) {
        UserDefaults.standard.set(d, forKey: key)
    }

    // loadout (supplies bought from the trader or carried out of a raid)
    static func loadoutCount(_ k: String) -> Int { dict(loadKey)[k] ?? 0 }

    static func addLoadout(_ k: String, _ n: Int = 1) {
        var l = dict(loadKey)
        l[k] = max(0, min(12, (l[k] ?? 0) + n))
        save(loadKey, l)
    }

    static func takeLoadout(room: Int) -> [String] {
        var l = dict(loadKey)
        var out: [String] = []
        for k in ["med", "plate", "band", "ammo", "kit"] {
            while (l[k] ?? 0) > 0 && out.count < room {
                l[k] = (l[k] ?? 0) - 1
                out.append(k)
            }
        }
        save(loadKey, l)
        return out
    }

    static func takeCard() -> Bool {
        var l = dict(loadKey)
        guard (l["card"] ?? 0) > 0 else { return false }
        l["card"] = (l["card"] ?? 0) - 1
        save(loadKey, l)
        return true
    }

    // contracts + trader reputation
    static let repLevels = [0, 2, 5, 10]

    static var contractsDone: Int {
        get { UserDefaults.standard.integer(forKey: doneKey) }
        set { UserDefaults.standard.set(newValue, forKey: doneKey) }
    }

    static var traderLevel: Int { repLevels.lastIndex(where: { contractsDone >= $0 }) ?? 0 }

    static var board: [Int] {
        let b = (UserDefaults.standard.array(forKey: boardKey) as? [Int]) ?? []
        if b.count == 3 && b.allSatisfy({ $0 >= 0 && $0 < contracts.count }) { return b }
        return rollBoard()
    }

    @discardableResult
    static func rollBoard() -> [Int] {
        let b = Array(Array(0..<contracts.count).shuffled().prefix(3))
        UserDefaults.standard.set(b, forKey: boardKey)
        UserDefaults.standard.set(0, forKey: pickKey)
        return b
    }

    static var picked: Int {
        get { max(0, min(2, UserDefaults.standard.integer(forKey: pickKey))) }
        set { UserDefaults.standard.set(max(0, min(2, newValue)), forKey: pickKey) }
    }

    static var pickedContract: RaidContract { contracts[board[picked]] }

    // weapon mastery
    static let thresholds = [0, 50, 150, 300, 500, 800]

    static var mastery: [String: Int] {
        if let c = mastCache { return c }
        let m = dict(mastKey)
        mastCache = m
        return m
    }

    static func xp(_ g: String) -> Int { mastery[g] ?? 0 }

    static func level(_ g: String) -> Int {
        let x = xp(g)
        var l = 0
        for (i, t) in thresholds.enumerated() where x >= t { l = i }
        return l
    }

    static func unlocks(_ g: String) -> [String] {
        switch TWeapons.cls(g) {
        case "rifle": return ["comp", "agrip", "mag_ext", "c_carbon"]
        case "smg": return ["vgrip", "mag_ext", "sil", "c_neon"]
        case "sniper": return ["dot", "sil", "x4", "c_gold"]
        case "shotgun": return ["comp", "vgrip", "mag_ext", "c_tiger"]
        default: return ["comp", "mag_ext", "dot", "c_crimson"]
        }
    }

    static func nextUnlock(_ g: String) -> String {
        let n = level(g) + 1
        guard n < thresholds.count else { return "MAXED" }
        if n < 2 { return "Level 1" }
        let id = unlocks(g)[n - 2]
        return TAtt.def(id)?.name ?? id
    }

    /// a kill with this gun; returns a message when it levelled up
    static func addMastery(_ g: String) -> String? {
        var m = mastery
        let before = level(g)
        m[g] = (m[g] ?? 0) + 10
        mastCache = m
        save(mastKey, m)
        let now = level(g)
        guard now > before else { return nil }
        var msg = "\(TWeapons.w(g).name) MASTERY \(now)"
        if now >= 2 {
            let id = unlocks(g)[now - 2]
            TAtt.own(id)
            msg += "  ·  \(TAtt.def(id)?.name ?? id) UNLOCKED"
        }
        return msg
    }
}

// MARK: - raid systems on the engine

extension TacticalEngine {
    func raidRollGun(_ id: String, minTier: Int) -> RaidItem {
        let t = max(minTier, TacRarity.roll())
        let base = max(40, Int(TWeapons.w(id).price) / 5)
        let v = Int(Double(base) * TacRarity.mult(t))
        return RaidItem(kind: "gun", name: TGuns.get(id).name, value: v, ref: id, tier: t, dur: Int.random(in: 55...100))
    }

    func gunMods(_ p: TPlayer) -> (dmg: CGFloat, rec: CGFloat) {
        guard p.isPlayer else { return (1, 1) }
        let ml = CGFloat(TacMeta.level(p.gun))
        var d: CGFloat = 1 + ml * 0.01
        var r: CGFloat = 1 - ml * 0.025
        if gameMode == 6 {
            let t = CGFloat(gunTier)
            let worn = gunDur < 30
            d *= 1 + 0.05 * t
            r *= 1 - 0.07 * t
            if worn { d *= 0.9; r *= 1.15 }
        }
        return (d, r)
    }

    func raidSight(_ p: TPlayer) -> CGFloat {
        guard gameMode == 6 else { return 780 }
        if evKind == 3 { return 340 }
        return p.faction == 2 ? 1100 : 780
    }

    var raidInGas: Bool {
        evKind == 4 && me.alive && TMap.floorOf(me.pos) == TMap.floorOf(evPos) && tDist(me.pos, evPos) < 230
    }

    func raidWear(_ p: TPlayer) {
        guard !TWeapons.isPistol(p.gun) else { return }
        gunDur = max(0, gunDur - 0.35 * (gunTier >= 3 ? 0.7 : 1))
        if gunDur < 40 {
            let chance = Double(40 - gunDur) / 40 * 0.07
            if Double.random(in: 0...1) < chance {
                p.fireCd = 1.3
                pop(p.pos, "JAM", .orange)
                raidNote("WEAPON JAMMED  ·  REPAIR KIT FIXES WEAR")
            }
        }
    }

    func raidWound() {
        let r = Int.random(in: 0..<100)
        if r < 14 {
            if bleedT <= 0 { raidNote("BLEEDING  ·  USE A BANDAGE") }
            bleedT = 18
        } else if r < 26 && !legWound {
            legWound = true
            raidNote("LEG WOUND  ·  USE A MEDKIT")
        }
    }

    func raidRefuse(_ id: String) {
        guard raidMsgT <= 0 else { return }
        if id.hasPrefix("vault") {
            raidNote(raidHasKey ? "VAULT NEEDS 3 FREE SLOTS" : "VAULT LOCKED  ·  NEED ACCESS CARD")
        } else if raidBagFull && TacticalEngine.isBagKind(id) {
            raidNote("BACKPACK FULL  ·  OPEN BAG TO DROP ITEMS")
        }
    }

    /// bleeding, noise that bots can hear, footsteps
    func raidSurvival(_ dt: CGFloat) {
        guard me.alive else { return }
        if bleedT > 0 {
            bleedT = max(0, bleedT - dt)
            damage(me, 2.2 * dt, by: -2)
            if !me.alive { return }
        }
        var r: CGFloat = 0
        if moving { r = me.crouch ? 55 : (legWound ? 160 : 230) }
        if me.noiseT > 0 { r = max(r, noiseR) }
        noiseNow = r
        hearT -= dt
        if hearT <= 0 {
            hearT = 0.3
            if r > 0 {
                let mf = TMap.floorOf(me.pos)
                for b in players where !b.isPlayer && b.alive && b.faction != 2 && b.targetID < 0 && TMap.floorOf(b.pos) == mf && tDist(b.pos, me.pos) < r {
                    b.lastSeen = me.pos
                    b.hunt = max(b.hunt, 4)
                }
            }
        }
    }

    // MARK: factions

    func raidSetupFactions() {
        let bots = players.filter { !$0.isPlayer }
        let harbor = TMap.kind == 4
        let vaults = TMap.lootSpots.filter { $0.1.hasPrefix("vault") && !$0.1.hasPrefix("vault:B") }.map { $0.0 }.shuffled()
        let rich = TMap.lootSpots.filter { $0.1.hasPrefix("val:") || $0.1.hasPrefix("g:") }.map { $0.0 }.shuffled()
        var posts = harbor ? THarbor.posts.shuffled() : []
        var roofs = harbor ? THarbor.roofSpots.shuffled() : []
        let bossSpots = harbor ? THarbor.bossSpots : []
        let nB = bossSpots.count
        let nG = max(2, bots.count / 4), nS = max(2, bots.count / 10), nC = max(2, bots.count / 8)
        var bi = 0, ci = 0
        for (i, b) in bots.enumerated() {
            b.home = b.pos
            b.faction = 0
            b.team = 1
            b.watchDoor = false
            b.ambush = -1
            let role = i < nB ? 4 : (i < nB + nG ? 1 : (i < nB + nG + nS ? 2 : (i < nB + nG + nS + nC ? 3 : 0)))
            switch role {
            case 4:
                b.faction = 4
                b.team = 2
                b.hp = 450
                b.armorKind = 3
                b.armor = 200
                b.name = "WARDEN \(bi + 1)"
                setGun(b, ["ak", "m4"].randomElement() ?? "ak")
                b.home = bossSpots[bi]
                b.pos = b.home
                bi += 1
            case 1:
                b.faction = 1
                b.team = 2
                b.armorKind = 2
                b.armor = 100
                setGun(b, ["rifle", "ak", "shotgun"].randomElement() ?? "rifle")
                if let pt = posts.popLast() {
                    b.home = pt.0
                    b.pos = pt.0
                    b.ambushPos = pt.0
                    b.ambushAim = pt.1
                    b.aim = pt.1
                    b.watchDoor = true
                    b.crouch = true
                } else if i < rich.count { b.home = rich[i]; b.pos = b.home }
            case 2:
                b.faction = 2
                b.team = 1
                b.armorKind = 1
                b.armor = 60
                setGun(b, "awp")
                if let rp = roofs.popLast() { b.home = rp; b.pos = rp }
            case 3:
                b.faction = 3
                b.team = 2
                b.hp = 150
                b.armorKind = 3
                b.armor = 150
                setGun(b, ["ak", "m4"].randomElement() ?? "ak")
                if ci < vaults.count { b.home = vaults[ci]; b.pos = b.home }
                ci += 1
            default:
                break
            }
            b.path = []
            b.roam = .zero
        }
    }

    /// guards and commanders hold a post and circle around it
    func raidPost(_ p: TPlayer) -> CGPoint {
        if p.roam != .zero && p.goalT > time && tDist(p.pos, p.roam) > 40 { return p.roam }
        p.goalT = time + CGFloat.random(in: 3...6)
        let hf = TMap.floorOf(p.home)
        let near = TMap.lootSpots.map { $0.0 }.filter { TMap.floorOf($0) == hf && tDist($0, p.home) < 260 }
        let d = near.randomElement() ?? p.home
        p.roam = d
        return d
    }

    // MARK: drops (physical pickups placed in a pre-reserved pool of loot slots)

    func dynAdd(_ pos: CGPoint, _ id: String, _ j: Int) {
        let f = TMap.floorOf(pos)
        guard f >= 0 && f < 3 && dynBase > 0 else { return }
        let a = CGFloat(j) * 2.1
        let p = CGPoint(x: pos.x + cos(a) * 14, y: pos.y + sin(a) * 14)
        for k in 0..<12 {
            let idx = dynBase + f * 12 + k
            if idx < loot.count && loot[idx].taken {
                loot[idx] = Loot(pos: p, id: id, taken: false)
                return
            }
        }
    }

    func raidBotDrop(_ v: TPlayer, by owner: Int) {
        if v.faction == 3 && owner == 0 { cmdKilled += 1 }
        var drops: [String] = []
        let r = Int.random(in: 0..<100)
        switch v.faction {
        case 0:
            if r < 60 { drops.append("ammo") }
            if Int.random(in: 0..<100) < 40 { drops.append("band") }
            if Int.random(in: 0..<100) < 30 { drops.append("val:Scrap Metal:60") }
        case 1:
            drops.append("plate")
            if r < 50 { drops.append("g:\(v.gun)") }
            if Int.random(in: 0..<100) < 35 { drops.append("med") }
        case 2:
            drops.append("ammo")
            if r < 60 { drops.append("g:awp") }
        case 4:
            drops.append("plate")
            drops.append("plate")
            drops.append("val:Warden Core:2500")
            drops.append("g:\(v.gun):5")
            if !raidHasKey { drops.append("key") }
        case 3:
            drops.append("plate")
            drops.append("val:Commander Badge:300")
            drops.append("g:\(v.gun):2")
            if !raidHasKey { drops.append("key") }
        default:
            if r < 50 { drops.append("ammo") }
            if Int.random(in: 0..<100) < 50 { drops.append("g:\(v.gun)") }
        }
        for (j, id) in drops.enumerated() { dynAdd(v.pos, id, j) }
    }

    // MARK: raid events

    func raidEventTick(_ dt: CGFloat) {
        if alarmT > 0 {
            alarmT = max(0, alarmT - dt)
            alarmPulse -= dt
            if alarmPulse <= 0 { alarmPulse = 4; raidAlertBots() }
        }
        guard me.alive else { return }
        if evKind == 0 {
            evT -= dt
            if evT <= 0 { raidEventStart() }
            return
        }
        evLeft -= dt
        if evKind == 4 {
            let ef = TMap.floorOf(evPos)
            for p in players where p.alive && TMap.floorOf(p.pos) == ef && tDist(p.pos, evPos) < 230 {
                damage(p, 4 * dt, by: -3)
            }
        }
        if evLeft <= 0 { raidEventEnd() }
    }

    private func raidEventSpot() -> CGPoint {
        let spots = TMap.lootSpots.map { $0.0 }.filter { TMap.floorOf($0) == 1 && tDist($0, me.pos) > 350 }
        return spots.randomElement() ?? me.pos
    }

    private func raidEventStart() {
        evKind = [1, 2, 3, 4].randomElement() ?? 1
        switch evKind {
        case 1:
            evPos = raidEventSpot()
            evLeft = 25
            evMsg = "SUPPLY DROP INBOUND"
            let near = players.filter { !$0.isPlayer && $0.alive }.sorted { tDist($0.pos, evPos) < tDist($1.pos, evPos) }.prefix(3)
            for b in near { b.roam = evPos; b.goalT = time + 22 }
        case 2:
            evLeft = 6
            evMsg = "REINFORCEMENTS INBOUND"
            let far = TMap.spawns.filter { tDist($0, me.pos) > 650 }
            for b in players.filter({ !$0.isPlayer && !$0.alive }).prefix(3) {
                b.alive = true
                b.hp = 100
                b.faction = 4
                b.team = 1
                b.armorKind = 2
                b.armor = 100
                b.pos = far.randomElement() ?? b.pos
                b.home = b.pos
                b.path = []
                b.targetID = -1
                b.spotted = false
                b.reloadT = 0
                b.fireCd = 0
                b.respawn = 0
                setGun(b, ["ak", "m4", "rifle"].randomElement() ?? "rifle")
                b.lastSeen = me.pos
                b.hunt = 10
            }
        case 3:
            evLeft = 30
            evMsg = "POWER OUTAGE"
        default:
            evPos = raidEventSpot()
            evLeft = 35
            evMsg = "TOXIC GAS LEAK"
        }
        raidNote(evMsg)
    }

    private func raidEventEnd() {
        if evKind == 1 {
            let gun = ["ak", "m4", "awp", "p90"].randomElement() ?? "ak"
            let ids = ["g:\(gun):2", "plate", "med", "val:Gold Bars:500", "ammo"]
            for (j, id) in ids.enumerated() { dynAdd(evPos, id, j) }
            raidNote("SUPPLY DROP LANDED")
        }
        evKind = 0
        evMsg = ""
        evT = CGFloat.random(in: 55...85)
    }
}

// MARK: - HUD: status chips, events, screen effects

struct HudRaidStatus: View {
    let e: TacticalEngine

    private func chip(_ icon: String, _ text: String, _ col: Color) -> some View {
        HStack(spacing: 3) {
            SF(icon, "circle.fill").font(.system(size: 9, weight: .bold))
            Text(text).font(.jk(9, .heavy))
        }
        .foregroundColor(col).padding(.horizontal, 6).frame(height: 18)
        .background(Capsule().fill(Color.black.opacity(0.55)))
    }

    private var noiseText: String {
        let n = e.noiseNow
        if n <= 0 { return "SILENT" }
        if n < 120 { return "QUIET" }
        if n < 400 { return "NOISY" }
        return "LOUD"
    }

    private var noiseColor: Color {
        let n = e.noiseNow
        if n <= 0 { return TUI.green }
        if n < 120 { return TUI.accent }
        if n < 400 { return TUI.gold }
        return TUI.red
    }

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                chip("speaker.wave.2.fill", noiseText, noiseColor)
                chip("scope", "\(Int(e.gunDur))%", e.gunDur < 40 ? TUI.red : TacRarity.color(e.gunTier))
                if e.bleedT > 0 { chip("drop.fill", "BLEEDING", TUI.red) }
                if e.legWound { chip("figure.walk", "LEG", .orange) }
            }
            if e.alarmT > 0 {
                Text("ALARM  \(Int(e.alarmT))s").font(.jk(10, .heavy)).foregroundColor(TUI.red)
            }
            if e.evKind != 0 {
                Text("\(e.evMsg)  \(Int(max(0, e.evLeft)))s").font(.jk(10, .heavy)).foregroundColor(e.evKind == 4 ? TUI.green : TUI.gold)
            }
        }
        .shadow(color: .black.opacity(0.8), radius: 2)
    }
}

struct RaidFX: View {
    let e: TacticalEngine

    var body: some View {
        ZStack {
            if e.evKind == 3 {
                Color.black.opacity(0.5)
                RadialGradient(colors: [Color.clear, Color.black.opacity(0.75)], center: .center, startRadius: 120, endRadius: 520)
            }
            if e.bleedT > 0 {
                RadialGradient(colors: [Color.clear, Color.red.opacity(0.35)], center: .center, startRadius: 160, endRadius: 520)
            }
            if e.raidInGas {
                Color.green.opacity(0.16)
            }
            if e.alarmT > 0 {
                Color.red.opacity(0.07 + 0.06 * sin(Double(e.time) * 8))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - operations screen: contracts, trader, mastery

struct CSOps: View {
    @EnvironmentObject var game: Game
    let back: () -> Void
    @State private var tab = 0
    @State private var tick = 0

    private let tabNames = ["CONTRACTS", "TRADER", "MASTERY"]

    private func spend(_ n: Int) -> Bool {
        guard game.s.ex.gems >= n else { return false }
        var st = game.s
        st.ex.gems -= n
        game.s = st
        return true
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Button { tab = i } label: {
                    Text(tabNames[i]).font(.jk(11, .heavy)).foregroundColor(tab == i ? .black : .white)
                        .padding(.horizontal, 14).frame(height: 28)
                        .background(Rectangle().fill(tab == i ? CS.gold : Color.white.opacity(0.14)))
                }
                .buttonStyle(TuiPress())
            }
            Spacer()
        }
        .padding(.horizontal, 28).padding(.top, 8)
    }

    private func card<Content: View>(@ViewBuilder _ c: () -> Content) -> some View {
        c().padding(10).background(Color.black.opacity(0.6)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    // contracts
    private func contractCard(_ i: Int, _ c: RaidContract, _ lvl: Int) -> some View {
        let on = TacMeta.picked == i
        return card {
            HStack(spacing: 10) {
                SF("doc.text.fill", "circle.fill").font(.system(size: 18, weight: .bold)).foregroundColor(TUI.gold).frame(width: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(c.title).font(.jk(13, .heavy)).foregroundColor(.white)
                    Text(c.detail).font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.65))
                }
                Spacer()
                HStack(spacing: 3) {
                    SF("diamond.fill").font(.system(size: 10))
                    Text("+\(c.reward + 10 * lvl)").font(.jk(12, .heavy))
                }
                .foregroundColor(TUI.accent)
                Button { TacMeta.picked = i; tick += 1 } label: {
                    Text(on ? "ACTIVE" : "TAKE").font(.jk(10, .heavy)).foregroundColor(.black)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(Rectangle().fill(on ? TUI.green : CS.gold))
                }
                .buttonStyle(TuiPress())
            }
        }
    }

    private var contractsView: some View {
        let board = TacMeta.board
        let lvl = TacMeta.traderLevel
        let next: String = lvl + 1 < TacMeta.repLevels.count ? "NEXT LEVEL AT \(TacMeta.repLevels[lvl + 1])" : "MAX LEVEL"
        return VStack(spacing: 8) {
            HStack {
                Text("TRADER LEVEL \(lvl + 1)  ·  \(TacMeta.contractsDone) CONTRACTS DONE").font(.jk(11, .heavy)).foregroundColor(TUI.gold)
                Spacer()
                Text(next).font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.55))
            }
            ForEach(0..<board.count, id: \.self) { i in contractCard(i, TacMeta.contracts[board[i]], lvl) }
            Text("Finish your active contract and extract to claim the reward. A fresh board is posted after every raid.")
                .font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 28).padding(.top, 10)
    }

    // trader
    private func traderRow(_ it: TraderItem, _ lvl: Int) -> some View {
        let locked = it.level > lvl
        let have = TacMeta.loadoutCount(it.id)
        let afford = game.s.ex.gems >= it.price
        return card {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(it.name).font(.jk(13, .heavy)).foregroundColor(locked ? .white.opacity(0.4) : .white)
                    Text(locked ? "UNLOCKS AT TRADER LEVEL \(it.level + 1)" : it.desc).font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Text("IN KIT \(have)").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.6))
                Button {
                    guard !locked, have < 12, spend(it.price) else { return }
                    TacMeta.addLoadout(it.id)
                    tick += 1
                } label: {
                    HStack(spacing: 3) {
                        Text("BUY").font(.jk(10, .heavy))
                        SF("diamond.fill").font(.system(size: 9))
                        Text("\(it.price)").font(.jk(10, .heavy))
                    }
                    .foregroundColor(!locked && afford ? .black : .white.opacity(0.5))
                    .padding(.horizontal, 10).frame(height: 26)
                    .background(Rectangle().fill(!locked && afford ? CS.gold : Color.white.opacity(0.14)))
                }
                .buttonStyle(TuiPress())
            }
        }
    }

    private var traderView: some View {
        let lvl = TacMeta.traderLevel
        return VStack(spacing: 6) {
            ForEach(TacMeta.stock, id: \.id) { it in traderRow(it, lvl) }
            Text("Supplies are packed into your backpack at the start of the next raid. Unused ones come back with you when you extract.")
                .font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 28).padding(.top, 10)
    }

    // mastery
    private func masteryRow(_ id: String, _ name: String) -> some View {
        let xp = TacMeta.xp(id)
        let lv = TacMeta.level(id)
        let nextT: Int? = lv + 1 < TacMeta.thresholds.count ? TacMeta.thresholds[lv + 1] : nil
        let cur = TacMeta.thresholds[lv]
        var frac: CGFloat = 1
        if let n = nextT { frac = CGFloat(xp - cur) / CGFloat(max(1, n - cur)) }
        return card {
            HStack(spacing: 10) {
                Text(name).font(.jk(12, .heavy)).foregroundColor(.white).frame(width: 110, alignment: .leading)
                Text("LV \(lv)").font(.jk(11, .heavy)).foregroundColor(TUI.gold).frame(width: 36, alignment: .leading)
                Capsule().fill(Color.white.opacity(0.18)).frame(height: 6)
                    .overlay(alignment: .leading) { GeometryReader { g in Capsule().fill(TUI.accent).frame(width: g.size.width * max(0, min(1, frac))) } }
                Text("NEXT: \(TacMeta.nextUnlock(id))").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.6)).frame(width: 130, alignment: .trailing).lineLimit(1)
            }
        }
    }

    private var masteryView: some View {
        VStack(spacing: 6) {
            Text("Kills with a weapon raise its mastery: steadier recoil, more damage and free attachments at higher levels.")
                .font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.5))
            ForEach(TWeapons.all, id: \.id) { g in masteryRow(g.id, g.name) }
        }
        .padding(.horizontal, 28).padding(.top, 10)
    }

    var body: some View {
        _ = tick
        return GeometryReader { geo in
            VStack(spacing: 0) {
                CSHeader(title: "OPERATIONS", cash: game.s.ex.gems, coins: (game.s.ex.tac ?? TacData()).wins, back: back).padding(.top, 8)
                tabBar
                ScrollView(showsIndicators: false) {
                    Group {
                        if tab == 0 { contractsView } else if tab == 1 { traderView } else { masteryView }
                    }
                    .padding(.bottom, 16)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}
