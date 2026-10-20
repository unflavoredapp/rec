import SwiftUI
import UIKit

/// In-match HUD building blocks (landscape). All of them read straight from the engine and are redrawn at 10 Hz by the HUD timeline.
enum THud {
    static var floorTag: [String] { [["B", "G", "A"], ["U", "W", "T"], ["T", "Y", "C"], ["C", "O", "R"]][TMap.look] }
    static var floorCol: [Color] { TMap.look == 0 ? [TUI.red, TUI.blue, TUI.orange] : [TUI.red, TUI.green, TUI.orange] }
    static var floorShort: [String] { [["BASEMENT", "GROUND", "ATTIC"], ["BUNKER", "WOODS", "TOWER"], ["TUNNEL", "YARD", "CATWALK"], ["CELLAR", "OUTPOST", "ROOFTOP"]][TMap.look] }

    static func clock(_ t: Int) -> String { String(format: "%d:%02d", t / 60, t % 60) }
}

// MARK: roster

struct HudDot: View {
    let p: TPlayer?
    let ally: Bool
    let meID: Int

    var body: some View {
        let alive = p?.alive ?? false
        let isMe = p?.id == meID
        let col: Color = ally ? (isMe ? TUI.green : TUI.blue) : TUI.orange
        let frac: CGFloat = p == nil ? 0 : (ally ? max(0, min(1, p!.hp / 100)) : (alive ? 1 : 0))
        let ringCol: Color = ally && frac < 0.35 ? TUI.red : col
        let showFloor: Bool = alive && p != nil && (ally || (p?.spotted ?? false))
        return ZStack {
            Circle().stroke(Color.white.opacity(0.14), lineWidth: 2.5)
            Circle().trim(from: 0, to: frac).stroke(ringCol.opacity(alive ? 1 : 0.4), style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
            if let p = p {
                PortraitAvatar(key: p.handle, size: 26, look: TacAvatar.look(for: p.handle))
                    .drawingGroup()
                    .saturation(alive ? 1 : 0)
                    .opacity(alive ? 1 : 0.45)
                    .clipShape(Circle())
                if !alive { SF("xmark").font(.system(size: 12, weight: .black)).foregroundColor(.white) }
            }
        }
        .frame(width: 32, height: 32)
        .overlay(alignment: .bottomTrailing) {
            if showFloor, let p = p {
                let f = TMap.floorOf(p.pos)
                Text(THud.floorTag[f]).font(.system(size: 7, weight: .black, design: .monospaced)).foregroundColor(.black)
                    .frame(width: 11, height: 11).background(Circle().fill(THud.floorCol[f]))
                    .offset(x: 2, y: 2)
            }
        }
    }
}

struct HudRoster: View {
    let list: [TPlayer]
    let ally: Bool
    let meID: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { i in HudDot(p: i < list.count ? list[i] : nil, ally: ally, meID: meID) }
        }
    }
}

// MARK: scoreboard

struct HudScore: View {
    let v: Int
    let col: Color
    var body: some View {
        Text("\(v)").font(.system(size: 18, weight: .heavy, design: .monospaced)).foregroundColor(.white).monospacedDigit()
            .frame(width: 32, height: 28)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(col.opacity(0.32)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(col, lineWidth: 1.5))
    }
}

struct HudScoreboard: View {
    let e: TacticalEngine

