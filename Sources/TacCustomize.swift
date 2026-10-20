import SwiftUI
import UIKit

/// CUSTOMIZE page: operator, uniform, helmet, backpack, gloves, patches, weapon camo
struct CustomizeHome: View {
    @EnvironmentObject var nav: Nav
    let t: TacData
    let size: CGSize
    let act: (LobbyAct) -> Void
    @State private var look: AvatarLook = TacAvatar.look(for: TacAvatar.myKey)
    @State private var cat = 0
    @State private var yaw: Double = 0
    @State private var zoom: Double = 1
    @State private var op = UserDefaults.standard.integer(forKey: "ms.op")
    @State private var skin = UserDefaults.standard.integer(forKey: "ms.skin")
    @State private var note = ""

    private let cats: [(String, String)] = [("person.fill", "OPERATOR"), ("tshirt.fill", "UNIFORMS"), ("shield.fill", "HELMETS"), ("bag.fill", "BACKPACKS"),
                                             ("hand.raised.fill", "GLOVES"), ("shield.checkered", "PATCHES"), ("scope", "WEAPONS"), ("seal.fill", "CHARMS")]
    private let tabs = ["OPERATORS", "UNIFORMS", "HELMETS", "BACKPACKS"]
    // name, top, pants, vest, gloveCol
    private let skins: [(String, Int, Int, Int, Int)] = [("DEFAULT", 1, 3, 0, 4), ("WOODLAND", 4, 3, 5, 2), ("DESERT", 6, 7, 2, 3), ("URBAN", 1, 6, 6, 5), ("BLACK", 8, 4, 1, 4), ("SNOW", 7, 9, 6, 5)]
    private let topNames = ["Navy", "Slate", "Violet", "Blue", "Green", "Red", "Amber", "White", "Black", "Pink", "Cyan", "Lime"]
    private let pantsNames = ["Khaki", "Charcoal", "Navy", "Olive", "Black", "Blue", "Gray", "Sand", "Maroon", "Cream"]
    private let hats = [0, 1, 2, 5, 6, 10, 13, 15, 18, 19, 20, 21]
    private let colorIdx = [5, 2, 0, 6, 1, 4, 3]

    private var cw: CGFloat { max(40, (size.width * 0.5 - 22 - 25) / 6) }

    private func edit(_ f: (inout AvatarLook) -> Void) {
        var l = look
        f(&l)
        look = l
        AvatarLooks.save(l, handle: TacAvatar.myKey)
    }

    private func variant(_ f: (inout AvatarLook) -> Void) -> AvatarLook {
        var l = look
        f(&l)
        return l
    }

    private func card<A: View>(_ title: String, _ sel: Bool, locked: Bool = false, _ tap: @escaping () -> Void, @ViewBuilder _ art: () -> A) -> some View {
        Button(action: tap) {
            VStack(spacing: 2) {
                art().frame(width: cw, height: cw * 0.86).clipped()
                Text(title).font(.jk(8, .heavy)).foregroundColor(sel ? LS.orange : .white).lineLimit(1).minimumScaleFactor(0.55)
            }
            .padding(3).background(LS.card)
            .overlay(Rectangle().stroke(sel ? LS.orange : LS.line, lineWidth: sel ? 2 : 1))
            .overlay(alignment: .topTrailing) {
                if sel { SF("checkmark").font(.system(size: 8, weight: .black)).foregroundColor(.black).frame(width: 13, height: 13).background(LS.orange) }
            }
            .overlay {
                if locked { ZStack { Color.black.opacity(0.55); SF("lock.fill").font(.system(size: 13)).foregroundColor(.white) } }
            }
        }
        .buttonStyle(TuiPress())
    }

    private func face(_ l: AvatarLook) -> some View {
        PortraitAvatar(key: TacAvatar.myKey, size: cw * 0.86, look: l.faceCopy)
    }

    private func swatch(_ c: Color) -> some View { Rectangle().fill(c) }

    private func head(_ s: String) -> some View {
        Text(s).font(.jk(11, .heavy)).foregroundColor(.white).padding(.top, 6)
    }

