import SwiftUI
import UIKit

// MARK: - 3D style resolved from an AvatarLook

/// Everything the 3D soldier needs to look like one specific player.
struct TwStyle {
    var key = "you"
    var look = AvatarLook()
    var skin = UIColor.brown
    var top = UIColor.gray
    var pants = UIColor.darkGray
    var shoes = UIColor.black
    var pantsStyle = 0
    var outfit = 0
    var build = 1
    var height = 1
    var gloves = 0
    var gloveCol = UIColor.black
    var vest = UIColor(red: 0.36, green: 0.34, blue: 0.26, alpha: 1)
    var pack = 0
    var packCol = UIColor.darkGray
    var hairCol = UIColor.black
    var hairStyle = 0
    var hat = 0
    var hatCol = UIColor.gray
    var showFace = true
}

enum TacAvatar {
    /// Key used for the device owner's own avatar.
    static let myKey = "you"

    static func ui(_ v: UInt32) -> UIColor {
        UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }

    static let pantsCols: [UInt32] = [0x8A7B5A, 0x2A2A30, 0x232B45, 0x56603C, 0x0E0E10, 0x3C5A8A, 0x6B6F76, 0xB39A6B, 0x6B2A24, 0xD8D8D0]
    static let shoeCols: [UInt32] = [0x1E1712, 0x0E0E10, 0xF2F2F2, 0xC0392B, 0x2E6FE0, 0x8B6B3A, 0x37D67A, 0xFFD23F]
    static let vestCols: [UInt32] = [0x5C5842, 0x2A2D33, 0x6B5B3E, 0x39466B, 0x7A2E2E, 0x4A5A3A, 0x7C7F86]
    static let hairStyleList = [0, 1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 9]

