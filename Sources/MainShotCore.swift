import SwiftUI
import UIKit
import CoreText

// MARK: - App shell

enum OrientationLock {
    static var mask: UIInterfaceOrientationMask = .landscape

    static func set(landscape: Bool) {
        mask = landscape ? .landscape : .portrait
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: landscape ? .landscape : .portrait)) { _ in }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationLock.mask
    }
}

@main
struct MainShotApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var game = Game()
    @StateObject private var nav = Nav()

    init() {
        for sub in [nil, "Fonts"] as [String?] {
            for u in Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: sub) ?? [] {
                CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            LobbyView()
                .overlay(BodycamMenuLayer())
                .environmentObject(game)
                .environmentObject(nav)
                .preferredColorScheme(.dark)
                .dynamicTypeSize(.large)
        }
    }
}

// MARK: - Navigation + persisted state

final class Nav: ObservableObject {
    @Published var tacPlay: Int? = nil
    @Published var tacMode = 0
    @Published var tacGun = "rifle"
    @Published var tacMap = 0
}

struct Extras: Codable, Hashable {
    var tac: TacData? = nil
    var gems = 50
}

struct GameState: Codable, Hashable {
    var ex = Extras()
}

final class Game: ObservableObject {
    @Published var s: GameState {
        didSet {
            if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: "mainshot.state") }
        }
    }

    init() {
        if let d = UserDefaults.standard.data(forKey: "mainshot.state"), let v = try? JSONDecoder().decode(GameState.self, from: d) {
            s = v
        } else {
            s = GameState()
        }
    }
}

// MARK: - Bots

enum BotNames {
    static let first = ["Cleo", "Yuki", "Elena", "Marcus", "Ravi", "Sasha", "Diego", "Mina", "Jonas", "Amara", "Kenji", "Nadia", "Tobias", "Lena", "Omar", "Priya", "Viktor", "Zoe", "Hugo", "Ines", "Felix", "Talia", "Anders", "Rosa", "Kofi", "Mei", "Luca", "Ada", "Bram", "Noor"]
    static let last = ["Vance", "Lindqvist", "Sokolov", "Okafor", "Moreau", "Tanaka", "Reyes", "Novak", "Haddad", "Bianchi", "Kowalski", "Mbeki", "Larsen", "Costa", "Ivanov", "Park", "Silva", "Duarte", "Frost", "Ng"]

    static func pick(_ n: Int) -> [(String, String, String)] {
        var out: [(String, String, String)] = []
        var used = Set<String>()
        while out.count < n {
            let f = first.randomElement()!, l = last.randomElement()!
            let name = f + " " + l
            if used.insert(name).inserted { out.append((name, (f + l).lowercased(), "")) }
        }
        return out
    }
}

// MARK: - Shared helpers

struct GunDef {
    let id: String
    let name: String
    let emoji: String
    let dmg: CGFloat
    let rate: CGFloat
    let mag: Int
    let reload: CGFloat
    let spread: CGFloat
    let pellets: Int
    let speed: CGFloat
    let range: CGFloat
    let price: Int
}

func brRayThrough(_ o: CGPoint, _ dx: CGFloat, _ dy: CGFloat, _ r: CGRect) -> (CGFloat, CGFloat)? {
    var tmin: CGFloat = 0
    var tmax: CGFloat = 100000
    if abs(dx) < 1e-9 {
        if o.x < r.minX || o.x > r.maxX { return nil }
    } else {
        let t1 = (r.minX - o.x) / dx
        let t2 = (r.maxX - o.x) / dx
        tmin = max(tmin, min(t1, t2))
        tmax = min(tmax, max(t1, t2))
    }
    if abs(dy) < 1e-9 {
        if o.y < r.minY || o.y > r.maxY { return nil }
    } else {
        let t1 = (r.minY - o.y) / dy
        let t2 = (r.maxY - o.y) / dy
        tmin = max(tmin, min(t1, t2))
        tmax = min(tmax, max(t1, t2))
    }
    if tmin > tmax { return nil }
    return (tmin, tmax)
}

extension Font {
    /// Tactical UI face: Avenir Next Condensed (ships with iOS) - tight, military, all-caps friendly.
    static func jk(_ size: CGFloat, _ w: Font.Weight = .regular) -> Font {
        let n: String
        switch w {
        case .medium: n = "AvenirNextCondensed-Medium"
        case .semibold: n = "AvenirNextCondensed-DemiBold"
        case .bold: n = "AvenirNextCondensed-Bold"
        case .heavy, .black: n = "AvenirNextCondensed-Heavy"
        default: n = "AvenirNextCondensed-Regular"
        }
        return .custom(n, size: size * 1.08)
    }
}

enum T {
    static let bg = Color(red: 0.10, green: 0.10, blue: 0.11)
    static let card = Color(red: 0.15, green: 0.15, blue: 0.17)
    static let sub = Color.white.opacity(0.6)
    static let blue = Color(red: 0.27, green: 0.60, blue: 0.93)
    static let card2 = Color(red: 0.20, green: 0.20, blue: 0.22)
}

enum GunSprites {
    static func icon(_ id: String) -> UIImage { UIImage(named: "gunicon_" + id) ?? UIImage() }
}
