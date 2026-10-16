import Foundation

struct Film: Identifiable, Codable {
    var id: String
    var title: String
    var image: URL?
    var time: String
    var intro: String
    var story: String
    var detailError: Bool = false
    var url: URL { URL(string: "https://kinro.ntv.co.jp/lineup/\(id)")! }
    var date: Date { Self.formatter.date(from: id) ?? .distantPast }
    static var formatter: DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Tokyo"); f.dateFormat = "yyyyMMdd"; return f
    }
}

enum ScheduleParser {
    static func matches(_ pattern: String, _ html: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).map { m in
            (0..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) }
        }
    }
    static func clean(_ html: String) -> String {
        var s = html.replacingOccurrences(of: #"<br\s*/?>|</p>"#, with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        for (a,b) in [("&nbsp;"," "),("&quot;","\""),("&#039;","'"),("&lt;","<"),("&gt;",">"),("&amp;","&")] { s = s.replacingOccurrences(of: a, with: b) }
        for m in matches(#"&#(x[0-9a-f]+|[0-9]+);"#, s) {
            let hex = m[1].hasPrefix("x")
            if let n = UInt32(hex ? String(m[1].dropFirst()) : m[1], radix: hex ? 16 : 10), let c = UnicodeScalar(n) { s = s.replacingOccurrences(of: m[0], with: String(c)) }
        }
        return s.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    static func lineup(_ html: String) -> [Film] {
        let upcoming = html.components(separatedBy: "過去の放送ラインナップ")[0]
        var seen = Set<String>()
        return matches(#"<a\s+href=['"]/lineup/(\d{8})['"][^>]*>\s*<img\s+src=['"]([^'"]+)['"]\s+alt=['"]([^'"]*)['"]"#, upcoming).compactMap { m in
            guard seen.insert(m[1]).inserted else { return nil }
            return Film(id: m[1], title: clean(m[3]), image: URL(string: m[2]), time: "", intro: "", story: "")
        }.sorted { $0.id < $1.id }
    }
    static func detail(_ html: String, film: Film) -> Film {
        var f = film
        if let title = matches(#"<h1\s+class=['"]title['"][^>]*>(.*?)</h1>"#, html).first { f.title = clean(title[1]) }
        f.time = matches(#"<div\s+class=['"]date['"][^>]*>(.*?)</div>"#, html).first.map { clean($0[1]) } ?? ""
        func section(_ id: String) -> String {
            guard let s = matches("<section\\s+id=['\"]\(id)['\"][^>]*>(.*?)</section>", html).first else { return "" }
            let body = s[1].replacingOccurrences(of: "<h2[^>]*>.*?</h2>", with: "", options: .regularExpression)
            return clean(body)
        }
        f.intro = section("intro"); f.story = section("story")
        f.detailError = f.intro.isEmpty && f.story.isEmpty
        return f
    }
    static func group(_ date: Date, now: Date = Date()) -> Int {
        var c = Calendar(identifier: .iso8601); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        guard let start = c.dateInterval(of: .weekOfYear, for: now)?.start else { return 2 }
        if date < c.date(byAdding: .day, value: 7, to: start)! { return 0 }
        return date < c.date(byAdding: .day, value: 14, to: start)! ? 1 : 2
    }
}

enum ScheduleService {
    static func fetch(_ url: URL) async throws -> String {
        var req = URLRequest(url: url); req.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, let html = String(data: data, encoding: .utf8) else { throw URLError(.badServerResponse) }
        return html
    }
    static func load() async throws -> [Film] {
        let html = try await fetch(URL(string: "https://kinro.ntv.co.jp/lineup")!)
        let films = ScheduleParser.lineup(html)
        guard !films.isEmpty else { throw URLError(.cannotParseResponse) }
        var result: [Film] = []
        // Keep requests modest; detail failures must not hide the remaining schedule.
        for film in films {
            do { result.append(ScheduleParser.detail(try await fetch(film.url), film: film)) }
            catch { var f = film; f.detailError = true; result.append(f) }
        }
        return result
    }
}
