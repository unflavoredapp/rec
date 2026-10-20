import SwiftUI
import UIKit

/// The Special Task Force operator. Blender builds it as two parts so every piece can be swapped:
/// `stf_head.glb` (head, helmet, NVG, eyewear: shared by every pose) and `stf_<gun>.glb` (body + vest with the arms
/// posed on that gun's real grips). Textures are not baked in: `stf_body_<i>.jpg` (uniform camo), `stf_gear_<i>.jpg` (vest),
/// `stf_helm_<i>.jpg` (helmet), `stf_head_<i>.jpg` (face) are applied here, so face, uniform, vest, helmet and lenses change live.
/// `ophold_stf.json` says where each gun sits in the hands. Returns nil whenever a piece is missing so callers fall back
/// to the code-built soldier.
enum TacOperator {
    private static var imgs: [String: UIImage?] = [:]

    private static func url(_ n: String, _ e: String) -> URL? {
        Bundle.main.url(forResource: n, withExtension: e) ?? Bundle.main.url(forResource: n, withExtension: e, subdirectory: "models")
    }

    private static let hold: [String: [String: Any]] = {
        guard let u = url("ophold_stf", "json"), let d = try? Data(contentsOf: u),
              let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: [String: Any]] else { return [:] }
        return j
    }()

    /// a fresh copy per preview (materials are painted per operator, so nothing is shared between two screens)
    private static func fresh(_ name: String) -> MXNode? {
        guard let u = url(name, "glb") else { return nil }
        return MXGLTF.load(u)
    }

    private static func image(_ name: String) -> UIImage? {
        if let c = imgs[name] { return c }
        var im: UIImage? = nil
        if let u = url(name, "jpg") { im = UIImage(contentsOfFile: u.path) }
        imgs[name] = im
        return im
    }

    private static func walk(_ n: MXNode, _ f: (MXNode) -> Void) {
        f(n)
        for c in n.childNodes { walk(c, f) }
    }

    private static func paint(_ n: MXNode, _ contents: Any?) {
        for m in n.geometry?.materials ?? [] { m.diffuse.contents = contents }
    }

    static func node(style: TwStyle, gun: String) -> MXNode? {
        guard let k = TacGear.resolve(style.look),
              let hv = hold[gun], let al = hv["al"] as? Double, let phi = hv["phi"] as? Double,
              let p = hv["pos"] as? [Double], p.count == 3 else { return nil }
        guard let head = fresh("stf_head"), let body = fresh("stf_" + gun) else { return nil }

        // the gun (same loader + attachments + camo as the gunsmith preview)
        TwGunLib.setIdx = 2
        TwGunLib.load()
        guard let gg = TwGunLib.glbGun(gun, arms: false) else { TwGunLib.setIdx = 0; return nil }
        let gnode = MXNode()
        gnode.addChildNode(gg.node)
        let att = TAttBuild.build(gun, into: gnode, magHolder: nil)
        att.apply(gun)
        TAtt.applyCamo(gun, set: 2)
        TwGunLib.setIdx = 0
        let gh = MXNode()
        gh.addChildNode(gnode)
        gh.eulerAngles = MXVector3(Float(al), Float(phi), 0)
        gh.position = MXVector3(Float(p[0]), Float(p[1]), Float(p[2]))

        func tex(_ name: String, _ fallback: UIColor) -> Any {
            if let i = image(name) { return i }
            return fallback
        }
        let bodyTex = tex("stf_body_\(k.sBody)", TacGear.c(k.uni))
        let gearTex = tex("stf_gear_\(k.sGear)", TacGear.c(k.rigCol))
        let helmTex = tex("stf_helm_\(k.sHelmCol)", TacGear.c(k.rigCol))
        let faceTex = tex("stf_head_\(k.sFace)", style.skin)
        let lens = TacGear.c(TacGear.stfLens[max(0, min(TacGear.stfLens.count - 1, k.sLens))])

        func dress(_ root: MXNode) {
            walk(root) { n in
                guard let nm = n.name, nm.hasSuffix("_STF") else { return }
                switch String(nm.dropLast(4)) {
                case "body": paint(n, bodyTex)
                case "gear": paint(n, gearTex); n.isHidden = !k.sVest
                case "head": paint(n, faceTex)
                case "helm": paint(n, helmTex); n.isHidden = k.sHead == 0
                case "nvg": paint(n, helmTex); n.isHidden = k.sHead < 2
                case "glass":
                    n.isHidden = k.sLens == 0
                    for m in n.geometry?.materials ?? [] { m.diffuse.contents = lens; m.transparency = 0.84 }
                default: break
                }
            }
        }
        dress(head)
        dress(body)

        let op = MXNode()
        op.addChildNode(body)
        op.addChildNode(head)
        op.addChildNode(gh)
        let s: Float = 0.24                      // Blender centimetres -> preview units
        op.scale = MXVector3(s, s, s)
        op.eulerAngles = MXVector3(0, -Float.pi / 2, 0)   // modelled facing -z; the preview camera looks at +x
        let wrap = MXNode()
        wrap.addChildNode(op)
        return wrap
    }
}