    var body: some View {
        let allies = e.players.filter { $0.team == e.me.team }
        let foes = e.players.filter { $0.team != e.me.team }
        let t = Int(max(0, e.timer))
        let focus: TPlayer = e.me.alive ? e.me : (allies.first { $0.alive } ?? e.me)
        return VStack(spacing: 4) {
            if e.gameMode == 6 { HudRaidBar(e: e) } else if e.gameMode == 7 { HudFrontline(e: e) } else {
            HudCSScore(e: e)
            }
            if e.gameMode != 6 && e.gameMode != 0 && e.gameMode != 1 && e.gameMode != 2 && false {
            HStack(spacing: 6) {
                Text(TWeapons.modeNames[min(e.gameMode, TWeapons.modeNames.count - 1)].uppercased()).font(.jk(9, .heavy)).tracking(1).foregroundColor(TUI.blue)
                Text("|").font(.jk(10, .regular)).foregroundColor(.white.opacity(0.35))
                Text(e.objectiveText).font(.jk(11, .semibold)).foregroundColor(.white.opacity(0.95))
            }
            .padding(.horizontal, 12).frame(height: 22).background(Capsule().fill(Color.black.opacity(0.16)))
            }
            if e.planted { bombChip(focus) }
            if e.gameMode == 5 {
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        let pr = e.cpProg[i]
                        Text(["A", "B", "C"][i]).font(.jk(12, .heavy)).foregroundColor(.white).frame(width: 30, height: 24)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(pr == 0 ? Color.gray.opacity(0.55) : (pr > 0 ? TUI.blue.opacity(0.35 + 0.65 * Double(pr)) : TUI.orange.opacity(0.35 + 0.65 * Double(-pr)))))
                    }
                }
            }
            if e.bannerT > 0 {
                Text(e.banner).font(.system(size: 32, weight: .heavy, design: .monospaced)).tracking(1).foregroundColor(.white).multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.6), radius: 6)
                    .padding(.horizontal, 30).padding(.vertical, 4)
                    .padding(.top, 10).opacity(Double(min(1, e.bannerT)))
            }
            if e.plantProg > 0 || e.defuseProg > 0 {
                let pr = e.plantProg > 0 ? e.plantProg / 3 : e.defuseProg / 4
                VStack(spacing: 4) {
                    HStack(spacing: 5) {
                        SF(e.plantProg > 0 ? "timer" : "wrench.and.screwdriver.fill", "circle.fill").font(.system(size: 11, weight: .bold))
                        Text(e.plantProg > 0 ? "PLANTING" : "DEFUSING").font(.jk(11, .heavy)).tracking(1)
                    }
                    .foregroundColor(.white)
                    Capsule().fill(Color.white.opacity(0.22)).frame(width: 170, height: 8)
                        .overlay(alignment: .leading) { Capsule().fill(TUI.gold).frame(width: 170 * min(1, pr), height: 8) }
                }
                .padding(.top, 18)
            }
        }
    }

    private var brBar: some View {
        let cd = Int(max(0, e.stormCountdown))
        let purple = Color(red: 0.78, green: 0.5, blue: 1)
        return HStack(spacing: 14) {
            HStack(spacing: 5) {
                SF("person.3.fill").font(.system(size: 13, weight: .bold))
                Text("\(e.brAlive)").font(.system(size: 20, weight: .heavy, design: .monospaced)).monospacedDigit()
                Text("ALIVE").font(.jk(8, .heavy)).tracking(1).opacity(0.7)
            }
            Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 22)
            VStack(spacing: 1) {
                HStack(spacing: 4) {
                    SF("tornado", "circle.fill").font(.system(size: 10, weight: .bold)).foregroundColor(purple)
                    Text(e.stormShrinking ? "ZONE CLOSING" : "NEXT ZONE").font(.jk(8, .heavy)).tracking(1).foregroundColor(purple)
                }
                Text(THud.clock(cd)).font(.system(size: 17, weight: .heavy, design: .monospaced))
            }
            .frame(minWidth: 92)
            Rectangle().fill(Color.white.opacity(0.2)).frame(width: 1, height: 22)
            HStack(spacing: 5) {
                SF("scope", "circle.fill").font(.system(size: 13, weight: .bold)).foregroundColor(TUI.gold)
                Text("\(e.me.kills)").font(.system(size: 20, weight: .heavy, design: .monospaced)).monospacedDigit()
                Text("KILLS").font(.jk(8, .heavy)).tracking(1).opacity(0.7)
            }
        }
        .foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).hudFloat(18)
    }

    /// where the bomb is, in terms the player can act on: which floor, and which way to go
    private func bombChip(_ focus: TPlayer) -> some View {
        let bf = TMap.floorOf(e.bombPos), mf = TMap.floorOf(focus.pos)
        let dir = bf == mf ? "" : (bf > mf ? "  ▲ UPSTAIRS" : "  ▼ DOWNSTAIRS")
        return HStack(spacing: 6) {
            Circle().fill(TUI.red).frame(width: 7, height: 7)
            Text("BOMB · \(THud.floorShort[bf])\(dir)").font(.jk(10, .heavy)).tracking(1).foregroundColor(.white)
        }
        .padding(.horizontal, 12).frame(height: 22).background(Capsule().fill(TUI.red.opacity(0.35)))
        .overlay(Capsule().stroke(TUI.red.opacity(0.8), lineWidth: 1))
    }
}

