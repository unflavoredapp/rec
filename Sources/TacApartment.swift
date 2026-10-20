import SwiftUI

/// BLOCK 9 (kind 6): a worn-out three-floor apartment block on a cramped street lot.
/// 0 basement (boiler / garage / cellar), 1 street level (lobby, units, corridor), 2 upper floor (units).
/// Everything is close quarters: one long corridor per floor, doors into every unit, two stairwells, five ways in from outside.
enum TApartment {
    static let shared: MapData = build()

    private static func build() -> MapData {
        let b = MapBuilder()
        let rc = b.rc

        // ---- street lot
        let arena = rc(150, 100, 2700, 1600)
        b.setR(1, arena, true)
        b.tiles.insert(TRoom(name: "Yard", r: MapBuilder.R(1, arena), mat: 8, fl: 1), at: 0)
        b.rooms.append(TRoom(name: "West Lot", r: MapBuilder.R(1, rc(150, 100, 250, 1600)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "East Lot", r: MapBuilder.R(1, rc(2600, 100, 250, 1600)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "North Alley", r: MapBuilder.R(1, rc(400, 100, 2200, 300)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "Street", r: MapBuilder.R(1, rc(400, 1400, 2200, 300)), mat: 8, fl: 1))

        // building shell: everything inside the footprint is wall until a room is cut out of it
        let outer = rc(400, 400, 2200, 1000)
        b.setR(1, outer, false)
        b.setR(2, outer, false)
        b.outers.append(outer)

        // column x ranges shared by every floor: rooms never move, so stairs and sightlines line up
        let cols: [(CGFloat, CGFloat)] = [(425, 400), (850, 425), (1300, 425), (1750, 425), (2200, 375)]
        let northY: CGFloat = 425, northH: CGFloat = 325
        let southY: CGFloat = 925, southH: CGFloat = 450
        let corY: CGFloat = 775, corH: CGFloat = 125
        // door gap x for every column (100 wide), corridor side
        let gapX: [CGFloat] = [550, 1000, 1450, 1900, 2325]

        func door(_ fl: Int, _ x: CGFloat, _ y: CGFloat) { b.doors.append(b.dh(fl, x, y, 100)) }

        // ---- floor builder (1 = street level units, 2 = upper units)
        func unitFloor(_ fl: Int, _ nn: [String], _ sn: [String], _ cor: String) {
            let tileN: [Int] = [4, 4, 3, 4, 3]
            let tileS: [Int] = [4, 3, 1, 4, 5]
            for i in 0..<5 {
                b.area(fl, nn[i], rc(cols[i].0, northY, cols[i].1, northH), tileN[i])
                if fl == 1 && i == 2 {
                    b.area(fl, "Lobby", rc(cols[i].0, southY, cols[i].1, southH), 1)
                } else {
                    b.area(fl, sn[i], rc(cols[i].0, southY, cols[i].1, southH), tileS[i])
                }
            }
            b.area(fl, cor, rc(425, corY, 2150, corH), 5)
            // doorways from the corridor into every unit (lobby gets a wide open archway instead of a door)
            for i in 0..<5 {
                b.gap(fl, rc(gapX[i], 750, 100, 25), 5); door(fl, gapX[i], 750)
                if fl == 1 && i == 2 {
                    b.gap(fl, rc(1375, 900, 250, 25), 1)
                } else {
                    b.gap(fl, rc(gapX[i], 900, 100, 25), 5); door(fl, gapX[i], 900)
                }
            }
        }
        unitFloor(1, ["Apt 101", "Apt 102", "Apt 103", "Apt 104", "Apt 105"], ["Laundry", "Apt 106", "Lobby", "Apt 107", "Store Room"], "Ground Corridor")
        unitFloor(2, ["Apt 201", "Apt 202", "Apt 203", "Apt 204", "Apt 205"], ["Apt 206", "Apt 207", "Apt 208", "Apt 209", "Apt 210"], "Upper Corridor")

        // ---- ways in from outside: lobby, both corridor ends, two back doors
        b.gap(1, rc(1450, 1375, 100, 25), 1); door(1, 1450, 1375)
        b.gap(1, rc(400, 800, 25, 100), 5); b.doors.append(b.dv(1, 400, 800, 100))
        b.gap(1, rc(2575, 800, 25, 100), 5); b.doors.append(b.dv(1, 2575, 800, 100))
        b.gap(1, rc(500, 400, 100, 25), 4); door(1, 500, 400)
        b.gap(1, rc(2400, 400, 100, 25), 3); door(1, 2400, 400)

        // ---- basement: boiler, electrical, storage up north; garage bay, laundry, cellar down south
        b.area(0, "Basement Corridor", rc(425, corY, 2150, corH), 8)
        let bn: [(String, CGFloat, CGFloat, CGFloat)] = [("Boiler Room", 500, 500, 700), ("Electrical", 1100, 400, 1250), ("Storage Cage", 1600, 500, 1800)]
        for r in bn {
            b.area(0, r.0, rc(r.1, 450, r.2, 300), 8)
            b.gap(0, rc(r.3, 750, 100, 25), 8); door(0, r.3, 750)
        }
        let bs: [(String, CGFloat, CGFloat, CGFloat)] = [("Garage Bay", 500, 700, 800), ("Laundry Store", 1300, 400, 1450), ("Cellar", 1800, 700, 2100)]
        for r in bs {
            b.area(0, r.0, rc(r.1, 925, r.2, 400), 8)
            b.gap(0, rc(r.3, 900, 100, 25), 8); door(0, r.3, 900)
        }

        // stairs: west pair and east pair, each between corridor ends; lo = lower floor index
        let stairs: [CGRect] = [rc(425, 775, 100, 125), rc(675, 775, 100, 125), rc(2475, 775, 100, 125), rc(2150, 775, 100, 125)]
        let stairLo: [Int] = [0, 1, 0, 1]
        let layout = b.layout([.concrete, .brick, .concrete])

        // ---- furniture
        // far wall is the one opposite the doorway: top for the north row, bottom for the south row
        func furnish(_ fl: Int, _ r: CGRect, north: Bool, _ style: Int) {
            func ty(_ off: CGFloat, _ h: CGFloat) -> CGFloat { north ? r.minY + off : r.maxY - off - h }
            let cx = r.midX
            switch style {
            case 0: // living room
                b.p(fl, .couch, r.minX + 24, ty(16, 60), 150, 60)
                b.p(fl, .tv, cx + 20, ty(10, 24), 60, 24)
                b.p(fl, .table, r.minX + 60, ty(110, 60), 100, 60)
                b.p(fl, .plant, r.maxX - 50, ty(16, 36), 36, 36)
            case 1: // bedroom
                b.p(fl, .bed, r.maxX - 120, ty(16, 150), 100, 150)
                b.p(fl, .shelf, r.minX + 16, ty(40, 130), 28, 130)
                b.p(fl, .crate, r.minX + 70, ty(16, 50), 50, 50)
            case 2: // kitchen
                b.p(fl, .counter, r.minX + 24, ty(12, 34), 220, 34)
                b.p(fl, .table, cx - 20, ty(120, 70), 120, 70)
                b.p(fl, .barrel, r.maxX - 50, ty(16, 36), 36, 36)
            case 3: // cluttered flat
                b.p(fl, .couch, r.maxX - 175, ty(16, 60), 150, 60)
                b.p(fl, .shelf, r.minX + 16, ty(30, 140), 28, 140)
                b.p(fl, .crate, cx - 30, ty(120, 60), 60, 60)
                b.p(fl, .crate, cx + 40, ty(150, 50), 50, 50)
            default: // storage
                b.p(fl, .crate, r.minX + 20, ty(16, 70), 90, 70)
                b.p(fl, .crate, r.minX + 130, ty(16, 60), 60, 60)
                b.p(fl, .shelf, r.maxX - 44, ty(30, 150), 28, 150)
                b.p(fl, .barrel, cx, ty(130, 36), 36, 36)
            }
        }
        let styleN1: [Int] = [0, 1, 2, 3, 1]
        let styleS1: [Int] = [4, 1, 9, 0, 4]
        let styleN2: [Int] = [1, 3, 0, 2, 3]
        let styleS2: [Int] = [2, 0, 1, 3, 0]
        for i in 0..<5 {
            furnish(1, rc(cols[i].0, northY, cols[i].1, northH), north: true, styleN1[i])
            if i != 2 { furnish(1, rc(cols[i].0, southY, cols[i].1, southH), north: false, styleS1[i]) }
            furnish(2, rc(cols[i].0, northY, cols[i].1, northH), north: true, styleN2[i])
            furnish(2, rc(cols[i].0, southY, cols[i].1, southH), north: false, styleS2[i])
        }
        // lobby: reception desk, mailboxes, benches, plants
        b.p(1, .counter, 1340, 1260, 200, 36); b.p(1, .shelf, 1675, 1000, 28, 160); b.p(1, .couch, 1330, 1180, 120, 56)
        b.p(1, .plant, 1660, 1320, 36, 36); b.p(1, .crate, 1600, 1290, 50, 50)
        // corridors: a few things dumped against the walls so the lanes are not clean
        b.p(1, .barrel, 1180, 790, 36, 36); b.p(1, .crate, 1750, 855, 40, 40); b.p(1, .crate, 2060, 790, 50, 40)
        b.p(2, .crate, 1180, 855, 40, 40); b.p(2, .barrel, 1760, 790, 36, 36); b.p(2, .crate, 2050, 850, 50, 40)
        // basement
        b.p(0, .barrel, 560, 520, 36, 36); b.p(0, .crate, 700, 640, 90, 70); b.p(0, .crate, 880, 480, 80, 70)
        b.p(0, .crate, 1150, 480, 80, 70); b.p(0, .shelf, 1380, 470, 28, 150)
        b.p(0, .crate, 1650, 500, 100, 70); b.p(0, .crate, 1900, 620, 90, 70); b.p(0, .shelf, 2040, 470, 28, 150)
        b.p(0, .car, 560, 1100, 110, 56); b.p(0, .car, 800, 1230, 110, 56); b.p(0, .crate, 1000, 1000, 60, 60)
        b.p(0, .crate, 1350, 1000, 80, 70); b.p(0, .barrel, 1560, 1100, 36, 36)
        b.p(0, .crate, 1900, 1000, 100, 70); b.p(0, .crate, 2150, 1150, 90, 70); b.p(0, .barrel, 2350, 1000, 36, 36); b.p(0, .shelf, 1850, 1260, 220, 28)
        b.p(0, .barrel, 1000, 790, 36, 36); b.p(0, .crate, 2000, 855, 40, 40)
        // street lot: parked cars, dumpsters, bins, trees
        b.p(1, .car, 170, 180, 56, 110); b.p(1, .car, 170, 1480, 56, 110)
        b.p(1, .car, 2770, 200, 56, 110); b.p(1, .car, 2770, 1450, 56, 110)
        b.p(1, .car, 700, 170, 110, 56); b.p(1, .car, 1500, 175, 110, 56); b.p(1, .car, 2200, 170, 110, 56)
        b.p(1, .car, 900, 1580, 110, 56); b.p(1, .car, 1900, 1580, 110, 56)
        b.p(1, .crate, 1100, 150, 100, 60); b.p(1, .crate, 2480, 1520, 100, 60)
        b.p(1, .barrel, 330, 700, 36, 36); b.p(1, .barrel, 2640, 1100, 36, 36); b.p(1, .barrel, 1700, 1500, 36, 36)
        b.p(1, .tree, 250, 1320, 80, 80); b.p(1, .tree, 2680, 300, 80, 80); b.p(1, .tree, 1300, 1560, 80, 80)

        // ---- spawns: attackers on the west lot, defenders on the east lot, free spawns around the whole block
        let atk = (0..<5).map { CGPoint(x: 275 + 3200, y: 600 + CGFloat($0) * 150) }
        let def = (0..<5).map { CGPoint(x: 2725 + 3200, y: 600 + CGFloat($0) * 150) }
        var sp: [CGPoint] = []
        for i in 0..<5 { sp.append(CGPoint(x: 700 + CGFloat(i) * 400, y: 330)) }
        for i in 0..<5 { sp.append(CGPoint(x: 700 + CGFloat(i) * 400, y: 1470)) }
        sp += atk.map { CGPoint(x: $0.x - 3200, y: $0.y) }
        sp += def.map { CGPoint(x: $0.x - 3200, y: $0.y) }
        let spawns = sp.map { CGPoint(x: $0.x + 3200, y: $0.y) }
        let packs = [CGPoint(x: 1500, y: 840), CGPoint(x: 1000, y: 1250), CGPoint(x: 2000, y: 600), CGPoint(x: 1500, y: 1450)].map { CGPoint(x: $0.x + 3200, y: $0.y) }

        var md = MapData(rooms: b.rooms, floorTiles: b.tiles, layout: layout, props: b.props, packPos: packs, stairs: stairs, stairLo: stairLo,
                         siteA: MapBuilder.R(1, rc(875, 450, 375, 275)), siteB: MapBuilder.R(1, rc(1775, 1000, 375, 325)),
                         atkSpawn: atk, defSpawn: def, hubZone: MapBuilder.R(1, rc(1325, 950, 375, 300)),
                         floorNames: ["BASEMENT", "STREET", "UPPER"], loot: [], roofs: b.roofs, spawns: spawns)
        md.siteNames = ["A · APT 102", "B · APT 107"]
        return md
    }
}
