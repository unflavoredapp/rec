import SwiftUI
import UIKit

// MARK: - stairwells: cross-floor sight and fire, collapse, falling through the hole

extension TMap {
    static var stairHP: [CGFloat] = []
    static var stairDown: [Bool] = []
    static var stairBroken: [Int] = []       // collapse events for the 3D scene
    static var stairBrokenAll: [Int] = []
    static let stairMaxHP: CGFloat = 140

    static func stairsReset() {
        stairHP = [CGFloat](repeating: stairMaxHP, count: stairs.count)
        stairDown = [Bool](repeating: false, count: stairs.count)
        stairBroken = []
        stairBrokenAll = []
    }

    /// the annex uses continuous stairs: one straight run, near (foot) end at the rect's maxY, head at minY
    static var smooth: Bool { kind == 7 }
    static let riseH: CGFloat = 82
    static let stairSteps: CGFloat = 14

    /// 0 at the foot of the run, 1 at the head
    static func stairT(_ i: Int, _ p: CGPoint) -> CGFloat {
        let r = stairs[i], y = planOf(p).y
        return min(1, max(0, (r.maxY - y) / max(1, r.height)))
    }

    /// vertical offset of the eye against the floor the point stands on, nil when not on a staircase.
    /// Ground floor: 0...riseH going up. Upper floor: -riseH...0. Both agree at the hand-over point, so the climb never jumps.
    static func stairLift(_ p: CGPoint) -> CGFloat? {
        guard smooth, let s = stairAt(p) else { return nil }
        let n = stairSteps
        let t = stairT(s.0, p) * n
        let k = min(n - 1, floor(t))
        let f = t - k
        let h = (k + f * f * (3 - 2 * f)) * riseH / n
        return s.1 == stairLo[s.0] ? h : h - riseH
    }

    static func stairIntact(_ i: Int) -> Bool { i < stairDown.count ? !stairDown[i] : true }

