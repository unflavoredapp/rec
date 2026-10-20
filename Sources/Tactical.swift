import SwiftUI
import UIKit

// MARK: - Persisted stats

struct TacData: Codable, Hashable {
    var wins = 0
    var losses = 0
    var kills = 0
    var rating = 1000
    var sx: TacSeasonData? = nil
    var prestige: Int? = nil
    var xpExtra: Int? = nil
    var xpBase: Int? = nil
    var recent: [TacMatch]? = nil
}

/// one finished match for the profile screen
struct TacMatch: Codable, Hashable {
    var won: Bool
    var kills: Int
    var map: Int
    var mode: Int
    var delta: Int
    var date: Double
}

// MARK: - Geometry


func tDist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

func tAngDiff(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
    var d = a - b
    while d > .pi { d -= 2 * .pi }
    while d < -.pi { d += 2 * .pi }
    return d
}

func tPointSeg(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x, dy = b.y - a.y
    let l2 = dx * dx + dy * dy
    if l2 < 1e-6 { return tDist(p, a) }
    let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2))
    return tDist(p, CGPoint(x: a.x + dx * t, y: a.y + dy * t))
}

// MARK: - Map

enum PropKind { case bed, couch, table, counter, crate, car, shelf, barrel, sandbag, tv, plant, tree, rock }

struct TProp {
    let r: CGRect
    let k: PropKind
}

struct TRoom {
    let name: String
    let r: CGRect
    let mat: Int
    var fl: Int = 0
}

enum WallMat { case brick, concrete, wood, glass }

// MARK: - Navigation (A* on a coarse grid)

enum TNav {
    static let cell: CGFloat = 40
    static var cols = Int(TMap.totalW / cell) + 1
    static var rows = Int(TMap.H / cell) + 1
    static var floorSolids: [[Int]] = TNav.makeFloorSolids()

    static func makeFloorSolids() -> [[Int]] {
        var f: [[Int]] = [[], [], []]
        for (k, r) in TMap.origBase.enumerated() { f[TMap.floorOfX(r.midX)].append(k) }
        return f
    }

    /// the active map changed: rebuild the solid index and the whole blocked grid
    static func reload() {
        floorSolids = makeFloorSolids()
        rows = Int(TMap.H / cell) + 1
        cols = Int(TMap.totalW / cell) + 1
        blocked = [Bool](repeating: false, count: cols * rows)
        rebuild()
    }

    static func cellBlocked(_ c: Int, _ r: Int) -> Bool {
        let p = CGPoint(x: CGFloat(c) * cell + cell / 2, y: CGFloat(r) * cell + cell / 2)
        let fl = TMap.floorOf(p)
        if p.x - TMap.origin(fl) > TMap.W - 20 || p.y > TMap.H - 20 { return true }
        for k in floorSolids[fl] where TMap.baseSolid[k].insetBy(dx: -18, dy: -18).contains(p) { return true }
        return TMap.stairBlocked(p)
    }

    static var blocked: [Bool] = {
        [Bool](repeating: false, count: cols * rows)
    }()

    /// re-evaluates the cells around a rect (after something was destroyed)
    static func refresh(_ rect: CGRect) {
        let q = rect.insetBy(dx: -30, dy: -30)
        let c0 = max(0, Int(q.minX / cell)), c1 = min(cols - 1, Int(q.maxX / cell))
        let r0 = max(0, Int(q.minY / cell)), r1 = min(rows - 1, Int(q.maxY / cell))
        if c0 > c1 || r0 > r1 { return }
        for c in c0...c1 { for r in r0...r1 { blocked[r * cols + c] = cellBlocked(c, r) } }
    }

    static func rebuild() {
        var b = [Bool](repeating: false, count: cols * rows)
        for c in 0..<cols {
            let px = CGFloat(c) * cell + cell / 2
            let fl = TMap.floorOf(CGPoint(x: px, y: 0))
            let lx = px - TMap.origin(fl)
            for r in 0..<rows where lx > TMap.W - 20 || CGFloat(r) * cell + cell / 2 > TMap.H - 20 { b[r * cols + c] = true }
        }
        for fl in 0..<floorSolids.count {
            for k in floorSolids[fl] {
                let q = TMap.baseSolid[k].insetBy(dx: -18, dy: -18)
                let c0 = max(0, Int((q.minX - cell / 2) / cell)), c1 = min(cols - 1, Int((q.maxX - cell / 2) / cell) + 1)
                let r0 = max(0, Int((q.minY - cell / 2) / cell)), r1 = min(rows - 1, Int((q.maxY - cell / 2) / cell) + 1)
                if c0 > c1 || r0 > r1 { continue }
                for c in c0...c1 {
                    let cx = CGFloat(c) * cell + cell / 2
                    for r in r0...r1 where q.contains(CGPoint(x: cx, y: CGFloat(r) * cell + cell / 2)) { b[r * cols + c] = true }
                }
            }
        }
        blocked = b
        for i in TMap.stairs.indices where !TMap.stairIntact(i) {
            refresh(TMap.stairRect(i, floor: TMap.stairLo[i])); refresh(TMap.stairRect(i, floor: TMap.stairLo[i] + 1))
        }
    }

    static func idx(_ p: CGPoint) -> Int {
        let c = min(cols - 1, max(0, Int(p.x / cell)))
        let r = min(rows - 1, max(0, Int(p.y / cell)))
        return r * cols + c
    }
    static func center(_ i: Int) -> CGPoint { CGPoint(x: CGFloat(i % cols) * cell + cell / 2, y: CGFloat(i / cols) * cell + cell / 2) }

    static func nearestFree(_ i: Int) -> Int {
        if !blocked[i] { return i }
        let c0 = i % cols, r0 = i / cols
        for rad in 1...5 {
            for dc in -rad...rad {
                for dr in -rad...rad {
                    let c = c0 + dc, r = r0 + dr
                    if c < 0 || r < 0 || c >= cols || r >= rows { continue }
                    if !blocked[r * cols + c] { return r * cols + c }
                }
            }
        }
        return i
    }

    static func clear(_ a: CGPoint, _ b: CGPoint) -> Bool {
        var blocked = false
        TGrid.forEachSeg(a, b) { k in
            if k < TMap.baseSolid.count && tSegT(a, b, TMap.baseSolid[k].insetBy(dx: -15, dy: -15)) != nil { blocked = true; return true }
            return false
        }
        return !blocked
    }

    private static var gsB: [Int32] = []
    private static var cameB: [Int32] = []
    private static var seenB: [UInt32] = []
    private static var closedB: [UInt32] = []
    private static var genB: UInt32 = 0
    private static var heapF: [Int32] = []
    private static var heapI: [Int32] = []

    private static func hpush(_ f: Int32, _ i: Int32) {
        heapF.append(f); heapI.append(i)
        var c = heapF.count - 1
        while c > 0 {
            let p = (c - 1) / 2
            if heapF[p] <= heapF[c] { break }
            heapF.swapAt(p, c); heapI.swapAt(p, c)
            c = p
        }
    }

    private static func hpop() -> Int32? {
        guard !heapF.isEmpty else { return nil }
        let top = heapI[0]
        let lastF = heapF.removeLast(), lastI = heapI.removeLast()
        if !heapF.isEmpty {
            heapF[0] = lastF; heapI[0] = lastI
            var c = 0
            let n = heapF.count
            while true {
                let l = 2 * c + 1, r = l + 1
                var m = c
                if l < n && heapF[l] < heapF[m] { m = l }
                if r < n && heapF[r] < heapF[m] { m = r }
                if m == c { break }
                heapF.swapAt(m, c); heapI.swapAt(m, c)
                c = m
            }
        }
        return top
    }

    static func path(_ from: CGPoint, _ to: CGPoint) -> [CGPoint] {
        let s = nearestFree(idx(from))
        let g = nearestFree(idx(to))
        if s == g { return [to] }
        let n = cols * rows
        if gsB.count != n {
            gsB = [Int32](repeating: 0, count: n)
            cameB = [Int32](repeating: -1, count: n)
            seenB = [UInt32](repeating: 0, count: n)
            closedB = [UInt32](repeating: 0, count: n)
            genB = 0
        }
        genB &+= 1
        if genB == 0 {
            for i in 0..<n { seenB[i] = 0; closedB[i] = 0 }
            genB = 1
        }
        let gen = genB
        heapF.removeAll(keepingCapacity: true)
        heapI.removeAll(keepingCapacity: true)
        let gc = g % cols, gr = g / cols
        @inline(__always) func h(_ i: Int) -> Int32 {
            let dx = abs(i % cols - gc), dy = abs(i / cols - gr)
            return Int32(10 * (dx + dy) - 6 * min(dx, dy))
        }
        gsB[s] = 0; seenB[s] = gen; cameB[s] = -1
        hpush(h(s), Int32(s))
        var found = false
        var guardN = 0
        while let ci = hpop(), guardN < 40000 {
            guardN += 1
            let cur = Int(ci)
            if cur == g { found = true; break }
            if closedB[cur] == gen { continue }
            closedB[cur] = gen
            let c = cur % cols, r = cur / cols
            let gcur = gsB[cur]
            for dc in -1...1 {
                for dr in -1...1 {
                    if dc == 0 && dr == 0 { continue }
                    let nc = c + dc, nr = r + dr
                    if nc < 0 || nr < 0 || nc >= cols || nr >= rows { continue }
                    let ni = nr * cols + nc
                    if blocked[ni] || closedB[ni] == gen { continue }
                    if dc != 0 && dr != 0 && (blocked[r * cols + nc] || blocked[nr * cols + c]) { continue }
                    let cost = gcur + (dc != 0 && dr != 0 ? 14 : 10)
                    if seenB[ni] != gen || cost < gsB[ni] {
                        seenB[ni] = gen
                        gsB[ni] = cost
                        cameB[ni] = Int32(cur)
                        hpush(cost + h(ni), Int32(ni))
                    }
                }
            }
        }
        guard found else { return [to] }
        var cells: [Int] = []
        var k = g
        while k != -1 { cells.append(k); k = Int(cameB[k]) }
        cells.reverse()
        var pts = cells.map { center($0) }
        pts.append(to)
        // string pulling
        var out: [CGPoint] = []
        var anchor = from
        var i = 0
        while i < pts.count {
            var j = pts.count - 1
            while j > i && !clear(anchor, pts[j]) { j -= 1 }
            out.append(pts[j])
            anchor = pts[j]
            i = j + 1
        }
        return out
    }
}

// MARK: - Entities

final class TPlayer {
    let id: Int
    var team: Int
    var name: String
    let handle: String
    let emoji: String
    let isPlayer: Bool
    var pos = CGPoint.zero
    var hp: CGFloat = 100
    var alive = true
    var aim: CGFloat = 0
    var gun = "pistol"
    var mag = 12
    var spare = 2
    var nades = 1
    var smokes = 1
    var flashes = 1
    var armor: CGFloat = 100
    var blind: CGFloat = 0
    var pingCd: CGFloat = 0
    var reloadT: CGFloat = 0
    var fireCd: CGFloat = 0
    var flash: CGFloat = 0
    var hurt: CGFloat = 0
    var kills = 0
    var path: [CGPoint] = []
    var pathT: CGFloat = 0
    var pathDest = CGPoint.zero
    var targetID = -1
    var reactT: CGFloat = 0
    var seeT: CGFloat = 0
    var lastSeen = CGPoint.zero
    var hunt: CGFloat = 0
    var strafe: CGFloat = 1
    var strafeT: CGFloat = 0
    var role = 0
    var aggro = CGFloat.random(in: 0.08...0.95)      // 0 = holds angles and waits, 1 = pushes everything
    var patience = CGFloat.random(in: 0.4...1.6)     // how long it keeps a post / plan
    var reflex = CGFloat.random(in: 0.75...1.35)     // personal reaction-time multiplier
    var nerve = CGFloat.random(in: 0.2...0.9)        // how readily it takes cover or backs off
    var aiGoal = CGPoint.zero
    var aiGoalT: CGFloat = 0
    var commitAt: CGFloat = CGFloat.random(in: 10...55)
    var rank = 0   // 0 fighter, 1 staff, 2 admin
    var trophies = 0
    var site = 0
    var spotted = false
    var cls = 0   // frontline class: 0 assault 1 medic 2 support 3 recon 4 engineer
    var fl = 0    // frontline squad id (0 none)
    var seenEver = false
    var onStair = false
    var knife = false
    var crouch = false
    var hiding = false
    var hideT: CGFloat = 0
    var cover: CGPoint? = nil
    var noiseT: CGFloat = 0
    var faction = 0
    var home = CGPoint.zero
    var ambush = -1
    var watchDoor = false
    var holding: Bool { ambush >= 0 || watchDoor }
    var ambushPos = CGPoint.zero
    var ambushAim: CGFloat = 0
    var respawn: CGFloat = 0
    var money = 800
    var armorKind = 0
    var ladder = 0
    var roam = CGPoint.zero
    var altGun = "pistol"
    var altMag = 15
    var altSpare = 99
    var goalT: CGFloat = 0

    init(id: Int, team: Int, name: String, handle: String, emoji: String, isPlayer: Bool) {
        self.id = id; self.team = team; self.name = name; self.handle = handle; self.emoji = emoji; self.isPlayer = isPlayer
    }
}

final class TacticalEngine {
    struct Bullet {
        var pos: CGPoint
        var vel: CGVector
        var dmg: CGFloat
        var life: CGFloat
        var owner: Int
        var team: Int
        var inK = -1
        var pens = 0
        var tf = -1
        var h: CGFloat = 48        // height above the floor
        var vh: CGFloat = 0        // vertical speed: pitch-aware shots climb or fall
    }
    struct Nade {
        var pos: CGPoint
        var vel: CGVector
        var fuse: CGFloat
        var owner: Int
        var team: Int
        var kind = 0
    }
    struct Boom {
        var pos: CGPoint
        var life: CGFloat
        var r: CGFloat
    }
    struct Smoke {
        var pos: CGPoint
        var life: CGFloat
        var r: CGFloat
    }
    struct Ping {
        var pos: CGPoint
        var text: String
        var life: CGFloat
    }
    struct Pack {
        var pos: CGPoint
        var taken: Bool
    }
    struct Pop {
        var pos: CGPoint
        var text: String
        var life: CGFloat
        var color: Color
    }
    /// a bullet strike for the 3D scene to dress: kind 0 wall, 1 flesh, 2 glass, 3 floor blood pool
    struct Impact {
        var pos: CGPoint
        var nx: CGFloat
        var ny: CGFloat
        var kind: Int
    }
    var impacts: [Impact] = []
    func noteImpact(_ a: CGPoint, _ b: CGPoint, _ r: CGRect, _ kind: Int) {
        guard impacts.count < 48, let t = tSegT(a, b, r) else { return }
        let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        let d = [abs(p.x - r.minX), abs(p.x - r.maxX), abs(p.y - r.minY), abs(p.y - r.maxY)]
        let m = d.min() ?? 0
        var n = CGVector(dx: 0, dy: 1)
        if m == d[0] { n = CGVector(dx: -1, dy: 0) } else if m == d[1] { n = CGVector(dx: 1, dy: 0) } else if m == d[2] { n = CGVector(dx: 0, dy: -1) }
        impacts.append(Impact(pos: p, nx: n.dx, ny: n.dy, kind: kind))
    }
    struct Feed {
        var text: String
        var life: CGFloat
        var mine: Bool
        var k = ""
        var v = ""
        var kTeam = 0
        var gun = "pistol"
        var head = false
    }

    var players: [TPlayer] = []
    var bullets: [Bullet] = []
    var nades: [Nade] = []
    var smokeClouds: [Smoke] = []
    var pings: [Ping] = []
    var packs: [Pack] = []
    var booms: [Boom] = []
    var pops: [Pop] = []
    var feed: [Feed] = []
    var sprites: [String: UIImage] = [:]
    private let dummyMe = TPlayer(id: 0, team: 0, name: TacProfile.name, handle: "you", emoji: "", isPlayer: true)
    var me: TPlayer { players.first ?? dummyMe }

