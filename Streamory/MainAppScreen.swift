import SwiftUI

struct MainAppScreen: View {
    @ObservedObject var viewModel: StreamoryViewModel
    @AppStorage("streamory-show-mate-tab") private var showMateTab = true
    @State private var searchText = ""
    @State private var selectedKind: MediaKind = .movie
    @State private var selectedStatus: WatchStatus?

    private var libraryVersion: String {
        viewModel.library
            .map { "\($0.id.uuidString)-\($0.status.rawValue)-\($0.updatedAt?.timeIntervalSince1970 ?? 0)" }
            .joined(separator: "|")
    }

    private var filteredItems: [MediaItem] {
        viewModel.library
            .filter { item in
                let matchesSearch = searchText.isEmpty || item.title.localizedStandardContains(searchText)
                let matchesKind = item.kind == selectedKind
                let matchesStatus = selectedStatus == nil || item.status == selectedStatus
                let isVisibleStatus = selectedKind == .movie ? item.status != .watched && item.status != .stopped : item.status != .stopped
                let isReleasedMovie = selectedKind != .movie || item.isReleasedForWatchlist
                return isVisibleStatus && isReleasedMovie && matchesSearch && matchesKind && matchesStatus
            }
            .sorted(by: { first, second in
                if selectedKind == .movie {
                    let firstYear = first.releaseSortYear ?? Int.min
                    let secondYear = second.releaseSortYear ?? Int.min
                    if firstYear != secondYear { return firstYear > secondYear }
                }

                return first.title.localizedStandardCompare(second.title) == .orderedAscending
            })
    }

    var body: some View {
        TabView {
            NavigationStack {
                LibraryScreen(
                    items: filteredItems,
                    viewModel: viewModel,
                    searchText: $searchText,
                    selectedKind: $selectedKind,
                    selectedStatus: $selectedStatus,
                    isLoading: viewModel.isLoading,
                    onStatusChange: { item, status in Task { await viewModel.updateStatus(item, status) } },
                    onDelete: { item in Task { await viewModel.delete(item) } },
                    onRefresh: { Task { await viewModel.refreshAll() } }
                )
            }
            .tabItem {
                Image(systemName: "rectangle.stack.fill")
                Text("À voir")
            }

            NavigationStack {
                UpcomingScreen(viewModel: viewModel)
            }
            .tabItem { Label("À venir", systemImage: "calendar") }
            .task(id: libraryVersion) {
                await viewModel.loadUpcomingEpisodes()
            }

            NavigationStack {
                SearchScreen(viewModel: viewModel)
            }
            .tabItem { Label("Explorer", systemImage: "magnifyingglass") }

            if showMateTab {
                NavigationStack {
                    MateScreen(viewModel: viewModel)
                }
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Mate")
                }
            }

            NavigationStack {
                ProfileScreen(viewModel: viewModel, showMateTab: $showMateTab)
            }
            .tabItem { Label("Profil", systemImage: "person.crop.circle") }
        }
        .tint(.blue)
        .background(AppTheme.background.ignoresSafeArea())
    }
}

struct LibraryScreen: View {
    let items: [MediaItem]
    @ObservedObject var viewModel: StreamoryViewModel
    @Binding var searchText: String
    @Binding var selectedKind: MediaKind
    @Binding var selectedStatus: WatchStatus?
    let isLoading: Bool
    let onStatusChange: (MediaItem, WatchStatus) -> Void
    let onDelete: (MediaItem) -> Void
    let onRefresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Type", selection: $selectedKind) {
                    Text("Films").tag(MediaKind.movie)
                    Text("Séries").tag(MediaKind.series)
                }
                .pickerStyle(.segmented)

                if isLoading && items.isEmpty {
                    ProgressView("Chargement...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(20)
                } else if items.isEmpty {
                    EmptyStateView(
                        symbol: selectedKind == .movie ? "film" : "tv",
                        title: selectedKind == .movie ? "Aucun film à voir" : "Aucune série",
                        subtitle: selectedKind == .movie ? "Les films ajoutés mais pas encore vus apparaîtront ici." : "Les séries ajoutées apparaîtront ici."
                    )
                } else if selectedKind == .movie {
                    MovieWatchlistGrid(
                        items: items,
                        viewModel: viewModel,
                        onStatusChange: onStatusChange,
                        onDelete: onDelete
                    )
                } else {
                    MediaGrid(items: items, viewModel: viewModel, onStatusChange: onStatusChange, onDelete: onDelete)
                }
            }
            .padding(18)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("À voir")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            onRefresh()
        }
    }
}

