import SwiftUI
import UIKit

// MARK: - persistent stash

struct RaidItem: Codable, Identifiable, Hashable {
    var id = UUID().uuidString
    var kind: String        // val, gun, part, intel, ammo, med, plate, band, kit
    var name: String
    var value: Int
    var ref = ""
    var issued = false
    var tier = 0
    var dur = 100
    var secure = false

    enum CodingKeys: String, CodingKey { case id, kind, name, value, ref, issued, tier, dur, secure }

    static func supply(_ kind: String) -> RaidItem {
        switch kind {
        case "med": return RaidItem(kind: "med", name: "Medkit", value: 25)
        case "plate": return RaidItem(kind: "plate", name: "Armor Plate", value: 30)
        case "band": return RaidItem(kind: "band", name: "Bandage", value: 8)
        case "kit": return RaidItem(kind: "kit", name: "Repair Kit", value: 25)
        default: return RaidItem(kind: "ammo", name: "Ammo Box", value: 20)
        }
    }
}

extension RaidItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        kind = try c.decodeIfPresent(String.self, forKey: .kind) ?? "val"
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Item"
        value = try c.decodeIfPresent(Int.self, forKey: .value) ?? 0
        ref = try c.decodeIfPresent(String.self, forKey: .ref) ?? ""
        issued = try c.decodeIfPresent(Bool.self, forKey: .issued) ?? false
        tier = try c.decodeIfPresent(Int.self, forKey: .tier) ?? 0
        dur = try c.decodeIfPresent(Int.self, forKey: .dur) ?? 100
        secure = try c.decodeIfPresent(Bool.self, forKey: .secure) ?? false
    }
}

enum TacStash {
    static let cap = 40
    private static let key = "ms.stash.v1"

    static var items: [RaidItem] {
        get {
            guard let d = UserDefaults.standard.data(forKey: key), let a = try? JSONDecoder().decode([RaidItem].self, from: d) else { return [] }
            return a
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(d, forKey: key) }
        }
    }

    static var totalValue: Int { items.reduce(0) { $0 + $1.value } }

    // backpack
    static let packNames = ["SMALL PACK", "FIELD PACK", "ASSAULT PACK", "TACTICAL PACK"]
    static let packCaps = [6, 10, 14, 20]
    static let packCosts = [0, 80, 220, 500]
    private static let packKey = "ms.pack.tier"
    static var packTier: Int {
        get { max(0, min(3, UserDefaults.standard.integer(forKey: packKey))) }
        set { UserDefaults.standard.set(max(0, min(3, newValue)), forKey: packKey) }
    }
    static var packCap: Int { packCaps[packTier] }

    // raid weapon (a stash gun risked in the next raid)
    private static let kitKey = "ms.kit.id"
    static var kitId: String? {
        get { UserDefaults.standard.string(forKey: kitKey) }
        set { if let v = newValue { UserDefaults.standard.set(v, forKey: kitKey) } else { UserDefaults.standard.removeObject(forKey: kitKey) } }
    }

    /// moves an extracted bag into the stash. Parts unlock instantly, supplies go back to your kit, overflow is sold. Returns the gems the overflow was worth.
    @discardableResult
    static func commit(_ bag: [RaidItem]) -> Int {
        var cur = items
        var sold = 0
        for it in bag {
            if it.issued { continue }
            if it.kind == "part" { if !it.ref.isEmpty { TAtt.own(it.ref) }; continue }
            if it.kind == "intel" { sold += it.value; continue }
            if ["ammo", "med", "plate", "band", "kit"].contains(it.kind) { TacMeta.addLoadout(it.kind); continue }
            var x = it
            x.secure = false
            if cur.count < cap { cur.append(x) } else { sold += it.value }
        }
        items = cur
        return sold
    }

    static func update(_ it: RaidItem) {
        var cur = items
        if let i = cur.firstIndex(where: { $0.id == it.id }) { cur[i] = it; items = cur }
    }

    static func remove(_ id: String) {
        items = items.filter { $0.id != id }
    }
}

// MARK: - raid rules

struct RaidZone {
    let pos: CGPoint
    let name: String
    let key: Bool
    let hold: CGFloat
    let loud: Bool
}

