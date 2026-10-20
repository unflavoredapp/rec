import SwiftUI

/// Bodycam conversion switches and shared overlay pieces.
enum TBody {
    static let on = true
    /// everything hurts more: two to three hits to go down, same for the bots
    static let dmgMul: CGFloat = 2.3
    static let hipSpread: CGFloat = 1.5
    static let fov: CGFloat = 76
    static let serial = "MS-CAM 4471-0092"

    static func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: d)
    }

    static func clock(_ s: Double) -> String {
        let t = Int(max(0, s))
        return String(format: "%02d:%02d:%02d", t / 3600, (t / 60) % 60, t % 60)
    }
}

/// animated film grain, drawn at ~12 fps so it costs next to nothing
struct BodycamGrain: View {
    var strength: Double = 0.07

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.08)) { tl in
            Canvas { ctx, sz in
                var s = UInt64(tl.date.timeIntervalSinceReferenceDate * 1000) & 0xFFFF
                func rnd() -> CGFloat { s = s &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((s >> 33) & 0xFFFF) / 65535 }
                let n = Int(sz.width * sz.height / 420)
                for _ in 0..<n {
                    let x = rnd() * sz.width, y = rnd() * sz.height
                    let l = rnd()
                    ctx.fill(Path(CGRect(x: x, y: y, width: 2, height: 2)), with: .color((l > 0.5 ? Color.white : Color.black).opacity(strength * Double(0.4 + rnd()))))
                }
                var y: CGFloat = 0
                while y < sz.height { ctx.fill(Path(CGRect(x: 0, y: y, width: sz.width, height: 1)), with: .color(Color.black.opacity(0.05))); y += 3 }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// REC dot, date stamp, camera serial and battery, bodycam style
struct BodycamStamp: View {
    var elapsed: Double? = nil
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { tl in
            let blink = Int(tl.date.timeIntervalSinceReferenceDate * 2) % 2 == 0
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Circle().fill(Color(red: 0.95, green: 0.12, blue: 0.1)).frame(width: compact ? 7 : 9, height: compact ? 7 : 9).opacity(blink ? 1 : 0.15)
                    Text("REC").font(.system(size: compact ? 10 : 12, weight: .heavy, design: .monospaced)).foregroundColor(.white)
                    if let e = elapsed {
                        Text(TBody.clock(e)).font(.system(size: compact ? 10 : 12, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.9))
                    }
                }
                Text(TBody.stamp(tl.date)).font(.system(size: compact ? 8 : 10, weight: .semibold, design: .monospaced)).foregroundColor(.white.opacity(0.85))
                if !compact {
                    Text(TBody.serial).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundColor(.white.opacity(0.55))
                }
            }
            .shadow(color: .black.opacity(0.8), radius: 2)
        }
        .allowsHitTesting(false)
    }
}

/// full-screen bodycam wash for the menus: grain, scanlines, corner stamp, vignette
struct BodycamMenuLayer: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            RadialGradient(colors: [.clear, Color.black.opacity(0.5)], center: .center, startRadius: 180, endRadius: 620).ignoresSafeArea().allowsHitTesting(false)
            BodycamGrain(strength: 0.05)
        }
        .allowsHitTesting(false)
    }
}

/// in-match readout: stamp top-left under the settings button, tiny vitals and ammo, nothing else
struct BodycamHud: View {
    let e: TacticalEngine

    var body: some View {
        let me = e.me
        let hp = Int(max(0, me.hp)), ar = Int(max(0, me.armor))
        return ZStack(alignment: .topLeading) {
            BodycamStamp(elapsed: Double(max(0, e.time)), compact: true)
                .padding(.leading, 14).padding(.top, 10)
            if me.alive {
                HStack(spacing: 10) {
                    Text("HP \(hp)").foregroundColor(hp < 35 ? Color(red: 1, green: 0.3, blue: 0.25) : .white)
                    Text("AR \(ar)").foregroundColor(.white.opacity(0.85))
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .shadow(color: .black.opacity(0.8), radius: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 16).padding(.bottom, 12)
            }
        }
        .allowsHitTesting(false)
    }
}


/// ammo line, bottom centre; tap swaps to the other weapon
struct BodycamAmmo: View {
    let e: TacticalEngine
    var body: some View {
        let me = e.me
        let g = TGuns.get(me.gun)
        let pistol = TWeapons.isPistol(me.gun)
        return Button { e.wantSwap = true } label: {
            HStack(spacing: 8) {
                Text(g.name.uppercased()).foregroundColor(.white.opacity(0.7))
                if me.reloadT > 0 {
                    Text("RELOADING").foregroundColor(Color(red: 1, green: 0.7, blue: 0.2))
                } else {
                    Text(pistol ? "\(me.mag)" : "\(me.mag) / \(me.spare * g.mag)").foregroundColor(me.mag == 0 ? Color(red: 1, green: 0.3, blue: 0.25) : .white)
                }
            }
            .font(.system(size: 13, weight: .bold, design: .monospaced))
            .shadow(color: .black.opacity(0.8), radius: 2)
            .padding(.horizontal, 12).padding(.vertical, 6)
        }
        .buttonStyle(TuiPress())
    }
}

/// shown while down: camera feed lost, auto redeploy, tap for loadout
struct BodycamDown: View {
    let e: TacticalEngine
    let loadout: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().allowsHitTesting(false)
            VStack(spacing: 6) {
                Text("SIGNAL LOST").font(.system(size: 20, weight: .heavy, design: .monospaced)).foregroundColor(Color(red: 0.95, green: 0.2, blue: 0.15))
                if e.me.respawn > 0 && e.me.respawn < 100 {
                    Text("REDEPLOY \(Int(ceil(e.me.respawn)))").font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundColor(.white.opacity(0.8))
                }
                Button(action: loadout) {
                    Text("LOADOUT").font(.system(size: 12, weight: .heavy, design: .monospaced)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 7).overlay(Rectangle().stroke(Color.white.opacity(0.6), lineWidth: 1))
                }
                .buttonStyle(TuiPress())
            }
        }
    }
}
