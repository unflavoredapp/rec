import SwiftUI
import UIKit

// 3D stage + thumbnail service for the avatar studio, rendered by the Metal engine.

enum AvatarShot: String {
    case full, head, hair, upper, legs, back

    /// camera target, distance, yaw (0 = facing the soldier's face), elevation
    var frame: (target: (Float, Float, Float), dist: Float, yaw: Float, el: Float) {
        switch self {
        case .full:  return ((0, 28, 0), 156, 0.5, 0.16)
        case .head:  return ((0.6, 48.8, 0), 52, 0.32, 0.05)
        case .hair:  return ((-0.5, 49.4, 0), 58, 0.95, 0.1)
        case .upper: return ((3, 36, 0), 98, 0.45, 0.1)
        case .legs:  return ((1, 12, 0), 84, 0.5, 0.08)
        case .back:  return ((-2, 34, 0), 108, 2.75, 0.1)
        }
    }
}

enum AvatarStageScene {
    struct Parts { let scene: MXScene; let cam: MXNode; let holder: MXNode }

    static let horizon = UIColor(red: 0.13, green: 0.16, blue: 0.27, alpha: 1)

    private static func gradient() -> UIImage {
        let top = UIColor(red: 0.03, green: 0.04, blue: 0.08, alpha: 1)
        let mid = UIColor(red: 0.08, green: 0.11, blue: 0.19, alpha: 1)
        return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 256)).image { c in
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top.cgColor, mid.cgColor, horizon.cgColor] as CFArray, locations: [0, 0.55, 1]) {
                c.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 256), options: [])
            }
        }
    }

    static func make(stage: Bool) -> Parts {
        let scene = MXScene()
        let root = scene.rootNode

        if stage {
            scene.background.contents = gradient()
            scene.fogColor = horizon
            scene.fogStartDistance = 200
            scene.fogEndDistance = 760
            scene.fogDensityExponent = 1.2
        }

        let amb = MXNode()
        amb.light = MXLight()
        amb.light?.type = .ambient
        amb.light?.intensity = stage ? 520 : 600
        amb.light?.color = UIColor(red: 0.74, green: 0.8, blue: 0.96, alpha: 1)
        root.addChildNode(amb)

        let key = MXNode()
        let kl = MXLight()
        kl.type = .directional
        kl.intensity = 1500
        kl.color = UIColor(red: 1, green: 0.95, blue: 0.86, alpha: 1)
        kl.castsShadow = stage
        kl.maximumShadowDistance = 420
        kl.shadowColor = UIColor(white: 0, alpha: 0.62)
        key.light = kl
        key.position = MXVector3(150, 210, 130)
        root.addChildNode(key)
        key.look(at: MXVector3(0, 0, 0))

        let rim = MXNode()
        let rl = MXLight()
        rl.type = .directional
        rl.intensity = stage ? 900 : 700
        rl.color = UIColor(red: 0.55, green: 0.7, blue: 1, alpha: 1)
        rim.light = rl
        rim.position = MXVector3(-170, 100, -150)
        root.addChildNode(rim)
        rim.look(at: MXVector3(0, 20, 0))

        if stage {
            let ground = MXCylinder(radius: 900, height: 1)
            ground.radialSegmentCount = 36
            let gm = MXMaterial()
            gm.diffuse.contents = UIColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1)
            gm.lightingModel = .lambert
            ground.materials = [gm]
            let gn = MXNode(geometry: ground)
            gn.position = MXVector3(0, -1.5, 0)
            gn.castsShadow = false
            root.addChildNode(gn)

            let ped = MXCylinder(radius: 46, height: 1.6)
            ped.radialSegmentCount = 48
            let pm = MXMaterial()
            pm.diffuse.contents = UIColor(red: 0.13, green: 0.15, blue: 0.2, alpha: 1)
            pm.specular.contents = UIColor(white: 0.5, alpha: 1)
            pm.shininess = 0.5
            ped.materials = [pm]
            let pn = MXNode(geometry: ped)
            pn.position = MXVector3(0, -0.8, 0)
            pn.castsShadow = false
            root.addChildNode(pn)

            let ring = MXTorus(ringRadius: 46, pipeRadius: 0.55)
            let rm = MXMaterial()
            rm.lightingModel = .constant
            rm.diffuse.contents = UIColor(red: 0.78, green: 0.96, blue: 0.28, alpha: 1)
            rm.emission.contents = UIColor(red: 0.78, green: 0.96, blue: 0.28, alpha: 1)
            ring.materials = [rm]
            let rn = MXNode(geometry: ring)
            rn.position = MXVector3(0, 0.1, 0)
            rn.castsShadow = false
            root.addChildNode(rn)
        }

        let camN = MXNode()
        let cam = MXCamera()
        cam.fieldOfView = stage ? 30 : 28
        cam.zNear = 5
        cam.zFar = 1800
        cam.wantsHDR = true
        cam.bloomIntensity = stage ? 0.35 : 0
        cam.bloomThreshold = 0.85
        cam.bloomBlurRadius = 6
        cam.vignettingIntensity = stage ? 0.35 : 0
        cam.vignettingPower = 1.3
        cam.saturation = 1.12
        cam.contrast = 0.12
        camN.camera = cam
        root.addChildNode(camN)

        let holder = MXNode()
        root.addChildNode(holder)
        return Parts(scene: scene, cam: camN, holder: holder)
    }

    static func place(_ cam: MXNode, shot: AvatarShot) {
        let f = shot.frame
        pose(cam, target: f.target, dist: f.dist, yaw: f.yaw, el: f.el)
    }

    static func pose(_ cam: MXNode, target t: (Float, Float, Float), dist: Float, yaw: Float, el: Float) {
        cam.position = MXVector3(t.0 + dist * cos(el) * cos(yaw), t.1 + dist * sin(el), t.2 + dist * cos(el) * sin(yaw))
        cam.look(at: MXVector3(t.0, t.1, t.2))
    }
}