    // deterministic generator so every bot / remote user always looks the same
    struct Rng {
        var s: UInt64
        init(_ key: String) { s = UInt64(HK.h(key)) &* 0x9E3779B97F4A7C15 &+ 0x1234567 }
        mutating func next() -> UInt64 {
            s = s &+ 0x9E3779B97F4A7C15
            var z = s
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func int(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
        mutating func chance(_ pct: Int) -> Bool { int(100) < pct }
    }

    /// Fill every unset field so the 2D face and the 3D body always agree.
    static func full(_ key: String, _ base: AvatarLook?) -> AvatarLook {
        let fresh = base == nil
        var l = base ?? AvatarLook()
        var r = Rng(key)
        func pick<T>(_ v: inout T?, _ g: @autoclosure () -> T) { if v == nil { v = g() } }
        pick(&l.skin, r.int(8))
        pick(&l.faceShape, r.int(5))
        pick(&l.hair, r.int(13))
        pick(&l.hairStyle, hairStyleList[r.int(hairStyleList.count)])
        pick(&l.top, r.int(12))
        pick(&l.outfit, r.chance(50) ? 14 + r.int(2) : r.int(14))
        pick(&l.eyes, r.int(3))
        pick(&l.eyeColor, r.int(9))
        pick(&l.brow, r.int(5))
        pick(&l.lashes, r.chance(35))
        pick(&l.nose, r.int(4))
        pick(&l.mouth, r.int(4))
        pick(&l.beard, r.chance(30) ? 1 + r.int(7) : 0)
        pick(&l.freckles, r.chance(20))
        pick(&l.mole, r.chance(15) ? 1 + r.int(3) : 0)
        pick(&l.scar, r.chance(12) ? 1 + r.int(2) : 0)
        pick(&l.blush, r.int(3))
        pick(&l.specs, r.chance(25) ? 1 + r.int(3) : 0)
        pick(&l.ear, r.int(4))
        pick(&l.metal, r.int(5))
        pick(&l.accent, r.int(8))
        pick(&l.build, r.int(4))
        pick(&l.height, r.int(3))
        pick(&l.pants, r.int(pantsCols.count))
        pick(&l.pantsStyle, r.int(4))
        pick(&l.shoes, r.int(shoeCols.count))
        pick(&l.gloves, r.int(3))
        pick(&l.gloveCol, r.int(8))
        pick(&l.vestCol, r.int(vestCols.count))
        pick(&l.pack, r.chance(40) ? 1 + r.int(2) : 0)
        pick(&l.packCol, r.int(vestCols.count))
        pick(&l.kit, 1 + r.int(TacGear.kits.count))
        if (l.kit ?? 0) < 1 { l.kit = 1 + r.int(TacGear.kits.count) }      // the old civilian outfit is retired
        if fresh {
            let hats = [1, 2, 6, 18, 19, 5, 10, 13, 20, 15]
            l.hat = r.chance(45) ? hats[r.int(hats.count)] : 0
            l.hatColor = r.int(12)
            l.paint = r.chance(8) ? 1 + r.int(17) : 0
            l.paintColor = r.int(8)
            l.mask = r.chance(6) ? 1 + r.int(7) : 0
            l.pierce = r.chance(10) ? 1 + r.int(4) : 0
        }
        return l
    }

    /// The saved look of the local player, or the generated one for anyone else.
    private static var lookCache: [String: AvatarLook] = [:]
    private static var lookVer = -1

    static func look(for key: String) -> AvatarLook {
        if lookVer != AvatarLooks.version { lookCache.removeAll(); lookVer = AvatarLooks.version }
        if let c = lookCache[key] { return c }
        let l = full(key, AvatarLooks.look(for: key))
        lookCache[key] = l
        return l
    }

    static func style(_ key: String, _ given: AvatarLook? = nil) -> TwStyle {
        let l = given ?? look(for: key)
        func idx(_ v: Int?, _ n: Int) -> Int { max(0, min(n - 1, v ?? 0)) }
        var s = TwStyle()
        s.key = key
        var l2 = l
        l2.mask = 0; l2.specs = 0; l2.hat = 0                             // the operator draws those in 3D
        s.look = l2
        s.skin = ui(PortraitAvatar.skins[idx(l.skin, 8)])
        s.top = ui(PortraitAvatar.tops[idx(l.top, 12)])
        s.pants = ui(pantsCols[idx(l.pants, pantsCols.count)])
        s.shoes = ui(shoeCols[idx(l.shoes, shoeCols.count)])
        s.pantsStyle = idx(l.pantsStyle, 4)
        s.outfit = l.outfit ?? 0
        s.build = idx(l.build, 4)
        s.height = idx(l.height, 3)
        s.gloves = idx(l.gloves, 3)
        s.gloveCol = ui(PortraitAvatar.paints[idx(l.gloveCol, 8)])
        s.vest = ui(vestCols[idx(l.vestCol, vestCols.count)])
        s.pack = idx(l.pack, 3)
        s.packCol = ui(vestCols[idx(l.packCol, vestCols.count)])
        s.hairCol = ui(PortraitAvatar.hairs[idx(l.hair, 13)])
        s.hairStyle = l.hairStyle ?? 0
        s.hat = l.hat
        s.hatCol = ui(PortraitAvatar.tops[idx(l.hatColor, 12)])
        return s
    }

    // MARK: face texture (2D portrait → 3D head)

    @MainActor private static var faceCache: [String: UIImage] = [:]

    /// The face texture for a style (drawn with Core Graphics, cached).
    static func faceImage(_ s: TwStyle) -> UIImage? { TacFace.cached(s) }

    /// Puts the face texture on the material.
    static func applyFace(_ mat: MXMaterial, style s: TwStyle) {
        mat.diffuse.contents = TacFace.cached(s)
    }
}

// MARK: - Roster (the device owner is the only admin and hands out roles)

enum TacRoster {
    /// Change this passcode before shipping. Only the owner needs it.
    static let passcode = "mrzefv"

    private static let rolesKey = "ms.roles.v1"
    private static let poolKey = "ms.pool.v1"
    private static let unlockKey = "ms.admin.on"

