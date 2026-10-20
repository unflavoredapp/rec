import SwiftUI
import UIKit

/// Critical-Strike-style building blocks: flat dark panels, bold blue/orange buttons, top-left vitals, score bar.
enum CS {
    static let blue = Color(red: 0.2, green: 0.23, blue: 0.27)
    static let blueDark = Color(red: 0.1, green: 0.115, blue: 0.14)
    static let orange = Color(red: 0.93, green: 0.5, blue: 0.1)
    static let orangeDark = Color(red: 0.78, green: 0.38, blue: 0.05)
    static let panel = Color(red: 0.04, green: 0.05, blue: 0.07)
    static let cash = Color(red: 0.42, green: 0.9, blue: 0.62)
    static let gold = Color(red: 0.9, green: 0.72, blue: 0.3)
    static let modeCols: [Color] = [
        Color(red: 0.95, green: 0.7, blue: 0.1), Color(red: 0.2, green: 0.5, blue: 1), Color(red: 0.7, green: 0.3, blue: 1),
        Color(red: 0.2, green: 0.85, blue: 0.4), Color(red: 1, green: 0.25, blue: 0.25), Color(red: 0.2, green: 0.85, blue: 0.9), Color(red: 0.55, green: 0.9, blue: 0.2), Color(red: 0.25, green: 0.6, blue: 1)
    ]
    static let modeIcons = ["timer", "person.2.fill", "tag.fill", "arrow.up.forward.circle.fill", "person.3.fill", "flag.fill", "scope", "shield.lefthalf.filled"]
    static let modeInfo = ["Plant or defuse the bomb.", "Team to 30 kills wins.", "Collect dog tags.", "Every kill upgrades your gun.", "Everyone for themselves.", "Hold zones A, B and C.", "Loot, fight AI, extract alive.", "Capture A-E. Drain tickets."]
    static let modeReward = [(16, 24), (10, 14), (16, 20), (17, 20), (10, 14), (16, 20), (30, 40), (24, 30)]
}

/// flat parallelogram-free button: gradient fill, white hairline, heavy caps
struct CSButton: View {
    let title: String
    var col: Color = CS.blue
    var dark: Color = CS.blueDark
    var w: CGFloat = 150
    var h: CGFloat = 46
    var size: CGFloat = 22
    var dot = false
    let act: () -> Void

    var body: some View {
        let primary = col == CS.orange
        return Button(action: act) {
            Text(title).font(.jk(size, .heavy)).foregroundColor(primary ? .black : .white)
                .frame(width: w, height: h)
                .background(LinearGradient(colors: primary ? [col, dark] : [col, dark], startPoint: .top, endPoint: .bottom))
                .overlay(Rectangle().stroke(primary ? Color.white.opacity(0.25) : Color.white.opacity(0.22), lineWidth: 1))
                .overlay(alignment: .leading) { Rectangle().fill(primary ? Color.black.opacity(0.35) : CS.orange).frame(width: 3) }
                .overlay(alignment: .topTrailing) {
                    if dot { Text("!").font(.jk(11, .heavy)).foregroundColor(.white).frame(width: 16, height: 16).background(Rectangle().fill(Color.red)).offset(x: 6, y: -6) }
                }
        }
        .buttonStyle(TuiPress())
    }
}

struct CSCurrency: View {
    let cash: Int
    let coins: Int

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                SF("banknote.fill", "dollarsign.circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(CS.cash)
                Text(cash.formatted()).font(.jk(19, .heavy)).foregroundColor(CS.cash).monospacedDigit()
            }
            HStack(spacing: 5) {
                SF("circle.hexagongrid.fill", "circle.fill").font(.system(size: 16, weight: .bold)).foregroundColor(CS.gold)
                Text("\(coins)").font(.jk(19, .heavy)).foregroundColor(CS.gold).monospacedDigit()
                Text("+").font(.jk(16, .heavy)).foregroundColor(CS.gold).frame(width: 22, height: 22).overlay(Rectangle().stroke(CS.gold, lineWidth: 2))
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
    }
}

struct CSBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.1, blue: 0.11), Color(red: 0.03, green: 0.035, blue: 0.04)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color(red: 0.25, green: 0.28, blue: 0.3).opacity(0.4), .clear], center: .center, startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct CSHeader: View {
    let title: String
    let cash: Int
    let coins: Int
    let back: () -> Void

    var body: some View {
        HStack {
            Button(action: back) {
                SF("chevron.backward.2", "chevron.left").font(.system(size: 26, weight: .black)).foregroundColor(.white).frame(width: 52, height: 44)
            }
            .buttonStyle(TuiPress())
            Text(title).font(.jk(26, .heavy)).foregroundColor(.white)
            Spacer()
            CSCurrency(cash: cash, coins: coins)
        }
    }
}