    var phase = 0              // 0 prep, 1 live, 2 planted, 3 round end, 4 match over
    var timer: CGFloat = 0
    var scores = [0, 0]
    var round = 0
    var atkTeam = 0
    let target = 3
    var planted = false
    var bombPos = CGPoint.zero
    var bombSite = 0
    var bombT: CGFloat = 0
    var atkSite = 0
    var plantProg: CGFloat = 0
    var defuseProg: CGFloat = 0
    var banner = ""
    var bannerT: CGFloat = 0
    var diff = 1
    var move = CGVector.zero
    var aimIn: CGFloat? = nil
    var autoAim = false      // aim assist removed: manual aim and manual fire only
    var ads = false
    var autoFire = false
    var autoTarget = -1
    var firing = false
    var actHeld = false
    var wantNade = false
    var wantSmoke = false
    var wantFlash = false
    var scoped = false
    var pitch: CGFloat = 0
    var fp = false
    var view3D = true
    var project: ((CGPoint, CGFloat) -> CGPoint?)? = nil
    var lookDelta: CGFloat = 0
    var hitT: CGFloat = 0
    var wantReload = false
    var wantSwap = false
    var wantKnife = false
    var wantGun = false
    var knifeKill = false
    var buyT: CGFloat = 0
    var buyOpen = false
    var theme = 0
    var killFx = "fx_none"
    var charm = "charm_none"
    var fxId = "fx_none"
    var fxT: CGFloat = 0
    var fxSerial = 0
    var cpProg: [CGFloat] = [0, 0, 0]
    var cpT: CGFloat = 0
    var rivalScore: Int { gameMode == 4 ? (scores.dropFirst().max() ?? 0) : scores[1] }
    var cpZones: [CGRect] { gameMode == 7 ? TFront.zones : [TMap.site(0), TMap.site(1), TMap.hubZone] }
    static var flClass: Int {
        get { max(0, min(4, UserDefaults.standard.integer(forKey: "ms.flclass"))) }
        set { UserDefaults.standard.set(newValue, forKey: "ms.flclass") }
    }
    var flSpawn = -1          // -1 base, 0..4 owned point, 10 squad mate
    var flChat: [FLMsg] = []
    var flAuraT: CGFloat = 0.5
    var flAuraN = 0
    var flChatT: CGFloat = 9
    var flBleedT: CGFloat = 2
    var flMeZone = -1
    var flOwner: [Int] = [-1, -1, -1, -1, -1]
    var gameMode = 0
    var killTarget = 30
    struct Loot { var pos: CGPoint; var id: String; var taken: Bool }
    var loot: [Loot] = []
    var stormT: CGFloat = 0
    var stormRad: CGFloat = 1800
    var stormC = CGPoint(x: 1500, y: 900)
    var stormStage = 0
    var stormShrinking = false
    var stormCountdown: CGFloat = 40
    var stormHitT: CGFloat = 0
    private let stormR: [CGFloat] = [1800, 1050, 640, 360, 170, 50]
    private var stormCs: [CGPoint] = []
    var brPlace = 0
    // extraction raid
    var raidBag: [RaidItem] = []
    var raidHasKey = false
    var raidZoneT: CGFloat = 0
    var raidZoneIdx = -1
    var raidExtracted = false
    var raidCommitted = false
    var raidSold = 0
    var gunDur: CGFloat = 100
    var gunTier = 0
    var bleedT: CGFloat = 0
    var legWound = false
    var noiseR: CGFloat = 0
    var noiseNow: CGFloat = 0
    var hearT: CGFloat = 0
    var evT: CGFloat = 60
    var evKind = 0
    var evLeft: CGFloat = 0
    var evPos = CGPoint.zero
    var evMsg = ""
    var alarmT: CGFloat = 0
    var alarmPulse: CGFloat = 0
    var raidSecureEq = false
    var holdT: CGFloat = 0
    var dynBase = 0
    var cmdKilled = 0
    var vaultsOpened = 0
    var raidLoudT: CGFloat = 0
    var raidMsg = ""
    var raidMsgT: CGFloat = 0
    var contractKind = 0
    var raidEquipped: RaidItem? = nil
    var raidBagOpen = false
    var contractDone = false
    var contractReward = 50
    var brEndT: CGFloat = 3
    var brAlive: Int { players.filter { $0.alive }.count }
    var stormDps: CGFloat { [1.5, 3, 5, 8, 12, 16][min(stormStage, 5)] }
    struct Tag { var pos: CGPoint; var team: Int; var life: CGFloat }
    var tags: [Tag] = []
    var fast = false
    var paused = false
    var won = false
    var last: Date? = nil
    var time: CGFloat = 0
    var squadGoals: [Int: (CGPoint, CGFloat)] = [:]
    var roundT0: CGFloat = 0
    var plantedAt: CGFloat = 0
    var spotT: CGFloat = 0
    var shake: CGFloat = 0
    var recoil: CGFloat = 0
    var jumpT: CGFloat = 0
    var kick: CGFloat = 0
    var moving: Bool { hypot(move.dx, move.dy) > 0.1 }
    var myGun = "pistol"
    var mapPick = 0
    var lastKiller = -1
    // killcam replay
    struct RSnap { var pos: [CGPoint]; var aim: [CGFloat]; var alive: [Bool]; var gun: [String]; var flash: [CGFloat]; var crouch: [Bool]; var hurt: [CGFloat]; var knife: [Bool] }
    var rbuf: [RSnap] = []
    var rAcc: CGFloat = 0
    var replay: [RSnap] = []
    var replayOn = false
    var replayT: CGFloat = 0
    var replayKiller = -1
    private func rCapture() -> RSnap {
        RSnap(pos: players.map { $0.pos }, aim: players.map { $0.aim }, alive: players.map { $0.alive }, gun: players.map { $0.gun }, flash: players.map { $0.flash }, crouch: players.map { $0.crouch }, hurt: players.map { $0.hurt }, knife: players.map { $0.knife })
    }
    private func rApply(_ s: RSnap) {
        for (i, p) in players.enumerated() where i < s.pos.count {
            p.pos = s.pos[i]; p.aim = s.aim[i]; p.alive = s.alive[i]; p.gun = s.gun[i]; p.flash = s.flash[i]; p.crouch = s.crouch[i]; p.hurt = s.hurt[i]; p.knife = s.knife[i]
        }
    }
    /// swaps the world into the replay frame for rendering; pair with endReplayView
    func beginReplayView() -> RSnap? {
        guard replayOn, !replay.isEmpty else { return nil }
        let cur = rCapture()
        rApply(replay[min(replay.count - 1, max(0, Int(replayT * 30)))])
        return cur
    }
    var replayDone: Bool { replayT >= CGFloat(replay.count) / 30 + 0.4 }
    func replayAgain() { replayT = 0 }
    func respawnNow() {
        guard !me.alive, !over else { return }
        replayOn = false
        me.respawn = 0
        respawnPlayer(me)
    }
    func endReplayView(_ s: RSnap?) { if let s = s { rApply(s) } }
    var kills: Int { me.kills }

    private let react: [CGFloat] = [0.55, 0.33, 0.18]
    private let turn: [CGFloat] = [5, 8, 12]
    private let aimErr: [CGFloat] = [0.13, 0.07, 0.035]

    func setup(gun: String, diff: Int, mode: Int = 0) {
        self.diff = diff
        gameMode = mode
        TMap.load((mode == 6 || mode == 7) ? 4 : mapPick)
        tags = []
        myGun = gun
        let nb = mode == 6 ? 36 : (mode == 7 ? TFront.bots : 9)
        var names: [(String, String, String)] = TacRoster.pick(nb)
        while names.count < nb { let k = names.count + 1; names.append(("Recruit \(k)", "recruit\(k)", "")) }
        players = [TPlayer(id: 0, team: 0, name: TacProfile.name, handle: "you", emoji: "", isPlayer: true)]
        players[0].trophies = TacLeague.myRating
        for i in 0..<nb {
            let bp = TPlayer(id: i + 1, team: mode == 7 ? (i < (nb - 1) / 2 ? 0 : 1) : (i < 4 ? 0 : 1), name: names[i].0, handle: names[i].1, emoji: names[i].2, isPlayer: false)
            bp.rank = TacRoster.rank(of: names[i].1)
            bp.trophies = max(0, TacLeague.myRating + Int.random(in: -400...900) + (Int.random(in: 0..<8) == 0 ? Int.random(in: 1000...6000) : 0))
            players.append(bp)
        }
        scores = [0, 0]
        killTarget = mode == 4 ? 20 : (mode == 5 ? 100 : 30)
        if mode == 4 {
            for p in players { p.team = p.id }
            scores = Array(repeating: 0, count: 10)
        }
        if mode == 6 { for p in players { p.team = p.isPlayer ? 0 : 1 } }
        if mode == 7 {
            killTarget = TFront.tickets
            TFront.prepare()
            TFront.assign(players)
            flChat = []; flSpawn = -1; flChatT = 9; flBleedT = 2; flAuraT = 0.5; flAuraN = 0
        }
        round = 0
        phase = 0
        over = false
        startRound()
    }
    var over = false

    private func gunPick() -> String {
        let r = Int.random(in: 0..<100)
        if r < 6 { return "awp" }
        if r < 40 { return ["rifle", "ak", "m4"].randomElement()! }
        if r < 68 { return ["smg", "mp7", "p90"].randomElement()! }
        if r < 82 { return ["shotgun", "pump"].randomElement()! }
        return ["pistol", "eagle"].randomElement()!
    }

    func startRound() {
        round += 1
        atkTeam = round % 2 == 1 ? 0 : 1
        atkSite = Int.random(in: 0...1)
        planted = false
        plantProg = 0
        defuseProg = 0
        bullets = []; nades = []; booms = []; pops = []
        smokeClouds = []; pings = []
        TMap.resetDoors()
        TMap.resetDestruction()
        squadGoals = [:]
        for b in players { b.aiGoalT = 0; b.aiGoal = .zero; b.commitAt = CGFloat.random(in: 10...55); b.path = []; b.pathT = 0 }
        roundT0 = time
        lookDelta = 0
        packs = TMap.packPos.map { Pack(pos: $0, taken: false) }
        var ai = 0, di = 0
        var defBots = 0
        let brSpawns = TMap.spawns.shuffled()
        let spreadPts = gameMode != 0 && gameMode != 6 && gameMode != 7 ? TMap.spreadPoints(players.count, sep: 700) : []
        var spreadI = 0
        let raidPts = gameMode == 6 ? TMap.spreadPoints(players.count, sep: 650, avoid: [TMap.atkSpawn[2]], avoidDist: 1500) : []
        var raidI = 0
        cpProg = [CGFloat](repeating: 0, count: gameMode == 7 ? 5 : 3)
        cpT = 1.5
        for p in players {
            let survived = p.alive
            p.hp = 100
            p.alive = true
            p.path = []
            p.targetID = -1
            p.hunt = 0
            p.reloadT = 0
            p.fireCd = 0
            p.spotted = false
            p.seenEver = false
            p.nades = 1
            p.smokes = 1
            p.flashes = 1
            if p.isPlayer { scoped = false; ads = false; pitch = 0 }
            if gameMode != 0 && gameMode != 6 { p.armor = 100; p.armorKind = 1 }
            p.blind = 0
            p.pingCd = 0
            p.knife = false
            p.crouch = false
            p.hiding = false
            p.cover = nil
            p.noiseT = 0
            let atk = p.team == atkTeam
            var spot = atk ? TMap.atkSpawn[ai % 5] : TMap.defSpawn[di % 5]
            if atk { ai += 1 } else { di += 1 }
            if gameMode != 0 && gameMode != 6 && !spreadPts.isEmpty {
                spot = spreadPts[spreadI % spreadPts.count]
                spreadI += 1
            }
            if gameMode == 6 {
                let home = TMap.atkSpawn[2]
                if p.isPlayer { spot = home } else if !raidPts.isEmpty {
                    spot = raidPts[raidI % raidPts.count]
                    raidI += 1
                } else {
                    let far = brSpawns.filter { tDist($0, home) > 700 }
                    spot = far.isEmpty ? brSpawns[p.id % brSpawns.count] : far[p.id % far.count]
                }
            }
            p.pos = spot
            p.aim = TMap.aimAtCenter(spot)
            p.respawn = 0
            if gameMode == 0 {
                // the player always carries the loadout gun picked in the lobby (no buy phase)
                if round == 1 { p.money = 800; p.armor = 0; p.armorKind = 0; p.gun = p.isPlayer ? myGun : "pistol" }
                else if !survived { p.armor = 0; p.armorKind = 0; p.gun = p.isPlayer ? myGun : "pistol" }
                p.mag = magSize(p, p.gun)
                p.spare = TWeapons.isPistol(p.gun) ? 99 : 2
                if p.isPlayer && (round == 1 || !survived) {
                    p.altGun = TacticalEngine.altFor(p.gun); p.altMag = magSize(p, p.altGun); p.altSpare = 99
                }
            } else {
                p.gun = p.isPlayer ? myGun : gunPick()
                if gameMode == 3 { p.gun = TWeapons.ladder[0]; p.ladder = 0 }
                if gameMode == 6 {
                    p.smokes = 0; p.flashes = 0
                    if p.isPlayer { p.armorKind = 1; p.armor = 60; p.nades = 1 }
                    else { p.armorKind = [1, 1, 2, 3][p.id % 4]; p.armor = p.armorKind >= 3 ? 150 : (p.armorKind == 2 ? 100 : 60); p.nades = p.id % 3 == 0 ? 1 : 0 }
                }
                p.mag = magSize(p, p.gun)
                p.spare = TWeapons.isPistol(p.gun) ? 99 : 2
                if p.isPlayer {
                    p.altGun = TacticalEngine.altFor(p.gun)
                    p.altMag = magSize(p, p.altGun)
                    p.altSpare = 99
                    if gameMode == 6 { p.altGun = "pistol"; p.altMag = 15; p.altSpare = 99 }
                }
            }
            p.role = 0
            if !atk && !p.isPlayer { p.site = defBots % 2; defBots += 1 }
            p.site = atk ? atkSite : p.site
        }
        if let planter = players.filter({ $0.team == atkTeam && !$0.isPlayer }).randomElement() { planter.role = 1 }
        phase = 0
        timer = 4
        banner = me.team == atkTeam ? "PREPARE TO ATTACK" : "PREPARE TO DEFEND"
        if gameMode != 0 {
            atkTeam = 0
            banner = TWeapons.modeNames[gameMode]
            tags = []
            if gameMode == 6 { raidStart() } else { for p in players { respawnPlayer(p) } }
            assignAmbush()
        } else {
            timer = 6
            buyT = 0
            buyOpen = false
            for p in players where !p.isPlayer { botBuy(p) }
        }
        bannerT = 3.5
    }

    // MARK: sim

    func step(_ now: Date) {
        guard let l = last else { last = now; return }
        let dt = min(0.05, CGFloat(now.timeIntervalSince(l)))
        last = now
        if paused || over { return }
        let n = (!me.alive && fast && phase < 3 && !replayOn) ? 3 : 1
        for _ in 0..<n { update(dt) }
    }

    private func update(_ dt: CGFloat) {
        time += dt
        if me.alive {
            replayOn = false
            rAcc += dt
            if rAcc >= 1.0 / 30 {
                rAcc = 0
                rbuf.append(rCapture())
                if rbuf.count > (gameMode == 6 ? 300 : 90) { rbuf.removeFirst() }
            }
        } else if replayOn {
            replayT = min(replayT + dt, CGFloat(replay.count) / 30 + 0.5)
        }
        bannerT = max(0, bannerT - dt)
        hitT = max(0, hitT - dt)
        shake = max(0, shake - dt * 30)
        recoil = max(0, recoil - dt * 2.4)
        jumpT = max(0, jumpT - dt)
        fxT = max(0, fxT - dt * 1.0)
        buyT = max(0, buyT - dt)
        if buyT <= 0 { buyOpen = false }
        kick = max(0, kick - dt * (22 + kick * 3))
        for i in feed.indices { feed[i].life -= dt }
        feed.removeAll { $0.life <= 0 }
        for i in booms.indices { booms[i].life -= dt }
        booms.removeAll { $0.life <= 0 }
        for i in smokeClouds.indices { smokeClouds[i].life -= dt }
        smokeClouds.removeAll { $0.life <= 0 }
        for i in pings.indices { pings[i].life -= dt }
        pings.removeAll { $0.life <= 0 }
        for i in pops.indices { pops[i].life -= dt * 1.1 }
        pops.removeAll { $0.life <= 0 }
        for p in players { p.flash = max(0, p.flash - dt); p.hurt = max(0, p.hurt - dt); p.blind = max(0, p.blind - dt); p.noiseT = max(0, p.noiseT - dt) }

        if phase == 3 {
            timer -= dt
            moveProjectiles(dt)
            if timer <= 0 {
                if scores[0] >= target || scores[1] >= target {
                    phase = 4
                    over = true
                    won = scores[0] >= target
                } else { startRound() }
            }
            return
        }
        if phase == 0 {
            timer -= dt
            if timer <= 0 { phase = 1; timer = gameMode == 0 ? 100 : (gameMode == 6 ? 99999 : (gameMode == 7 ? TFront.minutes * 60 : 240)); banner = gameMode == 6 ? "DEPLOYED" : "GO"; bannerT = 1 }
            for p in players where !p.isPlayer { botLook(p, dt) }
            return
        }
        // live
        timer -= dt
        var planting = false
        var defusing = false
        updateDoors(dt)
        playerUpdate(dt, &planting, &defusing)
        for p in players where !p.isPlayer && p.alive { botThink(p, dt, &planting, &defusing) }
        for i in packs.indices where !packs[i].taken {
            for p in players where p.alive && p.hp < 100 && tDist(p.pos, packs[i].pos) < 24 {
                p.hp = min(100, p.hp + 40)
                packs[i].taken = true
                pop(p.pos, "+40", .green)
                break
            }
        }
        moveProjectiles(dt)
        for p in players where p.alive { stairCheck(p) }
        reactToBreaches()
        // spotting
        spotT -= dt
        if spotT <= 0 {
            spotT = 0.1
            for e in players where e.team != me.team {
                let was = e.spotted
                e.spotted = false
                e.pingCd = max(0, e.pingCd - 0.1)
                guard e.alive else { continue }
                for a in players where a.team == me.team && a.alive {
                    if TMap.pdist(a.pos, e.pos) < (gameMode == 7 && a.cls == 3 ? 1500 : 900) * (a.isPlayer ? TPerk.spotMul : 1) && see(a.pos, e.pos) { e.spotted = true; e.seenEver = true; break }
                }
                if e.spotted && !was && e.pingCd <= 0 {
                    e.pingCd = 4
                    pings.append(Ping(pos: e.pos, text: TMap.roomName(e.pos), life: 3.5))
                    if pings.count > 6 { pings.removeFirst() }
                }
            }
        }
        if gameMode != 0 { dmTick(dt); return }
        // objectives
        if !planted {
            if planting { plantProg += dt } else { plantProg = max(0, plantProg - dt * 2) }
            if plantProg >= 3 {
                planted = true
                plantedAt = time
                phase = 2
                bombT = 30
                bombSite = atkSite
                if let who = players.first(where: { $0.team == atkTeam && $0.alive && TMap.site(atkSite).contains($0.pos) }) { bombPos = who.pos }
                else { bombPos = CGPoint(x: TMap.site(atkSite).midX, y: TMap.site(atkSite).midY) }
                plantProg = 0
                banner = "BOMB PLANTED"
                bannerT = 2
                timer = bombT
            }
        } else {
            bombT -= dt
            timer = bombT
            if defusing { defuseProg += dt } else { defuseProg = 0 }
            if defuseProg >= 4 { endRound(winner: 1 - atkTeam, text: "BOMB DEFUSED"); return }
            if bombT <= 0 {
                booms.append(Boom(pos: bombPos, life: 0.8, r: 220))
                TMap.blast(bombPos, radius: 330, dmg: 420)
                shake = 14
                endRound(winner: atkTeam, text: "BOMB DETONATED")
                return
            }
        }
        let atkAlive = players.filter { $0.team == atkTeam && $0.alive }.count
        let defAlive = players.filter { $0.team != atkTeam && $0.alive }.count
        if defAlive == 0 { endRound(winner: atkTeam, text: "DEFENDERS ELIMINATED"); return }
        if atkAlive == 0 && !planted { endRound(winner: 1 - atkTeam, text: "ATTACKERS ELIMINATED"); return }
        if !planted && timer <= 0 { endRound(winner: 1 - atkTeam, text: "TIME RAN OUT") }
    }