    static var unlocked: Bool {
        get { UserDefaults.standard.bool(forKey: unlockKey) }
        set { UserDefaults.standard.set(newValue, forKey: unlockKey) }
    }

    static var roles: [String: Int] {
        get { (UserDefaults.standard.dictionary(forKey: rolesKey) as? [String: Int]) ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: rolesKey) }
    }

    static func rank(of handle: String) -> Int { roles[handle] ?? 0 }

    static func setRank(_ handle: String, _ r: Int) {
        var d = roles
        if r <= 0 { d.removeValue(forKey: handle) } else { d[handle] = min(2, r) }
        roles = d
    }

    /// Persistent set of 24 regular users so the same people (and the same outfits) show up every match.
    static var pool: [(name: String, handle: String)] {
        if let a = UserDefaults.standard.array(forKey: poolKey) as? [[String]], a.count >= 12 {
            return a.map { ($0[0], $0[1]) }
        }
        let made = BotNames.pick(24).map { ($0.0, $0.1) }
        UserDefaults.standard.set(made.map { [$0.0, $0.1] }, forKey: poolKey)
        return made
    }

    static func pick(_ n: Int) -> [(String, String, String)] {
        var all = pool
        // admin-assigned people are always in the lobby first so their roles are actually visible
        all.sort { rank(of: $0.handle) > rank(of: $1.handle) }
        let staff = all.filter { rank(of: $0.handle) > 0 }
        var rest = all.filter { rank(of: $0.handle) == 0 }.shuffled()
        var out: [(String, String, String)] = []
        for p in staff.prefix(max(0, n - 3)) { out.append((p.name, p.handle, "")) }
        while out.count < n, let p = rest.popLast() { out.append((p.name, p.handle, "")) }
        return out.shuffled()
    }
}

// MARK: - 3D preview used inside the studio

struct AvatarSoldierPreview: UIViewRepresentable {
    let style: TwStyle
    var rank = 0
    var gun = ""
    var yaw: Double = 0
    var zoom: Double = 1
    var sway = true

    final class Coord {
        var last = ""
        var holder = MXNode()
        var yaw: Float = 0
        var zoom: Float = 1
        var sway = true
    }

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> MXView {
        let v = MXView()
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        v.isUserInteractionEnabled = false
        let sc = MXScene()
        v.scene = sc

        let cam = MXNode()
        cam.camera = MXCamera()
        cam.camera?.fieldOfView = 32
        cam.camera?.zNear = 1
        cam.camera?.zFar = 1000
        cam.position = MXVector3(120, 30, 52)
        let tgt = MXNode()
        tgt.position = MXVector3(0, 25, 0)
        sc.rootNode.addChildNode(tgt)
        sc.rootNode.addChildNode(cam)
        v.pointOfView = cam
        cam.look(at: MXVector3(0, 25, 0))

        let amb = MXNode()
        amb.light = MXLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 650
        sc.rootNode.addChildNode(amb)
        let sun = MXNode()
        sun.light = MXLight()
        sun.light?.type = .directional
        sun.light?.intensity = 900
        sun.eulerAngles = MXVector3(-0.6, 1.2, 0)
        sc.rootNode.addChildNode(sun)

        let holder = context.coordinator.holder
        sc.rootNode.addChildNode(holder)
        let co = context.coordinator
        v.preRender = { [weak holder, weak co] t in
            let y: Float = co?.yaw ?? 0
            let sw: Float = (co?.sway ?? true) ? Float(sin(t * 0.98)) * 0.55 : 0
            holder?.eulerAngles = MXVector3(0, y + sw, 0)
            let z: Float = co?.zoom ?? 1
            holder?.scale = MXVector3(z, z, z)
        }
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {
        context.coordinator.yaw = Float(yaw)
        context.coordinator.zoom = Float(zoom)
        context.coordinator.sway = sway
        let sig = (try? JSONEncoder().encode(style.look)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let gid = gun.isEmpty ? "rifle" : gun
        let sig2 = sig + "#\(rank)#" + gid + "#" + TAtt.viewSig(gid)
        guard context.coordinator.last != sig2 else { return }
        context.coordinator.last = sig2
        let h = context.coordinator.holder
        h.childNodes.forEach { $0.removeFromParentNode() }
        // Blender operator (modular GLB + arms + gun) when the kit and gun have models; otherwise the code-built soldier
        if let op = TacOperator.node(style: style, gun: gid) {
            op.position = MXVector3(0, -4, 0)
            h.addChildNode(op)
            return
        }
        let sol = TwRig.soldier(team: UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1), style: style, rank: rank)
        for g in sol.variants { g.isHidden = true }
        let rifle = TwRig.gunIdx(gid)
        if rifle < sol.variants.count { sol.variants[rifle].isHidden = false }
        TAtt.applyCamo(gid, set: 0)
        sol.root.position = MXVector3(0, -4, 0)
        h.addChildNode(sol.root)
    }
}

// MARK: - Admin / roster panel

struct AdminRosterView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var open = TacRoster.unlocked
    @State private var bad = false
    @State private var roles = TacRoster.roles

