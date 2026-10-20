import SwiftUI
import UIKit

/// Shared map API. Two data sets can be loaded: kind 0 = "The House" (3 floors), kind 1 = "The Woods" (0 bunker, 1 forest, 2 watchtower).
/// Every floor is its own 3000x1800 plane, laid out side by side in world space at x = floor * `off`.
enum TMap {
    static var floorW: CGFloat = 3000
    static var off: CGFloat = 3200
    static let nFloors = 3
    static var W: CGFloat = 3000
    static var H: CGFloat = 1800
    static var look: Int { (kind == 6 || kind == 7) ? 0 : ((kind == 4 || kind == 5) ? 2 : kind) }
    static var totalW: CGFloat { off * 3 }
    static let th: CGFloat = 14
    static let wallH: CGFloat = 80
    static let eyeH: CGFloat = 54

    static var kind = 0
    static var cur: MapData = THouse.shared

    static func floorOf(_ p: CGPoint) -> Int { min(nFloors - 1, max(0, Int(p.x / off))) }
    static func floorOfX(_ x: CGFloat) -> Int { min(nFloors - 1, max(0, Int(x / off))) }
    static func origin(_ fl: Int) -> CGFloat { CGFloat(fl) * off }
    static func aimAtCenter(_ p: CGPoint) -> CGFloat { atan2(H / 2 - p.y, origin(floorOf(p)) + floorW / 2 - p.x) }

    static func propH(_ k: PropKind) -> CGFloat {
        switch k {
        case .bed: return 22
        case .couch: return 34
        case .table: return 29
        case .counter: return 40
        case .crate: return 38
        case .car: return 44
        case .shelf: return 66
        case .barrel: return 34
        case .sandbag: return 18
        case .tv: return 40
        case .plant: return 44
        case .tree: return 210
        case .rock: return 44
        }
    }

    static func propMat(_ k: PropKind) -> WallMat {
        switch k {
        case .counter, .car, .barrel, .sandbag, .tree, .rock: return .concrete
        case .tv: return .glass
        default: return .wood
        }
    }

    static func propHP(_ k: PropKind) -> CGFloat {
        switch k {
        case .crate: return 70
        case .barrel: return 50
        case .shelf: return 90
        case .tv: return 35
        case .plant: return 20
        case .table: return 90
        case .couch: return 140
        case .bed: return 160
        case .counter: return 200
        case .car, .sandbag, .tree, .rock: return -1
        }
    }

    // MARK: forwarded data (current map)

    static var floorNames: [String] { cur.floorNames }
    static var rooms: [TRoom] { cur.rooms }
    static var floorTiles: [TRoom] { cur.floorTiles }
    static var walls: [CGRect] { cur.layout.walls }
    static var wallMats: [WallMat] { cur.layout.mats }
    static var doors: [CGRect] { cur.layout.doors }
    static var props: [TProp] { cur.props }
    static var rugs: [(CGRect, Color)] { [] }
    static var packPos: [CGPoint] { cur.packPos }
    static var stairs: [CGRect] { cur.stairs }
    static var stairLo: [Int] { cur.stairLo }
    static var siteA: CGRect { cur.siteA }
    static var siteB: CGRect { cur.siteB }
    static var atkSpawn: [CGPoint] { cur.atkSpawn }
    static var defSpawn: [CGPoint] { cur.defSpawn }
    static var hubZone: CGRect { cur.hubZone }
    static var lootSpots: [(CGPoint, String)] { cur.loot }
    static var roofs: [CGRect] { cur.roofs }
    static var spawns: [CGPoint] { cur.spawns }

    static func site(_ i: Int) -> CGRect { i == 0 ? siteA : siteB }
    static var siteNames: [String] { cur.siteNames }
    static let mapNames = ["THE HOUSE", "THE WOODS", "WAREHOUSE YARD", "DESERT OUTPOST", "HARBOR COMPLEX", "CUSTOM MAP", "BLOCK 9", "ANNEX"]

    static func roomName(_ p: CGPoint) -> String {
        for r in rooms where r.r.contains(p) { return r.name }
        return kind == 1 ? "Woods" : (kind >= 2 ? "Outside" : "Stairs")
    }

    // MARK: layout (walls from everything that is not walkable)

    static func buildLayout(_ walkRects: [(CGRect, Int)], mats m: [WallMat], doors d: [CGRect]) -> (walls: [CGRect], mats: [WallMat], doors: [CGRect]) {
        let cell: CGFloat = 25
        let cols = Int(W / cell), rows = Int(H / cell)
        var rects: [CGRect] = []
        var mats: [WallMat] = []
        for fl in 0..<3 {
            var blocked = [Bool](repeating: true, count: cols * rows)
            let ox = CGFloat(fl) * off
            for (r, f) in walkRects where f == fl {
                let c0 = max(0, Int((r.minX - ox) / cell)), c1 = min(cols - 1, Int(ceil((r.maxX - ox) / cell)) - 1)
                let r0 = max(0, Int(r.minY / cell)), r1 = min(rows - 1, Int(ceil(r.maxY / cell)) - 1)
                if c0 > c1 || r0 > r1 { continue }
                for c in c0...c1 { for rw in r0...r1 { blocked[rw * cols + c] = false } }
            }
            var active: [String: (c0: Int, c1: Int, r0: Int)] = [:]
            var local: [CGRect] = []
            for rw in 0...rows {
                var cur: [String: (Int, Int)] = [:]
                if rw < rows {
                    var c = 0
                    while c < cols {
                        if blocked[rw * cols + c] {
                            var e = c
                            while e + 1 < cols && blocked[rw * cols + e + 1] { e += 1 }
                            cur["\(c)-\(e)"] = (c, e)
                            c = e + 1
                        } else { c += 1 }
                    }
                }
                for (k, a) in active where cur[k] == nil {
                    local.append(CGRect(x: CGFloat(a.c0) * cell + ox, y: CGFloat(a.r0) * cell, width: CGFloat(a.c1 - a.c0 + 1) * cell, height: CGFloat(rw - a.r0) * cell))
                    active[k] = nil
                }
                for (k, v) in cur where active[k] == nil { active[k] = (v.0, v.1, rw) }
            }
            local.sort { $0.minY != $1.minY ? $0.minY < $1.minY : $0.minX < $1.minX }
            let wm: WallMat = m[fl]
            for w in local {
                let thin = min(w.width, w.height) <= 25.01
                if thin {
                    let horiz = w.width >= w.height
                    let len = horiz ? w.width : w.height
                    let n = max(1, Int((len / 100).rounded()))
                    for i in 0..<n {
                        let a = len * CGFloat(i) / CGFloat(n), b = len * CGFloat(i + 1) / CGFloat(n)
                        rects.append(horiz ? CGRect(x: w.minX + a, y: w.minY, width: b - a, height: w.height) : CGRect(x: w.minX, y: w.minY + a, width: w.width, height: b - a))
                        mats.append(wm)
                    }
                } else {
                    rects.append(w)
                    mats.append(wm)
                }
            }
        }
        return (rects, mats, d)
    }

