import SwiftUI

/// LOADOUT page: class, primary + attachments, sidearm, kit, perks, presets
struct LoadoutHome: View {
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void
    @State private var cls = TacticalEngine.flClass
    @State private var yaw: Double = 0
    @State private var ver = 0
    @State private var preset = max(1, UserDefaults.standard.integer(forKey: "ms.preset.sel"))
    @State private var perks = TPerk.on
    @State private var saved = false

    private let classes: [(String, String, String)] = [("ASSAULT", "Balanced · Versatile", "chevron.up.2"), ("MEDIC", "Heal · Support", "cross.fill"),
                                                       ("SUPPORT", "Ammo · Supplies", "shippingbox.fill"), ("RECON", "Long Range · Intel", "scope"),
                                                       ("ENGINEER", "Build · Repair", "wrench.and.screwdriver.fill")]
    private let slotTitles: [(TAttSlot, String, String)] = [(.optic, "Optic", "scope"), (.muzzle, "Muzzle", "speaker.slash.fill"), (.grip, "Underbarrel", "hand.raised.fill"),
                                                            (.mag, "Magazine", "rectangle.stack.fill"), (.camo, "Camo", "paintpalette.fill")]
    private var primaries: [String] { TWeapons.all.map { $0.id }.filter { !TWeapons.isPistol($0) } }
    private var sidearms: [String] { TWeapons.all.map { $0.id }.filter { TWeapons.isPistol($0) } }

    private func typeName(_ g: String) -> String {
        switch TWeapons.cls(g) { case "rifle": return "ASSAULT RIFLE"; case "smg": return "SUBMACHINE GUN"; case "shotgun": return "SHOTGUN"; case "sniper": return "SNIPER RIFLE"; default: return "PISTOL" }
    }

    private func attName(_ g: String, _ s: TAttSlot) -> String {
        guard let id = TAtt.eq(g, s), let d = TAtt.def(id) else { return "None" }
        return d.name
    }

    private func cycle(_ g: String, _ s: TAttSlot) {
        let opts: [String?] = [nil] + TAtt.defs.filter { $0.slot == s && TAtt.owned.contains($0.id) }.map { Optional($0.id) }
        if opts.count == 1 { act(.screen(7)); return }
        let cur = TAtt.eq(g, s)
        let i = opts.firstIndex(where: { $0 == cur }) ?? 0
        TAtt.setEq(g, s, opts[(i + 1) % opts.count])
        ver += 1
    }

    private func stat(_ g: String) -> (Int, Int, Int) {
        let w = TWeapons.w(g)
        let base = w.dmg * (w.pellets > 1 ? CGFloat(w.pellets) * 0.45 : 1)
        let dmg = Int(max(5, min(100, base * 1.7)))
        let acc = Int(max(8, min(100, 100 - w.spread * 1800)))
        var mob: Int
        switch w.cls { case "pistol": mob = 95; case "smg": mob = 90; case "shotgun": mob = 78; case "rifle": mob = 75; default: mob = 50 }
        if TAtt.mods(g).magMul >= 2 { mob -= 8 }
        return (dmg, acc, mob)
    }

    private func saveCurrent() {
        let d: [String: Any] = ["gun": nav.tacGun, "cls": cls, "sec": TacticalEngine.secondary, "perks": Array(perks)]
        UserDefaults.standard.set(d, forKey: "ms.preset.\(preset)")
        UserDefaults.standard.set(preset, forKey: "ms.preset.sel")
    }

    private func loadPreset(_ n: Int) {
        preset = n
        UserDefaults.standard.set(n, forKey: "ms.preset.sel")
        if let d = UserDefaults.standard.dictionary(forKey: "ms.preset.\(n)") {
            if let g = d["gun"] as? String { nav.tacGun = g }
            if let c = d["cls"] as? Int { cls = c; TacticalEngine.flClass = c }
            if let s = d["sec"] as? String { TacticalEngine.secondary = s }
            if let p = d["perks"] as? [Int] { perks = Set(p); TPerk.on = perks }
        } else {
            saveCurrent()
        }
        ver += 1
    }

