import SwiftUI
import UIKit

// MARK: - Operator kits: modular gear that is swapped onto the shared 3D soldier

/// One operator loadout. Every slot can be overridden from the customize screen (see `TacGear.resolve`).
struct TacKit {
    var name: String
    var uni: UInt32          // uniform
    var pants: UInt32
    var boots: UInt32
    var glove: UInt32
    var rigCol: UInt32       // chest rig / plate carrier
    var accent: UInt32       // scarf, flaps, patches
    var camo: Bool
    var helmet = 0           // see TacGear.helmetNames
    var face = 0             // see TacGear.faceNames
    var eyes = 0             // see TacGear.eyeNames
    var rig = 0              // see TacGear.rigNames
    var glv = 1              // see TacGear.gloveNames
    var pack = 0             // 0 none, 1 radio, 2 assault pack, 3 medic pack, 4 bedroll pack, 5 cape
    var headset = false
    var knee = true
    var holster = false
    var bulk: CGFloat = 1    // body width multiplier (silhouette)
    var tall: CGFloat = 1
    var cross = false        // medic markings
    // Special Task Force preset (what the Blender operator wears)
    var sBody = 0, sGear = 0, sHelmCol = 0, sHead = 2, sFace = 0, sLens = 1
    var sVest = true
}

enum TacGear {
    static let helmetNames = ["NONE", "HIGH-CUT", "BALLISTIC", "BOONIE", "CAP", "BEANIE", "HOOD"]
    static let faceNames = ["NONE", "BALACLAVA", "GAITER", "SKULL", "SHEMAGH", "FULL MASK"]
    static let eyeNames = ["NONE", "GOGGLES", "GLASSES", "NVG"]
    static let rigNames = ["NONE", "PLATE CARRIER", "CHEST RIG", "HEAVY ARMOR", "MEDIC RIG"]
    static let gloveNames = ["BARE", "TACTICAL", "PADDED", "FINGERLESS"]
    // Special Task Force operator options (index = texture variant in stf_*_<i>.jpg)
    static let stfBodyNames = ["STANDARD", "DESERT", "WOODLAND", "URBAN", "ARCTIC", "NIGHT", "CRIMSON"]
    static let stfGearNames = ["COYOTE", "OLIVE", "BLACK", "GREY", "NAVY"]
    static let stfHeadNames = ["BARE HEAD", "HELMET", "HELMET + NVG"]
    static let stfHelmColNames = ["COYOTE", "OLIVE", "BLACK", "GREY", "WHITE"]
    static let stfFaceNames = ["STANDARD", "FAIR", "TAN", "DEEP", "WOODLAND PAINT", "NIGHT PAINT", "SCARRED"]
    static let stfLensNames = ["NONE", "SMOKE", "AMBER", "BLUE", "RED"]
    static let stfLens: [UInt32] = [0x000000, 0x08080A, 0x8C520D, 0x0D2666, 0x800D0A]
    /// SKINS row -> (uniform, vest, helmet colour)
    static let stfSkin: [(Int, Int, Int)] = [(0, 0, 0), (2, 1, 1), (1, 0, 0), (3, 3, 3), (5, 2, 2), (4, 3, 4)]

