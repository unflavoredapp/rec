import SwiftUI
import UIKit

/// look of the map builder: near-black panels, white hairlines, red accents
enum ME {
    static let bg = Color(red: 0.045, green: 0.045, blue: 0.055)
    static let panel = Color(red: 0.08, green: 0.08, blue: 0.09)
    static let field = Color(red: 0.125, green: 0.125, blue: 0.14)
    static let line = Color(white: 0.3)
    static let red = Color(red: 0.8, green: 0.06, blue: 0.17)
    static let txt = Color(white: 0.92)
    static let dim = Color(white: 0.62)
}

/// full-screen map builder: asset tree on the left, 3D-style layout view in the middle, object list and transform on the right
struct MapEditorView: View {
    let back: () -> Void
    let deploy: () -> Void

    private let mw = TWorkshop.mw, mh = TWorkshop.mh

    @State private var page = 0                       // 0 builder, 1 my maps, 2 about
    @State private var vpTab = 0                      // 0 layout, 1 asset preview
    @State private var maps: [WSMap] = TWorkshop.maps
    @State private var mapId = ""
    @State private var cells: [UInt8] = []
    @State private var undoStack: [[UInt8]] = []
    @State private var tile: UInt8 = 1
    @State private var tool = 0                       // 0 paint, 1 select, 2 orbit, 3 pan, 4 erase
    @State private var sel: Int? = nil
    @State private var yaw: Double = 28
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var pan = CGSize.zero
    @State private var lastDrag = CGSize.zero
    @State private var stroke = false
    @State private var dirty = false
    @State private var wire = false
    @State private var numbers = false
    @State private var showHelp = false
    @State private var search = ""
    @State private var catFilter = -1
    @State private var open: Set<Int> = [1, 4]
    @State private var xs = "0"
    @State private var ys = "0"
    @State private var zs = "0"
    @State private var vp = CGSize(width: 400, height: 260)
    @State private var rename = false
    @State private var renameText = ""
    @State private var shareText = ""
    @State private var showShare = false
    @State private var note = "Ready"
    @State private var viewMode = 0                   // 0 real 3D, 1 blueprint colour, 2 blueprint wire
    @State private var pitch: Double = 52
    @State private var dist: Double = 2500
    @State private var baseDist: Double = 2500
    @State private var target = CGPoint(x: 1350, y: 750)
    @State private var assetZoom: Double = 1
    @State private var baseAssetZoom: Double = 1
    @State private var h3 = Map3DHandle()

    private var mapIdx: Int? { maps.firstIndex(where: { $0.id == mapId }) }
    private var mapName: String { mapIdx.map { maps[$0].name } ?? "MAP" }

    // MARK: data

    private func def(_ i: Int) -> TWorkshop.TileDef { TWorkshop.tile(i) }

    private func isObject(_ k: TWorkshop.TK) -> Bool {
        switch k {
        case .floor, .water, .bridge: return false
        default: return true
        }
    }

    private var objects: [Int] {
        guard cells.count == mw * mh else { return [] }
        var out: [Int] = []
        for i in 0..<cells.count where isObject(def(Int(cells[i])).k) { out.append(i) }
        return out
    }

    private var spawnCount: Int {
        guard cells.count == mw * mh else { return 0 }
        var n = 0
        for v in cells {
            let k = def(Int(v)).k
            if k == .spawn || k == .spawnA || k == .spawnD { n += 1 }
        }
        return n
    }

    private func loadMap(_ id: String) {
        mapId = id
        TWorkshop.mapSel = id
        if let i = mapIdx { cells = TWorkshop.cellsArray(maps[i].cells) }
        if cells.count != mw * mh { cells = TWorkshop.defaultMap() }
        undoStack = []
        sel = nil
        dirty = false
        TCustom.invalidate()
        frameAll()
    }

    private func commit() {
        guard let i = mapIdx, cells.count == mw * mh else { return }
        maps[i].cells = TWorkshop.cellsString(cells)
        TWorkshop.maps = maps
        TWorkshop.mapSel = mapId
        TCustom.invalidate()
        dirty = false
        note = "Saved"
    }

    private func pushUndo() {
        undoStack.append(cells)
        if undoStack.count > 40 { undoStack.removeFirst() }
    }

    private func undo() {
        guard let u = undoStack.popLast() else { return }
        cells = u
        commit()
        note = "Undone"
    }

    private func newMap(name: String? = nil, cellsStr: String? = nil) {
        let m = WSMap(id: TWorkshop.newId(), name: name ?? "Custom Map \(maps.count + 1)", cells: cellsStr ?? TWorkshop.cellsString(TWorkshop.preset("Blank")), desc: "A custom map built in the Map Builder.")
        maps.append(m)
        TWorkshop.maps = maps
        loadMap(m.id)
    }

    private func deleteMap(_ id: String) {
        guard maps.count > 1, let i = maps.firstIndex(where: { $0.id == id }) else { note = "Keep at least one map"; return }
        maps.remove(at: i)
        TWorkshop.maps = maps
        if mapId == id { loadMap(maps[0].id) }
    }

    private func importClipboard() {
        guard let s = UIPasteboard.general.string else { note = "Clipboard is empty"; return }
        let p = s.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        if p.count >= 3, p[0] == "MAINSHOT-MAP", (p[2].count == mw * mh || p[2].count == mw * mh * 2) { newMap(name: p[1], cellsStr: p[2]); note = "Map imported" }
        else { note = "Nothing to import" }
    }

    private func setCell(_ i: Int, _ v: UInt8) {
        guard cells.count == mw * mh, i >= 0, i < cells.count else { return }
        pushUndo()
        cells[i] = v
        commit()
    }

    private func rotatedId(_ id: Int) -> Int? {
        let n = def(id).name
        let corners = ["NE", "SE", "SW", "NW"]
        let dirs = ["N", "E", "S", "W"]
        var target: String? = nil
        if n.hasPrefix("Corner "), let k = corners.firstIndex(of: String(n.dropFirst(7))) { target = "Corner " + corners[(k + 1) % 4] }
        else if n.hasPrefix("Wall "), n.count == 6, let k = dirs.firstIndex(of: String(n.dropFirst(5))) { target = "Wall " + dirs[(k + 1) % 4] }
        else if let last = n.last, let k = dirs.firstIndex(of: String(last)), n.count > 2, n.dropLast().last == " " { target = String(n.dropLast()) + dirs[(k + 1) % 4] }
        guard let t = target else { return nil }
        return TWorkshop.tiles.firstIndex(where: { $0.name == t })
    }