    private func bar(_ label: String, _ v: Int) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.85)).frame(width: 52, alignment: .leading)
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.18))
                Rectangle().fill(Color.white).frame(width: 90 * CGFloat(v) / 100)
            }
            .frame(width: 90, height: 4)
            Text("\(v)").font(.jk(9, .heavy)).foregroundColor(.white).frame(width: 22, alignment: .trailing)
        }
    }

    private func gearCard(_ title: String, _ name: String, _ icon: String, _ qty: String) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.jk(8, .heavy)).foregroundColor(.white.opacity(0.7))
                Text(name).font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
            }
            Spacer(minLength: 0)
            SF(icon, "circle.fill").font(.system(size: 20, weight: .bold)).foregroundColor(.white.opacity(0.75))
            Text(qty).font(.jk(10, .heavy)).foregroundColor(.white)
        }
        .padding(6).frame(maxWidth: .infinity).frame(height: 42)
        .background(LS.card).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
    }

    private var kit: (String, String, String, String, String, String) {
        switch cls {
        case 1: return ("Frag Grenade ×1", "Smoke ×2", "Heal Aura", "grenade.fill", "smoke.fill", "cross.case.fill")
        case 2: return ("Frag Grenade ×1", "Smoke ×1", "Ammo Aura", "grenade.fill", "smoke.fill", "shippingbox.fill")
        case 3: return ("Frag Grenade ×1", "Smoke ×1", "Long Spotting", "grenade.fill", "smoke.fill", "binoculars.fill")
        case 4: return ("Frag Grenade ×3", "Smoke ×1", "Extra Grenades", "grenade.fill", "smoke.fill", "wrench.and.screwdriver.fill")
        default: return ("Frag Grenade ×2", "Smoke ×1", "Frontline Push", "grenade.fill", "smoke.fill", "chevron.up.2")
        }
    }

    private func slotTile(_ g: String, _ s: (TAttSlot, String, String)) -> some View {
        Button { cycle(g, s.0) } label: {
            VStack(spacing: 1) {
                SF(s.2, "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(.white.opacity(0.85))
                Text(s.1).font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.8))
                Text(attName(g, s.0)).font(.jk(8, .heavy)).foregroundColor(TAtt.eq(g, s.0) == nil ? .white.opacity(0.45) : LS.orange).lineLimit(1).minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity).frame(height: 40)
            .background(LS.card).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func infoRow(_ a: String, _ b: String) -> some View {
        HStack { Text(a).font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.6)); Spacer(minLength: 4); Text(b).font(.jk(9, .heavy)).foregroundColor(.white) }
    }

    private func arrow(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { SF(icon).font(.system(size: 11, weight: .black)).foregroundColor(.white).frame(width: 22, height: 22).background(Color.black.opacity(0.5)) }.buttonStyle(TuiPress())
    }

    private func step(_ list: [String], _ cur: String, _ d: Int) -> String {
        guard !list.isEmpty else { return cur }
        let i = list.firstIndex(of: cur) ?? 0
        return list[(i + d + list.count) % list.count]
    }

    var body: some View {
        _ = ver
        let W = size.width, H = size.height
        let rp = W * 0.46
        let g = nav.tacGun
        let sec = TacticalEngine.secondary
        let st = stat(g)
        let k = kit
        return ZStack {
            LSTitle(title: "LOADOUT", sub: "Build your class and gear for the battlefield.").position(x: 14 + 150, y: 28)
            // classes
            VStack(spacing: 4) {
                ForEach(0..<classes.count, id: \.self) { i in
                    let on = cls == i
                    Button { cls = i; TacticalEngine.flClass = i } label: {
                        HStack(spacing: 7) {
                            SF(classes[i].2, "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(on ? LS.orange : .white.opacity(0.85)).frame(width: 24)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(classes[i].0).font(.jk(11, .heavy)).foregroundColor(on ? LS.orange : .white)
                                Text(classes[i].1).font(.jk(8, .medium)).foregroundColor(.white.opacity(0.6)).lineLimit(1).minimumScaleFactor(0.6)
                            }
                            Spacer(minLength: 0)
                            if on { Circle().fill(LS.orange).frame(width: 6, height: 6) }
                        }
                        .padding(.horizontal, 8).frame(height: 40)
                        .background(on ? LS.orange.opacity(0.14) : LS.panel.opacity(0.88))
                        .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: on ? 1.5 : 1))
                    }
                    .buttonStyle(TuiPress())
                }
            }
            .frame(width: 128)
            .position(x: 12 + 64, y: 54 + 110)
            // soldier
            AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: TacRank.index(TacRank.totalXP(t)), gun: g, yaw: yaw, zoom: 1, sway: false)
                .frame(width: W - 150 - rp, height: H * 0.9)
                .position(x: 150 + (W - 150 - rp) / 2, y: H * 0.46)
                .allowsHitTesting(false)
            LSSmallButton(icon: "arrow.triangle.2.circlepath", label: "ROTATE") { yaw += .pi / 2 }
                .position(x: 150 + (W - 150 - rp) / 2 + 70, y: H - 92)
            // presets
            VStack(alignment: .leading, spacing: 4) {
                Text("PRESET LOADOUTS").font(.jk(9, .heavy)).foregroundColor(.white)
                HStack(spacing: 5) {
                    ForEach(1...4, id: \.self) { n in
                        Button { loadPreset(n) } label: {
                            Text("\(n)").font(.jk(12, .heavy)).foregroundColor(preset == n ? .black : .white)
                                .frame(width: 30, height: 26).background(Rectangle().fill(preset == n ? LS.orange : Color.white.opacity(0.14)))
                        }
                        .buttonStyle(TuiPress())
                    }
                }
            }
            .padding(6).background(LS.panel.opacity(0.9)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            .position(x: 12 + 90, y: H - 92)
            // stats
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    bar("DAMAGE", st.0); bar("ACCURACY", st.1); bar("MOBILITY", st.2)
                }
                VStack(alignment: .leading, spacing: 3) {
                    infoRow("CLASS", classes[cls].0.capitalized)
                    infoRow("PRIMARY", TWeapons.w(g).name)
                    infoRow("SECONDARY", TWeapons.w(sec).name)
                }
                .frame(width: 112)
            }
            .padding(7).background(LS.panel.opacity(0.9)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            .position(x: 12 + 150, y: H - 36)
            // right: gear
            ScrollView(showsIndicators: false) {
                VStack(spacing: 5) {
                    VStack(spacing: 5) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("PRIMARY").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.75))
                                Text(TWeapons.w(g).name).font(.jk(17, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                                Text(typeName(g)).font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.65))
                                HStack(spacing: 4) {
                                    arrow("chevron.left") { nav.tacGun = step(primaries, g, -1) }
                                    arrow("chevron.right") { nav.tacGun = step(primaries, g, 1) }
                                }
                                .padding(.top, 2)
                            }
                            Spacer(minLength: 0)
                            Image(uiImage: GunSprites.icon(TWeapons.rig(g))).renderingMode(.template).resizable().scaledToFit().foregroundColor(.white).frame(width: 118, height: 40)
                            Text("LV. \(TacMeta.level(g) + 1)").font(.jk(10, .heavy)).foregroundColor(LS.orange)
                        }
                        HStack(spacing: 4) { ForEach(0..<slotTitles.count, id: \.self) { slotTile(g, slotTitles[$0]) } }
                    }
                    .padding(7).background(LS.panel.opacity(0.92)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    VStack(spacing: 5) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("SECONDARY").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.75))
                                Text(TWeapons.w(sec).name).font(.jk(15, .heavy)).foregroundColor(.white)
                                Text("PISTOL").font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.65))
                                HStack(spacing: 4) {
                                    arrow("chevron.left") { TacticalEngine.secondary = step(sidearms, sec, -1); ver += 1 }
                                    arrow("chevron.right") { TacticalEngine.secondary = step(sidearms, sec, 1); ver += 1 }
                                }
                                .padding(.top, 2)
                            }
                            Spacer(minLength: 0)
                            Image(uiImage: GunSprites.icon(TWeapons.rig(sec))).renderingMode(.template).resizable().scaledToFit().foregroundColor(.white).frame(width: 70, height: 26)
                        }
                    }
                    .padding(7).background(LS.panel.opacity(0.92)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    HStack(spacing: 5) {
                        gearCard("TACTICAL", k.1, k.4, "")
                        gearCard("LETHAL", k.0, k.3, "")
                        gearCard("FIELD UPGRADE", k.2, k.5, "")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PERKS").font(.jk(9, .heavy)).foregroundColor(.white)
                        HStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { i in
                                let on = perks.contains(i)
                                Button {
                                    if on { perks.remove(i) } else { perks.insert(i) }
                                    TPerk.on = perks
                                } label: {
                                    VStack(spacing: 2) {
                                        SF(TPerk.icons[i], "circle.fill").font(.system(size: 14, weight: .bold)).foregroundColor(on ? LS.orange : .white.opacity(0.7))
                                        Text(TPerk.names[i]).font(.jk(8, .heavy)).foregroundColor(on ? LS.orange : .white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.5)
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 38)
                                    .background(on ? LS.orange.opacity(0.12) : LS.card)
                                    .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: on ? 1.5 : 1))
                                }
                                .buttonStyle(TuiPress())
                            }
                        }
                    }
                    .padding(7).background(LS.panel.opacity(0.92)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    Button {
                        saveCurrent()
                        saved = true
                        act(.nav(0))
                    } label: {
                        HStack(spacing: 8) {
                            SF("square.and.arrow.down.fill").font(.system(size: 14, weight: .bold))
                            Text("SAVE LOADOUT").font(.jk(14, .heavy))
                        }
                        .foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 38)
                        .background(LinearGradient(colors: [LS.orange, LS.orange2], startPoint: .top, endPoint: .bottom))
                    }
                    .buttonStyle(TuiPress())
                }
                .padding(.bottom, 4)
            }
            .frame(width: rp, height: H - 8)
            .position(x: W - 4 - rp / 2, y: H / 2)
        }
    }
}
