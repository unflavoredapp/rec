import SwiftUI
import Combine

struct LobbyView: View {
    @EnvironmentObject var game: Game
    @EnvironmentObject var nav: Nav
    @State private var showSeason = false
    @State private var showStats = false
    @State private var showAvatar = false
    @State private var showAdmin = false
    @State private var showRanks = false
    @State private var diff = 1
    @State private var seasonTab = 0
    @State private var username = TacProfile.name
    @State private var screen = 0          // 0 home, 1 game mode, 2 battle search, 3 map loading
    @State private var searchT = 0
    @State private var loadP: CGFloat = 0
    @State private var mapImg: UIImage? = nil
    @State private var cd = 12
    @State private var fromMatch = false
    @State private var gsBack = 6
    @State private var opsBack = 0
    private let modeOrder = [0, 1, 5]
    private let modeLock = [4, 1, 6, 5, 1, 3, 1, 1]

    private let lime = TUI.accent
    private let diffNames = ["EASY", "NORMAL", "HARD"]

    var body: some View {
        GeometryReader { g in
            let t = game.s.ex.tac ?? TacData()
            ZStack {
                BodycamBackdrop()
                Group {
                    switch screen {
                    case 1: modeScreen(t, g.size)
                    case 2: searchScreen(t, g.size)
                    case 3: loadingScreen(g.size)
                    case 4:
                        CSArsenal(gun: $nav.tacGun, rank: TacRank.index(TacRank.totalXP(t)), cash: game.s.ex.gems, coins: t.wins, back: { screen = 0 },
                                  editLoadout: { fromMatch = false; screen = 6 }, editChar: { showAvatar = true }, editCos: { seasonTab = 1; showSeason = true }, offer: { seasonTab = 2; showSeason = true })
                    case 7: CSGunsmith(back: { screen = gsBack })
                    case 8: CSStash(back: { screen = 0 }, ops: { opsBack = 8; screen = 9 })
                    case 9: CSOps(back: { screen = opsBack })
                    case 10: CSMarket(back: { screen = 0 })
                    case 11: workPage(t, g.size)
                    case 12: custPage(t, g.size)
                    case 14: CamoLabView(back: { screen = 12 })
                    case 13: MapEditorView(back: { screen = 0 }, deploy: { nav.tacMap = 5; if nav.tacMode == 6 || nav.tacMode == 7 { nav.tacMode = 1 }; searchT = 0; screen = 2 })
                    case 5: CSLeague(rating: t.rating, cash: game.s.ex.gems, coins: t.wins) { screen = 0 }
                    case 6:
                        if !fromMatch { loadoutPage(t, g.size) } else { CSLoadout(gun: $nav.tacGun, countdown: fromMatch ? cd : nil, showBattle: fromMatch, gunsmith: fromMatch ? nil : { gsBack = 6; screen = 7 }, ok: { if fromMatch { beginMatch() } else { screen = 4 } }, battle: { beginMatch() }) }
                    default: homeScreen(t, g.size)
                    }
                }
                .transition(.opacity)
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if screen == 2 {
                searchT += 1
                if searchT >= 3 { startLoading() }
            }
            if screen == 6 && fromMatch {
                cd -= 1
                if cd <= 0 { beginMatch() }
            }
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            if screen == 3 {
                loadP = min(1, loadP + 0.012 + CGFloat.random(in: 0...0.012))
                if loadP >= 1 { cd = 12; fromMatch = true; screen = 6 }
            }
        }
        .onAppear {
            OrientationLock.set(landscape: true)
            username = TacProfile.name
        }
        .onChange(of: nav.tacPlay) { v in
            if v == nil { OrientationLock.set(landscape: true); screen = 0 }
        }
        .fullScreenCover(isPresented: $showSeason) {
            TacSeasonView(startTab: seasonTab).environmentObject(game).preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: Binding(get: { nav.tacPlay != nil }, set: { if !$0 { nav.tacPlay = nil } })) {
            TacticalPlay(diff: nav.tacPlay ?? 1, modeId: nav.tacMode).environmentObject(game).environmentObject(nav).preferredColorScheme(.dark)
        }
        .fullScreenCover(isPresented: $showAvatar) {
            AvatarStudioView().preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showAdmin) {
            AdminRosterView().preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showStats) {
            statsSheet.preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showRanks) {
            TacRankSheet(t: game.s.ex.tac ?? TacData(), username: $username, onPrestige: { game.tacPrestige() }).preferredColorScheme(.dark)
        }
    }

    private func beginMatch() {
        fromMatch = false
        screen = 0
        nav.tacPlay = diff
    }

    private func startLoading() {
        TMap.load([5, 6, 7].contains(nav.tacMap) ? nav.tacMap : 7)
        mapImg = TacRadar.image(1)
        loadP = 0
        screen = 3
    }

    // MARK: shared

    private func sq(_ w: CGFloat, _ h: CGFloat) -> some View { Color.clear.frame(width: w, height: h) }

    // MARK: home

    private func menuRow(_ icon: String, _ label: String, dot: Bool = false, col: Color = .white, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            HStack(spacing: 8) {
                SF(icon, "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(col).frame(width: 22)
                Text(label).font(.jk(13, .heavy)).foregroundColor(col).lineLimit(1).fixedSize()
                if dot { Text("!").font(.jk(8, .heavy)).foregroundColor(.white).frame(width: 12, height: 12).background(Rectangle().fill(Color.red)).offset(y: -5) }
                Spacer(minLength: 0)
            }
            .frame(height: 20)
            .shadow(color: .black.opacity(0.8), radius: 3, y: 1)
        }
        .buttonStyle(TuiPress())
    }

    private func homeScreen(_ t: TacData, _ size: CGSize) -> some View {
        TacLeague.myRating = t.rating
        return LobbyShell(active: 0, size: size, t: t, act: { homeAct($0) }) {
            LobbyHome(t: t, size: LS.area(size), diff: $diff, act: { homeAct($0) })
        }
    }

    private func loadoutPage(_ t: TacData, _ size: CGSize) -> some View {
        LobbyShell(active: 2, size: size, t: t, act: { homeAct($0) }) {
            LoadoutHome(t: t, size: LS.area(size), act: { homeAct($0) })
        }
    }

    private func custPage(_ t: TacData, _ size: CGSize) -> some View {
        LobbyShell(active: 1, size: size, t: t, act: { homeAct($0) }) {
            CustomizeHome(t: t, size: LS.area(size), act: { homeAct($0) })
        }
    }

    private func workPage(_ t: TacData, _ size: CGSize) -> some View {
        LobbyShell(active: 3, size: size, t: t, act: { homeAct($0) }) {
            CSWorkshop(t: t, size: LS.area(size), act: { homeAct($0) }, playMap: {
                nav.tacMap = 5
                if nav.tacMode == 6 || nav.tacMode == 7 { nav.tacMode = 1 }
                searchT = 0
                screen = 2
            })
        }
    }

    private func homeAct(_ a: LobbyAct) {
        switch a {
        case .nav(let i):
            switch i {
            case 0: screen = 0
            case 1: screen = 12
            case 2: fromMatch = false; screen = 6
            case 3: gsBack = 0; screen = 7
            case 4: showRanks = true
            case 5: showAdmin = true
            case 6: seasonTab = 2; showSeason = true
            case 8: screen = 13
            default: showStats = true
            }
        case .screen(let s):
            if s == 2 { searchT = 0 }
            if s == 7 { gsBack = 0 }
            screen = s
        case .season(let tb): seasonTab = tb; showSeason = true
        case .avatar: showAvatar = true
        case .friends: showAdmin = true
        case .ranks: showRanks = true
        case .stats: showStats = true
        case .loadout: fromMatch = false; screen = 6
        }
    }

    private func contractRow() -> some View {
        let c = TacMeta.pickedContract
        let kit: String = TacStash.kitId == nil ? "ISSUED GUN" : "STASH GUN"
        return Button { opsBack = 0; screen = 9 } label: {
            HStack(spacing: 8) {
                SF("doc.text.fill", "circle.fill").font(.system(size: 18, weight: .bold)).foregroundColor(CS.gold).frame(width: 30)
                VStack(alignment: .leading, spacing: 0) {
                    Text("CONTRACT  ·  \(c.title)").font(.jk(10, .heavy)).foregroundColor(.white).lineLimit(1)
                    Text("+\(c.reward + 10 * TacMeta.traderLevel) GEMS  ·  \(kit)  ·  \(TacStash.packCap) SLOTS").font(.jk(8, .bold)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
                }
                Spacer(minLength: 0)
                SF("chevron.right", "circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 8).frame(width: 250, height: 30).background(Rectangle().fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(TuiPress())
    }

    private func chestRow(_ icon: String, _ v: String, _ col: Color, w: CGFloat = 250) -> some View {
        HStack(spacing: 8) {
            SF("shippingbox.fill", "gift.fill").font(.system(size: 26)).foregroundColor(col)
            HStack(spacing: 6) {
                SF(icon, "circle.fill").font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                Text(v).font(.jk(12, .heavy)).foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 8).frame(height: 22).frame(maxWidth: .infinity, alignment: .leading).background(Rectangle().fill(Color.white.opacity(0.14)))
        }
        .frame(width: w, height: 30)
    }

    // MARK: game mode

    private func modeCard(_ i: Int, _ w: CGFloat, _ h: CGFloat) -> some View {
        let on = nav.tacMode == i
        let col = CS.modeCols[i]
        let r = CS.modeReward[i]
        let lockLv = modeLock[i]
        let locked = TacRank.index(TacRank.totalXP(game.s.ex.tac ?? TacData())) + 1 < lockLv
        return Button { if !locked { nav.tacMode = i } } label: {
            VStack(spacing: 0) {
                Text(TWeapons.modeNames[i]).font(.jk(13, .heavy)).foregroundColor(on ? col : .white)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.55).padding(.horizontal, 3).frame(height: 36).padding(.top, 4)
                Spacer(minLength: 0)
                ZStack {
                    Image(systemName: "hexagon.fill").resizable().scaledToFit().foregroundColor(col.opacity(on ? 0.35 : 0.15)).frame(width: w * 0.5)
                    SF(CS.modeIcons[i], "circle.fill").font(.system(size: w * 0.2, weight: .bold)).foregroundColor(on ? col : .white.opacity(0.75))
                }
                Spacer(minLength: 0)
                Text(CS.modeInfo[i]).font(.jk(9, .semibold)).foregroundColor(.white.opacity(0.6)).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8).padding(.horizontal, 4).frame(height: 24)
                HStack(spacing: 4) {
                    Text("\(r.0)").font(.jk(14, .heavy))
                    SF("circle.hexagongrid.fill", "circle.fill").font(.system(size: 12)).foregroundColor(CS.gold)
                    Text("PER WIN").font(.jk(10, .heavy)).opacity(0.8)
                }
                .foregroundColor(.white).padding(.top, 2)
                HStack(spacing: 4) {
                    Text("\(r.1)").font(.jk(14, .heavy))
                    SF("diamond.fill").font(.system(size: 12)).foregroundColor(Color(red: 0.7, green: 0.35, blue: 1))
                    Text("PER WIN").font(.jk(10, .heavy)).opacity(0.8)
                }
                .foregroundColor(.white).padding(.vertical, 2).padding(.bottom, 4)
            }
            .overlay {
                if locked {
                    ZStack {
                        Color.black.opacity(0.6)
                        VStack(spacing: 4) {
                            SF("lock.fill").font(.system(size: 20)).foregroundColor(.white)
                            Text("REQUIRED LEVEL").font(.jk(8, .heavy)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                            Text("\(lockLv)").font(.jk(18, .heavy)).foregroundColor(.white)
                        }
                    }
                }
            }
            .frame(width: w, height: h)
            .background(LinearGradient(colors: on ? [Color(red: 0.3, green: 0.36, blue: 0.46), Color(red: 0.12, green: 0.15, blue: 0.22)] : [Color(red: 0.1, green: 0.13, blue: 0.2), Color(red: 0.04, green: 0.05, blue: 0.09)], startPoint: .top, endPoint: .bottom))
            .overlay(Rectangle().stroke(on ? col : Color.white.opacity(0.15), lineWidth: on ? 2 : 1))
            .shadow(color: on ? col.opacity(0.45) : .clear, radius: 10)
        }
        .buttonStyle(TuiPress())
    }

    private func modeScreen(_ t: TacData, _ size: CGSize) -> some View {
        let W = size.width, H = size.height
        let cw = min(140, (W - 60 - 7 * 7) / 8)
        return ZStack {
            VStack(spacing: 0) {
                CSHeader(title: "GAME MODE", cash: game.s.ex.gems, coins: t.wins) { screen = 0 }.padding(.top, 8)
                Spacer(minLength: 4)
                HStack(spacing: 7) { ForEach(modeOrder, id: \.self) { modeCard($0, cw, max(150, H - 170)) } }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { i in
                    Button { diff = i } label: {
                        Text(diffNames[i]).font(.jk(12, .heavy)).foregroundColor(diff == i ? .black : .white.opacity(0.85))
                            .frame(width: 78, height: 30)
                            .background(Rectangle().fill(diff == i ? Color.white : Color.white.opacity(0.12)))
                    }
                    .buttonStyle(TuiPress())
                }
            }
            .position(x: W / 2, y: H - 30)
            if nav.tacMode == 7 {
                FrontClassPicker().position(x: W / 2, y: H - 80)
            } else if nav.tacMode != 6 {
                HStack(spacing: 8) {
                    ForEach([6], id: \.self) { k in
                        Button { nav.tacMap = k } label: {
                            Text(TMap.mapNames[k]).font(.jk(11, .heavy)).foregroundColor(nav.tacMap == k ? .black : .white.opacity(0.85))
                                .padding(.horizontal, 12).frame(height: 28)
                                .background(Rectangle().fill(nav.tacMap == k ? CS.gold : Color.white.opacity(0.12)))
                        }
                        .buttonStyle(TuiPress())
                    }
                }
                .position(x: W / 2, y: H - 80)
            } else {
                Text("MAP: WAREHOUSE YARD").font(.jk(11, .heavy)).foregroundColor(CS.gold).position(x: W / 2, y: H - 80)
            }
            CSButton(title: "CREATE SQUAD", w: 180, h: 40, size: 16) { showAdmin = true }.position(x: 100, y: H - 30)
            CSButton(title: "PLAY", col: CS.orange, dark: CS.orangeDark, w: 180, h: 42, size: 26) { searchT = 0; screen = 2 }
                .position(x: W - 110, y: H - 30)
        }
        .padding(.horizontal, 6)
    }

    // MARK: battle search

    private func mono(_ n: CGFloat, _ w: Font.Weight = .bold) -> Font { .system(size: n, weight: w, design: .monospaced) }

    private func recDot(_ label: String) -> some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let on = Int(tl.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            HStack(spacing: 6) {
                Circle().fill(Color(red: 0.95, green: 0.1, blue: 0.1)).frame(width: 9, height: 9).opacity(on ? 1 : 0.25)
                Text(label).font(mono(12)).foregroundColor(.white)
            }
        }
    }

    private static let stampFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd  HH:mm:ss"
        return f
    }()

    private func stamp() -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            Text(Self.stampFmt.string(from: tl.date)).font(mono(10, .regular)).foregroundColor(.white.opacity(0.75))
        }
    }