extension TacticalEngine {
    static let warehouseZones: [RaidZone] = [
        RaidZone(pos: CGPoint(x: 2740 + 3200, y: 440), name: "EAST GATE", key: false, hold: 8, loud: false),
        RaidZone(pos: CGPoint(x: 1500 + 3200, y: 900), name: "CENTRAL YARD", key: false, hold: 14, loud: true),
        RaidZone(pos: CGPoint(x: 1500 + 3200, y: 1650), name: "SOUTH DOCK", key: true, hold: 8, loud: false)
    ]
    static let harborZones: [RaidZone] = [
RaidZone(pos: CGPoint(x: 5200 + 10600, y: 170), name: "NORTH GATE", key: false, hold: 8, loud: false),
RaidZone(pos: CGPoint(x: 5200 + 10600, y: 5200), name: "CENTRAL TERMINAL", key: false, hold: 14, loud: true),
RaidZone(pos: CGPoint(x: 7800 + 10600, y: 10230), name: "SOUTH PIER", key: true, hold: 8, loud: false),
RaidZone(pos: CGPoint(x: 10230 + 10600, y: 3200), name: "EAST PIER", key: false, hold: 8, loud: false),
RaidZone(pos: CGPoint(x: 170 + 10600, y: 3500), name: "WEST QUAY", key: false, hold: 8, loud: false),
    ]
    static var raidZones: [RaidZone] { TMap.kind == 4 ? harborZones : warehouseZones }

    var bagValue: Int { raidBag.reduce(0) { $0 + $1.value } }
    static let raidAmmoCap = 8
    var raidBagFull: Bool { raidBag.count >= TacStash.packCap }

    static func isBagKind(_ id: String) -> Bool {
        let k = id.split(separator: ":").first.map(String.init) ?? ""
        return ["val", "part", "intel", "g", "med", "ammo"].contains(k)
    }

    var contractText: String {
        switch contractKind {
        case 0: return "ELIMINATE 4 HOSTILES  \(min(4, me.kills))/4"
        case 1: return raidBag.contains(where: { $0.kind == "intel" }) ? "INTEL SECURED" : "RECOVER THE INTEL (OFFICE)"
        case 2: return "SECURE 3 VALUABLES  \(min(3, raidBag.filter { $0.kind == "val" }.count))/3"
        case 3: return cmdKilled > 0 ? "COMMANDER DOWN" : "ELIMINATE A COMMANDER"
        case 4: return "HOLD CENTRAL YARD  \(Int(min(20, holdT)))/20s"
        default: return vaultsOpened > 0 ? "VAULT CRACKED" : (raidHasKey ? "CRACK A VAULT" : "FIND AN ACCESS CARD  ·  CRACK A VAULT")
        }
    }

    func raidNote(_ s: String) { raidMsg = s; raidMsgT = 2.5 }

    func raidContinue() {
        replayOn = false
        brEndT = 0
    }

    func raidStart() {
        loot = TMap.lootSpots.map { Loot(pos: $0.0, id: $0.1, taken: false) }
        dynBase = loot.count
        for _ in 0..<36 { loot.append(Loot(pos: .zero, id: "", taken: true)) }
        var a0 = RaidItem.supply("ammo")
        a0.issued = true
        var a1 = RaidItem.supply("ammo")
        a1.issued = true
        raidBag = [a0, a1]
        for k in TacMeta.takeLoadout(room: max(0, TacStash.packCap - raidBag.count)) { raidBag.append(RaidItem.supply(k)) }
        raidEquipped = nil
        raidBagOpen = false
        gunTier = 0
        gunDur = 100
        if let kid = TacStash.kitId, let it = TacStash.items.first(where: { $0.id == kid }), it.kind == "gun" {
            raidEquipped = it
            TacStash.remove(kid)
            setGun(me, it.ref)
            gunTier = it.tier
            gunDur = CGFloat(it.dur)
        }
        TacStash.kitId = nil
        raidHasKey = TacMeta.takeCard()
        raidZoneT = 0
        raidZoneIdx = -1
        raidExtracted = false
        raidCommitted = false
        raidSold = 0
        raidLoudT = 0
        let c = TacMeta.pickedContract
        contractKind = c.kind
        contractDone = false
        contractReward = c.reward + 10 * TacMeta.traderLevel
        holdT = 0
        cmdKilled = 0
        vaultsOpened = 0
        bleedT = 0
        legWound = false
        noiseR = 0
        noiseNow = 0
        hearT = 0
        evKind = 0
        evLeft = 0
        evMsg = ""
        evT = CGFloat.random(in: 45...75)
        alarmT = 0
        alarmPulse = 0
        raidSecureEq = false
        raidSetupFactions()
        brPlace = 0
        brEndT = 3
        raidNote("DEPLOYED  ·  FIND LOOT, EXTRACT ALIVE")
    }

