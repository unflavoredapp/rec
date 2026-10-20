import SwiftUI

/// small painted card art: 0 harbor, 1 town, 2 industrial / extraction
struct MiniArt: View {
    var desert = false
    var variant = 0

    var body: some View {
        let v = desert ? 1 : variant
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let sky: [Color] = v == 1 ? [Color(red: 0.45, green: 0.62, blue: 0.82), Color(red: 0.98, green: 0.8, blue: 0.55)] : [Color(red: 0.3, green: 0.5, blue: 0.8), Color(red: 0.98, green: 0.78, blue: 0.52)]
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .linearGradient(Gradient(colors: sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: h * 0.7)))
            if v == 1 {
                let wall: [Color] = [Color(red: 0.78, green: 0.62, blue: 0.42), Color(red: 0.66, green: 0.52, blue: 0.36), Color(red: 0.86, green: 0.72, blue: 0.5)]
                for i in 0..<7 {
                    let bw = w / 7
                    let bh = h * (0.3 + 0.16 * CGFloat((i * 5) % 4))
                    let x = bw * CGFloat(i)
                    ctx.fill(Path(CGRect(x: x, y: h - bh - 4, width: bw - 1, height: bh + 4)), with: .color(wall[i % 3]))
                    ctx.fill(Path(CGRect(x: x + bw * 0.2, y: h - bh + 3, width: bw * 0.22, height: 4)), with: .color(Color(red: 0.2, green: 0.2, blue: 0.25).opacity(0.7)))
                    ctx.fill(Path(CGRect(x: x + bw * 0.58, y: h - bh + 3, width: bw * 0.22, height: 4)), with: .color(Color(red: 0.2, green: 0.2, blue: 0.25).opacity(0.7)))
                }
                ctx.fill(Path(CGRect(x: 0, y: h - 6, width: w, height: 6)), with: .color(Color(red: 0.55, green: 0.45, blue: 0.33)))
            } else if v == 2 {
                ctx.fill(Path(CGRect(x: 0, y: h * 0.64, width: w, height: h * 0.1)), with: .color(Color(red: 0.2, green: 0.32, blue: 0.45)))
                for i in 0..<4 {
                    let bw = w * 0.2
                    let x = w * (0.04 + 0.24 * CGFloat(i))
                    let bh = h * (0.28 + 0.1 * CGFloat(i % 2))
                    ctx.fill(Path(CGRect(x: x, y: h * 0.72 - bh, width: bw, height: bh)), with: .color(Color(red: 0.42, green: 0.45, blue: 0.5)))
                    ctx.fill(Path(CGRect(x: x - 2, y: h * 0.72 - bh - 3, width: bw + 4, height: 4)), with: .color(Color(red: 0.3, green: 0.32, blue: 0.38)))
                }
                for (i, c) in HarborArt.boxCols.prefix(6).enumerated() {
                    HarborArt.box(ctx, w * CGFloat(i) / 6, h * 0.72, w / 6 - 1, h * 0.28, c)
                }
            } else {
                ctx.fill(Path(CGRect(x: 0, y: h * 0.58, width: w, height: h * 0.12)), with: .color(Color(red: 0.22, green: 0.38, blue: 0.52)))
                for cx in [0.2, 0.55, 0.88] as [CGFloat] {
                    HarborArt.crane(ctx, x: w * cx, top: h * 0.14, base: h * 0.74, s: max(0.3, h / 110))
                }
                var i = 0
                for gx in stride(from: CGFloat(0), to: w, by: max(9, w / 12)) {
                    let rows = 1 + (i * 7) % 3
                    for r in 0..<rows {
                        HarborArt.box(ctx, gx, h * 0.76 - CGFloat(r) * h * 0.14, max(8, w / 12 - 1), h * 0.13, HarborArt.boxCols[(i + r) % HarborArt.boxCols.count])
                    }
                    i += 1
                }
                ctx.fill(Path(CGRect(x: 0, y: h * 0.76, width: w, height: h * 0.24)), with: .color(Color(red: 0.45, green: 0.37, blue: 0.3)))
            }
        }
    }
}