    // MARK: solids + destruction (state for the loaded map)

    static var origBase: [CGRect] = cur.layout.walls + cur.props.map { $0.r }
    static var baseSolid: [CGRect] = origBase
    static var solid: [CGRect] = origBase + cur.layout.doors
    static var solidKind: [PropKind?] = cur.layout.walls.map { _ -> PropKind? in nil } + cur.props.map { Optional($0.k) } + cur.layout.doors.map { _ -> PropKind? in nil }
    static var solidMat: [WallMat] = cur.layout.mats + cur.props.map { TMap.propMat($0.k) } + cur.layout.doors.map { _ -> WallMat in .wood }
    static var maxHP: [CGFloat] = cur.layout.walls.map { min($0.width, $0.height) <= 25.01 ? 110 : -1 } + cur.props.map { propHP($0.k) }
    static var hp: [CGFloat] = maxHP
    static var broken: [Int] = []          // pending events for the 3D scene
    static var brokenAll: [Int] = []       // everything broken this round (radar overlay)
    static var breaches: [CGRect] = []     // pending events for bot AI
    static var resetTick = 0
    /// solid indices per floor (static by original position) so collision / LOS / bullets only test the current floor
    static var floorIdx: [[Int]] = TMap.makeFloorIdx()
    static let gone = CGRect(x: -9999, y: -9999, width: 1, height: 1)

    static var doorOpen: [CGFloat] = [CGFloat](repeating: 0, count: cur.layout.doors.count)
    static var doorWant: [Bool] = [Bool](repeating: false, count: cur.layout.doors.count)
    static var doorHold: [CGFloat] = [CGFloat](repeating: 0, count: cur.layout.doors.count)

    private static func makeFloorIdx() -> [[Int]] {
        var f: [[Int]] = [[], [], []]
        for (k, r) in (origBase + cur.layout.doors).enumerated() { f[floorOfX(r.midX)].append(k) }
        return f
    }

    /// switches the active map (0 house, 1 woods) and rebuilds every piece of world state that depends on it
    static func load(_ k: Int) {
        if k == kind && !needsApply { return }
        needsApply = false
        kind = k
        W = 3000; floorW = 3000; off = 3200; H = 1800
        _ = THouse.shared
        if k == 4 { W = THarbor.W; floorW = THarbor.W; off = THarbor.W + 200; H = THarbor.W }
        if k == 7 { W = TAnnex.W; floorW = TAnnex.W; H = TAnnex.H }
        switch k {
        case 1: cur = TWoods.shared
        case 2: cur = TWarehouse.shared
        case 3: cur = TDesert.shared
        case 4: cur = THarbor.shared
        case 5: cur = TCustom.shared
        case 6: cur = TApartment.shared
        case 7: cur = TAnnex.shared
        default: cur = THouse.shared
        }
        let d = cur
        origBase = d.layout.walls + d.props.map { $0.r }
        baseSolid = origBase
        solid = origBase + d.layout.doors
        solidKind = d.layout.walls.map { _ -> PropKind? in nil } + d.props.map { Optional($0.k) } + d.layout.doors.map { _ -> PropKind? in nil }
        solidMat = d.layout.mats + d.props.map { TMap.propMat($0.k) } + d.layout.doors.map { _ -> WallMat in .wood }
        maxHP = d.layout.walls.map { min($0.width, $0.height) <= 25.01 && k != 7 ? 110 : -1 } + d.props.map { propHP($0.k) }
        hp = maxHP
        broken = []; brokenAll = []; breaches = []
        floorIdx = makeFloorIdx()
        doorOpen = [CGFloat](repeating: 0, count: d.layout.doors.count)
        doorWant = [Bool](repeating: false, count: d.layout.doors.count)
        doorHold = [CGFloat](repeating: 0, count: d.layout.doors.count)
        resetTick += 1
        stairsReset()
        TGrid.invalidate()
        TNav.reload()
    }
    static var needsApply = false

    static func refreshDoors() {
        let b = baseSolid.count
        for i in doors.indices { solid[b + i] = doorOpen[i] > 0.8 ? gone : doors[i] }
    }

    static func resetDoors() {
        for i in doors.indices { doorOpen[i] = 0; doorWant[i] = false; doorHold[i] = 0 }
        refreshDoors()
    }

    /// applies damage to a destructible solid; true when it just broke
    @discardableResult
    static func hit(_ k: Int, _ amt: CGFloat) -> Bool {
        guard k >= 0, k < hp.count, hp[k] > 0 else { return false }
        hp[k] -= amt
        if hp[k] <= 0 { destroy(k); return true }
        return false
    }

    static func destroy(_ k: Int) {
        guard k < baseSolid.count, baseSolid[k] != gone else { return }
        let r = origBase[k]
        baseSolid[k] = gone
        solid[k] = gone
        hp[k] = 0
        broken.append(k)
        brokenAll.append(k)
        breaches.append(r)
        TNav.refresh(r)
    }

