import SwiftUI
import UIKit
import Combine

struct UpcomingEpisode: Identifiable, Hashable {
    let series: MediaItem
    let episode: SeriesEpisode

    var id: String { "\(series.id.uuidString)-\(episode.id)" }
}

@MainActor
final class StreamoryViewModel: ObservableObject {
    @Published var session: StreamorySession?
    @Published var profile: StreamoryProfile?
    @Published var library: [MediaItem] = []
    @Published var friends: [StreamoryFriend] = []
    @Published var friendWatchlists: [UUID: [MediaItem]] = [:]
    @Published var friendLibraries: [UUID: [MediaItem]] = [:]
    @Published var mateSeriesMatches: [UUID: [MediaItem]] = [:]
    @Published var searchResults: [TVDBSearchResult] = []
    @Published var profileSearchResults: [StreamoryProfileSearchResult] = []
    @Published var upcomingEpisodes: [UpcomingEpisode] = []
    @Published var castMembersByMediaKey: [String: [CastMember]] = [:]
    @Published var startupAlert: StreamoryAppAlert?
    @Published var dismissedAlertIDs: Set<UUID> = []
    @Published var cloudKitAvailability: StreamoryCloudKitAvailability = .unknown
    @Published var isLoading = false
    @Published var isLoadingUpcomingEpisodes = false
    @Published var isRestoringSession = true
    @Published var message: String?
    @Published var resetPasswordInlineMessage: String?
    @Published var resetPasswordInlineMessageIsError = false

    private let service = StreamoryService()
    private let cloudKitService = StreamoryCloudKitService()
    private let sessionKey = "streamory-native-session"
    private let dismissedAlertsKey = "streamory-dismissed-alerts"
    private let localizedTitlesKey = "streamory-localized-titles"

    init() {
        configureImageCache()
        restoreDismissedAlerts()
        restoreSession()
        Task { await loadStartupAlert() }
    }