// MARK: floor + room

struct HudFloorStack: View {
    let floor: Int
    var body: some View {
        VStack(spacing: 3) {
            ForEach([2, 1, 0], id: \.self) { f in
                let on = f == floor
                Text(THud.floorShort[f]).font(.jk(8, .heavy)).tracking(0.5)
                    .foregroundColor(on ? .black : .white.opacity(0.5))
                    .frame(width: on ? 62 : 54, height: 17)
                    .background(Capsule().fill(on ? THud.floorCol[f] : Color.black.opacity(0.15)))
                    .overlay(Capsule().stroke(Color.white.opacity(on ? 0.7 : 0.15), lineWidth: 1))
            }
        }
        .animation(.easeOut(duration: 0.18), value: floor)
    }
}

struct HudRoomChip: View {
    let floor: Int
    let room: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(THud.floorCol[floor]).frame(width: 6, height: 6)
            Text("\(THud.floorShort[floor]) · \(room)".uppercased()).font(.jk(10, .heavy)).tracking(1).foregroundColor(.white.opacity(0.95))
        }
        .padding(.horizontal, 10).frame(height: 20).background(Capsule().fill(Color.black.opacity(0.2)))
    }
}

// MARK: kill feed

struct HudFeed: View {
    let e: TacticalEngine
    var body: some View {
        let items = Array(e.feed.filter { $0.life > 0 }.suffix(3))
        return VStack(alignment: .trailing, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, f in
                HStack(spacing: 8) {
                    Text(f.k.split(separator: " ").first.map(String.init) ?? f.k).font(.jk(12, .bold)).foregroundColor(f.kTeam == e.me.team ? TUI.blue : TUI.orange)
                    if f.gun == "knife" {
                        HudKnifeShape().fill(Color.white).frame(width: 20, height: 16)
                    } else {
                        Image(uiImage: GunSprites.icon(TWeapons.rig(f.gun))).renderingMode(.template).resizable().scaledToFit()
                            .foregroundColor(.white).frame(width: 36, height: 14)
                    }
                    if f.head { SF("scope", "circle.fill").font(.system(size: 11, weight: .black)).foregroundColor(TUI.red) }
                    Text(f.v.split(separator: " ").first.map(String.init) ?? f.v).font(.jk(12, .bold)).foregroundColor(f.kTeam == e.me.team ? TUI.orange : TUI.blue)
                }
                .padding(.horizontal, 10).frame(height: 24).hudFloat(12)
                .opacity(i == items.count - 1 ? 1 : 0.55)
            }
        }
    }
}

// MARK: damage / low health

struct HudVignette: View {
    let e: TacticalEngine
    var body: some View {
        let low = e.me.alive && e.me.hp < 35
        let k = min(1, max(0, e.me.hurt * 4)) * 0.55 + (low ? 0.25 : 0)
        return Rectangle()
            .fill(RadialGradient(colors: [.clear, TUI.red.opacity(k)], center: .center, startRadius: 160, endRadius: 520))
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

// MARK: dock (vitals + weapons + grenades)

struct HudKnifeShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + r.width * x, y: r.minY + r.height * y) }
        p.move(to: pt(0.34, 0.58)); p.addLine(to: pt(0.92, 0.08)); p.addLine(to: pt(0.66, 0.66)); p.closeSubpath()
        p.move(to: pt(0.1, 0.88)); p.addLine(to: pt(0.2, 0.97)); p.addLine(to: pt(0.46, 0.68)); p.addLine(to: pt(0.34, 0.58)); p.closeSubpath()
        return p
    }
}

struct HudDock: View {
    let e: TacticalEngine