    static func blast(_ c: CGPoint, radius: CGFloat, dmg: CGFloat) {
        stairDamage(near: c, radius: radius, dmg: dmg)
        let fl = floorOf(c)
        for k in 0..<baseSolid.count where hp[k] > 0 {
            let r = baseSolid[k]
            if floorOfX(r.midX) != fl { continue }
            let d = rectDist(r, c)
            if d < radius { hit(k, dmg * (1 - d / radius) + 8) }
        }
    }

    static func resetDestruction() {
        var any = false
        for k in 0..<baseSolid.count where baseSolid[k] == gone { baseSolid[k] = origBase[k]; solid[k] = origBase[k]; any = true }
        hp = maxHP
        broken = []
        brokenAll = []
        breaches = []
        let stairsWere = !stairBrokenAll.isEmpty
        if stairsWere { stairsReset() }
        if any || stairsWere { TNav.rebuild(); resetTick += 1 }
        refreshDoors()
    }

    static func rectDist(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: stairs (plan-space rects, each links floor `stairLo[i]` with `stairLo[i] + 1` at the same spot)

    static func stairRect(_ i: Int, floor: Int) -> CGRect { stairs[i].offsetBy(dx: CGFloat(floor) * off, dy: 0) }

    static func stairAt(_ p: CGPoint) -> (Int, Int)? {
        let st = stairs, lo = stairLo
        for i in st.indices {
            if !stairIntact(i) { continue }
            if stairRect(i, floor: lo[i]).contains(p) { return (i, lo[i]) }
            if stairRect(i, floor: lo[i] + 1).contains(p) { return (i, lo[i] + 1) }
        }
        return nil
    }

    // MARK: queries

    static func los(_ a: CGPoint, _ b: CGPoint) -> Bool {
        if floorOf(a) != floorOf(b) { return crossLink(a, b) }
        var hit = false
        TGrid.forEachSeg(a, b) { k in
            if solidMat[k] != .glass && tSegT(a, b, solid[k]) != nil { hit = true; return true }
            return false
        }
        return !hit
    }

    static func rayDist(_ from: CGPoint, _ ang: CGFloat, _ maxD: CGFloat) -> CGFloat {
        let b = CGPoint(x: from.x + cos(ang) * maxD, y: from.y + sin(ang) * maxD)
        var best: CGFloat = 1
        TGrid.forEachSeg(from, b) { k in
            if solidMat[k] != .glass, let t = tSegT(from, b, solid[k]), t < best { best = t }
            return false
        }
        return maxD * best
    }

    static func push(_ p: inout CGPoint, _ r: CGFloat) {
        let fl = floorOf(p)
        let o = origin(fl)
        p.x = min(max(o + r, p.x), o + W - r)
        p.y = min(max(r, p.y), H - r)
        TGrid.forEachNear(p, r + 2) { k in
            let o = solid[k]
            let cx = min(max(p.x, o.minX), o.maxX)
            let cy = min(max(p.y, o.minY), o.maxY)
            let dx = p.x - cx, dy = p.y - cy
            let d = (dx * dx + dy * dy).squareRoot()
            if d < r {
                if d > 0.001 { p.x += dx / d * (r - d); p.y += dy / d * (r - d) }
                else { p.y -= r }
            }
            return false
        }
        pushRubble(&p, r)
    }

    static func inSolid(_ p: CGPoint) -> Bool {
        var hit = false
        TGrid.forEachNear(p, 1) { k in
            if solid[k].contains(p) { hit = true; return true }
            return false
        }
        return hit
    }
}

// MARK: - Map data

struct MapData {
    var rooms: [TRoom]
    var floorTiles: [TRoom]
    var layout: (walls: [CGRect], mats: [WallMat], doors: [CGRect])
    var props: [TProp]
    var packPos: [CGPoint]
    var stairs: [CGRect]
    var stairLo: [Int]
    var siteA: CGRect
    var siteB: CGRect
    var atkSpawn: [CGPoint]
    var defSpawn: [CGPoint]
    var hubZone: CGRect
    var floorNames: [String]
    var loot: [(CGPoint, String)]
    var roofs: [CGRect]
    var spawns: [CGPoint]
    var siteNames: [String] = ["A · BASEMENT", "B · ATTIC"]
}

/// "The House": three stacked floors (0 basement, 1 ground floor, 2 attic).
enum THouse {
    private static let W: CGFloat = 3000
    private static let H: CGFloat = 1800

    private static func R(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x + CGFloat(fl) * 3200, y: y, width: w, height: h)
    }

    static let rooms: [TRoom] = {
        func r(_ fl: Int, _ n: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ m: Int) -> TRoom {
            TRoom(name: n, r: R(fl, x, y, w, h), mat: m, fl: fl)
        }
        var l: [TRoom] = []
        // basement
        l += [r(0, "Laundry", 200, 150, 700, 500, 5), r(0, "Furnace", 925, 150, 625, 500, 1), r(0, "Wine Cellar", 1575, 150, 625, 500, 4), r(0, "Workshop", 2225, 150, 575, 500, 1),
              r(0, "Cellar Hall", 200, 675, 2600, 225, 1),
              r(0, "Storage", 200, 925, 900, 725, 1), r(0, "Rec Room", 1125, 925, 1125, 725, 2), r(0, "Boiler Room", 2275, 925, 525, 725, 1)]
        // ground floor
        l += [r(1, "Garage", 200, 150, 700, 500, 1), r(1, "Kitchen", 925, 150, 625, 500, 5), r(1, "Dining", 1575, 150, 625, 500, 4), r(1, "Study", 2225, 150, 575, 500, 2),
              r(1, "Main Hall", 200, 675, 2600, 225, 4),
              r(1, "Living Room", 200, 925, 900, 725, 2), r(1, "Foyer", 1125, 925, 550, 725, 3), r(1, "Master Bed", 1700, 925, 550, 725, 2),
              r(1, "Bathroom", 2275, 925, 525, 325, 5), r(1, "Sunroom", 2275, 1275, 525, 375, 3)]
        // attic
        l += [r(2, "Loft", 200, 150, 700, 500, 4), r(2, "Library", 925, 150, 625, 500, 4), r(2, "Gallery", 1575, 150, 625, 500, 4), r(2, "Studio", 2225, 150, 575, 500, 4),
              r(2, "Attic Hall", 200, 675, 2600, 225, 4),
              r(2, "Kids Room", 200, 925, 900, 725, 2), r(2, "Landing", 1125, 925, 550, 725, 4), r(2, "Master Loft", 1700, 925, 1100, 725, 2)]
        return l
    }()