    var raidGems: Int {
        (won ? 25 : 5) + kills * 3 + (won && contractDone ? contractReward : 0)
    }

    private func raidCollect(_ id: String) {
        let parts = id.split(separator: ":").map(String.init)
        let arg = parts.count > 1 ? parts[1] : ""
        switch parts[0] {
        case "val":
            let v = parts.count > 2 ? (Int(parts[2]) ?? 100) : 100
            raidBag.append(RaidItem(kind: "val", name: arg, value: v))
            raidNote("+ \(arg.uppercased())  ($\(v))")
        case "part":
            raidBag.append(RaidItem(kind: "part", name: TAtt.def(arg)?.name ?? arg, value: 0, ref: arg))
            raidNote("+ \((TAtt.def(arg)?.name ?? arg).uppercased())")
        case "intel":
            raidBag.append(RaidItem(kind: "intel", name: "Intel", value: 150))
            raidNote("INTEL RECOVERED")
        case "key":
            raidHasKey = true
            raidNote("ACCESS CARD  ·  VAULTS + SOUTH DOCK UNLOCKED")
        case "g":
            let minT = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0
            raidBag.append(raidRollGun(arg, minTier: minT))
            let t = raidBag[raidBag.count - 1].tier
            raidNote("+ \(TacRarity.name(t))  \(TGuns.get(arg).name.uppercased())")
        case "med", "plate", "band", "kit", "ammo":
            let it = RaidItem.supply(parts[0])
            raidBag.append(it)
            raidNote("+ \(it.name.uppercased())")
        case "vault":
            if arg.hasPrefix("B") {
                raidBag.append(RaidItem(kind: "val", name: "Mythic Relic", value: 4000))
                raidBag.append(raidRollGun(["ak", "m4", "awp", "p90"].randomElement() ?? "ak", minTier: 5))
                raidBag.append(RaidItem.supply("plate"))
            } else {
                raidBag.append(RaidItem(kind: "val", name: "Gold Bars", value: 600))
                raidBag.append(raidRollGun(["ak", "m4", "awp", "p90"].randomElement() ?? "ak", minTier: 2))
                raidBag.append(RaidItem.supply("plate"))
            }
            vaultsOpened += 1
            alarmT = 25
            alarmPulse = 0
            raidNote("VAULT OPEN  ·  ALARM TRIGGERED")
        default:
            break
        }
    }

    func raidFeedAmmo() {
        guard let i = raidBag.firstIndex(where: { $0.kind == "ammo" }) else { return }
        raidBag.remove(at: i)
        me.spare = min(TacticalEngine.raidAmmoCap, me.spare + 2)
        raidNote("+2 MAGS FROM BACKPACK")
    }