    private func cell<C: View>(_ w: CGFloat, on: Bool, _ act: (() -> Void)? = nil, @ViewBuilder _ c: () -> C) -> some View {
        ZStack { c() }
            .frame(width: w, height: 52)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? TUI.accent.opacity(0.2) : Color.black.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(on ? TUI.accent : Color.white.opacity(0.2), lineWidth: on ? 1.6 : 1))
            .contentShape(Rectangle())
            .onTapGesture { act?() }
    }

    private func ammo(_ mag: Int, _ spare: Int, pistol: Bool, reloading: Bool, big: Bool) -> some View {
        Group {
            if reloading {
                Text("RELOAD").font(.jk(big ? 11 : 9, .heavy)).foregroundColor(TUI.gold)
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(mag)").font(.system(size: big ? 19 : 12, weight: .heavy, design: .monospaced)).foregroundColor(mag == 0 ? TUI.red : .white).monospacedDigit()
                    if !pistol { Text("/\(spare)").font(.jk(big ? 10 : 8, .bold)).foregroundColor(.white.opacity(0.6)) }
                }
            }
        }
    }

    private func gun(_ id: String, mag: Int, spare: Int, reloading: Bool, on: Bool, w: CGFloat, _ act: (() -> Void)?) -> some View {
        let g = TGuns.get(id)
        return cell(w, on: on, act) {
            VStack(spacing: 2) {
                Image(uiImage: GunSprites.icon(TWeapons.rig(id))).renderingMode(.template).resizable().scaledToFit()
                    .foregroundColor(on ? .white : .white.opacity(0.55)).frame(width: w - 16, height: on ? 22 : 17)
                ammo(mag, spare * g.mag, pistol: TWeapons.isPistol(id), reloading: reloading, big: on)
            }
        }
    }

    private func nade(_ icon: String, _ n: Int, _ act: @escaping () -> Void) -> some View {
        cell(34, on: false, act) {
            ZStack(alignment: .bottomTrailing) {
                SF(icon, "circle.fill").font(.system(size: 17, weight: .bold)).foregroundColor(.white.opacity(n == 0 ? 0.28 : 0.95)).frame(width: 34, height: 52)
                Text("\(n)").font(.jk(10, .heavy)).foregroundColor(.black).frame(minWidth: 15, minHeight: 15)
                    .background(Circle().fill(n == 0 ? Color.white.opacity(0.4) : TUI.accent)).padding(2)
            }
        }
    }

    var body: some View {
        let me = e.me
        let hpFrac = max(0, min(1, me.hp / 100))
        return VStack(spacing: 6) {
            HStack(spacing: 4) {
                cell(36, on: me.knife, { e.wantKnife = true }) { HudKnifeShape().fill(me.knife ? Color.white : Color.white.opacity(0.7)).frame(width: 24, height: 24) }
                gun(me.gun, mag: me.mag, spare: me.spare, reloading: me.reloadT > 0, on: !me.knife, w: 84) { e.wantGun = true }
                gun(me.altGun, mag: me.altMag, spare: me.altSpare, reloading: false, on: false, w: 56) { e.wantSwap = true }
                nade("circle.hexagongrid.fill", me.nades) { e.wantNade = true }
                nade("smoke.fill", me.smokes) { e.wantSmoke = true }
                nade("sun.max.fill", me.flashes) { e.wantFlash = true }
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(width: 330)
        .hudFloat(18)
    }
}


extension View {
    /// transparent floating HUD card: faint tint + hairline, no blur, so the world shows through
    func hudFloat(_ r: CGFloat = 14) -> some View {
        self
            .background(RoundedRectangle(cornerRadius: r, style: .continuous).fill(Color.black.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: r, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
            .shadow(color: .black.opacity(0.55), radius: 5, y: 1)
    }
}


/// purple pulse while the player is standing in the storm
struct HudStormTint: View {
    let e: TacticalEngine
    var body: some View {
        let inStorm = e.me.alive && e.stormOutside(e.me.pos)
        return Rectangle()
            .fill(RadialGradient(colors: [Color.clear, Color(red: 0.55, green: 0.15, blue: 0.9).opacity(inStorm ? 0.55 : 0)], center: .center, startRadius: 120, endRadius: 520))
            .ignoresSafeArea().allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.4), value: inStorm)
    }
}