    static let openings: [CGRect] = {
        var o: [CGRect] = []
        for x in [525, 1175, 1825, 2450] as [CGFloat] { o.append(CGRect(x: x, y: 650, width: 100, height: 25)) }
        o.append(CGRect(x: 600, y: 900, width: 100, height: 25))
        o.append(CGRect(x: 1325, y: 900, width: 150, height: 25))
        o.append(CGRect(x: 1925, y: 900, width: 100, height: 25))
        o.append(CGRect(x: 2500, y: 900, width: 100, height: 25))
        for x in [900, 1550, 2200] as [CGFloat] { o.append(CGRect(x: x, y: 450, width: 25, height: 100)) }
        o.append(CGRect(x: 1100, y: 1200, width: 25, height: 100))
        o.append(CGRect(x: 1675, y: 1200, width: 25, height: 100))
        o.append(CGRect(x: 2250, y: 1000, width: 25, height: 100))
        o.append(CGRect(x: 2500, y: 1250, width: 100, height: 25))
        return o
    }()

    static let walkRects: [(CGRect, Int)] = {
        var l: [(CGRect, Int)] = rooms.map { ($0.r, $0.fl) }
        for fl in 0..<3 {
            for o in openings {
                let w = o.offsetBy(dx: CGFloat(fl) * 3200, dy: 0)
                let mid = CGPoint(x: w.midX, y: w.midY)
                if rooms.contains(where: { $0.fl == fl && $0.r.contains(mid) }) { continue }
                l.append((w, fl))
            }
        }
        return l
    }()

    static let floorTiles: [TRoom] = {
        var l = rooms
        for fl in 0..<3 {
            for o in openings {
                let w = o.offsetBy(dx: CGFloat(fl) * 3200, dy: 0)
                let mid = CGPoint(x: w.midX, y: w.midY)
                if rooms.contains(where: { $0.fl == fl && $0.r.contains(mid) }) { continue }
                l.append(TRoom(name: "", r: w, mat: fl == 0 ? 1 : 4, fl: fl))
            }
        }
        return l
    }()

