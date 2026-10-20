import SwiftUI

enum TacCredits {
    static let text = "3D MODELS\n\"Makarov PM\" by Martin Trafas (https://sketchfab.com/TinoD2) is licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). Source: https://sketchfab.com/3d-models/makarov-pm-dbf03ce95c834cb7b07edba799dcd46a. Changes: cleaned up, re-oriented, split into slide / magazine / frame, converted to GLB. Distributed by AiZity (https://aizity.com).\n\nSpecial Task Force character: rigged model supplied by the project owner; re-posed and split into swappable parts."
}

enum TWeapons {
    struct W { let id: String; let name: String; let cls: String; let dmg: CGFloat; let interval: CGFloat; let mag: Int; let reload: CGFloat; let spread: CGFloat; let pellets: Int; let range: CGFloat; let price: Int }

    static let all: [W] = [
        W(id: "pistol", name: "G-18", cls: "pistol", dmg: 22, interval: 0.28, mag: 15, reload: 1.2, spread: 0.025, pellets: 1, range: 650, price: 0),
        W(id: "eagle", name: "EAGLE-50", cls: "pistol", dmg: 48, interval: 0.5, mag: 7, reload: 1.5, spread: 0.02, pellets: 1, range: 700, price: 700),
        W(id: "pm", name: "MAKAROV PM-S", cls: "pistol", dmg: 30, interval: 0.34, mag: 8, reload: 1.3, spread: 0.012, pellets: 1, range: 700, price: 500),
        W(id: "smg", name: "VX-9 SMG", cls: "smg", dmg: 14, interval: 0.075, mag: 30, reload: 1.6, spread: 0.05, pellets: 1, range: 520, price: 1200),
        W(id: "mp7", name: "MP-7", cls: "smg", dmg: 16, interval: 0.07, mag: 40, reload: 1.7, spread: 0.055, pellets: 1, range: 560, price: 1500),
        W(id: "p90", name: "P-90", cls: "smg", dmg: 13, interval: 0.06, mag: 50, reload: 2.0, spread: 0.06, pellets: 1, range: 500, price: 2350),
        W(id: "rifle", name: "AR-27", cls: "rifle", dmg: 24, interval: 0.12, mag: 30, reload: 2.0, spread: 0.02, pellets: 1, range: 1100, price: 2000),
        W(id: "ak", name: "AK-74X", cls: "rifle", dmg: 30, interval: 0.14, mag: 30, reload: 2.2, spread: 0.026, pellets: 1, range: 1100, price: 2700),
        W(id: "m4", name: "M4-CQ", cls: "rifle", dmg: 25, interval: 0.1, mag: 30, reload: 2.0, spread: 0.018, pellets: 1, range: 1100, price: 3100),
        W(id: "shotgun", name: "BREACHER", cls: "shotgun", dmg: 11, interval: 0.9, mag: 6, reload: 2.4, spread: 0.09, pellets: 8, range: 320, price: 1800),
        W(id: "pump", name: "PUMP-12", cls: "shotgun", dmg: 14, interval: 1.0, mag: 8, reload: 2.6, spread: 0.08, pellets: 8, range: 340, price: 1200),
        W(id: "awp", name: "AWP-X", cls: "sniper", dmg: 105, interval: 1.5, mag: 5, reload: 2.8, spread: 0.004, pellets: 1, range: 2200, price: 4750)
    ]

    static func w(_ id: String) -> W { all.first { $0.id == id } ?? all[0] }
    static func cls(_ id: String) -> String { w(id).cls }
    static func isPistol(_ id: String) -> Bool { cls(id) == "pistol" }
    /// model / icon id used by the viewmodel rigs and sprites
    /// each weapon has its own first-person model
    static func model(_ id: String) -> String { all.contains { $0.id == id } ? id : "pistol" }
    static func recoil(_ id: String) -> Float {
        switch cls(id) { case "pistol": return 1.0; case "smg": return 0.45; case "rifle": return 0.7; case "shotgun": return 1.6; default: return 1.9 }
    }
    static func rig(_ id: String) -> String { let c = cls(id); return c == "sniper" ? "rifle" : c }

    static let ladder = ["pistol", "eagle", "pump", "mp7", "p90", "ak", "m4", "awp"]
    static let modeNames = ["BOMB DEFUSAL", "TEAM DEATHMATCH", "KILL CONFIRMED", "ARMS RACE", "FREE FOR ALL", "CONTROL POINT", "EXTRACTION", "FRONTLINE"]
    static let modeShort = ["DEFUSE", "TDM", "KILL CONF", "ARMS", "FFA", "CONTROL", "ROYALE", "FRONT"]
}