    private func rotateSel() {
        guard let s = sel, cells.count == mw * mh else { return }
        if let r = rotatedId(Int(cells[s])) { setCell(s, UInt8(r)); note = "Rotated 90°" } else { note = "This asset has no rotated variant" }
    }

    private func duplicateSel() {
        guard let s = sel, cells.count == mw * mh else { return }
        let id = cells[s]
        let c = s % mw, r = s / mw
        for (dc, dr) in [(1, 0), (0, 1), (-1, 0), (0, -1), (2, 0), (0, 2)] {
            let nc = c + dc, nr = r + dr
            if nc < 0 || nr < 0 || nc >= mw || nr >= mh { continue }
            let k = def(Int(cells[nr * mw + nc])).k
            if k == .floor { setCell(nr * mw + nc, id); sel = nr * mw + nc; note = "Duplicated"; return }
        }
        note = "No free cell next to it"
    }

    private func removeSel() {
        guard let s = sel else { return }
        setCell(s, 0)
        sel = nil
        note = "Removed"
    }

    private func applyTransform() {
        guard let s = sel, cells.count == mw * mh, let x = Double(xs), let y = Double(ys) else { note = "Pick an object first"; return }
        let c = max(0, min(mw - 1, Int((x / 75).rounded()))), r = max(0, min(mh - 1, Int((y / 75).rounded())))
        let t = r * mw + c
        if t == s { return }
        pushUndo()
        cells[t] = cells[s]
        cells[s] = 0
        sel = t
        commit()
        note = "Moved to \(c), \(r)"
    }

    private func addToLayout() {
        guard cells.count == mw * mh else { return }
        var t = sel ?? -1
        if t < 0 || def(Int(cells[t])).k != .floor || t < 0 {
            if let c = cellAt(CGPoint(x: vp.width / 2, y: vp.height / 2), vp) { t = c.1 * mw + c.0 } else { t = (mh / 2) * mw + mw / 2 }
        }
        setCell(t, tile)
        sel = t
        vpTab = 0
        note = "Added \(def(Int(tile)).name)"
    }

    // MARK: camera

    private func fit(_ sz: CGSize) -> CGFloat { min(sz.width / CGFloat(mw + mh) * 1.55, sz.height / CGFloat(mw + mh) * 2.1) }

    private func proj(_ gx: CGFloat, _ gy: CGFloat, _ h: CGFloat, _ sz: CGSize) -> CGPoint {
        let a = CGFloat(yaw * .pi / 180)
        let dx = gx - CGFloat(mw) / 2, dy = gy - CGFloat(mh) / 2
        let rx = dx * cos(a) - dy * sin(a)
        let ry = dx * sin(a) + dy * cos(a)
        let S = fit(sz) * zoom
        return CGPoint(x: sz.width / 2 + pan.width + rx * S, y: sz.height * 0.56 + pan.height + ry * S * 0.55 - h * S * 0.85)
    }

    private func cellAt(_ p: CGPoint, _ sz: CGSize) -> (Int, Int)? {
        let a = CGFloat(yaw * .pi / 180)
        let S = fit(sz) * zoom
        let rx = (p.x - sz.width / 2 - pan.width) / S
        let ry = (p.y - sz.height * 0.56 - pan.height) / (S * 0.55)
        let dx = rx * cos(a) + ry * sin(a)
        let dy = -rx * sin(a) + ry * cos(a)
        let c = Int(floor(dx + CGFloat(mw) / 2)), r = Int(floor(dy + CGFloat(mh) / 2))
        if c < 0 || r < 0 || c >= mw || r >= mh { return nil }
        return (c, r)
    }

    private func frameAll() {
        zoom = 1; baseZoom = 1; pan = .zero
        pitch = 52; dist = 2500; baseDist = 2500
        target = CGPoint(x: CGFloat(mw) * Map3DBuilder.ts / 2, y: CGFloat(mh) * Map3DBuilder.ts / 2)
    }

    private func zoom3D(_ f: Double) {
        dist = max(250, min(5200, dist * f)); baseDist = dist
        zoom = max(0.4, min(5, zoom / CGFloat(f))); baseZoom = zoom
    }

    private func frameSel() {
        guard let s = sel else { frameAll(); return }
        if viewMode == 0 {
            target = CGPoint(x: (CGFloat(s % mw) + 0.5) * Map3DBuilder.ts, y: (CGFloat(s / mw) + 0.5) * Map3DBuilder.ts)
            dist = 650; baseDist = 650
            return
        }
        let save = pan
        pan = .zero
        let p = proj(CGFloat(s % mw) + 0.5, CGFloat(s / mw) + 0.5, 0, vp)
        pan = CGSize(width: vp.width / 2 - p.x, height: vp.height / 2 - p.y)
        if pan == save { note = "Framed" }
    }

    // MARK: drawing

    private func heightOf(_ d: TWorkshop.TileDef) -> CGFloat {
        switch d.k {
        case .wall, .edge: return 1.0
        case .prop:
            switch d.pk {
            case .tree: return 1.3
            case .shelf: return 0.9
            case .car: return 0.55
            case .barrel: return 0.5
            case .sandbag: return 0.3
            case .table, .counter: return 0.4
            case .bed, .couch: return 0.3
            default: return 0.5
            }
        default: return 0
        }
    }

    private func quad(_ ctx: GraphicsContext, _ p: [CGPoint], _ col: Color, _ lineCol: Color? = nil) {
        var path = Path()
        path.move(to: p[0])
        for i in 1..<p.count { path.addLine(to: p[i]) }
        path.closeSubpath()
        if wire {
            ctx.stroke(path, with: .color(col.opacity(0.9)), lineWidth: 0.8)
        } else {
            ctx.fill(path, with: .color(col))
            if let l = lineCol { ctx.stroke(path, with: .color(l), lineWidth: 0.5) }
        }
    }

