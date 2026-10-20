import SwiftUI

// MARK: - Frontline: large-scale conquest on the Harbor map (mode 7)

struct FLMsg {
    var who: String
    var text: String
    var life: CGFloat
    var sys: Bool
}

enum TFront {
    static let bots = 99                 // + the player = 100 combatants
    static let tickets = 250
    static let minutes: CGFloat = 25
    static let letters = ["A", "B", "C", "D", "E"]
    static let classNames = ["ASSAULT", "MEDIC", "SUPPORT", "RECON", "ENGINEER"]
    static let classIcons = ["chevron.up.2", "cross.fill", "shippingbox.fill", "scope", "wrench.and.screwdriver.fill"]
    static let classInfo = ["Close combat, rifles", "Heals nearby squad", "Resupplies ammo", "Long range spotting", "Extra grenades"]
    static let classGuns: [[String]] = [["rifle", "ak", "m4"], ["smg", "mp7"], ["p90", "ak"], ["awp", "m4"], ["shotgun", "pump"]]

    /// harbor hold zones re-ordered as A west quay, B north gate, C central terminal, D east pier, E south pier
    static var zoneList: [RaidZone] {
        let z = TacticalEngine.harborZones
        return [z[4], z[0], z[1], z[3], z[2]]
    }

    static var zones: [CGRect] = TFront.zoneList.map { CGRect(x: $0.pos.x - 230, y: $0.pos.y - 230, width: 460, height: 460) }
    static var bases: [[CGPoint]] = [[], []]

    static func prepare() {
        zones = zoneList.map { CGRect(x: $0.pos.x - 230, y: $0.pos.y - 230, width: 460, height: 460) }
        let off = TMap.off, w = THarbor.W
        let pts = TMap.spreadPoints(260, sep: 260).filter { TMap.floorOfX($0.x) == 1 }
        func near(_ c: CGPoint) -> [CGPoint] {
            Array(pts.sorted { hypot($0.x - c.x, $0.y - c.y) < hypot($1.x - c.x, $1.y - c.y) }.prefix(14))
        }
        var b0 = near(CGPoint(x: off + 500, y: w - 500))
        var b1 = near(CGPoint(x: off + w - 500, y: 500))
        if b0.isEmpty { b0 = TMap.atkSpawn }
        if b1.isEmpty { b1 = TMap.defSpawn }
        bases = [b0, b1]
    }

    static func assign(_ ps: [TPlayer]) {
        for p in ps {
            if p.isPlayer { p.cls = TacticalEngine.flClass; p.fl = 1; continue }
            if p.team == 0 && p.id <= 3 { p.fl = 1; p.cls = [1, 2, 3][p.id - 1]; continue }
            p.fl = 0
            p.cls = [0, 0, 1, 2, 3, 4, 0, 0, 1, 2][p.id % 10]
        }
    }
}

extension TacticalEngine {
    func flSay(_ who: String, _ text: String, sys: Bool = false) {
        flChat.append(FLMsg(who: who, text: text, life: 9, sys: sys))
        if flChat.count > 4 { flChat.removeFirst() }
    }

    func flOwned(_ team: Int, _ i: Int) -> Bool { team == 0 ? cpProg[i] >= 1 : cpProg[i] <= -1 }

    private func flAround(_ c: CGPoint, _ r: CGFloat) -> CGPoint {
        let t = CGPoint(x: c.x + CGFloat.random(in: -r...r), y: c.y + CGFloat.random(in: -r...r))
        return TNav.center(TNav.nearestFree(TNav.idx(t)))
    }

    // MARK: respawn