    // MARK: economy

    func price(_ id: String) -> Int {
        switch id {
        case "kev": return 650
        case "vest": return 1000
        case "spec": return 2000
        case "flashb": return 200
        case "smokeb": return 300
        case "fragb": return 300
        default: return TWeapons.w(id).price
        }
    }

    @discardableResult func buyItem(_ p: TPlayer, _ id: String) -> Bool {
        guard gameMode == 0, p.alive else { return false }
        let c = price(id)
        guard p.money >= c else { return false }
        switch id {
        case "kev": guard p.armorKind < 1 || p.armor < 50 else { return false }; p.armor = 100; p.armorKind = 1
        case "vest": guard p.armorKind < 2 || p.armor < 50 else { return false }; p.armor = 100; p.armorKind = 2
        case "spec": guard p.armorKind < 3 || p.armor < 75 else { return false }; p.armor = 150; p.armorKind = 3
        case "flashb": guard p.flashes < 2 else { return false }; p.flashes += 1
        case "smokeb": guard p.smokes < 1 else { return false }; p.smokes += 1
        case "fragb": guard p.nades < 1 else { return false }; p.nades += 1
        default:
            guard p.gun != id, p.altGun != id else { return false }
            if TWeapons.isPistol(id) {
                if TWeapons.isPistol(p.gun) { setGun(p, id) } else { p.altGun = id; p.altMag = magSize(p, id); p.altSpare = 99 }
            } else {
                if TWeapons.isPistol(p.gun) { p.altGun = p.gun; p.altMag = p.mag; p.altSpare = 99 }
                setGun(p, id)
            }
        }
        p.money -= c
        return true
    }

    private func botBuy(_ p: TPlayer) {
        if TWeapons.isPistol(p.gun) {
            let prim = TWeapons.all.filter { !TWeapons.isPistol($0.id) && $0.price <= p.money - (p.armorKind == 0 ? 650 : 0) && ($0.id != "awp" || Int.random(in: 0..<4) == 0) }
            if let w = prim.randomElement() { buyItem(p, w.id) }
            else if p.money >= 700 + 650, Int.random(in: 0..<2) == 0 { buyItem(p, "eagle") }
        }
        if p.armorKind == 0 || p.armor < 40 {
            if p.money >= 2400, Int.random(in: 0..<3) == 0 { buyItem(p, "spec") }
            else if p.money >= 1000 { buyItem(p, "vest") }
            else if p.money >= 650 { buyItem(p, "kev") }
        }
        if p.money >= 300, p.nades == 0 { buyItem(p, "fragb") }
        if p.money >= 300, p.smokes == 0 { buyItem(p, "smokeb") }
    }

    // MARK: deathmatch-style modes

    func magSize(_ p: TPlayer, _ id: String) -> Int {
        let b = TGuns.get(id).mag
        return p.isPlayer ? max(1, Int(CGFloat(b) * TAtt.mods(id).magMul)) : b
    }

    func setGun(_ p: TPlayer, _ id: String) {
        p.gun = id
        p.mag = magSize(p, id)
        p.spare = TWeapons.isPistol(id) ? 99 : 2
        p.reloadT = 0
        p.knife = false
    }

    private func respawnPlayer(_ p: TPlayer) {
        if p.isPlayer { rbuf.removeAll(); replayOn = false }
        if gameMode == 7 { frontRespawn(p); return }
        var list = p.id % 2 == 0 ? TMap.atkSpawn : TMap.defSpawn
        if gameMode != 0 && gameMode != 6 { list = TMap.spreadPoints(14, sep: 500) + list }
        var best = list[0], bd: CGFloat = -1
        for c in list {
            var near = CGFloat.greatestFiniteMagnitude
            for e in players where e.alive && e.id != p.id { near = min(near, tDist(c, e.pos) * (e.team != p.team ? 1 : 0.6)) }
            near += CGFloat.random(in: 0...250)
            if near > bd { bd = near; best = c }
        }
        p.pos = CGPoint(x: best.x + CGFloat.random(in: -18...18), y: best.y + CGFloat.random(in: -18...18))
        p.hp = 100; p.armor = 100; p.alive = true; p.blind = 0; p.crouch = false
        p.path = []; p.targetID = -1; p.hunt = 0; p.reloadT = 0; p.fireCd = 0; p.hiding = false; p.cover = nil
        p.nades = 1; p.smokes = 1; p.flashes = 1
        p.aim = TMap.aimAtCenter(p.pos)
        if gameMode == 3 { setGun(p, TWeapons.ladder[min(p.ladder, TWeapons.ladder.count - 1)]) }
        else { setGun(p, p.isPlayer ? myGun : gunPick()) }
        if p.isPlayer {
            scoped = false; ads = false; pitch = 0
            p.altGun = TacticalEngine.altFor(p.gun)
            p.altMag = magSize(p, p.altGun)
            p.altSpare = 99
        }
    }

    func finishMatch(_ winner: Int) {
        phase = 4
        over = true
        won = winner == me.team
        banner = won ? "VICTORY" : "DEFEAT"
        bannerT = 3
    }

    private func dmTick(_ dt: CGFloat) {
        if gameMode == 6 { raidTick(dt); return }
        for p in players where !p.alive && p.respawn > 0 && !(p.isPlayer && replayOn) {
            p.respawn -= dt
            if p.respawn <= 0 { respawnPlayer(p) }
        }
        if gameMode == 2 {
            for i in tags.indices { tags[i].life -= dt }
            tags.removeAll { $0.life <= 0 }
            var rest: [Tag] = []
            for t in tags {
                var taken = false
                for p in players where p.alive && tDist(p.pos, t.pos) < 30 {
                    if p.team != t.team { scores[p.team] += 1; pop(t.pos, "CONFIRMED", .yellow) }
                    else { pop(t.pos, "DENIED", .red) }
                    taken = true
                    break
                }
                if !taken { rest.append(t) }
            }
            tags = rest
        }
        if gameMode == 7 {
            frontTick(dt)
            if over { return }
        } else if gameMode == 3 {
            if let w = players.first(where: { $0.ladder >= TWeapons.ladder.count }) { finishMatch(w.team); return }
        } else if let wi = scores.firstIndex(where: { $0 >= killTarget }) {
            finishMatch(wi); return
        }
        if gameMode == 5 {
            let zs = cpZones
            for i in 0..<3 {
                var n0 = 0, n1 = 0
                for p in players where p.alive && zs[i].contains(p.pos) { if p.team == 0 { n0 += 1 } else { n1 += 1 } }
                let d = n0 - n1
                if d != 0 { cpProg[i] = max(-1, min(1, cpProg[i] + CGFloat(d.signum()) * dt * 0.22 * CGFloat(min(abs(d), 3)))) }
            }
            cpT -= dt
            if cpT <= 0 {
                cpT = 1.5
                for i in 0..<3 { if cpProg[i] >= 1 { scores[0] += 1 } else if cpProg[i] <= -1 { scores[1] += 1 } }
            }
        }
        if timer <= 0 && gameMode != 7 {
            if gameMode == 3 {
                let a = players.filter { $0.team == 0 }.map { $0.ladder }.reduce(0, +)
                let b = players.filter { $0.team == 1 }.map { $0.ladder }.reduce(0, +)
                finishMatch(a >= b ? 0 : 1)
            } else { finishMatch(scores.firstIndex(of: scores.max() ?? 0) ?? 0) }
        }
    }

    private func swapGun(_ p: TPlayer) {
        if p.knife { p.knife = false; p.fireCd = 0.3; return }
        guard gameMode != 3, p.reloadT <= 0 else { return }
        let g = p.gun, m = p.mag, s = p.spare
        p.gun = p.altGun; p.mag = p.altMag; p.spare = p.altSpare
        p.altGun = g; p.altMag = m; p.altSpare = s
        p.fireCd = 0.35
    }

    func see(_ a: CGPoint, _ b: CGPoint) -> Bool {
        if !TMap.los(a, b) { return false }
        for s in smokeClouds where tPointSeg(s.pos, a, b) < s.r * 0.9 { return false }
        return true
    }

    private func endRound(winner: Int, text: String) {
        scores[winner] += 1
        for p in players { p.money = min(16000, p.money + (p.team == winner ? 3000 : 1900)) }
        phase = 3
        timer = 3.5
        let w = winner == me.team
        banner = (w ? "ROUND WON  " : "ROUND LOST  ") + text
        bannerT = 3.5
    }

    // MARK: player

    // MARK: doors + cover

    private func updateDoors(_ dt: CGFloat) {
        var changed = false
        for i in TMap.doors.indices {
            let d = TMap.doors[i]
            var botNear = false
            for p in players where p.alive && !p.isPlayer && TMap.floorOf(p.pos) == TMap.floorOf(CGPoint(x: d.midX, y: d.midY)) {
                if TMap.rectDist(d, p.pos) < 40 { botNear = true; break }
            }
            let meNear = me.alive && TMap.rectDist(d, me.pos) < 100
            if botNear { TMap.doorWant[i] = true; TMap.doorHold[i] = 1.2 }
            else if TMap.doorWant[i] {
                if meNear { TMap.doorHold[i] = max(TMap.doorHold[i], 2.5) } else {
                    TMap.doorHold[i] -= dt
                    if TMap.doorHold[i] <= 0 { TMap.doorWant[i] = false }
                }
            }
            let goal: CGFloat = TMap.doorWant[i] ? 1 : 0
            let was = TMap.doorOpen[i] > 0.8
            if TMap.doorOpen[i] < goal { TMap.doorOpen[i] = min(goal, TMap.doorOpen[i] + dt * 3.2) }
            else if TMap.doorOpen[i] > goal { TMap.doorOpen[i] = max(goal, TMap.doorOpen[i] - dt * 2.4) }
            if was != (TMap.doorOpen[i] > 0.8) { changed = true }
        }
        if changed { TMap.refreshDoors() }
    }

    func nearestDoor() -> Int? {
        guard me.alive else { return nil }
        var best: Int? = nil
        var bd: CGFloat = 46
        for i in TMap.doors.indices {
            let dd = TMap.rectDist(TMap.doors[i], me.pos)
            if dd < bd && TMap.floorOf(CGPoint(x: TMap.doors[i].midX, y: TMap.doors[i].midY)) == TMap.floorOf(me.pos) { bd = dd; best = i }
        }
        return best
    }

    func toggleDoor() {
        guard let i = nearestDoor() else { return }
        if TMap.doorWant[i] || TMap.doorOpen[i] > 0.5 { TMap.doorWant[i] = false; TMap.doorHold[i] = 0 }
        else { TMap.doorWant[i] = true; TMap.doorHold[i] = 3 }
    }

    func coverNear(_ p: TPlayer) -> Bool {
        for r in TMap.solid where r.minX > -5000 && TMap.rectDist(r, p.pos) < 26 { return true }
        return false
    }

    func toggleCover() {
        let p = me
        guard p.alive else { return }
        if p.crouch { p.crouch = false; return }
        if coverNear(p) { p.crouch = true }
    }

    private func coverSpot(_ p: TPlayer, _ threat: CGPoint) -> CGPoint? {
        let base = atan2(threat.y - p.pos.y, threat.x - p.pos.x)
        for rad in [44, 76, 120] as [CGFloat] {
            var best: CGPoint? = nil
            var bs: CGFloat = 1e9
            for k in 0..<12 {
                let a = base + CGFloat.pi + (CGFloat(k) / 12) * 6.283 - CGFloat.pi
                let c = CGPoint(x: p.pos.x + cos(a) * rad, y: p.pos.y + sin(a) * rad)
                if TMap.solid.contains(where: { $0.insetBy(dx: -15, dy: -15).contains(c) }) { continue }
                if TMap.los(c, threat) { continue }
                if !TMap.los(p.pos, c) { continue }
                let d = tDist(c, threat)
                if d < 90 { continue }
                let s = rad + (d > 420 ? 40 : 0)
                if s < bs { bs = s; best = c }
            }
            if best != nil { return best }
        }
        return nil
    }

    private func playerUpdate(_ dt: CGFloat, _ planting: inout Bool, _ defusing: inout Bool) {
        let p = me
        guard p.alive else { return }
        if p.crouch && !coverNear(p) { p.crouch = false }
        let legMul: CGFloat = (gameMode == 6 && legWound) ? 0.62 : 1
        let sp: CGFloat = (p.crouch ? 88 : (p.knife ? 195 : 170)) * (scoped ? 0.6 : (ads ? 0.75 : 1)) * legMul
        var mv = move
        let tgt = autoAim ? pickTarget(p) : nil
        autoTarget = tgt?.id ?? -1
        var aligned = false
        if fp {
            p.aim += lookDelta
            lookDelta = 0
            let fx = cos(p.aim), fy = sin(p.aim)
            mv = CGVector(dx: fx * (-move.dy) - fy * move.dx, dy: fy * (-move.dy) + fx * move.dx)
            if let e = tgt {
                let want = TMap.pang(p.pos, e.pos)
                aligned = abs(angWrap(want - p.aim)) < 0.09
            }
        } else if let a = aimIn { p.aim = a }
        else if let e = tgt {
            let want = TMap.pang(p.pos, e.pos)
            p.aim = turnToward(p.aim, want, 13 * dt)
            aligned = abs(angWrap(want - p.aim)) < 0.09
        } else if hypot(mv.dx, mv.dy) > 0.2 {
            p.aim = turnToward(p.aim, atan2(mv.dy, mv.dx), 9 * dt)
        }
        p.pos.x += mv.dx * sp * dt
        p.pos.y += mv.dy * sp * dt
        TMap.push(&p.pos, 14)
        p.fireCd -= dt
        if wantReload { wantReload = false; startReload(p) }
        if wantSwap { wantSwap = false; swapGun(p) }
        if wantKnife { wantKnife = false; if !p.knife { p.knife = true; p.reloadT = 0; scoped = false; ads = false; p.fireCd = max(p.fireCd, 0.3) } }
        if wantGun { wantGun = false; if p.knife { p.knife = false; p.fireCd = max(p.fireCd, 0.3) } }
        if p.reloadT > 0 {
            p.reloadT -= dt
            if p.reloadT <= 0 { finishReload(p) }
        } else if firing && p.fireCd <= 0 && !actHeld {
            if p.knife { slash(p) } else if p.mag > 0 { shoot(p, 0) } else { startReload(p) }
        }
        if wantNade { wantNade = false; throwNade(p, p.aim, 420) }
        if wantFlash { wantFlash = false; throwNade(p, p.aim, 400, flash: true) }
        if wantSmoke { wantSmoke = false; throwNade(p, p.aim, 380, smoke: true) }
        if actHeld {
            if p.team == atkTeam && !planted && TMap.site(atkSite).contains(p.pos) && move == .zero { planting = true }
            if p.team != atkTeam && planted && tDist(p.pos, bombPos) < 46 && move == .zero { defusing = true }
        }
    }

    private func angWrap(_ x: CGFloat) -> CGFloat {
        var d = x
        while d > .pi { d -= 2 * .pi }
        while d < -.pi { d += 2 * .pi }
        return d
    }

    private func turnToward(_ cur: CGFloat, _ want: CGFloat, _ maxStep: CGFloat) -> CGFloat {
        let d = angWrap(want - cur)
        let s = min(abs(d), maxStep)
        return cur + (d < 0 ? -s : s)
    }

    private func pickTarget(_ p: TPlayer) -> TPlayer? {
        let range = p.knife ? 110 : TGuns.get(p.gun).range
        var best: TPlayer? = nil
        var bd: CGFloat = .greatestFiniteMagnitude
        for e in players where e.alive && e.team != p.team {
            let d = TMap.pdist(p.pos, e.pos)
            if d < range && d < bd && see(p.pos, e.pos) { bd = d; best = e }
        }
        return best
    }

    func startReload(_ p: TPlayer) {
        let g = TGuns.get(p.gun)
        if p.isPlayer && gameMode == 6 && p.spare <= 0 && !TWeapons.isPistol(p.gun) && p.mag < magSize(p, p.gun) { raidFeedAmmo() }
        guard !p.knife, p.reloadT <= 0, p.mag < magSize(p, p.gun), p.spare > 0 else { return }
        let tierMul: CGFloat = (p.isPlayer && gameMode == 6) ? max(0.6, 1 - 0.05 * CGFloat(gunTier)) : 1
        p.reloadT = g.reload * (p.isPlayer ? TAtt.mods(p.gun).reloadMul * TPerk.reloadMul : 1) * tierMul
    }

