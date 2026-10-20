import SwiftUI

/// BLOCK 9 ANNEX (kind 7): compact CQC house on a small walled lot. Ten rooms a floor, two or three doors on every room,
/// no sight line longer than a room. One straight staircase (x 750-850, y 300-525): foot opens into the break room at the south,
/// head arrives on the upper landing through a gap at the north. Same footprint on both floors, so the climb is continuous.
/// Generated from the shared plan in annex_data.py, the same plan the Blender bake uses.
enum TAnnex {
    static let W: CGFloat = 1000
    static let H: CGFloat = 800
    static let shared: MapData = build()

    private static func build() -> MapData {
        let b = MapBuilder(cols: 40, rows: 32)
        let rc = b.rc

        // ---- lot
        let arena = rc(0, 0, W, H)
        b.setR(1, arena, true)
        b.tiles.insert(TRoom(name: "Yard", r: MapBuilder.R(1, arena), mat: 8, fl: 1), at: 0)
        b.rooms.append(TRoom(name: "West Yard", r: MapBuilder.R(1, rc(0, 0, 125, H)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "East Yard", r: MapBuilder.R(1, rc(875, 0, 125, H)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "North Yard", r: MapBuilder.R(1, rc(125, 0, 750, 100)), mat: 8, fl: 1))
        b.rooms.append(TRoom(name: "South Yard", r: MapBuilder.R(1, rc(125, 700, 750, 100)), mat: 8, fl: 1))

        // ---- shell
        let outer = rc(125, 100, 750, 600)
        b.setR(1, outer, false)
        b.setR(2, outer, false)
        b.outers.append(outer)

        func door(_ fl: Int, _ x: CGFloat, _ y: CGFloat) { b.doors.append(b.dh(fl, x, y, 100)) }
        func doorV(_ fl: Int, _ x: CGFloat, _ y: CGFloat) { b.doors.append(b.dv(fl, x, y, 100)) }

        // ---- ground floor
        let armory1 = rc(150, 125, 225, 150)
        let server1 = rc(400, 125, 200, 150)
        let kitchen1 = rc(625, 125, 225, 150)
        let living1 = rc(150, 300, 225, 225)
        let lobby1 = rc(400, 300, 200, 225)
        let corridor1 = rc(625, 300, 100, 225)
        let stairs1 = rc(750, 300, 100, 225)
        let storage1 = rc(150, 550, 225, 125)
        let garage1 = rc(400, 550, 200, 125)
        let breakroom1 = rc(625, 550, 225, 125)

        b.area(1, "Armory", armory1, 4)
        b.area(1, "Server", server1, 5)
        b.area(1, "Kitchen", kitchen1, 3)
        b.area(1, "Living", living1, 4)
        b.area(1, "Lobby", lobby1, 5)
        b.area(1, "Corridor", corridor1, 5)
        b.area(1, "Stairs", stairs1, 1)
        b.area(1, "Storage", storage1, 5)
        b.area(1, "Garage", garage1, 5)
        b.area(1, "Break Room", breakroom1, 3)
        b.gap(1, rc(375, 150, 25, 100), 5); doorV(1, 375, 150)
        b.gap(1, rc(600, 150, 25, 100), 5); doorV(1, 600, 150)
        b.gap(1, rc(225, 275, 100, 25), 5); door(1, 225, 275)
        b.gap(1, rc(450, 275, 100, 25), 5); door(1, 450, 275)
        b.gap(1, rc(625, 275, 100, 25), 5); door(1, 625, 275)
        b.gap(1, rc(375, 375, 25, 100), 5); doorV(1, 375, 375)
        b.gap(1, rc(600, 375, 25, 100), 5); doorV(1, 600, 375)
        b.gap(1, rc(725, 375, 25, 100), 5)
        b.gap(1, rc(225, 525, 100, 25), 5); door(1, 225, 525)
        b.gap(1, rc(450, 525, 100, 25), 5); door(1, 450, 525)
        b.gap(1, rc(625, 525, 100, 25), 5); door(1, 625, 525)
        b.gap(1, rc(750, 525, 100, 25), 5)
        b.gap(1, rc(375, 575, 25, 100), 5); doorV(1, 375, 575)
        b.gap(1, rc(600, 575, 25, 100), 5); doorV(1, 600, 575)
        b.gap(1, rc(125, 375, 25, 100), 5); doorV(1, 125, 375)
        b.gap(1, rc(850, 575, 25, 100), 5); doorV(1, 850, 575)
        b.gap(1, rc(450, 100, 100, 25), 5); door(1, 450, 100)
        b.gap(1, rc(450, 675, 100, 25), 5); door(1, 450, 675)

        // ---- upper floor
        let bathroom2 = rc(150, 125, 225, 150)
        let library2 = rc(400, 125, 200, 150)
        let landing2 = rc(625, 125, 225, 150)
        let bedroom2 = rc(150, 300, 225, 225)
        let study2 = rc(400, 300, 200, 225)
        let upperhall2 = rc(625, 300, 100, 225)
        let stairhead2 = rc(750, 300, 100, 225)
        let closet2 = rc(150, 550, 225, 125)
        let office2 = rc(400, 550, 200, 125)
        let guestroom2 = rc(625, 550, 225, 125)

        b.area(2, "Bathroom", bathroom2, 5)
        b.area(2, "Library", library2, 3)
        b.area(2, "Landing", landing2, 5)
        b.area(2, "Bedroom", bedroom2, 4)
        b.area(2, "Study", study2, 3)
        b.area(2, "Upper Hall", upperhall2, 5)
        b.area(2, "Stair Head", stairhead2, 1)
        b.area(2, "Closet", closet2, 4)
        b.area(2, "Office", office2, 4)
        b.area(2, "Guest Room", guestroom2, 3)
        b.gap(2, rc(375, 150, 25, 100), 5); doorV(2, 375, 150)
        b.gap(2, rc(600, 150, 25, 100), 5); doorV(2, 600, 150)
        b.gap(2, rc(225, 275, 100, 25), 5); door(2, 225, 275)
        b.gap(2, rc(450, 275, 100, 25), 5); door(2, 450, 275)
        b.gap(2, rc(625, 275, 100, 25), 5); door(2, 625, 275)
        b.gap(2, rc(750, 275, 100, 25), 5)
        b.gap(2, rc(375, 375, 25, 100), 5); doorV(2, 375, 375)
        b.gap(2, rc(600, 375, 25, 100), 5); doorV(2, 600, 375)
        b.gap(2, rc(725, 375, 25, 100), 5)
        b.gap(2, rc(225, 525, 100, 25), 5); door(2, 225, 525)
        b.gap(2, rc(450, 525, 100, 25), 5); door(2, 450, 525)
        b.gap(2, rc(625, 525, 100, 25), 5); door(2, 625, 525)
        b.gap(2, rc(375, 575, 25, 100), 5); doorV(2, 375, 575)
        b.gap(2, rc(600, 575, 25, 100), 5); doorV(2, 600, 575)

        let stair = rc(750, 300, 100, 225)
        let stairs: [CGRect] = [stair]
        let stairLo: [Int] = [1]
        let layout = b.layout([.concrete, .brick, .concrete])

        // ---- furniture
        b.p(1, .counter, 645, 137, 200, 30)
        b.p(1, .table, 700, 200, 60, 50)
        b.p(1, .shelf, 162, 137, 28, 110)
        b.p(1, .crate, 260, 135, 50, 50)
        b.p(1, .crate, 250, 215, 40, 40)
        b.p(1, .table, 470, 165, 60, 60)
        b.p(1, .barrel, 560, 145, 32, 32)
        b.p(1, .couch, 170, 345, 150, 56)
        b.p(1, .tv, 160, 470, 56, 24)
        b.p(1, .table, 270, 420, 70, 60)
        b.p(1, .plant, 330, 490, 30, 30)
        b.p(1, .table, 470, 380, 60, 60)
        b.p(1, .barrel, 420, 320, 32, 32)
        b.p(1, .crate, 560, 480, 40, 40)
        b.p(1, .crate, 635, 335, 40, 40)
        b.p(1, .crate, 165, 565, 50, 40)
        b.p(1, .barrel, 320, 630, 32, 32)
        b.p(1, .barrel, 415, 570, 32, 32)
        b.p(1, .barrel, 555, 640, 32, 32)
        b.p(1, .table, 700, 590, 70, 60)
        b.p(1, .couch, 640, 640, 120, 30)
        b.p(2, .table, 170, 140, 100, 50)
        b.p(2, .shelf, 350, 140, 22, 110)
        b.p(2, .shelf, 410, 137, 150, 24)
        b.p(2, .table, 470, 190, 60, 50)
        b.p(2, .bed, 165, 345, 100, 130)
        b.p(2, .shelf, 348, 310, 24, 60)
        b.p(2, .table, 270, 470, 60, 40)
        b.p(2, .table, 470, 380, 60, 60)
        b.p(2, .crate, 430, 485, 40, 40)
        b.p(2, .shelf, 405, 310, 22, 60)
        b.p(2, .crate, 640, 335, 40, 40)
        b.p(2, .shelf, 160, 645, 200, 24)
        b.p(2, .crate, 170, 600, 40, 36)
        b.p(2, .table, 470, 590, 80, 50)
        b.p(2, .bed, 740, 600, 100, 60)
        b.p(2, .crate, 640, 640, 40, 30)
        b.p(2, .couch, 650, 140, 150, 50)
        b.p(2, .plant, 820, 240, 30, 30)
        // yard
        b.p(1, .car, 40, 150, 56, 110)
        b.p(1, .car, 900, 600, 56, 110)
        b.p(1, .crate, 300, 20, 100, 60)
        b.p(1, .crate, 620, 720, 100, 60)
        b.p(1, .barrel, 60, 420, 36, 36)
        b.p(1, .barrel, 920, 400, 36, 36)
        b.p(1, .tree, 40, 680, 80, 80)
        b.p(1, .tree, 900, 40, 80, 80)

        // ---- spawns (floor 1 plan x is offset by 3200)
        let atk: [CGPoint] = [CGPoint(x: 3260, y: 200), CGPoint(x: 3260, y: 300), CGPoint(x: 3260, y: 400), CGPoint(x: 3260, y: 500), CGPoint(x: 3260, y: 600)]
        let def: [CGPoint] = [CGPoint(x: 4140, y: 200), CGPoint(x: 4140, y: 300), CGPoint(x: 4140, y: 400), CGPoint(x: 4140, y: 500), CGPoint(x: 4140, y: 600)]
        var sp: [CGPoint] = [CGPoint(x: 3462, y: 200), CGPoint(x: 3700, y: 200), CGPoint(x: 3937, y: 200), CGPoint(x: 3462, y: 412), CGPoint(x: 3700, y: 412), CGPoint(x: 3875, y: 412), CGPoint(x: 3462, y: 612), CGPoint(x: 3700, y: 612), CGPoint(x: 3937, y: 612)]
        sp += atk
        sp += def
        let packs: [CGPoint] = [CGPoint(x: 3937, y: 230), CGPoint(x: 3700, y: 412), CGPoint(x: 3462, y: 612), CGPoint(x: 3937, y: 612)]

        var md = MapData(rooms: b.rooms, floorTiles: b.tiles, layout: layout, props: b.props, packPos: packs, stairs: stairs, stairLo: stairLo,
                         siteA: MapBuilder.R(1, kitchen1), siteB: MapBuilder.R(2, study2),
                         atkSpawn: atk, defSpawn: def, hubZone: MapBuilder.R(1, lobby1),
                         floorNames: ["", "GROUND", "UPPER"], loot: [], roofs: b.roofs, spawns: sp)
        md.siteNames = ["A · KITCHEN", "B · STUDY"]
        return md
    }
}