    static func planOf(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - origin(floorOf(p)), y: p.y) }

    static func pdist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let pa = planOf(a), pb = planOf(b)
        return hypot(pa.x - pb.x, pa.y - pb.y)
    }

    static func pang(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let pa = planOf(a), pb = planOf(b)
        return atan2(pb.y - pa.y, pb.x - pa.x)
    }

    private static func segRect(_ a: CGPoint, _ b: CGPoint, _ r: CGRect) -> (CGFloat, CGFloat)? {
        var t0: CGFloat = 0, t1: CGFloat = 1
        let d = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let axes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(a.x, d.x, r.minX, r.maxX), (a.y, d.y, r.minY, r.maxY)]
        for (p0, dd, mn, mx) in axes {
            if abs(dd) < 0.000001 {
                if p0 < mn || p0 > mx { return nil }
            } else {
                var ta = (mn - p0) / dd, tb = (mx - p0) / dd
                if ta > tb { swap(&ta, &tb) }
                t0 = max(t0, ta)
                t1 = min(t1, tb)
                if t0 > t1 { return nil }
            }
        }
        return (t0, t1)
    }

    /// two points on neighbouring floors can see each other through a stairwell opening
    static func crossLink(_ a: CGPoint, _ b: CGPoint) -> Bool {
        let fa = floorOf(a), fb = floorOf(b)
        guard abs(fa - fb) == 1 else { return false }
        let lo = min(fa, fb)
        let pa = planOf(a), pb = planOf(b)
        for i in stairs.indices where stairLo[i] == lo {
            guard let (t0, t1) = segRect(pa, pb, stairs[i]) else { continue }
            let tm = (t0 + t1) / 2
            let mx = pa.x + (pb.x - pa.x) * tm, my = pa.y + (pb.y - pa.y) * tm
            let ma = CGPoint(x: mx + origin(fa), y: my)
            let mb = CGPoint(x: mx + origin(fb), y: my)
            if los(a, ma) && los(mb, b) { return true }
        }
        return false
    }

    /// shift to apply to a bullet that is over a stair opening and was aimed at the neighbouring floor `tf`
    static func hopShift(_ p: CGPoint, to tf: Int) -> CGFloat? {
        let fl = floorOf(p)
        guard abs(fl - tf) == 1 else { return nil }
        let lo = min(fl, tf)
        for i in stairs.indices where stairLo[i] == lo && stairRect(i, floor: fl).contains(p) { return CGFloat(tf - fl) * off }
        return nil
    }

    static func stairDamage(near c: CGPoint, radius: CGFloat, dmg: CGFloat) {
        if stairHP.count != stairs.count { stairsReset() }
        let fl = floorOf(c)
        for i in stairs.indices where stairIntact(i) {
            let lo = stairLo[i]
            guard fl == lo || fl == lo + 1 else { continue }
            let d = rectDist(stairRect(i, floor: fl), c)
            guard d < radius else { continue }
            stairHP[i] -= dmg * (1 - d / radius) + 8
            if stairHP[i] <= 0 { collapse(i) }
        }
    }

    static func collapse(_ i: Int) {
        guard i < stairDown.count, !stairDown[i] else { return }
        stairDown[i] = true
        stairBroken.append(i)
        stairBrokenAll.append(i)
        let lo = stairLo[i]
        breaches.append(stairRect(i, floor: lo))
        TNav.refresh(stairRect(i, floor: lo))
        TNav.refresh(stairRect(i, floor: lo + 1))
    }

    /// destroyed stairs: the rubble below and the open hole above are not walkable
    static func stairBlocked(_ p: CGPoint) -> Bool {
        for i in stairs.indices where i < stairDown.count && stairDown[i] {
            let lo = stairLo[i]
            if stairRect(i, floor: lo).insetBy(dx: -18, dy: -18).contains(p) { return true }
            if stairRect(i, floor: lo + 1).insetBy(dx: -6, dy: -6).contains(p) { return true }
        }
        return false
    }

    /// standing over the open hole of a destroyed staircase on the upper floor
    static func holeAt(_ p: CGPoint) -> Int? {
        for i in stairs.indices where i < stairDown.count && stairDown[i] {
            if floorOf(p) == stairLo[i] + 1 && stairRect(i, floor: stairLo[i] + 1).insetBy(dx: 10, dy: 10).contains(p) { return i }
        }
        return nil
    }

    /// pushes a point out of rubble on its own floor
    static func pushRubble(_ p: inout CGPoint, _ r: CGFloat) {
        let fl = floorOf(p)
        for i in stairs.indices where i < stairDown.count && stairDown[i] && stairLo[i] == fl {
            let o = stairRect(i, floor: fl)
            let cx = min(max(p.x, o.minX), o.maxX)
            let cy = min(max(p.y, o.minY), o.maxY)
            let dx = p.x - cx, dy = p.y - cy
            let d = (dx * dx + dy * dy).squareRoot()
            if d < r {
                if d > 0.001 { p.x += dx / d * (r - d); p.y += dy / d * (r - d) }
                else { p.y = o.maxY + r }
            }
        }
    }

    /// a crouching spot on the upper floor from which a bot can watch the stairs and the floor below
    static func ambushSpot(_ i: Int) -> (CGPoint, CGFloat)? {
        guard i < stairs.count else { return nil }
        let loF = stairLo[i], hiF = loF + 1
        let r = stairs[i]
        let center = CGPoint(x: r.midX + origin(hiF), y: r.midY)
        let probes: [CGPoint] = [
            CGPoint(x: r.midX + origin(loF), y: r.maxY + 150),
            CGPoint(x: r.midX + origin(loF), y: r.minY - 150),
            CGPoint(x: r.maxX + 150 + origin(loF), y: r.midY),
            CGPoint(x: r.minX - 150 + origin(loF), y: r.midY)
        ]
        let offs: [CGPoint] = [
            CGPoint(x: r.midX, y: r.minY - 50), CGPoint(x: r.midX, y: r.maxY + 50),
            CGPoint(x: r.maxX + 50, y: r.midY), CGPoint(x: r.minX - 50, y: r.midY),
            CGPoint(x: r.maxX + 45, y: r.minY - 45), CGPoint(x: r.minX - 45, y: r.minY - 45),
            CGPoint(x: r.maxX + 45, y: r.maxY + 45), CGPoint(x: r.minX - 45, y: r.maxY + 45)
        ]
        var best: CGPoint? = nil
        var bestScore = 0
        for o in offs {
            let c = CGPoint(x: o.x + origin(hiF), y: o.y)
            if TNav.blocked[TNav.idx(c)] || inSolid(c) { continue }
            if !los(c, center) { continue }
            var score = 0
            for (k, pr) in probes.enumerated() where crossLink(c, pr) { score += k == 0 ? 3 : 1 }
            if score > bestScore { bestScore = score; best = c }
        }
        guard let c = best else { return nil }
        let pc = planOf(c)
        return (c, atan2(r.midY - pc.y, r.midX - pc.x))
    }
}

