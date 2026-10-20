import SwiftUI
import UIKit

// MARK: - Attachment data

enum TAttSlot: String, CaseIterable {
    case mag, muzzle, optic, grip, camo
    var title: String {
        switch self { case .mag: return "MAGAZINE"; case .muzzle: return "MUZZLE"; case .optic: return "OPTIC"; case .grip: return "GRIP"; case .camo: return "CAMO" }
    }
    var icon: String {
        switch self { case .mag: return "rectangle.stack.fill"; case .muzzle: return "speaker.slash.fill"; case .optic: return "scope"; case .grip: return "hand.raised.fill"; case .camo: return "paintpalette.fill" }
    }
}

struct TAttDef {
    let id: String
    let slot: TAttSlot
    let name: String
    let desc: String
    let cost: Int
    var color: (CGFloat, CGFloat, CGFloat)? = nil
    var pat = 0
    var c2: (CGFloat, CGFloat, CGFloat)? = nil
    var c3: (CGFloat, CGFloat, CGFloat)? = nil
}

struct TAttMods {
    var magMul: CGFloat = 1
    var reloadMul: CGFloat = 1
    var recoilMul: CGFloat = 1
    var dmgMul: CGFloat = 1
    var rangeMul: CGFloat = 1
    var scopeMul: CGFloat = 1
    var silenced = false
    var zoomFOV: CGFloat = 26
}

enum TAtt {
    /// built-in parts and camos plus everything the player made in the lab
    static var defs: [TAttDef] { baseDefs + TAttCustom.camoDefs + TAttCustom.attDefs }

    static func visualId(_ id: String) -> String { TAttCustom.att(id)?.base ?? id }

    static let baseDefs: [TAttDef] = [
        TAttDef(id: "mag_ext", slot: .mag, name: "Extended Mag", desc: "+50% magazine, slightly slower reload", cost: 60),
        TAttDef(id: "mag_drum", slot: .mag, name: "Drum Mag", desc: "+100% magazine, much slower reload", cost: 150),
        TAttDef(id: "sil", slot: .muzzle, name: "Silencer", desc: "Quiet shots bots can't hear, no muzzle flash, -8% damage", cost: 100),
        TAttDef(id: "comp", slot: .muzzle, name: "Compensator", desc: "-25% recoil", cost: 60),
        TAttDef(id: "dot", slot: .optic, name: "Red Dot", desc: "Tighter spread when scoped, 2.5x zoom", cost: 50),
        TAttDef(id: "x4", slot: .optic, name: "4x Scope", desc: "Strong zoom, tight spread, +20% range", cost: 140),
        TAttDef(id: "vgrip", slot: .grip, name: "Vertical Grip", desc: "-30% recoil", cost: 60),
        TAttDef(id: "agrip", slot: .grip, name: "Angled Grip", desc: "-15% recoil, faster reload", cost: 60),
        TAttDef(id: "c_forest", slot: .camo, name: "Woodland", desc: "Layered green blotches", cost: 40, color: (0.2, 0.34, 0.14), pat: 1, c2: (0.34, 0.27, 0.13), c3: (0.08, 0.14, 0.07)),
        TAttDef(id: "c_desert", slot: .camo, name: "Desert Digital", desc: "Sand pixel pattern", cost: 40, color: (0.78, 0.64, 0.42), pat: 2, c2: (0.58, 0.45, 0.28), c3: (0.9, 0.8, 0.6)),
        TAttDef(id: "c_arctic", slot: .camo, name: "Arctic", desc: "Snow and slate blotches", cost: 40, color: (0.9, 0.93, 0.96), pat: 1, c2: (0.62, 0.68, 0.76), c3: (0.78, 0.83, 0.9)),
        TAttDef(id: "c_urban", slot: .camo, name: "Urban Digital", desc: "Grey city pixels", cost: 40, color: (0.38, 0.4, 0.44), pat: 2, c2: (0.22, 0.23, 0.26), c3: (0.55, 0.57, 0.6)),
        TAttDef(id: "c_tiger", slot: .camo, name: "Tiger Stripe", desc: "Orange and black stripes", cost: 60, color: (0.85, 0.42, 0.08), pat: 3, c2: (0.06, 0.06, 0.06), c3: (0.95, 0.6, 0.15)),
        TAttDef(id: "c_crimson", slot: .camo, name: "Crimson Splatter", desc: "Red paint splatter", cost: 60, color: (0.5, 0.05, 0.07), pat: 5, c2: (0.9, 0.12, 0.14), c3: (0.12, 0.02, 0.03)),
        TAttDef(id: "c_violet", slot: .camo, name: "Violet Storm", desc: "Purple splatter", cost: 60, color: (0.28, 0.1, 0.5), pat: 5, c2: (0.65, 0.35, 1.0), c3: (0.1, 0.04, 0.2)),
        TAttDef(id: "c_carbon", slot: .camo, name: "Carbon Fiber", desc: "Woven carbon finish", cost: 90, color: (0.07, 0.07, 0.08), pat: 4, c2: (0.2, 0.21, 0.23)),
        TAttDef(id: "c_neon", slot: .camo, name: "Neon Wave", desc: "Cyan and magenta stripes", cost: 90, color: (0.05, 0.85, 0.95), pat: 3, c2: (0.95, 0.1, 0.7), c3: (0.1, 0.1, 0.2)),
        TAttDef(id: "c_gold", slot: .camo, name: "Gold Plated", desc: "Solid gold finish", cost: 150, color: (1.0, 0.78, 0.22))
    ]

