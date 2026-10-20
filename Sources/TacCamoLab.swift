import SwiftUI
import UIKit

// MARK: - player-made camos and attachments

struct TCustomCamo: Codable, Hashable {
    var id: String
    var name: String
    var c1: [Double]
    var c2: [Double]
    var c3: [Double]
    var pat: Int
}

struct TCustomAtt: Codable, Hashable {
    var id: String
    var name: String
    var slot: String
    var base: String          // built-in part whose model it uses
    var mag = 1.0
    var reload = 1.0
    var recoil = 1.0
    var dmg = 1.0
    var range = 1.0
    var zoom = 26.0
    var silenced = false
}

enum TAttCustom {
    private static let camoKey = "ms.camo.custom.v1"
    private static let attKey = "ms.att.custom.v1"
    private static var camoCache: [TCustomCamo]? = nil
    private static var attCache: [TCustomAtt]? = nil
    static var draftCamo: TCustomCamo? = nil
    static var draftAtt: TCustomAtt? = nil

    static var camos: [TCustomCamo] {
        get {
            if let c = camoCache { return c }
            let c = (UserDefaults.standard.data(forKey: camoKey).flatMap { try? JSONDecoder().decode([TCustomCamo].self, from: $0) }) ?? []
            camoCache = c
            return c
        }
        set {
            camoCache = newValue
            if let d = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(d, forKey: camoKey) }
        }
    }

    static var atts: [TCustomAtt] {
        get {
            if let c = attCache { return c }
            let c = (UserDefaults.standard.data(forKey: attKey).flatMap { try? JSONDecoder().decode([TCustomAtt].self, from: $0) }) ?? []
            attCache = c
            return c
        }
        set {
            attCache = newValue
            if let d = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(d, forKey: attKey) }
        }
    }

    static func att(_ id: String) -> TCustomAtt? {
        guard id.hasPrefix("ca_") else { return nil }
        if let d = draftAtt, d.id == id { return d }
        return atts.first { $0.id == id }
    }

    private static func tup(_ a: [Double]) -> (CGFloat, CGFloat, CGFloat) { (CGFloat(a[0]), CGFloat(a[1]), CGFloat(a[2])) }

    static var camoDefs: [TAttDef] {
        var l = camos
        if let d = draftCamo { l.append(d) }
        return l.map { c in
            TAttDef(id: c.id, slot: .camo, name: c.name, desc: "Custom camo", cost: 0, color: tup(c.c1), pat: c.pat, c2: tup(c.c2), c3: tup(c.c3))
        }
    }

    static var attDefs: [TAttDef] {
        var l = atts
        if let d = draftAtt { l.append(d) }
        return l.map { a in
            TAttDef(id: a.id, slot: TAttSlot(rawValue: a.slot) ?? .mag, name: a.name, desc: describe(a), cost: 0)
        }
    }

    static func describe(_ a: TCustomAtt) -> String {
        var p: [String] = []
        func pct(_ v: Double, _ n: String) { if abs(v - 1) > 0.005 { p.append("\(v > 1 ? "+" : "")\(Int(((v - 1) * 100).rounded()))% \(n)") } }
        pct(a.mag, "magazine"); pct(a.reload, "reload time"); pct(a.recoil, "recoil"); pct(a.dmg, "damage"); pct(a.range, "range")
        if a.silenced { p.append("silenced") }
        return p.isEmpty ? "Custom part" : p.joined(separator: ", ")
    }

    /// how strong a part is; the lab only lets it through under the cap
    static func power(_ a: TCustomAtt) -> Double {
        var p = (1 - a.recoil) * 100 + (1 - a.reload) * 60 + (a.mag - 1) * 40 + (a.dmg - 1) * 120 + (a.range - 1) * 80
        if a.slot == "optic" { p += (26 - a.zoom) * 1.2 }
        if a.silenced { p += 10 }
        return p
    }
    static let powerCap = 30.0

    static func newId(_ prefix: String) -> String { prefix + String(UInt32.random(in: 0...UInt32.max), radix: 36) }

    // share codes (copy / paste between players)
    static func code(_ c: TCustomCamo) -> String { "BCCAMO1:" + ((try? JSONEncoder().encode(c))?.base64EncodedString() ?? "") }
    static func code(_ a: TCustomAtt) -> String { "BCATT1:" + ((try? JSONEncoder().encode(a))?.base64EncodedString() ?? "") }

    /// returns what it imported, or nil if the text isn't a share code
    @discardableResult
    static func importCode(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("BCCAMO1:"), let d = Data(base64Encoded: String(s.dropFirst(8))), var c = try? JSONDecoder().decode(TCustomCamo.self, from: d), c.c1.count == 3, c.c2.count == 3, c.c3.count == 3 {
            c.id = newId("cc_"); c.pat = max(0, min(5, c.pat))
            camos = camos + [c]; TAtt.own(c.id)
            return c.name
        }
        if s.hasPrefix("BCATT1:"), let d = Data(base64Encoded: String(s.dropFirst(7))), var a = try? JSONDecoder().decode(TCustomAtt.self, from: d), TAttSlot(rawValue: a.slot) != nil, a.slot != "camo", TAtt.baseDefs.contains(where: { $0.id == a.base }) {
            guard power(a) <= powerCap else { return nil }
            a.id = newId("ca_")
            atts = atts + [a]; TAtt.own(a.id)
            return a.name
        }
        return nil
    }
}