    private func finishReload(_ p: TPlayer) {
        p.mag = magSize(p, p.gun)
        if !TWeapons.isPistol(p.gun) { p.spare -= 1 }
    }

    /// melee: hits the nearest enemy in a short front arc; from behind it is an instant kill; also chips breakables in front
    private func slash(_ p: TPlayer) {
        p.fireCd = 0.55
        p.flash = 0.06
        p.noiseT = 0.8
        let fl = TMap.floorOf(p.pos)
        var hit = false
        var best: TPlayer? = nil
        var bd: CGFloat = 62
        for v in players where v.alive && v.team != p.team && TMap.floorOf(v.pos) == fl {
            let d = tDist(p.pos, v.pos)
            guard d < bd else { continue }
            let ang = atan2(v.pos.y - p.pos.y, v.pos.x - p.pos.x)
            guard abs(tAngDiff(ang, p.aim)) < 0.95, TMap.los(p.pos, v.pos) else { continue }
            bd = d
            best = v
        }
        if let v = best {
            let ang = atan2(v.pos.y - p.pos.y, v.pos.x - p.pos.x)
            let behind = abs(tAngDiff(v.aim, ang)) < 1.1
            knifeKill = true
            damage(v, behind ? 400 : 55 * (p.isPlayer ? 1 : [0.8, 1, 1][diff]), by: p.id)
            knifeKill = false
            if behind && p.isPlayer { pop(v.pos, "BACKSTAB", TUI.gold) }
            hit = true
        }
        let tip = CGPoint(x: p.pos.x + cos(p.aim) * 34, y: p.pos.y + sin(p.aim) * 34)
        for k in 0..<TMap.baseSolid.count where TMap.hp[k] > 0 && TMap.floorOfX(TMap.baseSolid[k].midX) == fl {
            if TMap.rectDist(TMap.baseSolid[k], tip) < 12 { TMap.hit(k, 38); hit = true; break }
        }
        if p.isPlayer {
            shake = max(shake, hit ? 5 : 1)
            kick = min(38, kick + 5)
        }
    }

    private func shoot(_ p: TPlayer, _ err: CGFloat) {
        let g = TGuns.get(p.gun)
        let spd: CGFloat = 1100
        var muzzle: CGFloat = 20
        var sprd = g.spread + err
        if TWeapons.cls(p.gun) == "sniper" && !(p.isPlayer && scoped) { sprd += 0.06 }
        let am = p.isPlayer ? TAtt.mods(p.gun) : TAttMods()
        let gm = gunMods(p)
        let rMul = am.recoilMul * gm.rec
        if p.isPlayer {
            sprd += recoil * 0.045 * rMul + (moving ? 0.03 : 0) + (p.crouch ? -0.004 : 0)
            if scoped { sprd *= 0.35 * am.scopeMul } else if ads { sprd *= 0.5 } else if TBody.on { sprd *= TBody.hipSpread }
            sprd = max(0.002, sprd)
            p.aim += CGFloat.random(in: -0.0035...0.0035) * (0.4 + recoil)
            recoil = min(1.2, recoil + 0.13 * rMul)
            kick = min(38, kick + (6 + recoil * 4) * rMul)
        }
        if p.isPlayer && p.crouch {
            let bx = cos(p.aim), by = sin(p.aim)
            for r in TMap.solid where r.minX > -5000 {
                if let h = brRayThrough(p.pos, bx, by, r), h.0 >= 0, h.0 < 40, h.1 - h.0 < 100 { muzzle = max(muzzle, h.1 + 3) }
            }
            if muzzle > 20 { sprd *= 2.6 }
        }
        if p.blind > 0 { sprd += p.isPlayer ? 0.05 : 0.35 }
        p.noiseT = am.silenced ? 0.45 : 1.5
        if p.isPlayer { noiseR = am.silenced ? 230 : 720 }
        let tfl = shootTargetFloor(p)
        for _ in 0..<g.pellets {
            let a = p.aim + CGFloat.random(in: -sprd...sprd)
            // the player's shot follows the camera pitch as well as yaw; spread opens the cone vertically too
            let pa: CGFloat = p.isPlayer ? pitch + CGFloat.random(in: -sprd...sprd) * 0.8 : 0
            var bl = Bullet(pos: CGPoint(x: p.pos.x + cos(a) * muzzle, y: p.pos.y + sin(a) * muzzle),
                            vel: CGVector(dx: cos(a) * spd, dy: sin(a) * spd), dmg: g.dmg * (p.isPlayer ? am.dmgMul * gm.dmg : [0.85, 1, 1][diff]),
                            life: g.range * am.rangeMul / spd + 0.15, owner: p.id, team: p.team, tf: tfl)
            bl.h = p.isPlayer ? (p.crouch ? CGFloat(TMap.eyeH) - 14 : CGFloat(TMap.eyeH)) : 48
            bl.vh = spd * tan(pa)
            bullets.append(bl)
        }
        p.mag -= 1
        p.fireCd = (1 / g.rate) * (p.isPlayer ? 1 : 1.15)
        p.flash = am.silenced ? 0 : 0.05
        if p.isPlayer { shake = max(shake, g.pellets > 1 ? 4 : 1.5) }
        if p.isPlayer && gameMode == 6 { raidWear(p) }
    }

    private func throwNade(_ p: TPlayer, _ ang: CGFloat, _ speed: CGFloat, smoke: Bool = false, flash: Bool = false) {
        guard p.alive, (flash ? p.flashes > 0 : (smoke ? p.smokes > 0 : p.nades > 0)) else { return }
        if flash { p.flashes -= 1 } else if smoke { p.smokes -= 1 } else { p.nades -= 1 }
        nades.append(Nade(pos: CGPoint(x: p.pos.x + cos(ang) * 20, y: p.pos.y + sin(ang) * 20),
                          vel: CGVector(dx: cos(ang) * speed, dy: sin(ang) * speed), fuse: 1.5, owner: p.id, team: p.team, kind: flash ? 2 : (smoke ? 1 : 0)))
    }

    func damage(_ victim: TPlayer, _ amt: CGFloat, by owner: Int) {
        guard victim.alive else { return }
        var amt = TBody.on && owner > -2 ? amt * TBody.dmgMul : amt
        if victim.armor > 0 && owner > -2 {
            let ratio: CGFloat = victim.armorKind >= 3 ? 0.75 : (victim.armorKind == 2 ? 0.6 : 0.5)
            let red: CGFloat = victim.armorKind >= 3 ? 0.9 : (victim.armorKind == 2 ? 0.85 : 0.8)
            let ab = min(victim.armor, amt * ratio); victim.armor -= ab; amt -= ab * red
        }
        victim.hp -= victim.crouch ? amt * 0.7 : amt
        victim.hurt = 0.25
        if owner > -2 && impacts.count < 48 { impacts.append(Impact(pos: victim.pos, nx: 0, ny: 0, kind: 1)) }
        if owner == 0 && victim.team != me.team { hitT = 0.2 }
        if victim.isPlayer && owner > -2 { shake = max(shake, 8) }
        if victim.isPlayer && gameMode == 6 && owner >= 0 && amt >= 10 { raidWound() }
        if let o = players.first(where: { $0.id == owner }), o.team != victim.team {
            if !victim.isPlayer && victim.targetID < 0 && victim.hunt <= 0 { victim.lastSeen = o.pos; victim.hunt = 4 }
        }
        if victim.hp <= 0 {
            victim.hp = 0
            victim.alive = false
            if impacts.count < 48 { impacts.append(Impact(pos: victim.pos, nx: 0, ny: 0, kind: 3)) }
            let killer = players.first { $0.id == owner }
            if victim.isPlayer {
                lastKiller = owner
                if (gameMode != 6 || owner > 0), owner != 0, owner != victim.id, rbuf.count > 8 { replay = []; replayOn = false }
            }
            if let k = killer, k.team != victim.team {
                k.kills += 1
                if gameMode == 0 { k.money = min(16000, k.money + 300) }
                if k.isPlayer { fxT = 1; fxId = killFx; fxSerial += 1 }
            }
            if let k = killer, k.isPlayer, k.team != victim.team, let msg = TacMeta.addMastery(k.gun) { pop(k.pos, msg, TUI.gold) }
            if gameMode == 6 && !victim.isPlayer { raidBotDrop(victim, by: owner) }
            if gameMode != 0 {
                victim.respawn = gameMode == 6 ? 0 : (victim.isPlayer && replayOn ? 999 : (gameMode == 7 ? 6 : 3))
                if gameMode == 6 && victim.isPlayer { brPlace = players.filter { $0.alive }.count + 1; brEndT = 3 }
                if (gameMode == 1 || gameMode == 4), let k = killer, k.team != victim.team { scores[k.team] += 1 }
                if gameMode == 7 { scores[victim.team] += 1 }
                if gameMode == 2 { tags.append(Tag(pos: victim.pos, team: victim.team, life: 25)) }
                if gameMode == 3, let k = killer, k.team != victim.team {
                    k.ladder += 1
                    scores[k.team] += 1
                    if k.ladder < TWeapons.ladder.count { setGun(k, TWeapons.ladder[k.ladder]) }
                }
            }
            let kn = killer?.name ?? (owner == -1 ? "The Storm" : (owner == -2 ? "Bleeding" : (owner == -3 ? "Toxic Gas" : (owner == -4 ? "Fall" : "?"))))
            feed.append(Feed(text: "\(kn)  >  \(victim.name)", life: 5, mine: killer?.isPlayer == true || victim.isPlayer, k: kn, v: victim.name, kTeam: killer?.team ?? 0, gun: knifeKill ? "knife" : (killer?.gun ?? "pistol"), head: knifeKill ? false : amt >= 45))
            if feed.count > 4 { feed.removeFirst() }
            pop(victim.pos, "X", .red)
        }
    }

    func pop(_ p: CGPoint, _ t: String, _ c: Color) {
        pops.append(Pop(pos: p, text: t, life: 1, color: c))
        if pops.count > 30 { pops.removeFirst() }
    }

    private func moveProjectiles(_ dt: CGFloat) {
        var keep: [Bullet] = []
        for var b in bullets {
            let old = b.pos
            b.pos.x += b.vel.dx * dt
            b.pos.y += b.vel.dy * dt
            let hPrev = b.h
            b.h += b.vh * dt
            b.life -= dt
            if b.life <= 0 { continue }
            if b.h < 0 || b.h > CGFloat(TMap.wallH) { continue }      // into the floor or ceiling
            var dead = false
            var hitK = -1
            let bnow = b.pos
            TGrid.forEachSeg(old, bnow) { k in
                guard tSegT(old, bnow, TMap.solid[k]) != nil else { return false }
                let mt = TMap.solidMat[k]
                if mt == .brick || mt == .concrete { noteImpact(old, bnow, TMap.solid[k], 0); TMap.hit(k, b.dmg * 0.9); dead = true; return true }
                hitK = k
                return false
            }
            if dead { continue }
            if hitK >= 0 {
                if hitK != b.inK {
                    let glass = TMap.solidMat[hitK] == .glass
                    noteImpact(old, bnow, TMap.solid[hitK], glass ? 2 : 0)
                    b.inK = hitK
                    TMap.hit(hitK, b.dmg * 0.9)
                    b.pens += 1
                    b.dmg *= glass ? 0.92 : 0.55
                    if !glass && (b.pens > 2 || b.dmg < 6) { continue }
                }
            } else { b.inK = -1 }
            for v in players where v.alive && v.team != b.team {
                let top: CGFloat = v.crouch ? 54 : 78
                let hm = (hPrev + b.h) / 2
                if tPointSeg(v.pos, old, b.pos) < 15 && hm >= 0 && hm <= top {
                    damage(v, b.dmg, by: b.owner)
                    dead = true
                    break
                }
            }
            if !dead && b.tf >= 0, let sh = TMap.hopShift(b.pos, to: b.tf) {
                b.pos.x += sh
                b.tf = -1
                b.inK = -1
            }
            if !dead { keep.append(b) }
        }
        bullets = keep
        var nk: [Nade] = []
        for var n in nades {
            n.fuse -= dt
            var np = CGPoint(x: n.pos.x + n.vel.dx * dt, y: n.pos.y + n.vel.dy * dt)
            let npc = np
            let npos = n.pos
            var bounce = false
            var bx = false
            TGrid.forEachNear(npc, 2) { k in
                let r = TMap.solid[k]
                guard r.contains(npc) else { return false }
                bounce = true
                bx = r.contains(CGPoint(x: npos.x + n.vel.dx * dt, y: npos.y))
                return true
            }
            if bounce {
                if bx { n.vel.dx = -n.vel.dx * 0.5 } else { n.vel.dy = -n.vel.dy * 0.5 }
                np = n.pos
            }
            n.pos = np
            n.vel.dx *= pow(0.5, dt)
            n.vel.dy *= pow(0.5, dt)
            if n.fuse <= 0 && n.kind == 2 {
                booms.append(Boom(pos: n.pos, life: 0.25, r: 60))
                for v in players where v.alive {
                    let d = tDist(v.pos, n.pos)
                    guard d < 320, TMap.los(n.pos, v.pos) else { continue }
                    let toN = atan2(n.pos.y - v.pos.y, n.pos.x - v.pos.x)
                    let facing = abs(tAngDiff(toN, v.aim)) < 1.5
                    v.blind = max(v.blind, (facing ? 3.2 : 0.8) * (1 - d / 400))
                }
            } else if n.fuse <= 0 && n.kind == 1 {
                smokeClouds.append(Smoke(pos: n.pos, life: 10, r: 85))
            } else if n.fuse <= 0 {
                booms.append(Boom(pos: n.pos, life: 0.45, r: 110))
                TMap.blast(n.pos, radius: 170, dmg: 190)
                shake = max(shake, tDist(n.pos, me.pos) < 300 ? 10 : 0)
                for v in players where v.alive {
                    let d = tDist(v.pos, n.pos)
                    if d < 110 && TMap.los(n.pos, v.pos) { damage(v, 100 * (1 - d / 110) + 12, by: n.owner) }
                }
            } else { nk.append(n) }
        }
        nades = nk
    }

    // MARK: bots

    private func botLook(_ p: TPlayer, _ dt: CGFloat) {
        // face the objective while frozen
        let d = objective(p)
        let a = atan2(d.y - p.pos.y, d.x - p.pos.x)
        p.aim += max(-3 * dt, min(3 * dt, tAngDiff(a, p.aim)))
    }

    private func stairCheck(_ p: TPlayer) {
        if let s = TMap.stairAt(p.pos) {
            if TMap.smooth {
                // continuous stairs: hand over to the other floor half way up the run, same spot in plan
                let t = TMap.stairT(s.0, p.pos), lo = TMap.stairLo[s.0]
                if s.1 == lo && t > 0.5 {
                    p.pos.x += TMap.off
                    p.path = []; p.pathT = 0; p.targetID = -1
                } else if s.1 == lo + 1 && t < 0.5 {
                    p.pos.x -= TMap.off
                    p.path = []; p.pathT = 0; p.targetID = -1
                }
                p.onStair = true
                return
            }
            if !p.onStair {
                let up = s.1 == TMap.stairLo[s.0]
                let r = TMap.stairRect(s.0, floor: up ? s.1 + 1 : s.1 - 1)
                p.pos = CGPoint(x: r.midX, y: r.midY)
                p.onStair = true
                p.path = []
                p.pathT = 0
                p.targetID = -1
            }
        } else {
            p.onStair = false
            if let h = TMap.holeAt(p.pos) {
                // the staircase is gone: you drop to the floor below
                let r = TMap.stairRect(h, floor: TMap.stairLo[h])
                var np = CGPoint(x: r.midX, y: r.maxY + 34)
                np = TNav.center(TNav.nearestFree(TNav.idx(np)))
                p.pos = np
                p.path = []
                p.pathT = 0
                p.targetID = -1
                p.onStair = true
                if p.isPlayer { pop(p.pos, "FELL", .red) }
                damage(p, 22, by: -4)
            }
        }
    }

    private func routed(_ p: TPlayer, _ dest: CGPoint) -> CGPoint {
        let pf = TMap.floorOf(p.pos), df = TMap.floorOf(dest)
        if pf == df { return dest }
        let nf = pf + (df > pf ? 1 : -1)
        let lo = min(pf, nf)
        var best = dest
        var bd = CGFloat.greatestFiniteMagnitude
        for i in TMap.stairs.indices where TMap.stairLo[i] == lo && TMap.stairIntact(i) {
            let here = TMap.stairRect(i, floor: pf)
            let there = TMap.stairRect(i, floor: nf)
            if TMap.smooth {
                // walk through the run: aim past the hand-over point going up, short of it going down
                let tt: CGFloat = nf > pf ? 0.8 : 0.2
                let tp = CGPoint(x: here.midX, y: here.maxY - tt * here.height)
                let tl = nf == df ? tDist(CGPoint(x: there.midX, y: there.midY), dest) : CGFloat(abs(df - nf)) * 900
                let cs = tDist(p.pos, tp) + tl
                if cs < bd { bd = cs; best = tp }
                continue
            }
            let tail = nf == df ? tDist(CGPoint(x: there.midX, y: there.midY), dest) : CGFloat(abs(df - nf)) * 900
            let c = tDist(p.pos, CGPoint(x: here.midX, y: here.midY)) + tail
            if c < bd { bd = c; best = CGPoint(x: here.midX, y: here.midY) }
        }
        return best
    }