    static func def(_ id: String) -> TAttDef? { defs.first { $0.id == id } }

    private static let ownKey = "ms.att.own"
    private static let eqKey = "ms.att.eq"
    private static var ownCache: Set<String>? = nil
    private static var eqCache: [String: [String: String]]? = nil

    static var owned: Set<String> {
        if let c = ownCache { return c }
        let c = Set((UserDefaults.standard.array(forKey: ownKey) as? [String]) ?? [])
        ownCache = c
        return c
    }

    static var equipped: [String: [String: String]] {
        if let c = eqCache { return c }
        let c = (UserDefaults.standard.dictionary(forKey: eqKey) as? [String: [String: String]]) ?? [:]
        eqCache = c
        return c
    }

    static func own(_ id: String) {
        var o = owned
        o.insert(id)
        ownCache = o
        UserDefaults.standard.set(Array(o), forKey: ownKey)
    }

    /// gunsmith try-on: "<gun>|<slot>" -> id ("" = none); only set while the gunsmith is open
    static var pv: [String: String] = [:]

    static func eq(_ gun: String, _ slot: TAttSlot) -> String? {
        if let p = pv["\(gun)|\(slot.rawValue)"] { return p.isEmpty ? nil : p }
        return equipped[gun]?[slot.rawValue]
    }

    static func realEq(_ gun: String, _ slot: TAttSlot) -> String? { equipped[gun]?[slot.rawValue] }

    static func setEq(_ gun: String, _ slot: TAttSlot, _ id: String?) {
        var e = equipped
        var g = e[gun] ?? [:]
        if let id = id { g[slot.rawValue] = id } else { g.removeValue(forKey: slot.rawValue) }
        e[gun] = g
        eqCache = e
        UserDefaults.standard.set(e, forKey: eqKey)
    }

