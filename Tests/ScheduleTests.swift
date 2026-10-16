import XCTest
@testable import KinroCore

final class ScheduleTests: XCTestCase {
    func fixture(_ name: String) throws -> String {
        try String(contentsOf: Bundle.module.url(forResource: name, withExtension: "html", subdirectory: "Fixtures")!, encoding: .utf8)
    }
    func testActualOfficialHTML() throws {
        let films = ScheduleParser.lineup(try fixture("lineup"))
        XCTAssertEqual(films.map(\.id), ["20261016", "20261023", "20261030", "20261106", "20261113"])
        XCTAssertEqual(films.first?.title, "インサイド・ヘッド2")
        XCTAssertNotNil(films.first?.image)
        let detail = ScheduleParser.detail(try fixture("detail"), film: films[0])
        XCTAssertTrue(detail.time.contains("よる9時"))
        XCTAssertTrue(detail.intro.contains("2024年"))
        XCTAssertTrue(detail.story.contains("ライリー"))
        XCTAssertFalse(detail.intro.contains("<"))
        XCTAssertFalse(detail.detailError)
    }
    func testWeekBoundariesAndYearRollover() {
        let now = Film.formatter.date(from: "20261231")!
        XCTAssertEqual(ScheduleParser.group(Film.formatter.date(from: "20270101")!, now: now), 0)
        XCTAssertEqual(ScheduleParser.group(Film.formatter.date(from: "20270108")!, now: now), 1)
        XCTAssertEqual(ScheduleParser.group(Film.formatter.date(from: "20270115")!, now: now), 2)
    }
    func testMissingSectionsAndEntities() {
        let film = Film(id: "20261016", title: "test", time: "", intro: "", story: "")
        XCTAssertTrue(ScheduleParser.detail("<html></html>", film: film).detailError)
        XCTAssertEqual(ScheduleParser.clean("A&amp;B<br>&#x6620;&#30011;"), "A&B\n映画")
        XCTAssertTrue(ScheduleParser.lineup("<html></html>").isEmpty)
    }
}
