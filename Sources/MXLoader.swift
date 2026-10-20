import UIKit
import ModelIO
import MetalKit
import simd

/// Loads .glb / .gltf (own parser) and .usdz / .usd / .obj (ModelIO) into MXNode trees.
/// Drop files in Resources/models/ and call `MXModel.load("name")`.
enum MXModel {
    static func load(_ name: String) -> MXNode? {
        for ext in ["glb", "gltf", "usdz", "usd", "usdc", "obj"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "models")
                ?? Bundle.main.url(forResource: name, withExtension: ext) {
                return load(url: url)
            }
        }
        return nil
    }

    static func load(url: URL) -> MXNode? {
        switch url.pathExtension.lowercased() {
        case "glb", "gltf": return MXGLTF.load(url)
        default: return loadModelIO(url)
        }
    }

    // MARK: ModelIO (usdz / obj)

    private static func loadModelIO(_ url: URL) -> MXNode? {
        let asset = MDLAsset(url: url)
        asset.loadTextures()
        let root = MXNode()
        func walk(_ o: MDLObject, _ parent: MXNode) {
            let n = MXNode()
            n.name = o.name
            if let t = o.transform { n.setLocalTransform(t.matrix) }
            parent.addChildNode(n)
            if let mesh = o as? MDLMesh, let g = convert(mesh) { n.geometry = g }
            for c in o.children.objects { walk(c, n) }
        }
        for i in 0..<asset.count { walk(asset.object(at: i), root) }
        return root
    }

    private static func convert(_ mesh: MDLMesh) -> MXGeometry? {
        mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
        guard let posA = mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributePosition),
              let nrmA = mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributeNormal) else { return nil }
        let uvA = mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributeTextureCoordinate)
        let md = MXMeshData()
        for i in 0..<mesh.vertexCount {
            let p = posA.dataStart.advanced(by: i * posA.stride).assumingMemoryBound(to: Float.self)
            let n = nrmA.dataStart.advanced(by: i * nrmA.stride).assumingMemoryBound(to: Float.self)
            var u: Float = 0, v: Float = 0
            if let a = uvA {
                let t = a.dataStart.advanced(by: i * a.stride).assumingMemoryBound(to: Float.self)
                u = t[0]; v = 1 - t[1]
            }
            md.verts.append(MXVertex(px: p[0], py: p[1], pz: p[2], nx: n[0], ny: n[1], nz: n[2], u: u, v: v))
        }
        var mats: [MXMaterial] = []
        for sub in (mesh.submeshes as? [MDLSubmesh]) ?? [] {
            var idx: [UInt32] = []
            let buf = sub.indexBuffer.map()
            let cnt = sub.indexCount
            switch sub.indexType {
            case .uInt32: let p = buf.bytes.assumingMemoryBound(to: UInt32.self); for i in 0..<cnt { idx.append(p[i]) }
            case .uInt16: let p = buf.bytes.assumingMemoryBound(to: UInt16.self); for i in 0..<cnt { idx.append(UInt32(p[i])) }
            case .uInt8: let p = buf.bytes.assumingMemoryBound(to: UInt8.self); for i in 0..<cnt { idx.append(UInt32(p[i])) }
            default: break
            }
            if sub.geometryType != .triangles { continue }
            md.elems.append(idx)
            let m = MXMaterial()
            if let mm = sub.material {
                if let bc = mm.property(with: .baseColor) {
                    if bc.type == .float3 { m.diffuse.contents = UIColor(red: CGFloat(bc.float3Value.x), green: CGFloat(bc.float3Value.y), blue: CGFloat(bc.float3Value.z), alpha: 1) }
                    else if bc.type == .texture, let tex = bc.textureSamplerValue?.texture, let cg = tex.imageFromTexture()?.takeUnretainedValue() {
                        m.diffuse.contents = UIImage(cgImage: cg)
                    }
                }
            }
            mats.append(m)
        }
        if md.elems.isEmpty { return nil }
        let g = MXCustomGeometry(data: md)
        g.materials = mats
        return g
    }
}

// MARK: - glTF 2.0

enum MXGLTF {
    private struct Ctx {
        var json: [String: Any]
        var bin: Data
        var base: URL?
        var materials: [Int: MXMaterial] = [:]
        var images: [Int: UIImage] = [:]
    }

