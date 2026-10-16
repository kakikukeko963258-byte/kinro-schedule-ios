import SwiftUI

@main struct KinroApp: App {
    var body: some Scene { WindowGroup { ScheduleView() } }
}

@MainActor final class ScheduleStore: ObservableObject {
    @Published var films: [Film] = []
    @Published var loading = false
    @Published var error: String?
    @Published var updated: Date?
    private let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("schedule.json")
    struct Snapshot: Codable { let films: [Film]; let date: Date }
    init() {
        if let data = try? Data(contentsOf: cache), let saved = try? JSONDecoder().decode(Snapshot.self, from: data) { films = saved.films; updated = saved.date }
    }
    func refresh() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        do {
            films = try await ScheduleService.load(); updated = Date()
            if let data = try? JSONEncoder().encode(Snapshot(films: films, date: updated!)) { try? data.write(to: cache, options: .atomic) }
        } catch { self.error = "放送予定を取得できませんでした。通信環境を確認して再試行してください。保存済みの予定がある場合は表示しています。" }
    }
    var visible: [Film] {
        var calendar = Calendar(identifier: .iso8601); calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())!.start
        return films.filter { $0.date >= start }
    }
}

struct ScheduleView: View {
    @StateObject private var store = ScheduleStore()
    private let gold = Color(red: 0.96, green: 0.76, blue: 0.38)
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("FRIDAY MOVIE NIGHT", systemImage: "film.stack").font(.caption.weight(.bold)).tracking(3).foregroundStyle(gold)
                        Text("金曜の夜を、\nもっと楽しみに。").font(.largeTitle.bold())
                        Text("金曜ロードショーの放送予定").foregroundStyle(.secondary)
                    }.padding(.top, 12)
                    if let error = store.error {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(error, systemImage: "wifi.exclamationmark").font(.callout)
                            Button("再試行") { Task { await store.refresh() } }
                        }.padding().background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                    if store.loading { ProgressView("公式サイトから取得中…").frame(maxWidth: .infinity) }
                    ForEach(0..<3) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            Text(["今週", "来週", "その先の放送予定"][group]).font(.title2.bold()).foregroundStyle(gold)
                            let films = store.visible.filter { ScheduleParser.group($0.date) == group }
                            if films.isEmpty && !store.loading {
                                Text(store.error == nil ? "公式サイトに放送予定が掲載されていません。" : "表示できる予定がありません。")
                                    .font(.callout).foregroundStyle(.secondary).padding(.vertical, 12)
                            }
                            ForEach(films) { film in NavigationLink { FilmDetail(film: film) } label: { FilmCard(film: film) }.buttonStyle(.plain) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        if let date = store.updated { Text("取得日時：\(date.formatted(date: .abbreviated, time: .shortened))") }
                        Text("非公式アプリ · 放送内容は変更される場合があります。画像・作品情報の権利は各権利者に帰属します。")
                        Link("出典：金曜ロードシネマクラブ", destination: URL(string: "https://kinro.ntv.co.jp/lineup")!)
                    }.font(.caption).foregroundStyle(.secondary)
                }.padding(20)
            }
            .background(Color(red: 0.045, green: 0.065, blue: 0.11))
            .navigationTitle("金ロー予定").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") }.disabled(store.loading) }
            .refreshable { await store.refresh() }
            .task { await store.refresh() }
        }.tint(gold).preferredColorScheme(.dark)
    }
}

struct FilmImage: View {
    let film: Film
    var body: some View {
        AsyncImage(url: film.image) { phase in
            if let image = phase.image { image.resizable().scaledToFit() }
            else { Rectangle().fill(.white.opacity(0.07)).aspectRatio(16/9, contentMode: .fit).overlay { Image(systemName: "film").font(.largeTitle).foregroundStyle(.secondary) } }
        }.frame(maxWidth: .infinity).accessibilityLabel(film.title + "の作品画像")
    }
}
struct FilmCard: View {
    let film: Film
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FilmImage(film: film)
            VStack(alignment: .leading, spacing: 9) {
                Text(film.time.isEmpty ? film.date.formatted(.dateTime.month().day().weekday().locale(Locale(identifier: "ja_JP"))) : film.time).font(.caption.weight(.semibold)).foregroundStyle(.yellow)
                Text(film.title).font(.title3.bold())
                Text(film.intro.isEmpty ? "作品の詳細を見る" : film.intro).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                Label("作品の詳細", systemImage: "arrow.right").font(.caption.weight(.bold)).padding(.top, 4)
            }.padding(16)
        }.background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20)).clipShape(RoundedRectangle(cornerRadius: 20))
    }
}
struct FilmDetail: View {
    let film: Film
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                FilmImage(film: film).clipShape(RoundedRectangle(cornerRadius: 16))
                Text(film.time).font(.subheadline).foregroundStyle(.yellow)
                Text(film.title).font(.largeTitle.bold())
                if film.detailError { Text("説明文を取得できませんでした。公式サイトでご確認ください。").foregroundStyle(.secondary) }
                if !film.intro.isEmpty { Text("みどころ").font(.title2.bold()); Text(film.intro).lineSpacing(7).textSelection(.enabled) }
                if !film.story.isEmpty { Text("ストーリー").font(.title2.bold()); Text(film.story).lineSpacing(7).textSelection(.enabled) }
                Link(destination: film.url) { Label("公式サイトで見る", systemImage: "arrow.up.right.square").frame(maxWidth: .infinity).padding() }.buttonStyle(.bordered)
                Text("出典：日本テレビ 金曜ロードシネマクラブ\n画像・作品情報 © 各権利者").font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.navigationBarTitleDisplayMode(.inline)
    }
}