private struct MovieWatchlistGrid: View {
    let items: [MediaItem]
    @ObservedObject var viewModel: StreamoryViewModel
    let onStatusChange: (MediaItem, WatchStatus) -> Void
    let onDelete: (MediaItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items) { item in
                NavigationLink {
                    MediaDetailView(item: item, viewModel: viewModel, onStatusChange: onStatusChange, onDelete: onDelete)
                } label: {
                    MovieWatchlistPoster(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MovieWatchlistPoster: View {
    let item: MediaItem

    var body: some View {
        PosterImage(imageURL: item.imageURL, title: item.title, kind: item.kind)
            .aspectRatio(2 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
    }
}

struct UpcomingScreen: View {
    @ObservedObject var viewModel: StreamoryViewModel
    @State private var selectedKind: MediaKind = .series

    private var upcomingMovies: [MediaItem] {
        let today = Calendar.current.startOfDay(for: Date())
        return viewModel.library
            .filter { item in
                item.kind == .movie
                    && item.status != .watched
                    && item.status != .stopped
                    && (item.releaseDate ?? .distantPast) > today
            }
            .sorted {
                let firstDate = $0.releaseDate ?? .distantFuture
                let secondDate = $1.releaseDate ?? .distantFuture
                if firstDate == secondDate { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
                return firstDate < secondDate
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Type", selection: $selectedKind) {
                    Text("Films").tag(MediaKind.movie)
                    Text("Séries").tag(MediaKind.series)
                }
                .pickerStyle(.segmented)

                if selectedKind == .series {
                    upcomingSeriesContent
                } else {
                    upcomingMoviesContent
                }
            }
            .padding(18)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("À venir")
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await viewModel.loadUpcomingEpisodes()
        }
    }

    @ViewBuilder
    private var upcomingSeriesContent: some View {
        if viewModel.isLoadingUpcomingEpisodes && viewModel.upcomingEpisodes.isEmpty {
            ProgressView("Chargement des épisodes...")
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(20)
        } else if viewModel.upcomingEpisodes.isEmpty {
            EmptyStateView(
                symbol: "calendar",
                title: "Aucune série à venir",
                subtitle: "Les prochains épisodes des séries suivies apparaîtront ici."
            )
        } else {
            ForEach(viewModel.upcomingEpisodes) { item in
                UpcomingEpisodeRow(item: item)
            }
        }
    }

    @ViewBuilder
    private var upcomingMoviesContent: some View {
        if upcomingMovies.isEmpty {
            EmptyStateView(
                symbol: "film",
                title: "Aucun film à venir",
                subtitle: "Les films ajoutés avant leur sortie apparaîtront ici."
            )
        } else {
            ForEach(upcomingMovies) { item in
                NavigationLink {
                    MediaDetailView(
                        item: item,
                        viewModel: viewModel,
                        onStatusChange: { item, status in Task { await viewModel.updateStatus(item, status) } },
                        onDelete: { item in Task { await viewModel.delete(item) } }
                    )
                } label: {
                    UpcomingMovieRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct UpcomingEpisodeRow: View {
    let item: UpcomingEpisode

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(imageURL: item.series.imageURL, title: item.series.title, kind: item.series.kind)
                .frame(width: 52, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.series.title)
                    .font(.headline)
                    .lineLimit(2)

                Text("S\(item.episode.seasonNumber) \(item.episode.displayNumber) · \(item.episode.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(item.episode.formattedAirDate)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct UpcomingMovieRow: View {
    let item: MediaItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PosterImage(imageURL: item.imageURL, title: item.title, kind: item.kind)
                .frame(width: 52, height: 78)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(item.year ?? "Film")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let releaseDate = item.releaseDate {
                    Text(releaseDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension MediaItem {
    var releaseSortYear: Int? {
        guard let year else { return nil }
        return Int(String(year.prefix(4).filter(\.isNumber)))
    }

    var isReleasedForWatchlist: Bool {
        guard let releaseSortYear else { return false }

        if let releaseDate {
            return releaseDate <= Date()
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        return releaseSortYear <= currentYear
    }

    var releaseDate: Date? {
        guard let year else { return nil }
        let components = year.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(10)
            .split(separator: "-")
        guard components.count == 3,
              let year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]) else {
            return nil
        }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day))
    }
}