    static let kits: [TacKit] = [
        TacKit(name: "ASSAULT", uni: 0x4B5236, pants: 0x3E4630, boots: 0x1E1712, glove: 0x1A1A1A, rigCol: 0x3A3D32, accent: 0x1A1A1A, camo: true,
               helmet: 1, face: 1, eyes: 1, rig: 1, glv: 1, pack: 1, headset: true, knee: true, holster: false, bulk: 1.0,
               sBody: 0, sGear: 0, sHelmCol: 0, sHead: 2, sFace: 0, sLens: 1),
        TacKit(name: "BREACHER", uni: 0x1D1F22, pants: 0x17181A, boots: 0x0E0E10, glove: 0x111214, rigCol: 0x24262A, accent: 0x6B6F76, camo: false,
               helmet: 2, face: 5, eyes: 0, rig: 3, glv: 2, pack: 0, headset: false, knee: true, holster: true, bulk: 1.14, tall: 1.02,
               sBody: 5, sGear: 2, sHelmCol: 2, sHead: 1, sFace: 5, sLens: 1),
        TacKit(name: "RECON", uni: 0x56603C, pants: 0x4A5233, boots: 0x3A2E20, glove: 0x2A2A24, rigCol: 0x4A4F36, accent: 0x6B6246, camo: true,
               helmet: 3, face: 2, eyes: 2, rig: 2, glv: 3, pack: 5, headset: false, knee: false, holster: false, bulk: 0.92,
               sBody: 2, sGear: 1, sHelmCol: 1, sHead: 1, sFace: 4, sLens: 0),
        TacKit(name: "MARKSMAN", uni: 0x9C8A63, pants: 0x8A7B5A, boots: 0x8B6B3A, glove: 0x6B5B3E, rigCol: 0x7A6B4A, accent: 0xC9B98A, camo: true,
               helmet: 4, face: 4, eyes: 2, rig: 2, glv: 3, pack: 4, headset: false, knee: true, holster: false, bulk: 0.95,
               sBody: 1, sGear: 0, sHelmCol: 0, sHead: 1, sFace: 2, sLens: 2),
        TacKit(name: "MEDIC", uni: 0x3F4A3A, pants: 0x38402F, boots: 0x1E1712, glove: 0x1A1A1A, rigCol: 0x4A5A3A, accent: 0xB02A24, camo: false,
               helmet: 1, face: 0, eyes: 2, rig: 4, glv: 1, pack: 3, headset: true, knee: true, holster: false, bulk: 1.02, cross: true,
               sBody: 4, sGear: 3, sHelmCol: 4, sHead: 1, sFace: 1, sLens: 0),
        TacKit(name: "SUPPORT", uni: 0x5A5640, pants: 0x4B4834, boots: 0x2A2118, glove: 0x2D2A22, rigCol: 0x4A4630, accent: 0x2A2A24, camo: true,
               helmet: 1, face: 2, eyes: 0, rig: 1, glv: 2, pack: 2, headset: true, knee: true, holster: true, bulk: 1.18,
               sBody: 0, sGear: 1, sHelmCol: 3, sHead: 1, sFace: 3, sLens: 0),
        TacKit(name: "SPECTRE", uni: 0x16171A, pants: 0x121315, boots: 0x0A0A0B, glove: 0x0E0E10, rigCol: 0x1E2024, accent: 0xE8E6DC, camo: false,
               helmet: 6, face: 3, eyes: 3, rig: 2, glv: 1, pack: 0, headset: false, knee: false, holster: false, bulk: 0.9, tall: 1.03,
               sBody: 5, sGear: 4, sHelmCol: 2, sHead: 2, sFace: 6, sLens: 4),
        TacKit(name: "URBAN", uni: 0x5D6168, pants: 0x3C3F45, boots: 0x1A1A1C, glove: 0x1A1A1A, rigCol: 0x2D3036, accent: 0xE8731A, camo: false,
               helmet: 1, face: 1, eyes: 1, rig: 1, glv: 1, pack: 1, headset: false, knee: true, holster: true, bulk: 1.04,
               sBody: 3, sGear: 3, sHelmCol: 3, sHead: 1, sFace: 1, sLens: 1)
    ]

    /// uniform / pants / rig / glove palettes the SKINS row recolours a kit with (index 0 keeps the kit's own colours)
    static let skins: [(name: String, uni: UInt32, pants: UInt32, rig: UInt32, glove: UInt32, camo: Bool)] = [
        ("DEFAULT", 0, 0, 0, 0, false),
        ("WOODLAND", 0x4B5236, 0x3E4630, 0x3A3D32, 0x2A2A24, true),
        ("DESERT", 0x9C8A63, 0x8A7B5A, 0x7A6B4A, 0x6B5B3E, true),
        ("URBAN", 0x5D6168, 0x3C3F45, 0x2D3036, 0x1A1A1A, false),
        ("BLACK", 0x1D1F22, 0x17181A, 0x222428, 0x0E0E10, false),
        ("SNOW", 0xD8DADC, 0xC8CBCE, 0x9AA0A6, 0x8A8F94, false)
    ]

    /// 1-based kit of a look; anything outside the list (the retired civilian outfit, never chosen) is the first operator
    static func kitIndex(_ l: AvatarLook) -> Int {
        let n = l.kit ?? 0
        return (n >= 1 && n <= kits.count) ? n : 1
    }