    /// a wall or prop just broke: nearby bots drop their cached routes, and nearby squads may go and look
    private func reactToBreaches() {
        if TMap.breaches.isEmpty { return }
        let list = TMap.breaches
        TMap.breaches = []
        for r in list {
            let c = CGPoint(x: r.midX, y: r.midY)
            let fl = TMap.floorOf(c)
            var keys = Set<Int>()
            for p in players where p.alive && !p.isPlayer && TMap.floorOf(p.pos) == fl && tDist(p.pos, c) < 800 {
                p.path = []
                p.pathT = 0
                // each bot decides for itself whether the noise is worth checking
                if CGFloat.random(in: 0...1) < p.aggro * 0.8 { p.aiGoal = c; p.aiGoalT = time + 6 + 6 * p.patience }
            }
        }
    }

    private func roomGoal() -> CGPoint {
        let rs = TMap.rooms
        let r = rs[Int.random(in: 0..<rs.count)].r
        return CGPoint(x: r.midX + CGFloat.random(in: -r.width * 0.25...r.width * 0.25), y: r.midY + CGFloat.random(in: -r.height * 0.25...r.height * 0.25))
    }

    /// each bot picks its own post: aggressive ones lean toward the objective, careful ones hold rooms away from friends
    private func squadGoalFor(_ p: TPlayer, bias: CGPoint?) -> CGPoint {
        if p.aiGoalT > time && p.aiGoal != .zero { return p.aiGoal }
        let mates = players.filter { $0.team == p.team && $0 !== p && $0.alive }
        var best = roomGoal(), bestScore = -CGFloat.greatestFiniteMagnitude
        for _ in 0..<7 {
            var c = roomGoal()
            if let bi = bias, CGFloat.random(in: 0...1) < p.aggro * 0.8 { c = bi }
            var sc = CGFloat.random(in: 0...40)
            for m in mates {
                let mp = m.aiGoalT > time ? m.aiGoal : m.pos
                let d = tDist(c, mp)
                if d < 190 { sc -= (190 - d) * 2.2 }
            }
            if let bi = bias { sc -= tDist(c, bi) * p.aggro * 0.06 }
            sc -= tDist(c, p.pos) * (1 - p.aggro) * 0.02
            if sc > bestScore { bestScore = sc; best = c }
        }
        p.aiGoal = best
        p.aiGoalT = time + CGFloat.random(in: 7...20) * p.patience
        return best
    }

    private func objective(_ p: TPlayer) -> CGPoint {
        if gameMode == 6 { return raidGoal(p) }
        if gameMode == 7 { return frontGoal(p) }
        if gameMode == 5 {
            let zs = cpZones
            let notMine = (0..<3).filter { !(p.team == 0 ? cpProg[$0] >= 1 : cpProg[$0] <= -1) }
            let pick = notMine.isEmpty ? p.id % 3 : notMine[p.id % notMine.count]
            let r = zs[pick]
            return CGPoint(x: r.midX + cos(CGFloat(p.id) * 1.9) * r.width * 0.3, y: r.midY + sin(CGFloat(p.id) * 2.7) * r.height * 0.3)
        }
        if gameMode != 0 {
            if gameMode == 2, let t = tags.min(by: { tDist($0.pos, p.pos) < tDist($1.pos, p.pos) }), tDist(t.pos, p.pos) < 900 { return t.pos }
            if p.roam == .zero || tDist(p.pos, p.roam) < 50 {
                if Int.random(in: 0..<100) < 40, let en = players.filter({ $0.alive && $0.team != p.team }).randomElement() { p.roam = en.pos }
                else {
                    let g = squadGoalFor(p, bias: nil)
                    p.roam = CGPoint(x: g.x + cos(CGFloat(p.id) * 2.1) * 55, y: g.y + sin(CGFloat(p.id) * 2.1) * 55)
                }
            }
            return p.roam
        }
        let atk = p.team == atkTeam
        let o = CGPoint(x: cos(CGFloat(p.id) * 1.7) * 70, y: sin(CGFloat(p.id) * 2.3) * 45)
        let off = CGPoint(x: cos(CGFloat(p.id) * 2.1) * 60, y: sin(CGFloat(p.id) * 2.1) * 60)
        if planted {
            if atk {
                // guards spread over the rooms around the bomb
                let g = squadGoalFor(p, bias: bombPos)
                let near = tDist(g, bombPos) < 700 && TMap.floorOf(g) == TMap.floorOf(bombPos)
                let c = near ? g : bombPos
                return CGPoint(x: c.x + off.x * 1.6, y: c.y + off.y * 1.6)
            }
            // defenders come in from different squads / directions
            if p.aggro > 0.5 && time - plantedAt < 6 * p.patience {
                let g = squadGoalFor(p, bias: nil)
                return TMap.floorOf(g) == TMap.floorOf(bombPos) ? g : bombPos
            }
            return bombPos
        }
        let r = TMap.site(atk ? atkSite : p.site)
        if atk {
            // squad 0 executes the site, the other squads flank through other floors and rooms, everyone commits after 35s
            if p.aggro > 0.82 || time - roundT0 > p.commitAt { return CGPoint(x: r.midX + o.x, y: r.midY + o.y) }
            let g = squadGoalFor(p, bias: CGPoint(x: r.midX, y: r.midY))
            return CGPoint(x: g.x + off.x, y: g.y + off.y)
        }
        // defenders hold posts all over the house and rotate; half the posts lean on the sites
        let g = squadGoalFor(p, bias: CGPoint(x: r.midX, y: r.midY))
        return CGPoint(x: g.x + off.x, y: g.y + off.y)
    }

    private func botThink(_ p: TPlayer, _ dt: CGFloat, _ planting: inout Bool, _ defusing: inout Bool) {
        p.fireCd -= dt
        if p.reloadT > 0 {
            p.reloadT -= dt
            if p.reloadT <= 0 { finishReload(p) }
        }
        if p.mag <= 0 && p.reloadT <= 0 {
            if p.spare > 0 { startReload(p) } else { p.gun = "pistol"; p.mag = 15; p.spare = 99 }
        }
        p.seeT -= dt
        p.hunt = max(0, p.hunt - dt)
        if p.seeT <= 0 {
            p.seeT = 0.12
            var best: TPlayer? = nil
            var bd = CGFloat.greatestFiniteMagnitude
            for e in players where e.team != p.team && e.alive {
                let d = TMap.pdist(p.pos, e.pos)
                if d < raidSight(p) && d < bd && see(p.pos, e.pos) { best = e; bd = d }
            }
            if let b = best {
                if p.targetID != b.id { p.targetID = b.id; p.reactT = react[diff] * p.reflex }
                p.lastSeen = b.pos
            } else if p.targetID >= 0 {
                p.targetID = -1
                p.hunt = 3 * p.patience
            }
            if best == nil && p.targetID < 0 && p.hunt <= 0 && Double.random(in: 0...1) < 0.3 {
                for e in players where e.team != p.team && e.alive && e.noiseT > 0 {
                    if tDist(p.pos, e.pos) < 380 && TMap.floorOf(e.pos) == TMap.floorOf(p.pos) && CGFloat.random(in: 0...1) < p.aggro {
                        p.hunt = 2.5; p.lastSeen = e.pos; break
                    }
                }
            }
        }
        var speed: CGFloat = 150
        if p.ambush >= 0 && !TMap.stairIntact(p.ambush) { p.ambush = -1; p.crouch = false }
        var dest = p.holding ? p.ambushPos : objective(p)
        let atk = gameMode != 0 || p.team == atkTeam
        if p.targetID >= 0, let e = players.first(where: { $0.id == p.targetID }), e.alive {
            let d = TMap.pdist(p.pos, e.pos)
            let ang = TMap.pang(p.pos, e.pos)
            let df = tAngDiff(ang, p.aim)
            let mt = turn[diff] * dt
            p.aim += max(-mt, min(mt, df))
            p.reactT -= dt
            if p.reactT <= 0 && abs(df) < 0.14 && p.fireCd <= 0 && p.reloadT <= 0 && p.mag > 0 {
                if d < 46 && Int.random(in: 0..<100) < 70 { slash(p) } else { shoot(p, aimErr[diff]) }
            }
            if p.nades > 0 && d > 220 && TMap.floorOf(e.pos) == TMap.floorOf(p.pos) && Double.random(in: 0...1) < Double(dt) * 0.12 {
                throwNade(p, ang, min(d / 1.4, 470))
            }
            if p.holding && tDist(p.pos, p.ambushPos) < 60 { p.crouch = true; return }
            let pc = TWeapons.cls(p.gun)
            let pref: CGFloat = (pc == "shotgun" ? 200 : (pc == "smg" ? 320 : (pc == "rifle" ? 460 : (pc == "sniper" ? 700 : 380)))) * (1.2 - 0.5 * p.aggro)
            p.strafeT -= dt
            if p.strafeT <= 0 { p.strafe = Bool.random() ? 1 : -1; p.strafeT = CGFloat.random(in: 0.35...1.8) * p.patience }
            p.hideT -= dt
            if p.hideT <= 0 {
                p.hiding = p.hiding ? false : (p.hp < 50 * (0.5 + p.nerve) || Double.random(in: 0...1) < Double(0.15 + 0.6 * p.nerve * (1.1 - p.aggro)))
                p.hideT = p.hiding ? CGFloat.random(in: 0.9...1.8) : CGFloat.random(in: 1.2...2.4)
                p.cover = p.hiding ? coverSpot(p, e.pos) : nil
            }
            if p.hiding, let c = p.cover, tDist(p.pos, c) > 8 {
                let a2 = atan2(c.y - p.pos.y, c.x - p.pos.x)
                p.pos.x += cos(a2) * 125 * dt
                p.pos.y += sin(a2) * 125 * dt
                TMap.push(&p.pos, 14)
                return
            }
            if d > pref + 60 && (atk || planted) {
                dest = e.pos
            } else {
                let sx = -sin(ang) * p.strafe, sy = cos(ang) * p.strafe
                p.pos.x += sx * 95 * dt
                p.pos.y += sy * 95 * dt
                TMap.push(&p.pos, 14)
                return
            }
            speed = 120
        } else if p.hunt > 0 {
            dest = p.lastSeen
            speed = 130
            // hear gunfire through walls and spray at it (no aim assist, just rough error)
            if p.fireCd <= 0 && p.reloadT <= 0 && p.mag > 0 {
                for e in players where e.team != p.team && e.alive && e.noiseT > 0 {
                    let d = tDist(p.pos, e.pos)
                    if d < 300 && TMap.floorOf(e.pos) == TMap.floorOf(p.pos) {
                        let ang = atan2(e.pos.y - p.pos.y, e.pos.x - p.pos.x)
                        p.aim += max(-6 * dt, min(6 * dt, tAngDiff(ang, p.aim)))
                        if abs(tAngDiff(ang, p.aim)) < 0.2 && Double.random(in: 0...1) < 0.5 { shoot(p, aimErr[diff] * 2) }
                        break
                    }
                }
            }
        }
        if gameMode == 0 && atk && !planted && p.smokes > 0 && p.targetID < 0 && smokeClouds.isEmpty {
            let sc = TMap.site(atkSite)
            let c = CGPoint(x: sc.midX, y: sc.midY)
            let dd = tDist(p.pos, c)
            if dd < 400 && dd > 200 && TMap.los(p.pos, c) {
                throwNade(p, atan2(c.y - p.pos.y, c.x - p.pos.x), dd / 0.93, smoke: true)
            }
        }
        // actions
        if p.targetID < 0 {
            if atk && !planted && p.role == 1 && TMap.site(atkSite).contains(p.pos) { planting = true }
            if !atk && planted && tDist(p.pos, bombPos) < 40 { defusing = true }
        }
        // movement
        dest = routed(p, dest)
        let atDest = tDist(p.pos, dest) < 26
        if atDest {
            if p.targetID < 0 {
                if p.holding {
                    p.crouch = true
                    p.aim += max(-3 * dt, min(3 * dt, tAngDiff(p.ambushAim, p.aim)))
                } else {
                    p.aim += sin(time * 1.3 + CGFloat(p.id)) * dt * 0.8
                }
            }
            return
        }
        p.pathT -= dt
        if p.pathT <= 0 || tDist(dest, p.pathDest) > 90 {
            p.path = TNav.path(p.pos, dest)
            p.pathDest = dest
            p.pathT = CGFloat.random(in: 0.8...1.4)
        }
        while let f = p.path.first, tDist(p.pos, f) < 14 { p.path.removeFirst() }
        guard let nxt = p.path.first else { return }
        let a = atan2(nxt.y - p.pos.y, nxt.x - p.pos.x)
        p.pos.x += cos(a) * speed * dt
        p.pos.y += sin(a) * speed * dt
        TMap.push(&p.pos, 14)
        if p.targetID < 0 {
            p.aim += max(-4 * dt, min(4 * dt, tAngDiff(a, p.aim)))
        }
    }

    // MARK: drawing

