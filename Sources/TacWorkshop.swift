import SwiftUI
import UIKit

// MARK: - Workshop data (sprite guns + tile maps)

struct WSGun: Codable, Identifiable {
    var id: String
    var name: String
    var base: String
    var px: String
}

struct WSMap: Codable, Identifiable {
    var id: String
    var name: String
    var cells: String
    var desc: String
}

enum TWorkshop {
    static let gw = 32, gh = 14
    static let mw = 36, mh = 20
    static let defPal = ["1c1c20", "4a4d55", "8d939e", "d8dce4", "7a4a26", "b98a52", "2f5a2a", "7fb04a", "a02a2a", "e0453a", "e8a21a", "f5e050", "1f4f9a", "4aa3e0", "ffffff"]
    private static let ud = UserDefaults.standard

    static var pal: [String] {
        get { let a = ud.stringArray(forKey: "ws.pal") ?? []; return a.count == 15 ? a : defPal }
        set { ud.set(newValue, forKey: "ws.pal") }
    }

    static func rgb(_ h: String) -> (Double, Double, Double) {
        let v = UInt32(h, radix: 16) ?? 0x888888
        return (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
    }

    static func hexColor(_ h: String) -> Color {
        let c = rgb(h)
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    static func hexOf(_ c: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
    }

    // MARK: guns (named slots, one equipped per base gun)

    static func newId() -> String { UUID().uuidString }

    static var guns: [WSGun] {
        get {
            guard let d = ud.data(forKey: "ws.guns"), let a = try? JSONDecoder().decode([WSGun].self, from: d) else { return [] }
            return a
        }
        set { if let d = try? JSONEncoder().encode(newValue) { ud.set(d, forKey: "ws.guns") } }
    }

    static var maps: [WSMap] {
        get {
            if let d = ud.data(forKey: "ws.maps"), let a = try? JSONDecoder().decode([WSMap].self, from: d), !a.isEmpty { return a }
            return [WSMap(id: newId(), name: "Harbor Base", cells: cellsString(defaultMap()), desc: "A custom harbor map with multiple routes, cover and close quarters combat.")]
        }
        set { if let d = try? JSONEncoder().encode(newValue) { ud.set(d, forKey: "ws.maps") } }
    }

    static var mapSel: String {
        get { ud.string(forKey: "ws.mapSel") ?? "" }
        set { ud.set(newValue, forKey: "ws.mapSel") }
    }

    static var currentMap: WSMap {
        let m = maps
        return m.first(where: { $0.id == mapSel }) ?? m[0]
    }

    static func equippedId(_ base: String) -> String? { ud.string(forKey: "ws.eq." + base) }
    static func setEquipped(_ base: String, _ id: String?) {
        if let id = id { ud.set(id, forKey: "ws.eq." + base) } else { ud.removeObject(forKey: "ws.eq." + base) }
    }

    static func pxArray(_ s: String) -> [UInt8] {
        var a = [UInt8](repeating: 0, count: gw * gh)
        for (i, ch) in s.enumerated() where i < a.count { a[i] = UInt8(String(ch), radix: 16) ?? 0 }
        return a
    }

    static func pxString(_ a: [UInt8]) -> String { a.map { String($0, radix: 16) }.joined() }

    static func sprite(_ base: String) -> [UInt8] {
        guard let id = equippedId(base), let g = guns.first(where: { $0.id == id }) else { return [UInt8](repeating: 0, count: gw * gh) }
        return pxArray(g.px)
    }

    /// ready-to-edit rifle so a new gun never starts as an empty grid
    static func starter() -> [UInt8] {
        var a = [UInt8](repeating: 0, count: gw * gh)
        func box(_ c0: Int, _ r0: Int, _ c1: Int, _ r1: Int, _ v: UInt8) {
            for r in r0...r1 { for c in c0...c1 where c >= 0 && c < gw && r >= 0 && r < gh { a[r * gw + c] = v } }
        }
        box(0, 5, 5, 9, 5)
        box(0, 5, 1, 9, 1)
        box(6, 4, 17, 8, 2)
        box(6, 4, 17, 4, 3)
        box(7, 2, 16, 3, 1)
        box(11, 1, 12, 1, 1)
        box(18, 5, 25, 7, 2)
        box(18, 5, 25, 5, 3)
        box(26, 6, 31, 6, 3)
        box(29, 5, 31, 7, 1)
        box(9, 9, 11, 11, 1)
        box(8, 12, 10, 12, 1)
        box(14, 9, 16, 12, 2)
        box(14, 12, 16, 12, 1)
        return a
    }

    typealias Rect = (x: Int, y: Int, w: Int, h: Int, c: Int)

    /// greedy rectangle merge so a sprite becomes the fewest boxes
    static func rects(_ sp: [UInt8]) -> [Rect] {
        var used = [Bool](repeating: false, count: sp.count)
        var out: [Rect] = []
        for y in 0..<gh {
            for x in 0..<gw {
                let c = sp[y * gw + x]
                if c == 0 || used[y * gw + x] { continue }
                var w = 1
                while x + w < gw && sp[y * gw + x + w] == c && !used[y * gw + x + w] { w += 1 }
                var h = 1
                outer: while y + h < gh {
                    for k in 0..<w where sp[(y + h) * gw + x + k] != c || used[(y + h) * gw + x + k] { break outer }
                    h += 1
                }
                for yy in y..<(y + h) { for xx in x..<(x + w) { used[yy * gw + xx] = true } }
                out.append((x, y, w, h, Int(c)))
            }
        }
        return out
    }

    /// called by TwGunLib.load(): registers palette materials and swaps sprite guns into the rigs
    static func inject() {
        // pixel-art guns do not belong in a bodycam game: keep the real gun models
        if TBody.on { return }
        guard var rs = TwGunLib.rigs else { return }
        let p = pal
        for i in 1...15 {
            let c = rgb(p[i - 1])
            TwGunLib.defs["cg\(i)"] = ["c": [c.0, c.1, c.2], "sp": 0.3, "sh": 0.3, "rf": 0.0, "a": 1.0] as [String: Any]
        }
        let arm: Set<String> = ["glove", "sleeve", "sleeveDark", "knuckle", "strap", "skin", "nail"]
        for (gid, any) in rs {
            let sp = sprite(gid)
            if !sp.contains(where: { $0 != 0 }) { continue }
            guard var rig = any as? [String: Any] else { continue }
            let rs2 = rects(sp)
            // first-person: barrel along -z
            let parts = (rig["parts"] as? [[String: Any]]) ?? []
            var keep = parts.filter { arm.contains(($0["m"] as? String) ?? "") }
            let body = parts.filter { !arm.contains(($0["m"] as? String) ?? "") }
            var x0 = 1e9, x1 = -1e9, y1 = -1e9, z0 = 1e9, z1 = -1e9
            for q in body {
                guard let pos = q["p"] as? [Double], let s = q["s"] as? [Double], pos.count == 3, s.count == 3 else { continue }
                x0 = min(x0, pos[0] - s[0] / 2); x1 = max(x1, pos[0] + s[0] / 2)
                y1 = max(y1, pos[1] + s[1] / 2)
                z0 = min(z0, pos[2] - s[2] / 2); z1 = max(z1, pos[2] + s[2] / 2)
            }
            if let m = rig["muzzle"] as? [Double], m.count == 3 { z0 = min(z0, m[2]) }
            if x1 < x0 || z1 <= z0 { continue }
            let cl = (z1 - z0) / Double(gw)
            let th = min(5.0, max(2.0, cl * 1.4))
            let cx = (x0 + x1) / 2
            let top = y1 + 3 * cl
            for r in rs2 {
                let z = z1 - (Double(r.x) + Double(r.w) / 2) * cl
                let y = top - (Double(r.y) + Double(r.h) / 2) * cl
                keep.append(["t": "box", "m": "cg\(r.c)", "p": [cx, y, z], "q": [0.0, 0.0, 0.0, 1.0], "s": [th, Double(r.h) * cl, Double(r.w) * cl], "c": 0.0])
            }
            rig["parts"] = keep
            // world model: +x forward
            if var w = rig["w"] as? [String: Any], let wp = w["parts"] as? [[String: Any]] {
                var a0 = 1e9, a1 = -1e9, b1 = -1e9
                for q in wp {
                    guard let pos = q["p"] as? [Double], let s = q["s"] as? [Double], let qq = q["q"] as? [Double], pos.count == 3, s.count == 3, qq.count == 4 else { continue }
                    let ex = abs(qq[1]) > 0.5 ? s[2] : s[0]
                    a0 = min(a0, pos[0] - ex / 2); a1 = max(a1, pos[0] + ex / 2)
                    b1 = max(b1, pos[1] + s[1] / 2)
                }
                if a1 > a0 {
                    a1 = max(a1, (w["mx"] as? Double) ?? a1)
                    let wl = (a1 - a0) / Double(gw)
                    let wt = min(2.2, max(0.7, wl * 1.4))
                    let wtop = b1 + 3 * wl
                    var np: [[String: Any]] = []
                    for r in rs2 {
                        np.append(["t": "box", "m": "cg\(r.c)", "p": [a0 + (Double(r.x) + Double(r.w) / 2) * wl, wtop - (Double(r.y) + Double(r.h) / 2) * wl, 0.0],
                                   "q": [0.0, 0.0, 0.0, 1.0], "s": [Double(r.w) * wl, Double(r.h) * wl, wt], "c": 0.0])
                    }
                    w["parts"] = np
                    w["mx"] = a1
                    rig["w"] = w
                }
            }
            rs[gid] = rig
        }
        TwGunLib.rigs = rs
    }

    // MARK: map

    // MARK: tile catalog (ids 0-9 keep their original meaning for old maps)

    enum TK { case floor, water, bridge, wall, edge, prop, spawn, spawnA, spawnD, loot, site }

    struct TileDef {
        let name: String
        let cat: Int
        let icon: String
        let col: Color
        let k: TK
        var mat: Int = 8
        var pk: PropKind = .crate
        var fr: [CGRect] = [CGRect(x: 0, y: 0, width: 1, height: 1)]
        var tag: String = ""
    }

    static let catNames = ["FLOORS", "WATER", "BRIDGES", "WALLS", "COVER", "DECOR", "SPECIAL"]
    static let catIcons = ["square.grid.3x3.fill", "drop.fill", "road.lanes", "rectangle.split.3x3.fill", "shippingbox.fill", "tree.fill", "star.fill"]

    /// floor material colours (0-8 are the original engine floors, 9+ are workshop floors / liquids)
    static let floorMatCols: [(CGFloat, CGFloat, CGFloat)] = [
        (0.72, 0.59, 0.41), (0.7, 0.6, 0.45), (0.5, 0.26, 0.2), (0.72, 0.5, 0.34), (0.4, 0.27, 0.17), (0.66, 0.56, 0.42), (0.22, 0.36, 0.17), (0.38, 0.3, 0.2), (0.34, 0.35, 0.38),
        (0.12, 0.38, 0.62), (0.9, 0.93, 0.97), (0.5, 0.5, 0.48), (0.35, 0.4, 0.45), (0.85, 0.86, 0.88), (0.3, 0.22, 0.14), (0.6, 0.8, 0.9), (0.15, 0.16, 0.2),
        (0.05, 0.2, 0.4), (0.9, 0.3, 0.05), (0.3, 0.7, 0.2), (0.08, 0.08, 0.1), (0.2, 0.3, 0.2), (0.2, 0.5, 0.65), (0.15, 0.45, 0.7), (0.1, 0.3, 0.55), (0.02, 0.02, 0.03)
    ]
    static let liquidMats: Set<Int> = [9, 17, 18, 19, 20, 21, 22, 23, 24, 25]

    static func matColor(_ m: Int) -> Color {
        let c = floorMatCols[min(max(m, 0), floorMatCols.count - 1)]
        return Color(red: Double(c.0), green: Double(c.1), blue: Double(c.2))
    }

    static let tiles: [TileDef] = {
        var t: [TileDef] = []
        func col(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        let full = CGRect(x: 0, y: 0, width: 1, height: 1)
        // 0-9 legacy ids
        t.append(TileDef(name: "Floor", cat: 0, icon: "square.fill", col: Color(white: 0.2), k: .floor, mat: 8))
        t.append(TileDef(name: "Wall", cat: 3, icon: "rectangle.split.3x3.fill", col: Color(white: 0.72), k: .wall))
        t.append(TileDef(name: "Crate", cat: 4, icon: "shippingbox.fill", col: col(0.55, 0.38, 0.2), k: .prop, pk: .crate, fr: [CGRect(x: 0.03, y: 0.03, width: 0.93, height: 0.93)]))
        t.append(TileDef(name: "Barrel", cat: 4, icon: "cylinder.fill", col: col(0.9, 0.5, 0.1), k: .prop, pk: .barrel, fr: [CGRect(x: 0.25, y: 0.25, width: 0.48, height: 0.48)]))
        t.append(TileDef(name: "Sandbag", cat: 4, icon: "rectangle.split.2x1.fill", col: col(0.75, 0.68, 0.45), k: .prop, pk: .sandbag, fr: [CGRect(x: 0, y: 0.29, width: 1, height: 0.43)]))
        t.append(TileDef(name: "Car", cat: 4, icon: "car.fill", col: col(0.2, 0.45, 0.85), k: .prop, pk: .car, fr: [CGRect(x: 0, y: 0.12, width: 1, height: 0.75)]))
        t.append(TileDef(name: "Table", cat: 4, icon: "table.furniture.fill", col: col(0.6, 0.45, 0.3), k: .prop, pk: .table, fr: [CGRect(x: 0.07, y: 0.2, width: 0.87, height: 0.6)]))
        t.append(TileDef(name: "Shelf", cat: 4, icon: "books.vertical.fill", col: col(0.6, 0.3, 0.7), k: .prop, pk: .shelf, fr: [CGRect(x: 0, y: 0.31, width: 1, height: 0.37)]))
        t.append(TileDef(name: "Spawn", cat: 6, icon: "figure.walk", col: col(0.2, 0.9, 0.3), k: .spawn))
        t.append(TileDef(name: "Loot", cat: 6, icon: "diamond.fill", col: col(1.0, 0.8, 0.2), k: .loot))
        // floors
        let floors: [(String, Int)] = [("Sand", 0), ("Slab", 1), ("Red Carpet", 2), ("Clay Tile", 3), ("Wood Floor", 4), ("Stone Tile", 5), ("Grass", 6), ("Dirt", 7), ("Asphalt", 8),
                                       ("Snow", 10), ("Gravel", 11), ("Metal Deck", 12), ("White Tile", 13), ("Mud", 14), ("Ice", 15), ("Dark Tile", 16)]
        for (n, m) in floors { t.append(TileDef(name: n, cat: 0, icon: "square.fill", col: matColor(m), k: .floor, mat: m)) }
        // water and other liquids (impassable)
        let liquids: [(String, Int, String)] = [("Water", 9, "drop.fill"), ("Deep Water", 17, "water.waves"), ("Pond", 22, "drop.fill"), ("River", 23, "water.waves"), ("Sea", 24, "water.waves"),
                                                ("Swamp", 21, "leaf.fill"), ("Toxic Pool", 19, "exclamationmark.triangle.fill"), ("Oil Slick", 20, "drop.fill"), ("Lava", 18, "flame.fill"), ("Void", 25, "circle.fill")]
        for (n, m, i) in liquids { t.append(TileDef(name: n, cat: 1, icon: i, col: matColor(m), k: .water, mat: m)) }
        // bridges (walkable over water)
        let bridges: [(String, Int)] = [("Wood Bridge", 4), ("Plank Bridge", 7), ("Steel Bridge", 12), ("Stone Bridge", 1), ("Rope Bridge", 14), ("Pier", 4), ("Dock", 5), ("Boardwalk", 3), ("Catwalk", 16), ("Pontoon", 11)]
        for (n, m) in bridges { t.append(TileDef(name: n, cat: 2, icon: "road.lanes", col: matColor(m), k: .bridge, mat: m)) }
        // wall shapes
        let w3: CGFloat = 1.0 / 3.0
        t.append(TileDef(name: "Pillar", cat: 3, icon: "square.fill", col: Color(white: 0.6), k: .edge, fr: [CGRect(x: w3, y: w3, width: w3, height: w3)]))
        t.append(TileDef(name: "Wall N", cat: 3, icon: "arrow.up.to.line", col: Color(white: 0.66), k: .edge, fr: [CGRect(x: 0, y: 0, width: 1, height: w3)]))
        t.append(TileDef(name: "Wall S", cat: 3, icon: "arrow.down.to.line", col: Color(white: 0.66), k: .edge, fr: [CGRect(x: 0, y: 2 * w3, width: 1, height: w3)]))
        t.append(TileDef(name: "Wall E", cat: 3, icon: "arrow.right.to.line", col: Color(white: 0.66), k: .edge, fr: [CGRect(x: 2 * w3, y: 0, width: w3, height: 1)]))
        t.append(TileDef(name: "Wall W", cat: 3, icon: "arrow.left.to.line", col: Color(white: 0.66), k: .edge, fr: [CGRect(x: 0, y: 0, width: w3, height: 1)]))
        t.append(TileDef(name: "Corner NE", cat: 3, icon: "arrow.up.right", col: Color(white: 0.62), k: .edge, fr: [CGRect(x: 0, y: 0, width: 1, height: w3), CGRect(x: 2 * w3, y: 0, width: w3, height: 1)]))
        t.append(TileDef(name: "Corner NW", cat: 3, icon: "arrow.up.left", col: Color(white: 0.62), k: .edge, fr: [CGRect(x: 0, y: 0, width: 1, height: w3), CGRect(x: 0, y: 0, width: w3, height: 1)]))
        t.append(TileDef(name: "Corner SE", cat: 3, icon: "arrow.down.right", col: Color(white: 0.62), k: .edge, fr: [CGRect(x: 0, y: 2 * w3, width: 1, height: w3), CGRect(x: 2 * w3, y: 0, width: w3, height: 1)]))
        t.append(TileDef(name: "Corner SW", cat: 3, icon: "arrow.down.left", col: Color(white: 0.62), k: .edge, fr: [CGRect(x: 0, y: 2 * w3, width: 1, height: w3), CGRect(x: 0, y: 0, width: w3, height: 1)]))
        t.append(TileDef(name: "Wall Cross", cat: 3, icon: "plus", col: Color(white: 0.58), k: .edge, fr: [CGRect(x: 0, y: w3, width: 1, height: w3), CGRect(x: w3, y: 0, width: w3, height: 1)]))
        // props: base, small, and four edge-hugging placements
        struct PK { let n: String; let k: PropKind; let w: CGFloat; let h: CGFloat; let c: Color; let i: String; let cat: Int }
        let kinds: [PK] = [
            PK(n: "Crate", k: .crate, w: 0.93, h: 0.93, c: col(0.55, 0.38, 0.2), i: "shippingbox.fill", cat: 4),
            PK(n: "Barrel", k: .barrel, w: 0.48, h: 0.48, c: col(0.9, 0.5, 0.1), i: "cylinder.fill", cat: 4),
            PK(n: "Sandbag", k: .sandbag, w: 1, h: 0.43, c: col(0.75, 0.68, 0.45), i: "rectangle.split.2x1.fill", cat: 4),
            PK(n: "Car", k: .car, w: 1, h: 0.75, c: col(0.2, 0.45, 0.85), i: "car.fill", cat: 4),
            PK(n: "Table", k: .table, w: 0.87, h: 0.6, c: col(0.6, 0.45, 0.3), i: "table.furniture.fill", cat: 4),
            PK(n: "Shelf", k: .shelf, w: 1, h: 0.37, c: col(0.6, 0.3, 0.7), i: "books.vertical.fill", cat: 4),
            PK(n: "Counter", k: .counter, w: 1, h: 0.4, c: col(0.5, 0.52, 0.56), i: "rectangle.fill", cat: 4),
            PK(n: "Couch", k: .couch, w: 0.9, h: 0.5, c: col(0.7, 0.3, 0.3), i: "sofa.fill", cat: 5),
            PK(n: "Bed", k: .bed, w: 0.8, h: 0.95, c: col(0.8, 0.8, 0.9), i: "bed.double.fill", cat: 5),
            PK(n: "TV", k: .tv, w: 0.5, h: 0.3, c: col(0.15, 0.2, 0.3), i: "tv.fill", cat: 5),
            PK(n: "Plant", k: .plant, w: 0.4, h: 0.4, c: col(0.25, 0.6, 0.25), i: "leaf.fill", cat: 5),
            PK(n: "Tree", k: .tree, w: 0.8, h: 0.8, c: col(0.15, 0.45, 0.18), i: "tree.fill", cat: 5),
            PK(n: "Rock", k: .rock, w: 0.6, h: 0.5, c: col(0.5, 0.5, 0.52), i: "triangle.fill", cat: 5)
        ]
        for pk in kinds {
            let sw = pk.w * 0.55, sh = pk.h * 0.55
            let vars: [(String, CGRect)] = [
                ("", CGRect(x: (1 - pk.w) / 2, y: (1 - pk.h) / 2, width: pk.w, height: pk.h)),
                (" Small", CGRect(x: (1 - sw) / 2, y: (1 - sh) / 2, width: sw, height: sh)),
                (" N", CGRect(x: (1 - sw) / 2, y: 0, width: sw, height: sh)),
                (" S", CGRect(x: (1 - sw) / 2, y: 1 - sh, width: sw, height: sh)),
                (" E", CGRect(x: 1 - sw, y: (1 - sh) / 2, width: sw, height: sh)),
                (" W", CGRect(x: 0, y: (1 - sh) / 2, width: sw, height: sh))
            ]
            for (suf, r) in vars {
                if suf.isEmpty && pk.cat == 4 && pk.k != .counter { continue }
                t.append(TileDef(name: pk.n + suf, cat: pk.cat, icon: pk.i, col: pk.c, k: .prop, pk: pk.k, fr: [r]))
            }
        }
        // specials
        t.append(TileDef(name: "Attack Spawn", cat: 6, icon: "figure.run", col: col(0.95, 0.35, 0.25), k: .spawnA))
        t.append(TileDef(name: "Defend Spawn", cat: 6, icon: "shield.fill", col: col(0.25, 0.55, 0.95), k: .spawnD))
        t.append(TileDef(name: "Bomb Site A", cat: 6, icon: "a.circle.fill", col: col(0.95, 0.75, 0.15), k: .site, tag: "A"))
        t.append(TileDef(name: "Bomb Site B", cat: 6, icon: "b.circle.fill", col: col(0.95, 0.55, 0.15), k: .site, tag: "B"))
        let loots: [(String, String)] = [("Rifle", "g:rifle"), ("SMG", "g:smg"), ("M4", "g:m4"), ("Medkit", "med"), ("Ammo", "ammo"), ("Armor", "armor:2"), ("Light Armor", "armor:1"), ("Plate", "plate"), ("Bandage", "band"), ("Kit", "kit")]
        for (n, id) in loots { t.append(TileDef(name: n + " Loot", cat: 6, icon: "diamond.fill", col: col(1.0, 0.8, 0.2), k: .loot, tag: id)) }
        _ = full
        return t
    }()

    static func tile(_ id: Int) -> TileDef { tiles[min(max(id, 0), tiles.count - 1)] }

    static let presetNames = ["Harbor Base", "Warehouse", "Arena", "River Crossing", "Island", "Blank"]

    /// two hex chars per cell (ids up to 255); old single-char maps still load
    static func cellsString(_ a: [UInt8]) -> String {
        let hex = Array("0123456789abcdef")
        var out = ""
        out.reserveCapacity(a.count * 2)
        for v in a { out.append(hex[Int(v >> 4)]); out.append(hex[Int(v & 15)]) }
        return out
    }

    static func cellsArray(_ s: String) -> [UInt8] {
        let ch = Array(s)
        if ch.count == mw * mh { return ch.map { UInt8(String($0), radix: 16) ?? 0 } }
        if ch.count == mw * mh * 2 {
            var o = [UInt8](repeating: 0, count: mw * mh)
            for i in 0..<(mw * mh) {
                let hi = Int(String(ch[i * 2]), radix: 16) ?? 0, lo = Int(String(ch[i * 2 + 1]), radix: 16) ?? 0
                o[i] = UInt8(min(tiles.count - 1, hi * 16 + lo))
            }
            return o
        }
        return defaultMap()
    }

    static func preset(_ name: String) -> [UInt8] {
        var a = [UInt8](repeating: 0, count: mw * mh)
        func box(_ c0: Int, _ r0: Int, _ c1: Int, _ r1: Int, _ v: UInt8) { for r in r0...r1 { for c in c0...c1 { a[r * mw + c] = v } } }
        func put(_ c: Int, _ r: Int, _ v: UInt8) { if c >= 0 && c < mw && r >= 0 && r < mh { a[r * mw + c] = v } }
        switch name {
        case "Warehouse":
            box(4, 2, 16, 8, 1); box(5, 3, 15, 7, 0); box(9, 8, 11, 8, 0)
            box(19, 11, 31, 17, 1); box(20, 12, 30, 16, 0); box(24, 11, 26, 11, 0)
            for (c, r) in [(7, 4), (8, 4), (13, 5), (22, 14), (23, 14), (28, 13), (10, 12), (11, 12), (2, 15), (33, 4), (16, 15)] { put(c, r, 2) }
            for (c, r) in [(6, 7), (14, 4), (21, 15), (29, 15)] { put(c, r, 7) }
            for (c, r) in [(18, 9), (19, 9), (17, 5)] { put(c, r, 4) }
            for r in stride(from: 3, to: 18, by: 3) { put(1, r, 8); put(34, r, 8) }
            put(10, 5, 9); put(25, 14, 9); put(18, 10, 9)
        case "Arena":
            box(16, 7, 19, 12, 1); box(17, 8, 18, 11, 0); put(17, 7, 0); put(18, 12, 0)
            for (c, r) in [(8, 4), (8, 15), (27, 4), (27, 15), (12, 9), (23, 10), (5, 9), (30, 10)] { put(c, r, 2); put(c + 1, r, 2) }
            for (c, r) in [(14, 3), (21, 16), (3, 5), (32, 14)] { put(c, r, 3) }
            for (c, r) in [(10, 6), (25, 13), (14, 14), (21, 5)] { put(c, r, 4); put(c + 1, r, 4) }
            for r in stride(from: 3, to: 18, by: 3) { put(1, r, 8); put(34, r, 8) }
            put(17, 9, 9); put(18, 10, 9)
        case "River Crossing":
            let water = UInt8(TWorkshop.tiles.firstIndex(where: { $0.name == "River" }) ?? 0)
            let bridge = UInt8(TWorkshop.tiles.firstIndex(where: { $0.name == "Wood Bridge" }) ?? 0)
            let grass = UInt8(TWorkshop.tiles.firstIndex(where: { $0.name == "Grass" }) ?? 0)
            let tree = UInt8(TWorkshop.tiles.firstIndex(where: { $0.name == "Tree" }) ?? 0)
            box(0, 0, mw - 1, mh - 1, grass)
            box(16, 0, 19, mh - 1, water)
            for r in [4, 10, 15] { box(16, r, 19, r + 1, bridge) }
            for (c, r) in [(6, 3), (9, 8), (4, 14), (12, 16), (26, 4), (30, 9), (24, 15), (32, 17)] { put(c, r, tree) }
            for (c, r) in [(10, 11), (13, 5), (25, 10), (29, 14)] { put(c, r, 2) }
            for (c, r) in [(14, 4), (14, 10), (14, 15), (21, 4), (21, 10), (21, 15)] { put(c, r, 4) }
            for r in stride(from: 3, to: 18, by: 3) { put(1, r, 8); put(34, r, 8) }
            put(8, 6, 9); put(27, 13, 9)
        case "Island":
            let water = UInt8(TWorkshop.tiles.firstIndex(where: { $0.name == "Water" }) ?? 0)
            let deep = UInt8(TWorkshop.tiles.firstIndex(where: { $0.name == "Deep Water" }) ?? 0)
            let sand = UInt8(TWorkshop.tiles.firstIndex(where: { $0.name == "Sand" }) ?? 0)
            let dock = UInt8(TWorkshop.tiles.firstIndex(where: { $0.name == "Dock" }) ?? 0)
            box(0, 0, mw - 1, mh - 1, deep)
            box(2, 2, mw - 3, mh - 3, water)
            box(10, 4, 25, 15, sand)
            box(4, 9, 9, 10, dock); box(26, 9, 31, 10, dock)
            box(12, 6, 15, 8, 1); box(13, 7, 14, 7, 0)
            box(20, 11, 23, 13, 1); box(21, 12, 22, 12, 0)
            for (c, r) in [(17, 9), (18, 9), (16, 12), (19, 6), (11, 13), (24, 7)] { put(c, r, 2) }
            put(3, 9, 8); put(32, 10, 8); put(3, 10, 8); put(32, 9, 8)
            put(17, 10, 9); put(18, 8, 9)
        case "Blank":
            for r in stride(from: 3, to: 18, by: 3) { put(1, r, 8); put(34, r, 8) }
        default:
            return defaultMap()
        }
        return a
    }

    static func defaultMap() -> [UInt8] {
        var a = [UInt8](repeating: 0, count: mw * mh)
        func box(_ c0: Int, _ r0: Int, _ c1: Int, _ r1: Int, _ v: UInt8) { for r in r0...r1 { for c in c0...c1 { a[r * mw + c] = v } } }
        func put(_ c: Int, _ r: Int, _ v: UInt8) { if c >= 0 && c < mw && r >= 0 && r < mh { a[r * mw + c] = v } }
        box(5, 3, 13, 8, 1); box(6, 4, 12, 7, 0); box(8, 8, 10, 8, 0); put(9, 5, 9); put(7, 6, 6)
        box(23, 11, 31, 16, 1); box(24, 12, 30, 15, 0); box(26, 11, 28, 11, 0); put(27, 14, 9); put(25, 13, 7)
        for (c, r) in [(17, 4), (18, 4), (16, 9), (19, 10), (20, 5), (15, 14), (16, 14), (3, 12), (4, 12), (31, 5), (32, 5), (22, 18), (12, 17)] { put(c, r, 2) }
        for (c, r) in [(18, 8), (17, 12), (21, 8), (14, 11)] { put(c, r, 3) }
        for (c, r) in [(10, 11), (11, 11), (24, 6), (25, 6), (28, 19)] { put(c, r, 4) }
        put(20, 14, 5); put(8, 14, 5)
        for r in stride(from: 3, to: 18, by: 3) { put(1, r, 8); put(34, r, 8) }
        put(18, 6, 9); put(18, 13, 9)
        return a
    }
}

// MARK: - Custom map (kind 5)

enum TCustom {
    private static var cache: MapData?

    static func invalidate() {
        cache = nil
        TMap.needsApply = true
    }

    static var shared: MapData {
        if let c = cache { return c }
        let m = build()
        cache = m
        return m
    }

    private static func build() -> MapData {
        let cells = TWorkshop.cellsArray(TWorkshop.currentMap.cells)
        let mw = TWorkshop.mw, mh = TWorkshop.mh
        let ox: CGFloat = 150, oy: CGFloat = 150, ts: CGFloat = 75
        let b = MapBuilder()
        let rc = b.rc
        let arena = rc(150, 150, 2700, 1500)
        b.setR(1, arena, true)
        b.rooms.append(TRoom(name: "West Side", r: MapBuilder.R(1, rc(150, 150, 1350, 1500)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "East Side", r: MapBuilder.R(1, rc(1500, 150, 1350, 1500)), mat: 8, fl: 1))

        var free: [CGPoint] = [], marked: [CGPoint] = [], atkM: [CGPoint] = [], defM: [CGPoint] = []
        var lootT: [(CGPoint, String)] = []
        var matGrid = [Int](repeating: 8, count: mw * mh)
        var siteA: CGRect?, siteB: CGRect?
        for r in 0..<mh {
            for c in 0..<mw {
                let def = TWorkshop.tile(Int(cells[r * mw + c]))
                let x = ox + CGFloat(c) * ts, y = oy + CGFloat(r) * ts
                let mid = CGPoint(x: x + ts / 2, y: y + ts / 2)
                switch def.k {
                case .floor, .bridge:
                    matGrid[r * mw + c] = def.mat
                    free.append(mid)
                case .water:
                    matGrid[r * mw + c] = def.mat
                    b.setR(1, rc(x, y, ts, ts), false)
                case .wall:
                    b.setR(1, rc(x, y, ts, ts), false)
                case .edge:
                    for f in def.fr { b.setR(1, rc(x + f.minX * ts, y + f.minY * ts, f.width * ts, f.height * ts), false) }
                case .prop:
                    let f = def.fr[0]
                    b.p(1, def.pk, x + f.minX * ts, y + f.minY * ts, f.width * ts, f.height * ts)
                case .spawn:
                    marked.append(mid); free.append(mid)
                case .spawnA:
                    marked.append(mid); atkM.append(mid); free.append(mid)
                case .spawnD:
                    marked.append(mid); defM.append(mid); free.append(mid)
                case .loot:
                    lootT.append((mid, def.tag)); free.append(mid)
                case .site:
                    let sr = rc(min(max(mid.x - 225, 150), 2850 - 450), min(max(mid.y - 150, 150), 1650 - 300), 450, 300)
                    if def.tag == "A" { siteA = sr } else { siteB = sr }
                    free.append(mid)
                }
            }
        }
        // floors: merge same-material cells into the fewest boxes
        var used = [Bool](repeating: false, count: mw * mh)
        for r in 0..<mh {
            for c in 0..<mw where !used[r * mw + c] {
                let m = matGrid[r * mw + c]
                var w = 1
                while c + w < mw && !used[r * mw + c + w] && matGrid[r * mw + c + w] == m { w += 1 }
                var h = 1
                outer: while r + h < mh {
                    for k in 0..<w where used[(r + h) * mw + c + k] || matGrid[(r + h) * mw + c + k] != m { break outer }
                    h += 1
                }
                for yy in r..<(r + h) { for xx in c..<(c + w) { used[yy * mw + xx] = true } }
                let rect = rc(ox + CGFloat(c) * ts, oy + CGFloat(r) * ts, CGFloat(w) * ts, CGFloat(h) * ts)
                b.tiles.append(TRoom(name: TWorkshop.liquidMats.contains(m) ? "Water" : "Arena", r: MapBuilder.R(1, rect), mat: m, fl: 1))
            }
        }
        if free.isEmpty { free = [CGPoint(x: 300, y: 300), CGPoint(x: 2700, y: 1500)] }

        func spread(_ n: Int, _ seed: [CGPoint]) -> [CGPoint] {
            var out = seed
            var g = 0
            while out.count < n && g < 400 {
                var best = free[0]
                var bd: CGFloat = -1
                for p in free {
                    var d = CGFloat.infinity
                    for q in out { d = min(d, hypot(p.x - q.x, p.y - q.y)) }
                    if d > bd { bd = d; best = p }
                }
                out.append(best)
                g += 1
            }
            return out
        }
        let sp = Array(spread(20, Array(marked.prefix(20))).prefix(20))
        let spawns = sp.map { CGPoint(x: $0.x + TMap.off, y: $0.y) }
        let byX = sp.sorted { $0.x < $1.x }
        let atk = (atkM.isEmpty ? Array(byX.prefix(5)) : Array(atkM.prefix(5))).map { CGPoint(x: $0.x + TMap.off, y: $0.y) }
        let def = (defM.isEmpty ? Array(byX.suffix(5)) : Array(defM.prefix(5))).map { CGPoint(x: $0.x + TMap.off, y: $0.y) }
        let packs = spread(24, sp).suffix(4).map { CGPoint(x: $0.x + TMap.off, y: $0.y) }
        let ids = ["g:rifle", "med", "ammo", "armor:2", "g:smg", "plate", "band", "kit", "g:m4", "armor:1"]
        var lootList: [(CGPoint, String)] = []
        if lootT.isEmpty {
            for (i, p) in Array(spread(28, sp).suffix(8)).enumerated() { lootList.append((CGPoint(x: p.x + TMap.off, y: p.y), ids[i % ids.count])) }
        } else {
            for (i, e) in lootT.enumerated() { lootList.append((CGPoint(x: e.0.x + TMap.off, y: e.0.y), e.1.isEmpty ? ids[i % ids.count] : e.1)) }
        }

        let layout = b.layout([.brick, .concrete, .concrete])
        var md = MapData(rooms: b.rooms, floorTiles: b.tiles, layout: layout, props: b.props, packPos: packs, stairs: [], stairLo: [],
                         siteA: MapBuilder.R(1, siteA ?? rc(250, 300, 450, 300)), siteB: MapBuilder.R(1, siteB ?? rc(2300, 1200, 450, 300)),
                         atkSpawn: atk, defSpawn: def, hubZone: MapBuilder.R(1, rc(1300, 700, 400, 200)),
                         floorNames: ["", "CUSTOM", ""], loot: lootList, roofs: b.roofs, spawns: spawns)
        md.siteNames = ["A · WEST", "B · EAST"]
        return md
    }
}

// MARK: - Workshop screen

struct CSWorkshop: View {
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void
    let playMap: () -> Void

    @State private var tab = 0
    @State private var guns: [WSGun] = TWorkshop.guns
    @State private var gunId = ""
    @State private var grid: [UInt8] = [UInt8](repeating: 0, count: TWorkshop.gw * TWorkshop.gh)
    @State private var ink: UInt8 = 3
    @State private var tool = 0
    @State private var undo: [UInt8] = []
    @State private var pal = TWorkshop.pal
    @State private var ver = 0
    @State private var stroke = false
    @State private var yaw: Double = 0
    @State private var maps: [WSMap] = TWorkshop.maps
    @State private var mapId = ""
    @State private var cells: [UInt8] = []
    @State private var tile: UInt8 = 1
    @State private var cat = 0
    @State private var mUndo: [UInt8] = []
    @State private var presetPick = "Harbor Base"
    @State private var rename = false
    @State private var renameTarget = 0
    @State private var renameText = ""
    @State private var shareText = ""
    @State private var showShare = false
    @State private var note = ""

    private let gw = TWorkshop.gw, gh = TWorkshop.gh, mw = TWorkshop.mw, mh = TWorkshop.mh

    private var gunIdx: Int? { guns.firstIndex(where: { $0.id == gunId }) }
    private var mapIdx: Int? { maps.firstIndex(where: { $0.id == mapId }) }
    private var base: String { gunIdx.map { guns[$0].base } ?? nav.tacGun }

    // MARK: gun data ops

    private func syncGuns() { TWorkshop.guns = guns }

    private func loadGun(_ id: String) {
        gunId = id
        if let i = gunIdx {
            grid = TWorkshop.pxArray(guns[i].px)
            TWorkshop.setEquipped(guns[i].base, id)
        }
        undo = []
        TwGunLib.reloadRigs()
        ver += 1
    }

    private func commitGun() {
        guard let i = gunIdx else { return }
        guns[i].px = TWorkshop.pxString(grid)
        syncGuns()
        TWorkshop.setEquipped(guns[i].base, guns[i].id)
        TwGunLib.reloadRigs()
        ver += 1
    }

    private func newGun(base b: String? = nil, name: String? = nil, px: String? = nil) {
        let g = WSGun(id: TWorkshop.newId(), name: name ?? "Custom Gun \(guns.count + 1)", base: b ?? nav.tacGun, px: px ?? TWorkshop.pxString(TWorkshop.starter()))
        guns.append(g)
        syncGuns()
        loadGun(g.id)
    }

    private func deleteGun(_ id: String) {
        guard let i = guns.firstIndex(where: { $0.id == id }) else { return }
        let g = guns[i]
        if TWorkshop.equippedId(g.base) == id { TWorkshop.setEquipped(g.base, nil) }
        guns.remove(at: i)
        syncGuns()
        if guns.isEmpty { newGun() } else if gunId == id { loadGun(guns[0].id) } else { TwGunLib.reloadRigs(); ver += 1 }
    }

    private func setBase(_ id: String, _ b: String) {
        guard let i = guns.firstIndex(where: { $0.id == id }) else { return }
        if TWorkshop.equippedId(guns[i].base) == id { TWorkshop.setEquipped(guns[i].base, nil) }
        guns[i].base = b
        syncGuns()
        if gunId == id { TWorkshop.setEquipped(b, id) }
        TwGunLib.reloadRigs()
        ver += 1
    }

    // MARK: map data ops

    private func syncMaps() { TWorkshop.maps = maps }

    private func loadMap(_ id: String) {
        mapId = id
        TWorkshop.mapSel = id
        if let i = mapIdx { cells = TWorkshop.cellsArray(maps[i].cells) }
        mUndo = []
        TCustom.invalidate()
    }

    private func commitMap() {
        guard let i = mapIdx else { return }
        maps[i].cells = TWorkshop.cellsString(cells)
        syncMaps()
        TWorkshop.mapSel = mapId
        TCustom.invalidate()
    }

    private func newMap(name: String? = nil, cellsStr: String? = nil) {
        let m = WSMap(id: TWorkshop.newId(), name: name ?? "Custom Map \(maps.count + 1)", cells: cellsStr ?? TWorkshop.cellsString(TWorkshop.preset("Blank")), desc: "A custom map built in the Workshop.")
        maps.append(m)
        syncMaps()
        loadMap(m.id)
    }

    private func deleteMap(_ id: String) {
        guard maps.count > 1, let i = maps.firstIndex(where: { $0.id == id }) else { note = "Keep at least one map"; return }
        maps.remove(at: i)
        syncMaps()
        if mapId == id { loadMap(maps[0].id) }
    }

    private func importClipboard() {
        guard let s = UIPasteboard.general.string else { note = "Clipboard is empty"; return }
        let p = s.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if p.count >= 3, p[0] == "MAINSHOT-MAP", (p[2].count == mw * mh || p[2].count == mw * mh * 2) { newMap(name: p[1], cellsStr: p[2]); tab = 1; note = "Map imported" }
        else if p.count >= 4, p[0] == "MAINSHOT-GUN", p[3].count == gw * gh { newGun(base: p[1], name: p[2], px: p[3]); tab = 0; note = "Gun imported" }
        else { note = "Nothing to import" }
    }

    // MARK: pieces

    private func thumb(_ px: String, _ w: CGFloat, _ h: CGFloat) -> some View {
        Canvas { ctx, sz in
            let a = TWorkshop.pxArray(px)
            let cs = min(sz.width / CGFloat(TWorkshop.gw), sz.height / CGFloat(TWorkshop.gh))
            for y in 0..<TWorkshop.gh {
                for x in 0..<TWorkshop.gw {
                    let v = Int(a[y * TWorkshop.gw + x])
                    if v > 0 { ctx.fill(Path(CGRect(x: CGFloat(x) * cs, y: CGFloat(y) * cs, width: cs + 0.3, height: cs + 0.3)), with: .color(TWorkshop.hexColor(pal[v - 1]))) }
                }
            }
        }
        .frame(width: w, height: h)
    }

    private func drawTile(_ ctx: GraphicsContext, _ id: Int, _ r: CGRect) {
        let d = TWorkshop.tile(id)
        let base = Color(white: 0.16)
        func sub(_ f: CGRect) -> CGRect { CGRect(x: r.minX + f.minX * r.width, y: r.minY + f.minY * r.height, width: f.width * r.width, height: f.height * r.height) }
        switch d.k {
        case .floor, .water, .bridge, .wall:
            ctx.fill(Path(r), with: .color(d.col))
        case .edge:
            ctx.fill(Path(r), with: .color(base))
            for f in d.fr { ctx.fill(Path(sub(f)), with: .color(d.col)) }
        case .prop:
            ctx.fill(Path(r), with: .color(base))
            ctx.fill(Path(sub(d.fr[0])), with: .color(d.col))
        default:
            ctx.fill(Path(r), with: .color(base))
            ctx.fill(Path(ellipseIn: r.insetBy(dx: r.width * 0.18, dy: r.height * 0.18)), with: .color(d.col))
        }
    }

    private func mapThumb(_ s: String, _ w: CGFloat, _ h: CGFloat) -> some View {
        Canvas { ctx, sz in
            let a = TWorkshop.cellsArray(s)
            let cs = min(sz.width / CGFloat(TWorkshop.mw), sz.height / CGFloat(TWorkshop.mh))
            for y in 0..<TWorkshop.mh {
                for x in 0..<TWorkshop.mw {
                    drawTile(ctx, Int(a[y * TWorkshop.mw + x]), CGRect(x: CGFloat(x) * cs, y: CGFloat(y) * cs, width: cs + 0.3, height: cs + 0.3))
                }
            }
        }
        .frame(width: w, height: h)
    }

    private func listBtns(_ newAct: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Button(action: newAct) {
                HStack(spacing: 4) {
                    SF("plus").font(.system(size: 10, weight: .bold))
                    Text("NEW").font(.jk(9, .heavy)).lineLimit(1)
                }
                .foregroundColor(.white.opacity(0.9)).frame(maxWidth: .infinity).frame(height: 24)
                .background(Color.black.opacity(0.45)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            }
            .buttonStyle(TuiPress())
            Button { importClipboard() } label: {
                SF("square.and.arrow.down").font(.system(size: 11, weight: .bold)).foregroundColor(.white.opacity(0.9))
                    .frame(width: 30, height: 24).background(Color.black.opacity(0.45)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            }
            .buttonStyle(TuiPress())
        }
    }

    private func listRow(selected: Bool, name: String, sub: String, art: AnyView, menu: AnyView, tap: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            Button(action: tap) {
                HStack(spacing: 6) {
                    art
                    VStack(alignment: .leading, spacing: 0) {
                        Text(name).font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                        Text(sub).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.55))
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(TuiPress())
            menu
        }
        .padding(.horizontal, 6).frame(height: 40)
        .background(selected ? LS.orange.opacity(0.12) : LS.card)
        .overlay(Rectangle().stroke(selected ? LS.orange : LS.line, lineWidth: selected ? 1.5 : 1))
    }

    private func toolBtn(_ icon: String, _ label: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 6) {
                SF(icon, "circle.fill").font(.system(size: 11, weight: .bold)).frame(width: 14)
                Text(label).font(.jk(10, .semibold))
                Spacer(minLength: 0)
            }
            .foregroundColor(on ? LS.orange : .white.opacity(0.85))
            .padding(.horizontal, 6).frame(height: 27)
            .background(on ? LS.orange.opacity(0.18) : Color.black.opacity(0.35))
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func paintGun(_ p: CGPoint, _ cs: CGFloat) {
        let x = Int(p.x / cs), y = Int(p.y / cs)
        guard x >= 0, y >= 0, x < gw, y < gh, grid.count == gw * gh else { return }
        let first = !stroke
        if first { stroke = true; undo = grid }
        if tool == 2 { if first { flood(x, y) }; return }
        grid[y * gw + x] = tool == 1 ? 0 : ink
    }

    private func flood(_ sx: Int, _ sy: Int) {
        let target = grid[sy * gw + sx], to: UInt8 = ink
        if target == to { return }
        var st = [(sx, sy)]
        while let (x, y) = st.popLast() {
            if x < 0 || y < 0 || x >= gw || y >= gh || grid[y * gw + x] != target { continue }
            grid[y * gw + x] = to
            st += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
        }
    }

    private func mirror() {
        for y in 0..<gh { for x in 0..<(gw / 2) { grid.swapAt(y * gw + x, y * gw + (gw - 1 - x)) } }
    }

    // MARK: guns tab

    private func gunMenu(_ g: WSGun) -> AnyView {
        AnyView(Menu {
            Button("Rename") { renameTarget = 0; renameText = g.name; gunId = g.id; rename = true }
            Menu("Base Gun") {
                ForEach(TWeapons.all.map { $0.id }, id: \.self) { id in Button(TWeapons.w(id).name) { setBase(g.id, id) } }
            }
            Button("Duplicate") { newGun(base: g.base, name: g.name + " Copy", px: g.px) }
            Button("Share") { shareText = "MAINSHOT-GUN|\(g.base)|\(g.name)|\(g.px)"; showShare = true }
            Button("Delete", role: .destructive) { deleteGun(g.id) }
        } label: {
            SF("ellipsis").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.7)).rotationEffect(.degrees(90)).frame(width: 18, height: 28)
        })
    }

    private func toolChip(_ icon: String, _ label: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(spacing: 1) {
                SF(icon, "circle.fill").font(.system(size: 11, weight: .bold))
                Text(label).font(.jk(8, .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundColor(on ? LS.orange : .white.opacity(0.85))
            .frame(maxWidth: .infinity).frame(height: 30)
            .background(on ? LS.orange.opacity(0.18) : Color.black.opacity(0.35))
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func gunsTab(_ W: CGFloat, _ ph: CGFloat) -> some View {
        let avail = W - 16
        let listW = max(98, (avail * 0.18).rounded())
        let prevW = max(92, (avail * 0.17).rounded())
        let gameW = max(92, (avail * 0.165).rounded())
        let edW = avail - listW - prevW - gameW - 15
        let inW = edW - 12
        let cs = max(4, min(floor(inW / CGFloat(gw) * 2) / 2, (ph - 22 - 12 - 30 - 5 - 20 - 10) / CGFloat(gh)))
        let cw = cs * CGFloat(gw)
        let sw = max(8, floor((cw - 30 - 24) / 15))
        let b = base
        return HStack(alignment: .top, spacing: 5) {
            LSPanel(title: "MY GUNS") {
                VStack(spacing: 4) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(guns) { g in
                                listRow(selected: g.id == gunId, name: g.name, sub: "Custom Gun", art: AnyView(thumb(g.px, 40, 17)), menu: gunMenu(g)) { loadGun(g.id) }
                            }
                        }
                    }
                    listBtns { newGun() }
                }
                .padding(5)
            }
            .frame(width: listW, height: ph).clipped()
            LSPanel(title: "PIXEL EDITOR", trailing: "32 × 14") {
                VStack(spacing: 5) {
                    HStack(spacing: 3) {
                        toolChip("pencil", "Paint", tool == 0) { tool = 0 }
                        toolChip("eraser.fill", "Erase", tool == 1) { tool = 1 }
                        toolChip("drop.fill", "Fill", tool == 2) { tool = 2 }
                        toolChip("arrow.left.arrow.right", "Mirror", false) { undo = grid; mirror(); commitGun() }
                        toolChip("arrow.uturn.backward", "Undo", false) { if !undo.isEmpty { grid = undo; undo = []; commitGun() } }
                        toolChip("trash.fill", "Clear", false) { undo = grid; grid = [UInt8](repeating: 0, count: gw * gh); commitGun() }
                    }
                    .frame(width: cw)
                    Canvas { ctx, _ in
                        guard grid.count == gw * gh else { return }
                        for y in 0..<gh {
                            for x in 0..<gw {
                                let r = CGRect(x: CGFloat(x) * cs, y: CGFloat(y) * cs, width: cs, height: cs)
                                ctx.fill(Path(r), with: .color(Color.white.opacity((x + y) % 2 == 0 ? 0.05 : 0.1)))
                                let v = Int(grid[y * gw + x])
                                if v > 0 { ctx.fill(Path(r.insetBy(dx: 0.3, dy: 0.3)), with: .color(TWorkshop.hexColor(pal[v - 1]))) }
                            }
                        }
                    }
                    .frame(width: cw, height: cs * CGFloat(gh))
                    .background(Color.black.opacity(0.35))
                    .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { g in paintGun(g.location, cs) }
                        .onEnded { _ in stroke = false; commitGun() })
                    HStack(spacing: 2) {
                        ForEach(1...15, id: \.self) { i in
                            Button { ink = UInt8(i); if tool == 1 { tool = 0 } } label: {
                                Rectangle().fill(TWorkshop.hexColor(pal[i - 1])).frame(width: sw, height: sw)
                                    .overlay(Rectangle().stroke(ink == UInt8(i) ? Color.white : Color.black.opacity(0.5), lineWidth: ink == UInt8(i) ? 2 : 1))
                            }
                            .buttonStyle(TuiPress())
                        }
                        ColorPicker("", selection: Binding(get: { TWorkshop.hexColor(pal[Int(max(1, ink)) - 1]) }, set: { c in
                            pal[Int(max(1, ink)) - 1] = TWorkshop.hexOf(c)
                            TWorkshop.pal = pal
                            commitGun()
                        })).labelsHidden().frame(width: 24)
                    }
                    .frame(width: cw)
                    Spacer(minLength: 0)
                }
                .padding(6)
                .frame(maxWidth: .infinity)
            }
            .frame(width: edW, height: ph).clipped()
            LSPanel(title: "3D PREVIEW") {
                ZStack(alignment: .bottomLeading) {
                    GunPreview3D(gid: b, sig: "ws\(ver)", yaw: yaw).allowsHitTesting(false)
                    LSSmallButton(icon: "arrow.triangle.2.circlepath", label: "ROTATE") { yaw += .pi / 2 }.padding(4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            }
            .frame(width: prevW, height: ph).clipped()
            LSPanel(title: "IN-GAME VIEW") {
                VStack(spacing: 5) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [Color(red: 0.25, green: 0.45, blue: 0.7), Color(red: 0.5, green: 0.4, blue: 0.3)], startPoint: .top, endPoint: .bottom)
                        thumb(TWorkshop.pxString(grid), gameW - 10, (gameW - 10) * 0.44).rotationEffect(.degrees(-6)).offset(x: 4, y: -6)
                        Text("FIRST PERSON").font(.jk(7, .heavy)).foregroundColor(.white).padding(3)
                    }
                    .frame(height: 50).clipped()
                    ZStack(alignment: .bottomLeading) {
                        AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: 0, gun: b, yaw: 0.5, zoom: 1.5, sway: false).allowsHitTesting(false)
                        Text("ON SOLDIERS").font(.jk(7, .heavy)).foregroundColor(.white).padding(3)
                    }
                    .frame(height: 74).background(Color.black.opacity(0.3)).clipped()
                    Button { commitGun(); note = "Gun saved" } label: {
                        HStack(spacing: 5) {
                            SF("square.and.arrow.down.fill").font(.system(size: 11, weight: .bold))
                            Text("SAVE GUN").font(.jk(11, .heavy)).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 30)
                        .background(LinearGradient(colors: [LS.orange, LS.orange2], startPoint: .top, endPoint: .bottom))
                    }
                    .buttonStyle(TuiPress())
                    Spacer(minLength: 0)
                }
                .padding(5)
            }
            .frame(width: gameW, height: ph).clipped()
        }
    }

    // MARK: maps tab

    private func mapMenu(_ m: WSMap) -> AnyView {
        AnyView(Menu {
            Button("Rename") { renameTarget = 1; renameText = m.name; mapId = m.id; rename = true }
            Button("Duplicate") { newMap(name: m.name + " Copy", cellsStr: m.cells) }
            Button("Share") { shareText = "MAINSHOT-MAP|\(m.name)|\(m.cells)"; showShare = true }
            Button("Delete", role: .destructive) { deleteMap(m.id) }
        } label: {
            SF("ellipsis").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.7)).rotationEffect(.degrees(90)).frame(width: 18, height: 28)
        })
    }

    private func tileRow(_ i: Int) -> some View {
        let d = TWorkshop.tile(i)
        let on = tile == UInt8(i)
        return Button { tile = UInt8(i) } label: {
            HStack(spacing: 5) {
                SF(d.icon, "circle.fill").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.92))
                    .frame(width: 15, height: 15).background(d.col).overlay(Rectangle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                Text(d.name).font(.jk(9, .semibold)).foregroundColor(on ? LS.orange : .white.opacity(0.88)).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4).frame(height: 21)
            .background(on ? LS.orange.opacity(0.16) : Color.black.opacity(0.35))
            .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func mapsTab(_ W: CGFloat, _ ph: CGFloat) -> some View {
        let avail = W - 16
        let listW = max(104, (avail * 0.18).rounded())
        let prevW = max(150, (avail * 0.27).rounded())
        let edW = avail - listW - prevW - 10
        let inW = edW - 12
        let palW: CGFloat = 96
        let innerH = ph - 22 - 12
        let cs = max(4, min((inW - palW - 6) / CGFloat(mw), (innerH - 26 - 5 - 26 - 4 - 26) / CGFloat(mh)))
        let ids = TWorkshop.tiles.indices.filter { TWorkshop.tiles[$0].cat == cat }
        let cur = mapIdx.map { maps[$0] }
        let tdef = TWorkshop.tile(Int(tile))
        return HStack(alignment: .top, spacing: 5) {
            LSPanel(title: "MY MAPS") {
                VStack(spacing: 4) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 4) {
                            ForEach(maps) { m in
                                listRow(selected: m.id == mapId, name: m.name, sub: "Custom Map", art: AnyView(mapThumb(m.cells, 34, 19)), menu: mapMenu(m)) { loadMap(m.id) }
                            }
                        }
                    }
                    listBtns { newMap() }
                }
                .padding(5)
            }
            .frame(width: listW, height: ph).clipped()
            LSPanel(title: "TILE EDITOR", trailing: "36 × 20 · \(TWorkshop.tiles.count) TILES") {
                VStack(alignment: .leading, spacing: 4) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 3) {
                            ForEach(0..<TWorkshop.catNames.count, id: \.self) { i in
                                Button { cat = i } label: {
                                    HStack(spacing: 3) {
                                        SF(TWorkshop.catIcons[i], "circle.fill").font(.system(size: 9, weight: .bold))
                                        Text(TWorkshop.catNames[i]).font(.jk(8, .heavy)).lineLimit(1)
                                    }
                                    .foregroundColor(cat == i ? LS.orange : .white.opacity(0.75))
                                    .padding(.horizontal, 7).frame(height: 22)
                                    .background(cat == i ? LS.orange.opacity(0.18) : Color.black.opacity(0.35))
                                    .overlay(Rectangle().stroke(cat == i ? LS.orange : LS.line, lineWidth: 1))
                                }
                                .buttonStyle(TuiPress())
                            }
                        }
                    }
                    .frame(height: 22)
                    HStack(alignment: .top, spacing: 6) {
                        ScrollView(showsIndicators: true) {
                            VStack(spacing: 2) {
                                ForEach(ids, id: \.self) { i in tileRow(i) }
                            }
                        }
                        .frame(width: palW, height: innerH - 26)
                        VStack(alignment: .leading, spacing: 5) {
                            Canvas { ctx, _ in
                                guard cells.count == mw * mh else { return }
                                for y in 0..<mh {
                                    for x in 0..<mw {
                                        drawTile(ctx, Int(cells[y * mw + x]), CGRect(x: CGFloat(x) * cs, y: CGFloat(y) * cs, width: cs, height: cs).insetBy(dx: 0.2, dy: 0.2))
                                    }
                                }
                            }
                            .frame(width: cs * CGFloat(mw), height: cs * CGFloat(mh))
                            .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    let x = Int(g.location.x / cs), y = Int(g.location.y / cs)
                                    guard x >= 0, y >= 0, x < mw, y < mh, cells.count == mw * mh else { return }
                                    if !stroke { stroke = true; mUndo = cells }
                                    cells[y * mw + x] = tile
                                }
                                .onEnded { _ in stroke = false; commitMap() })
                            HStack(spacing: 4) {
                                Menu {
                                    ForEach(TWorkshop.presetNames, id: \.self) { n in Button(n) { presetPick = n } }
                                } label: {
                                    HStack {
                                        Text(presetPick).font(.jk(9, .semibold)).foregroundColor(.white).lineLimit(1)
                                        Spacer(minLength: 2)
                                        SF("chevron.down").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 6).frame(maxWidth: .infinity).frame(height: 24).background(Color.black.opacity(0.45)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                                }
                                LSSmallButton(icon: "arrow.down.doc", label: "LOAD") { mUndo = cells; cells = TWorkshop.preset(presetPick); commitMap() }
                            }
                            .frame(width: cs * CGFloat(mw))
                            HStack(spacing: 4) {
                                LSSmallButton(icon: "trash", label: "CLEAR") { mUndo = cells; cells = [UInt8](repeating: 0, count: mw * mh); commitMap() }
                                LSSmallButton(icon: "arrow.uturn.backward", label: "UNDO") { if !mUndo.isEmpty { cells = mUndo; mUndo = []; commitMap() } }
                                Spacer(minLength: 0)
                                SF(tdef.icon, "circle.fill").font(.system(size: 8, weight: .bold)).foregroundColor(.white).frame(width: 15, height: 15).background(tdef.col)
                                Text(tdef.name).font(.jk(9, .heavy)).foregroundColor(LS.orange).lineLimit(1).minimumScaleFactor(0.6)
                            }
                            .frame(width: cs * CGFloat(mw))
                        }
                    }
                }
                .padding(6)
            }
            .frame(width: edW, height: ph).clipped()
            LSPanel(title: "MAP PREVIEW") {
                VStack(alignment: .leading, spacing: 5) {
                    ZStack(alignment: .bottomLeading) {
                        mapThumb(TWorkshop.cellsString(cells.count == mw * mh ? cells : TWorkshop.defaultMap()), prevW - 12, (prevW - 12) * 20 / 36)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(cur?.name ?? "").font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1)
                            Text("36 × 20 tiles").font(.jk(8, .medium)).foregroundColor(.white.opacity(0.75))
                        }
                        .padding(4).background(Color.black.opacity(0.55))
                    }
                    Button { commitMap(); playMap() } label: {
                        HStack(spacing: 6) {
                            SF("play.fill").font(.system(size: 11, weight: .bold))
                            Text("PLAY MAP").font(.jk(12, .heavy))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 30).background(LS.green)
                    }
                    .buttonStyle(TuiPress())
                    Text("MAP INFO").font(.jk(8, .heavy)).foregroundColor(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        SF("mappin.circle.fill").font(.system(size: 16)).foregroundColor(.white.opacity(0.7))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(cur?.name ?? "").font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1)
                            Text("By \(TacProfile.name)").font(.jk(8, .medium)).foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Text(cur?.desc ?? "").font(.jk(8, .medium)).foregroundColor(.white.opacity(0.65)).lineLimit(3)
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        LSSmallButton(icon: "square.and.arrow.up", label: "SHARE") {
                            if let m = cur { shareText = "MAINSHOT-MAP|\(m.name)|\(m.cells)"; showShare = true }
                        }
                    }
                }
                .padding(6)
            }
            .frame(width: prevW, height: ph).clipped()
        }
    }

    var body: some View {
        let W = size.width, H = size.height
        let top: CGFloat = 92
        let ph = H - top - 6
        return ZStack(alignment: .topLeading) {
            LSTitle(title: "WORKSHOP", sub: "Create custom guns and maps. Play your creations.").position(x: 14 + 170, y: 26)
            HStack(spacing: 4) {
                LSTab(icon: "scope", label: "GUNS", on: tab == 0) { tab = 0 }
                LSTab(icon: "map.fill", label: "MAPS", on: tab == 1) { tab = 1 }
                if !note.isEmpty { Text(note).font(.jk(9, .heavy)).foregroundColor(TUI.gold).padding(.leading, 8) }
            }
            .position(x: 8 + 150, y: 68)
            Group {
                if tab == 0 { gunsTab(W, ph) } else { mapsTab(W, ph) }
            }
            .frame(width: W - 16, height: ph, alignment: .topLeading)
            .position(x: W / 2, y: top + ph / 2)
            if rename {
                RenameOverlay(text: $renameText) { ok in
                    if ok && !renameText.isEmpty {
                        if renameTarget == 0, let i = gunIdx { guns[i].name = renameText; syncGuns() }
                        if renameTarget == 1, let i = mapIdx { maps[i].name = renameText; syncMaps() }
                    }
                    rename = false
                }
                .frame(width: W, height: H)
            }
        }
        .frame(width: W, height: H)
        .sheet(isPresented: $showShare) { ShareSheet(text: shareText) }
        .onAppear {
            for i in guns.indices where !TWorkshop.pxArray(guns[i].px).contains(where: { $0 != 0 }) { guns[i].px = TWorkshop.pxString(TWorkshop.starter()) }
            syncGuns()
            if guns.isEmpty { newGun() } else { loadGun(guns.first(where: { $0.id == gunId })?.id ?? guns[0].id) }
            maps = TWorkshop.maps
            loadMap(TWorkshop.currentMap.id)
        }
    }
}