    private static var swImgs: [String: UIImage?] = [:]
    /// small texture crop for the customize cards ("stfsw_<kind>_<i>.png")
    static func swatch(_ kind: String, _ i: Int) -> UIImage? {
        let key = "stfsw_\(kind)_\(i)"
        if let c = swImgs[key] { return c }
        var img: UIImage? = nil
        if let u = Bundle.main.url(forResource: key, withExtension: "png") { img = UIImage(contentsOfFile: u.path) }
        swImgs[key] = img
        return img
    }

    /// The kit a look is wearing (nil = old civilian-style outfit), with the player's slot overrides applied.
    static func resolve(_ l: AvatarLook) -> TacKit? {
        let n = kitIndex(l)
        var k = kits[n - 1]
        if let s = l.kSkin, s >= 1 && s < skins.count {
            let p = skins[s]
            k.uni = p.uni; k.pants = p.pants; k.rigCol = p.rig; k.glove = p.glove; k.camo = p.camo
            if s < stfSkin.count { k.sBody = stfSkin[s].0; k.sGear = stfSkin[s].1; k.sHelmCol = stfSkin[s].2 }
        }
        if let v = l.sBody { k.sBody = max(0, min(stfBodyNames.count - 1, v)) }
        if let v = l.sGear { k.sGear = max(0, min(stfGearNames.count - 1, v)) }
        if let v = l.sVest { k.sVest = v }
        if let v = l.sHead { k.sHead = max(0, min(stfHeadNames.count - 1, v)) }
        if let v = l.sHelmCol { k.sHelmCol = max(0, min(stfHelmColNames.count - 1, v)) }
        if let v = l.sFace { k.sFace = max(0, min(stfFaceNames.count - 1, v)) }
        if let v = l.sLens { k.sLens = max(0, min(stfLensNames.count - 1, v)) }
        if let v = l.kHelm { k.helmet = max(0, min(helmetNames.count - 1, v)) }
        if let v = l.kFace { k.face = max(0, min(faceNames.count - 1, v)) }
        if let v = l.kEyes { k.eyes = max(0, min(eyeNames.count - 1, v)) }
        if let v = l.kRig { k.rig = max(0, min(rigNames.count - 1, v)) }
        if let v = l.kGlove { k.glv = max(0, min(gloveNames.count - 1, v)) }
        if k.rig == 4 { k.cross = true } else if l.kRig != nil { k.cross = false }
        return k
    }

    /// colours the first-person arms use: (sleeve, glove). nil glove = bare skin.
    static func fpColors(_ l: AvatarLook, skin: UIColor) -> (sleeve: UIColor, glove: UIColor, fingers: UIColor?)? {
        guard let k = resolve(l) else { return nil }
        let g = k.glv == 0 ? skin : c(k.glove)
        // tactical / padded gloves cover the fingers; fingerless and bare keep the skin texture
        let f: UIColor? = (k.glv == 1 || k.glv == 2) ? c(k.glove) : nil
        return (c(k.uni), g, f)
    }

    // MARK: helpers

    static func c(_ v: UInt32) -> UIColor { TacAvatar.ui(v) }