// MARK: - live stage

final class AvatarStage {
    let parts = AvatarStageScene.make(stage: true)
    var shot: AvatarShot = .full
    var userYaw: Float = 0
    var zoom: Float = 1
    var lastTouch: Double = 0
    var lastSig = ""

    private var cur: [Float] = [0, 28, 0, 156, 0.5, 0.16]
    private var lastT: Double = 0
    private var idle: Float = 1

    func setStyle(_ style: TwStyle) {
        let sig = (try? JSONEncoder().encode(style.look)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        guard sig != lastSig else { return }
        lastSig = sig
        parts.holder.childNodes.forEach { $0.removeFromParentNode() }
        let sol = TwRig.soldier(team: UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1), style: style, rank: 0)
        for g in sol.variants { g.isHidden = true }
        let rifle = TwRig.gunIdx("rifle")
        if rifle < sol.variants.count { sol.variants[rifle].isHidden = false }
        parts.holder.addChildNode(sol.root)
    }

    func tick(_ t: Double) {
        let dt = Float(max(0, min(0.1, lastT == 0 ? 0.016 : t - lastT)))
        lastT = t
        let f = shot.frame
        let goal: [Float] = [f.target.0, f.target.1, f.target.2, f.dist, f.yaw, f.el]
        let k = 1 - exp(-dt * 6)
        for i in 0..<6 { cur[i] += (goal[i] - cur[i]) * k }
        let touching = t - lastTouch < 2.2
        idle += ((touching ? 0 : 1) - idle) * (1 - exp(-dt * 2))
        let sway = sin(Float(t) * 0.6) * 0.32 * idle
        AvatarStageScene.pose(parts.cam, target: (cur[0], cur[1], cur[2]), dist: cur[3] * zoom, yaw: cur[4] + userYaw + sway, el: cur[5])
    }
}

struct AvatarStageView: UIViewRepresentable {
    let style: TwStyle
    var shot: AvatarShot

    final class Coord: NSObject {
        let stage = AvatarStage()
        var pinchBase: Float = 1

