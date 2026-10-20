import SwiftUI
import UIKit

// MARK: - spatial grid over every solid (walls, props, doors) + allocation-free segment test

@inline(__always)
func tSegT(_ a: CGPoint, _ b: CGPoint, _ r: CGRect) -> CGFloat? {
    var t0: CGFloat = 0
    var t1: CGFloat = 1
    let dx = b.x - a.x, dy = b.y - a.y
    if abs(dx) < 1e-9 {
        if a.x < r.minX || a.x > r.maxX { return nil }
    } else {
        var ta = (r.minX - a.x) / dx, tb = (r.maxX - a.x) / dx
        if ta > tb { swap(&ta, &tb) }
        if ta > t0 { t0 = ta }
        if tb < t1 { t1 = tb }
        if t0 > t1 { return nil }
    }
    if abs(dy) < 1e-9 {
        if a.y < r.minY || a.y > r.maxY { return nil }
    } else {
        var ta = (r.minY - a.y) / dy, tb = (r.maxY - a.y) / dy
        if ta > tb { swap(&ta, &tb) }
        if ta > t0 { t0 = ta }
        if tb < t1 { t1 = tb }
        if t0 > t1 { return nil }
    }
    return t0
}

enum TGrid {
    static let cs: CGFloat = 200
    private static var gc = 1
    private static var gr = 1
    private static var cells: [[Int32]] = []
    private static var stamp: [UInt32] = []
    private static var gen: UInt32 = 0
    static var ready = false

    /// call when the map changes
    static func invalidate() { ready = false }

    static func build() {
        let all = TMap.origBase + TMap.cur.layout.doors
        gc = Int(TMap.totalW / cs) + 2
        gr = Int(TMap.H / cs) + 2
        cells = [[Int32]](repeating: [], count: gc * gr)
        stamp = [UInt32](repeating: 0, count: all.count + 8)
        gen = 0
        for (k, r) in all.enumerated() {
            let q = r.insetBy(dx: -20, dy: -20)
            let c0 = max(0, min(gc - 1, Int(q.minX / cs))), c1 = max(0, min(gc - 1, Int(q.maxX / cs)))
            let r0 = max(0, min(gr - 1, Int(q.minY / cs))), r1 = max(0, min(gr - 1, Int(q.maxY / cs)))
            for cx in c0...c1 { for cy in r0...r1 { cells[cy * gc + cx].append(Int32(k)) } }
        }
        ready = true
    }

    @inline(__always) private static func next() -> UInt32 {
        gen &+= 1
        if gen == 0 { for i in stamp.indices { stamp[i] = 0 }; gen = 1 }
        return gen
    }

    /// visits every solid whose cell lies on the segment a-b; the body returns true to stop early
    static func forEachSeg(_ a: CGPoint, _ b: CGPoint, _ body: (Int) -> Bool) {
        if !ready { build() }
        let g = next()
        var x = max(0, min(gc - 1, Int(a.x / cs))), y = max(0, min(gr - 1, Int(a.y / cs)))
        let ex = max(0, min(gc - 1, Int(b.x / cs))), ey = max(0, min(gr - 1, Int(b.y / cs)))
        let dx = b.x - a.x, dy = b.y - a.y
        let sx = dx > 0 ? 1 : -1, sy = dy > 0 ? 1 : -1
        let inf = CGFloat.greatestFiniteMagnitude
        var tx = abs(dx) < 1e-9 ? inf : ((dx > 0 ? CGFloat(x + 1) * cs : CGFloat(x) * cs) - a.x) / dx
        var ty = abs(dy) < 1e-9 ? inf : ((dy > 0 ? CGFloat(y + 1) * cs : CGFloat(y) * cs) - a.y) / dy
        let ddx = abs(dx) < 1e-9 ? inf : cs / abs(dx)
        let ddy = abs(dy) < 1e-9 ? inf : cs / abs(dy)
        var steps = 0
        let cap = abs(ex - x) + abs(ey - y) + 2
        while steps <= cap {
            for k32 in cells[y * gc + x] {
                let k = Int(k32)
                if stamp[k] == g { continue }
                stamp[k] = g
                if body(k) { return }
            }
            if x == ex && y == ey { break }
            if tx < ty { x += sx; tx += ddx } else { y += sy; ty += ddy }
            if x < 0 || y < 0 || x >= gc || y >= gr { break }
            steps += 1
        }
    }

    /// visits solids whose cells overlap the box p +- r; the body returns true to stop early
    static func forEachNear(_ p: CGPoint, _ r: CGFloat, _ body: (Int) -> Bool) {
        if !ready { build() }
        let g = next()
        let c0 = max(0, min(gc - 1, Int((p.x - r) / cs))), c1 = max(0, min(gc - 1, Int((p.x + r) / cs)))
        let r0 = max(0, min(gr - 1, Int((p.y - r) / cs))), r1 = max(0, min(gr - 1, Int((p.y + r) / cs)))
        for cx in c0...c1 {
            for cy in r0...r1 {
                for k32 in cells[cy * gc + cx] {
                    let k = Int(k32)
                    if stamp[k] == g { continue }
                    stamp[k] = g
                    if body(k) { return }
                }
            }
        }
    }
}