    func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        if replayOn && !me.alive { return }
        drawOverlay3D(&ctx, size)
    }














    func drawMinimapPublic(_ ctx: inout GraphicsContext) {
        drawRadar(&ctx)
    }

    /// First-person radar: baked map image rotated heading-up inside a circle, live markers on top.
    private func drawRadar(_ ctx: inout GraphicsContext) {
        if TBody.on { return }
        let focus: TPlayer = me.alive ? me : (players.first { $0.team == me.team && $0.alive } ?? me)
        let cx: CGFloat = 84, cy: CGFloat = 128, R: CGFloat = 64
        let s: CGFloat = 0.12
        let th = -CGFloat.pi / 2 - focus.aim
        let ct = cos(th), st = sin(th)
        let circle = Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2))
        ctx.fill(circle, with: .color(Color.black.opacity(0.78)))
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let dx = (x - focus.pos.x) * s, dy = (y - focus.pos.y) * s
            return CGPoint(x: cx + dx * ct - dy * st, y: cy + dx * st + dy * ct)
        }
        func clamp(_ p: CGPoint) -> (CGPoint, Bool) {
            let dx = p.x - cx, dy = p.y - cy
            let d = hypot(dx, dy)
            if d <= R - 5 { return (p, false) }
            return (CGPoint(x: cx + dx / d * (R - 5), y: cy + dy / d * (R - 5)), true)
        }
        var g = ctx
        g.clip(to: circle)
        var mg = g
        mg.opacity = 0.7
        mg.translateBy(x: cx, y: cy)
        mg.rotate(by: .radians(Double(th)))
        mg.scaleBy(x: s, y: s)
        mg.translateBy(x: -focus.pos.x, y: -focus.pos.y)
        let rf = TMap.floorOf(focus.pos)
        mg.draw(Image(uiImage: TacRadar.image(rf)), in: CGRect(x: TMap.origin(rf), y: 0, width: TMap.floorW, height: TMap.H))
        // destroyed walls / props: paint the floor back over them so the radar matches the real geometry
        for k in TMap.brokenAll where TMap.floorOfX(TMap.origBase[k].midX) == rf {
            mg.fill(Path(TMap.origBase[k]), with: .color(Color(red: 0.5, green: 0.46, blue: 0.4)))
        }
        // dynamic doors (closed ones as bars)
        for (i, d) in TMap.doors.enumerated() where i < TMap.doorOpen.count && TMap.doorOpen[i] < 0.5 && TMap.floorOf(CGPoint(x: d.midX, y: d.midY)) == rf {
            mg.fill(Path(d), with: .color(Color(red: 0.75, green: 0.55, blue: 0.28)))
        }
        let pulse = 0.5 + 0.5 * sin(Double(time) * 4)
        if gameMode == 7 {
            for (i, z) in cpZones.enumerated() {
                let (c, edge) = clamp(P(z.midX, z.midY))
                let pr = cpProg[i]
                let col: Color = pr == 0 ? .gray : (pr > 0 ? Color(red: 0.3, green: 0.62, blue: 1) : Color(red: 1, green: 0.28, blue: 0.3))
                g.fill(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 8, width: 16, height: 16)), with: .color(Color.black.opacity(0.55)))
                g.stroke(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 8, width: 16, height: 16)), with: .color(col.opacity(edge ? 0.7 : 1)), lineWidth: 2)
                g.draw(Text(["A", "B", "C", "D", "E"][i]).font(.system(size: 9, weight: .heavy)).foregroundColor(col), at: c)
            }
        }
        if gameMode == 5 {
            for (i, z) in cpZones.enumerated() {
                let c = P(z.midX, z.midY)
                let pr = cpProg[i]
                let col: Color = pr == 0 ? .gray : (pr > 0 ? Color(red: 0.3, green: 0.62, blue: 1) : Color(red: 0.96, green: 0.62, blue: 0.16))
                g.stroke(Path(ellipseIn: CGRect(x: c.x - 11, y: c.y - 11, width: 22, height: 22)), with: .color(col.opacity(0.9)), lineWidth: 2)
                g.draw(Text(["A", "B", "C"][i]).font(.system(size: 10, weight: .heavy)).foregroundColor(col), at: c)
            }
        }
        for t in tags {
            let c = clamp(P(t.pos.x, t.pos.y)).0
            let col: Color = t.team == me.team ? Color(red: 0.3, green: 0.62, blue: 1) : Color.yellow
            g.fill(Path(CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(col))
        }
        for pk in packs where !pk.taken && TMap.floorOf(pk.pos) == rf {
            let c = P(pk.pos.x, pk.pos.y)
            g.fill(Path(CGRect(x: c.x - 3, y: c.y - 1, width: 6, height: 2)), with: .color(.green))
            g.fill(Path(CGRect(x: c.x - 1, y: c.y - 3, width: 2, height: 6)), with: .color(.green))
        }
        for sm in smokeClouds {
            let c = P(sm.pos.x, sm.pos.y)
            g.fill(Path(ellipseIn: CGRect(x: c.x - sm.r * s, y: c.y - sm.r * s, width: sm.r * 2 * s, height: sm.r * 2 * s)), with: .color(.white.opacity(0.4)))
        }
        if gameMode == 6 {
            for z in TacticalEngine.raidZones where TMap.floorOf(z.pos) == rf {
                let c = P(z.pos.x, z.pos.y)
                if hypot(c.x - cx, c.y - cy) > R - 6 { continue }
                let zc: Color = z.key ? TUI.gold : TUI.green
                g.stroke(Path(ellipseIn: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12)), with: .color(zc), lineWidth: 2)
                g.fill(Path(ellipseIn: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)), with: .color(zc))
            }
            if (evKind == 1 || evKind == 4) && TMap.floorOf(evPos) == rf {
                let ec = P(evPos.x, evPos.y)
                let er: CGFloat = evKind == 4 ? 230 * s : 7
                if hypot(ec.x - cx, ec.y - cy) < R {
                    g.stroke(Path(ellipseIn: CGRect(x: ec.x - er, y: ec.y - er, width: er * 2, height: er * 2)), with: .color(evKind == 4 ? Color.green : TUI.gold), lineWidth: 2)
                }
            }
            for l in loot where !l.taken && !l.id.isEmpty && TMap.floorOf(l.pos) == rf {
                let c = P(l.pos.x, l.pos.y)
                if hypot(c.x - cx, c.y - cy) > R - 4 { continue }
                let tier: Color = (l.id == "g:awp" || l.id == "g:ak" || l.id == "g:m4" || l.id == "armor:3") ? TUI.gold : (l.id.hasPrefix("g:") || l.id.hasPrefix("armor") ? TUI.blue : (l.id == "med" ? TUI.green : Color.white.opacity(0.7)))
                g.fill(Path(ellipseIn: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4)), with: .color(tier))
            }
        }
        // view cone
        var cone = Path()
        cone.move(to: CGPoint(x: cx, y: cy))
        cone.addArc(center: CGPoint(x: cx, y: cy), radius: R, startAngle: .radians(-Double.pi / 2 - 0.5), endAngle: .radians(-Double.pi / 2 + 0.5), clockwise: false)
        cone.closeSubpath()
        g.fill(cone, with: .linearGradient(Gradient(colors: [Color.green.opacity(0.32), Color.green.opacity(0)]), startPoint: CGPoint(x: cx, y: cy), endPoint: CGPoint(x: cx, y: cy - R)))
        for p in players where p.alive && !p.isPlayer && (p.team == me.team || p.spotted) && TMap.floorOf(p.pos) == rf {
            let (c, edge) = clamp(P(p.pos.x, p.pos.y))
            let ally = p.team == me.team
            let col: Color = ally ? Color(red: 0.3, green: 0.62, blue: 1) : Color(red: 1, green: 0.28, blue: 0.3)
            if edge {
                g.fill(Path(ellipseIn: CGRect(x: c.x - 3, y: c.y - 3, width: 6, height: 6)), with: .color(col))
                continue
            }
            let a = Double(p.aim + th)
            var tri = Path()
            tri.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * 7, y: c.y + CGFloat(sin(a)) * 7))
            tri.addLine(to: CGPoint(x: c.x + CGFloat(cos(a + 2.5)) * 5, y: c.y + CGFloat(sin(a + 2.5)) * 5))
            tri.addLine(to: CGPoint(x: c.x + CGFloat(cos(a - 2.5)) * 5, y: c.y + CGFloat(sin(a - 2.5)) * 5))
            tri.closeSubpath()
            g.fill(tri, with: .color(col))
            g.stroke(tri, with: .color(.black.opacity(0.7)), lineWidth: 0.8)
            if !ally { g.stroke(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)), with: .color(col.opacity(0.3 + 0.4 * pulse)), lineWidth: 1) }
        }
        for pg in pings {
            let c = clamp(P(pg.pos.x, pg.pos.y)).0
            g.stroke(Path(ellipseIn: CGRect(x: c.x - 7, y: c.y - 7, width: 14, height: 14)), with: .color(.orange.opacity(Double(min(1, pg.life)))), lineWidth: 1.5)
        }
        if planted && TMap.floorOf(bombPos) == rf {
            let c = clamp(P(bombPos.x, bombPos.y)).0
            let rr = 5 + 5 * CGFloat(pulse)
            g.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)), with: .color(.red.opacity(0.8)), lineWidth: 1.5)
            g.fill(Path(ellipseIn: CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7)), with: .color(.orange))
        }
        // me, always centre, pointing up
        var me3 = Path()
        me3.move(to: CGPoint(x: cx, y: cy - 8))
        me3.addLine(to: CGPoint(x: cx + 5.5, y: cy + 5))
        me3.addLine(to: CGPoint(x: cx, y: cy + 2))
        me3.addLine(to: CGPoint(x: cx - 5.5, y: cy + 5))
        me3.closeSubpath()
        g.fill(me3, with: .color(Color(red: 0.3, green: 0.95, blue: 0.45)))
        g.stroke(me3, with: .color(.black.opacity(0.8)), lineWidth: 1)
        // vignette + bezel
        ctx.fill(circle, with: .radialGradient(Gradient(colors: [.clear, .black.opacity(0.5)]), center: CGPoint(x: cx, y: cy), startRadius: R * 0.62, endRadius: R))
        ctx.stroke(circle, with: .color(.white.opacity(0.55)), lineWidth: 2.5)
        ctx.stroke(Path(ellipseIn: CGRect(x: cx - R - 3, y: cy - R - 3, width: R * 2 + 6, height: R * 2 + 6)), with: .color(.black.opacity(0.6)), lineWidth: 2)
        ctx.draw(Text("N").font(.system(size: 9, weight: .heavy)).foregroundColor(.red), at: CGPoint(x: cx + st * (R - 9), y: cy - ct * (R - 9)))
    }



    // MARK: HUD helpers

    var meInSite: Bool { me.alive && me.team == atkTeam && !planted && TMap.site(atkSite).contains(me.pos) }
    var meNearBomb: Bool { me.alive && me.team != atkTeam && planted && tDist(me.pos, bombPos) < 46 }
    var allyAlive: Int { players.filter { $0.team == me.team && $0.alive }.count }
    var enemyAlive: Int { players.filter { $0.team != me.team && $0.alive }.count }
    var objectiveText: String {
        if gameMode == 6 { return contractText }
        if gameMode == 1 { return "First to \(killTarget) kills" }
        if gameMode == 2 { return "Collect enemy tags, deny yours" }
        if gameMode == 3 { return "Arms Race  \(min(me.ladder + 1, TWeapons.ladder.count))/\(TWeapons.ladder.count)  \(TGuns.get(me.gun).name)" }
        if phase == 0 { return me.team == atkTeam ? "Attack: plant at \(TMap.siteNames[atkSite])" : "Defend \(TMap.siteNames[0]) and \(TMap.siteNames[1])" }
        if planted { return me.team == atkTeam ? "Protect the bomb" : "Defuse the bomb" }
        return me.team == atkTeam ? "Plant the bomb at \(TMap.siteNames[atkSite])" : "Hold both sites"
    }
}

// MARK: - Battle royale

extension TacticalEngine {
    func brStart() {
        loot = TMap.lootSpots.map { Loot(pos: $0.0, id: $0.1, taken: false) }
        stormT = 0
        stormHitT = 0
        brPlace = 0
        brEndT = 3
        let c0 = CGPoint(x: 1500, y: TMap.H / 2)
        let cf = CGPoint(x: 1500 + CGFloat.random(in: -250...250), y: 760 + CGFloat.random(in: -200...200))
        let n = stormR.count - 1
        stormCs = (0...n).map { i in
            CGPoint(x: c0.x + (cf.x - c0.x) * CGFloat(i) / CGFloat(n), y: c0.y + (cf.y - c0.y) * CGFloat(i) / CGFloat(n))
        }
        updateStorm()
    }

    /// storm schedule: every stage holds 40s, then shrinks for 25s toward the next circle
    func updateStorm() {
        guard stormCs.count == stormR.count else { return }
        let hold: CGFloat = 40, shrink: CGFloat = 25
        var t = stormT
        var s = 0
        while s < stormR.count - 1 && t >= hold + shrink { t -= hold + shrink; s += 1 }
        stormStage = s
        if s >= stormR.count - 1 {
            stormRad = stormR[s]
            stormC = stormCs[s]
            stormShrinking = false
            stormCountdown = 0
            return
        }
        if t < hold {
            stormRad = stormR[s]
            stormC = stormCs[s]
            stormShrinking = false
            stormCountdown = hold - t
        } else {
            let k = (t - hold) / shrink
            stormRad = stormR[s] + (stormR[s + 1] - stormR[s]) * k
            stormC = CGPoint(x: stormCs[s].x + (stormCs[s + 1].x - stormCs[s].x) * k, y: stormCs[s].y + (stormCs[s + 1].y - stormCs[s].y) * k)
            stormShrinking = true
            stormCountdown = hold + shrink - t
        }
    }

    func stormOutside(_ pos: CGPoint) -> Bool {
        let px = pos.x - TMap.origin(TMap.floorOf(pos))
        return hypot(px - stormC.x, pos.y - stormC.y) > stormRad
    }

    func brTick(_ dt: CGFloat) {
        stormT += dt
        updateStorm()
        stormHitT -= dt
        if stormHitT <= 0 {
            stormHitT = 0.5
            for p in players where p.alive && stormOutside(p.pos) { damage(p, stormDps * 0.5, by: -1) }
        }
        for i in loot.indices where !loot[i].taken {
            let lp = loot[i].pos
            let lf = TMap.floorOf(lp)
            for p in players where p.alive && TMap.floorOf(p.pos) == lf && tDist(p.pos, lp) < 28 {
                if lootUse(p, loot[i].id, apply: true) { loot[i].taken = true; break }
            }
        }
        let n = brAlive
        if !me.alive {
            brEndT -= dt
            if brEndT <= 0 { phase = 4; over = true; won = false; banner = "ELIMINATED"; bannerT = 3 }
        } else if n <= 1 {
            phase = 4; over = true; won = true; banner = "VICTORY ROYALE"; bannerT = 3
        }
    }

    /// picks a pickup up (apply) or just says whether this player would take it
    @discardableResult
    func lootUse(_ p: TPlayer, _ id: String, apply: Bool) -> Bool {
        let parts = id.split(separator: ":").map(String.init)
        let kind = parts[0]
        let arg = parts.count > 1 ? parts[1] : ""
        switch kind {
        case "med":
            if p.isPlayer && gameMode == 6 { return !raidBagFull }
            guard p.hp < 90 else { return false }
            if apply { p.hp = min(100, p.hp + 45); if p.isPlayer { pop(p.pos, "+45", .green) } }
            return true
        case "ammo":
            if p.isPlayer && gameMode == 6 { return !raidBagFull }
            guard !TWeapons.isPistol(p.gun), p.spare < 4 else { return false }
            if apply { p.spare = min(6, p.spare + 2); if p.isPlayer { pop(p.pos, "AMMO", .yellow) } }
            return true
        case "nade":
            guard p.nades < 3 else { return false }
            if apply { p.nades += 1; if p.isPlayer { pop(p.pos, "GRENADE", .white) } }
            return true
        case "armor":
            let k = Int(arg) ?? 1
            guard p.armorKind < k || p.armor < 30 else { return false }
            if apply { p.armorKind = k; p.armor = k >= 3 ? 150 : (k == 2 ? 100 : 60); if p.isPlayer { pop(p.pos, "ARMOR", .blue) } }
            return true
        case "val", "part", "intel":
            return p.isPlayer && !raidBagFull
        case "plate", "band", "kit":
            return p.isPlayer && gameMode == 6 && !raidBagFull
        case "vault":
            return p.isPlayer && gameMode == 6 && raidHasKey && raidBag.count + 3 <= TacStash.packCap
        case "key":
            return p.isPlayer
        case "g":
            if p.isPlayer && gameMode == 6 { return !raidBagFull }
            let np = TWeapons.w(arg).price
            if TWeapons.isPistol(arg) {
                guard TWeapons.isPistol(p.gun), np > TWeapons.w(p.gun).price else { return false }
                if apply { setGun(p, arg); if p.isPlayer { pop(p.pos, TGuns.get(arg).name.uppercased(), .yellow) } }
                return true
            }
            guard TWeapons.isPistol(p.gun) || np > TWeapons.w(p.gun).price else { return false }
            if apply {
                if TWeapons.isPistol(p.gun) { p.altGun = p.gun; p.altMag = p.mag; p.altSpare = 99 }
                setGun(p, arg)
                if p.isPlayer { pop(p.pos, TGuns.get(arg).name.uppercased(), .yellow) }
            }
            return true
        default:
            return false
        }
    }

    private func lootValue(_ id: String) -> CGFloat {
        switch id {
        case "g:awp": return 450
        case "g:ak", "g:m4", "armor:3": return 400
        case "armor:2": return 300
        case "g:p90", "g:pump", "g:rifle", "g:shotgun": return 250
        case "g:smg", "g:mp7": return 180
        case "med": return 200
        case "armor:1": return 150
        case "ammo": return 120
        case "nade": return 80
        default: return 60
        }
    }

    /// where a battle-royale bot wants to be: inside the zone first, then gear, then the next fight
    func brGoal(_ p: TPlayer) -> CGPoint {
        if p.roam != .zero && p.goalT > time && tDist(p.pos, p.roam) > 40 { return p.roam }
        p.goalT = time + CGFloat.random(in: 2.5...4.5)
        let fl = TMap.floorOf(p.pos)
        let plan = CGPoint(x: p.pos.x - TMap.origin(fl), y: p.pos.y)
        let inside = hypot(plan.x - stormC.x, plan.y - stormC.y) < stormRad - 80
        var nextR = stormRad, nextC = stormC
        if stormStage < stormR.count - 1, stormCs.count == stormR.count { nextR = stormR[stormStage + 1]; nextC = stormCs[stormStage + 1] }
        let outsideNext = hypot(plan.x - nextC.x, plan.y - nextC.y) > nextR - 60
        var dest = p.roam
        if !inside || ((stormShrinking || stormCountdown < 25) && outsideNext) {
            // run for the safe circle on the surface (stairs are routed automatically)
            let a = CGFloat(p.id) * 2.4
            dest = CGPoint(x: nextC.x + cos(a) * nextR * 0.45 + TMap.origin(1), y: nextC.y + sin(a) * nextR * 0.45)
        } else {
            var bestLoot: CGPoint? = nil
            var bs = CGFloat.greatestFiniteMagnitude
            for l in loot where !l.taken {
                if !lootUse(p, l.id, apply: false) { continue }
                let lf = TMap.floorOf(l.pos)
                let lp = CGPoint(x: l.pos.x - TMap.origin(lf), y: l.pos.y)
                if hypot(lp.x - stormC.x, lp.y - stormC.y) > stormRad - 40 { continue }
                let d = hypot(lp.x - plan.x, lp.y - plan.y) + CGFloat(abs(lf - fl)) * 600
                let s = d - lootValue(l.id)
                if d < 1500 && s < bs { bs = s; bestLoot = l.pos }
            }
            if let b = bestLoot {
                dest = b
            } else if Int.random(in: 0..<100) < 35, let en = players.filter({ $0.alive && $0.id != p.id }).min(by: { tDist($0.pos, p.pos) < tDist($1.pos, p.pos) }) {
                dest = en.pos
            } else {
                let rs = TMap.rooms.filter { r in
                    let rf = r.fl
                    let c = CGPoint(x: r.r.midX - TMap.origin(rf), y: r.r.midY)
                    return hypot(c.x - stormC.x, c.y - stormC.y) < stormRad - 40
                }
                if let r = rs.randomElement() {
                    dest = CGPoint(x: r.r.midX + CGFloat.random(in: -60...60), y: r.r.midY + CGFloat.random(in: -60...60))
                } else {
                    dest = CGPoint(x: stormC.x + TMap.origin(1), y: stormC.y)
                }
            }
        }
        p.roam = dest
        return dest
    }
}

// MARK: - Play view