    func frontRespawn(_ p: TPlayer) {
        let zs = cpZones
        var pos: CGPoint? = nil
        if p.isPlayer {
            if flSpawn == 10, let m = players.first(where: { $0.alive && !$0.isPlayer && $0.fl == p.fl }) {
                pos = flAround(m.pos, 60)
            } else if flSpawn >= 0 && flSpawn < 5 && flOwned(p.team, flSpawn) {
                pos = flAround(CGPoint(x: zs[flSpawn].midX, y: zs[flSpawn].midY), 120)
            }
        } else if Int.random(in: 0..<100) < 40 {
            let ow = (0..<5).filter { flOwned(p.team, $0) }
            if let i = ow.randomElement() { pos = flAround(CGPoint(x: zs[i].midX, y: zs[i].midY), 140) }
        }
        if pos == nil {
            let list = TFront.bases[p.team].isEmpty ? TMap.atkSpawn : TFront.bases[p.team]
            var best = list[0], bd: CGFloat = -1
            for c in list {
                var near = CGFloat.greatestFiniteMagnitude
                for e in players where e.alive && e.team != p.team { near = min(near, tDist(c, e.pos)) }
                near += CGFloat.random(in: 0...400)
                if near > bd { bd = near; best = c }
            }
            pos = flAround(best, 50)
        }
        p.pos = pos ?? TMap.atkSpawn[0]
        p.hp = 100; p.armor = 100; p.armorKind = 1; p.alive = true; p.blind = 0; p.crouch = false
        p.path = []; p.targetID = -1; p.hunt = 0; p.reloadT = 0; p.fireCd = 0; p.hiding = false; p.cover = nil
        p.respawn = 0
        let cls = min(4, max(0, p.cls))
        p.nades = [2, 1, 1, 1, 3][cls]
        p.smokes = cls == 1 ? 2 : 1
        p.flashes = 1
        p.aim = TMap.aimAtCenter(p.pos)
        setGun(p, p.isPlayer ? myGun : (TFront.classGuns[cls].randomElement() ?? "rifle"))
        if cls == 2 && !TWeapons.isPistol(p.gun) { p.spare = 4 }
        if p.isPlayer { p.spare += TPerk.spareBonus; p.armor = TPerk.armor }
        if p.isPlayer {
            scoped = false; pitch = 0
            p.altGun = TacticalEngine.altFor(p.gun)
            p.altMag = magSize(p, p.altGun)
            p.altSpare = 99
        }
    }

    // MARK: ai goal

    func frontGoal(_ p: TPlayer) -> CGPoint {
        let zs = cpZones
        func around(_ r: CGRect) -> CGPoint {
            CGPoint(x: r.midX + cos(CGFloat(p.id) * 1.9) * r.width * 0.3, y: r.midY + sin(CGFloat(p.id) * 2.7) * r.height * 0.3)
        }
        if p.fl == 1 && !p.isPlayer && me.alive && me.team == p.team && tDist(me.pos, p.pos) > 130 {
            let a = CGFloat(p.id) * 2.1
            return CGPoint(x: me.pos.x + cos(a) * 70, y: me.pos.y + sin(a) * 70)
        }
        let cen: [CGPoint] = zs.map { CGPoint(x: $0.midX, y: $0.midY) }
        let order: [Int] = (0..<5).sorted { (a: Int, b: Int) -> Bool in tDist(cen[a], p.pos) < tDist(cen[b], p.pos) }
        let notMine = order.filter { !flOwned(p.team, $0) }
        if p.id % 4 == 0, let d = order.first(where: { flOwned(p.team, $0) }) { return around(zs[d]) }
        if !notMine.isEmpty { return around(zs[notMine[min(notMine.count - 1, p.id % 2)]]) }
        return around(zs[order[p.id % 5]])
    }

    // MARK: tick