    static func load(_ url: URL) -> MXNode? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        var json: [String: Any]?
        var bin = Data()
        if data.count > 20, data.prefix(4) == Data("glTF".utf8) {
            var off = 12
            while off + 8 <= data.count {
                let len = Int(data.u32(off)), typ = data.u32(off + 4)
                let s = off + 8
                if s + len > data.count { break }
                let chunk = data.subdata(in: s..<s + len)
                if typ == 0x4E4F534A { json = (try? JSONSerialization.jsonObject(with: chunk)) as? [String: Any] }
                else if typ == 0x004E4942 { bin = chunk }
                off = s + ((len + 3) & ~3)
            }
        } else {
            json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        }
        guard let j = json else { return nil }
        var ctx = Ctx(json: j, bin: bin, base: url.deletingLastPathComponent())
        let nodes = j["nodes"] as? [[String: Any]] ?? []
        let sceneIdx = j["scene"] as? Int ?? 0
        let scenes = j["scenes"] as? [[String: Any]] ?? []
        var rootsIdx = (scenes.indices.contains(sceneIdx) ? scenes[sceneIdx]["nodes"] as? [Int] : nil) ?? []
        if rootsIdx.isEmpty { rootsIdx = Array(nodes.indices) }
        let root = MXNode()
        // glTF is right-handed, +Y up, metres; the game uses the same handedness
        for i in rootsIdx { root.addChildNode(build(i, nodes, &ctx)) }
        return root
    }

    private static func build(_ i: Int, _ nodes: [[String: Any]], _ ctx: inout Ctx) -> MXNode {
        let nd = nodes[i]
        let n = MXNode()
        n.name = nd["name"] as? String
        if let m = nd["matrix"] as? [Double], m.count == 16 {
            var mm = simd_float4x4()
            for c in 0..<4 { mm[c] = SIMD4<Float>(Float(m[c * 4]), Float(m[c * 4 + 1]), Float(m[c * 4 + 2]), Float(m[c * 4 + 3])) }
            n.setLocalTransform(mm)
        } else {
            if let t = nd["translation"] as? [Double], t.count == 3 { n.position = MXVector3(Float(t[0]), Float(t[1]), Float(t[2])) }
            if let s = nd["scale"] as? [Double], s.count == 3 { n.scale = MXVector3(Float(s[0]), Float(s[1]), Float(s[2])) }
            if let r = nd["rotation"] as? [Double], r.count == 4 { n.orientation = MXVector4(Float(r[0]), Float(r[1]), Float(r[2]), Float(r[3])) }
        }
        if let mi = nd["mesh"] as? Int, let meshes = ctx.json["meshes"] as? [[String: Any]], meshes.indices.contains(mi) {
            let prims = meshes[mi]["primitives"] as? [[String: Any]] ?? []
            if let g = primitives(prims, &ctx) { n.geometry = g }
        }
        for c in nd["children"] as? [Int] ?? [] where nodes.indices.contains(c) { n.addChildNode(build(c, nodes, &ctx)) }
        return n
    }

    private static func primitives(_ prims: [[String: Any]], _ ctx: inout Ctx) -> MXGeometry? {
        let md = MXMeshData()
        var mats: [MXMaterial] = []
        for p in prims {
            if let mode = p["mode"] as? Int, mode != 4 { continue }
            guard let attrs = p["attributes"] as? [String: Int], let pa = attrs["POSITION"] else { continue }
            let pos = floats(pa, 3, ctx)
            let nrm = attrs["NORMAL"].map { floats($0, 3, ctx) } ?? []
            let uv = attrs["TEXCOORD_0"].map { floats($0, 2, ctx) } ?? []
            let base = UInt32(md.verts.count)
            let n = pos.count / 3
            for i in 0..<n {
                md.verts.append(MXVertex(px: pos[i * 3], py: pos[i * 3 + 1], pz: pos[i * 3 + 2],
                                         nx: nrm.count >= (i + 1) * 3 ? nrm[i * 3] : 0,
                                         ny: nrm.count >= (i + 1) * 3 ? nrm[i * 3 + 1] : 1,
                                         nz: nrm.count >= (i + 1) * 3 ? nrm[i * 3 + 2] : 0,
                                         u: uv.count >= (i + 1) * 2 ? uv[i * 2] : 0,
                                         v: uv.count >= (i + 1) * 2 ? uv[i * 2 + 1] : 0))
            }
            var idx: [UInt32] = []
            if let ia = p["indices"] as? Int { idx = indices(ia, ctx).map { $0 + base } }
            else { idx = (0..<UInt32(n)).map { $0 + base } }
            md.elems.append(idx)
            mats.append(material(p["material"] as? Int, &ctx))
        }
        if md.elems.isEmpty { return nil }
        let g = MXCustomGeometry(data: md)
        g.materials = mats
        return g
    }

    // MARK: accessors

    private static func view(_ acc: [String: Any], _ ctx: Ctx) -> (Data, Int, Int)? {
        guard let bv = acc["bufferView"] as? Int,
              let views = ctx.json["bufferViews"] as? [[String: Any]], views.indices.contains(bv) else { return nil }
        let v = views[bv]
        var buf = ctx.bin
        if (v["buffer"] as? Int ?? 0) != 0 || buf.isEmpty {
            if let bufs = ctx.json["buffers"] as? [[String: Any]], let b = bufs.indices.contains(v["buffer"] as? Int ?? 0) ? bufs[v["buffer"] as? Int ?? 0] : nil,
               let uri = b["uri"] as? String {
                if uri.hasPrefix("data:"), let c = uri.firstIndex(of: ","), let d = Data(base64Encoded: String(uri[uri.index(after: c)...])) { buf = d }
                else if let base = ctx.base, let d = try? Data(contentsOf: base.appendingPathComponent(uri)) { buf = d }
            }
        }
        let off = (v["byteOffset"] as? Int ?? 0) + (acc["byteOffset"] as? Int ?? 0)
        return (buf, off, v["byteStride"] as? Int ?? 0)
    }

    private static func floats(_ ai: Int, _ comps: Int, _ ctx: Ctx) -> [Float] {
        guard let accs = ctx.json["accessors"] as? [[String: Any]], accs.indices.contains(ai) else { return [] }
        let a = accs[ai]
        let count = a["count"] as? Int ?? 0
        let ct = a["componentType"] as? Int ?? 5126
        let norm = a["normalized"] as? Bool ?? false
        guard let (buf, off, strideIn) = view(a, ctx) else { return [Float](repeating: 0, count: count * comps) }
        let csz = (ct == 5126 || ct == 5125) ? 4 : (ct == 5123 || ct == 5122) ? 2 : 1
        let stride = strideIn > 0 ? strideIn : csz * comps
        var out = [Float](); out.reserveCapacity(count * comps)
        for i in 0..<count {
            for c in 0..<comps {
                let o = off + i * stride + c * csz
                if o + csz > buf.count { out.append(0); continue }
                switch ct {
                case 5126: out.append(Float(bitPattern: buf.u32(o)))
                case 5123: let x = Float(buf.u16(o)); out.append(norm ? x / 65535 : x)
                case 5121: let x = Float(buf[o]); out.append(norm ? x / 255 : x)
                case 5122: let x = Float(Int16(bitPattern: buf.u16(o))); out.append(norm ? max(x / 32767, -1) : x)
                case 5120: let x = Float(Int8(bitPattern: buf[o])); out.append(norm ? max(x / 127, -1) : x)
                default: out.append(0)
                }
            }
        }
        return out
    }

    private static func indices(_ ai: Int, _ ctx: Ctx) -> [UInt32] {
        guard let accs = ctx.json["accessors"] as? [[String: Any]], accs.indices.contains(ai) else { return [] }
        let a = accs[ai]
        let count = a["count"] as? Int ?? 0
        let ct = a["componentType"] as? Int ?? 5125
        guard let (buf, off, strideIn) = view(a, ctx) else { return [] }
        let csz = ct == 5125 ? 4 : ct == 5123 ? 2 : 1
        let stride = strideIn > 0 ? strideIn : csz
        var out = [UInt32](); out.reserveCapacity(count)
        for i in 0..<count {
            let o = off + i * stride
            if o + csz > buf.count { out.append(0); continue }
            out.append(ct == 5125 ? buf.u32(o) : ct == 5123 ? UInt32(buf.u16(o)) : UInt32(buf[o]))
        }
        return out
    }

    // MARK: materials

    private static func material(_ mi: Int?, _ ctx: inout Ctx) -> MXMaterial {
        if let mi = mi, let c = ctx.materials[mi] { return c }
        let m = MXMaterial()
        m.lightingModel = .blinn
        m.shininess = 0.15
        m.specular.contents = UIColor(white: 0.25, alpha: 1)
        if let mi = mi, let mats = ctx.json["materials"] as? [[String: Any]], mats.indices.contains(mi) {
            let d = mats[mi]
            m.isDoubleSided = d["doubleSided"] as? Bool ?? false
            let pbr = d["pbrMetallicRoughness"] as? [String: Any] ?? [:]
            if let f = pbr["baseColorFactor"] as? [Double], f.count == 4 {
                m.diffuse.contents = UIColor(red: CGFloat(f[0]), green: CGFloat(f[1]), blue: CGFloat(f[2]), alpha: CGFloat(f[3]))
            } else { m.diffuse.contents = UIColor.white }
            if let t = pbr["baseColorTexture"] as? [String: Any], let ti = t["index"] as? Int, let img = image(ti, &ctx) {
                m.diffuse.contents = img
            }
            let rf = (pbr["roughnessFactor"] as? Double) ?? 0.8
            if (pbr["metallicFactor"] as? Double ?? 0) <= 0.5, d["normalTexture"] != nil {
                // dielectric: glossiness follows the roughness factor (plaster dull, varnished wood and tile glossier)
                let r = max(0.12, min(1, rf))
                m.specular.contents = UIColor(white: CGFloat(0.12 + 0.2 * (1 - r)), alpha: 1)
                m.shininess = CGFloat(max(0.02, (2 / (r * r) - 2) / 128))
            }
            if let nt = d["normalTexture"] as? [String: Any], let ni = nt["index"] as? Int, let img = image(ni, &ctx) {
                // baked height map riding in the normal slot; the renderer turns it into a bump
                m.normal.contents = img
                m.bakedLighting = true
                m.normal.intensity = CGFloat((nt["scale"] as? Double) ?? 0.45)
            }
            if let met = pbr["metallicFactor"] as? Double, met > 0.5 {
                let rough = (pbr["roughnessFactor"] as? Double) ?? 0.5
                m.specular.contents = UIColor(white: 0.7, alpha: 1)
                m.shininess = CGFloat(0.25 + 0.5 * (1 - rough))
                m.reflective.contents = TwGunLib.envMap
                m.reflective.intensity = CGFloat(max(0.05, 0.5 - rough * 0.6))
            }
            if let e = d["emissiveFactor"] as? [Double], e.count == 3, e.contains(where: { $0 > 0 }) {
                m.emission.contents = UIColor(red: CGFloat(e[0]), green: CGFloat(e[1]), blue: CGFloat(e[2]), alpha: 1)
            }
            if (d["alphaMode"] as? String) == "BLEND", let f = pbr["baseColorFactor"] as? [Double], f.count == 4 {
                m.transparency = CGFloat(f[3])
            }
        } else {
            m.diffuse.contents = UIColor.white
        }
        if let mi = mi { ctx.materials[mi] = m }
        return m
    }

    private static func image(_ texIndex: Int, _ ctx: inout Ctx) -> UIImage? {
        guard let texs = ctx.json["textures"] as? [[String: Any]], texs.indices.contains(texIndex),
              let src = texs[texIndex]["source"] as? Int else { return nil }
        if let c = ctx.images[src] { return c }
        guard let imgs = ctx.json["images"] as? [[String: Any]], imgs.indices.contains(src) else { return nil }
        let im = imgs[src]
        var data: Data?
        if let bv = im["bufferView"] as? Int, let views = ctx.json["bufferViews"] as? [[String: Any]], views.indices.contains(bv) {
            let v = views[bv]
            let o = v["byteOffset"] as? Int ?? 0, l = v["byteLength"] as? Int ?? 0
            if o + l <= ctx.bin.count { data = ctx.bin.subdata(in: o..<o + l) }
        } else if let uri = im["uri"] as? String {
            if uri.hasPrefix("data:"), let c = uri.firstIndex(of: ",") { data = Data(base64Encoded: String(uri[uri.index(after: c)...])) }
            else if let base = ctx.base { data = try? Data(contentsOf: base.appendingPathComponent(uri)) }
        }
        guard let d = data, let ui = UIImage(data: d) else { return nil }
        ctx.images[src] = ui
        return ui
    }
}

private extension Data {
    func u32(_ o: Int) -> UInt32 {
        guard o + 4 <= count else { return 0 }
        return UInt32(self[startIndex + o]) | UInt32(self[startIndex + o + 1]) << 8 | UInt32(self[startIndex + o + 2]) << 16 | UInt32(self[startIndex + o + 3]) << 24
    }
    func u16(_ o: Int) -> UInt16 {
        guard o + 2 <= count else { return 0 }
        return UInt16(self[startIndex + o]) | UInt16(self[startIndex + o + 1]) << 8
    }
}