struct TacticalPlay: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @Environment(\.dismiss) private var dismiss
    @State private var showLoadout = false
    var diff: Int
    var modeId = 0
    @State private var engine = TacticalEngine()
    @State private var lStart: CGPoint? = nil
    @State private var lActive = false
    @State private var crossLast: CGSize = .zero
    @State private var crossMax: CGFloat = 0
    @State private var lOff: CGSize = .zero
    @State private var lKnob: CGPoint = .zero
    @State private var rStart: CGPoint? = nil
    @State private var rKnob: CGPoint = .zero
    @State private var collected = false
    @State private var autoOn = true
    @State private var bridge: TacScene? = nil
    private var fp: Bool { true }
    @State private var lastLook: CGFloat = 0
    @State private var lastLookY: CGFloat = 0
    @State private var lookOn = false
    @State private var baseYaw: CGFloat = 0
    @State private var lastDrag = CGSize.zero
    @State private var baseDist: CGFloat = 430
    @State private var camP = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let b = bridge {
                TacSceneView(bridge: b).ignoresSafeArea().allowsHitTesting(false)
            }
            TimelineView(.animation) { tl in
                Canvas { ctx, size in
                    engine.step(tl.date)
                    bridge?.sync(engine)
                    engine.draw(&ctx, size)
                }
            }
            .ignoresSafeArea()
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                ZStack {
                    if !(engine.replayOn && !engine.me.alive && !engine.over) {
                        controls
                        hud
                        buyLayer
                    }
                }
            }
            stateLayer
        }
        .statusBarHidden(true)
        .onAppear {
            OrientationLock.set(landscape: true)
            engine.fp = true
            engine.view3D = true
            engine.autoAim = false
            engine.autoFire = false
            autoOn = true
            let sxd = game.sx
            engine.killFx = sxd.fx
            engine.charm = sxd.charm
            engine.theme = TacSeason.themes.firstIndex(of: sxd.map) ?? 0
            let gc = TacSeason.cos(sxd.gloves).rgb
            let mine = TacAvatar.style(TacAvatar.myKey)
            let fpk = TacGear.fpColors(mine.look, skin: mine.skin)
            TwViewModel.sleeveColor = fpk?.sleeve
            TwViewModel.fingerColor = fpk?.fingers
            if sxd.gloves != "gl_black" {
                TwViewModel.gloveColor = UIColor(red: gc.0, green: gc.1, blue: gc.2, alpha: 1)
            } else if let f = fpk {
                TwViewModel.gloveColor = f.glove
            } else {
                TwViewModel.gloveColor = mine.gloves == 0 ? mine.skin : mine.gloveCol
            }
            if fpk?.fingers != nil { TwViewModel.fingerColor = TwViewModel.gloveColor }
            engine.mapPick = nav.tacMap
            engine.setup(gun: nav.tacGun, diff: diff, mode: modeId)
            _ = TacRadar.image(0)
            let b = TacScene()
            b.fpMode = true
            b.build(engine)
            bridge = b
            engine.project = { [weak b] p, h in b?.project(p, h) }
        }
    }

    private func gearSym(_ id: String) -> String {
        switch id {
        case "kev": return "shield.lefthalf.filled"
        case "vest": return "shield.fill"
        case "spec": return "shield.checkered"
        case "flashb": return "sun.max.fill"
        case "smokeb": return "smoke.fill"
        default: return "circle.hexagongrid.fill"
        }
    }

    private func buyBtn(_ e: TacticalEngine, _ id: String, _ name: String, gear: Bool) -> some View {
        let c = e.price(id)
        let own = e.me.gun == id || e.me.altGun == id
        let ok = e.me.money >= c && !own
        return Button { e.buyItem(e.me, id) } label: {
            HStack(spacing: 8) {
                if gear {
                    SF(gearSym(id), "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(.white.opacity(0.9)).frame(width: 34)
                } else {
                    Image(uiImage: GunSprites.icon(TWeapons.rig(id))).renderingMode(.template).resizable().scaledToFit()
                        .foregroundColor(.white.opacity(0.9)).frame(width: 34, height: 15)
                }
                Text(name).font(.jk(11, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                if own {
                    SF("checkmark.circle.fill").font(.system(size: 13)).foregroundColor(TUI.green)
                } else {
                    Text("$\(c)").font(.jk(11, .bold)).foregroundColor(ok ? TUI.green : TUI.red.opacity(0.85))
                }
            }
            .padding(.horizontal, 9).frame(width: 150, height: 34)
            .background(Rectangle().fill(Color.white.opacity(ok ? 0.12 : 0.04)))
            .overlay(Rectangle().stroke(own ? TUI.green.opacity(0.6) : Color.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func buyCol(_ e: TacticalEngine, _ title: String, _ items: [(String, String)], gear: Bool = false) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.jk(10, .heavy)).tracking(1).foregroundColor(TUI.accent)
            ForEach(items, id: \.0) { it in buyBtn(e, it.0, it.1, gear: gear) }
        }
    }

    private var buyLayer: some View {
        TimelineView(.periodic(from: .now, by: 0.15)) { _ in
            let e = engine
            ZStack {
                if e.buyOpen && e.gameMode == 0 && e.buyT > 0 && e.me.alive {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            SF("cart.fill").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            Text("BUY MENU").font(.jk(15, .heavy)).foregroundColor(.white)
                            Text("\(Int(e.buyT))s").font(.jk(12, .bold)).foregroundColor(.white.opacity(0.6))
                            Spacer()
                            SF("dollarsign.circle.fill").font(.system(size: 16)).foregroundColor(TUI.green)
                            Text("\(e.me.money)").font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundColor(TUI.green)
                            Button { e.buyOpen = false } label: {
                                SF("xmark").font(.system(size: 12, weight: .black)).foregroundColor(.white)
                                    .frame(width: 30, height: 30).background(Rectangle().fill(Color.white.opacity(0.12))).overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(TuiPress())
                        }
                        HStack(alignment: .top, spacing: 10) {
                            buyCol(e, "PISTOL", [("eagle", "EAGLE-50")])
                            buyCol(e, "SMG", [("smg", "VX-9 SMG"), ("mp7", "MP-7"), ("p90", "P-90")])
                            buyCol(e, "RIFLE", [("rifle", "AR-27"), ("ak", "AK-74X"), ("m4", "M4-CQ")])
                            buyCol(e, "HEAVY", [("pump", "PUMP-12"), ("shotgun", "BREACHER"), ("awp", "AWP-X")])
                            buyCol(e, "GEAR", [("kev", "KEVLAR"), ("vest", "VEST + HELMET"), ("spec", "SPECIAL ARMOR"), ("flashb", "FLASHBANG"), ("smokeb", "SMOKE"), ("fragb", "FRAG")], gear: true)
                        }
                    }
                    .padding(14)
                    .tuiGlass(18, fill: 0.84)
                }
            }
        }
    }

    private var controls: some View {
        GeometryReader { g in
            ZStack {
                HStack(spacing: 0) {
                    Color.clear.frame(width: g.size.width * 0.5)
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                if fp {
                                    let sens: CGFloat = engine.scoped ? 0.0035 : (engine.ads ? 0.0055 : 0.008)
                                    engine.lookDelta += (v.translation.width - lastLook) * sens
                                    lastLook = v.translation.width
                                    // free look: dragging up looks up
                                    engine.pitch = max(-0.75, min(0.75, engine.pitch - (v.translation.height - lastLookY) * sens * 0.8))
                                    lastLookY = v.translation.height
                                    return
                                }
                                rStart = v.startLocation
                                rKnob = v.location
                                let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
                                if hypot(dx, dy) > 8 { engine.aimIn = atan2(dy, dx) - (bridge?.yaw ?? 0) }
                                engine.firing = true
                            }
                            .onEnded { _ in rStart = nil; lastLook = 0; lastLookY = 0; engine.aimIn = nil; engine.firing = false })
                }
                // fixed, always-visible movement stick (bottom-left)
                let sb = CGPoint(x: 120, y: g.size.height - 112)
                ZStack {
                    Circle().fill(Color.black.opacity(0.22)).frame(width: 128, height: 128)
                    Circle().stroke(Color.white.opacity(0.4), lineWidth: 1).frame(width: 128, height: 128)
                    Rectangle().fill(Color.white.opacity(0.18)).frame(width: 128, height: 1)
                    Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 128)
                    Rectangle().fill(Color.white.opacity(lActive ? 0.8 : 0.4)).frame(width: 46, height: 46)
                        .overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1))
                        .offset(x: lOff.width, y: lOff.height)
                    Image(systemName: "arrow.up").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.5)).offset(y: -52)
                }
                .frame(width: 210, height: 210)
                .contentShape(Rectangle())
                .position(sb)
                .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { v in
                        // origin = where the thumb first lands, so a touch alone never moves you
                        let dx = v.location.x - v.startLocation.x, dy = v.location.y - v.startLocation.y
                        let d = max(0.001, hypot(dx, dy))
                        let k = min(1, d / 58)
                        lActive = true
                        lOff = CGSize(width: dx / d * k * 58, height: dy / d * k * 58)
                        var mv = d > 6 ? CGVector(dx: dx / d * k, dy: dy / d * k) : .zero
                        if !fp, let b = bridge, b.yaw != 0 {
                            let c = cos(b.yaw), sn = sin(b.yaw)
                            mv = CGVector(dx: c * mv.dx + sn * mv.dy, dy: -sn * mv.dx + c * mv.dy)
                        }
                        engine.move = mv
                    }
                    .onEnded { _ in lActive = false; lOff = .zero; engine.move = .zero })
                if lookOn {
                    Color.clear.contentShape(Rectangle())
                        .frame(width: g.size.width * 0.55, height: g.size.height)
                        .position(x: g.size.width * 0.725, y: g.size.height / 2)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let dx = v.translation.width - lastDrag.width
                                let dy = v.translation.height - lastDrag.height
                                lastDrag = v.translation
                                bridge?.yaw -= dx * 0.008
                                if let b = bridge { b.pitch = max(0.45, min(1.45, b.pitch + dy * 0.005)) }
                            }
                            .onEnded { _ in lastDrag = .zero })
                        .simultaneousGesture(MagnificationGesture()
                            .onChanged { m in bridge?.dist = max(220, min(900, baseDist / m)) }
                            .onEnded { _ in baseDist = bridge?.dist ?? 430 })
                }
                if let s = rStart { stick(s, rKnob, Color.red) }
                if fp {
                    // fire sits on the left, above the move stick
                    shootButton.position(x: 84, y: g.size.height - 262)
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            fireButton.padding(.trailing, 70).padding(.bottom, 30)
                        }
                    }
                }
            }
            .frame(width: g.size.width, height: g.size.height)
            .simultaneousGesture(RotationGesture()
                .onChanged { a in if !fp { bridge?.yaw = baseYaw + CGFloat(a.radians) } }
                .onEnded { _ in baseYaw = bridge?.yaw ?? 0 })
        }
        .ignoresSafeArea()
    }

    /// big crosshair button: drag it to aim the gun any direction, tap it to aim down sights
    private var fireButton: some View {
        let on = engine.ads || engine.scoped
        return Rectangle().fill(on ? TUI.accent.opacity(0.85) : Color.black.opacity(0.4)).frame(width: 88, height: 88)
            .overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
            .tacBrackets(Color.white.opacity(0.9), len: 12)
            .overlay(Image(systemName: "scope").font(.system(size: 34, weight: .light)).foregroundColor(on ? .black : .white.opacity(0.95)))
            .contentShape(Rectangle().inset(by: -18))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let sens: CGFloat = engine.scoped ? 0.0035 : (engine.ads ? 0.0055 : 0.008)
                    engine.lookDelta += (v.translation.width - crossLast.width) * sens
                    engine.pitch = max(-0.75, min(0.75, engine.pitch - (v.translation.height - crossLast.height) * sens * 0.8))
                    crossLast = v.translation
                    crossMax = max(crossMax, hypot(v.translation.width, v.translation.height))
                }
                .onEnded { _ in
                    if crossMax < 10 {
                        if TWeapons.cls(engine.me.gun) == "sniper" { engine.scoped.toggle(); engine.ads = false } else { engine.ads.toggle(); engine.scoped = false }
                    }
                    crossLast = .zero; crossMax = 0
                })
    }

    /// manual fire, sits higher than the ADS button so the thumb reaches it
    private var shootButton: some View {
        Rectangle().fill(LS.orange.opacity(0.25)).frame(width: 80, height: 80)
            .overlay(Rectangle().stroke(LS.orange, lineWidth: 1.5))
            .tacBrackets(LS.orange, len: 12)
            .overlay(Text("FIRE").font(.jk(15, .heavy)).tracking(1).foregroundColor(.white))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in engine.firing = true }.onEnded { _ in engine.firing = false })
    }

    private func stick(_ base: CGPoint, _ knob: CGPoint, _ c: Color) -> some View {
        let dx = knob.x - base.x, dy = knob.y - base.y
        let d = max(1, hypot(dx, dy))
        let k = min(d, 50)
        return ZStack {
            Circle().stroke(c.opacity(0.35), lineWidth: 2).frame(width: 100, height: 100).position(base)
            Circle().fill(c.opacity(0.35)).frame(width: 46, height: 46).position(x: base.x + dx / d * k, y: base.y + dy / d * k)
        }
        .allowsHitTesting(false)
    }


    @ViewBuilder private var hud: some View {
        fpHud
    }



    // MARK: HUD building blocks

    private func memberCard(_ p: TPlayer?, ally: Bool, me: Int) -> some View {
        let alive = p?.alive ?? false
        let isMe = p?.id == me
        let col: Color = ally ? (isMe ? TUI.green : TUI.blue) : TUI.orange
        let frac: CGFloat = p == nil ? 0 : (ally ? max(0, min(1, p!.hp / 100)) : (alive ? 1 : 0))
        let barCol: Color = ally && frac < 0.35 ? TUI.red : col
        return VStack(spacing: 3) {
            ZStack {
                if let p = p {
                    PortraitAvatar(key: p.handle, size: 30, look: TacAvatar.look(for: p.handle))
                        .drawingGroup()
                        .saturation(alive ? 1 : 0)
                        .opacity(alive ? 1 : 0.5)
                    if !alive { SF("xmark").font(.system(size: 13, weight: .black)).foregroundColor(.white) }
                } else {
                    Rectangle().fill(Color.white.opacity(0.12))
                }
            }
            .frame(width: 30, height: 30)
            .clipShape(Rectangle())
            .overlay(Rectangle().stroke(col.opacity(alive ? 1 : 0.4), lineWidth: 1.5))
            Rectangle().fill(Color.white.opacity(0.16)).frame(width: 30, height: 3)
                .overlay(alignment: .leading) { Rectangle().fill(barCol).frame(width: 30 * frac, height: 3) }
        }
    }

    private func teamCards(_ list: [TPlayer], ally: Bool, me: Int) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<5, id: \.self) { i in memberCard(i < list.count ? list[i] : nil, ally: ally, me: me) }
        }
    }

    private struct KnifeShape: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
            p.move(to: pt(0.34, 0.58)); p.addLine(to: pt(0.92, 0.08)); p.addLine(to: pt(0.66, 0.66)); p.closeSubpath()
            p.move(to: pt(0.1, 0.88)); p.addLine(to: pt(0.2, 0.97)); p.addLine(to: pt(0.46, 0.68)); p.addLine(to: pt(0.34, 0.58)); p.closeSubpath()
            return p
        }
    }

    private func hotCell<C: View>(_ w: CGFloat, on: Bool, _ act: (() -> Void)? = nil, @ViewBuilder _ c: () -> C) -> some View {
        ZStack { c() }
            .frame(width: w, height: 50)
            .background(Rectangle().fill(on ? TUI.accent.opacity(0.2) : Color(red: 0.05, green: 0.055, blue: 0.06).opacity(0.7)))
            .overlay(Rectangle().stroke(on ? TUI.accent : Color.white.opacity(0.18), lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { act?() }
    }

    private func ammoText(_ mag: Int, _ spare: Int, pistol: Bool, reloading: Bool, big: Bool) -> some View {
        Group {
            if reloading {
                Text("RELOAD").font(.jk(big ? 11 : 9, .heavy)).foregroundColor(TUI.gold)
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(mag)").font(.system(size: big ? 17 : 12, weight: .heavy, design: .monospaced)).foregroundColor(mag == 0 ? TUI.red : .white)
                    if !pistol { Text("/\(spare)").font(.jk(big ? 10 : 8, .bold)).foregroundColor(.white.opacity(0.65)) }
                }
            }
        }
    }

    private func gunSlot(_ id: String, mag: Int, spare: Int, reloading: Bool, on: Bool, w: CGFloat, _ act: (() -> Void)?) -> some View {
        let g = TGuns.get(id)
        return hotCell(w, on: on, act) {
            VStack(spacing: 2) {
                Image(uiImage: GunSprites.icon(TWeapons.rig(id))).renderingMode(.template).resizable().scaledToFit()
                    .foregroundColor(on ? .white : .white.opacity(0.6)).frame(width: w - 16, height: on ? 22 : 18)
                ammoText(mag, spare * g.mag, pistol: TWeapons.isPistol(id), reloading: reloading, big: on)
            }
        }
    }

    private func nadeSlot(_ icon: String, _ n: Int, _ act: @escaping () -> Void) -> some View {
        hotCell(32, on: false, act) {
            ZStack(alignment: .bottomTrailing) {
                SF(icon, "circle.fill").font(.system(size: 17, weight: .bold)).foregroundColor(.white.opacity(n == 0 ? 0.3 : 0.95))
                    .frame(width: 32, height: 50)
                Text("\(n)").font(.jk(10, .heavy)).foregroundColor(.black).frame(minWidth: 15, minHeight: 15)
                    .background(Rectangle().fill(n == 0 ? Color.white.opacity(0.4) : TUI.accent)).padding(2)
            }
        }
    }

    private func hotbar(_ e: TacticalEngine) -> some View {
        let me = e.me
        let reloading = me.reloadT > 0
        return VStack(spacing: 5) {
            HStack(spacing: 8) {
                if e.gameMode == 0 {
                    HStack(spacing: 4) {
                        SF("dollarsign.circle.fill").font(.system(size: 12)).foregroundColor(TUI.green)
                        Text("\(me.money)").font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundColor(TUI.green)
                    }
                }
                Spacer(minLength: 0)
                HStack(spacing: 3) {
                    SF("heart.fill").font(.system(size: 10, weight: .bold)).foregroundColor(me.hp < 35 ? TUI.red : .white)
                    Text("\(Int(max(0, me.hp)))").font(.jk(12, .heavy)).foregroundColor(.white)
                    SF("shield.fill").font(.system(size: 10, weight: .bold)).foregroundColor(TUI.blue).padding(.leading, 4)
                    Text("\(Int(max(0, me.armor)))").font(.jk(12, .heavy)).foregroundColor(.white)
                    SF("scope", "circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(TUI.gold).padding(.leading, 4)
                    Text("\(me.kills)").font(.jk(12, .heavy)).foregroundColor(.white)
                }
                .padding(.horizontal, 8).frame(height: 20).background(Rectangle().fill(Color.black.opacity(0.5)))
            }
            HStack(spacing: 3) {
                hotCell(34, on: false) { KnifeShape().fill(Color.white.opacity(0.75)).frame(width: 24, height: 24) }
                gunSlot(me.gun, mag: me.mag, spare: me.spare, reloading: reloading, on: true, w: 78, nil)
                gunSlot(me.altGun, mag: me.altMag, spare: me.altSpare, reloading: false, on: false, w: 54) { e.wantSwap = true }
                nadeSlot("circle.hexagongrid.fill", me.nades) { e.wantNade = true }
                nadeSlot("smoke.fill", me.smokes) { e.wantSmoke = true }
                nadeSlot("sun.max.fill", me.flashes) { e.wantFlash = true }
            }
            VStack(spacing: 3) {
                Rectangle().fill(Color.white.opacity(0.2)).frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { g in
                            Rectangle().fill(me.hp < 35 ? TUI.red : Color.white).frame(width: g.size.width * max(0, min(1, me.hp / 100)), height: 4)
                        }
                    }
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        let fill = max(0, min(1, me.armor / 100 * 3 - CGFloat(i)))
                        Rectangle().fill(Color.white.opacity(0.2)).frame(height: 3)
                            .overlay(alignment: .leading) {
                                GeometryReader { g in Rectangle().fill(TUI.blue).frame(width: g.size.width * fill, height: 3) }
                            }
                    }
                }
            }
        }
        .frame(width: 280)
    }

    private func vbtn(_ icon: String, _ d: CGFloat, on: Bool = false, dim: Bool = false) -> some View {
        SF(icon, "circle.fill").font(.system(size: d * 0.42, weight: .semibold))
            .foregroundColor(on ? .black : .white.opacity(dim ? 0.35 : 0.95))
            .frame(width: d, height: d)
            .background(Rectangle().fill(on ? TUI.accent : Color(red: 0.05, green: 0.055, blue: 0.06).opacity(0.7)))
            .overlay(Rectangle().stroke(on ? Color.white.opacity(0.9) : Color.white.opacity(0.35), lineWidth: 1))
            .tacBrackets(on ? .black.opacity(0.6) : Color.white.opacity(0.7), len: 6)
    }

    private func nadeBubble(_ icon: String, _ n: Int) -> some View {
        ZStack(alignment: .bottomTrailing) {
            SF(icon, "circle.fill").font(.system(size: 19, weight: .bold)).foregroundColor(.white.opacity(n == 0 ? 0.3 : 0.95))
                .frame(width: 48, height: 48)
                .background(Rectangle().fill(Color.black.opacity(0.5)))
                .overlay(Rectangle().stroke(Color.white.opacity(n == 0 ? 0.2 : 0.4), lineWidth: 1))
            Text("\(n)").font(.jk(11, .heavy)).foregroundColor(.black).frame(minWidth: 17, minHeight: 17)
                .background(Rectangle().fill(n == 0 ? Color.white.opacity(0.4) : TUI.accent))
        }
    }

    private func statBar(_ icon: String, _ v: CGFloat, _ col: Color) -> some View {
        HStack(spacing: 7) {
            SF(icon, "circle.fill").font(.system(size: 13, weight: .black)).foregroundColor(col).frame(width: 16)
            Rectangle().fill(Color.white.opacity(0.18)).frame(width: 104, height: 5)
                .overlay(alignment: .leading) { Rectangle().fill(col).frame(width: 104 * max(0, min(1, v / 100)), height: 5) }
            Text("\(Int(max(0, v)))").font(.system(size: 19, weight: .heavy, design: .monospaced)).foregroundColor(.white).frame(width: 36, alignment: .trailing)
        }
    }

    private func togglePill(_ icon: String, _ label: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 5) {
                SF(icon, "circle.fill").font(.system(size: 11, weight: .bold))
                Text(label).font(.jk(10, .heavy))
            }
            .foregroundColor(on ? .black : .white.opacity(0.9)).frame(width: 64, height: 28)
            .background(Rectangle().fill(on ? TUI.accent : Color.black.opacity(0.5)))
            .overlay(Rectangle().stroke(Color.white.opacity(on ? 0.8 : 0.3), lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func actionPill(_ icon: String, _ label: String, _ col: Color) -> some View {
        HStack(spacing: 6) {
            SF(icon, "circle.fill").font(.system(size: 13, weight: .bold))
            Text(label).font(.jk(12, .heavy))
        }
        .foregroundColor(.black).padding(.horizontal, 14).frame(height: 38).background(Rectangle().fill(col))
        .tacBrackets(.black.opacity(0.55), len: 7)
    }

    private var fpHud: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            let e = engine
            let allies = e.players.filter { $0.team == e.me.team }
            let foes = e.players.filter { $0.team != e.me.team }
            let t = Int(max(0, e.timer))
            let g = TGuns.get(e.me.gun)
            let charm = TacSeason.cos(e.charm)
            GeometryReader { geo in
                let W = geo.size.width, H = geo.size.height
                ZStack(alignment: .topLeading) {
                    BodycamGrain(strength: 0.03)
                    BodycamHud(e: e)
                    // top-left: settings; the radar is drawn by the canvas
                    Button { e.paused = true } label: { vbtn("gearshape.fill", 34) }
                        .buttonStyle(TuiPress())
                        .position(x: W - 34, y: 28)
                    if e.gameMode == 6 && e.me.alive {
                        Button { e.raidBagOpen.toggle() } label: {
                            VStack(spacing: 0) {
                                SF("bag.fill", "circle.fill").font(.system(size: 18, weight: .bold))
                                Text("\(e.raidBag.count)/\(TacStash.packCap)").font(.jk(9, .heavy))
                            }
                            .foregroundColor(e.raidBagFull ? TUI.red : .white).frame(width: 46, height: 46).tuiGlass(23, fill: 0.5)
                        }
                        .buttonStyle(TuiPress()).position(x: W - 36, y: 236)
                    }
                    if e.me.alive {
                        Button { e.toggleCover() } label: { vbtn("figure.stand", 44, on: e.me.crouch) }
                            .buttonStyle(TuiPress()).position(x: W - 36, y: H - 96)
                        Button { e.jumpT = max(e.jumpT, 0.55) } label: { vbtn("arrow.up", 44) }
                            .buttonStyle(TuiPress()).position(x: W - 36, y: H - 44)
                        Button { e.wantReload = true } label: { vbtn("arrow.triangle.2.circlepath", 48) }
                            .buttonStyle(TuiPress()).position(x: W - 214, y: H - 40)
                        BodycamAmmo(e: e).position(x: W / 2, y: H - 30)
                    } else {
                        Button { e.fast.toggle() } label: {
                            HStack(spacing: 6) {
                                SF(e.fast ? "play.fill" : "forward.fill", "circle.fill").font(.system(size: 12, weight: .bold))
                                Text(e.fast ? "Normal speed" : "Skip ahead").font(.jk(13, .bold))
                            }
                            .foregroundColor(.white).padding(.horizontal, 14).frame(height: 38).tuiGlass(19, fill: 0.55)
                        }
                        .buttonStyle(TuiPress())
                        .position(x: W / 2, y: H - 40)
                    }

                    if e.gameMode == 0 && e.buyT > 0 && e.me.alive {
                        Button { e.buyOpen.toggle() } label: {
                            HStack(spacing: 6) {
                                SF("cart.fill").font(.system(size: 13, weight: .bold))
                                Text("BUY  \(Int(e.buyT))").font(.jk(13, .heavy))
                            }
                            .foregroundColor(.black).padding(.horizontal, 14).frame(height: 38).background(Rectangle().fill(TUI.green))
                            .tacBrackets(.black.opacity(0.55), len: 7)
                        }
                        .buttonStyle(TuiPress())
                        .position(x: 70, y: H * 0.55)
                    }
                    if e.fxT > 0 && e.fxId != "fx_none" {
                        TacGif(name: e.fxId).id(e.fxSerial)
                            .frame(width: 240, height: 240)
                            .position(x: W / 2, y: H * 0.42)
                            .allowsHitTesting(false)
                    }
                    // bottom-center: contextual
                    HStack(spacing: 10) {
                        if let di = e.nearestDoor() {
                            let closing = TMap.doorWant[di] || TMap.doorOpen[di] > 0.5
                            Button { e.toggleDoor() } label: {
                                actionPill(closing ? "door.left.hand.closed" : "door.left.hand.open", closing ? "CLOSE DOOR" : "OPEN DOOR", TUI.gold)
                            }
                            .buttonStyle(TuiPress())
                        }
                        if e.meInSite || e.meNearBomb {
                            actionPill(e.meInSite ? "timer" : "wrench.and.screwdriver.fill", e.meInSite ? "HOLD PLANT" : "HOLD DEFUSE", TUI.gold)
                                .gesture(DragGesture(minimumDistance: 0).onChanged { _ in e.actHeld = true }.onEnded { _ in e.actHeld = false })
                        }
                    }
                    .position(x: W * 0.5, y: H - 126)
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: pause + results

    private var stateLayer: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { _ in
            ZStack {
                if engine.paused && !engine.over { pauseView }
                if engine.over { overView }
                if !engine.me.alive && !engine.over && !engine.paused {
                    BodycamDown(e: engine) { showLoadout = true; engine.paused = true }
                }
                if engine.gameMode == 6 && !engine.over && engine.me.alive { RaidFX(e: engine) }
                if engine.raidBagOpen && engine.gameMode == 6 && engine.me.alive && !engine.over { RaidBagPanel(e: engine) }
                if showLoadout {
                    CSLoadout(gun: $nav.tacGun, ok: { engine.myGun = nav.tacGun; showLoadout = false; engine.paused = false; engine.last = nil }, battle: {}).background(Color.black.opacity(0.4)).ignoresSafeArea()
                }
            }
        }
    }

    private func settingRow(_ icon: String, _ title: String, _ sub: String, _ on: Bool, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 12) {
                SF(icon, "circle.fill").font(.system(size: 14, weight: .bold)).foregroundColor(on ? .black : .white.opacity(0.8))
                    .frame(width: 34, height: 34).background(Rectangle().fill(on ? TUI.accent : Color.white.opacity(0.12)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.jk(14, .heavy)).foregroundColor(.white)
                    Text(sub).font(.jk(10, .semibold)).foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                ZStack(alignment: on ? .trailing : .leading) {
                    Rectangle().fill(on ? TUI.accent : Color.white.opacity(0.2)).frame(width: 46, height: 24)
                    Rectangle().fill(Color.white).frame(width: 18, height: 18).padding(.horizontal, 3)
                }
            }
            .padding(.horizontal, 12).frame(width: 340, height: 56).tuiGlass(14, fill: 0.35)
        }
        .buttonStyle(TuiPress())
    }

    private var pauseView: some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    SF("pause.circle.fill").font(.system(size: 22)).foregroundColor(TUI.accent)
                    Text("PAUSED").font(.jk(24, .heavy)).tracking(2).foregroundColor(.white)
                }
                .padding(.bottom, 4)
                settingRow("arrow.triangle.2.circlepath", "Flip faces", "Toggle if the world looks inside-out", MXRenderer.flipWinding) { MXRenderer.flipWinding.toggle(); UserDefaults.standard.set(MXRenderer.flipWinding, forKey: "ms.mx.flip") }
                Button { engine.paused = false; engine.last = nil } label: {
                    HStack(spacing: 8) {
                        SF("play.fill").font(.system(size: 14, weight: .bold))
                        Text("RESUME").font(.jk(16, .heavy))
                    }
                    .foregroundColor(.black).frame(width: 340, height: 48).background(Rectangle().fill(TUI.accent)).tacBrackets(.black.opacity(0.5), len: 8)
                }
                .buttonStyle(TuiPress())
                Button { engine.scores = [0, engine.target]; engine.over = true; engine.won = false; engine.paused = false } label: {
                    HStack(spacing: 8) {
                        SF("flag.fill").font(.system(size: 13, weight: .bold))
                        Text("FORFEIT MATCH").font(.jk(13, .heavy))
                    }
                    .foregroundColor(TUI.red).frame(width: 340, height: 42).background(Rectangle().fill(TUI.red.opacity(0.14)))
                    .overlay(Rectangle().stroke(TUI.red.opacity(0.45), lineWidth: 1))
                }
                .buttonStyle(TuiPress())
            }
            .padding(20).tuiGlass(22, fill: 0.7)
        }
    }

    private func resultTile(_ icon: String, _ value: String, _ label: String, _ col: Color) -> some View {
        VStack(spacing: 4) {
            SF(icon, "circle.fill").font(.system(size: 18, weight: .bold)).foregroundColor(col)
            Text(value).font(.system(size: 22, weight: .heavy, design: .monospaced)).foregroundColor(.white)
            Text(label).font(.jk(9, .heavy)).tracking(1.5).foregroundColor(.white.opacity(0.55))
        }
        .frame(width: 108, height: 78).tuiGlass(14, fill: 0.35)
    }

    private var overView: some View {
        let e = engine
        let gems = (e.gameMode == 6 ? e.raidGems : ((e.won ? 25 : 8) + e.kills * 2 + e.scores[0] * 3)) * TacRank.mult(game.s.ex.tac?.prestige ?? 0)
        let xp = 40 + e.kills * 10 + (e.won ? 60 : 0)
        let col = e.won ? TUI.green : TUI.red
        return ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 12) {
                SF(e.won ? "trophy.fill" : "xmark.octagon.fill", "star.fill").font(.system(size: 34)).foregroundColor(col)
                Text(e.gameMode == 6 ? (e.won ? "EXTRACTED" : "K.I.A.") : (e.won ? "VICTORY" : "DEFEAT")).font(.jk(38, .heavy)).tracking(3).foregroundColor(col)
                if e.gameMode == 6 {
                    VStack(spacing: 3) {
                        Text(e.won ? "LOOT SECURED  ·  \(e.raidBag.filter { $0.kind != "intel" }.count) ITEMS  ·  $\(e.bagValue)" : "BAG LOST  ·  \(e.raidBag.count) ITEMS")
                            .font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundColor(.white)
                        Text(e.contractDone ? (e.won ? "CONTRACT COMPLETE  +\(e.contractReward) GEMS" : "CONTRACT COMPLETE (NOT EXTRACTED)") : "CONTRACT: \(e.contractText)")
                            .font(.jk(12, .heavy)).foregroundColor(e.contractDone ? TUI.green : .white.opacity(0.6))
                    }
                } else {
                    HStack(spacing: 14) {
                        Text("\(e.scores[0])").foregroundColor(TUI.blue)
                        Text(":").foregroundColor(.white.opacity(0.5))
                        Text("\(e.rivalScore)").foregroundColor(TUI.orange)
                    }
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                }
                HStack(spacing: 10) {
                    resultTile("scope", "\(e.kills)", "KILLS", TUI.gold)
                    resultTile("diamond.fill", "+\(gems)", "GEMS", TUI.accent)
                    resultTile("star.fill", "+\(xp)", "SEASON XP", TUI.blue)
                }
                Button {
                    guard !collected else { return }
                    collected = true
                    var extra = 0
                    if e.gameMode == 6 { extra = e.raidSold }
                    game.tacticalFinish(won: e.won, kills: e.kills, gems: gems + extra, map: e.mapPick, mode: e.gameMode)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        SF("checkmark.circle.fill").font(.system(size: 15, weight: .bold))
                        Text("COLLECT AND EXIT").font(.jk(15, .heavy))
                    }
                    .foregroundColor(.black).frame(width: 300, height: 50).background(Rectangle().fill(TUI.accent)).tacBrackets(.black.opacity(0.5), len: 8)
                }
                .buttonStyle(TuiPress())
                .padding(.top, 4)
            }
        }
    }
}