    func frontTick(_ dt: CGFloat) {
        let zs = cpZones
        if cpProg.count < 5 { cpProg = [CGFloat](repeating: 0, count: 5) }
        flMeZone = -1
        for i in 0..<5 {
            var n0 = 0, n1 = 0
            for p in players where p.alive && zs[i].contains(p.pos) {
                if p.team == 0 { n0 += 1 } else { n1 += 1 }
                if p.isPlayer { flMeZone = i }
            }
            let d = n0 - n1
            if d != 0 { cpProg[i] = max(-1, min(1, cpProg[i] + CGFloat(d.signum()) * dt * 0.18 * CGFloat(min(abs(d), 4)))) }
            let own = cpProg[i] >= 1 ? 0 : (cpProg[i] <= -1 ? 1 : -1)
            if own != flOwner[i] {
                if own == 0 { flSay("", "POINT \(TFront.letters[i]) CAPTURED", sys: true); banner = "POINT \(TFront.letters[i]) CAPTURED"; bannerT = 2 }
                else if own == 1 { flSay("", "POINT \(TFront.letters[i]) LOST", sys: true); banner = "POINT \(TFront.letters[i]) LOST"; bannerT = 2 }
                flOwner[i] = own
            }
        }
        // ticket bleed
        flBleedT -= dt
        if flBleedT <= 0 {
            flBleedT = 2
            let o0 = (0..<5).filter { cpProg[$0] >= 1 }.count, o1 = (0..<5).filter { cpProg[$0] <= -1 }.count
            if o0 > o1 { scores[1] += o0 - o1 } else if o1 > o0 { scores[0] += o1 - o0 }
        }
        // class auras
        flAuraT -= dt
        if flAuraT <= 0 {
            flAuraT = 0.5
            flAuraN += 1
            for m in players where m.alive && (m.cls == 1 || m.cls == 2) {
                for a in players where a.alive && a.team == m.team && tDist(a.pos, m.pos) < 230 {
                    if m.cls == 1 && a.hp < 100 {
                        a.hp = min(100, a.hp + 5)
                        if a.isPlayer && flAuraN % 4 == 0 { pop(a.pos, "+HP", .green) }
                    }
                    if m.cls == 2 && flAuraN % 12 == 0 && !TWeapons.isPistol(a.gun) && a.spare < 5 {
                        a.spare += 1
                        if a.isPlayer { pop(a.pos, "AMMO", .yellow) }
                    }
                }
            }
        }
        // squad chatter
        let cen: [CGPoint] = zs.map { CGPoint(x: $0.midX, y: $0.midY) }
        for i in flChat.indices { flChat[i].life -= dt }
        flChat.removeAll { $0.life <= 0 }
        flChatT -= dt
        if flChatT <= 0 {
            flChatT = CGFloat.random(in: 9...18)
            if let b = players.filter({ $0.fl == 1 && !$0.isPlayer && $0.alive }).randomElement() {
                let unowned = (0..<5).filter { !flOwned(0, $0) }
                var txt = "On my way!"
                if b.hp < 45 && b.cls != 1 { txt = "Need a medic!" }
                else if let e = players.first(where: { $0.team != b.team && $0.alive && $0.spotted && tDist($0.pos, b.pos) < 900 }) { txt = "Contact near \(TMap.roomName(e.pos))!" }
                else if let u = unowned.min(by: { (a: Int, b: Int) -> Bool in tDist(cen[a], me.pos) < tDist(cen[b], me.pos) }), Bool.random() { txt = "Attack \(TFront.letters[u])!" }
                else if let o = (0..<5).first(where: { flOwned(0, $0) }) { txt = "Holding \(TFront.letters[o])" }
                flSay(b.name, txt)
            }
        }
        // end of match
        if scores[0] >= killTarget { finishMatch(1) }
        else if scores[1] >= killTarget { finishMatch(0) }
        else if timer <= 0 { finishMatch(scores[0] <= scores[1] ? 0 : 1) }
    }
}

// MARK: - HUD

struct FrontPoint: View {
    let letter: String
    let prog: CGFloat
    var size: CGFloat = 26

    var body: some View {
        let col: Color = prog >= 1 ? TUI.blue : (prog <= -1 ? TUI.red : (prog > 0 ? TUI.blue.opacity(0.6) : (prog < 0 ? TUI.red.opacity(0.6) : Color.gray)))
        return ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(col.opacity(0.85))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Color.white.opacity(0.85), lineWidth: 1.5))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(45))
            Text(letter).font(.jk(size * 0.5, .heavy)).foregroundColor(.white)
        }
        .frame(width: size * 1.45, height: size * 1.45)
    }
}

struct HudFrontline: View {
    let e: TacticalEngine

    var body: some View {
        let t = Int(max(0, e.timer))
        let r0 = max(0, e.killTarget - e.scores[0]), r1 = max(0, e.killTarget - e.scores[1])
        let k = CGFloat(max(1, e.killTarget))
        let z = e.flMeZone
        return VStack(spacing: 3) {
            HStack(spacing: 6) {
                ZStack(alignment: .trailing) {
                    Rectangle().fill(Color.white.opacity(0.18))
                    Rectangle().fill(TUI.blue).frame(width: 96 * CGFloat(r0) / k)
                }
                .frame(width: 96, height: 7)
                Text("\(r0)").font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundColor(TUI.blue).monospacedDigit()
                Text(THud.clock(t)).font(.system(size: 18, weight: .heavy, design: .monospaced)).foregroundColor(.white).monospacedDigit()
                    .padding(.horizontal, 8).padding(.vertical, 2).background(Rectangle().fill(Color.black.opacity(0.55)))
                Text("\(r1)").font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundColor(TUI.red).monospacedDigit()
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.18))
                    Rectangle().fill(TUI.red).frame(width: 96 * CGFloat(r1) / k)
                }
                .frame(width: 96, height: 7)
            }
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    FrontPoint(letter: TFront.letters[i], prog: i < e.cpProg.count ? e.cpProg[i] : 0, size: 20)
                }
            }
            if z >= 0 && z < e.cpProg.count {
                let pr = e.cpProg[z]
                let mine = pr >= 1
                let label = mine ? "HOLDING" : (pr <= -1 ? "ENEMY POINT" : "CAPTURING")
                VStack(spacing: 2) {
                    Text("\(TFront.letters[z])  \(label)").font(.jk(11, .heavy)).foregroundColor(.white).shadow(color: .black.opacity(0.8), radius: 2)
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.22))
                        Rectangle().fill(pr >= 0 ? TUI.blue : TUI.red).frame(width: 150 * abs(pr))
                    }
                    .frame(width: 150, height: 5)
                }
            }
        }
    }
}