    private func lsBar(_ frac: CGFloat, _ col: Color, h: CGFloat = 5) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.14))
                Rectangle().fill(col).frame(width: g.size.width * max(0, min(1, frac)))
            }
        }
        .frame(height: h)
    }

    private func unlockRow(_ title: String, _ sub: String, _ v: Int, _ n: Int, _ col: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.jk(11, .heavy)).foregroundColor(.white)
                Spacer()
                Text("\(v)/\(n)").font(mono(11)).foregroundColor(col)
            }
            Text(sub).font(.jk(9, .medium)).foregroundColor(.white.opacity(0.6)).lineLimit(1)
            lsBar(CGFloat(v) / CGFloat(max(1, n)), col)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .overlay(alignment: .bottom) { Rectangle().fill(LS.line).frame(height: 1) }
    }

    private func searchScreen(_ t: TacData, _ size: CGSize) -> some View {
        let W = size.width, H = size.height
        let ri = TacRank.index(TacRank.totalXP(t))
        let mc = CS.modeCols[nav.tacMode]
        return ZStack {
            AvatarSoldierPreview(style: TacAvatar.style(TacAvatar.myKey), rank: ri, gun: nav.tacGun)
                .frame(width: W * 0.4, height: H * 0.92).position(x: W * 0.5, y: H * 0.58).allowsHitTesting(false)
            LinearGradient(colors: [Color.black.opacity(0.55), .clear, Color.black.opacity(0.6)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false)
            BodycamGrain(strength: 0.05).allowsHitTesting(false)
            // frame corners like a viewfinder
            ForEach(0..<4, id: \.self) { i in
                Path { p in
                    let x: CGFloat = i % 2 == 0 ? 12 : W - 12, y: CGFloat = i < 2 ? 12 : H - 12
                    let dx: CGFloat = i % 2 == 0 ? 18 : -18, dy: CGFloat = i < 2 ? 18 : -18
                    p.move(to: CGPoint(x: x + dx, y: y)); p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + dy))
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
            }
            .allowsHitTesting(false)
            recDot("REC").position(x: 56, y: 28)
            stamp().position(x: 120, y: 46)
            Text("NET  AMERICAS-37").font(mono(10)).foregroundColor(LS.green).position(x: W - 84, y: 28)
            // search status
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    SF(CS.modeIcons[nav.tacMode], "circle.fill").font(.system(size: 22, weight: .bold)).foregroundColor(mc).frame(width: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SEARCHING FOR MATCH").font(.jk(10, .heavy)).foregroundColor(.white.opacity(0.65))
                        Text(TWeapons.modeNames[nav.tacMode].uppercased()).font(.jk(18, .heavy)).foregroundColor(LS.orange)
                    }
                    Spacer(minLength: 12)
                    Text(String(format: "00:%02d", searchT)).font(.system(size: 40, weight: .heavy, design: .monospaced)).foregroundColor(.white).monospacedDigit()
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                TimelineView(.animation) { tl in
                    let k = CGFloat((tl.date.timeIntervalSinceReferenceDate * 0.6).truncatingRemainder(dividingBy: 1))
                    GeometryReader { g in
                        Rectangle().fill(LS.orange).frame(width: g.size.width * 0.22).offset(x: (g.size.width * 1.22) * k - g.size.width * 0.22)
                            .frame(width: g.size.width, alignment: .leading).clipped()
                    }
                    .frame(height: 3).background(Color.white.opacity(0.12))
                }
            }
            .frame(width: 400).background(Color.black.opacity(0.88)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
            .position(x: W / 2, y: 76)
            // unlock progress
            LSPanel(title: "UNLOCKS", trailing: "THIS SEASON") {
                VStack(spacing: 0) {
                    unlockRow("WINNER CHEST", "Win matches to unlock", t.wins % 3, 3, LS.green)
                    unlockRow("KILLER CHEST", "Kill 50 enemies to unlock", t.kills % 50, 50, LS.orange)
                }
            }
            .frame(width: 210).position(x: 20 + 105, y: H * 0.5)
            // leaderboard
            LSPanel(title: "TOP OPERATORS", trailing: "TODAY") {
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        let nm = TacRoster.pool[i].name
                        HStack(spacing: 8) {
                            Text(String(format: "%02d", i + 1)).font(mono(13)).foregroundColor(i == 0 ? LS.orange : .white.opacity(0.8)).frame(width: 24, alignment: .leading)
                            Text(nm).font(.jk(12, .heavy)).foregroundColor(.white).lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(5200 - i * 520)").font(mono(11, .regular)).foregroundColor(.white.opacity(0.7))
                            Text("\(50 - i * 5)K").font(mono(11)).foregroundColor(LS.orange).frame(width: 34, alignment: .trailing)
                        }
                        .padding(.horizontal, 10).frame(height: 30)
                        .background(i == 0 ? Color.white.opacity(0.07) : .clear)
                        .overlay(alignment: .bottom) { Rectangle().fill(LS.line).frame(height: 1) }
                    }
                }
            }
            .frame(width: 250).position(x: W - 20 - 125, y: H * 0.55)
            Button { screen = 1 } label: {
                Text("CANCEL").font(.jk(15, .heavy)).foregroundColor(.white).frame(width: 150, height: 40)
                    .background(Color.black.opacity(0.6)).overlay(Rectangle().stroke(Color.white.opacity(0.8), lineWidth: 1.5))
            }
            .buttonStyle(TuiPress()).position(x: 20 + 75, y: H - 32)
        }
    }

    // MARK: loading

    private func loadingScreen(_ size: CGSize) -> some View {
        let W = size.width, H = size.height
        let woods = nav.tacMode == 6
        let m = nav.tacMode
        let tips = ["Pistols are very useful weapons that can save you from a lot of trouble.", "Walls and props can be shot apart. Break cover to flush enemies out.", "Doors can be closed to slow pushes and hide sound.", "Loot the yard, finish your contract and reach an extraction zone alive. Die and you lose the bag."]
        let mapTitle = TMap.mapNames[(woods || m == 7) ? 4 : nav.tacMap]
        return ZStack {
            BodycamGrain(strength: 0.05).allowsHitTesting(false)
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    recDot("REC")
                    Text("TIP").font(mono(10)).foregroundColor(LS.orange)
                    Text(m == 6 ? tips[3] : tips[Int(loadP * 3) % 3]).font(.jk(12, .medium)).foregroundColor(.white.opacity(0.92)).lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    stamp()
                }
                .padding(.horizontal, 12).frame(height: 38).background(Color.black.opacity(0.88)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Color.black
                        if let im = mapImg { Image(uiImage: im).resizable().scaledToFit().padding(10).opacity(0.92) }
                        // viewfinder brackets over the map plan
                        ForEach(0..<4, id: \.self) { i in
                            GeometryReader { g in
                                Path { p in
                                    let x: CGFloat = i % 2 == 0 ? 6 : g.size.width - 6, y: CGFloat = i < 2 ? 6 : g.size.height - 6
                                    let dx: CGFloat = i % 2 == 0 ? 16 : -16, dy: CGFloat = i < 2 ? 16 : -16
                                    p.move(to: CGPoint(x: x + dx, y: y)); p.addLine(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x, y: y + dy))
                                }
                                .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                            }
                        }
                    }
                    .frame(width: W * 0.4, height: H * 0.55)
                    .overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("OPERATION").font(mono(10)).foregroundColor(.white.opacity(0.6))
                                Text(mapTitle).font(.jk(34, .heavy)).lineLimit(1).minimumScaleFactor(0.6).foregroundColor(.white)
                                Text(TWeapons.modeNames[m].uppercased()).font(.jk(18, .heavy)).foregroundColor(LS.orange)
                            }
                            Spacer()
                            SF(CS.modeIcons[m], "circle.fill").font(.system(size: 30, weight: .bold)).foregroundColor(.white.opacity(0.85))
                        }
                        Rectangle().fill(LS.line).frame(height: 1).padding(.vertical, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array([m == 6 ? "Extract with your loot to keep it" : (m == 0 ? "First to 3 rounds wins" : "First to the kill target wins"),
                                           m == 6 ? "Die and the bag is lost" : "5 minutes time limit",
                                           m == 6 ? "Solo raid vs AI squads" : (m == 7 ? "60 combatants · 5 capture points" : "Up to 10 players")].enumerated()), id: \.offset) { _, line in
                                HStack(spacing: 8) {
                                    Rectangle().fill(LS.orange).frame(width: 5, height: 5)
                                    Text(line).font(.jk(13, .semibold)).foregroundColor(.white)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        Text(m == 6 ? "Bodycam rolling. Every shot is on the record." : "Walls and props can be shot apart. Manual aim, manual fire.").font(mono(10, .regular)).foregroundColor(.white.opacity(0.6)).lineLimit(2)
                    }
                    .frame(maxHeight: H * 0.55)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("LOADING MAP").font(mono(12)).foregroundColor(.white)
                        Spacer()
                        Text(String(format: "%03d%%", Int(loadP * 100))).font(mono(12)).foregroundColor(LS.orange)
                    }
                    lsBar(loadP, LS.orange, h: 6)
                }
                .padding(12).background(Color.black.opacity(0.88)).overlay(Rectangle().stroke(LS.line, lineWidth: 1))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16).padding(.top, 10)
        }
    }

    private var statsSheet: some View {
        let t = game.s.ex.tac ?? TacData()
        let rows: [(String, String, String, Color)] = [("trophy.fill", "Wins", "\(t.wins)", TUI.green), ("xmark.circle.fill", "Losses", "\(t.losses)", TUI.red), ("scope", "Kills", "\(t.kills)", TUI.gold), ("shield.lefthalf.filled", "Rating", "\(t.rating)", TUI.blue)]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SF("chart.bar.fill").font(.system(size: 22, weight: .bold)).foregroundColor(lime)
                Text("Stats").font(.jk(28, .heavy))
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 12) {
                    SF(r.0, "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(r.3).frame(width: 28)
                    Text(r.1).font(.jk(16, .bold))
                    Spacer()
                    Text(r.2).font(.jk(18, .heavy))
                }
                .padding(14).background(T.card).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            Button {
                var s2 = game.s
                s2.ex.tac = nil
                game.s = s2
            } label: {
                HStack(spacing: 8) {
                    SF("arrow.counterclockwise").font(.system(size: 14, weight: .bold))
                    Text("Reset stats").font(.jk(15, .bold))
                }
                .foregroundColor(.red).frame(maxWidth: .infinity).frame(height: 48).background(Color.red.opacity(0.15)).clipShape(Capsule())
            }
            Spacer()
        }
        .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity).background(T.bg.ignoresSafeArea())
    }
}