extension Game {
    func tacPrestige() {
        var st = s
        var d = st.ex.tac ?? TacData()
        let xp = TacRank.totalXP(d)
        guard TacRank.index(xp) >= TacRank.ranks.count - 1, (d.prestige ?? 0) < TacRank.maxPrestige else { return }
        d.prestige = (d.prestige ?? 0) + 1
        d.xpBase = (d.xpBase ?? 0) + xp
        st.ex.tac = d
        s = st
        _ = TacRank.totalXP(d)
    }

    func tacticalFinish(won: Bool, kills: Int, gems: Int, map: Int = 0, mode: Int = 0) {
        var st = s
        var d = st.ex.tac ?? TacData()
        if won { d.wins += 1; d.rating += 10 } else { d.losses += 1; d.rating = max(0, d.rating - 5) }
        d.kills += kills
        var rec = d.recent ?? []
        rec.insert(TacMatch(won: won, kills: kills, map: map, mode: mode, delta: won ? 10 : -5, date: Date().timeIntervalSince1970), at: 0)
        d.recent = Array(rec.prefix(20))
        let baseXP = 40 + kills * 10 + (won ? 60 : 0)
        d.xpExtra = (d.xpExtra ?? 0) + baseXP * (TacRank.mult(d.prestige ?? 0) - 1)
        var x = d.sx ?? TacSeasonData()
        x.xp += 40 + kills * 10 + (won ? 60 : 0)
        d.sx = x
        st.ex.tac = d
        TacLeague.myRating = d.rating
        st.ex.gems += gems
        s = st
    }
}
