import SwiftUI

/// Dress-up studio for the player's avatar: skin, hair, outfits, hats, face paint, glasses, animated backdrops.
struct AvatarStudioView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var look = AvatarLook()
    @State private var tab = 0
    @State private var manualShot: AvatarShot? = nil

    private let tabs = ["Skin", "Face", "Hair", "Beard", "Outfit", "Body", "Hats", "Paint", "Eyewear", "Jewelry", "Mask"]
    private let tabIcons = ["drop.fill", "face.smiling", "scissors", "mustache.fill", "tshirt.fill", "figure.stand", "graduationcap.fill", "paintbrush.fill", "eyeglasses", "sparkles", "theatermasks.fill"]
    private var tabShot: AvatarShot {
        switch tabs[tab] {
        case "Skin", "Body": return .full
        case "Outfit": return .upper
        case "Hair": return .hair
        default: return .head
        }
    }
    private var shot: AvatarShot { manualShot ?? tabShot }
    private let buildNames = ["Slim", "Average", "Athletic", "Heavy"]
    private let heightNames = ["Short", "Average", "Tall"]
    private let pantsStyleNames = ["Cargo", "Jeans", "Tactical", "Shorts"]
    private let gloveNames = ["None", "Fingerless", "Full"]
    private let packNames = ["None", "Small", "Large"]
    private let shapeNames = ["Default", "Slim", "Round", "Wide", "Long"]
    private let hairStyles = [0, 1, 2, 3, 4, 5, 6, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 9]
    private let hairNames = ["Crop", "Long", "Buzz", "Afro", "Bun", "Swoop", "Waves", "Mohawk", "Ponytail", "Braids", "Curly", "Side part", "Spiky", "Mullet", "Pigtails", "Undercut", "Space buns", "Bald"]
    private let eyeNames = ["Round", "Wide", "Happy"]
    private let browNames = ["Thin", "Thick", "Angry", "Raised", "None"]
    private let noseNames = ["Line", "Button", "Wide", "Pointed"]
    private let mouthNames = ["Smile", "Flat", "Smirk", "Grin"]
    private let beardNames = ["None", "Stubble", "Mustache", "Goatee", "Full beard", "Soul patch", "Handlebar", "Chinstrap"]
    private let outfitNames = ["Tee", "Hoodie", "Collar", "Turtle", "Jacket", "Jersey", "Suit", "Tank", "Overalls", "Hawaiian", "Armor", "Lab coat", "Varsity", "Kimono", "Combat", "Carrier"]
    private let neckNames = ["None", "Scarf", "Bow tie", "Bandana"]
    private let hatNames = ["None", "Beanie", "Cap", "Crown", "Party", "Cowboy", "Band", "Halo", "Bunny", "Cat", "Top hat", "Wizard", "Horns", "Pirate", "Santa", "Chef", "Flowers", "Antenna", "Headset", "Bucket", "Viking", "Grad cap"]
    private let paintNames = ["None", "Stripes", "Stars", "Bolt", "Tiger", "Clown", "Cyber", "Hearts", "Skull", "Bandit", "Galaxy", "Flames", "Tears", "Whiskers", "Rainbow", "Full skull", "Eye black", "Butterfly"]
    private let specNames = ["None", "Round", "Shades", "Visor"]
    private let earNames = ["None", "Stud", "Hoops", "Drops"]
    private let pierceNames = ["None", "Nose", "Brow", "Lip", "Septum"]
    private let maskNames = ["None", "Surgical", "Ninja", "Bandana", "Respirator", "Hero", "Luchador", "Ski mask"]
    private let necklaceNames = ["None", "Chain", "Cuban", "Layered", "Pearls", "Choker", "Pendant choker", "Dog tags", "Cross", "Beads"]
    private let metalNames = ["Gold", "Silver", "Rose", "Black", "Neon"]
    private let animNames = ["Still", "Aurora", "Stars", "Matrix", "Bubbles", "Pulse", "Glitch", "Embers", "Rainbow", "Snow", "Confetti", "Storm", "Sakura", "Waves", "Radar", "Hearts", "Synthwave", "Fireflies"]
    private let patternNames = ["None", "Grid", "Dots", "Stripes", "Diamonds"]
    private let frameNames = ["None", "Gold", "Neon", "Fire", "Rainbow", "Pixel", "Double"]
    private let stickerNames = ["None", "Star", "Fire", "Crown", "Gem", "Skull", "Bolt", "Heart", "Rainbow", "Ghost", "Music", "Rocket"]
    private let accNames = ["None", "Bow", "Clips", "Scrunchie", "Flower"]
    private let moleNames = ["None", "Cheek", "Lip", "Brow"]
    private let scarNames = ["None", "Brow", "Cheek"]
    private let blushNames = ["Soft", "None", "Strong"]

    private var key: String { TacAvatar.myKey }
    private let cols = [GridItem(.adaptive(minimum: 84), spacing: 10)]

    private func col(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 255) / 255, green: Double((v >> 8) & 255) / 255, blue: Double(v & 255) / 255)
    }

    private func variant(_ f: (inout AvatarLook) -> Void) -> AvatarLook {
        var l = look
        f(&l)
        l.anim = 0
        l.frame = 0
        return l
    }

    private func tile(_ label: String, _ v: AvatarLook, shot ts: AvatarShot = .head, on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            VStack(spacing: 5) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Color(red: 0.17, green: 0.2, blue: 0.3), Color(red: 0.09, green: 0.1, blue: 0.16)], startPoint: .top, endPoint: .bottom))
                    AvatarThumb(key: key, look: v, shot: ts).padding(3)
                    if on {
                        SF("checkmark.circle.fill").font(.system(size: 17)).foregroundColor(TUI.accent).background(Circle().fill(Color.black).padding(2)).padding(5)
                    }
                }
                .frame(height: 84)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(on ? TUI.accent : Color.white.opacity(0.08), lineWidth: on ? 2.5 : 1))
                Text(label).font(.jk(11, .semibold)).foregroundColor(on ? Color.white : T.sub).lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func swatch(_ c: Color, on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Circle().fill(c).frame(width: 40, height: 40)
                .overlay(Circle().stroke(on ? Color.white : Color.white.opacity(0.15), lineWidth: on ? 3 : 1))
        }
        .buttonStyle(.plain)
    }

    private func gradSwatch(_ a: Color, _ b: Color, on: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Circle().fill(LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 40, height: 40)
                .overlay(Circle().stroke(on ? Color.white : Color.white.opacity(0.15), lineWidth: on ? 3 : 1))
        }
        .buttonStyle(.plain)
    }

    private func chips(_ names: [String], _ sel: Int?, _ pick: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
            ForEach(0..<names.count, id: \.self) { i in
                Button { pick(i) } label: {
                    Text(names[i]).font(.jk(14, .semibold)).foregroundColor(sel == i ? Color.white : T.sub)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(sel == i ? T.blue : T.card2).clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func flag(_ title: String, _ b: Binding<Bool?>) -> some View {
        Toggle(title, isOn: Binding(get: { b.wrappedValue ?? false }, set: { b.wrappedValue = $0 }))
            .font(.jk(16, .semibold))
    }

    private func palette(_ vals: [UInt32], _ sel: Int?, _ pick: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: cols, spacing: 14) {
            ForEach(0..<vals.count, id: \.self) { i in
                swatch(col(vals[i]), on: sel == i) { pick(i) }
            }
        }
    }

    private func section(_ t: String) -> some View {
        Text(t).font(.jk(14, .bold)).foregroundColor(T.sub)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
    }

    private func tri(_ title: String, _ b: Binding<Bool?>) -> some View {
        HStack {
            Text(title).font(.jk(16, .semibold))
            Spacer()
            Picker("", selection: b) {
                Text("Auto").tag(Bool?.none)
                Text("On").tag(Bool?.some(true))
                Text("Off").tag(Bool?.some(false))
            }
            .pickerStyle(.segmented).frame(width: 190)
        }
    }

    private func randomize() {
        var l = AvatarLook()
        l.skin = Int.random(in: 0..<8)
        l.faceShape = Int.random(in: 0..<5)
        l.hair = Int.random(in: 0..<13)
        l.hairStyle = hairStyles.randomElement()
        l.streak = Int.random(in: 0..<4) == 0 ? Int.random(in: 0..<13) : nil
        l.hairAcc = Int.random(in: 0..<5) == 0 ? Int.random(in: 1...4) : 0
        l.top = Int.random(in: 0..<12)
        l.outfit = Int.random(in: 0..<16)
        l.neck = Int.random(in: 0..<5) == 0 ? Int.random(in: 1...3) : 0
        l.eyes = Int.random(in: 0..<3)
        l.eyeColor = Int.random(in: 0..<9)
        l.brow = Int.random(in: 0..<5)
        l.lashes = Bool.random()
        l.nose = Int.random(in: 0..<4)
        l.mouth = Int.random(in: 0..<4)
        l.lips = Int.random(in: 0..<3) == 0 ? Int.random(in: 0..<7) : nil
        l.beard = Int.random(in: 0..<3) == 0 ? Int.random(in: 1...7) : 0
        l.freckles = Int.random(in: 0..<4) == 0
        l.mole = Int.random(in: 0..<5) == 0 ? Int.random(in: 1...3) : 0
        l.scar = Int.random(in: 0..<8) == 0 ? Int.random(in: 1...2) : 0
        l.blush = Int.random(in: 0..<3)
        l.specs = [0, 0, 1, 2, 3].randomElement()
        l.hat = Bool.random() ? Int.random(in: 1...21) : 0
        l.hatColor = Int.random(in: 0..<12)
        l.paint = Int.random(in: 0...2) == 0 ? Int.random(in: 1...17) : 0
        l.paintColor = Int.random(in: 0..<8)
        l.necklace = Int.random(in: 0..<3) == 0 ? Int.random(in: 1...9) : 0
        l.metal = Int.random(in: 0..<5)
        l.ear = Int.random(in: 0..<4)
        l.pierce = Int.random(in: 0..<6) == 0 ? Int.random(in: 1...4) : 0
        l.mask = Int.random(in: 0..<10) == 0 ? Int.random(in: 1...7) : 0
        l.accent = Int.random(in: 0..<8)
        l.build = Int.random(in: 0..<4)
        l.height = Int.random(in: 0..<3)
        l.pants = Int.random(in: 0..<TacAvatar.pantsCols.count)
        l.pantsStyle = Int.random(in: 0..<4)
        l.shoes = Int.random(in: 0..<TacAvatar.shoeCols.count)
        l.gloves = Int.random(in: 0..<3)
        l.gloveCol = Int.random(in: 0..<8)
        l.vestCol = Int.random(in: 0..<TacAvatar.vestCols.count)
        l.pack = Int.random(in: 0..<3)
        l.packCol = Int.random(in: 0..<TacAvatar.vestCols.count)
        look = l
    }

    private func save() {
        AvatarLooks.save(look, handle: key)
        dismiss()
    }

    private func shotButton(_ icon: String, _ sh: AvatarShot) -> some View {
        Button { manualShot = sh } label: {
            SF(icon).font(.system(size: 15, weight: .bold))
                .foregroundColor(shot == sh ? TUI.ink : .white)
                .frame(width: 38, height: 38)
                .background(Circle().fill(shot == sh ? TUI.accent : Color.black.opacity(0.5)))
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var stagePanel: some View {
        ZStack {
            AvatarStageView(style: TacAvatar.style(key, look), shot: shot)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
            VStack {
                HStack(alignment: .top) {
                    Button { dismiss() } label: {
                        SF("chevron.left").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(Color.black.opacity(0.5)))
                            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        shotButton("figure.stand", .full)
                        shotButton("person.crop.square.fill", .upper)
                        shotButton("face.smiling", .head)
                        shotButton("scissors", .hair)
                        shotButton("arrow.uturn.backward", .back)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Button { randomize() } label: {
                        Label("Random", systemImage: "dice.fill").font(.jk(12, .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 9).background(Capsule().fill(Color.black.opacity(0.55)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                    Button { look = TacAvatar.full(key, nil) } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise").font(.jk(12, .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 9).background(Capsule().fill(Color.black.opacity(0.55)))
                            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    }
                }
                Button(action: save) {
                    Text("SAVE").font(.jk(15, .heavy)).foregroundColor(TUI.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 12).background(Capsule().fill(TUI.accent))
                }
                .buttonStyle(TuiPress())
            }
            .padding(12)
        }
    }

    private var tabRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(0..<tabs.count, id: \.self) { i in
                    Button { tab = i; manualShot = nil } label: {
                        VStack(spacing: 4) {
                            SF(tabIcons[i]).font(.system(size: 17, weight: .semibold))
                            Text(tabs[i]).font(.jk(10, .bold))
                        }
                        .foregroundColor(tab == i ? TUI.ink : T.sub)
                        .frame(width: 62, height: 50)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tab == i ? TUI.accent : T.card2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 10)
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                stagePanel
                    .padding(12)
                    .frame(width: min(400, geo.size.width * 0.42))
                VStack(spacing: 0) {
                    tabRail
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            content
                        }
                        .padding(14).padding(.bottom, 24)
                    }
                    .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(T.card.opacity(0.55)))
                    .padding(.trailing, 10).padding(.bottom, 10)
                }
            }
        }
        .background(T.bg.ignoresSafeArea())
        .onAppear { look = TacAvatar.look(for: key) }
    }

    @ViewBuilder private var content: some View {
        switch tabs[tab] {
        case "Skin": skinTab
        case "Face": faceTab
        case "Hair": hairTab
        case "Beard": beardTab
        case "Outfit": outfitTab
        case "Body": bodyTab
        case "Hats": hatTab
        case "Paint": paintTab
        case "Eyewear": glassesTab
        case "Jewelry": jewelryTab
        default: maskTab
        }
    }

    private var bodyTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Build")
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<buildNames.count, id: \.self) { i in
                    tile(buildNames[i], variant { $0.build = i }, shot: .full, on: (look.build ?? 1) == i) { look.build = i }
                }
            }
            section("Height")
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<heightNames.count, id: \.self) { i in
                    tile(heightNames[i], variant { $0.height = i }, shot: .full, on: (look.height ?? 1) == i) { look.height = i }
                }
            }
            section("Pants")
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<pantsStyleNames.count, id: \.self) { i in
                    tile(pantsStyleNames[i], variant { $0.pantsStyle = i }, shot: .legs, on: (look.pantsStyle ?? 0) == i) { look.pantsStyle = i }
                }
            }
            palette(TacAvatar.pantsCols, look.pants ?? 0) { look.pants = $0 }
            section("Shoes")
            palette(TacAvatar.shoeCols, look.shoes ?? 0) { look.shoes = $0 }
            section("Gloves")
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<gloveNames.count, id: \.self) { i in
                    tile(gloveNames[i], variant { $0.gloves = i }, shot: .upper, on: (look.gloves ?? 0) == i) { look.gloves = i }
                }
            }
            palette(PortraitAvatar.paints, look.gloveCol ?? 0) { look.gloveCol = $0 }
            section("Armor colour")
            palette(TacAvatar.vestCols, look.vestCol ?? 0) { look.vestCol = $0 }
            section("Backpack")
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(0..<packNames.count, id: \.self) { i in
                    tile(packNames[i], variant { $0.pack = i }, shot: .back, on: (look.pack ?? 0) == i) { look.pack = i }
                }
            }
            palette(TacAvatar.vestCols, look.packCol ?? 0) { look.packCol = $0 }
        }
    }

    private var skinTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Skin tone")
            palette(PortraitAvatar.skins, look.skin) { look.skin = $0 }
            section("Face shape")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<shapeNames.count, id: \.self) { i in
                    tile(shapeNames[i], variant { $0.faceShape = i }, on: (look.faceShape ?? 0) == i) { look.faceShape = i }
                }
            }
            section("Blush")
            chips(blushNames, look.blush ?? 0) { look.blush = $0 }
            section("Marks")
            flag("Freckles", $look.freckles)
            Text("Mole").font(.jk(14, .bold)).foregroundColor(T.sub).padding(.top, 4)
            chips(moleNames, look.mole ?? 0) { look.mole = $0 }
            Text("Scar").font(.jk(14, .bold)).foregroundColor(T.sub).padding(.top, 4)
            chips(scarNames, look.scar ?? 0) { look.scar = $0 }
        }
    }

    private var faceTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Eyes")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<eyeNames.count, id: \.self) { i in
                    tile(eyeNames[i], variant { $0.eyes = i }, on: look.eyes == i) { look.eyes = i }
                }
            }
            section("Eye colour")
            palette(PortraitAvatar.eyeCols, look.eyeColor) { look.eyeColor = $0 }
            flag("Lashes", $look.lashes)
            section("Eyebrows")
            chips(browNames, look.brow ?? 0) { look.brow = $0 }
            section("Brow colour")
            palette(PortraitAvatar.hairs, look.browColor) { look.browColor = $0 }
            section("Nose")
            chips(noseNames, (look.nose ?? 0) % 4) { look.nose = $0 }
            section("Mouth")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<mouthNames.count, id: \.self) { i in
                    tile(mouthNames[i], variant { $0.mouth = i }, on: look.mouth == i) { look.mouth = i }
                }
            }
            section("Lip colour")
            palette(PortraitAvatar.lipCols, look.lips) { look.lips = $0 }
            Button { look.lips = nil } label: { Text("No lipstick").font(.jk(14, .semibold)).foregroundColor(T.sub) }
        }
    }

    private var hairTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Style")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<hairStyles.count, id: \.self) { i in
                    let st = hairStyles[i]
                    tile(hairNames[i], variant { $0.hairStyle = st }, shot: .hair, on: look.hairStyle == st) { look.hairStyle = st }
                }
            }
            section("Colour")
            palette(PortraitAvatar.hairs, look.hair) { look.hair = $0 }
            section("Highlight streak")
            palette(PortraitAvatar.hairs, look.streak) { look.streak = $0 }
            Button { look.streak = nil } label: { Text("No streak").font(.jk(14, .semibold)).foregroundColor(T.sub) }
            section("Hair accessory")
            chips(accNames, look.hairAcc ?? 0) { look.hairAcc = $0 }
            section("Accessory colour")
            palette(PortraitAvatar.paints, look.accent ?? 0) { look.accent = $0 }
        }
    }

    private var beardTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Facial hair")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<beardNames.count, id: \.self) { i in
                    tile(beardNames[i], variant { $0.beard = i }, on: (look.beard ?? 0) == i) { look.beard = i }
                }
            }
            section("Colour")
            palette(PortraitAvatar.hairs, look.beardColor) { look.beardColor = $0 }
            Button { look.beardColor = nil } label: { Text("Match hair").font(.jk(14, .semibold)).foregroundColor(T.sub) }
        }
    }

    private var outfitTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Clothes")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<outfitNames.count, id: \.self) { i in
                    tile(outfitNames[i], variant { $0.outfit = i }, shot: .upper, on: look.outfit == i) { look.outfit = i }
                }
            }
            section("Colour")
            palette(PortraitAvatar.tops, look.top) { look.top = $0 }
            section("Neckwear")
            chips(neckNames, look.neck ?? 0) { look.neck = $0 }
            palette(PortraitAvatar.paints, look.accent ?? 0) { look.accent = $0 }
            section("Necklace")
            necklaceGrid
            section("Metal")
            palette(PortraitAvatar.metals, look.metal ?? 0) { look.metal = $0 }
        }
    }

    private var hatTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Hats")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<hatNames.count, id: \.self) { i in
                    tile(hatNames[i], variant { $0.hat = i }, on: look.hat == i) { look.hat = i }
                }
            }
            section("Hat colour")
            palette(PortraitAvatar.tops, look.hatColor) { look.hatColor = $0 }
        }
    }

    private var paintTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Face paint")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<paintNames.count, id: \.self) { i in
                    tile(paintNames[i], variant { $0.paint = i }, on: look.paint == i) { look.paint = i }
                }
            }
            section("Paint colour")
            palette(PortraitAvatar.paints, look.paintColor) { look.paintColor = $0 }
        }
    }

    private var glassesTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Eyewear")
            LazyVGrid(columns: cols, spacing: 14) {
                tile("Auto", variant { $0.specs = nil }, on: look.specs == nil) { look.specs = nil }
                ForEach(0..<specNames.count, id: \.self) { i in
                    tile(specNames[i], variant { $0.specs = i }, on: look.specs == i) { look.specs = i }
                }
            }
        }
    }

    private var jewelryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            section("Earrings")
            chips(earNames, look.ear) { look.ear = $0 }
            section("Piercings")
            chips(pierceNames, look.pierce ?? 0) { look.pierce = $0 }
            section("Necklaces & chokers")
            necklaceGrid
            section("Metal")
            palette(PortraitAvatar.metals, look.metal ?? 0) { look.metal = $0 }
            section("Gem / bead colour")
            palette(PortraitAvatar.paints, look.accent ?? 0) { look.accent = $0 }
            section("Other")
            tri("Headphones", $look.phones)
        }
    }

    private var necklaceGrid: some View {
        LazyVGrid(columns: cols, spacing: 14) {
            ForEach(0..<necklaceNames.count, id: \.self) { i in
                tile(necklaceNames[i], variant { $0.necklace = i; $0.chain = false }, on: (look.necklace ?? (look.chain ? 1 : 0)) == i) { look.necklace = i; look.chain = false }
            }
        }
    }

    private var maskTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            section("Masks")
            LazyVGrid(columns: cols, spacing: 14) {
                ForEach(0..<maskNames.count, id: \.self) { i in
                    tile(maskNames[i], variant { $0.mask = i }, on: (look.mask ?? 0) == i) { look.mask = i }
                }
            }
        }
    }
}