    static let layout: (walls: [CGRect], mats: [WallMat], doors: [CGRect]) = {
        func dh(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat) -> CGRect { CGRect(x: x + CGFloat(fl) * 3200, y: y + 5.5, width: w, height: 14) }
        func dv(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x + 5.5 + CGFloat(fl) * 3200, y: y, width: 14, height: h) }
        let d: [CGRect] = [
            dh(1, 1175, 650, 100), dh(1, 2450, 650, 100), dh(1, 1925, 900, 100), dv(1, 900, 450, 100),
            dh(0, 1175, 650, 100), dh(0, 2450, 650, 100),
            dh(2, 1175, 650, 100), dh(2, 1925, 900, 100)
        ]
        return TMap.buildLayout(walkRects, mats: [.brick, .concrete, .concrete], doors: d)
    }()

    static let props: [TProp] = {
        var l: [TProp] = []
        func p(_ fl: Int, _ k: PropKind, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { l.append(TProp(r: R(fl, x, y, w, h), k: k)) }
        // ---- basement
        p(0, .counter, 400, 160, 250, 45); p(0, .crate, 780, 540, 70, 70); p(0, .barrel, 835, 175, 40, 40); p(0, .barrel, 835, 225, 40, 40); p(0, .crate, 240, 540, 60, 60); p(0, .table, 500, 380, 140, 70)
        p(0, .barrel, 1300, 190, 40, 40); p(0, .barrel, 1350, 190, 40, 40); p(0, .barrel, 1325, 240, 40, 40); p(0, .crate, 1400, 500, 80, 80); p(0, .crate, 1470, 430, 60, 60); p(0, .counter, 1100, 560, 200, 45); p(0, .shelf, 1505, 175, 30, 200)
        p(0, .shelf, 1650, 200, 320, 30); p(0, .shelf, 1650, 330, 320, 30); p(0, .shelf, 1650, 460, 320, 30); p(0, .barrel, 2080, 200, 40, 40); p(0, .barrel, 2080, 260, 40, 40); p(0, .barrel, 2080, 500, 40, 40); p(0, .table, 2000, 380, 100, 60)
        p(0, .counter, 2300, 160, 420, 45); p(0, .crate, 2680, 480, 80, 80); p(0, .crate, 2600, 540, 60, 60); p(0, .table, 2420, 330, 180, 80); p(0, .barrel, 2250, 560, 40, 40)
        p(0, .crate, 230, 690, 50, 50); p(0, .barrel, 2720, 820, 40, 40); p(0, .crate, 1500, 690, 50, 50); p(0, .crate, 900, 830, 50, 50); p(0, .crate, 2100, 690, 50, 50)
        p(0, .crate, 300, 1000, 90, 90); p(0, .crate, 300, 1100, 60, 60); p(0, .crate, 690, 1480, 110, 110); p(0, .crate, 850, 1050, 80, 80); p(0, .crate, 230, 1560, 70, 70); p(0, .shelf, 205, 1250, 30, 250); p(0, .barrel, 560, 1580, 40, 40); p(0, .barrel, 610, 1580, 40, 40)
        p(0, .couch, 1300, 1550, 300, 90); p(0, .tv, 1350, 1622, 200, 25); p(0, .table, 1850, 1420, 260, 130); p(0, .counter, 2150, 1000, 40, 300); p(0, .crate, 1480, 1150, 70, 70); p(0, .crate, 1700, 1300, 80, 80); p(0, .plant, 1140, 945, 32, 32)
        p(0, .barrel, 2420, 1000, 40, 40); p(0, .barrel, 2420, 1050, 40, 40); p(0, .barrel, 2420, 1100, 40, 40); p(0, .crate, 2650, 1500, 100, 100); p(0, .crate, 2500, 1300, 80, 80); p(0, .shelf, 2740, 1000, 30, 300); p(0, .counter, 2400, 1580, 300, 45)
        // ---- ground floor
        p(1, .car, 400, 300, 170, 80); p(1, .shelf, 205, 500, 30, 140); p(1, .crate, 800, 200, 60, 60); p(1, .crate, 700, 540, 70, 70); p(1, .barrel, 840, 580, 40, 40); p(1, .counter, 400, 160, 300, 45)
        p(1, .counter, 1075, 160, 400, 45); p(1, .table, 1150, 360, 260, 80); p(1, .shelf, 1510, 200, 30, 100); p(1, .plant, 1480, 580, 32, 32)
        p(1, .table, 1750, 300, 320, 120); p(1, .shelf, 1590, 175, 30, 150); p(1, .counter, 1750, 160, 300, 45); p(1, .plant, 2150, 580, 32, 32)
        p(1, .shelf, 2400, 160, 370, 35); p(1, .table, 2450, 350, 200, 80); p(1, .couch, 2690, 300, 50, 150); p(1, .plant, 2700, 580, 32, 32)
        p(1, .plant, 215, 690, 32, 32); p(1, .plant, 2750, 690, 32, 32); p(1, .plant, 2750, 840, 32, 32); p(1, .plant, 215, 840, 32, 32); p(1, .table, 700, 690, 160, 40); p(1, .table, 1600, 845, 200, 40)
        p(1, .couch, 320, 1500, 300, 90); p(1, .tv, 320, 1620, 200, 28); p(1, .table, 380, 1370, 160, 70); p(1, .plant, 215, 945, 32, 32); p(1, .shelf, 1040, 950, 40, 200); p(1, .couch, 800, 1400, 100, 100)
        p(1, .table, 1520, 1000, 100, 40); p(1, .plant, 1140, 1600, 32, 32); p(1, .plant, 1630, 1600, 32, 32); p(1, .shelf, 1640, 1000, 30, 150)
        p(1, .bed, 1900, 1450, 220, 130); p(1, .shelf, 2195, 1140, 40, 180); p(1, .couch, 1730, 960, 50, 200); p(1, .plant, 2200, 1600, 32, 32)
        p(1, .counter, 2300, 945, 300, 45); p(1, .plant, 2750, 1200, 32, 32)
        p(1, .plant, 2300, 1360, 32, 32); p(1, .plant, 2740, 1360, 32, 32); p(1, .plant, 2300, 1610, 32, 32); p(1, .couch, 2450, 1560, 260, 80); p(1, .table, 2450, 1400, 160, 70)
        // ---- attic
        p(2, .crate, 250, 500, 90, 90); p(2, .crate, 700, 200, 80, 80); p(2, .shelf, 205, 175, 30, 200); p(2, .bed, 480, 200, 200, 110); p(2, .plant, 850, 580, 32, 32)
        p(2, .shelf, 950, 160, 560, 35); p(2, .shelf, 950, 590, 200, 35); p(2, .table, 1100, 350, 260, 90); p(2, .couch, 1450, 200, 50, 130)
        p(2, .crate, 1650, 300, 80, 80); p(2, .crate, 1900, 450, 100, 100); p(2, .crate, 2050, 200, 70, 70); p(2, .table, 1800, 250, 200, 70); p(2, .plant, 2150, 580, 32, 32)
        p(2, .table, 2500, 300, 180, 70); p(2, .shelf, 2400, 160, 370, 35); p(2, .couch, 2650, 500, 150, 80); p(2, .plant, 2760, 590, 32, 32)
        p(2, .crate, 230, 690, 50, 50); p(2, .crate, 2720, 820, 50, 50); p(2, .crate, 1000, 690, 50, 50)
        p(2, .bed, 250, 1000, 200, 100); p(2, .bed, 250, 1450, 200, 100); p(2, .table, 600, 1400, 160, 90); p(2, .crate, 900, 1500, 100, 100); p(2, .plant, 215, 1610, 32, 32)
        p(2, .shelf, 1500, 950, 150, 35); p(2, .table, 1450, 1500, 150, 80); p(2, .plant, 1140, 1600, 32, 32); p(2, .plant, 1630, 1600, 32, 32)
        p(2, .bed, 1750, 1450, 220, 120); p(2, .crate, 2080, 1150, 80, 80); p(2, .crate, 2250, 1280, 90, 90); p(2, .crate, 2150, 1500, 100, 100); p(2, .shelf, 2740, 950, 35, 250); p(2, .counter, 2400, 1590, 300, 45); p(2, .table, 2500, 1050, 180, 70)
        return l
    }()

    static let packPos: [CGPoint] = [
        CGPoint(x: 1400, y: 790), CGPoint(x: 700, y: 790), CGPoint(x: 2200, y: 790),
        CGPoint(x: 3200 + 1400, y: 790), CGPoint(x: 3200 + 450, y: 1000), CGPoint(x: 3200 + 2000, y: 790),
        CGPoint(x: 6400 + 800, y: 790), CGPoint(x: 6400 + 2000, y: 790)
    ]

    static let stairs: [CGRect] = [
        CGRect(x: 950, y: 175, width: 100, height: 150),
        CGRect(x: 225, y: 175, width: 100, height: 150),
        CGRect(x: 1150, y: 1000, width: 100, height: 160),
        CGRect(x: 2250, y: 175, width: 100, height: 150)
    ]
    static let stairLo: [Int] = [0, 0, 1, 1]

    static let siteA = R(0, 1450, 1100, 350, 300)
    static let siteB = R(2, 2000, 1100, 350, 300)
    static let atkSpawn: [CGPoint] = [CGPoint(x: 3200 + 1220, y: 1560), CGPoint(x: 3200 + 1300, y: 1560), CGPoint(x: 3200 + 1380, y: 1560), CGPoint(x: 3200 + 1460, y: 1560), CGPoint(x: 3200 + 1340, y: 1480)]
    static let defSpawn: [CGPoint] = [CGPoint(x: 3200 + 1650, y: 480), CGPoint(x: 3200 + 1730, y: 480), CGPoint(x: 3200 + 1810, y: 480), CGPoint(x: 3200 + 1890, y: 480), CGPoint(x: 3200 + 1770, y: 560)]
    static let hubZone = R(1, 1100, 700, 400, 200)

    static let shared = MapData(rooms: rooms, floorTiles: floorTiles, layout: layout, props: props, packPos: packPos, stairs: stairs, stairLo: stairLo,
                                siteA: siteA, siteB: siteB, atkSpawn: atkSpawn, defSpawn: defSpawn, hubZone: hubZone,
                                floorNames: ["BASEMENT", "GROUND FLOOR", "ATTIC"], loot: [], roofs: [], spawns: [])
}