    func raidUse(_ id: String) {
        guard let i = raidBag.firstIndex(where: { $0.id == id }) else { return }
        let it = raidBag[i]
        switch it.kind {
        case "med":
            guard me.hp < 100 || bleedT > 0 || legWound else { raidNote("ALREADY AT FULL HEALTH"); return }
            raidBag.remove(at: i)
            me.hp = min(100, me.hp + 45)
            bleedT = 0
            legWound = false
            pop(me.pos, "+45", .green)
        case "band":
            guard bleedT > 0 || me.hp < 100 else { raidNote("NOT BLEEDING"); return }
            raidBag.remove(at: i)
            bleedT = 0
            me.hp = min(100, me.hp + 10)
            pop(me.pos, "BANDAGED", .green)
        case "plate":
            guard me.armorKind >= 1 else { raidNote("NEED A VEST TO FIT PLATES"); return }
            let cap: CGFloat = me.armorKind >= 3 ? 150 : (me.armorKind == 2 ? 100 : 60)
            guard me.armor < cap else { raidNote("ARMOR FULL"); return }
            raidBag.remove(at: i)
            me.armor = min(cap, me.armor + 50)
            pop(me.pos, "PLATE", .blue)
        case "kit":
            guard gunDur < 100 else { raidNote("WEAPON IN GOOD SHAPE"); return }
            raidBag.remove(at: i)
            gunDur = min(100, gunDur + 50)
            pop(me.pos, "REPAIRED", .yellow)
        case "ammo":
            guard !TWeapons.isPistol(me.gun), me.spare < TacticalEngine.raidAmmoCap else { raidNote("AMMO FULL"); return }
            raidBag.remove(at: i)
            me.spare = min(TacticalEngine.raidAmmoCap, me.spare + 2)
            pop(me.pos, "AMMO", .yellow)
        case "gun":
            raidBag.remove(at: i)
            var prev = raidEquipped ?? RaidItem(kind: "gun", name: TGuns.get(me.gun).name + " (issued)", value: 0, ref: me.gun)
            if raidEquipped == nil { prev.issued = true }
            prev.dur = Int(gunDur)
            prev.tier = gunTier
            prev.secure = raidSecureEq
            raidBag.append(prev)
            raidSecureEq = it.secure
            raidEquipped = it
            raidEquipped?.secure = false
            gunTier = it.tier
            gunDur = CGFloat(it.dur)
            setGun(me, it.ref)
            raidNote("EQUIPPED \(TacRarity.name(it.tier))  \(TGuns.get(it.ref).name.uppercased())")
        default:
            break
        }
    }

    func raidDrop(_ id: String) {
        raidBag.removeAll { $0.id == id }
    }

    /// safe pouch: one item (or the equipped stash gun) is kept even if you die
    func raidToggleSecure(_ id: String?) {
        if let id = id {
            guard let i = raidBag.firstIndex(where: { $0.id == id }), !raidBag[i].issued else { return }
            let on = !raidBag[i].secure
            raidClearSecure()
            raidBag[i].secure = on
        } else {
            guard raidEquipped != nil else { return }
            let on = !raidSecureEq
            raidClearSecure()
            raidSecureEq = on
        }
    }

    private func raidClearSecure() {
        for i in raidBag.indices { raidBag[i].secure = false }
        raidSecureEq = false
    }

    func raidSecureCommit() -> Int {
        var items = raidBag.filter { $0.secure && !$0.issued }
        if raidSecureEq, var q = raidEquipped {
            q.dur = Int(gunDur)
            items.append(q)
        }
        return TacStash.commit(items)
    }

    func raidAlertBots() {
        for p in players where !p.isPlayer && p.alive { p.lastSeen = me.pos; p.hunt = 6 }
    }