extension TacticalEngine {
    func shootTargetFloor(_ p: TPlayer) -> Int {
        let own = TMap.floorOf(p.pos)
        let tid = p.isPlayer ? autoTarget : p.targetID
        guard tid >= 0, let t = players.first(where: { $0.id == tid }), t.alive else { return -1 }
        let tf = TMap.floorOf(t.pos)
        return tf != own ? tf : -1
    }

    /// some bots crouch at the top of a staircase and watch it
    func assignAmbush() {
        for p in players { p.ambush = -1 }
        guard !TMap.stairs.isEmpty else { return }
        var used = Set<Int>()
        for b in players.filter({ !$0.isPlayer }).shuffled() {
            if b.watchDoor { continue }
            let chance: Int = gameMode == 6 ? (b.faction == 1 ? 90 : 0) : (gameMode == 7 ? 0 : 22)
            guard Int.random(in: 0..<100) < chance else { continue }
            var order = Array(TMap.stairs.indices).filter { !used.contains($0) && TMap.stairIntact($0) }
            if gameMode == 6 {
                order = order.filter { TMap.pdist(b.pos, CGPoint(x: TMap.stairs[$0].midX + TMap.origin(TMap.stairLo[$0] + 1), y: TMap.stairs[$0].midY)) < 1400 }
            }
            order.shuffle()
            for i in order {
                if let (spot, aim) = TMap.ambushSpot(i) {
                    b.ambush = i
                    b.ambushPos = spot
                    b.ambushAim = aim
                    used.insert(i)
                    break
                }
            }
        }
    }
}

// MARK: - spread-out spawns

extension TMap {
    private static var reachCache: (Int, [Bool])? = nil

    private static func reachable() -> [Bool] {
        if let c = reachCache, c.0 == kind { return c.1 }
        var seen = [Bool](repeating: false, count: TNav.cols * TNav.rows)
        var q: [Int] = []
        var seeds: [CGPoint] = atkSpawn + defSpawn + spawns
        for i in stairs.indices {
            for f in [stairLo[i], stairLo[i] + 1] {
                let r = stairRect(i, floor: f)
                seeds.append(CGPoint(x: r.midX, y: r.midY))
            }
        }
        for s in seeds {
            let i = TNav.nearestFree(TNav.idx(s))
            if !TNav.blocked[i] && !seen[i] { seen[i] = true; q.append(i) }
        }
        var h = 0
        while h < q.count {
            let i = q[h]; h += 1
            let c = i % TNav.cols, r = i / TNav.cols
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nc = c + dc, nr = r + dr
                if nc < 0 || nr < 0 || nc >= TNav.cols || nr >= TNav.rows { continue }
                let j = nr * TNav.cols + nc
                if !seen[j] && !TNav.blocked[j] { seen[j] = true; q.append(j) }
            }
        }
        reachCache = (kind, seen)
        return seen
    }

    /// n walkable points scattered over the whole map (and all floors), each at least `sep` from the others
    static func spreadPoints(_ n: Int, sep: CGFloat, avoid: [CGPoint] = [], avoidDist: CGFloat = 0) -> [CGPoint] {
        let ok = reachable()
        var cells: [Int] = []
        for i in 0..<ok.count where ok[i] && !TNav.blocked[i] { cells.append(i) }
        cells.shuffle()
        var out: [CGPoint] = []
        var s = sep
        while out.count < n && s > 60 {
            for i in cells {
                let c = TNav.center(i)
                if stairAt(c) != nil { continue }
                if out.contains(where: { hypot($0.x - c.x, $0.y - c.y) < s }) { continue }
                if avoid.contains(where: { hypot($0.x - c.x, $0.y - c.y) < avoidDist }) { continue }
                out.append(c)
                if out.count >= n { break }
            }
            s *= 0.7
        }
        return out
    }
}