    static func shade(_ col: UIColor, _ f: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        col.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(1, r * f), green: min(1, g * f), blue: min(1, b * f), alpha: 1)
    }

    @discardableResult
    private static func bx(_ p: MXNode, _ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ col: UIColor,
                           rx: Float = 0, ry: Float = 0, rz: Float = 0) -> MXNode {
        let n = TwRig.box(w, h, l, col)
        n.position = MXVector3(Float(x), Float(y), Float(z))
        if rx != 0 || ry != 0 || rz != 0 { n.eulerAngles = MXVector3(rx, ry, rz) }
        p.addChildNode(n)
        return n
    }

    @discardableResult
    private static func bl(_ p: MXNode, _ r: CGFloat, _ sx: Float, _ sy: Float, _ sz: Float, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ col: UIColor) -> MXNode {
        let n = TwRig.ball(r, col)
        n.scale = MXVector3(sx, sy, sz)
        n.position = MXVector3(Float(x), Float(y), Float(z))
        p.addChildNode(n)
        return n
    }

    /// cylinder whose axis points along x (forward) or z (sideways) instead of y
    @discardableResult
    private static func cy(_ p: MXNode, _ r: CGFloat, _ h: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, _ col: UIColor, axis: Character = "y") -> MXNode {
        let n = TwRig.cyl(r, h, col)
        n.position = MXVector3(Float(x), Float(y), Float(z))
        if axis == "x" { n.eulerAngles = MXVector3(0, 0, Float.pi / 2) }
        if axis == "z" { n.eulerAngles = MXVector3(Float.pi / 2, 0, 0) }
        p.addChildNode(n)
        return n
    }

    // MARK: torso gear (chest rig, plates, pouches, back items)

    /// `roleN` is the z-scaled node on the torso (x forward, y up, z sideways, chest front at x ≈ 5).
    static func dressTorso(_ k: TacKit, roleN: MXNode, team: UIColor) {
        let rc = c(k.rigCol), dk = shade(rc, 0.62), lt = shade(rc, 1.28), ac = c(k.accent)
        let webbing = shade(rc, 0.45)
        switch k.rig {
        case 1, 4:   // plate carrier: plates, cummerbund, shoulder straps, 3 mag pouches, molle rows
            bx(roleN, 1.8, 8.8, 10.2, 5.0, 26.6, 0, rc)
            bx(roleN, 1.8, 9.0, 10.2, -4.7, 26.6, 0, rc)
            for z in [-4.7, 4.7] as [CGFloat] {
                bx(roleN, 9.8, 1.0, 2.4, 0.1, 31.7, z, dk)                   // shoulder strap
                bx(roleN, 1.2, 4.0, 2.2, 5.3, 30.0, z * 0.9, dk)             // front strap drop
            }
            bx(roleN, 10.6, 3.6, 14.4, 0, 21.4, 0, rc)                       // cummerbund
            for y in [24.8, 26.6, 28.4] as [CGFloat] { bx(roleN, 0.3, 0.38, 9.0, 5.98, y, 0, webbing) }   // molle rows
            if k.rig == 1 {
                for z in [-3.6, 0, 3.6] as [CGFloat] {
                    bx(roleN, 1.8, 3.8, 2.8, 6.0, 22.4, z, dk)               // mag pouch
                    bx(roleN, 1.95, 0.8, 2.9, 6.0, 24.1, z, lt)              // flap
                    bx(roleN, 0.4, 1.2, 1.2, 7.0, 23.0, z, ac)               // pull tab
                }
                bx(roleN, 2.6, 3.4, 3.6, 1.0, 21.6, 7.9, dk)                 // dump pouch on the hip
                bx(roleN, 2.6, 3.4, 3.6, 1.0, 21.6, -7.9, dk)
            } else {
                bx(roleN, 2.2, 5.6, 4.8, 6.0, 23.4, -3.3, dk)                // med pouch
                bx(roleN, 2.3, 0.9, 4.9, 6.0, 26.3, -3.3, lt)
                bx(roleN, 1.8, 3.6, 2.6, 6.0, 22.4, 2.6, dk)                 // tourniquet / mag
                bx(roleN, 1.95, 0.8, 2.7, 6.0, 24.1, 2.6, lt)
            }
            bx(roleN, 0.3, 1.3, 2.4, 6.0, 29.6, 3.4, ac)                     // id patch
            bx(roleN, 0.3, 1.1, 2.0, 6.0, 29.7, -3.6, team)                  // team tag
        case 2:      // slim chest rig: panel + 4 mag pouches, thin straps
            bx(roleN, 1.6, 5.8, 10.6, 5.1, 25.0, 0, rc)
            for z in [-3.9, -1.3, 1.3, 3.9] as [CGFloat] {
                bx(roleN, 1.8, 3.4, 2.3, 5.9, 25.2, z, dk)
                bx(roleN, 1.95, 0.7, 2.4, 5.9, 26.8, z, lt)
            }
            for z in [-4.2, 4.2] as [CGFloat] { bx(roleN, 9.2, 0.8, 1.6, 0.1, 31.6, z, dk) }
            bx(roleN, 10.2, 1.0, 14.2, 0, 22.2, 0, dk)
            bx(roleN, 0.3, 1.2, 2.2, 6.0, 28.6, 3.6, team)
        case 3:      // heavy armor: big plates, side plates, shoulder pads, collar, groin guard
            bx(roleN, 2.2, 9.8, 11.2, 5.1, 26.2, 0, rc)
            bx(roleN, 2.0, 10.0, 11.2, -4.8, 26.2, 0, rc)
            for z in [-6.7, 6.7] as [CGFloat] { bx(roleN, 7.8, 8.0, 1.5, 0, 26.0, z, dk) }
            for z in [-8.3, 8.3] as [CGFloat] {
                bx(roleN, 4.4, 2.6, 5.0, 0, 32.6, z, rc, rx: z > 0 ? -0.2 : 0.2)   // shoulder pad
                bx(roleN, 4.0, 0.8, 4.6, 0, 33.9, z, dk, rx: z > 0 ? -0.2 : 0.2)
            }
            bx(roleN, 4.2, 1.8, 9.6, 0, 33.3, 0, dk)                         // collar
            bx(roleN, 1.8, 4.4, 5.6, 5.4, 16.0, 0, rc)                       // groin guard
            for z in [-3.6, 0, 3.6] as [CGFloat] { bx(roleN, 1.6, 3.2, 2.6, 6.4, 21.8, z, dk) }
            bx(roleN, 0.3, 2.0, 9.6, 6.3, 29.4, 0, ac)                       // hazard stripe
        default: break
        }
        if k.cross {
            let red = c(0xB02A24), wh = UIColor(white: 0.95, alpha: 1)
            for (x, sgn) in [(6.05, 1.0), (-5.75, -1.0)] as [(CGFloat, CGFloat)] {
                bx(roleN, 0.3, 3.8, 3.8, x, 27.6, 3.2 * sgn, wh)
                bx(roleN, 0.4, 2.8, 0.9, x + 0.1 * sgn, 27.6, 3.2 * sgn, red)
                bx(roleN, 0.4, 0.9, 2.8, x + 0.1 * sgn, 27.6, 3.2 * sgn, red)
            }
        }
        // back items (the silhouette seen from behind)
        switch k.pack {
        case 1:  // radio pouch + antenna
            bx(roleN, 2.4, 5.2, 3.4, -6.4, 27.0, -3.8, dk)
            cy(roleN, 0.28, 13, -6.9, 33.6, -4.2, UIColor(white: 0.08, alpha: 1))
        case 2:  // assault pack
            bx(roleN, 5.4, 10.4, 10.8, -7.4, 25.8, 0, dk)
            bx(roleN, 2.6, 5.4, 9.6, -10.4, 24.6, 0, rc)
            bx(roleN, 5.6, 0.8, 11.0, -7.4, 28.8, 0, lt)
            cy(roleN, 1.2, 11.4, -7.4, 32.6, 0, ac, axis: "z")
        case 3:  // medic pack with cross
            bx(roleN, 5.0, 9.6, 9.6, -7.2, 25.6, 0, dk)
            bx(roleN, 0.3, 4.4, 4.4, -9.8, 26.4, 0, UIColor(white: 0.95, alpha: 1))
            bx(roleN, 0.4, 3.4, 1.0, -9.9, 26.4, 0, c(0xB02A24))
            bx(roleN, 0.4, 1.0, 3.4, -9.9, 26.4, 0, c(0xB02A24))
        case 4:  // bedroll pack
            bx(roleN, 3.6, 8.0, 8.4, -6.6, 25.2, 0, dk)
            cy(roleN, 1.9, 10.6, -7.6, 31.4, 0, ac, axis: "z")
        case 5:  // cape / ghillie scrap
            bx(roleN, 0.7, 11.0, 11.6, -5.6, 24.6, 0, shade(c(k.uni), 0.82), rz: 0.06)
            for z in [-4.2, -1.4, 1.4, 4.2] as [CGFloat] { bx(roleN, 0.5, 6.0, 0.9, -6.1, 18.0, z, shade(c(k.uni), 0.7), rz: 0.1) }
        default: break
        }
    }

    // MARK: legs

    static func dressLeg(_ k: TacKit, hip: MXNode, index: Int) {
        let pantsC = c(k.pants), dk = shade(c(k.rigCol), 0.6), ac = c(k.accent)
        if k.knee {
            bx(hip, 2.2, 4.6, 4.9, 2.6, -10.9, 0, dk)                        // knee pad
            bx(hip, 0.6, 3.2, 3.7, 3.8, -10.9, 0, shade(dk, 1.4))
            bx(hip, 3.0, 0.8, 5.4, 1.6, -9.0, 0, dk)                         // upper strap
            bx(hip, 3.0, 0.8, 5.4, 1.6, -13.0, 0, dk)
        }
        cy(hip, 2.82, 1.3, 0.1, -17.6, 0, pantsC)                            // bloused cuff
        bx(hip, 0.4, 3.4, 1.2, 2.6, -19.8, 0, UIColor(white: 0.55, alpha: 1))   // laces
        bx(hip, 1.2, 0.9, 5.2, 0.4, -18.4, 0, shade(c(k.boots), 0.8))       // boot collar strap
        if k.holster && index == 1 {
            bx(hip, 1.6, 5.8, 2.2, 0.6, -5.2, 3.6, shade(c(k.rigCol), 0.5)) // drop-leg holster
            bx(hip, 1.7, 0.8, 2.3, 0.6, -2.3, 3.6, ac)
            bx(hip, 0.8, 0.8, 4.8, 0.5, -3.0, 0, shade(c(k.rigCol), 0.5))   // leg strap
        }
        if k.pack == 1 && index == 0 {
            bx(hip, 1.4, 4.0, 3.4, 2.7, -6.0, 0, shade(pantsC, 0.8))        // cargo pocket
        }
    }

    // MARK: head gear

    /// helmet-mounted gear lives in `hat` (hidden together with the armor helmet); face coverings stay on the head.
    static func dressHead(_ k: TacKit, head: MXNode, hat: MXNode, team: UIColor) {
        let uni = c(k.uni), dk = shade(c(k.rigCol), 0.55), ac = c(k.accent)
        let hcol: UIColor = k.camo ? shade(uni, 0.9) : shade(uni, 1.1)
        let black = UIColor(white: 0.06, alpha: 1)
        // ---- helmets and hats
        switch k.helmet {
        case 1:   // high-cut ops helmet with rails, NVG shroud, counterweight
            bl(hat, 5.5, 1.02, 0.74, 1.0, 0.1, 38.7, 0, hcol)
            for z in [-5.2, 5.2] as [CGFloat] { bx(hat, 6.6, 0.7, 0.7, 0.3, 38.0, z, black) }
            bx(hat, 1.5, 2.0, 3.4, 5.5, 40.0, 0, black)
            bx(hat, 1.8, 2.6, 4.8, -4.6, 38.2, 0, dk)
            bx(hat, 0.5, 0.6, 5.0, 5.0, 38.1, 0, shade(hcol, 0.7))
        case 2:   // full ballistic with ear guards, brow ridge and a tinted visor
            bl(hat, 5.75, 1.05, 0.82, 1.05, 0.0, 38.4, 0, hcol)
            for z in [-5.5, 5.5] as [CGFloat] { bx(hat, 3.6, 4.0, 1.0, 0.0, 35.0, z, shade(hcol, 0.85)) }
            bx(hat, 1.5, 1.0, 8.0, 5.4, 38.6, 0, shade(hcol, 0.8))
            bx(hat, 1.0, 3.6, 7.4, 5.3, 36.8, 0, UIColor(red: 0.08, green: 0.12, blue: 0.16, alpha: 1), rz: -0.1)
            bx(hat, 1.4, 1.6, 2.6, 5.5, 40.4, 0, black)
        case 3:   // boonie
            cy(hat, 7.0, 0.4, 0.2, 38.4, 0, hcol)
            cy(hat, 4.6, 2.8, 0.1, 39.7, 0, hcol)
            cy(hat, 4.75, 0.9, 0.1, 38.9, 0, ac)
        case 4:   // cap
            bl(hat, 4.95, 1.0, 0.62, 1.0, 0.0, 39.0, 0, hcol)
            bx(hat, 3.6, 0.4, 6.6, 5.3, 38.4, 0, shade(hcol, 0.8), rz: -0.16)
        case 5:   // beanie
            bl(hat, 4.95, 1.0, 0.86, 1.0, 0.0, 38.7, 0, hcol)
            cy(hat, 4.85, 1.3, 0.1, 37.2, 0, shade(hcol, 0.78))
        case 6:   // hood
            bl(hat, 5.7, 1.06, 1.0, 1.06, -0.6, 37.6, 0, hcol)
            bx(hat, 1.0, 1.0, 8.6, 4.9, 38.8, 0, shade(hcol, 0.75), rz: -0.2)
        default: break
        }
        if k.helmet == 1 || k.helmet == 2 {
            if k.cross {
                for z in [-5.5, 5.5] as [CGFloat] {
                    bx(hat, 2.8, 2.8, 0.3, 0.3, 38.8, z * 1.0, UIColor(white: 0.95, alpha: 1))
                    bx(hat, 2.2, 0.7, 0.4, 0.3, 38.8, z * 1.02, c(0xB02A24))
                    bx(hat, 0.7, 2.2, 0.4, 0.3, 38.8, z * 1.02, c(0xB02A24))
                }
            }
        }
        if k.headset && k.helmet != 2 {
            for z in [-5.0, 5.0] as [CGFloat] {
                cy(hat, 2.0, 1.4, 0.2, 35.9, z, black, axis: "z")
                bx(hat, 1.0, 0.8, 0.6, 0.2, 38.2, z * 0.98, black)
            }
            let mic = TwRig.limb((2.2, 35.0, 5.1), (5.0, 33.0, 2.5), 0.28, 0.24, TwRig.mat(black))
            hat.addChildNode(mic)
            bl(hat, 0.5, 1, 1, 1, 5.0, 33.0, 2.5, black)
        }
        // ---- eyewear
        switch k.eyes {
        case 1:   // goggles: strap ring, frame, tinted lens
            cy(head, 4.95, 1.6, 0.35, 36.6, 0, dk)
            bx(head, 1.6, 2.8, 8.4, 4.9, 36.6, 0, black)
            bx(head, 0.5, 2.0, 7.4, 5.7, 36.6, 0, UIColor(red: 0.85, green: 0.55, blue: 0.12, alpha: 1))
        case 2:   // shooting glasses
            for z in [-2.2, 2.2] as [CGFloat] { bx(head, 0.5, 1.5, 3.0, 4.8, 36.0, z, UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)) }
            bx(head, 0.5, 0.35, 1.4, 4.8, 36.3, 0, black)
            for z in [-4.2, 4.2] as [CGFloat] { bx(head, 4.0, 0.35, 0.35, 2.6, 36.2, z, black) }
        case 3:   // NVG on the front of the helmet, tubes glowing
            bx(hat, 2.2, 2.5, 4.8, 5.5, 39.4, 0, black)
            for z in [-1.4, 1.4] as [CGFloat] {
                cy(hat, 0.95, 1.8, 6.5, 39.4, z, black, axis: "x")
                let lens = TwRig.box(0.3, 1.2, 1.2, UIColor(red: 0.2, green: 1.0, blue: 0.4, alpha: 1), glow: true)
                lens.position = MXVector3(7.5, 39.4, Float(z))
                hat.addChildNode(lens)
            }
        default: break
        }
        // ---- face coverings (lower face; the 2D face texture stays visible above)
        let fc: UIColor = k.face == 3 ? UIColor(red: 0.91, green: 0.9, blue: 0.86, alpha: 1) : (k.face == 4 ? ac : shade(uni, k.face == 5 ? 0.35 : 0.5))
        switch k.face {
        case 1, 2, 3, 4:
            bl(head, 4.95, 0.98, 0.5, 0.97, 0.3, 32.6, 0, fc)
            bx(head, 1.0, 2.2, 2.8, 4.4, 34.2, 0, fc)                         // nose bridge
            if k.face == 2 || k.face == 4 { cy(head, 3.4, 3.6, 0.3, 30.4, 0, fc) }   // neck tube
            if k.face == 4 { bx(head, 0.7, 7.0, 2.6, 2.4, 28.4, 2.6, shade(ac, 0.88), rz: -0.08) }   // hanging tail
            if k.face == 3 {
                let tooth = UIColor(white: 0.07, alpha: 1)
                bx(head, 0.3, 0.45, 6.0, 4.95, 32.0, 0, tooth)
                for z in [-2.2, -0.7, 0.7, 2.2] as [CGFloat] { bx(head, 0.3, 1.7, 0.4, 4.95, 32.0, z, tooth) }
                bx(head, 0.3, 0.9, 1.0, 4.9, 34.0, 0, tooth)
            }
        case 5:   // full mask: dark shell, glass eye slit, filter cans
            bl(head, 4.9, 0.98, 1.0, 0.97, 0.3, 35.5, 0, shade(uni, 0.3))
            bx(head, 0.5, 1.6, 6.6, 5.0, 36.2, 0, UIColor(red: 0.1, green: 0.13, blue: 0.16, alpha: 1))
            for z in [-2.4, 2.4] as [CGFloat] { cy(head, 1.25, 1.8, 5.3, 32.6, z, UIColor(white: 0.14, alpha: 1), axis: "x") }
        default: break
        }
    }

    // MARK: hands

    /// A gloved hand for the 3D soldier (the FP arms use the same colour via `fpColors`).
    static func hand(_ k: TacKit, skin: UIColor, at p: (CGFloat, CGFloat, CGFloat), into root: MXNode) {
        let gcol = c(k.glove)
        let dark = shade(gcol, 0.6)
        let node = MXNode()
        node.position = MXVector3(Float(p.0), Float(p.1), Float(p.2))
        root.addChildNode(node)
        switch k.glv {
        case 0:   // bare hand with a wrist band
            bl(node, 1.85, 1, 1, 1, 0, 0, 0, skin)
            cy(node, 1.9, 1.0, -1.3, 0, 0, dark)
        case 2:   // padded: big palm, hard knuckle shell, long cuff
            bl(node, 2.2, 1, 1, 1, 0, 0, 0, gcol)
            bl(node, 1.4, 1.5, 0.8, 1.2, 1.5, 0, 0, gcol)
            bx(node, 1.2, 0.8, 3.0, 0.7, 1.4, 0, dark)
            cy(node, 2.1, 1.8, -1.6, 0, 0, gcol)
            bx(node, 0.5, 0.6, 3.6, -0.8, 1.6, 0, shade(gcol, 1.5))
        case 3:   // fingerless: skin fingers, glove palm and knuckle strip
            bl(node, 1.85, 1, 1, 1, 0, 0, 0, skin)
            bl(node, 1.9, 0.8, 0.9, 1.0, -0.2, -0.2, 0, gcol)
            bx(node, 0.9, 0.5, 2.8, 0.4, 0.6, 0, dark)
            cy(node, 1.95, 1.2, -1.4, 0, 0, gcol)
        default:  // tactical: palm, fingers, knuckle guard, cuff
            bl(node, 1.95, 1, 1, 1, 0, 0, 0, gcol)
            bl(node, 1.2, 1.5, 0.8, 1.2, 1.4, 0, 0, gcol)
            bx(node, 1.0, 0.6, 2.4, 0.6, 1.3, 0, dark)
            cy(node, 2.05, 1.5, -1.4, 0, 0, gcol)
            bx(node, 0.4, 0.5, 3.0, -0.9, 1.5, 0, shade(gcol, 1.6))
        }
    }

    // MARK: lobby labels / thumbnails

    private static var opImgs: [String: UIImage?] = [:]
    /// Blender-rendered operator portrait ("op_<name>.png" bust, "opf_<name>.png" full body); nil if not bundled
    static func opImage(_ name: String, full: Bool = false) -> UIImage? {
        let key = (full ? "opf_" : "op_") + name.lowercased()
        if let c = opImgs[key] { return c }
        var img: UIImage? = nil
        if let u = Bundle.main.url(forResource: key, withExtension: "png") { img = UIImage(contentsOfFile: u.path) }
        opImgs[key] = img
        return img
    }

    static func icon(_ kind: Int, _ i: Int) -> String {
        switch kind {
        case 0: return ["nosign", "shield.fill", "shield.lefthalf.filled", "sun.max.fill", "capsule.fill", "circle.fill", "person.crop.circle.fill"][min(i, 6)]
        case 1: return ["nosign", "theatermasks.fill", "wind", "face.dashed.fill", "flag.fill", "theatermasks.circle.fill"][min(i, 5)]
        case 2: return ["nosign", "eyeglasses", "sunglasses.fill", "binoculars.fill"][min(i, 3)]
        case 3: return ["nosign", "rectangle.fill", "square.grid.2x2.fill", "shield.checkered", "cross.case.fill"][min(i, 4)]
        default: return ["hand.raised.slash.fill", "hand.raised.fill", "hand.raised.fingers.spread.fill", "hand.point.up.left.fill"][min(i, 3)]
        }
    }
}