struct FrontSide: View {
    let e: TacticalEngine
    let W: CGFloat
    let H: CGFloat

    var body: some View {
        let squad = e.players.filter { $0.fl == 1 }.sorted { $0.isPlayer && !$1.isPlayer }
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 1) {
                Text("SQUAD 1").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.85))
                ForEach(squad, id: \.id) { p in
                    HStack(spacing: 4) {
                        SF(TFront.classIcons[min(4, p.cls)], "circle.fill").font(.system(size: 9, weight: .bold)).foregroundColor(p.alive ? TUI.green : TUI.red).frame(width: 12)
                        Text(p.isPlayer ? "YOU" : (p.name.split(separator: " ").first.map(String.init) ?? p.name)).font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1).frame(width: 62, alignment: .leading)
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.white.opacity(0.2))
                            Rectangle().fill(p.hp > 40 ? TUI.green : TUI.red).frame(width: 46 * max(0, min(1, p.alive ? p.hp / 100 : 0)))
                        }
                        .frame(width: 46, height: 4)
                    }
                    .frame(height: 15)
                }
            }
            .padding(5).frame(width: 140, alignment: .leading).background(Color.black.opacity(0.4))
            .position(x: 14 + 70, y: 262)
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(e.flChat.enumerated()), id: \.offset) { _, m in
                    HStack(spacing: 3) {
                        if m.sys {
                            Text(m.text).font(.jk(10, .heavy)).foregroundColor(TUI.gold)
                        } else {
                            Text("[Team] \(m.who.split(separator: " ").first.map(String.init) ?? m.who):").font(.jk(10, .heavy)).foregroundColor(TUI.blue)
                            Text(m.text).font(.jk(10, .semibold)).foregroundColor(.white)
                        }
                    }
                    .shadow(color: .black.opacity(0.9), radius: 2)
                    .opacity(Double(min(1, m.life)))
                }
            }
            .frame(width: 240, alignment: .leading)
            .position(x: 205 + 120, y: H - 44)
            Text("\(TFront.classNames[min(4, e.me.cls)])")
                .font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.black.opacity(0.4))
                .position(x: 14 + 30, y: 330)
        }
        .allowsHitTesting(false)
    }
}

struct FrontSpawnPicker: View {
    let e: TacticalEngine

    private func chip(_ t: String, _ id: Int, _ ok: Bool) -> some View {
        Button { if ok { e.flSpawn = id } } label: {
            Text(t).font(.jk(11, .heavy)).foregroundColor(e.flSpawn == id ? .black : (ok ? .white : .white.opacity(0.35)))
                .padding(.horizontal, 10).frame(height: 26)
                .background(Rectangle().fill(e.flSpawn == id ? CS.gold : Color.white.opacity(ok ? 0.18 : 0.06)))
        }
        .buttonStyle(TuiPress())
    }

    var body: some View {
        let squadOK = e.players.contains { $0.alive && !$0.isPlayer && $0.fl == 1 }
        return HStack(spacing: 5) {
            Text("SPAWN").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.7))
            chip("BASE", -1, true)
            chip("SQUAD", 10, squadOK)
            ForEach(0..<5, id: \.self) { i in chip(TFront.letters[i], i, e.flOwned(0, i)) }
        }
        .padding(6).background(Color.black.opacity(0.55))
    }
}

/// class picker used on the mode screen
struct FrontClassPicker: View {
    @State private var cur = TacticalEngine.flClass

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { i in
                Button { cur = i; TacticalEngine.flClass = i } label: {
                    VStack(spacing: 1) {
                        SF(TFront.classIcons[i], "circle.fill").font(.system(size: 14, weight: .bold)).foregroundColor(cur == i ? .black : .white)
                        Text(TFront.classNames[i]).font(.jk(8, .heavy)).foregroundColor(cur == i ? .black : .white.opacity(0.85))
                    }
                    .frame(width: 64, height: 38)
                    .background(Rectangle().fill(cur == i ? CS.gold : Color.white.opacity(0.14)))
                }
                .buttonStyle(TuiPress())
            }
        }
    }
}

extension TacticalEngine {
    /// player's chosen sidearm (Loadout screen)
    static var secondary: String {
        get { UserDefaults.standard.string(forKey: "ms.secondary") ?? "pistol" }
        set { UserDefaults.standard.set(newValue, forKey: "ms.secondary") }
    }

    static func altFor(_ g: String) -> String {
        let s = secondary
        return s == g ? (g == "pistol" ? "eagle" : "pistol") : s
    }
}