    private func box(_ ctx: GraphicsContext, _ sz: CGSize, _ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, _ h: CGFloat, _ col: Color) {
        let b = [proj(x0, y0, 0, sz), proj(x1, y0, 0, sz), proj(x1, y1, 0, sz), proj(x0, y1, 0, sz)]
        let t = [proj(x0, y0, h, sz), proj(x1, y0, h, sz), proj(x1, y1, h, sz), proj(x0, y1, h, sz)]
        let a = yaw * .pi / 180
        let normals: [(Double, Double)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
        for i in 0..<4 {
            let nx = normals[i].0, ny = normals[i].1
            let ry = nx * sin(a) + ny * cos(a)
            if ry <= 0.01 { continue }
            let rx = nx * cos(a) - ny * sin(a)
            let j = (i + 1) % 4
            quad(ctx, [b[i], b[j], t[j], t[i]], col, nil)
            if !wire { quad(ctx, [b[i], b[j], t[j], t[i]], Color.black.opacity(0.62 - 0.18 * abs(rx)), nil) }
        }
        quad(ctx, t, col, Color.black.opacity(0.35))
        if !wire { quad(ctx, t, Color.white.opacity(0.1), nil) }
    }

    private func drawCell(_ ctx: GraphicsContext, _ sz: CGSize, _ c: Int, _ r: Int, _ id: Int, floorOnly: Bool) {
        let d = def(id)
        let x = CGFloat(c), y = CGFloat(r)
        let corners = [proj(x, y, 0, sz), proj(x + 1, y, 0, sz), proj(x + 1, y + 1, 0, sz), proj(x, y + 1, 0, sz)]
        switch d.k {
        case .floor, .bridge:
            quad(ctx, corners, d.k == .floor ? TWorkshop.matColor(d.mat) : d.col, Color.black.opacity(0.25))
            if d.k == .bridge && !wire {
                let m0 = proj(x + 0.5, y, 0, sz), m1 = proj(x + 0.5, y + 1, 0, sz)
                var p = Path(); p.move(to: m0); p.addLine(to: m1)
                ctx.stroke(p, with: .color(Color.black.opacity(0.35)), lineWidth: 0.8)
            }
        case .water:
            quad(ctx, corners, d.col.opacity(0.95), Color.white.opacity(0.08))
        default:
            quad(ctx, corners, TWorkshop.matColor(8), Color.black.opacity(0.25))
            if floorOnly { return }
            switch d.k {
            case .spawn, .spawnA, .spawnD:
                var p = Path()
                let ctr = proj(x + 0.5, y + 0.5, 0.02, sz)
                let rad = fit(sz) * zoom * 0.3
                p.addEllipse(in: CGRect(x: ctr.x - rad, y: ctr.y - rad * 0.55, width: rad * 2, height: rad * 1.1))
                ctx.fill(p, with: .color(d.col.opacity(0.9)))
            case .loot:
                var p = Path()
                let ctr = proj(x + 0.5, y + 0.5, 0.35, sz)
                let rad = fit(sz) * zoom * 0.22
                p.move(to: CGPoint(x: ctr.x, y: ctr.y - rad)); p.addLine(to: CGPoint(x: ctr.x + rad, y: ctr.y))
                p.addLine(to: CGPoint(x: ctr.x, y: ctr.y + rad)); p.addLine(to: CGPoint(x: ctr.x - rad, y: ctr.y)); p.closeSubpath()
                ctx.fill(p, with: .color(d.col))
            case .site:
                quad(ctx, [proj(x + 0.05, y + 0.05, 0.02, sz), proj(x + 0.95, y + 0.05, 0.02, sz), proj(x + 0.95, y + 0.95, 0.02, sz), proj(x + 0.05, y + 0.95, 0.02, sz)], d.col.opacity(0.8), nil)
            default: break
            }
        }
    }

    private func drawObject(_ ctx: GraphicsContext, _ sz: CGSize, _ c: Int, _ r: Int, _ id: Int) {
        let d = def(id)
        let h = heightOf(d)
        if h <= 0 { return }
        let x = CGFloat(c), y = CGFloat(r)
        switch d.k {
        case .wall:
            box(ctx, sz, x, y, x + 1, y + 1, h, d.col)
        case .edge:
            for f in d.fr { box(ctx, sz, x + f.minX, y + f.minY, x + f.maxX, y + f.maxY, h, d.col) }
        case .prop:
            let f = d.fr[0]
            box(ctx, sz, x + f.minX, y + f.minY, x + f.maxX, y + f.maxY, h, d.col)
        default: break
        }
    }

    private func drawLayout(_ ctx: GraphicsContext, _ sz: CGSize) {
        guard cells.count == mw * mh else { return }
        // ground slab under the whole map
        quad(ctx, [proj(-0.6, -0.6, 0, sz), proj(CGFloat(mw) + 0.6, -0.6, 0, sz), proj(CGFloat(mw) + 0.6, CGFloat(mh) + 0.6, 0, sz), proj(-0.6, CGFloat(mh) + 0.6, 0, sz)], Color(white: 0.1), Color(white: 0.3))
        for r in 0..<mh { for c in 0..<mw { drawCell(ctx, sz, c, r, Int(cells[r * mw + c]), floorOnly: false) } }
        // objects far to near
        let a = yaw * .pi / 180
        var order: [(Double, Int)] = []
        for i in objects {
            let c = Double(i % mw) + 0.5 - Double(mw) / 2, r = Double(i / mw) + 0.5 - Double(mh) / 2
            order.append((c * sin(a) + r * cos(a), i))
        }
        order.sort { $0.0 < $1.0 }
        for (_, i) in order { drawObject(ctx, sz, i % mw, i / mw, Int(cells[i])) }
        if let s = sel, s >= 0, s < cells.count {
            let c = CGFloat(s % mw), r = CGFloat(s / mw)
            let h = max(0.12, heightOf(def(Int(cells[s]))))
            var p = Path()
            p.move(to: proj(c, r, h, sz)); p.addLine(to: proj(c + 1, r, h, sz)); p.addLine(to: proj(c + 1, r + 1, h, sz)); p.addLine(to: proj(c, r + 1, h, sz)); p.closeSubpath()
            ctx.stroke(p, with: .color(ME.red), lineWidth: 2.2)
            var q = Path()
            q.move(to: proj(c, r, 0, sz)); q.addLine(to: proj(c + 1, r, 0, sz)); q.addLine(to: proj(c + 1, r + 1, 0, sz)); q.addLine(to: proj(c, r + 1, 0, sz)); q.closeSubpath()
            ctx.stroke(q, with: .color(ME.red.opacity(0.7)), lineWidth: 1.2)
        }
        if numbers {
            for i in objects {
                let p = proj(CGFloat(i % mw) + 0.5, CGFloat(i / mw) + 0.5, heightOf(def(Int(cells[i]))) + 0.25, sz)
                ctx.draw(Text("\(i)").font(.system(size: 7, weight: .bold)).foregroundColor(.white), at: p)
            }
        }
    }

    private func drawPreview(_ ctx: GraphicsContext, _ sz: CGSize) {
        let d = def(Int(tile))
        let S = min(sz.width, sz.height) * 0.28
        let a = yaw * .pi / 180
        func pr(_ gx: CGFloat, _ gy: CGFloat, _ h: CGFloat) -> CGPoint {
            let dx = gx - 0.5, dy = gy - 0.5
            let rx = dx * CGFloat(cos(a)) - dy * CGFloat(sin(a)), ry = dx * CGFloat(sin(a)) + dy * CGFloat(cos(a))
            return CGPoint(x: sz.width / 2 + rx * S, y: sz.height * 0.62 + ry * S * 0.55 - h * S * 0.85)
        }
        var fl = Path()
        fl.move(to: pr(-0.3, -0.3, 0)); fl.addLine(to: pr(1.3, -0.3, 0)); fl.addLine(to: pr(1.3, 1.3, 0)); fl.addLine(to: pr(-0.3, 1.3, 0)); fl.closeSubpath()
        ctx.fill(fl, with: .color(Color(white: 0.14)))
        ctx.stroke(fl, with: .color(Color(white: 0.3)), lineWidth: 1)
        let h = max(0.08, heightOf(d))
        let rects: [CGRect]
        switch d.k {
        case .wall, .floor, .water, .bridge: rects = [CGRect(x: 0, y: 0, width: 1, height: 1)]
        default: rects = d.fr
        }
        let hh: CGFloat = (d.k == .floor || d.k == .water || d.k == .bridge) ? 0.06 : h
        let col = (d.k == .floor) ? TWorkshop.matColor(d.mat) : d.col
        for f in rects {
            let b = [pr(f.minX, f.minY, 0), pr(f.maxX, f.minY, 0), pr(f.maxX, f.maxY, 0), pr(f.minX, f.maxY, 0)]
            let t = [pr(f.minX, f.minY, hh), pr(f.maxX, f.minY, hh), pr(f.maxX, f.maxY, hh), pr(f.minX, f.maxY, hh)]
            let normals: [(Double, Double)] = [(0, -1), (1, 0), (0, 1), (-1, 0)]
            for i in 0..<4 {
                let ry = normals[i].0 * sin(a) + normals[i].1 * cos(a)
                if ry <= 0.01 { continue }
                let j = (i + 1) % 4
                var sp = Path(); sp.move(to: b[i]); sp.addLine(to: b[j]); sp.addLine(to: t[j]); sp.addLine(to: t[i]); sp.closeSubpath()
                ctx.fill(sp, with: .color(col))
                ctx.fill(sp, with: .color(Color.black.opacity(0.5)))
            }
            var tp = Path(); tp.move(to: t[0]); tp.addLine(to: t[1]); tp.addLine(to: t[2]); tp.addLine(to: t[3]); tp.closeSubpath()
            ctx.fill(tp, with: .color(col))
            ctx.stroke(tp, with: .color(Color.black.opacity(0.4)), lineWidth: 0.8)
        }
        ctx.draw(Text(d.name).font(.system(size: 13, weight: .bold)).foregroundColor(.white), at: CGPoint(x: sz.width / 2, y: 18))
        ctx.draw(Text(TWorkshop.catNames[min(d.cat, TWorkshop.catNames.count - 1)]).font(.system(size: 9)).foregroundColor(Color(white: 0.6)), at: CGPoint(x: sz.width / 2, y: 34))
    }

    private func thumb(_ s: String, _ w: CGFloat, _ h: CGFloat) -> some View {
        Canvas { ctx, sz in
            let a = TWorkshop.cellsArray(s)
            guard a.count == TWorkshop.mw * TWorkshop.mh else { return }
            let cs = min(sz.width / CGFloat(TWorkshop.mw), sz.height / CGFloat(TWorkshop.mh))
            for y in 0..<TWorkshop.mh {
                for x in 0..<TWorkshop.mw {
                    let d = TWorkshop.tile(Int(a[y * TWorkshop.mw + x]))
                    let r = CGRect(x: CGFloat(x) * cs, y: CGFloat(y) * cs, width: cs + 0.3, height: cs + 0.3)
                    let col: Color = d.k == .floor ? TWorkshop.matColor(d.mat) : d.col
                    ctx.fill(Path(r), with: .color(col))
                }
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: small UI

    private func btn(_ label: String, red: Bool = false, on: Bool = false, w: CGFloat? = nil, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 8).frame(width: w, height: 24)
                .background(red ? ME.red : (on ? Color(white: 0.28) : ME.field))
                .overlay(Rectangle().stroke(on ? Color.white.opacity(0.7) : ME.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func tabBtn(_ i: Int, _ label: String) -> some View {
        Button { page = i } label: {
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 12).frame(height: 28)
                .background(page == i ? ME.red : Color(white: 0.11))
                .overlay(Rectangle().stroke(Color.white.opacity(page == i ? 0.9 : 0.3), lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func vpTabBtn(_ i: Int, _ label: String) -> some View {
        Button { vpTab = i } label: {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 10).frame(height: 22)
                .background(vpTab == i ? ME.bg : Color(white: 0.12))
                .overlay(Rectangle().stroke(vpTab == i ? ME.red : ME.line, lineWidth: 1))
        }
        .buttonStyle(TuiPress())
    }

    private func radio(_ label: String, _ i: Int) -> some View {
        Button { tool = i } label: {
            HStack(spacing: 3) {
                Circle().stroke(Color.white.opacity(0.8), lineWidth: 1).frame(width: 9, height: 9)
                    .overlay(Circle().fill(tool == i ? Color.white : .clear).frame(width: 5, height: 5))
                Text(label).font(.system(size: 9)).foregroundColor(ME.txt).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(TuiPress())
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 8)).foregroundColor(ME.dim)
            TextField("0", text: text).font(.system(size: 10)).foregroundColor(.white).keyboardType(.numbersAndPunctuation)
                .padding(.horizontal, 4).frame(height: 22).background(ME.field).overlay(Rectangle().stroke(ME.line, lineWidth: 1))
        }
    }

    // MARK: asset tree (left)

    private func catIds(_ c: Int) -> [Int] {
        let q = search.lowercased()
        return TWorkshop.tiles.indices.filter { TWorkshop.tiles[$0].cat == c && (q.isEmpty || TWorkshop.tiles[$0].name.lowercased().contains(q)) }
    }

    private func treeRow(_ i: Int) -> some View {
        let d = def(i)
        let on = tile == UInt8(i)
        return Button { tile = UInt8(i); vpTab = vpTab == 1 ? 1 : 0; tool = tool == 2 || tool == 3 || tool == 1 ? 0 : tool } label: {
            HStack(spacing: 5) {
                if let ic = TileArt.icon(d.name) {
                    Image(uiImage: ic).resizable().scaledToFit().frame(width: 26, height: 26)
                } else {
                    Rectangle().fill(d.k == .floor ? TWorkshop.matColor(d.mat) : d.col).frame(width: 9, height: 9).overlay(Rectangle().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                }
                Text(d.name).font(.system(size: 10)).foregroundColor(on ? .white : ME.txt).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.leading, 14).padding(.trailing, 4).frame(height: 28)
            .background(on ? ME.red : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func assetPanel(_ w: CGFloat, _ h: CGFloat) -> some View {
        let total = TWorkshop.tiles.count
        return VStack(alignment: .leading, spacing: 5) {
            Text("BODYCAM ASSETS · \(total)").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
            Text("Search names or folders").font(.system(size: 8)).foregroundColor(ME.dim)
            HStack(spacing: 4) {
                TextField("", text: $search).font(.system(size: 10)).foregroundColor(.white).autocorrectionDisabled().textInputAutocapitalization(.never)
                    .padding(.horizontal, 4).frame(height: 22).background(Color.black).overlay(Rectangle().stroke(ME.line, lineWidth: 1))
                btn("Clear", w: 42) { search = "" }
            }
            Menu {
                Button("All assets") { catFilter = -1 }
                ForEach(0..<TWorkshop.catNames.count, id: \.self) { i in Button(TWorkshop.catNames[i].capitalized) { catFilter = i; open.insert(i) } }
            } label: {
                HStack {
                    Text(catFilter < 0 ? "All assets" : TWorkshop.catNames[catFilter].capitalized).font(.system(size: 10)).foregroundColor(.white)
                    Spacer()
                    SF("chevron.down").font(.system(size: 8)).foregroundColor(ME.dim)
                }
                .padding(.horizontal, 5).frame(height: 22).background(ME.field).overlay(Rectangle().stroke(ME.line, lineWidth: 1))
            }
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<TWorkshop.catNames.count, id: \.self) { c in
                        if catFilter < 0 || catFilter == c {
                            let ids = catIds(c)
                            if !ids.isEmpty || search.isEmpty {
                                Button { if open.contains(c) { open.remove(c) } else { open.insert(c) } } label: {
                                    HStack(spacing: 4) {
                                        SF(open.contains(c) || !search.isEmpty ? "arrowtriangle.down.fill" : "arrowtriangle.right.fill").font(.system(size: 7)).foregroundColor(ME.dim).frame(width: 10)
                                        if let ic = TileArt.icon(["wood_floor", "water", "wood_bridge", "wall", "crate", "tree", "bomb_site_a"][min(c, 6)]) {
                                            Image(uiImage: ic).resizable().scaledToFit().frame(width: 20, height: 20)
                                        }
                                        Text(TWorkshop.catNames[c].capitalized).font(.system(size: 10, weight: .semibold)).foregroundColor(.white)
                                        Text("\(ids.count)").font(.system(size: 8)).foregroundColor(ME.dim)
                                        Spacer(minLength: 0)
                                    }
                                    .frame(height: 20)
                                }
                                .buttonStyle(.plain)
                                if open.contains(c) || !search.isEmpty {
                                    ForEach(ids, id: \.self) { i in treeRow(i) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(3).background(Color.black).overlay(Rectangle().stroke(Color.white.opacity(0.7), lineWidth: 1))
            let d = def(Int(tile))
            HStack(spacing: 6) {
                if let ic = TileArt.icon(d.name) { Image(uiImage: ic).resizable().scaledToFit().frame(width: 44, height: 44).background(Color.black).overlay(Rectangle().stroke(ME.line, lineWidth: 1)) }
                Text("\(d.name) · \(TWorkshop.catNames[min(d.cat, TWorkshop.catNames.count - 1)].capitalized)").font(.system(size: 8)).foregroundColor(ME.dim).lineLimit(2)
            }
            HStack(spacing: 4) {
                btn("Preview", w: (w - 24) * 0.4) { vpTab = 1 }
                btn("Add to layout", red: true, w: (w - 24) * 0.6) { addToLayout() }
            }
        }
        .padding(6)
        .frame(width: w, height: h, alignment: .topLeading)
        .background(ME.bg)
    }

    // MARK: viewport (center)

    private func viewport(_ w: CGFloat, _ h: CGFloat) -> some View {
        let vh = h - 26 - 24 - 36
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                btn("Frame all") { frameAll() }
                btn("Frame selected") { frameSel() }
                btn("Help", on: showHelp) { showHelp.toggle() }
                btn("Undo") { undo() }
                Menu {
                    ForEach(TWorkshop.presetNames, id: \.self) { n in
                        Button("Load preset: \(n)") { pushUndo(); cells = TWorkshop.preset(n); sel = nil; commit() }
                    }
                } label: {
                    Text("Presets ▾").font(.system(size: 10, weight: .semibold)).foregroundColor(.white).padding(.horizontal, 8).frame(height: 24)
                        .background(ME.field).overlay(Rectangle().stroke(ME.line, lineWidth: 1))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 4) {
                btn("View: \(["3D", "Color", "Wire"][viewMode])") { viewMode = (viewMode + 1) % 3; wire = viewMode == 2 }
                btn("Zoom +", w: 52) { zoom3D(0.78) }
                btn("Zoom −", w: 52) { zoom3D(1.28) }
                btn("Numbers: \(numbers ? "On" : "Off")") { numbers.toggle() }
                Text("\(objects.count) objects · \(mw)×\(mh) tiles").font(.system(size: 9)).foregroundColor(ME.dim)
                Spacer(minLength: 0)
            }
            HStack(spacing: 0) {
                vpTabBtn(0, "Layout")
                vpTabBtn(1, "Asset preview")
                Spacer(minLength: 0)
            }
            ZStack(alignment: .topLeading) {
                Color.black
                if vpTab == 0 {
                    if viewMode == 0 {
                        MapView3D(cells: cells, sel: sel, yaw: yaw, pitch: pitch, dist: dist, target: target, handle: h3)
                            .overlay(Color.clear.contentShape(Rectangle())
                                .gesture(drag3D())
                                .simultaneousGesture(MagnificationGesture()
                                    .onChanged { v in dist = max(250, min(5200, baseDist / Double(v))) }
                                    .onEnded { _ in baseDist = dist }))
                    } else {
                        Canvas { ctx, sz in drawLayout(ctx, sz) }
                            .gesture(dragGesture(CGSize(width: w - 6, height: vh)))
                            .simultaneousGesture(MagnificationGesture()
                                .onChanged { v in zoom = max(0.4, min(5, baseZoom * v)) }
                                .onEnded { _ in baseZoom = zoom })
                    }
                } else {
                    AssetView3D(tileId: Int(tile), yaw: yaw, zoom: assetZoom)
                        .overlay(Color.clear.contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                                yaw += Double(g.translation.width - lastDrag.width) * 0.6
                                lastDrag = g.translation
                            }.onEnded { _ in lastDrag = .zero })
                            .simultaneousGesture(MagnificationGesture()
                                .onChanged { v in assetZoom = max(0.5, min(3.2, baseAssetZoom * Double(v))) }
                                .onEnded { _ in baseAssetZoom = assetZoom }))
                        .overlay(alignment: .topTrailing) { assetDetail().padding(6) }
                        .overlay(alignment: .bottomLeading) {
                            HStack(spacing: 4) {
                                btn("Zoom +", w: 52) { assetZoom = min(3.2, assetZoom * 1.25); baseAssetZoom = assetZoom }
                                btn("Zoom −", w: 52) { assetZoom = max(0.5, assetZoom / 1.25); baseAssetZoom = assetZoom }
                                btn("Place it", red: true, w: 60) { addToLayout() }
                            }
                            .padding(6)
                        }
                }
                Text(vpTab == 0 ? "\(mapName.uppercased()) · \(dirty ? "UNSAVED" : "SAVED IN APP") · PLAYS OFFLINE VS BOTS" : "ASSET PREVIEW · drag to turn · pinch to zoom")
                    .font(.system(size: 8)).foregroundColor(Color(white: 0.75)).padding(4).allowsHitTesting(false)
            }
            .frame(width: w - 6, height: vh)
            .overlay(Rectangle().stroke(ME.red, lineWidth: 2))
            .clipped()
            .background(GeometryReader { _ in Color.clear.onAppear { vp = CGSize(width: w - 6, height: vh) } })
            Text(showHelp ? "Paint: drag over tiles · Select: tap a tile · Orbit: drag to turn · Pan: drag to move · Pinch: zoom · Erase: drag to clear. Tiles are placed on a \(mw)×\(mh) grid, 75 cm per tile." : "Tool: \(["Paint", "Select", "Orbit", "Pan", "Erase"][tool]) · tile: \(def(Int(tile)).name) · pinch to zoom")
                .font(.system(size: 8)).foregroundColor(ME.dim).lineLimit(2).frame(height: 24, alignment: .topLeading)
        }
        .frame(width: w, height: h, alignment: .topLeading)
    }

    /// drag handling for the real 3D view (picking goes through the projected ground grid)
    private func drag3D() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                switch tool {
                case 0, 4:
                    if !stroke { stroke = true; pushUndo() }
                    if let i = h3.cell(at: g.location), cells.count == mw * mh {
                        let v: UInt8 = tool == 4 ? 0 : tile
                        if cells[i] != v { cells[i] = v; dirty = true }
                    }
                case 1:
                    if let i = h3.cell(at: g.location) { sel = i }
                case 2:
                    yaw += Double(g.translation.width - lastDrag.width) * 0.45
                    pitch = max(14, min(86, pitch + Double(g.translation.height - lastDrag.height) * 0.3))
                    lastDrag = g.translation
                default:
                    let a = yaw * .pi / 180
                    let k = dist * 0.0011
                    let dx = Double(g.translation.width - lastDrag.width) * k, dy = Double(g.translation.height - lastDrag.height) * k
                    target = CGPoint(x: target.x - CGFloat(cos(a) * dx) + CGFloat(-sin(a) * dy), y: target.y + CGFloat(sin(a) * dx) + CGFloat(-cos(a) * dy))
                    lastDrag = g.translation
                }
            }
            .onEnded { _ in
                stroke = false
                lastDrag = .zero
                if dirty { commit() }
            }
    }

    private func detailLine(_ k: String, _ v: String) -> some View {
        HStack(spacing: 6) {
            Text(k).font(.system(size: 8, weight: .semibold)).foregroundColor(ME.dim).frame(width: 52, alignment: .leading)
            Text(v).font(.system(size: 9, weight: .semibold)).foregroundColor(.white)
        }
    }

    /// size, height, behaviour of the selected asset
    private func assetDetail() -> some View {
        let d = def(Int(tile))
        let hcm = Int(Map3DBuilder.heightCm(d))
        var fw = 75, fd = 75
        if d.k == .prop || d.k == .edge, let f = d.fr.first {
            fw = Int(f.width * 75); fd = Int(f.height * 75)
        }
        let kind: String
        let behaviour: String
        switch d.k {
        case .floor: kind = "Floor · \(d.name)"; behaviour = "Walkable"
        case .water: kind = "Liquid"; behaviour = TWorkshop.liquidMats.contains(d.mat) ? "Blocks movement, bullets pass" : "Walkable"
        case .bridge: kind = "Bridge"; behaviour = "Walkable over water"
        case .wall: kind = "Solid wall"; behaviour = "Blocks movement, sight and bullets"
        case .edge: kind = "Wall piece"; behaviour = "Blocks movement, sight and bullets"
        case .prop: kind = "Cover prop"; behaviour = d.pk == .tree || d.pk == .shelf ? "Solid, blocks sight" : "Solid cover"
        case .spawn: kind = "Spawn marker"; behaviour = "Player / bot start"
        case .spawnA: kind = "Attack spawn"; behaviour = "Attackers start here"
        case .spawnD: kind = "Defend spawn"; behaviour = "Defenders start here"
        case .loot: kind = "Loot spot"; behaviour = "Pickup: \(d.tag.isEmpty ? "random" : d.tag)"
        case .site: kind = "Bomb site \(d.tag)"; behaviour = "Plant / defuse zone"
        }
        return VStack(alignment: .leading, spacing: 3) {
            Text(d.name.uppercased()).font(.system(size: 11, weight: .heavy)).foregroundColor(.white)
            Text(TWorkshop.catNames[min(d.cat, TWorkshop.catNames.count - 1)]).font(.system(size: 8)).foregroundColor(ME.dim)
            detailLine("TYPE", kind)
            detailLine("FOOTPRINT", "\(fw) × \(fd) cm")
            detailLine("HEIGHT", hcm == 0 ? "flat" : "\(hcm) cm")
            detailLine("BEHAVIOUR", behaviour)
            detailLine("ID", "#\(tile)")
        }
        .padding(7)
        .background(Color.black.opacity(0.72))
        .overlay(Rectangle().stroke(ME.line, lineWidth: 1))
        .allowsHitTesting(false)
    }

    private func dragGesture(_ sz: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                switch tool {
                case 0, 4:
                    if !stroke { stroke = true; pushUndo() }
                    if let (c, r) = cellAt(g.location, sz), cells.count == mw * mh {
                        let v: UInt8 = tool == 4 ? 0 : tile
                        if cells[r * mw + c] != v { cells[r * mw + c] = v; dirty = true }
                    }
                case 1:
                    if let (c, r) = cellAt(g.location, sz) { sel = r * mw + c }
                case 2:
                    yaw += Double(g.translation.width - lastDrag.width) * 0.5
                    lastDrag = g.translation
                default:
                    pan = CGSize(width: pan.width + g.translation.width - lastDrag.width, height: pan.height + g.translation.height - lastDrag.height)
                    lastDrag = g.translation
                }
            }
            .onEnded { _ in
                stroke = false
                lastDrag = .zero
                if dirty { commit() }
            }
    }

    // MARK: object panel (right)

    private func objectPanel(_ w: CGFloat, _ h: CGFloat) -> some View {
        let objs = objects
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text("\(mapName.uppercased()) · \(objs.count) objects").font(.system(size: 10, weight: .bold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer(minLength: 0)
                    Menu {
                        Button("Select next object") { if let n = objs.first(where: { $0 > (sel ?? -1) }) ?? objs.first { sel = n; frameSel() } }
                        Button("Clear selection") { sel = nil }
                    } label: { Text("Select ▾").font(.system(size: 9)).foregroundColor(.white).padding(.horizontal, 5).frame(height: 20).background(ME.field).overlay(Rectangle().stroke(ME.line, lineWidth: 1)) }
                    Menu {
                        Button("Rename map") { renameText = mapName; rename = true }
                        Button("Duplicate map") { if let i = mapIdx { newMap(name: maps[i].name + " Copy", cellsStr: maps[i].cells) } }
                        Button("Import from clipboard") { importClipboard() }
                        Button("Delete map", role: .destructive) { deleteMap(mapId) }
                    } label: { Text("Bundle ▾").font(.system(size: 9)).foregroundColor(.white).padding(.horizontal, 5).frame(height: 20).background(ME.field).overlay(Rectangle().stroke(ME.line, lineWidth: 1)) }
                }
                VStack(spacing: 0) {
                    HStack {
                        Text("Object").font(.system(size: 9, weight: .semibold)).foregroundColor(.black)
                        Spacer()
                        Text("Use").font(.system(size: 9, weight: .semibold)).foregroundColor(.black)
                    }
                    .padding(.horizontal, 5).frame(height: 18).background(Color(white: 0.82))
                    ScrollView(showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(objs.prefix(400), id: \.self) { i in
                                Button { sel = i; tool = tool == 0 ? 1 : tool } label: {
                                    HStack {
                                        Text("\(def(Int(cells[i])).name)  \(i % mw),\(i / mw)").font(.system(size: 9)).foregroundColor(sel == i ? .white : .black).lineLimit(1)
                                        Spacer()
                                        Text("Deploy").font(.system(size: 9)).foregroundColor(sel == i ? .white : .black)
                                    }
                                    .padding(.horizontal, 5).frame(height: 18).background(sel == i ? ME.red : Color.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(height: max(60, h * 0.28)).background(Color.white)
                }
                .overlay(Rectangle().stroke(ME.line, lineWidth: 1))
                HStack(spacing: 4) {
                    field("X (cm)", $xs); field("Y (cm)", $ys); field("Z (cm)", $zs)
                }
                btn("Apply transform", w: w - 12) { applyTransform() }
                HStack(spacing: 6) {
                    Text("Tool").font(.system(size: 9)).foregroundColor(ME.dim)
                    radio("Paint", 0); radio("Select", 1); radio("Orbit", 2)
                }
                HStack(spacing: 8) {
                    Spacer().frame(width: 22)
                    radio("Pan", 3); radio("Erase", 4)
                }
                HStack(spacing: 4) {
                    btn("Duplicate", w: (w - 16) / 3) { duplicateSel() }
                    btn("Rotate 90°", w: (w - 16) / 3) { rotateSel() }
                    btn("Remove", w: (w - 16) / 3) { removeSel() }
                }
                HStack(spacing: 4) {
                    Menu {
                        ForEach(maps) { m in Button(m.name) { loadMap(m.id) } }
                        Divider()
                        Button("New blank map") { newMap() }
                        ForEach(TWorkshop.presetNames, id: \.self) { n in Button("New from \(n)") { newMap(name: n, cellsStr: TWorkshop.cellsString(TWorkshop.preset(n))) } }
                    } label: {
                        Text("New / Open ▾").font(.system(size: 10, weight: .semibold)).foregroundColor(.white).frame(width: (w - 16) * 0.42, height: 24)
                            .background(ME.field).overlay(Rectangle().stroke(ME.line, lineWidth: 1))
                    }
                    btn("Save", red: true, w: (w - 16) * 0.26) { commit() }
                    btn("Export", w: (w - 16) * 0.32) { if let i = mapIdx { shareText = "MAINSHOT-MAP|\(maps[i].name)|\(maps[i].cells)"; showShare = true } }
                }
                Button { commit(); deploy() } label: {
                    Text("Deploy layout to game").font(.system(size: 12, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: 30).background(ME.red)
                }
                .buttonStyle(TuiPress())
                Text("Ready to deploy. Replaces the custom map with this layout and starts a bot match on it. \(spawnCount) spawn points placed; the builder fills in the rest.")
                    .font(.system(size: 8)).foregroundColor(ME.dim).fixedSize(horizontal: false, vertical: true)
            }
            .padding(6)
        }
        .frame(width: w, height: h)
        .background(ME.bg)
    }

    // MARK: pages

    private func myMaps(_ w: CGFloat, _ h: CGFloat) -> some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(maps) { m in
                    VStack(alignment: .leading, spacing: 4) {
                        thumb(m.cells, 150, 84).overlay(Rectangle().stroke(m.id == mapId ? ME.red : ME.line, lineWidth: m.id == mapId ? 2 : 1))
                        Text(m.name).font(.system(size: 11, weight: .bold)).foregroundColor(.white).lineLimit(1)
                        HStack(spacing: 4) {
                            btn("Open", red: true) { loadMap(m.id); page = 0 }
                            btn("Copy") { newMap(name: m.name + " Copy", cellsStr: m.cells) }
                            btn("Delete") { deleteMap(m.id) }
                        }
                    }
                    .padding(6).background(ME.panel).overlay(Rectangle().stroke(ME.line, lineWidth: 1))
                }
            }
            .padding(10)
        }
        .frame(width: w, height: h).background(ME.bg)
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MAP BUILDER").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            Text("Browse the asset tree, pick a tile, then paint it onto the layout. Select an object to move it by coordinates, rotate it, duplicate it or remove it. Save keeps the map on this device. Deploy starts a bot match on your layout.")
            Text("Place Attack and Defend spawns, Bomb Sites A and B and loot from the Special folder. Anything you leave out is filled in automatically so the map always plays.")
            Text("Export copies a share code you can paste into Bundle > Import from clipboard on another device.")
            Text(TacCredits.text).font(.system(size: 9)).foregroundColor(ME.txt.opacity(0.7)).padding(.top, 8)
        }
        .font(.system(size: 11)).foregroundColor(ME.txt).padding(14).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(ME.bg)
    }

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            let top: CGFloat = 32
            let bar: CGFloat = 22
            let bodyH = H - top - bar - 6
            let lw = max(150, min(190, W * 0.22)), rw = max(180, min(230, W * 0.26))
            ZStack(alignment: .topLeading) {
                ME.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 3) {
                        Button { back() } label: {
                            HStack(spacing: 3) { SF("chevron.left").font(.system(size: 9, weight: .bold)); Text("Lobby").font(.system(size: 11, weight: .semibold)) }
                                .foregroundColor(.white).padding(.horizontal, 10).frame(height: 28).background(Color(white: 0.11)).overlay(Rectangle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(TuiPress())
                        tabBtn(0, "Map Builder"); tabBtn(1, "My Maps"); tabBtn(2, "About")
                        Spacer(minLength: 0)
                        Text(note).font(.system(size: 9)).foregroundColor(ME.dim)
                    }
                    .padding(.horizontal, 6).padding(.top, 4).frame(height: top)
                    Group {
                        if page == 0 {
                            HStack(alignment: .top, spacing: 4) {
                                assetPanel(lw, bodyH)
                                viewport(W - lw - rw - 20, bodyH)
                                objectPanel(rw, bodyH)
                            }
                            .padding(.horizontal, 6)
                        } else if page == 1 {
                            myMaps(W - 12, bodyH).padding(.horizontal, 6)
                        } else {
                            about.padding(.horizontal, 6)
                        }
                    }
                    .frame(height: bodyH + 6)
                    HStack {
                        Text("\(maps.count) maps · \(mapName)").font(.system(size: 9)).foregroundColor(ME.dim)
                        Spacer()
                        Circle().fill(dirty ? Color.orange : ME.red).frame(width: 6, height: 6)
                        Text(dirty ? "UNSAVED" : "SAVED").font(.system(size: 9, weight: .semibold)).foregroundColor(ME.txt)
                    }
                    .padding(.horizontal, 10).frame(height: bar).background(Color(white: 0.07))
                }
                if rename {
                    RenameOverlay(text: $renameText) { ok in
                        if ok && !renameText.isEmpty, let i = mapIdx { maps[i].name = renameText; TWorkshop.maps = maps }
                        rename = false
                    }
                    .frame(width: W, height: H)
                }
            }
            .frame(width: W, height: H)
        }
        .sheet(isPresented: $showShare) { ShareSheet(text: shareText) }
        .onChange(of: sel) { v in
            if let s = v { xs = "\((s % mw) * 75)"; ys = "\((s / mw) * 75)"; zs = "0" }
        }
        .onAppear {
            maps = TWorkshop.maps
            loadMap(TWorkshop.currentMap.id)
        }
    }
}