// MARK: - lab screen

struct CamoLabView: View {
    @EnvironmentObject var nav: Nav
    let back: () -> Void

    @State private var tab = 0                       // 0 camo, 1 attachment
    @State private var gid = "rifle"
    @State private var yaw: Double = 0
    @State private var tick = 0
    @State private var note = ""

    // camo draft
    @State private var cEditing: String? = nil       // id of the saved camo being edited
    @State private var cName = "My Camo"
    @State private var cPat = 1
    @State private var cC1 = Color(red: 0.2, green: 0.34, blue: 0.14)
    @State private var cC2 = Color(red: 0.34, green: 0.27, blue: 0.13)
    @State private var cC3 = Color(red: 0.08, green: 0.14, blue: 0.07)

    // attachment draft
    @State private var aEditing: String? = nil
    @State private var aSlot = "muzzle"
    @State private var aBase = "comp"
    @State private var aName = "My Part"
    @State private var aMag = 1.0
    @State private var aReload = 1.0
    @State private var aRecoil = 1.0
    @State private var aDmg = 1.0
    @State private var aRange = 1.0
    @State private var aZoom = 26.0
    @State private var aSil = false

    private let patNames = ["SOLID", "BLOTCH", "DIGITAL", "STRIPE", "CARBON", "SPLATTER"]
    private let slots: [(String, String)] = [("mag", "MAGAZINE"), ("muzzle", "MUZZLE"), ("optic", "OPTIC"), ("grip", "GRIP")]