    private func configureImageCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 300 * 1024 * 1024,
            diskPath: "streamory-poster-cache"
        )
    }

    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: sessionKey),
              let session = try? JSONDecoder().decode(StreamorySession.self, from: data) else {
            isRestoringSession = false
            return
        }

        self.session = session
        isRestoringSession = false

        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                let refreshedSession = try await service.refreshSession(refreshToken: session.refreshToken)
                setSession(refreshedSession)
                try await loadRemoteData(session: refreshedSession)
            } catch {
                handleServiceError(error)
            }
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        message = nil
        do {
            let session = try await service.signIn(email: email, password: password)
            setSession(session)
            try await loadRemoteData(session: session)
        } catch {
            let rawError = String(describing: error)
            if rawError.contains("invalid_credentials") || rawError.contains("Invalid login credentials") || rawError.contains("code\":400") {
                isLoading = false
                return
            }
            handleServiceError(error)
        }
        isLoading = false
    }

    func resetPassword(email: String) async {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        resetPasswordInlineMessage = nil
        resetPasswordInlineMessageIsError = false

        guard cleanEmail.contains("@") else {
            resetPasswordInlineMessage = "Email requis pour recevoir le lien de réinitialisation.".streamoryLocalized
            resetPasswordInlineMessageIsError = true
            return
        }

        isLoading = true
        message = nil
        do {
            try await service.resetPassword(email: cleanEmail)
            resetPasswordInlineMessage = "Si un compte existe avec cet email, un lien de réinitialisation a été envoyé.".streamoryLocalized
            resetPasswordInlineMessageIsError = false
        } catch {
            let rawError = String(describing: error)
            if rawError.contains("429") || rawError.contains("For security purposes") {
                resetPasswordInlineMessage = "Demande trop récente. Nouvelle tentative possible dans quelques secondes.".streamoryLocalized
                resetPasswordInlineMessageIsError = true
            } else {
                handleServiceError(error)
            }
        }
        isLoading = false
    }

    func signUp(email: String, password: String, username: String, birthDate: Date, country: String) async {
        await run {
            let session = try await service.signUp(email: email, password: password, username: username, birthDate: birthDate, country: country)
            setSession(session)
            try await loadRemoteData(session: session)
        }
    }

    func signInWithApple(idToken: String, nonce: String, fullName: String?, email: String?, country: String?) async {
        await run {
            let session = try await service.signInWithApple(
                idToken: idToken,
                nonce: nonce,
                fullName: fullName,
                email: email,
                country: country
            )
            setSession(session)
            try await loadRemoteData(session: session)
        }
    }

    func storeAppleAuthorizationCode(_ authorizationCode: String) async {
        guard let session else { return }
        await run {
            try await service.storeAppleAuthorizationCode(authorizationCode, session: session)
        }
    }

    func linkAppleLogin(idToken: String, nonce: String, fullName: String?, email: String?) async {
        guard let session else { return }
        await run {
            let updatedSession = try await service.linkAppleLogin(
                idToken: idToken,
                nonce: nonce,
                fullName: fullName,
                email: email,
                session: session
            )
            setSession(updatedSession)
            profile = try await service.loadProfile(session: updatedSession)
            message = "Connexion Apple ajoutée au compte.".streamoryLocalized
        }
    }

    var needsAppleProfileCompletion: Bool {
        guard let session, session.user.metadata["apple_login_enabled"] == "true" else { return false }
        let metadata = session.user.metadata
        let birthDate = metadata["birth_date"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let country = metadata["country"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return birthDate.isEmpty || !SupportedCountries.codes.contains(country)
    }

    var hasPasswordLogin: Bool {
        guard let session else { return true }
        let providers = Set(session.user.identities.map(\.provider))
        if !providers.isEmpty {
            return providers.contains("email")
        }
        return session.user.metadata["apple_login_enabled"] != "true"
    }

    var requiresPasswordForAccountDeletion: Bool {
        hasPasswordLogin
    }

    func completeAppleProfile(birthDate: Date, country: String) async {
        guard let session else { return }
        await run {
            let updatedSession = try await service.completeAppleProfile(birthDate: birthDate, country: country, session: session)
            setSession(updatedSession)
            profile = try await service.loadProfile(session: updatedSession)
            message = nil
        }
    }

    func unlinkAppleLogin() async {
        guard let session else { return }
        await run {
            let updatedSession = try await service.unlinkAppleLogin(session: session)
            setSession(updatedSession)
            profile = try await service.loadProfile(session: updatedSession)
            message = "Connexion Apple dissociée.".streamoryLocalized
        }
    }

    func deleteAccount(password: String?) async {
        guard let session else {
            print("[DELETE ACCOUNT] ViewModel has no session")
            return
        }

        print("[DELETE ACCOUNT] ViewModel deleteAccount started")
        print("[DELETE ACCOUNT] ViewModel user id: \(session.user.id.uuidString)")
        print("[DELETE ACCOUNT] Password provided: \(password?.isEmpty == false)")

        await run {
            print("[DELETE ACCOUNT] Calling service.deleteAccount")
            try await service.deleteAccount(password: password, session: session)
            print("[DELETE ACCOUNT] service.deleteAccount succeeded")
            signOut()
        }

        print("[DELETE ACCOUNT] ViewModel deleteAccount finished")
    }

    func signOut() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
        UserDefaults.standard.synchronize()

        session = nil
        profile = nil
        library = []
        friends = []
        friendWatchlists = [:]
        friendLibraries = [:]
        mateSeriesMatches = [:]
        searchResults = []
        profileSearchResults = []
        upcomingEpisodes = []
        castMembersByMediaKey = [:]
        isLoading = false
        isLoadingUpcomingEpisodes = false
        isRestoringSession = false
        message = nil
        resetPasswordInlineMessage = nil
        resetPasswordInlineMessageIsError = false
    }

    func refreshAll() async {
        guard let session else { return }
        isLoading = true
        message = nil
        do {
            try await loadRemoteData(session: session)
        } catch {
            handleServiceError(error)
        }
        isLoading = false
    }

    func searchTVDB(query: String) async {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanQuery.isEmpty else {
            clearSearchResults()
            return
        }

        await run {
            var loadedResults: [TVDBSearchResult] = []
            var seenSearches = Set<String>()

            let normalizedQuery = cleanQuery.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            let queries = [cleanQuery, normalizedQuery]
            let languages = Array(Set([preferredTVDBLanguage, "eng"]))

            for language in languages {
                for searchQuery in queries {
                    let searchKey = "\(language)|\(searchQuery.lowercased())"
                    guard !seenSearches.contains(searchKey) else { continue }
                    seenSearches.insert(searchKey)

                    let results = try await service.searchTVDB(query: searchQuery, language: language, session: session)
                    loadedResults.append(contentsOf: results)
                }
            }

            var seenResults = Set<String>()
            searchResults = loadedResults.compactMap { result in
                guard result.kind == .movie || result.kind == .series else { return nil }
                guard !looksLikeTVDBPersonResult(result) else { return nil }

                let key = "\(result.kind)-\(result.tvdbID)"
                guard !seenResults.contains(key) else { return nil }
                seenResults.insert(key)
                return result
            }
        }
    }

    private func looksLikeTVDBPersonResult(_ result: TVDBSearchResult) -> Bool {
        let raw = String(describing: result).lowercased()

        if raw.contains("type: person") || raw.contains("type = person") || raw.contains("type\":\"person") || raw.contains("type\": \"person") {
            return true
        }

        if raw.contains("kind: person") || raw.contains("kind = person") || raw.contains("kind\":\"person") || raw.contains("kind\": \"person") {
            return true
        }

        if raw.contains("personid") || raw.contains("person_id") || raw.contains("peopleid") || raw.contains("people_id") {
            return true
        }

        if raw.contains("type: company") || raw.contains("type = company") || raw.contains("type\":\"company") || raw.contains("type\": \"company") {
            return true
        }

        if raw.contains("type: franchise") || raw.contains("type = franchise") || raw.contains("type\":\"franchise") || raw.contains("type\": \"franchise") {
            return true
        }

        let yearText = result.year?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let overviewText = result.overview?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let imageText = String(describing: result.imageURL).lowercased()

        let hasNoYear = yearText.isEmpty
        let hasNoOverview = overviewText.isEmpty
        let hasPersonImage = imageText.contains("person") || imageText.contains("people") || imageText.contains("placeholder")

        return result.kind == .series && hasNoYear && (hasNoOverview || hasPersonImage)
    }

    func clearSearchResults() {
        searchResults = []
    }

    func addToWatchlist(_ result: TVDBSearchResult) async {
        guard let session else { return }
        await run {
            let item = result.mediaItem(userID: session.user.id, status: .watchlist)
            let savedItem = try await service.upsert(item, session: session)
            let localizedSavedItem = await service.localizedMediaItems([savedItem], language: preferredTVDBLanguage, session: session).first ?? savedItem
            library.removeAll { $0.tvdbID == savedItem.tvdbID && $0.kind == savedItem.kind }
            library.insert(localizedSavedItem, at: 0)
            searchResults.removeAll { $0.id == result.id }
            message = "Ajouté à la liste.".streamoryLocalized
        }
    }

    func addToWatchlist(_ item: MediaItem) async {
        guard let session else { return }
        await run {
            var watchlistItem = item
            watchlistItem.userID = session.user.id
            watchlistItem.status = .watchlist
            let savedItem = try await service.upsert(watchlistItem, session: session)
            let localizedSavedItem = await service.localizedMediaItems([savedItem], language: preferredTVDBLanguage, session: session).first ?? savedItem
            library.removeAll { $0.tvdbID == localizedSavedItem.tvdbID && $0.kind == localizedSavedItem.kind }
            library.insert(localizedSavedItem, at: 0)
            message = "Ajouté à la liste.".streamoryLocalized
        }
    }

    func addToMutualWatchlist(_ item: MediaItem, friendID: UUID) async {
        guard let session else { return }

        await run {
            try await service.addToMutualWatchlist(item, friendID: friendID, session: session)
            await refreshAll()

            let loadedFriendLibrary = try await service.loadPublicLibrary(userID: friendID, session: session)
            friendLibraries[friendID] = await service.localizedMediaItems(loadedFriendLibrary, language: preferredTVDBLanguage, session: session)

            let loadedFriendWatchlist = try await service.loadFriendWatchlist(friendID: friendID, session: session)
            friendWatchlists[friendID] = await service.localizedMediaItems(loadedFriendWatchlist, language: preferredTVDBLanguage, session: session)

            message = "Ajouté aux deux listes.".streamoryLocalized
        }
    }

    func updateStatus(_ item: MediaItem, _ status: WatchStatus) async {
        guard let session else { return }
        await run {
            try await service.updateStatus(item: item, status: status, session: session)
            if let index = library.firstIndex(where: { $0.id == item.id }) {
                library[index].status = status
            }
        }
    }

    func loadSeriesProgress(for item: MediaItem) async throws -> ([SeriesEpisode], [String: EpisodeWatchState]) {
        guard let session else { return ([], [:]) }
        async let episodes = service.loadSeriesEpisodes(tvdbID: item.tvdbID, language: preferredTVDBLanguage, session: session)
        async let states = service.loadEpisodeWatchStates(userID: session.user.id, tvdbID: item.tvdbID, session: session)
        let loadedStates = try await states
        return try await (episodes, Dictionary(uniqueKeysWithValues: loadedStates.map { ($0.episodeID, $0) }))
    }

    func loadLocalizedMediaDetails(for item: MediaItem) async -> MediaItem {
        guard let session else { return item }
        return await service.localizedMediaItems([item], language: preferredTVDBLanguage, session: session).first ?? item
    }

    func loadCast(for item: MediaItem) async {
        guard let session else { return }
        guard castMembersByMediaKey[item.matchKey] == nil else { return }

        do {
            let cast = try await service.loadCast(for: item, language: preferredTVDBLanguage, session: session)
            castMembersByMediaKey[item.matchKey] = cast.streamoryCastMembers
        } catch {
            castMembersByMediaKey[item.matchKey] = []
        }
    }

    func loadUpcomingEpisodes() async {
        guard let session else {
            upcomingEpisodes = []
            return
        }

        let seriesItems = library.filter { $0.kind == .series && $0.status != .stopped }
        guard !seriesItems.isEmpty else {
            upcomingEpisodes = []
            return
        }

        isLoadingUpcomingEpisodes = true
        defer { isLoadingUpcomingEpisodes = false }

        do {
            let today = Calendar.current.startOfDay(for: Date())
            var loadedEpisodes: [UpcomingEpisode] = []

            for item in seriesItems {
                let episodes = try await service.loadSeriesEpisodes(tvdbID: item.tvdbID, language: preferredTVDBLanguage, session: session)
                loadedEpisodes.append(contentsOf: episodes.compactMap { episode in
                    guard let airDate = episode.airDate, airDate > today else { return nil }
                    return UpcomingEpisode(series: item, episode: episode)
                })
            }

            upcomingEpisodes = loadedEpisodes.sorted {
                guard let firstDate = $0.episode.airDate, let secondDate = $1.episode.airDate else { return $0.series.title < $1.series.title }
                if firstDate == secondDate { return $0.series.title < $1.series.title }
                return firstDate < secondDate
            }
        } catch {
            handleServiceError(error)
        }
    }

    func markEpisodeWatched(_ episode: SeriesEpisode, in item: MediaItem, rewatchCount: Int, releasedEpisodes: [SeriesEpisode]) async throws -> [String: EpisodeWatchState] {
        guard let session else { return [:] }
        try await service.upsertEpisodeWatch(episode: episode, series: item, rewatchCount: rewatchCount, session: session)
        let states = try await service.loadEpisodeWatchStates(userID: session.user.id, tvdbID: item.tvdbID, session: session)
        let stateMap = Dictionary(uniqueKeysWithValues: states.map { ($0.episodeID, $0) })
        try await syncSeriesStatus(item, states: stateMap, releasedEpisodes: releasedEpisodes)
        return stateMap
    }

    func markEpisodeUnwatched(_ episode: SeriesEpisode, in item: MediaItem, releasedEpisodes: [SeriesEpisode]) async throws -> [String: EpisodeWatchState] {
        guard let session else { return [:] }
        try await service.deleteEpisodeWatch(episodeID: episode.id, session: session)
        let states = try await service.loadEpisodeWatchStates(userID: session.user.id, tvdbID: item.tvdbID, session: session)
        let stateMap = Dictionary(uniqueKeysWithValues: states.map { ($0.episodeID, $0) })
        try await syncSeriesStatus(item, states: stateMap, releasedEpisodes: releasedEpisodes)
        return stateMap
    }

    private func syncSeriesStatus(_ item: MediaItem, states: [String: EpisodeWatchState], releasedEpisodes: [SeriesEpisode]) async throws {
        let regularEpisodes = releasedEpisodes.filter { $0.seasonNumber > 0 }
        let statusEpisodes = regularEpisodes.isEmpty ? releasedEpisodes : regularEpisodes
        let watchedCount = statusEpisodes.filter { states[$0.id] != nil }.count
        let status: WatchStatus = watchedCount == 0 || statusEpisodes.isEmpty ? .watchlist : watchedCount >= statusEpisodes.count ? .watched : .watching
        try await service.updateStatus(item: item, status: status, session: session!)
        if let index = library.firstIndex(where: { $0.id == item.id }) {
            library[index].status = status
        }
    }
    
    func setFriendCanAddPermission(friend: StreamoryFriend, allowed: Bool) async {
        await setFriendCanAddPermissionByID(friendID: friend.id, allowed: allowed)
    }

    func setFriendCanAddPermissionByID(friendID: UUID, allowed: Bool) async {
        guard let session else { return }

        await run {
            try await service.setFriendCanAddPermission(
                friendID: friendID,
                allowed: allowed,
                session: session
            )

            message = allowed
                ? "Ajouts communs autorisés.".streamoryLocalized
                : "Ajouts communs désactivés.".streamoryLocalized
        }
    }

    func friendCanAddPermission(friendID: UUID) async -> Bool {
        guard let session else { return false }

        do {
            return try await service.friendCanAddPermission(friendID: friendID, session: session)
        } catch {
            return false
        }
    }

    func mutualFriendCanAddPermission(friendID: UUID) async -> Bool {
        guard let session else { return false }

        do {
            return try await service.mutualFriendCanAddPermission(friendID: friendID, session: session)
        } catch {
            return false
        }
    }

    func delete(_ item: MediaItem) async {
        guard let session else { return }
        await run {
            try await service.delete(item: item, session: session)
            library.removeAll { $0.id == item.id }
        }
    }

    func loadWatchlist(for friend: StreamoryFriend) async {
        guard let session, friendWatchlists[friend.id] == nil else { return }
        await run {
            let friendItems = try await service.loadFriendWatchlist(friendID: friend.id, session: session)
            friendWatchlists[friend.id] = await service.localizedMediaItems(friendItems, language: preferredTVDBLanguage, session: session)
        }
    }

    func loadPublicLibrary(for user: StreamoryProfileSearchResult) async {
        guard let session, friendLibraries[user.id] == nil else { return }
        await run {
            let publicItems = try await service.loadPublicLibrary(userID: user.id, session: session)
            friendLibraries[user.id] = await service.localizedMediaItems(publicItems, language: preferredTVDBLanguage, session: session)
        }
    }

    func loadMateSeriesMatches(for friend: StreamoryFriend) async {
        guard let session else { return }

        await run {
            let friendItems: [MediaItem]
            if let cachedFriendLibrary = friendLibraries[friend.id] {
                friendItems = cachedFriendLibrary
            } else {
                let loadedFriendLibrary = try await service.loadPublicLibrary(userID: friend.id, session: session)
                let localizedFriendLibrary = await service.localizedMediaItems(loadedFriendLibrary, language: preferredTVDBLanguage, session: session)
                friendLibraries[friend.id] = localizedFriendLibrary
                friendItems = localizedFriendLibrary
            }

            let friendSeriesByKey = Dictionary(
                friendItems
                    .filter { $0.kind == .series && $0.status != .watched }
                    .map { ($0.matchKey, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            var matches: [MediaItem] = []
            for item in library where item.kind == .series && item.status != .watched {
                guard let friendItem = friendSeriesByKey[item.matchKey] else { continue }

                if item.status == .watchlist && friendItem.status == .watchlist {
                    matches.append(item)
                } else if try await hasSharedNextEpisode(for: item, with: friendItem, session: session, friendID: friend.id) {
                    matches.append(item)
                }
            }

            mateSeriesMatches[friend.id] = matches.sorted { $0.title < $1.title }
        }
    }

    func searchProfiles(query: String) async {
        guard let session else { return }
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanQuery.count >= 2 else {
            profileSearchResults = []
            message = "Deux caractères minimum requis.".streamoryLocalized
            return
        }

        await run {
            profileSearchResults = try await service.searchProfiles(query: cleanQuery, session: session)
        }
    }

    func sendFriendRequest(to user: StreamoryProfileSearchResult) async {
        guard let session else { return }
        await run {
            try await service.sendFriendRequest(targetUserID: user.userID, session: session)
            profileSearchResults = profileSearchResults.map { result in
                guard result.id == user.id else { return result }
                return StreamoryProfileSearchResult(userID: result.userID, username: result.username, country: result.country, relationshipStatus: "pending")
            }
            message = "Demande envoyée.".streamoryLocalized
        }
    }

    func updateProfile(username: String, country: String, email: String, currentPassword: String, newPassword: String) async {
        guard let session else { return }
        await run {
            let updatedSession = try await service.updateProfile(
                username: username,
                country: country,
                email: email,
                currentPassword: currentPassword,
                newPassword: newPassword,
                session: session
            )
            setSession(updatedSession)
            profile = try await service.loadProfile(session: updatedSession)
            await refreshLocalizedMedia()
            message = "Profil mis à jour.".streamoryLocalized
        }
    }

    func refreshLocalizedMedia() async {
        guard let session else { return }
        let language = preferredTVDBLanguage
        library = await service.localizedMediaItems(library, language: language, session: session)
        castMembersByMediaKey = [:]

        for (friendID, items) in friendWatchlists {
            friendWatchlists[friendID] = await service.localizedMediaItems(items, language: language, session: session)
        }

        for (friendID, items) in friendLibraries {
            friendLibraries[friendID] = await service.localizedMediaItems(items, language: language, session: session)
        }

        mateSeriesMatches = mateSeriesMatches.mapValues { items in
            items.compactMap { match in
                library.first { $0.matchKey == match.matchKey } ?? match
            }
        }
        await loadUpcomingEpisodes()
    }

    func loadStartupAlert() async {
        do {
            startupAlert = try await service.loadStartupAlerts()
                .first { !dismissedAlertIDs.contains($0.id) }
        } catch {
            startupAlert = nil
        }
    }

    func dismissStartupAlert(_ alert: StreamoryAppAlert) {
        dismissedAlertIDs.insert(alert.id)
        saveDismissedAlerts()
        startupAlert = nil
    }

    func removeFriend(_ user: StreamoryProfileSearchResult) async {
        fatalError("TODO")
    }

    func loadPublicProfile(userID: UUID) async {
        fatalError("TODO")
    }

    private func restoreDismissedAlerts() {
        guard let data = UserDefaults.standard.data(forKey: dismissedAlertsKey),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return }
        dismissedAlertIDs = Set(ids)
    }

    private func saveDismissedAlerts() {
        guard let data = try? JSONEncoder().encode(Array(dismissedAlertIDs)) else { return }
        UserDefaults.standard.set(data, forKey: dismissedAlertsKey)
    }

    private func setSession(_ session: StreamorySession) {
        self.session = session
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: sessionKey)
        }
    }

    private func loadRemoteData(session: StreamorySession) async throws {
        async let profile = service.loadProfile(session: session)
        async let library = service.loadLibrary(session: session)
        async let friends = service.loadFriends(session: session)
        self.profile = try await profile
        self.library = await service.localizedMediaItems(try await library, language: preferredTVDBLanguage, session: session)
        self.friends = try await friends
        friendWatchlists = [:]
        friendLibraries = [:]
        mateSeriesMatches = [:]
        castMembersByMediaKey = [:]
        await syncProfileToCloudKit(session: session)
    }

    private func refreshCloudKitAvailability() async {
        cloudKitAvailability = await cloudKitService.accountAvailability()
    }

    private func syncProfileToCloudKit(session: StreamorySession) async {
        await refreshCloudKitAvailability()
        guard cloudKitAvailability == .available, let profile else { return }

        do {
            try await cloudKitService.saveProfileSnapshot(profile, session: session)
        } catch {
            cloudKitAvailability = await cloudKitService.accountAvailability()
        }
    }

    private func hasSharedNextEpisode(for item: MediaItem, with friendItem: MediaItem, session: StreamorySession, friendID: UUID) async throws -> Bool {
        async let loadedEpisodes = service.loadSeriesEpisodes(tvdbID: item.tvdbID, language: preferredTVDBLanguage, session: session)
        async let ownStates = service.loadEpisodeWatchStates(userID: session.user.id, tvdbID: item.tvdbID, session: session)
        async let friendStates = service.loadEpisodeWatchStates(userID: friendID, tvdbID: friendItem.tvdbID, session: session)

        let episodes = try await loadedEpisodes
        let regularReleasedEpisodes = episodes.filter { $0.seasonNumber > 0 && $0.isReleased }
        let releasedEpisodes = regularReleasedEpisodes.isEmpty ? episodes.filter(\.isReleased) : regularReleasedEpisodes
        guard !releasedEpisodes.isEmpty else { return false }

        guard let ownLastEpisode = latestWatchedEpisode(in: try await ownStates),
              let friendLastEpisode = latestWatchedEpisode(in: try await friendStates),
              ownLastEpisode.episodeID == friendLastEpisode.episodeID else {
            return false
        }

        return releasedEpisodes.contains { episode in
            episode.seasonNumber > ownLastEpisode.seasonNumber ||
            (episode.seasonNumber == ownLastEpisode.seasonNumber && episode.episodeNumber > ownLastEpisode.episodeNumber)
        }
    }

    private func latestWatchedEpisode(in states: [EpisodeWatchState]) -> EpisodeWatchState? {
        states.max {
            if $0.seasonNumber == $1.seasonNumber {
                return $0.episodeNumber < $1.episodeNumber
            }
            return $0.seasonNumber < $1.seasonNumber
        }
    }

    private func run(_ operation: () async throws -> Void) async {
        isLoading = true
        message = nil
        do {
            try await operation()
        } catch {
            handleServiceError(error)
        }
        isLoading = false
    }

    private func handleServiceError(_ error: Error) {
        let text = error.localizedDescription.lowercased()
        if text.contains("jwt expired") || text.contains("pgrst303") {
            signOut()
            message = "Session expirée. Nouvelle connexion requise.".streamoryLocalized
        } else {
            message = error.localizedDescription
        }
    }

    private var preferredTVDBLanguage: String {
        UserDefaults.standard.object(forKey: localizedTitlesKey) as? Bool == false ? "eng" : tvdbLanguage
    }

    private var tvdbLanguage: String {
        switch (profile?.country ?? session?.user.metadata["country"] ?? "FR").uppercased() {
        case "FR", "BE", "CH": "fra"
        case "ES": "spa"
        case "IT": "ita"
        case "DE": "deu"
        case "PT": "por"
        default: "eng"
        }
    }
}