    static func mods(_ gun: String) -> TAttMods {
        var m = TAttMods()
        for s in TAttSlot.allCases {
            guard let id = eq(gun, s) else { continue }
            if let ca = TAttCustom.att(id) {
                m.magMul *= CGFloat(ca.mag); m.reloadMul *= CGFloat(ca.reload); m.recoilMul *= CGFloat(ca.recoil)
                m.dmgMul *= CGFloat(ca.dmg); m.rangeMul *= CGFloat(ca.range)
                if ca.silenced { m.silenced = true }
                if s == .optic { m.zoomFOV = CGFloat(ca.zoom); m.scopeMul = max(0.4, CGFloat(ca.zoom) / 26) }
                continue
            }
            switch id {
            case "mag_ext": m.magMul = 1.5; m.reloadMul *= 1.08
            case "mag_drum": m.magMul = 2; m.reloadMul *= 1.25
            case "sil": m.silenced = true; m.dmgMul *= 0.92
            case "comp": m.recoilMul *= 0.75
            case "dot": m.scopeMul = 0.8; m.zoomFOV = 22
            case "x4": m.scopeMul = 0.55; m.zoomFOV = 14; m.rangeMul = 1.2
            case "vgrip": m.recoilMul *= 0.7
            case "agrip": m.recoilMul *= 0.85; m.reloadMul *= 0.92
            default: break
            }
        }
        return m
    }

    static func camoColor(_ gun: String) -> Color? {
        guard let id = eq(gun, .camo), let c = def(id)?.color else { return nil }
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    /// recolours a gun material set (or restores it) to match the equipped camo
    static func applyCamo(_ gun: String, set: Int = 1) {
        let paint = ["poly", "tan", "olive", "bake"]
        let metals = ["steel", "blued"]
        let d = eq(gun, .camo).flatMap { def($0) }
        let sm = TwGunLib.sets[set]
        for k in paint + metals {
            guard let m = sm[k] else { continue }
            let isMetal = metals.contains(k)
            if let d = d, let c = d.color {
                if !isMetal, let img = TAttPattern.image(d) { m.diffuse.contents = img }
                else {
                    let f: CGFloat = isMetal ? (d.pat == 0 ? 1 : 0.55) : 1
                    m.diffuse.contents = UIColor(red: c.0 * f, green: c.1 * f, blue: c.2 * f, alpha: 1)
                }
            } else if let df = TwGunLib.defs[k]?["c"] as? [Double], df.count == 3 {
                m.diffuse.contents = UIColor(red: CGFloat(df[0]), green: CGFloat(df[1]), blue: CGFloat(df[2]), alpha: 1)
            }
        }
        // Blender-built guns: only the painted / polymer / wood parts take the camo, bare metal keeps its baked texture
        for (reg, regBase, dark) in [(TwGunLib.glbPaint, TwGunLib.glbPaintBase, false), (TwGunLib.glbMetal, TwGunLib.glbMetalBase, true)] {
            guard let pm = reg["\(gun)#\(set)"], let base = regBase["\(gun)#\(set)"] else { continue }
            for (i, m) in pm.enumerated() {
                if let d = d, let c = d.color {
                    if let img = TAttPattern.gunSkin(d, dark: dark) { m.diffuse.contents = img }
                    else { let f: CGFloat = dark ? 0.55 : 1; m.diffuse.contents = UIColor(red: c.0 * f, green: c.1 * f, blue: c.2 * f, alpha: 1) }
                } else if i < base.count, let b = base[i] { m.diffuse.contents = b }
            }
        }
    }

    /// puts the shared (bot / world) gun materials back to their stock colours
    static func resetCamo() {
        for k in ["poly", "tan", "olive", "bake", "steel", "blued"] {
            guard let m = TwGunLib.sets[0][k], let df = TwGunLib.defs[k]?["c"] as? [Double], df.count == 3 else { continue }
            m.diffuse.contents = UIColor(red: CGFloat(df[0]), green: CGFloat(df[1]), blue: CGFloat(df[2]), alpha: 1)
        }
    }

    static func viewSig(_ gun: String) -> String { [eq(gun, .camo) ?? "-", mods(gun).silenced ? "s" : "n", eq(gun, .optic) ?? "-", eq(gun, .grip) ?? "-", eq(gun, .mag) ?? "-"].joined(separator: "|") }
}