// MARK: in-match HUD pieces

struct HudCSVitals: View {
    let e: TacticalEngine

    private func cell(_ icon: String, _ v: Int, _ f: CGFloat, _ col: Color) -> some View {
        HStack(spacing: 6) {
            SF(icon, "circle.fill").font(.system(size: 17, weight: .black)).foregroundColor(.white.opacity(0.85))
            Text("\(v)").font(.system(size: 26, weight: .heavy, design: .monospaced)).foregroundColor(col).monospacedDigit()
            Rectangle().fill(Color.white.opacity(0.22)).frame(width: 44, height: 4)
                .overlay(alignment: .leading) { Rectangle().fill(Color.white).frame(width: 44 * max(0, min(1, f)), height: 4) }
        }
    }

    var body: some View {
        let me = e.me
        let hp = Int(max(0, me.hp)), ar = Int(max(0, me.armor))
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 14) {
                cell("cross.fill", hp, me.hp / 100, me.hp < 35 ? TUI.red : .white)
                cell("shield.fill", ar, me.armor / 100, .white)
            }
            Text("KILLS \(me.kills)").font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundColor(.white.opacity(0.9))
            if e.gameMode == 0 {
                Text("$\(me.money)").font(.system(size: 14, weight: .heavy, design: .monospaced)).foregroundColor(TUI.green)
            }
        }
        .shadow(color: .black.opacity(0.75), radius: 3, y: 1)
    }
}

struct HudCSScore: View {
    let e: TacticalEngine

    private func badge(_ col: Color, _ icon: String) -> some View {
        Circle().fill(Color.black.opacity(0.35)).frame(width: 34, height: 34)
            .overlay(Circle().stroke(col, lineWidth: 2))
            .overlay(SF(icon, "circle.fill").font(.system(size: 15, weight: .black)).foregroundColor(col))
    }

    private func num(_ v: Int, _ col: Color) -> some View {
        Text("\(v)").font(.system(size: 22, weight: .heavy, design: .monospaced)).foregroundColor(col).monospacedDigit().frame(minWidth: 26)
    }

    var body: some View {
        let t = Int(max(0, e.timer))
        let sub: String = e.gameMode == 0 ? "ROUND \(e.round + 1)" : ((e.gameMode == 1 || e.gameMode == 2) ? "\(max(0, e.killTarget - max(e.scores[0], e.rivalScore))) KILLS LEFT" : e.objectiveText.uppercased())
        return VStack(spacing: 2) {
            HStack(spacing: 8) {
                num(e.scores[0], TUI.blue)
                badge(TUI.blue, "shield.lefthalf.filled")
                Text(THud.clock(t))
                    .font(.system(size: 26, weight: .heavy, design: .monospaced)).foregroundColor(e.planted ? TUI.red : .white).monospacedDigit()
                    .frame(minWidth: 70)
                badge(CS.orange, "star.fill")
                num(e.rivalScore, CS.orange)
            }
            .padding(.horizontal, 16).padding(.vertical, 3)
            .background(LinearGradient(colors: [Color.clear, Color(red: 0.1, green: 0.3, blue: 0.7).opacity(0.55), Color.clear], startPoint: .leading, endPoint: .trailing))
            Text(sub).font(.jk(13, .heavy)).foregroundColor(.white)
                .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
        }
    }
}

struct HudCSWeapon: View {
    let e: TacticalEngine

    var body: some View {
        let me = e.me
        let g = TGuns.get(me.gun)
        let pistol = TWeapons.isPistol(me.gun)
        return VStack(alignment: .trailing, spacing: 2) {
            if me.knife {
                HudKnifeShape().fill(Color.white).frame(width: 56, height: 36)
            } else {
                Image(uiImage: GunSprites.icon(TWeapons.rig(me.gun))).renderingMode(.template).resizable().scaledToFit()
                    .foregroundColor(.white).frame(width: 112, height: 38)
                if me.reloadT > 0 {
                    Text("RELOADING").font(.jk(15, .heavy)).foregroundColor(TUI.gold)
                } else {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(me.mag)").font(.system(size: 28, weight: .heavy, design: .monospaced)).foregroundColor(me.mag == 0 ? TUI.red : .white).monospacedDigit()
                        if !pistol { Text("/ \(me.spare * g.mag)").font(.jk(14, .bold)).foregroundColor(.white.opacity(0.8)) }
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.75), radius: 3, y: 1)
    }
}