    private func rgb(_ c: Color) -> [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Double(r), Double(g), Double(b)]
    }
    private func col(_ a: [Double]) -> Color { Color(red: a[0], green: a[1], blue: a[2]) }

    private func draftCamo() -> TCustomCamo {
        TCustomCamo(id: "cc_draft_\(tick)", name: cName, c1: rgb(cC1), c2: rgb(cC2), c3: rgb(cC3), pat: cPat)
    }

    private func draftAtt() -> TCustomAtt {
        TCustomAtt(id: "ca_draft_\(tick)", name: aName, slot: aSlot, base: aBase, mag: aMag, reload: aReload, recoil: aRecoil, dmg: aDmg, range: aRange, zoom: aZoom, silenced: aSil)
    }

    /// pushes the current draft onto the preview gun
    private func refresh() {
        TAttPattern.forget("cc_draft_\(tick)")
        tick += 1
        if tab == 0 {
            let d = draftCamo()
            TAttCustom.draftCamo = d
            TAtt.pv["\(gid)|camo"] = d.id
        } else {
            TAttCustom.draftCamo = nil
            let d = draftAtt()
            TAttCustom.draftAtt = d
            TAtt.pv["\(gid)|\(aSlot)"] = d.id
        }
    }

    private func clearPreview() {
        TAttPattern.forget("cc_draft_\(tick)")
        TAtt.pv = [:]
        TAttCustom.draftCamo = nil
        TAttCustom.draftAtt = nil
    }

    private func baseParts(_ slot: String) -> [TAttDef] { TAtt.baseDefs.filter { $0.slot.rawValue == slot } }

    private func saveCamo() {
        let c = TCustomCamo(id: cEditing ?? TAttCustom.newId("cc_"), name: cName.trimmingCharacters(in: .whitespaces).isEmpty ? "My Camo" : cName, c1: rgb(cC1), c2: rgb(cC2), c3: rgb(cC3), pat: cPat)
        var l = TAttCustom.camos
        // a fresh id on every save so the cached pattern image never goes stale
        if let e = cEditing { l.removeAll { $0.id == e } }
        var n = c
        n.id = TAttCustom.newId("cc_")
        l.append(n)
        TAttCustom.camos = l
        TAtt.own(n.id)
        if let e = cEditing, TAtt.realEq(gid, .camo) == e { TAtt.setEq(gid, .camo, n.id) }
        cEditing = n.id
        note = "Saved \(n.name)"
        refresh()
    }

    private func saveAtt() {
        let p = TAttCustom.power(draftAtt())
        guard p <= TAttCustom.powerCap else { note = "Over the power cap. Add a drawback."; return }
        var a = draftAtt()
        a.name = a.name.trimmingCharacters(in: .whitespaces).isEmpty ? "My Part" : a.name
        var l = TAttCustom.atts
        if let e = aEditing, let i = l.firstIndex(where: { $0.id == e }) {
            a.id = e
            l[i] = a
        } else {
            a.id = TAttCustom.newId("ca_")
            l.append(a)
        }
        TAttCustom.atts = l
        TAtt.own(a.id)
        aEditing = a.id
        note = "Saved \(a.name)"
        refresh()
    }

    private func loadCamo(_ c: TCustomCamo) {
        cEditing = c.id; cName = c.name; cPat = c.pat; cC1 = col(c.c1); cC2 = col(c.c2); cC3 = col(c.c3)
        refresh()
    }

    private func loadAtt(_ a: TCustomAtt) {
        aEditing = a.id; aName = a.name; aSlot = a.slot; aBase = a.base
        aMag = a.mag; aReload = a.reload; aRecoil = a.recoil; aDmg = a.dmg; aRange = a.range; aZoom = a.zoom; aSil = a.silenced
        refresh()
    }

    private func paste() {
        if let s = UIPasteboard.general.string, let n = TAttCustom.importCode(s) { note = "Imported \(n)"; tick += 1 } else { note = "Clipboard has no valid BattleCam code" }
    }

    // MARK: ui pieces

    private func chip(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.jk(9, .heavy)).foregroundColor(on ? .black : .white).padding(.horizontal, 8).frame(height: 26)
                .background(on ? LS.orange : LS.card)
                .overlay(Rectangle().stroke(on ? LS.orange : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func action(_ t: String, hot: Bool = false, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(t).font(.jk(10, .heavy)).foregroundColor(hot ? .black : .white).frame(maxWidth: .infinity).frame(height: 30)
                .background(hot ? LS.orange : LS.card)
                .overlay(Rectangle().stroke(hot ? LS.orange : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func slider(_ label: String, _ v: Binding<Double>, _ r: ClosedRange<Double>, _ fmt: String = "%.2f") -> some View {
        HStack(spacing: 6) {
            Text(label).font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.7)).frame(width: 64, alignment: .leading)
            Slider(value: v, in: r)
                .tint(LS.orange)
                .onChange(of: v.wrappedValue) { _ in refresh() }
            Text(String(format: fmt, v.wrappedValue)).font(.jk(10, .heavy)).foregroundColor(.white).frame(width: 40, alignment: .trailing)
        }
    }

    private var library: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tab == 0 ? "MY CAMOS" : "MY PARTS").font(.jk(11, .heavy)).foregroundColor(.white)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 3) {
                    if tab == 0 {
                        if TAttCustom.camos.isEmpty { Text("None yet. Make one and save it.").font(.jk(9, .medium)).foregroundColor(.white.opacity(0.5)) }
                        ForEach(TAttCustom.camos, id: \.id) { c in
                            row(c.name, sel: cEditing == c.id, swatch: [col(c.c1), col(c.c2), col(c.c3)]) { loadCamo(c) }
                        }
                    } else {
                        if TAttCustom.atts.isEmpty { Text("None yet. Build a part and save it.").font(.jk(9, .medium)).foregroundColor(.white.opacity(0.5)) }
                        ForEach(TAttCustom.atts, id: \.id) { a in
                            row(a.name, sel: aEditing == a.id, swatch: [], sub: a.slot.uppercased()) { loadAtt(a) }
                        }
                    }
                }
            }
            HStack(spacing: 4) {
                action("NEW") {
                    if tab == 0 { cEditing = nil; cName = "My Camo" } else { aEditing = nil; aName = "My Part" }
                    refresh()
                }
                action("IMPORT") { paste() }
            }
        }
    }

    private func row(_ name: String, sel: Bool, swatch: [Color], sub: String = "", _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            HStack(spacing: 6) {
                if !swatch.isEmpty { HStack(spacing: 0) { ForEach(0..<swatch.count, id: \.self) { Rectangle().fill(swatch[$0]).frame(width: 7, height: 18) } } }
                VStack(alignment: .leading, spacing: 0) {
                    Text(name).font(.jk(10, .heavy)).foregroundColor(sel ? LS.orange : .white).lineLimit(1)
                    if !sub.isEmpty { Text(sub).font(.jk(8, .semibold)).foregroundColor(.white.opacity(0.5)) }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6).frame(height: 28)
            .background(sel ? LS.orange.opacity(0.14) : LS.card)
            .overlay(Rectangle().stroke(sel ? LS.orange : LS.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private var camoEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Camo name", text: $cName).font(.jk(13, .heavy)).foregroundColor(.white)
                .padding(.horizontal, 8).frame(height: 30).background(Color.black.opacity(0.5)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                .onChange(of: cName) { _ in refresh() }
            Text("PATTERN").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.6))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                ForEach(0..<patNames.count, id: \.self) { i in chip(patNames[i], cPat == i) { cPat = i; refresh() } }
            }
            HStack(spacing: 8) {
                picker("BASE", $cC1)
                picker("ACCENT", $cC2)
                picker("SHADOW", $cC3)
            }
            Menu {
                ForEach(TAtt.baseDefs.filter { $0.slot == .camo }, id: \.id) { d in
                    Button(d.name) {
                        if let c = d.color { cC1 = Color(red: c.0, green: c.1, blue: c.2) }
                        if let c = d.c2 { cC2 = Color(red: c.0, green: c.1, blue: c.2) } else if let c = d.color { cC2 = Color(red: c.0 * 0.6, green: c.1 * 0.6, blue: c.2 * 0.6) }
                        if let c = d.c3 { cC3 = Color(red: c.0, green: c.1, blue: c.2) } else if let c = d.color { cC3 = Color(red: c.0 * 0.35, green: c.1 * 0.35, blue: c.2 * 0.35) }
                        cPat = d.pat
                        refresh()
                    }
                }
            } label: {
                Text("START FROM A BUILT-IN CAMO  ▾").font(.jk(9, .heavy)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 28)
                    .background(LS.card).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            }
            HStack(spacing: 4) {
                action("SAVE", hot: true) { saveCamo() }
                action("EQUIP") {
                    if cEditing == nil { saveCamo() }
                    if let e = cEditing { TAtt.setEq(gid, .camo, e); note = "Equipped on \(TWeapons.w(gid).name)" }
                }
            }
            HStack(spacing: 4) {
                action("COPY SHARE CODE") {
                    let c = draftCamo()
                    UIPasteboard.general.string = TAttCustom.code(c)
                    note = "Code copied. Send it, they tap IMPORT."
                }
                action("DELETE") {
                    if let e = cEditing {
                        TAttCustom.camos = TAttCustom.camos.filter { $0.id != e }
                        if TAtt.realEq(gid, .camo) == e { TAtt.setEq(gid, .camo, nil) }
                        cEditing = nil; note = "Deleted"; refresh()
                    }
                }
            }
        }
    }

    private func picker(_ t: String, _ b: Binding<Color>) -> some View {
        VStack(spacing: 2) {
            ColorPicker("", selection: b, supportsOpacity: false).labelsHidden()
                .onChange(of: b.wrappedValue) { _ in refresh() }
            Text(t).font(.jk(8, .heavy)).foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var attEditor: some View {
        let p = TAttCustom.power(draftAtt())
        let over = p > TAttCustom.powerCap
        return VStack(alignment: .leading, spacing: 5) {
            TextField("Part name", text: $aName).font(.jk(13, .heavy)).foregroundColor(.white)
                .padding(.horizontal, 8).frame(height: 30).background(Color.black.opacity(0.5)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                .onChange(of: aName) { _ in refresh() }
            HStack(spacing: 4) {
                ForEach(slots, id: \.0) { s in
                    chip(s.1, aSlot == s.0) {
                        aSlot = s.0
                        aBase = baseParts(s.0).first?.id ?? aBase
                        refresh()
                    }
                }
            }
            HStack(spacing: 4) {
                Text("LOOKS LIKE").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.6))
                ForEach(baseParts(aSlot), id: \.id) { d in chip(d.name.uppercased(), aBase == d.id) { aBase = d.id; refresh() } }
            }
            slider("MAGAZINE", $aMag, 1...2, "x%.2f")
            slider("RECOIL", $aRecoil, 0.5...1.1, "x%.2f")
            slider("RELOAD", $aReload, 0.8...1.4, "x%.2f")
            slider("DAMAGE", $aDmg, 0.8...1.1, "x%.2f")
            slider("RANGE", $aRange, 0.9...1.3, "x%.2f")
            if aSlot == "optic" { slider("ZOOM FOV", $aZoom, 12...28, "%.0f") }
            if aSlot == "muzzle" {
                Toggle(isOn: $aSil) { Text("SILENCED").font(.jk(9, .heavy)).foregroundColor(.white) }
                    .tint(LS.orange).onChange(of: aSil) { _ in refresh() }
            }
            HStack(spacing: 6) {
                Text("POWER").font(.jk(9, .heavy)).foregroundColor(.white.opacity(0.7))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.white.opacity(0.15))
                        Rectangle().fill(over ? TUI.red : LS.green).frame(width: g.size.width * CGFloat(max(0, min(1, p / TAttCustom.powerCap))))
                    }
                }
                .frame(height: 6)
                Text(String(format: "%.0f / %.0f", p, TAttCustom.powerCap)).font(.jk(9, .heavy)).foregroundColor(over ? TUI.red : .white)
            }
            HStack(spacing: 4) {
                action("SAVE", hot: !over) { saveAtt() }
                action("EQUIP") {
                    if aEditing == nil { saveAtt() }
                    if let e = aEditing, TAttCustom.att(e) != nil, let sl = TAttSlot(rawValue: aSlot) { TAtt.setEq(gid, sl, e); note = "Equipped on \(TWeapons.w(gid).name)" }
                }
            }
            HStack(spacing: 4) {
                action("COPY SHARE CODE") {
                    if over { note = "Over the power cap"; return }
                    UIPasteboard.general.string = TAttCustom.code(draftAtt())
                    note = "Code copied. Send it, they tap IMPORT."
                }
                action("DELETE") {
                    if let e = aEditing {
                        TAttCustom.atts = TAttCustom.atts.filter { $0.id != e }
                        if let sl = TAttSlot(rawValue: aSlot), TAtt.realEq(gid, sl) == e { TAtt.setEq(gid, sl, nil) }
                        aEditing = nil; note = "Deleted"; refresh()
                    }
                }
            }
        }
    }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            ZStack {
                BodycamBackdrop()
                // header
                HStack(spacing: 8) {
                    Button { clearPreview(); back() } label: {
                        HStack(spacing: 4) { SF("chevron.left").font(.system(size: 12, weight: .bold)); Text("BACK").font(.jk(11, .heavy)) }
                            .foregroundColor(.white).padding(.horizontal, 10).frame(height: 30).background(LS.card).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    }
                    .buttonStyle(TuiPress())
                    chip("CAMO LAB", tab == 0) { tab = 0; refresh() }
                    chip("ATTACHMENT LAB", tab == 1) { tab = 1; refresh() }
                    Spacer()
                    Text(note).font(.jk(10, .heavy)).foregroundColor(LS.orange).lineLimit(1)
                }
                .padding(.horizontal, 12)
                .position(x: W / 2, y: 28)
                // library (left)
                library
                    .padding(8).frame(width: 150, height: H - 150, alignment: .topLeading)
                    .background(LS.panel.opacity(0.92)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    .position(x: 12 + 75, y: 56 + (H - 150) / 2)
                // preview (middle)
                let mw = W - 150 - 300 - 48
                ZStack {
                    GunPreview3D(gid: gid, sig: TAtt.viewSig(gid) + "#\(tick)", yaw: yaw)
                        .allowsHitTesting(false)
                    Color.clear.contentShape(Rectangle())
                        .gesture(DragGesture().onChanged { v in yaw = Double(v.translation.width) * 0.01 })
                }
                .frame(width: mw, height: H - 150)
                .background(Color.black.opacity(0.35)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                .position(x: 12 + 150 + 12 + mw / 2, y: 56 + (H - 150) / 2)
                // weapon strip (bottom of preview)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(TWeapons.all.map { $0.id }, id: \.self) { id in
                            chip(TWeapons.w(id).name.uppercased(), gid == id) { TAtt.pv = [:]; gid = id; refresh() }
                        }
                    }
                }
                .frame(width: mw, height: 30)
                .position(x: 12 + 150 + 12 + mw / 2, y: H - 62)
                // editor (right)
                ScrollView(showsIndicators: false) {
                    Group { if tab == 0 { camoEditor } else { attEditor } }
                        .padding(8)
                }
                .frame(width: 300, height: H - 100)
                .background(LS.panel.opacity(0.92)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                .position(x: W - 12 - 150, y: 56 + (H - 100) / 2 - 6)
            }
        }
        .onAppear {
            if let w = TWeapons.all.first(where: { $0.id == nav.tacGun }) { gid = w.id }
            aBase = baseParts(aSlot).first?.id ?? "comp"
            refresh()
        }
        .onDisappear { clearPreview() }
    }
}