// MARK: - The Woods (battle royale): floor 0 = bunker, floor 1 = forest, floor 2 = watchtower deck

private struct MapRNG {
    var s: UInt64
    mutating func next() -> CGFloat {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((s >> 33) & 0xFFFF) / 65535
    }
}

enum TWoods {
    private static let cell: CGFloat = 25
    private static let cols = 120
    private static let rows = 72

    private static func R(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x + CGFloat(fl) * 3200, y: y, width: w, height: h)
    }

    static let shared: MapData = build()

    private static func build() -> MapData {
        var mask = [[Bool]](repeating: [Bool](repeating: false, count: cols * rows), count: 3)
        func setR(_ fl: Int, _ r: CGRect, _ v: Bool) {
            let c0 = max(0, Int(floor(r.minX / cell))), c1 = min(cols - 1, Int(ceil(r.maxX / cell)) - 1)
            let r0 = max(0, Int(floor(r.minY / cell))), r1 = min(rows - 1, Int(ceil(r.maxY / cell)) - 1)
            if c0 > c1 || r0 > r1 { return }
            for c in c0...c1 { for rw in r0...r1 { mask[fl][rw * cols + c] = v } }
        }
        func rc(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x, y: y, width: w, height: h) }

        var rooms: [TRoom] = []
        var tiles: [TRoom] = []
        var doors: [CGRect] = []
        var roofs: [CGRect] = []
        func dh(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat) -> CGRect { CGRect(x: x + CGFloat(fl) * 3200, y: y + 5.5, width: w, height: 14) }
        func dv(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x + 5.5 + CGFloat(fl) * 3200, y: y, width: 14, height: h) }

        // ---------- floor 0: bunker
        let bunker: [(String, CGRect)] = [
            ("Armory", rc(725, 350, 425, 300)), ("Command Room", rc(1175, 350, 650, 300)), ("Generator Room", rc(1850, 350, 425, 300)),
            ("Main Corridor", rc(725, 675, 1550, 150)),
            ("Barracks", rc(725, 850, 425, 300)), ("Storage", rc(1175, 850, 425, 300)), ("Med Bay", rc(1625, 850, 325, 300)), ("Vault", rc(1975, 850, 300, 300))
        ]
        for b in bunker {
            setR(0, b.1, true)
            let t = TRoom(name: b.0, r: R(0, b.1.minX, b.1.minY, b.1.width, b.1.height), mat: 1, fl: 0)
            rooms.append(t)
            tiles.append(t)
        }
        let gaps0: [CGRect] = [rc(900, 650, 100, 25), rc(1450, 650, 100, 25), rc(2025, 650, 100, 25),
                               rc(900, 825, 100, 25), rc(1375, 825, 100, 25), rc(1750, 825, 100, 25), rc(2075, 825, 100, 25),
                               rc(1150, 450, 25, 100), rc(1825, 450, 25, 100), rc(1150, 950, 25, 100), rc(1600, 950, 25, 100), rc(1950, 950, 25, 100)]
        for g in gaps0 {
            setR(0, g, true)
            tiles.append(TRoom(name: "", r: R(0, g.minX, g.minY, g.width, g.height), mat: 1, fl: 0))
        }
        doors += [dh(0, 900, 650, 100), dh(0, 1450, 650, 100), dh(0, 2075, 825, 100)]

        // ---------- floor 2: watchtower deck
        let deck = rc(2450, 250, 400, 400)
        setR(2, deck, true)
        let tower = TRoom(name: "Watchtower", r: R(2, deck.minX, deck.minY, deck.width, deck.height), mat: 4, fl: 2)
        rooms.append(tower)
        tiles.append(tower)

        // ---------- floor 1: forest + cabins
        let arena = rc(150, 100, 2700, 1600)
        setR(1, arena, true)
        let cabins: [(String, CGRect, CGRect, CGRect)] = [
            ("Hunter Cabin", rc(300, 250, 350, 275), rc(325, 275, 300, 225), rc(450, 500, 100, 25)),
            ("Ranger Station", rc(1300, 1275, 450, 300), rc(1325, 1300, 400, 250), rc(1475, 1275, 100, 25)),
            ("Farmhouse", rc(2150, 1100, 450, 325), rc(2175, 1125, 400, 275), rc(2150, 1225, 25, 100)),
            ("Boathouse", rc(250, 1200, 375, 275), rc(275, 1225, 325, 225), rc(600, 1300, 25, 100))
        ]
        var cabinOuters: [CGRect] = []
        for c in cabins {
            setR(1, c.1, false)
            setR(1, c.2, true)
            setR(1, c.3, true)
            cabinOuters.append(c.1)
            let t = TRoom(name: c.0, r: R(1, c.2.minX, c.2.minY, c.2.width, c.2.height), mat: 4, fl: 1)
            rooms.append(t)
            tiles.append(t)
            tiles.append(TRoom(name: "", r: R(1, c.3.minX, c.3.minY, c.3.width, c.3.height), mat: 4, fl: 1))
            roofs.append(R(1, c.1.minX, c.1.minY, c.1.width, c.1.height))
        }
        doors += [dh(1, 450, 500, 100), dh(1, 1475, 1275, 100), dv(1, 2150, 1225, 100), dv(1, 600, 1300, 100)]
        // named outdoor zones (room chip + bot roaming); the big floor tile is first so it renders underneath
        rooms.append(TRoom(name: "Pine Hollow", r: R(1, 150, 100, 1350, 700), mat: 6, fl: 1))
        rooms.append(TRoom(name: "Birch Ridge", r: R(1, 1500, 100, 1350, 700), mat: 6, fl: 1))
        rooms.append(TRoom(name: "Fern Valley", r: R(1, 150, 800, 1350, 900), mat: 6, fl: 1))
        rooms.append(TRoom(name: "Stone Creek", r: R(1, 1500, 800, 1350, 900), mat: 6, fl: 1))
        tiles.insert(TRoom(name: "Woods", r: R(1, arena.minX, arena.minY, arena.width, arena.height), mat: 6, fl: 1), at: 0)

        // ---------- stairs: two bunker hatches in the woods + the watchtower ladder
        let stairs: [CGRect] = [rc(750, 690, 100, 120), rc(2150, 690, 100, 120), rc(2600, 300, 100, 150)]
        let stairLo: [Int] = [0, 0, 1]

        // ---------- walkable rects from the masks
        func maskRects(_ fl: Int) -> [(CGRect, Int)] {
            var out: [(CGRect, Int)] = []
            var active: [Int: (c1: Int, r0: Int)] = [:]
            for rw in 0...rows {
                var curRuns: [Int: Int] = [:]
                if rw < rows {
                    var c = 0
                    while c < cols {
                        if mask[fl][rw * cols + c] {
                            var e = c
                            while e + 1 < cols && mask[fl][rw * cols + e + 1] { e += 1 }
                            curRuns[c] = e
                            c = e + 1
                        } else { c += 1 }
                    }
                }
                for (k, a) in active {
                    if let e = curRuns[k], e == a.c1 { continue }
                    out.append((R(fl, CGFloat(k) * cell, CGFloat(a.r0) * cell, CGFloat(a.c1 - k + 1) * cell, CGFloat(rw - a.r0) * cell), fl))
                    active[k] = nil
                }
                for (k, e) in curRuns where active[k] == nil { active[k] = (e, rw) }
            }
            return out
        }
        let walk: [(CGRect, Int)] = maskRects(0) + maskRects(1) + maskRects(2)
        let layout = TMap.buildLayout(walk, mats: [.brick, .concrete, .concrete], doors: doors)

        // ---------- props
        var props: [TProp] = []
        func p(_ fl: Int, _ k: PropKind, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) { props.append(TProp(r: R(fl, x, y, w, h), k: k)) }
        // bunker
        p(0, .shelf, 750, 360, 380, 28); p(0, .crate, 1080, 560, 60, 60); p(0, .barrel, 745, 590, 36, 36)
        p(0, .table, 1350, 380, 300, 70); p(0, .counter, 1200, 360, 120, 35); p(0, .crate, 1760, 560, 50, 50)
        p(0, .barrel, 1880, 380, 40, 40); p(0, .barrel, 1930, 380, 40, 40); p(0, .barrel, 1880, 430, 40, 40); p(0, .counter, 2100, 360, 150, 40); p(0, .crate, 2200, 570, 60, 60)
        p(0, .sandbag, 1100, 690, 60, 30); p(0, .sandbag, 1620, 780, 60, 30); p(0, .crate, 2050, 700, 40, 40)
        p(0, .bed, 750, 880, 200, 100); p(0, .bed, 750, 1030, 200, 100); p(0, .crate, 1060, 1080, 60, 60)
        p(0, .shelf, 1200, 870, 380, 28); p(0, .shelf, 1200, 1100, 380, 28); p(0, .crate, 1250, 960, 70, 70); p(0, .crate, 1500, 990, 60, 60)
        p(0, .counter, 1650, 870, 200, 40); p(0, .bed, 1650, 1060, 150, 80)
        p(0, .crate, 1900, 960, 60, 60); p(0, .crate, 2200, 1080, 60, 60); p(0, .crate, 2000, 1080, 60, 60)
        // cabins
        p(1, .table, 400, 300, 120, 60); p(1, .crate, 540, 400, 50, 50); p(1, .shelf, 330, 280, 28, 110)
        p(1, .counter, 1340, 1480, 200, 36); p(1, .crate, 1650, 1480, 60, 60); p(1, .table, 1500, 1360, 160, 70)
        p(1, .couch, 2200, 1060, 200, 70); p(1, .table, 2400, 1250, 120, 70); p(1, .crate, 2500, 1320, 50, 50)
        p(1, .crate, 300, 1240, 60, 60); p(1, .shelf, 400, 1110, 90, 28); p(1, .barrel, 380, 1400, 36, 36)
        // tower deck
        p(2, .crate, 2480, 280, 60, 60); p(2, .crate, 2780, 580, 60, 60); p(2, .sandbag, 2500, 560, 80, 30)

        // trees + rocks
        var rng = MapRNG(s: 4242)
        let keepOut: [CGRect] = cabinOuters.map { $0.insetBy(dx: -90, dy: -90) } + stairs.map { $0.insetBy(dx: -80, dy: -80) }
        var trees: [CGRect] = []
        var tries = 0
        while trees.count < 150 && tries < 4000 {
            tries += 1
            let x = 190 + rng.next() * 2620, y = 140 + rng.next() * 1520
            let r = rc(x - 13, y - 13, 26, 26)
            if keepOut.contains(where: { $0.intersects(r) }) { continue }
            if trees.contains(where: { hypot($0.midX - x, $0.midY - y) < 115 }) { continue }
            trees.append(r)
        }
        var rocks: [CGRect] = []
        tries = 0
        while rocks.count < 14 && tries < 2000 {
            tries += 1
            let s = 46 + rng.next() * 34
            let x = 200 + rng.next() * 2600, y = 150 + rng.next() * 1500
            let r = rc(x - s / 2, y - s / 2, s, s * (0.7 + rng.next() * 0.4))
            if keepOut.contains(where: { $0.intersects(r) }) { continue }
            if trees.contains(where: { $0.insetBy(dx: -40, dy: -40).intersects(r) }) { continue }
            if rocks.contains(where: { $0.insetBy(dx: -80, dy: -80).intersects(r) }) { continue }
            rocks.append(r)
        }
        for t in trees { props.append(TProp(r: R(1, t.minX, t.minY, t.width, t.height), k: .tree)) }
        for r in rocks { props.append(TProp(r: R(1, r.minX, r.minY, r.width, r.height), k: .rock)) }

        func freeSpot(_ pt: CGPoint, _ pad: CGFloat) -> Bool {
            let r = rc(pt.x - pad, pt.y - pad, pad * 2, pad * 2)
            if keepOut.contains(where: { $0.intersects(r) }) { return false }
            if trees.contains(where: { $0.insetBy(dx: -pad, dy: -pad).intersects(r) }) { return false }
            if rocks.contains(where: { $0.insetBy(dx: -pad, dy: -pad).intersects(r) }) { return false }
            return true
        }

        // ---------- spawns (20 points on a ring through the forest)
        var spawnPlan: [CGPoint] = []
        var att = 0
        while spawnPlan.count < 20 && att < 1500 {
            att += 1
            let ang = (CGFloat(spawnPlan.count) / 20) * 2 * CGFloat.pi + (rng.next() - 0.5) * 0.22
            let rad = 0.78 + rng.next() * 0.16
            let pt = CGPoint(x: 1500 + cos(ang) * 1250 * rad, y: 900 + sin(ang) * 690 * rad)
            if !freeSpot(pt, 34) { continue }
            spawnPlan.append(pt)
        }
        var fb = 0
        while spawnPlan.count < 20 { spawnPlan.append(CGPoint(x: 260 + CGFloat(fb) * 120, y: 1640)); fb += 1 }
        let spawns = spawnPlan.map { CGPoint(x: $0.x + 3200, y: $0.y) }

        // ---------- loot
        var loot: [(CGPoint, String)] = []
        func L(_ fl: Int, _ x: CGFloat, _ y: CGFloat, _ id: String) { loot.append((CGPoint(x: x + CGFloat(fl) * 3200, y: y), id)) }
        // bunker: best gear
        L(0, 900, 500, "g:ak"); L(0, 1050, 480, "armor:2")
        L(0, 1500, 570, "g:awp"); L(0, 1650, 520, "armor:3")
        L(0, 2050, 520, "g:pump"); L(0, 1950, 560, "med")
        L(0, 1500, 750, "med"); L(0, 1100, 750, "ammo"); L(0, 1900, 750, "ammo")
        L(0, 1050, 1000, "g:m4"); L(0, 850, 1005, "ammo")
        L(0, 1400, 1000, "g:p90"); L(0, 1350, 1060, "nade")
        L(0, 1790, 1000, "med"); L(0, 1850, 950, "med"); L(0, 1700, 970, "armor:1")
        L(0, 2140, 1000, "g:awp"); L(0, 2180, 950, "armor:3"); L(0, 2140, 1100, "g:m4")
        // cabins: mid gear
        L(1, 560, 330, "g:smg"); L(1, 400, 430, "med"); L(1, 580, 460, "armor:1")
        L(1, 1650, 1350, "g:shotgun"); L(1, 1400, 1420, "armor:1"); L(1, 1550, 1500, "ammo")
        L(1, 2500, 1200, "g:rifle"); L(1, 2300, 1360, "med"); L(1, 2500, 1160, "nade")
        L(1, 330, 1350, "g:mp7"); L(1, 450, 1350, "med"); L(1, 520, 1300, "ammo")
        // tower
        L(2, 2650, 520, "g:awp"); L(2, 2760, 380, "ammo")
        // scattered in the woods
        let scatter = ["g:pistol", "g:pistol", "g:pistol", "g:eagle", "g:eagle", "med", "med", "med", "med", "med", "med", "ammo", "ammo", "ammo", "ammo", "ammo", "ammo", "ammo", "ammo",
                       "nade", "nade", "nade", "nade", "nade", "armor:1", "armor:1", "armor:1", "armor:1", "g:smg", "g:smg", "g:shotgun", "g:shotgun", "g:mp7", "g:rifle"]
        for id in scatter {
            var tries2 = 0
            while tries2 < 200 {
                tries2 += 1
                let pt = CGPoint(x: 220 + rng.next() * 2560, y: 160 + rng.next() * 1480)
                if freeSpot(pt, 22) { L(1, pt.x, pt.y, id); break }
            }
        }

        return MapData(rooms: rooms, floorTiles: tiles, layout: layout, props: props, packPos: [], stairs: stairs, stairLo: stairLo,
                       siteA: R(0, 1975, 850, 300, 300), siteB: R(0, 1175, 350, 650, 300),
                       atkSpawn: Array(spawns[0..<5]), defSpawn: Array(spawns[5..<10]), hubZone: R(1, 1300, 800, 400, 200),
                       floorNames: ["BUNKER", "WOODS", "WATCHTOWER"], loot: loot, roofs: roofs, spawns: spawns)
    }
}
