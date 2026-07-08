import SwiftUI
import UIKit

struct SearchAndFiltersView: View {
    @Binding var searchText: String
    @Binding var selectedKind: MediaKind
    @Binding var selectedStatus: WatchStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Filtrer la bibliothèque", text: $searchText)
            }
            .frame(height: 48)
            .padding(.horizontal, 14)
            .background(AppTheme.field)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Picker("Type", selection: $selectedKind) {
                Text("Films").tag(MediaKind.movie)
                Text("Séries").tag(MediaKind.series)
            }
            .pickerStyle(.segmented)

            Picker("Statut", selection: $selectedStatus) {
                Text("Tout").tag(WatchStatus?.none)
                ForEach(WatchStatus.allCases.filter { $0 != .stopped }) { status in Text(status.shortLabel).tag(Optional(status)) }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MediaGrid: View {
    let items: [MediaItem]
    @ObservedObject var viewModel: StreamoryViewModel
    let onStatusChange: (MediaItem, WatchStatus) -> Void
    let onDelete: (MediaItem) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 14)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items) { item in
                NavigationLink {
                    MediaDetailView(item: item, viewModel: viewModel, onStatusChange: onStatusChange, onDelete: onDelete)
                } label: {
                    MediaPosterCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SearchResultRow: View {
    let result: TVDBSearchResult
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            PosterImage(imageURL: result.imageURL, title: result.title, kind: result.kind)
                .frame(width: 68, height: 102)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(result.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(result.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let overview = result.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Ajouter")
        }
        .padding(12)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MediaPosterCard: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PosterImage(imageURL: item.imageURL, title: item.title, kind: item.kind)
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    Image(systemName: item.status.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(item.status.color.opacity(0.85))
                        .clipShape(Circle())
                        .padding(8)
                }

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
            Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct MediaDetailView: View {
    let item: MediaItem
    @ObservedObject var viewModel: StreamoryViewModel
    let onStatusChange: (MediaItem, WatchStatus) -> Void
    let onDelete: (MediaItem) -> Void

    var body: some View {
        if item.kind == .series {
            SeriesDetailView(item: item, viewModel: viewModel, onStatusChange: onStatusChange, onDelete: onDelete)
        } else {
            MovieDetailView(item: item, viewModel: viewModel, onStatusChange: onStatusChange, onDelete: onDelete)
        }
    }
}

struct MovieDetailView: View {
    let item: MediaItem
    @ObservedObject var viewModel: StreamoryViewModel
    let onStatusChange: (MediaItem, WatchStatus) -> Void
    let onDelete: (MediaItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showsNavigationTitle = false
    @State private var isOverviewExpanded = false
    @State private var selectedWatchedMovie = false
    @AppStorage("streamory-selected-mate-friend-id") private var selectedMateFriendIDString = ""
    @State private var canAddWithSelectedMate = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                movieHeader

                movieStatusBlock

                CastCarouselView(castMembers: [])
            }
            .padding(18)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 24
        } action: { _, isScrolled in
            showsNavigationTitle = isScrolled
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(showsNavigationTitle ? item.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                }
                .accessibilityLabel("Retour")
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    movieSharedMateActionButton
                    movieListActionButton
                    movieMenu
                }
            }
        }
        .confirmationDialog("Modifier le film", isPresented: $selectedWatchedMovie) {
            Button("Revu") {
                onStatusChange(item, .watched)
            }
            Button("Non vu", role: .destructive) {
                onStatusChange(item, .watchlist)
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(String(format: "%@ est déjà marqué comme vu.".streamoryLocalized, item.title))
        }
        .task(id: selectedMateFriendIDString) {
            await loadMovieMatePermission()
        }
    }

    private var movieHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.title)
                .font(.largeTitle.weight(.bold))
                .lineLimit(3)

            HStack(alignment: .top, spacing: 16) {
                PosterImage(imageURL: item.imageURL, title: item.title, kind: item.kind)
                    .frame(width: 128, height: 192)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    if let year = item.year, !year.isEmpty {
                        Text(year)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let genreRuntimeText {
                        Text(genreRuntimeText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let overview = item.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(overview)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(isOverviewExpanded ? nil : 6)
                            Button(isOverviewExpanded ? "Réduire" : "Développer") {
                                isOverviewExpanded.toggle()
                            }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var movieStatusBlock: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "film")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("Film".streamoryLocalized)
                    .font(.headline)
                Spacer()
                Button(action: handleMovieStatusTap) {
                    Text(movieStatusLabel)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(item.status == .watched ? Color.green : AppTheme.field)
                        .foregroundStyle(item.status == .watched ? .black : .secondary)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
        }
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }


    @ViewBuilder
    private var movieSharedMateActionButton: some View {
        if let selectedMateFriend, canAddWithSelectedMate {
            Button {
                Task {
                    print("🧪 Mutual movie add selectedMateFriend.id=\(selectedMateFriend.id) selectedMateFriend.userID=\(selectedMateFriend.userID)")
                    await viewModel.addToMutualWatchlist(item, friendID: selectedMateFriend.userID)
                }
            } label: {
                Image(systemName: "person.2.badge.plus")
                    .font(.headline.weight(.semibold))
            }
            .accessibilityLabel("Ajouter aux deux listes")
        }
    }

    private var selectedMateFriend: StreamoryFriend? {
        guard let selectedMateFriendID = UUID(uuidString: selectedMateFriendIDString) else { return nil }
        return viewModel.friends.first { $0.id == selectedMateFriendID }
    }

    @ViewBuilder
    private var movieListActionButton: some View {
        if item.status == .watchlist {
            Button(role: .destructive) {
                onDelete(item)
                dismiss()
            } label: {
                Image(systemName: "trash")
                    .font(.headline.weight(.semibold))
            }
            .accessibilityLabel("Supprimer de la liste")
        }
    }

    private var movieMenu: some View {
        Menu {
            Button {
            } label: {
                Label("Personnaliser", systemImage: "photo")
            }
            .disabled(true)

            Button {
                if let tvdbMovieURL {
                    openURL(tvdbMovieURL)
                }
            } label: {
                Label("Corriger sur TheTVDB", systemImage: "pencil")
            }
            .disabled(tvdbMovieURL == nil)
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline.weight(.semibold))
        }
        .accessibilityLabel("Options du film")
    }

    private var tvdbMovieURL: URL? {
        let tvdbID = item.tvdbID.onlyDigitsOrSelf
        guard !tvdbID.isEmpty else { return nil }
        return URL(string: "https://www.thetvdb.com/dereferrer/movies/\(tvdbID)")
    }

    private var genreRuntimeText: String? {
        let genres = item.localizedGenres.prefix(3).joined(separator: ", ")
        let runtime = item.episodeRuntime.map { $0 > 0 ? "\($0) min" : "" } ?? ""
        let text = [genres, runtime].filter { !$0.isEmpty }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }

    private var movieStatusLabel: String {
        switch item.status {
        case .watched:
            return "Vu".streamoryLocalized
        default:
            return "À voir".streamoryLocalized
        }
    }

    private func handleMovieStatusTap() {
        if item.status == .watched {
            selectedWatchedMovie = true
        } else {
            onStatusChange(item, .watched)
        }
    }
    private func loadMovieMatePermission() async {
        guard let selectedMateFriend else {
            canAddWithSelectedMate = false
            return
        }

        let isAllowed = await viewModel.mutualFriendCanAddPermission(friendID: selectedMateFriend.id)
        await MainActor.run {
            canAddWithSelectedMate = isAllowed
        }
    }
}

struct SeriesDetailView: View {
    let item: MediaItem
    @ObservedObject var viewModel: StreamoryViewModel
    let onStatusChange: (MediaItem, WatchStatus) -> Void
    let onDelete: (MediaItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var episodes: [SeriesEpisode] = []
    @State private var watchStates: [String: EpisodeWatchState] = [:]
    @State private var expandedSeasons: Set<Int> = []
    @State private var isOverviewExpanded = false
    @State private var selectedWatchedEpisode: SeriesEpisode?
    @State private var errorMessage: String?
    @State private var isLoadingEpisodes = true
    @State private var showsNavigationTitle = false
    @AppStorage("streamory-selected-mate-friend-id") private var selectedMateFriendIDString = ""
    @State private var canAddWithSelectedMate = false

    private var releasedEpisodes: [SeriesEpisode] {
        episodes.filter(\.isReleased)
    }

    private var seasons: [(Int, [SeriesEpisode])] {
        Dictionary(grouping: episodes, by: \.seasonNumber)
            .map { ($0.key, $0.value.sorted { $0.episodeNumber < $1.episodeNumber }) }
            .sorted {
                if $0.0 == 0 { return false }
                if $1.0 == 0 { return true }
                return $0.0 < $1.0
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                seriesHeader

                if isLoadingEpisodes {
                    ProgressView("Chargement des saisons...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(20)
                } else if seasons.isEmpty {
                    EmptyStateView(symbol: "tv", title: "Aucun épisode", subtitle: "Les saisons ne sont pas encore disponibles.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(seasons, id: \.0) { seasonNumber, seasonEpisodes in
                            SeasonDisclosureView(
                                seasonNumber: seasonNumber,
                                episodes: seasonEpisodes,
                                watchStates: watchStates,
                                isExpanded: expandedSeasons.contains(seasonNumber),
                                onToggle: { toggleSeason(seasonNumber) },
                                onSeasonAction: { Task { await markSeason(seasonEpisodes) } },
                                onEpisodeTap: handleEpisodeTap
                            )
                        }
                    }
                }

                CastCarouselView(castMembers: [])

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(18)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 24
        } action: { _, isScrolled in
            showsNavigationTitle = isScrolled
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(showsNavigationTitle ? currentItem.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                }
                .accessibilityLabel("Retour")
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    seriesSharedMateActionButton
                    seriesListActionButton
                    seriesMenu
                }
            }
        }
        .task {
            await loadProgress()
        }
        .task(id: selectedMateFriendIDString) {
            await loadSeriesMatePermission()
        }
        .confirmationDialog("Modifier l'épisode", isPresented: episodeActionDialogBinding) {
            Button("Revu") {
                if let selectedWatchedEpisode {
                    Task { await rewatchEpisode(selectedWatchedEpisode) }
                }
            }
            Button("Non vu", role: .destructive) {
                if let selectedWatchedEpisode {
                    Task { await unwatchEpisode(selectedWatchedEpisode) }
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text(String(format: "%@ est déjà marqué comme vu.".streamoryLocalized, selectedWatchedEpisode?.title ?? "Cet épisode".streamoryLocalized))
        }
    }

    private var seriesHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(currentItem.title)
                .font(.largeTitle.weight(.bold))
                .lineLimit(3)

            HStack(alignment: .top, spacing: 16) {
                PosterImage(imageURL: currentItem.imageURL, title: currentItem.title, kind: currentItem.kind)
                    .frame(width: 128, height: 192)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    Text([currentItem.year, currentItem.seriesStatus].compactMap { $0 }.joined(separator: " · "))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let genreRuntimeText {
                        Text(genreRuntimeText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if let overview = currentItem.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(overview)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(isOverviewExpanded ? nil : 6)
                            Button(isOverviewExpanded ? "Réduire" : "Développer") {
                                isOverviewExpanded.toggle()
                            }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var currentItem: MediaItem {
        currentUserLibraryItem ?? item
    }

    private var currentUserLibraryItem: MediaItem? {
        viewModel.library.first { $0.tvdbID == item.tvdbID && $0.kind == item.kind }
    }

    private var isInUserLibrary: Bool {
        currentUserLibraryItem != nil
    }

    private var genreRuntimeText: String? {
        let genres = currentItem.localizedGenres.prefix(3).joined(separator: ", ")
        let runtime = currentItem.episodeRuntime.map { $0 > 0 ? "\($0) min" : "" } ?? ""
        let text = [genres, runtime].filter { !$0.isEmpty }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }

    private var watchedEpisodeCount: Int {
        watchStates.values.filter { $0.watchCount > 0 }.count
    }

    private var canDeleteSeries: Bool {
        watchedEpisodeCount == 0
    }


    @ViewBuilder
    private var seriesSharedMateActionButton: some View {
        if let selectedMateFriend, canAddWithSelectedMate {
            Button {
                Task {
                    print("🧪 Mutual series add selectedMateFriend.id=\(selectedMateFriend.id) selectedMateFriend.userID=\(selectedMateFriend.userID)")
                    await viewModel.addToMutualWatchlist(currentItem, friendID: selectedMateFriend.userID)
                }
            } label: {
                Image(systemName: "person.2.badge.plus")
                    .font(.headline.weight(.semibold))
            }
            .accessibilityLabel("Ajouter aux deux listes")
        }
    }

    private var selectedMateFriend: StreamoryFriend? {
        guard let selectedMateFriendID = UUID(uuidString: selectedMateFriendIDString) else { return nil }
        return viewModel.friends.first { $0.id == selectedMateFriendID }
    }

    @ViewBuilder
    private var seriesListActionButton: some View {
        if !isInUserLibrary {
            Button {
                Task { await viewModel.addToWatchlist(currentItem) }
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
            }
            .accessibilityLabel("Ajouter à la liste")
        } else if canDeleteSeries {
            Button(role: .destructive) {
                onDelete(currentItem)
                dismiss()
            } label: {
                Image(systemName: "trash")
                    .font(.headline.weight(.semibold))
            }
            .accessibilityLabel("Supprimer de la liste")
        }
    }

    private var tvdbSeriesURL: URL? {
        let tvdbID = item.tvdbID.onlyDigitsOrSelf
        guard !tvdbID.isEmpty else { return nil }
        return URL(string: "https://www.thetvdb.com/dereferrer/series/\(tvdbID)")
    }

    private var seriesMenu: some View {
        Menu {
            Button {
            } label: {
                Label("Personnaliser", systemImage: "photo")
            }
            .disabled(true)

            Button {
                if let tvdbSeriesURL {
                    openURL(tvdbSeriesURL)
                }
            } label: {
                Label("Corriger sur TheTVDB", systemImage: "pencil")
            }
            .disabled(tvdbSeriesURL == nil)
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline.weight(.semibold))
        }
        .accessibilityLabel("Options de la série")
    }

    private var episodeActionDialogBinding: Binding<Bool> {
        Binding(
            get: { selectedWatchedEpisode != nil },
            set: { isPresented in
                if !isPresented {
                    selectedWatchedEpisode = nil
                }
            }
        )
    }

    private func loadProgress() async {
        isLoadingEpisodes = true
        errorMessage = nil
        do {
            let progress = try await viewModel.loadSeriesProgress(for: item)
            episodes = progress.0
            watchStates = progress.1
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingEpisodes = false
    }

    private func toggleSeason(_ seasonNumber: Int) {
        if expandedSeasons.contains(seasonNumber) {
            expandedSeasons.remove(seasonNumber)
        } else {
            expandedSeasons.insert(seasonNumber)
        }
    }

    private func handleEpisodeTap(_ episode: SeriesEpisode) {
        guard episode.isReleased else { return }
        if watchStates[episode.id] != nil {
            selectedWatchedEpisode = episode
        } else {
            Task { await watchEpisode(episode, rewatchCount: 0) }
        }
    }

    private func markSeason(_ seasonEpisodes: [SeriesEpisode]) async {
        let releasedSeasonEpisodes = seasonEpisodes.filter(\.isReleased)
        guard !releasedSeasonEpisodes.isEmpty else { return }
        do {
            for episode in releasedSeasonEpisodes where watchStates[episode.id] == nil {
                watchStates = try await viewModel.markEpisodeWatched(episode, in: item, rewatchCount: 0, releasedEpisodes: releasedEpisodes)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func watchEpisode(_ episode: SeriesEpisode, rewatchCount: Int) async {
        do {
            watchStates = try await viewModel.markEpisodeWatched(episode, in: item, rewatchCount: rewatchCount, releasedEpisodes: releasedEpisodes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rewatchEpisode(_ episode: SeriesEpisode) async {
        let nextRewatchCount = (watchStates[episode.id]?.rewatchCount ?? 0) + 1
        await watchEpisode(episode, rewatchCount: nextRewatchCount)
    }

    private func unwatchEpisode(_ episode: SeriesEpisode) async {
        do {
            watchStates = try await viewModel.markEpisodeUnwatched(episode, in: item, releasedEpisodes: releasedEpisodes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    private func loadSeriesMatePermission() async {
        guard let selectedMateFriend else {
            canAddWithSelectedMate = false
            return
        }

        let isAllowed = await viewModel.mutualFriendCanAddPermission(friendID: selectedMateFriend.id)
        await MainActor.run {
            canAddWithSelectedMate = isAllowed
        }
    }
}

struct SeasonDisclosureView: View {
    let seasonNumber: Int
    let episodes: [SeriesEpisode]
    let watchStates: [String: EpisodeWatchState]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSeasonAction: () -> Void
    let onEpisodeTap: (SeriesEpisode) -> Void

    private var releasedEpisodes: [SeriesEpisode] {
        episodes.filter(\.isReleased)
    }

    private var watchedCount: Int {
        releasedEpisodes.filter { watchStates[$0.id] != nil }.count
    }

    private var isSeasonWatched: Bool {
        !releasedEpisodes.isEmpty && watchedCount == releasedEpisodes.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 10) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(seasonNumber == 0 ? "Épisodes spéciaux".streamoryLocalized : String(format: "Saison %lld".streamoryLocalized, seasonNumber))
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%lld/%lld vus".streamoryLocalized, watchedCount, releasedEpisodes.count))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if !releasedEpisodes.isEmpty {
                        Button(action: onSeasonAction) {
                            Text(isSeasonWatched ? "Vu".streamoryLocalized : "À voir".streamoryLocalized)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(isSeasonWatched ? Color.green : AppTheme.field)
                                .foregroundStyle(isSeasonWatched ? .black : .secondary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)

            if isExpanded {
                Divider().opacity(0.35)
                ForEach(episodes) { episode in
                    EpisodeRowView(episode: episode, watchState: watchStates[episode.id]) {
                        onEpisodeTap(episode)
                    }
                    if episode.id != episodes.last?.id {
                        Divider().opacity(0.25)
                    }
                }
            }
        }
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct EpisodeRowView: View {
    let episode: SeriesEpisode
    let watchState: EpisodeWatchState?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Text(episode.displayNumber)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 42, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    Text(episode.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(episode.formattedAirDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if episode.isReleased {
                    Text(stateLabel)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(watchState == nil ? AppTheme.field : Color.green)
                        .foregroundColor(watchState == nil ? .secondary : .black)
                        .clipShape(Capsule())
                }
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!episode.isReleased)
    }

    private var stateLabel: String {
        guard let watchState else { return "À voir".streamoryLocalized }
        return watchState.watchCount > 1 ? String(format: "Vu ×%lld".streamoryLocalized, watchState.watchCount) : "Vu".streamoryLocalized
    }
}

struct CastMember: Identifiable, Hashable {
    let id: String
    let actorName: String
    let roleName: String
    let imageURL: String?
}

struct CastCarouselView: View {
    let castMembers: [CastMember]

    var body: some View {
        if !castMembers.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distribution".streamoryLocalized)
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(castMembers) { castMember in
                            CastMemberCard(castMember: castMember)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            .padding(12)
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct CastMemberCard: View {
    let castMember: CastMember
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.field)

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 116, height: 164)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(castMember.actorName)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if !castMember.roleName.isEmpty {
                    Text(castMember.roleName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                }
            }
            .padding(8)
        }
        .frame(width: 116, height: 164)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: castMember.imageURL) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let imageURL = castMember.imageURL, let url = URL(string: imageURL) else {
            image = nil
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)

        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let cachedImage = UIImage(data: cachedResponse.data) {
            image = cachedImage
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let loadedImage = UIImage(data: data) else { return }
            let cachedResponse = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedResponse, for: request)
            image = loadedImage
        } catch {
            image = nil
        }
    }
}

struct PosterImage: View {
    let imageURL: String?
    let title: String
    let kind: MediaKind
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            PosterPlaceholder(title: title, kind: kind)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .clipped()
        .task(id: imageURL) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let imageURL, let url = URL(string: imageURL) else {
            image = nil
            return
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)

        if let cachedResponse = URLCache.shared.cachedResponse(for: request),
           let cachedImage = UIImage(data: cachedResponse.data) {
            image = cachedImage
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let loadedImage = UIImage(data: data) else { return }

            let cachedResponse = CachedURLResponse(response: response, data: data)
            URLCache.shared.storeCachedResponse(cachedResponse, for: request)
            image = loadedImage
        } catch {
            image = nil
        }
    }
}

struct PosterPlaceholder: View {
    let title: String
    let kind: MediaKind

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.13, blue: 0.15)
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct ProfileRow: View {
    let symbol: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct HeaderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.weight(.bold))
            if !subtitle.isEmpty {
                Text(subtitle.streamoryLocalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
            Text(title.streamoryLocalized)
                .font(.headline)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

enum AppTheme {
    static let background = Color(uiColor: .systemBackground)
    static let panel = Color(uiColor: .secondarySystemGroupedBackground)
    static let field = Color(uiColor: .tertiarySystemGroupedBackground)
}

enum SupportedCountries {
    static let codes: [String] = Locale.Region.isoRegions
        .filter(\.isISORegion)
        .map(\.identifier)
        .filter { $0.count == 2 }
        .sorted { label(for: $0) < label(for: $1) }

    static var defaultCode: String {
        let regionCode = Locale.current.region?.identifier.uppercased()
        return codes.contains(regionCode ?? "") ? regionCode ?? "FR" : "FR"
    }

    static func label(for code: String) -> String {
        let name = Locale.current.localizedString(forRegionCode: code) ?? code
        return "\(code.streamoryCountryFlag) \(name)"
    }
}