    func raidTick(_ dt: CGFloat) {
        for i in loot.indices where !loot[i].taken && !loot[i].id.isEmpty {
            let lp = loot[i].pos
            let lf = TMap.floorOf(lp)
            for p in players where p.alive && TMap.floorOf(p.pos) == lf && tDist(p.pos, lp) < 28 {
                if lootUse(p, loot[i].id, apply: true) {
                    loot[i].taken = true
                    if p.isPlayer { raidCollect(loot[i].id) }
                    break
                } else if p.isPlayer {
                    raidRefuse(loot[i].id)
                }
            }
        }
        raidMsgT = max(0, raidMsgT - dt)
        raidSurvival(dt)
        raidEventTick(dt)
        if !contractDone {
            if contractKind == 4 && me.alive && TMap.floorOf(me.pos) == TMap.floorOf(TacticalEngine.raidZones[1].pos) && tDist(me.pos, TacticalEngine.raidZones[1].pos) < 120 { holdT += dt }
            switch contractKind {
            case 0: contractDone = me.kills >= 4
            case 1: contractDone = raidBag.contains(where: { $0.kind == "intel" })
            case 2: contractDone = raidBag.filter { $0.kind == "val" }.count >= 3
            case 3: contractDone = cmdKilled >= 1
            case 4: contractDone = holdT >= 20
            default: contractDone = vaultsOpened >= 1
            }
            if contractDone { raidNote("CONTRACT COMPLETE  ·  EXTRACT TO CLAIM +\(contractReward)") }
        }
        if me.alive && !raidExtracted {
            var inZ = -1
            for (i, z) in TacticalEngine.raidZones.enumerated() where tDist(me.pos, z.pos) < 55 { inZ = i }
            if inZ != raidZoneIdx {
                raidZoneIdx = inZ
                raidZoneT = 0
                if inZ >= 0 {
                    let z = TacticalEngine.raidZones[inZ]
                    if z.key && !raidHasKey { raidNote("ACCESS CARD REQUIRED") }
                    else if z.loud { raidNote("LOUD EXTRACTION  ·  HOSTILES ALERTED"); raidAlertBots() }
                    else { raidNote("EXTRACTING  ·  HOLD POSITION") }
                }
            }
            if inZ >= 0 {
                let z = TacticalEngine.raidZones[inZ]
                if !(z.key && !raidHasKey) {
                    raidZoneT += dt
                    if z.loud {
                        raidLoudT -= dt
                        if raidLoudT <= 0 { raidLoudT = 3; raidAlertBots() }
                    }
                    if raidZoneT >= z.hold {
                        raidExtracted = true
                        if !raidCommitted {
                            raidCommitted = true
                            var eq = raidEquipped
                            eq?.dur = Int(gunDur)
                            raidSold = TacStash.commit(raidBag + (eq.map { [$0] } ?? []))
                            if contractDone { TacMeta.contractsDone += 1 }
                            TacMeta.rollBoard()
                        }
                        phase = 4
                        over = true
                        won = true
                        banner = "EXTRACTED"
                        bannerT = 3
                    }
                }
            }
        }
        if !me.alive {
            if !(replayOn && !replayDone) { brEndT -= dt }
            if !raidCommitted {
                raidCommitted = true
                raidSold = raidSecureCommit()
                TacMeta.rollBoard()
            }
            if brEndT <= 0 { phase = 4; over = true; won = false; banner = "K.I.A."; bannerT = 3 }
        }
    }

    /// bots patrol rooms, scavenge nearby loot and sometimes hunt the player
    func raidGoal(_ p: TPlayer) -> CGPoint {
        if p.faction == 2 { return p.home }
        if p.faction == 1 || p.faction == 3 || p.faction == 4 { return raidPost(p) }
        if p.roam != .zero && p.goalT > time && tDist(p.pos, p.roam) > 40 { return p.roam }
        p.goalT = time + CGFloat.random(in: 4...8)
        var dest = p.roam
        var best: CGPoint? = nil
        var bs = CGFloat.greatestFiniteMagnitude
        for l in loot where !l.taken {
            if !lootUse(p, l.id, apply: false) { continue }
            let d = tDist(l.pos, p.pos)
            if d < 700 && d < bs { bs = d; best = l.pos }
        }
        if let b = best {
            dest = b
        } else if me.alive && Int.random(in: 0..<100) < 30 && TMap.pdist(p.pos, me.pos) < 650 && TMap.floorOf(p.pos) == TMap.floorOf(me.pos) {
            dest = me.pos
        } else {
            let pf = TMap.floorOf(p.pos)
            let near = TMap.rooms.filter { $0.fl == pf && hypot($0.r.midX - p.pos.x, $0.r.midY - p.pos.y) < 1100 }
            if let r = near.randomElement() ?? TMap.rooms.randomElement() {
                dest = CGPoint(x: r.r.midX + CGFloat.random(in: -50...50), y: r.r.midY + CGFloat.random(in: -50...50))
            }
        }
        p.roam = dest
        return dest
    }
}

// MARK: - HUD