    private var lime: Color { TUI.accent }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                SF("crown.fill").font(.system(size: 20, weight: .bold)).foregroundColor(TUI.gold)
                Text("Admin").font(.jk(26, .heavy))
                Spacer()
                Button { dismiss() } label: {
                    SF("xmark").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                        .frame(width: 38, height: 38).background(Circle().fill(T.card2))
                }
            }
            if !open {
                Spacer()
                VStack(spacing: 12) {
                    SF("lock.fill").font(.system(size: 30)).foregroundColor(.white.opacity(0.7))
                    SecureField("Passcode", text: $code)
                        .textFieldStyle(.roundedBorder).frame(width: 240)
                    if bad { Text("Wrong passcode").font(.jk(13, .semibold)).foregroundColor(TUI.red) }
                    Button {
                        if code == TacRoster.passcode { TacRoster.unlocked = true; open = true; bad = false } else { bad = true }
                    } label: {
                        Text("UNLOCK").font(.jk(15, .heavy)).foregroundColor(TUI.ink)
                            .frame(width: 240, height: 44).background(Capsule().fill(lime))
                    }
                    .buttonStyle(TuiPress())
                }
                Spacer()
            } else {
                Text("You are the only admin. Give other players staff or admin roles; everyone else is a regular player.")
                    .font(.jk(12, .medium)).foregroundColor(.white.opacity(0.6)).frame(maxWidth: .infinity, alignment: .leading)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                        ForEach(Array(TacRoster.pool.enumerated()), id: \.offset) { _, p in
                            HStack(spacing: 10) {
                                PortraitAvatar(key: p.handle, size: 44, look: TacAvatar.look(for: p.handle).faceCopy)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).font(.jk(14, .heavy))
                                        .foregroundColor((roles[p.handle] ?? 0) == 2 ? TUI.red : .white)
                                    Text(["PLAYER", "STAFF", "ADMIN"][roles[p.handle] ?? 0]).font(.jk(9, .heavy)).tracking(1)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                Spacer(minLength: 0)
                                ForEach(0..<3, id: \.self) { r in
                                    Button {
                                        TacRoster.setRank(p.handle, r)
                                        roles = TacRoster.roles
                                    } label: {
                                        SF(["person.fill", "shield.lefthalf.filled", "crown.fill"][r])
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor((roles[p.handle] ?? 0) == r ? TUI.ink : .white.opacity(0.7))
                                            .frame(width: 36, height: 36)
                                            .background(Circle().fill((roles[p.handle] ?? 0) == r ? [Color.white, TUI.green, TUI.gold][r] : T.card2))
                                    }
                                    .buttonStyle(TuiPress())
                                }
                            }
                            .padding(10).tuiGlass(12, fill: 0.4)
                        }
                    }
                }
                Button {
                    TacRoster.unlocked = false
                    open = false
                } label: {
                    Text("Lock").font(.jk(13, .bold)).foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg.ignoresSafeArea())
    }
}