    private var cols: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 5), count: 6) }

    private func camoDefs() -> [TAttDef] { TAtt.defs.filter { $0.slot == .camo } }

    private func camoArt(_ d: TAttDef) -> some View {
        Group {
            if let c = d.color {
                if let img = TAttPattern.image(d) { Image(uiImage: img).resizable().scaledToFill() }
                else { Rectangle().fill(Color(red: c.0, green: c.1, blue: c.2)) }
            } else { Rectangle().fill(Color.gray) }
        }
    }

    private func camoGrid() -> some View {
        let g = nav.tacGun
        let list = camoDefs()
        return LazyVGrid(columns: cols, spacing: 5) {
            card("DEFAULT", TAtt.eq(g, .camo) == nil, { TAtt.setEq(g, .camo, nil); note = "" }) { swatch(Color(white: 0.2)) }
            ForEach(list, id: \.id) { d in
                let own = TAtt.owned.contains(d.id)
                card(d.name.uppercased(), TAtt.eq(g, .camo) == d.id, locked: !own, {
                    if own { TAtt.setEq(g, .camo, d.id); note = "" } else { note = "Buy \(d.name) in the Gunsmith" }
                }) { camoArt(d) }
            }
        }
    }

    private func colorRow() -> some View {
        HStack(spacing: 6) {
            ForEach(0..<colorIdx.count, id: \.self) { i in
                let vi = colorIdx[i]
                let sel = (look.vestCol ?? 0) == vi
                Button { edit { $0.vestCol = vi; $0.packCol = vi } } label: {
                    Rectangle().fill(Color(uiColor: TacAvatar.ui(TacAvatar.vestCols[vi]))).frame(width: 30, height: 28)
                        .overlay(Rectangle().stroke(sel ? LS.orange : Color.white.opacity(0.35), lineWidth: sel ? 2 : 1))
                }
                .buttonStyle(TuiPress())
            }
        }
    }

    private func palette(_ vals: [UInt32], _ cur: Int, _ pick: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 10), spacing: 5) {
            ForEach(0..<vals.count, id: \.self) { i in
                Button { pick(i) } label: {
                    Rectangle().fill(Color(uiColor: TacAvatar.ui(vals[i]))).frame(height: 24)
                        .overlay(Rectangle().stroke(cur == i ? LS.orange : Color.white.opacity(0.3), lineWidth: cur == i ? 2 : 1))
                }
                .buttonStyle(TuiPress())
            }
        }
    }

    private func opPortrait(_ name: String, _ tint: Color) -> some View {
        ZStack {
            LinearGradient(colors: [tint.opacity(0.55), Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
            if let im = TacGear.opImage(name) {
                Image(uiImage: im).resizable().scaledToFill().scaleEffect(1.12, anchor: .top)
            } else {
                SF("person.fill").font(.system(size: 17)).foregroundColor(.white.opacity(0.55))
            }
        }
        .clipped()
    }

    private func kitArt(_ k: TacKit) -> some View {
        if TacGear.opImage(k.name) != nil { return AnyView(opPortrait(k.name, Color(uiColor: TacGear.c(k.uni)))) }
        return AnyView(kitArtFallback(k))
    }

    private func kitArtFallback(_ k: TacKit) -> some View {
        ZStack {
            Rectangle().fill(Color(uiColor: TacGear.c(k.uni)))
            Rectangle().fill(Color(uiColor: TacGear.c(k.rigCol))).frame(height: 12).offset(y: 6)
            Rectangle().fill(Color(uiColor: TacGear.c(k.accent))).frame(width: 14, height: 3).offset(y: -4)
            SF("person.fill").font(.system(size: 17)).foregroundColor(.white.opacity(0.55))
        }
    }

    private func gearCard(_ kind: Int, _ names: [String], _ cur: Int, _ pick: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: cols, spacing: 5) {
            ForEach(0..<names.count, id: \.self) { i in
                card(names[i], cur == i, { pick(i) }) {
                    swatch(Color(white: 0.16)).overlay(SF(TacGear.icon(kind, i)).font(.system(size: 16)).foregroundColor(i == 0 ? .white.opacity(0.35) : .white.opacity(0.88)))
                }
            }
        }
    }

    private func texArt(_ kind: String, _ i: Int) -> some View {
        Group {
            if let im = TacGear.swatch(kind, i) { Image(uiImage: im).resizable().scaledToFill() }
            else { Rectangle().fill(Color(white: 0.2)) }
        }
    }

    private func texGrid(_ kind: String, _ names: [String], _ cur: Int, _ pick: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: cols, spacing: 5) {
            ForEach(0..<names.count, id: \.self) { i in
                card(names[i], cur == i, { pick(i) }) { texArt(kind, i) }
            }
        }
    }

    /// swap individual pieces of the Special Task Force operator: face, headgear, helmet colour, eyewear, uniform, vest, gloves
    @ViewBuilder private func gearRows() -> some View {
        if let k = TacGear.resolve(look) {
            head("FACE")
            texGrid("face", TacGear.stfFaceNames, k.sFace) { i in edit { $0.sFace = i } }
            head("HEADGEAR")
            gearCard(0, TacGear.stfHeadNames, k.sHead) { i in edit { $0.sHead = i } }
            if k.sHead > 0 {
                head("HELMET COLOR")
                texGrid("helm", TacGear.stfHelmColNames, k.sHelmCol) { i in edit { $0.sHelmCol = i } }
            }
            head("EYEWEAR")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(0..<TacGear.stfLensNames.count, id: \.self) { i in
                    card(TacGear.stfLensNames[i], k.sLens == i, { edit { $0.sLens = i } }) {
                        swatch(i == 0 ? Color(white: 0.16) : Color(uiColor: TacGear.c(TacGear.stfLens[i])).opacity(0.9))
                            .overlay(SF(i == 0 ? "nosign" : "sunglasses.fill").font(.system(size: 16)).foregroundColor(.white.opacity(i == 0 ? 0.35 : 0.88)))
                    }
                }
            }
            head("UNIFORM")
            texGrid("body", TacGear.stfBodyNames, k.sBody) { i in edit { $0.sBody = i } }
            head("VEST")
            LazyVGrid(columns: cols, spacing: 5) {
                card("NO VEST", !k.sVest, { edit { $0.sVest = false } }) {
                    swatch(Color(white: 0.16)).overlay(SF("nosign").font(.system(size: 16)).foregroundColor(.white.opacity(0.35)))
                }
                ForEach(0..<TacGear.stfGearNames.count, id: \.self) { i in
                    card(TacGear.stfGearNames[i], k.sVest && k.sGear == i, { edit { $0.sVest = true; $0.sGear = i } }) { texArt("gear", i) }
                }
            }
            head("GLOVES (ALSO YOUR FIRST-PERSON HANDS)")
            gearCard(4, TacGear.gloveNames, k.glv) { i in edit { $0.kGlove = i } }
        }
    }

    /// an operator card resets every piece back to that operator's own preset
    private func pickKit(_ i: Int) {
        op = i; UserDefaults.standard.set(i, forKey: "ms.op")
        edit {
            $0.kit = i + 1; $0.kSkin = nil; $0.kHelm = nil; $0.kFace = nil; $0.kEyes = nil; $0.kRig = nil; $0.kGlove = nil
            $0.sBody = nil; $0.sGear = nil; $0.sVest = nil; $0.sHead = nil; $0.sHelmCol = nil; $0.sFace = nil; $0.sLens = nil
        }
        skin = 0; UserDefaults.standard.set(0, forKey: "ms.skin")
    }

    @ViewBuilder private var panelBody: some View {
        switch cat {
        case 0:
            head("OPERATORS")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(0..<TacGear.kits.count, id: \.self) { i in
                    let k = TacGear.kits[i]
                    card(k.name, TacGear.kitIndex(look) == i + 1, { pickKit(i) }) { kitArt(k) }
                }
            }
            gearRows()
            head("SKINS (UNIFORM + VEST + HELMET SETS)")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(0..<skins.count, id: \.self) { i in
                    let s = skins[i]
                    card(s.0, skin == i, {
                        skin = i; UserDefaults.standard.set(i, forKey: "ms.skin")
                        edit {
                            $0.top = s.1; $0.pants = s.2; $0.vestCol = s.3; $0.packCol = s.3; $0.gloveCol = s.4; $0.kSkin = i
                            $0.sBody = nil; $0.sGear = nil; $0.sVest = nil; $0.sHelmCol = nil
                        }
                    }) { texArt("body", i < TacGear.stfSkin.count ? TacGear.stfSkin[i].0 : 0) }
                }
            }
            head("WEAPON CAMO")
            camoGrid()
        case 1:
            head("TOPS")
            palette(PortraitAvatar.tops, look.top ?? 0) { i in edit { $0.top = i } }
            head("PANTS")
            palette(TacAvatar.pantsCols, look.pants ?? 0) { i in edit { $0.pants = i } }
            head("PANTS STYLE")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(0..<4, id: \.self) { i in
                    card(["CARGO", "JEANS", "TACTICAL", "SHORTS"][i], (look.pantsStyle ?? 0) == i, { edit { $0.pantsStyle = i } }) {
                        swatch(Color(uiColor: TacAvatar.ui(TacAvatar.pantsCols[look.pants ?? 0]))).overlay(Text("\(i + 1)").font(.jk(14, .heavy)).foregroundColor(.white.opacity(0.8)))
                    }
                }
            }
            head("BUILD")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(0..<4, id: \.self) { i in
                    card(["SLIM", "AVERAGE", "ATHLETIC", "HEAVY"][i], (look.build ?? 1) == i, { edit { $0.build = i } }) {
                        swatch(Color(white: 0.18)).overlay(SF("figure.stand").font(.system(size: 14 + CGFloat(i) * 2)).foregroundColor(.white.opacity(0.85)))
                    }
                }
            }
        case 2:
            head("HELMETS")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(hats, id: \.self) { h in
                    card(h == 0 ? "NONE" : "HELMET \(h)", look.hat == h, { edit { $0.hat = h } }) { face(variant { $0.hat = h }) }
                }
            }
            head("HELMET COLOR")
            palette(PortraitAvatar.tops, look.hatColor) { i in edit { $0.hatColor = i } }
        case 3:
            head("BACKPACKS")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    card(["NONE", "SMALL", "LARGE"][i], (look.pack ?? 0) == i, { edit { $0.pack = i } }) {
                        swatch(Color(white: 0.18)).overlay(SF("bag.fill").font(.system(size: 10 + CGFloat(i) * 5)).foregroundColor(i == 0 ? .white.opacity(0.3) : .white.opacity(0.85)))
                    }
                }
            }
            head("PACK COLOR")
            palette(TacAvatar.vestCols, look.packCol ?? 0) { i in edit { $0.packCol = i } }
            head("ARMOR COLOR")
            palette(TacAvatar.vestCols, look.vestCol ?? 0) { i in edit { $0.vestCol = i } }
        case 4:
            head("GLOVES")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    card(["NONE", "FINGERLESS", "FULL"][i], (look.gloves ?? 0) == i, { edit { $0.gloves = i } }) {
                        swatch(Color(white: 0.18)).overlay(SF("hand.raised.fill").font(.system(size: 18)).foregroundColor(i == 0 ? .white.opacity(0.3) : .white.opacity(0.85)))
                    }
                }
            }
            head("GLOVE COLOR")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 8), spacing: 5) {
                ForEach(0..<PortraitAvatar.paints.count, id: \.self) { i in
                    Button { edit { $0.gloveCol = i } } label: {
                        Rectangle().fill(Color(uiColor: TacAvatar.ui(PortraitAvatar.paints[i]))).frame(height: 26)
                            .overlay(Rectangle().stroke((look.gloveCol ?? 0) == i ? LS.orange : Color.white.opacity(0.3), lineWidth: (look.gloveCol ?? 0) == i ? 2 : 1))
                    }
                    .buttonStyle(TuiPress())
                }
            }
        case 5:
            head("PATCHES")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach([0, 1, 3, 5, 7, 9, 11, 13, 15, 17], id: \.self) { p in
                    card(p == 0 ? "NONE" : "PATCH \(p)", look.paint == p, { edit { $0.paint = p } }) { face(variant { $0.paint = p }) }
                }
            }
            head("PATCH COLOR")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 8), spacing: 5) {
                ForEach(0..<PortraitAvatar.paints.count, id: \.self) { i in
                    Button { edit { $0.paintColor = i } } label: {
                        Rectangle().fill(Color(uiColor: TacAvatar.ui(PortraitAvatar.paints[i]))).frame(height: 26)
                            .overlay(Rectangle().stroke(look.paintColor == i ? LS.orange : Color.white.opacity(0.3), lineWidth: look.paintColor == i ? 2 : 1))
                    }
                    .buttonStyle(TuiPress())
                }
            }
        case 6:
            head("WEAPON")
            LazyVGrid(columns: cols, spacing: 5) {
                ForEach(TWeapons.all.map { $0.id }, id: \.self) { id in
                    card(TWeapons.w(id).name, nav.tacGun == id, { nav.tacGun = id }) {
                        Image(uiImage: GunSprites.icon(TWeapons.rig(id))).renderingMode(.template).resizable().scaledToFit().foregroundColor(.white).padding(4).background(Color(white: 0.12))
                    }
                }
            }
            head("CAMO")
            camoGrid()
            Button { act(.screen(14)) } label: {
                HStack(spacing: 6) {
                    SF("paintpalette.fill").font(.system(size: 13, weight: .bold))
                    Text("CAMO & ATTACHMENT LAB").font(.jk(11, .heavy))
                    Spacer(minLength: 0)
                    Text("MAKE · SAVE · SHARE").font(.jk(8, .semibold)).opacity(0.7)
                }
                .foregroundColor(.black).padding(.horizontal, 10).frame(height: 34).background(LS.orange)
            }
            .buttonStyle(TuiPress())
        default:
            head("CHARMS")
            Text("Charms and kill effects live in the Store.").font(.jk(10, .medium)).foregroundColor(.white.opacity(0.7))
            LSSmallButton(icon: "cart.fill", label: "OPEN STORE", on: true) { act(.season(1)) }
        }
    }

    var body: some View {
        let W = size.width, H = size.height
        let rp = W * 0.5
        let midW = W - 122 - rp - 8
        return ZStack {
            LSTitle(title: "CUSTOMIZE", sub: "Change your look. Stand out on the battlefield.").position(x: 14 + 150, y: 28)
            // category list
            VStack(spacing: 3) {
                ForEach(0..<cats.count, id: \.self) { i in
                    let on = cat == i
                    Button { cat = i } label: {
                        HStack(spacing: 7) {
                            SF(cats[i].0, "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(on ? LS.orange : .white.opacity(0.8)).frame(width: 18)
                            Text(cats[i].1).font(.jk(10, .heavy)).foregroundColor(on ? LS.orange : .white.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.6)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8).frame(height: 30)
                        .background(on ? LS.orange.opacity(0.14) : LS.panel.opacity(0.85))
                        .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: on ? 1.5 : 1))
                    }
                    .buttonStyle(TuiPress())
                }
            }
            .frame(width: 108)
            .position(x: 12 + 54, y: 62 + 129)
            // soldier
            AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey, look), rank: TacRank.index(TacRank.totalXP(t)), gun: nav.tacGun, yaw: yaw, zoom: zoom, sway: false)
                .frame(width: midW, height: H * 0.92)
                .position(x: 122 + midW / 2, y: H * 0.5)
                .allowsHitTesting(false)
            HStack(spacing: 6) {
                LSSmallButton(icon: "arrow.triangle.2.circlepath", label: "ROTATE") { yaw += .pi / 2 }
                LSSmallButton(icon: "magnifyingglass", label: "ZOOM") { zoom = zoom > 1.2 ? 1 : 1.35 }
            }
            .position(x: 122 + 80, y: H - 22)
            // right panel
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(0..<tabs.count, id: \.self) { i in
                        Button { cat = i } label: {
                            Text(tabs[i]).font(.jk(11, .heavy)).foregroundColor(cat == i ? .white : .white.opacity(0.55))
                                .frame(maxWidth: .infinity).frame(height: 32)
                                .background(cat == i ? LS.orange : Color.clear)
                        }
                        .buttonStyle(TuiPress())
                    }
                }
                .background(Color.black.opacity(0.4))
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 5) {
                        panelBody
                        if !note.isEmpty { Text(note).font(.jk(9, .heavy)).foregroundColor(TUI.gold) }
                    }
                    .padding(.horizontal, 8).padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack(spacing: 10) {
                    SF("paintbrush.pointed.fill", "circle.fill").font(.system(size: 18)).foregroundColor(.white.opacity(0.8)).frame(width: 34, height: 34).background(Color.white.opacity(0.08))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("CUSTOMIZE YOUR OPERATOR").font(.jk(11, .heavy)).foregroundColor(.white)
                        Text("Mix and match skins, patterns and colors to make it yours.").font(.jk(8, .medium)).foregroundColor(.white.opacity(0.65)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(6).background(LS.card).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            }
            .frame(width: rp, height: H - 8)
            .background(LS.panel.opacity(0.92))
            .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            .position(x: W - 4 - rp / 2, y: H / 2)
        }
    }

}