struct HudRaidBar: View {
    let e: TacticalEngine
    var body: some View {
        let inZ = e.raidZoneIdx
        return VStack(spacing: 3) {
            HStack(spacing: 12) {
                HStack(spacing: 5) {
                    SF(e.contractDone ? "checkmark.circle.fill" : "doc.text.fill").font(.system(size: 12, weight: .bold)).foregroundColor(e.contractDone ? TUI.green : TUI.gold)
                    Text(e.contractText).font(.jk(11, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                }
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18)
                HStack(spacing: 4) {
                    SF("bag.fill", "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(TUI.accent)
                    Text("\(e.raidBag.count)").font(.system(size: 16, weight: .heavy, design: .monospaced)).monospacedDigit()
                    Text("$\(e.bagValue)").font(.jk(11, .heavy)).foregroundColor(TUI.green)
                }
                if e.raidHasKey {
                    SF("key.fill", "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(TUI.gold)
                }
                Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 18)
                HStack(spacing: 4) {
                    SF("scope", "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(TUI.gold)
                    Text("\(e.me.kills)").font(.system(size: 16, weight: .heavy, design: .monospaced)).monospacedDigit()
                }
            }
            .foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).hudFloat(18)
            HudRaidStatus(e: e)
            if inZ >= 0 {
                let z = TacticalEngine.raidZones[inZ]
                let need = z.key && !e.raidHasKey
                VStack(spacing: 2) {
                    Text(need ? "\(z.name)  ·  ACCESS CARD REQUIRED" : "EXTRACTING  ·  \(z.name)").font(.jk(10, .heavy)).foregroundColor(need ? TUI.red : TUI.green)
                    Capsule().fill(Color.white.opacity(0.22)).frame(width: 180, height: 7)
                        .overlay(alignment: .leading) { Capsule().fill(TUI.green).frame(width: 180 * min(1, e.raidZoneT / max(1, z.hold)), height: 7) }
                }
            } else if e.raidMsgT > 0 {
                Text(e.raidMsg).font(.jk(10, .heavy)).foregroundColor(.white).shadow(color: .black.opacity(0.8), radius: 2)
            }
        }
    }
}

// MARK: - stash screen

struct CSStash: View {
    @EnvironmentObject var game: Game
    let back: () -> Void
    var ops: () -> Void = {}
    @State private var tick = 0

    private func icon(_ k: String) -> String {
        switch k { case "gun": return "scope"; case "part": return "wrench.and.screwdriver.fill"; case "intel": return "doc.text.fill"; default: return "diamond.fill" }
    }

    private func repairCost(_ it: RaidItem) -> Int { max(1, (100 - it.dur) / 3) }

    private func repair(_ it: RaidItem) {
        let c = repairCost(it)
        guard it.dur < 100, game.s.ex.gems >= c else { return }
        var st = game.s
        st.ex.gems -= c
        game.s = st
        var x = it
        x.dur = 100
        TacStash.update(x)
        tick += 1
    }

    private func sub(_ it: RaidItem) -> String {
        it.kind == "gun" ? "\(TacRarity.name(it.tier))  ·  \(it.dur)%" : "VALUABLE"
    }

    private func sell(_ it: RaidItem) {
        var st = game.s
        st.ex.gems += it.value
        game.s = st
        TacStash.remove(it.id)
        tick += 1
    }

    private var packPanel: some View {
        let t = TacStash.packTier
        let next = t + 1 < TacStash.packNames.count ? t + 1 : nil
        return HStack(spacing: 10) {
            SF("bag.fill", "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(TUI.accent)
            Text("\(TacStash.packNames[t])  ·  \(TacStash.packCap) SLOTS").font(.jk(12, .heavy)).foregroundColor(.white)
            if let n = next {
                Button {
                    let cost = TacStash.packCosts[n]
                    guard game.s.ex.gems >= cost else { return }
                    var st = game.s
                    st.ex.gems -= cost
                    game.s = st
                    TacStash.packTier = n
                    tick += 1
                } label: {
                    HStack(spacing: 4) {
                        Text("UPGRADE  \(TacStash.packNames[n])").font(.jk(10, .heavy))
                        SF("diamond.fill").font(.system(size: 9))
                        Text("\(TacStash.packCosts[n])").font(.jk(10, .heavy))
                    }
                    .foregroundColor(game.s.ex.gems >= TacStash.packCosts[n] ? .black : .white.opacity(0.6)).padding(.horizontal, 8).frame(height: 24)
                    .background(Rectangle().fill(game.s.ex.gems >= TacStash.packCosts[n] ? CS.gold : Color.white.opacity(0.15)))
                }
                .buttonStyle(TuiPress())
            } else {
                Text("MAX").font(.jk(10, .heavy)).foregroundColor(TUI.green)
            }
            Button { ops() } label: {
                Text("OPERATIONS").font(.jk(10, .heavy)).foregroundColor(.black).padding(.horizontal, 8).frame(height: 24).background(Rectangle().fill(CS.gold))
            }
            .buttonStyle(TuiPress())
            Spacer()
            if let k = TacStash.kitId, let it = TacStash.items.first(where: { $0.id == k }) {
                Text("RAID WEAPON: \(it.name.uppercased())").font(.jk(10, .heavy)).foregroundColor(Color(red: 0.4, green: 0.95, blue: 0.4))
            } else {
                Text("RAID WEAPON: ISSUED").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 28).padding(.top, 6)
    }

    private func sellAll() {
        let total = TacStash.totalValue
        var st = game.s
        st.ex.gems += total
        game.s = st
        TacStash.items = []
        TacStash.kitId = nil
        tick += 1
    }

    var body: some View {
        _ = tick
        let items = TacStash.items
        return GeometryReader { geo in
            let W = geo.size.width, H = geo.size.height
            ZStack {
                VStack(spacing: 0) {
                    CSHeader(title: "STASH", cash: game.s.ex.gems, coins: (game.s.ex.tac ?? TacData()).wins, back: back).padding(.top, 8)
                    packPanel
                    HStack(spacing: 14) {
                        Text("\(items.count)/\(TacStash.cap) SLOTS").font(.jk(12, .heavy)).foregroundColor(.white.opacity(0.8))
                        Text("VALUE $\(TacStash.totalValue)").font(.jk(12, .heavy)).foregroundColor(TUI.green)
                        Spacer()
                        CSButton(title: "SELL ALL", col: CS.orange, dark: CS.orangeDark, w: 130, h: 32, size: 12) { sellAll() }
                    }
                    .padding(.horizontal, 28).padding(.top, 8)
                    if items.isEmpty {
                        Spacer()
                        VStack(spacing: 6) {
                            SF("bag.fill", "circle.fill").font(.system(size: 34)).foregroundColor(.white.opacity(0.35))
                            Text("Your stash is empty").font(.jk(16, .heavy)).foregroundColor(.white.opacity(0.8))
                            Text("Deploy on an Extraction raid, loot the Warehouse Yard and extract alive to keep what you find.").font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.55)).multilineTextAlignment(.center)
                        }
                        .frame(width: min(W - 80, 420))
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                                ForEach(items) { it in
                                    HStack(spacing: 8) {
                                        SF(icon(it.kind), "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(it.kind == "gun" ? TUI.blue : TUI.gold).frame(width: 26)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(it.name).font(.jk(12, .heavy)).foregroundColor(it.kind == "gun" ? TacRarity.color(it.tier) : .white).lineLimit(1)
                                            Text(sub(it)).font(.jk(8, .heavy)).foregroundColor(.white.opacity(0.5))
                                        }
                                        Spacer(minLength: 0)
                                        if it.kind == "gun" && it.dur < 100 {
                                            Button { repair(it) } label: {
                                                Text("FIX \(repairCost(it))").font(.jk(10, .heavy)).foregroundColor(.white).padding(.horizontal, 6).frame(height: 24).background(Rectangle().fill(Color.white.opacity(0.2)))
                                            }
                                            .buttonStyle(TuiPress())
                                        }
                                        if it.kind == "gun" {
                                            let on = TacStash.kitId == it.id
                                            Button { TacStash.kitId = on ? nil : it.id; tick += 1 } label: {
                                                Text(on ? "KIT ✓" : "EQUIP").font(.jk(10, .heavy)).foregroundColor(on ? .black : .white).padding(.horizontal, 7).frame(height: 24).background(Rectangle().fill(on ? Color(red: 0.4, green: 0.95, blue: 0.4) : CS.blue))
                                            }
                                            .buttonStyle(TuiPress())
                                        }
                                        Button { sell(it) } label: {
                                            Text("$\(it.value)").font(.jk(11, .heavy)).foregroundColor(.black).padding(.horizontal, 8).frame(height: 24).background(Rectangle().fill(CS.gold))
                                        }
                                        .buttonStyle(TuiPress())
                                    }
                                    .padding(8).background(Color.black.opacity(0.6)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, 28).padding(.vertical, 10)
                        }
                    }
                }
            }
            .frame(width: W, height: H)
        }
    }
}


// MARK: - in-raid backpack

struct RaidBagPanel: View {
    let e: TacticalEngine

    private func icon(_ k: String) -> String {
        switch k {
        case "gun": return "scope"
        case "med": return "cross.case.fill"
        case "band": return "bandage.fill"
        case "plate": return "shield.fill"
        case "kit": return "wrench.fill"
        case "ammo": return "shippingbox.fill"
        case "part": return "wrench.and.screwdriver.fill"
        case "intel": return "doc.text.fill"
        default: return "diamond.fill"
        }
    }

    private func label(_ it: RaidItem) -> String {
        switch it.kind {
        case "gun": return "EQUIP"
        case "med", "band", "plate": return "USE"
        case "kit": return "FIX"
        case "ammo": return "LOAD"
        default: return ""
        }
    }

    private func chip(_ t: String, _ bg: Color, _ fg: Color = .black) -> some View {
        Text(t).font(.jk(9, .heavy)).foregroundColor(fg).padding(.horizontal, 7).frame(height: 22).background(Rectangle().fill(bg))
    }

    private func row(_ it: RaidItem) -> some View {
        HStack(spacing: 6) {
            SF(icon(it.kind), "circle.fill").font(.system(size: 14, weight: .bold)).foregroundColor(it.kind == "gun" ? TacRarity.color(it.tier) : TUI.gold).frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(it.name).font(.jk(12, .heavy)).foregroundColor(it.kind == "gun" ? TacRarity.color(it.tier) : .white).lineLimit(1)
                if it.kind == "gun" {
                    Text("\(TacRarity.name(it.tier))  ·  \(it.dur)%").font(.jk(8, .heavy)).foregroundColor(.white.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
            if it.value > 0 { Text("$\(it.value)").font(.jk(10, .heavy)).foregroundColor(TUI.green) }
            if !it.issued {
                Button { e.raidToggleSecure(it.id) } label: { chip(it.secure ? "SAFE ✓" : "SAFE", it.secure ? TUI.green : Color.white.opacity(0.18), it.secure ? .black : .white) }
                    .buttonStyle(TuiPress())
            }
            if !label(it).isEmpty {
                Button { e.raidUse(it.id) } label: { chip(label(it), CS.gold) }.buttonStyle(TuiPress())
            }
            Button { e.raidDrop(it.id) } label: { chip("DROP", Color.white.opacity(0.18), .white) }.buttonStyle(TuiPress())
        }
        .padding(7).background(Color.black.opacity(0.6)).overlay(Rectangle().stroke(Color.white.opacity(0.2), lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 8) {
            SF("bag.fill", "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(TUI.accent)
            Text(TacStash.packNames[TacStash.packTier]).font(.jk(14, .heavy)).foregroundColor(.white)
            Text("\(e.raidBag.count)/\(TacStash.packCap)").font(.jk(13, .heavy)).foregroundColor(e.raidBagFull ? TUI.red : TUI.green)
            Spacer()
            Button { e.raidBagOpen = false } label: {
                SF("xmark").font(.system(size: 13, weight: .bold)).foregroundColor(.white).frame(width: 30, height: 30).background(Circle().fill(Color.white.opacity(0.15)))
            }
            .buttonStyle(TuiPress())
        }
    }

    private var equipped: some View {
        HStack(spacing: 8) {
            Text("EQUIPPED").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.5))
            Text(TGuns.get(e.me.gun).name.uppercased()).font(.jk(11, .heavy)).foregroundColor(TacRarity.color(e.gunTier))
            Text("\(TacRarity.name(e.gunTier))  ·  \(Int(e.gunDur))%").font(.jk(9, .heavy)).foregroundColor(e.gunDur < 40 ? TUI.red : .white.opacity(0.6))
            Spacer()
            if e.raidEquipped != nil {
                Button { e.raidToggleSecure(nil) } label: { chip(e.raidSecureEq ? "SAFE ✓" : "SAFE", e.raidSecureEq ? TUI.green : Color.white.opacity(0.18), e.raidSecureEq ? .black : .white) }
                    .buttonStyle(TuiPress())
            }
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture { e.raidBagOpen = false }
            VStack(spacing: 7) {
                header
                equipped
                if e.raidBag.isEmpty {
                    Text("Backpack is empty").font(.jk(12, .semibold)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity, minHeight: 70)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 5) {
                            ForEach(e.raidBag) { it in row(it) }
                        }
                    }
                    .frame(maxHeight: 170)
                }
                Text("SAFE: one item (or your stash gun) survives death").font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.45))
            }
            .padding(14).frame(width: 470).background(Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.96)).overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
    }
}