        @objc func pan(_ g: UIPanGestureRecognizer) {
            let d = g.translation(in: g.view)
            g.setTranslation(.zero, in: g.view)
            stage.userYaw += Float(d.x) * 0.012
            stage.lastTouch = CACurrentMediaTime()
        }
        @objc func pinch(_ g: UIPinchGestureRecognizer) {
            if g.state == .began { pinchBase = stage.zoom }
            stage.zoom = max(0.55, min(1.4, pinchBase / Float(g.scale)))
            stage.lastTouch = CACurrentMediaTime()
        }
        @objc func reset(_ g: UITapGestureRecognizer) {
            stage.userYaw = 0
            stage.zoom = 1
        }
    }

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> MXView {
        let c = context.coordinator
        let v = MXView()
        v.backgroundColor = .black
        v.antialiasingMode = .multisampling4X
        v.scene = c.stage.parts.scene
        v.pointOfView = c.stage.parts.cam
        v.preRender = { [weak c] t in c?.stage.tick(t) }
        v.addGestureRecognizer(UIPanGestureRecognizer(target: c, action: #selector(Coord.pan(_:))))
        v.addGestureRecognizer(UIPinchGestureRecognizer(target: c, action: #selector(Coord.pinch(_:))))
        let tap = UITapGestureRecognizer(target: c, action: #selector(Coord.reset(_:)))
        tap.numberOfTapsRequired = 2
        v.addGestureRecognizer(tap)
        c.stage.setStyle(style)
        c.stage.shot = shot
        return v
    }

    func updateUIView(_ v: MXView, context: Context) {
        context.coordinator.stage.shot = shot
        context.coordinator.stage.setStyle(style)
    }
}

// MARK: - 3D thumbnails

@MainActor
final class AvatarThumbs {
    static let shared = AvatarThumbs()

    private let off = MXOffscreen()
    private let parts = AvatarStageScene.make(stage: false)
    private var cache: [String: UIImage] = [:]
    private let px = 224

    func image(key: String, look: AvatarLook, shot: AvatarShot) async -> UIImage? {
        let sig = (try? JSONEncoder().encode(look)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let ck = key + "|" + shot.rawValue + "|" + sig
        if let c = cache[ck] { return c }
        // let the UI draw between renders so a screen of tiles never freezes the studio
        await Task.yield()
        if Task.isCancelled { return nil }
        if let c = cache[ck] { return c }

        let style = TacAvatar.style(key, look)
        let wantGun = shot == .full || shot == .upper
        let sol = TwRig.soldier(team: UIColor(red: 0.3, green: 0.9, blue: 0.45, alpha: 1), style: style, rank: 0,
                                onlyGun: wantGun ? "rifle" : "", asyncFace: false)
        sol.faceMat.diffuse.contents = TacFace.cached(style)
        let rifle = TwRig.gunIdx("rifle")
        for (i, g) in sol.variants.enumerated() { g.isHidden = !(wantGun && i == rifle) }

        parts.holder.childNodes.forEach { $0.removeFromParentNode() }
        parts.holder.addChildNode(sol.root)
        AvatarStageScene.place(parts.cam, shot: shot)
        guard let img = off.image(scene: parts.scene, camNode: parts.cam, size: px, samples: 4) else { return nil }
        if cache.count > 360 { cache.removeAll() }
        cache[ck] = img
        return img
    }
}

struct AvatarThumb: View {
    let key: String
    let look: AvatarLook
    var shot: AvatarShot = .head
    @State private var img: UIImage?

    private var sig: String {
        ((try? JSONEncoder().encode(look)).flatMap { String(data: $0, encoding: .utf8) } ?? "") + shot.rawValue
    }

    var body: some View {
        ZStack {
            if let img = img {
                Image(uiImage: img).resizable().scaledToFit().transition(.opacity)
            } else {
                ProgressView().tint(Color.white.opacity(0.35))
            }
        }
        .task(id: sig) {
            let r = await AvatarThumbs.shared.image(key: key, look: look, shot: shot)
            if let r = r { withAnimation(.easeOut(duration: 0.15)) { img = r } }
        }
    }
}
