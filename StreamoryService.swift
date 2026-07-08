import Foundation

struct StreamoryService {
    private let supabaseURL = URL(string: "https://nfrbencwzjgulzqpnnjx.supabase.co")!
    private let anonKey = "sb_publishable_p6cxFIj6Szs9KdHbgcLctA_3H4eXn8N"

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func signIn(email: String, password: String) async throws -> StreamorySession {
        let url = supabaseURL.appending(path: "/auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "password")])
        let payload = ["email": email, "password": password]
        return try await send(url, method: "POST", body: payload, token: nil, prefer: nil, response: AuthResponse.self).session
    }

    func signInWithApple(idToken: String, nonce: String, fullName: String?, email: String?, country: String?) async throws -> StreamorySession {
        let session = try await appleSession(idToken: idToken, nonce: nonce)
        return try await updateAppleMetadata(session: session, fullName: fullName, email: email, country: country, marksAppleLoginEnabled: true)
    }

    func storeAppleAuthorizationCode(_ authorizationCode: String, session: StreamorySession) async throws {
        let url = supabaseURL.appending(path: "/functions/v1/store-apple-token-v2")
        let payload = AppleAuthorizationCodePayload(authorizationCode: authorizationCode)

        print("[APPLE TOKEN] Calling store-apple-token")
        print("[APPLE TOKEN] Authorization code length: \(authorizationCode.count)")
        print("[APPLE TOKEN] User id: \(session.user.id.uuidString)")

        let result = try await send(
            url,
            method: "POST",
            body: payload,
            token: session.accessToken,
            prefer: nil,
            response: StoreAppleTokenResponse.self
        )

        print("[APPLE TOKEN] store-apple-token success: \(result.ok), stored_user_id: \(result.storedUserID ?? "nil")")
    }

    func linkAppleLogin(idToken: String, nonce: String, fullName: String?, email: String?, session currentSession: StreamorySession) async throws -> StreamorySession {
        let appleSession = try await appleSession(idToken: idToken, nonce: nonce)
        guard appleSession.user.id == currentSession.user.id else {
            throw StreamoryServiceError.server("Ce compte Apple est déjà associé à un autre compte Streamory.".streamoryLocalized)
        }

        return try await updateAppleMetadata(
            session: appleSession,
            fullName: fullName,
            email: email,
            country: currentSession.user.metadata["country"],
            marksAppleLoginEnabled: true
        )
    }

    func unlinkAppleLogin(session: StreamorySession) async throws -> StreamorySession {
        let identities = try await userIdentities(session: session)
        guard identities.count > 1 else {
            throw StreamoryServiceError.server("Ajoute d’abord un mot de passe ou une autre méthode de connexion avant de dissocier Apple.".streamoryLocalized)
        }
        guard let appleIdentity = identities.first(where: { $0.provider == "apple" }) else {
            throw StreamoryServiceError.server("Aucune connexion Apple n’est associée à ce compte.".streamoryLocalized)
        }

        let deleteURL = supabaseURL.appending(path: "/auth/v1/user/identities/\(appleIdentity.identityID)")
        _ = try await send(deleteURL, method: "DELETE", body: EmptyBody?.none, token: session.accessToken, prefer: nil, response: EmptyResponse.self)

        var metadata = session.user.metadata
        metadata["apple_login_enabled"] = "false"
        let updateURL = supabaseURL.appending(path: "/auth/v1/user")
        let payload = UpdateUserPayload(email: nil, password: nil, data: metadata)
        let updatedUser = try await send(updateURL, method: "PUT", body: payload, token: session.accessToken, prefer: nil, response: StreamoryUser.self)
        return StreamorySession(accessToken: session.accessToken, refreshToken: session.refreshToken, user: updatedUser)
    }

    func deleteAccount(password: String?, session: StreamorySession) async throws {
        if let password, !password.isEmpty {
            guard let email = session.user.email, !email.isEmpty else {
                throw StreamoryServiceError.server("Email du compte introuvable.".streamoryLocalized)
            }
            _ = try await signIn(email: email, password: password)
        }

        let url = supabaseURL.appending(path: "/functions/v1/delete-account-v2")
        print("[DELETE ACCOUNT] Service calling URL: \(url.absoluteString)")
        _ = try await send(url, method: "POST", body: EmptyJSON(), token: session.accessToken, prefer: nil, response: EmptyResponse.self)
    }

    private func userIdentities(session: StreamorySession) async throws -> [StreamoryIdentity] {
        let url = supabaseURL.appending(path: "/auth/v1/user")
        return try await send(url, method: "GET", body: EmptyBody?.none, token: session.accessToken, prefer: nil, response: StreamoryUser.self).identities
    }

    private func appleSession(idToken: String, nonce: String) async throws -> StreamorySession {
        let url = supabaseURL.appending(path: "/auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "id_token")])
        let payload = AppleIDTokenPayload(provider: "apple", idToken: idToken, nonce: nonce)
        return try await send(url, method: "POST", body: payload, token: nil, prefer: nil, response: AuthResponse.self).session
    }

    private func updateAppleMetadata(session: StreamorySession, fullName: String?, email: String?, country: String?, marksAppleLoginEnabled: Bool) async throws -> StreamorySession {
        var updatedSession = session
        var metadata = session.user.metadata
        if let fullName, !fullName.isEmpty {
            metadata["display_name"] = fullName
            metadata["username"] = fullName
            metadata["full_name"] = fullName
        }
        if let email, !email.isEmpty {
            metadata["email"] = email
        }
        if let country, !country.isEmpty {
            metadata["country"] = country
            metadata["country_label"] = Locale.current.localizedString(forRegionCode: country) ?? country
        }
        if marksAppleLoginEnabled {
            metadata["apple_login_enabled"] = "true"
        }

        if metadata != session.user.metadata {
            let updateURL = supabaseURL.appending(path: "/auth/v1/user")
            let payload = UpdateUserPayload(email: nil, password: nil, data: metadata)
            let updatedUser = try await send(updateURL, method: "PUT", body: payload, token: session.accessToken, prefer: nil, response: StreamoryUser.self)
            updatedSession = StreamorySession(accessToken: session.accessToken, refreshToken: session.refreshToken, user: updatedUser)
        }

        return updatedSession
    }

    func refreshSession(refreshToken: String?) async throws -> StreamorySession {
        guard let refreshToken, !refreshToken.isEmpty else {
            throw StreamoryServiceError.server("Aucun refresh token disponible.".streamoryLocalized)
        }

        let url = supabaseURL.appending(path: "/auth/v1/token")
            .appending(queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")])

        let payload = ["refresh_token": refreshToken]

        return try await send(
            url,
            method: "POST",
            body: payload,
            token: nil,
            prefer: nil,
            response: AuthResponse.self
        ).session
    }

    func resetPassword(email: String) async throws {
        let url = supabaseURL.appending(path: "/auth/v1/recover")
        let payload = ["email": email]
        _ = try await send(url, method: "POST", body: payload, token: nil, prefer: nil, response: EmptyResponse.self)
    }

    func signUp(email: String, password: String, username: String, birthDate: Date, country: String) async throws -> StreamorySession {
        let url = supabaseURL.appending(path: "/auth/v1/signup")
        let payload = SignupPayload(email: email, password: password, data: [
            "username": username,
            "display_name": username,
            "birth_date": Self.birthDateFormatter.string(from: birthDate),
            "country": country,
            "country_label": Locale.current.localizedString(forRegionCode: country) ?? country
        ])
        return try await send(url, method: "POST", body: payload, token: nil, prefer: nil, response: AuthResponse.self).session
    }

    func loadStartupAlerts() async throws -> [StreamoryAppAlert] {
        let now = ISO8601DateFormatter().string(from: Date())
        let url = supabaseURL
            .appending(path: "/rest/v1/alerts")
            .appending(queryItems: [
                URLQueryItem(name: "select", value: "id,title,message,type,placement"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "starts_at", value: "lte.\(now)"),
                URLQueryItem(name: "or", value: "(ends_at.is.null,ends_at.gte.\(now))"),
                URLQueryItem(name: "placement", value: "in.(global,home)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "1")
            ])
        return try await send(url, method: "GET", body: EmptyBody?.none, token: nil, prefer: nil, response: [StreamoryAppAlert].self)
    }

    func loadProfile(session: StreamorySession) async throws -> StreamoryProfile? {
        let url = supabaseURL
            .appending(path: "/rest/v1/profiles")
            .appending(queryItems: [
                URLQueryItem(name: "select", value: "user_id,username,country,premium_statut"),
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id.uuidString)")
            ])
        return try await send(url, method: "GET", body: EmptyBody?.none, token: session.accessToken, prefer: nil, response: [StreamoryProfile].self).first
    }

    func loadLibrary(session: StreamorySession) async throws -> [MediaItem] {
        let url = supabaseURL
            .appending(path: "/rest/v1/user_items")
            .appending(queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "order", value: "updated_at.desc")
            ])
        return try await send(url, method: "GET", body: EmptyBody?.none, token: session.accessToken, prefer: nil, response: [MediaItem].self)
    }

    func searchTVDB(query: String, language: String, session: StreamorySession?) async throws -> [TVDBSearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return [] }

        let normalizedQuery = cleanQuery.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        var searchQueries: [String] = []
        for candidate in [cleanQuery, normalizedQuery] {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !searchQueries.contains(trimmed) else { continue }
            searchQueries.append(trimmed)
        }

        var searchLanguages: [String] = []
        for candidate in [language, "eng", "fra", "deu", "spa", "ita", "por"] {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !trimmed.isEmpty, !searchLanguages.contains(trimmed) else { continue }
            searchLanguages.append(trimmed)
        }

        var loadedResults: [TVDBSearchResult] = []
        var seenSearches = Set<String>()

        for searchLanguage in searchLanguages {
            for searchQuery in searchQueries {
                let searchKey = "\(searchLanguage)|\(searchQuery.lowercased())"
                guard !seenSearches.contains(searchKey) else { continue }
                seenSearches.insert(searchKey)

                let url = supabaseURL
                    .appending(path: "/functions/v1/tvdb-search")
                    .appending(queryItems: [
                        URLQueryItem(name: "q", value: searchQuery),
                        URLQueryItem(name: "language", value: searchLanguage)
                    ])
                let payload = try await send(url, method: "GET", body: EmptyBody?.none, token: session?.accessToken ?? anonKey, prefer: nil, response: TVDBSearchResponse.self)
                loadedResults.append(contentsOf: payload.data.map { $0.preferringPoster(language: language) })
            }
        }

        var seenResults = Set<String>()
        return loadedResults.compactMap { result in
            guard isTVDBMediaSearchResult(result) else { return nil }
            guard result.kind == .movie || result.kind == .series else { return nil }

            let key = "\(result.kind.rawValue)-\(result.tvdbID.onlyDigitsOrSelf)"
            guard !seenResults.contains(key) else { return nil }
            seenResults.insert(key)
            return result
        }
    }

    private func isTVDBMediaSearchResult(_ result: TVDBSearchResult) -> Bool {
        let mediaTypes: Set<String> = ["movie", "movies", "film", "series", "serie", "show", "tv", "tvseries", "tv_series"]
        let rejectedTypes: Set<String> = ["person", "people", "actor", "actors", "character", "characters"]
        let typeLabels: Set<String> = ["type", "objectType", "entityType", "recordType", "resultType", "tvdbType"]

        for child in Mirror(reflecting: result).children {
            guard let label = child.label, typeLabels.contains(label) else { continue }

            if let rawType = normalizedSearchType(from: child.value) {
                if rejectedTypes.contains(rawType) || rawType.contains("person") || rawType.contains("people") || rawType.contains("actor") || rawType.contains("character") {
                    return false
                }

                if mediaTypes.contains(rawType) || rawType.contains("movie") || rawType.contains("series") {
                    return true
                }
            }
        }

        return result.kind == .movie || result.kind == .series
    }

    private func normalizedSearchType(from value: Any) -> String? {
        if let string = value as? String {
            return string
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .lowercased()
                .replacingOccurrences(of: "-", with: "_")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let optionalMirror = Mirror(reflecting: value)
        if optionalMirror.displayStyle == .optional,
           let wrapped = optionalMirror.children.first?.value {
            return normalizedSearchType(from: wrapped)
        }

        return nil
    }

    func loadSeriesEpisodes(tvdbID: String, language: String, session: StreamorySession) async throws -> [SeriesEpisode] {
        let normalizedTVDBID = tvdbID.onlyDigitsOrSelf
        guard !normalizedTVDBID.isEmpty, normalizedTVDBID.allSatisfy(\.isNumber) else {
            throw StreamoryServiceError.server("Identifiant TheTVDB invalide.".streamoryLocalized)
        }

        var episodes: [SeriesEpisode] = []
        let languagePath = language == "eng" ? "" : "/\(language)"
        for page in 0..<20 {
            let url = supabaseURL
                .appending(path: "/functions/v1/tvdb-search")
                .appending(queryItems: [
                    URLQueryItem(name: "endpoint", value: "series/\(normalizedTVDBID)/episodes/default\(languagePath)?page=\(page)")
                ])
            let payload = try await send(url, method: "GET", body: EmptyBody?.none, token: session.accessToken, prefer: nil, response: TVDBEpisodesResponse.self)
            episodes.append(contentsOf: payload.episodes)
            if payload.links?.next == nil && payload.episodes.count < 500 { break }
        }
        return episodes.sorted {
            if $0.seasonNumber == $1.seasonNumber { return $0.episodeNumber < $1.episodeNumber }
            if $0.seasonNumber == 0 { return false }
            if $1.seasonNumber == 0 { return true }
            return $0.seasonNumber < $1.seasonNumber
        }

    }

    func loadCast(for item: MediaItem, language: String, session: StreamorySession) async throws -> [TVDBCastMember] {
        let normalizedTVDBID = item.tvdbID.onlyDigitsOrSelf
        guard !normalizedTVDBID.isEmpty, normalizedTVDBID.allSatisfy(\.isNumber) else {
            return []
        }

        let kindPath = item.kind == .movie ? "movies" : "series"
        let endpoint = "\(kindPath)/\(normalizedTVDBID)/extended?meta=translations"
        let url = supabaseURL
            .appending(path: "/functions/v1/tvdb-search")
            .appending(queryItems: [
                URLQueryItem(name: "endpoint", value: endpoint),
                URLQueryItem(name: "language", value: language)
            ])

        let payload = try await send(url, method: "GET", body: EmptyBody?.none, token: session.accessToken, prefer: nil, response: TVDBMediaDetailsResponse.self)
        return payload.data?.castMembers ?? []
    }

    func localizedMediaItems(_ items: [MediaItem], language: String, session: StreamorySession) async -> [MediaItem] {
        await withTaskGroup(of: (Int, MediaItem).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    do {
                        let localizedItem = try await localizedMediaItem(item, language: language, session: session)
                        return (index, localizedItem)
                    } catch {
                        return (index, item)
                    }
                }
            }

            var localizedItems = items
            for await (index, item) in group {
                localizedItems[index] = item
            }
            return localizedItems
        }
    }

    private func localizedMediaItem(_ item: MediaItem, language: String, session: StreamorySession) async throws -> MediaItem {
        let normalizedTVDBID = item.tvdbID.onlyDigitsOrSelf
        guard !normalizedTVDBID.isEmpty, normalizedTVDBID.allSatisfy(\.isNumber) else {
            return item
        }

        let endpoint = "\(item.kind.rawValue == MediaKind.movie.rawValue ? "movies" : "series")/\(normalizedTVDBID)/extended?meta=translations"
        let url = supabaseURL
            .appending(path: "/functions/v1/tvdb-search")
            .appending(queryItems: [
                URLQueryItem(name: "endpoint", value: endpoint)
            ])
        let payload = try await send(url, method: "GET", body: EmptyBody?.none, token: session.accessToken, prefer: nil, response: TVDBMediaDetailsResponse.self)
        guard let details = payload.data else { return item }
        let artworks = (try? await loadMediaArtworks(kind: item.kind, tvdbID: normalizedTVDBID, session: session)) ?? []

        var localizedItem = item
        localizedItem.title = details.localizedTitle(language: language) ?? item.title
        localizedItem.imageURL = details.localizedImageURL(language: language, additionalArtworks: artworks) ?? item.imageURL
        localizedItem.year = details.year ?? item.year
        localizedItem.overview = details.localizedOverview(language: language) ?? item.overview
        localizedItem.episodeRuntime = details.episodeRuntime ?? item.episodeRuntime
        localizedItem.seriesStatus = details.localizedSeriesStatus ?? item.seriesStatus
        localizedItem.genres = details.genreNames.isEmpty ? item.genres : details.genreNames
        return localizedItem
    }

    private func loadMediaArtworks(kind: MediaKind, tvdbID: String, session: StreamorySession) async throws -> [TVDBMediaArtwork] {
        let kindPath = kind == .movie ? "movies" : "series"
        var artworks: [TVDBMediaArtwork] = []

        for page in 0..<3 {
            let url = supabaseURL
                .appending(path: "/functions/v1/tvdb-search")
                .appending(queryItems: [
                    URLQueryItem(name: "endpoint", value: "\(kindPath)/\(tvdbID)/artworks?page=\(page)")
                ])
            let payload = try await send(url, method: "GET", body: EmptyBody?.none, token: session.accessToken, prefer: nil, response: TVDBArtworksResponse.self)
            artworks.append(contentsOf: payload.artworks)
            if payload.links?.next == nil && payload.artworks.count < 500 { break }
        }

        return artworks
    }

    func upsert(_ item: MediaItem, session: StreamorySession) async throws -> MediaItem {
        let url = supabaseURL
            .appending(path: "/rest/v1/user_items")
            .appending(queryItems: [URLQueryItem(name: "on_conflict", value: "user_id,tvdb_id,media_type")])
        let payload = UserItemPayload(item: item, userID: session.user.id)
        return try await send(
            url,
            method: "POST",
            body: payload,
            token: session.accessToken,
            prefer: "resolution=merge-duplicates,return=representation",
            response: [MediaItem].self
        ).first ?? item
    }

    func updateStatus(item: MediaItem, status: WatchStatus, session: StreamorySession) async throws {
        let url = supabaseURL
            .appending(path: "/rest/v1/user_items")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(item.id.uuidString)")])
        let payload = StatusPayload(status: status.rawValue, updatedAt: Date())
        _ = try await send(url, method: "PATCH", body: payload, token: session.accessToken, prefer: "return=minimal", response: EmptyResponse.self)
    }

    func upsertEpisodeWatch(episode: SeriesEpisode, series: MediaItem, rewatchCount: Int, session: StreamorySession) async throws {
        let normalizedSeriesTVDBID = series.tvdbID.onlyDigitsOrSelf
        let url = supabaseURL
            .appending(path: "/rest/v1/user_episode_watches")
            .appending(queryItems: [URLQueryItem(name: "on_conflict", value: "user_id,series_tvdb_id,episode_tvdb_id")])
        let payload = EpisodeWatchPayload(
            userID: session.user.id,
            seriesTvdbID: normalizedSeriesTVDBID,
            seriesTitle: series.title,
            episode: episode,
            watchedAt: Date(),
            watchedCount: rewatchCount + 1,
            rewatchCount: rewatchCount,
            updatedAt: Date()
        )
        _ = try await send(
            url,
            method: "POST",
            body: payload,
            token: session.accessToken,
            prefer: "resolution=merge-duplicates,return=minimal",
            response: EmptyResponse.self
        )
    }

    func deleteEpisodeWatch(episodeID: String, session: StreamorySession) async throws {
        let url = supabaseURL
            .appending(path: "/rest/v1/user_episode_watches")
            .appending(queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(session.user.id.uuidString)"),
                URLQueryItem(name: "episode_tvdb_id", value: "eq.\(episodeID)")
            ])
        _ = try await send(url, method: "DELETE", body: EmptyBody?.none, token: session.accessToken, prefer: "return=minimal", response: EmptyResponse.self)
    }

    func delete(item: MediaItem, session: StreamorySession) async throws {
        let url = supabaseURL
            .appending(path: "/rest/v1/user_items")
            .appending(queryItems: [URLQueryItem(name: "id", value: "eq.\(item.id.uuidString)")])
        _ = try await send(url, method: "DELETE", body: EmptyBody?.none, token: session.accessToken, prefer: "return=minimal", response: EmptyResponse.self)
    }

    func loadFriends(session: StreamorySession) async throws -> [StreamoryFriend] {
        let url = supabaseURL.appending(path: "/rest/v1/rpc/list_streamory_friends")
        return try await send(url, method: "POST", body: EmptyJSON(), token: session.accessToken, prefer: nil, response: [StreamoryFriend].self)
    }

    func searchProfiles(query: String, session: StreamorySession) async throws -> [StreamoryProfileSearchResult] {
        let url = supabaseURL.appending(path: "/rest/v1/rpc/search_streamory_profiles")
        let payload = ProfileSearchPayload(candidate: query)
        return try await send(url, method: "POST", body: payload, token: session.accessToken, prefer: nil, response: [StreamoryProfileSearchResult].self)
    }

    func sendFriendRequest(targetUserID: UUID, session: StreamorySession) async throws {
        let url = supabaseURL.appending(path: "/rest/v1/rpc/send_streamory_friend_request")
        let payload = FriendRequestPayload(targetUserID: targetUserID)
        _ = try await send(url, method: "POST", body: payload, token: session.accessToken, prefer: nil, response: EmptyResponse.self)
    }

    func setFriendCanAddPermission(friendID: UUID, allowed: Bool, session: StreamorySession) async throws {
        let url = supabaseURL.appending(path: "/rest/v1/rpc/set_streamory_friend_can_add")
        let payload = FriendPermissionPayload(targetUserID: friendID, allowed: allowed)
        _ = try await send(url, method: "POST", body: payload, token: session.accessToken, prefer: nil, response: EmptyResponse.self)
    }

    func friendCanAddPermission(friendID: UUID, session: StreamorySession) async throws -> Bool {
        let url = supabaseURL.appending(path: "/rest/v1/rpc/get_streamory_friend_can_add")
        let payload = FriendWatchlistPayload(targetUserID: friendID)
        return try await send(url, method: "POST", body: payload, token: session.accessToken, prefer: nil, response: Bool.self)
    }

    func mutualFriendCanAddPermission(friendID: UUID, session: StreamorySession) async throws -> Bool {
        let url = supabaseURL.appending(path: "/rest/v1/rpc/get_streamory_friend_can_add_mutual")
        let payload = FriendWatchlistPayload(targetUserID: friendID)
        return try await send(url, method: "POST", body: payload, token: session.accessToken, prefer: nil, response: Bool.self)
    }

    func addToMutualWatchlist(_ item: MediaItem, friendID: UUID, session: StreamorySession) async throws {
        let upsertURL = supabaseURL
            .appending(path: "/rest/v1/user_items")
            .appending(queryItems: [URLQueryItem(name: "on_conflict", value: "user_id,tvdb_id,media_type")])

        let currentUserPayload = UserItemPayload(item: item, userID: session.user.id, forcedStatus: WatchStatus.watchlist)
        _ = try await send(
            upsertURL,
            method: "POST",
            body: currentUserPayload,
            token: session.accessToken,
            prefer: "resolution=merge-duplicates,return=minimal",
            response: EmptyResponse.self
        )

        let insertURL = supabaseURL.appending(path: "/rest/v1/user_items")
        let friendPayload = UserItemPayload(item: item, userID: friendID, forcedStatus: WatchStatus.watchlist)
        do {
            _ = try await send(
                insertURL,
                method: "POST",
                body: friendPayload,
                token: session.accessToken,
                prefer: "return=minimal",
                response: EmptyResponse.self
            )
        } catch StreamoryServiceError.server(let message) where message.contains("23505") || message.localizedCaseInsensitiveContains("duplicate key") {
            return
        }
    }

    func loadFriendWatchlist(friendID: UUID, session: StreamorySession) async throws -> [MediaItem] {
        let url = supabaseURL.appending(path: "/rest/v1/rpc/list_streamory_friend_watchlist")
        let payload = FriendWatchlistPayload(targetUserID: friendID)
        return try await send(url, method: "POST", body: payload, token: session.accessToken, prefer: nil, response: [MediaItem].self)
    }

    func loadPublicLibrary(userID: UUID, session: StreamorySession) async throws -> [MediaItem] {
        let url = supabaseURL.appending(path: "/rest/v1/rpc/get_streamory_library")
        let payload = FriendWatchlistPayload(targetUserID: userID)
        return try await send(url, method: "POST", body: payload, token: session.accessToken, prefer: nil, response: [MediaItem].self)
    }

    func loadEpisodeWatchStates(userID: UUID, tvdbID: String, session: StreamorySession) async throws -> [EpisodeWatchState] {
        let normalizedTVDBID = tvdbID.onlyDigitsOrSelf
        let url = supabaseURL.appending(path: "/rest/v1/rpc/get_streamory_episode_watches")

        struct Payload: Codable {
            let targetUserID: UUID
            let targetSeriesTvdbID: String

            enum CodingKeys: String, CodingKey {
                case targetUserID = "target_user_id"
                case targetSeriesTvdbID = "target_series_tvdb_id"
            }
        }

        return try await send(
            url,
            method: "POST",
            body: Payload(targetUserID: userID, targetSeriesTvdbID: normalizedTVDBID),
            token: session.accessToken,
            prefer: nil,
            response: [EpisodeWatchState].self
        )
    }

    func completeAppleProfile(birthDate: Date, country: String, session: StreamorySession) async throws -> StreamorySession {
        let url = supabaseURL.appending(path: "/auth/v1/user")
        var metadata = session.user.metadata
        metadata["birth_date"] = Self.birthDateFormatter.string(from: birthDate)
        metadata["country"] = country
        metadata["country_label"] = Locale.current.localizedString(forRegionCode: country) ?? country

        let payload = UpdateUserPayload(email: nil, password: nil, data: metadata)
        let updatedUser = try await send(url, method: "PUT", body: payload, token: session.accessToken, prefer: nil, response: StreamoryUser.self)
        return StreamorySession(accessToken: session.accessToken, refreshToken: session.refreshToken, user: updatedUser)
    }

    func updateProfile(
        username: String,
        country: String,
        email: String,
        currentPassword: String,
        newPassword: String,
        session: StreamorySession
    ) async throws -> StreamorySession {
        if !newPassword.isEmpty && !currentPassword.isEmpty {
            guard let currentEmail = session.user.email else { throw StreamoryServiceError.server("Email actuel introuvable.".streamoryLocalized) }
            _ = try await signIn(email: currentEmail, password: currentPassword)
        }

        let url = supabaseURL.appending(path: "/auth/v1/user")
        var metadata = session.user.metadata
        metadata["display_name"] = username
        metadata["username"] = username
        metadata["country"] = country

        let payload = UpdateUserPayload(
            email: email == session.user.email ? nil : email,
            password: newPassword.isEmpty ? nil : newPassword,
            data: metadata
        )
        let updatedUser = try await send(url, method: "PUT", body: payload, token: session.accessToken, prefer: nil, response: StreamoryUser.self)
        return StreamorySession(accessToken: session.accessToken, refreshToken: session.refreshToken, user: updatedUser)
    }

    private func send<Body: Encodable, Response: Decodable>(
        _ url: URL,
        method: String,
        body: Body?,
        token: String?,
        prefer: String?,
        response: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token ?? anonKey)", forHTTPHeaderField: "Authorization")
        if let prefer { request.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let body { request.httpBody = try encoder.encode(body) }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw StreamoryServiceError.invalidResponse }

        if url.path.contains("/functions/v1/store-apple-token") || url.path.contains("/functions/v1/store-apple-token-v2") {
            let rawResponse = String(data: data, encoding: .utf8) ?? ""
            print("[APPLE TOKEN] HTTP status: \(httpResponse.statusCode)")
            print("[APPLE TOKEN] Raw response: \(rawResponse)")
        }

        if url.path.contains("/functions/v1/delete-account") {
            let rawResponse = String(data: data, encoding: .utf8) ?? ""
            print("[DELETE ACCOUNT] Service HTTP status: \(httpResponse.statusCode)")
            print("[DELETE ACCOUNT] Service raw response: \(rawResponse)")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Erreur Supabase inconnue.".streamoryLocalized
            throw StreamoryServiceError.server(message)
        }

        if Response.self == EmptyResponse.self {
            return EmptyResponse() as! Response
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch let DecodingError.keyNotFound(key, context) {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Réponse illisible.".streamoryLocalized
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            throw StreamoryServiceError.server("Décodage impossible : clé manquante '\(key.stringValue)' à '\(path)'. Réponse serveur : \(rawResponse)")
        } catch let DecodingError.typeMismatch(type, context) {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Réponse illisible.".streamoryLocalized
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            throw StreamoryServiceError.server("Décodage impossible : type incorrect '\(type)' à '\(path)'. Réponse serveur : \(rawResponse)")
        } catch let DecodingError.valueNotFound(type, context) {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Réponse illisible.".streamoryLocalized
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            throw StreamoryServiceError.server("Décodage impossible : valeur manquante '\(type)' à '\(path)'. Réponse serveur : \(rawResponse)")
        } catch let DecodingError.dataCorrupted(context) {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Réponse illisible.".streamoryLocalized
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            throw StreamoryServiceError.server("Décodage impossible : données corrompues à '\(path)'. Réponse serveur : \(rawResponse)")
        } catch {
            let rawResponse = String(data: data, encoding: .utf8) ?? "Réponse illisible.".streamoryLocalized
            throw StreamoryServiceError.server("Décodage impossible : \(error.localizedDescription). Réponse serveur : \(rawResponse)")
        }
    }

    private static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let user: StreamoryUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }

    var session: StreamorySession {
        StreamorySession(accessToken: accessToken, refreshToken: refreshToken, user: user)
    }
}

private struct SignupPayload: Codable {
    let email: String
    let password: String
    let data: [String: String]
}

private struct AppleIDTokenPayload: Codable {
    let provider: String
    let idToken: String
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case provider
        case idToken = "id_token"
        case nonce
    }
}

private struct AppleAuthorizationCodePayload: Encodable {
    let authorizationCode: String

    enum CodingKeys: String, CodingKey {
        case authorizationCode
        case authorizationCodeSnake = "authorization_code"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(authorizationCode, forKey: .authorizationCode)
        try container.encode(authorizationCode, forKey: .authorizationCodeSnake)
    }
}

private struct StoreAppleTokenResponse: Codable {
    let ok: Bool
    let storedUserID: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case storedUserID = "stored_user_id"
    }
}

private struct TVDBSearchResponse: Decodable {
    let data: [TVDBSearchResult]

    enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent([TVDBSearchResult].self, forKey: .data) ?? []
    }
}

private struct TVDBEpisodesResponse: Decodable {
    let data: TVDBEpisodeData?
    let links: TVDBPaginationLinks?

    var episodes: [SeriesEpisode] {
        data?.episodes ?? []
    }
}

private struct TVDBEpisodeData: Decodable {
    let episodes: [SeriesEpisode]

    enum CodingKeys: String, CodingKey {
        case episodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        episodes = try container.decodeIfPresent([SeriesEpisode].self, forKey: .episodes) ?? []
    }
}

private struct TVDBPaginationLinks: Decodable {
    let next: String?
}

private struct TVDBMediaDetailsResponse: Decodable {
    let data: TVDBMediaDetails?
}

private struct TVDBArtworksResponse: Decodable {
    let data: TVDBArtworkPayload?
    let links: TVDBPaginationLinks?

    var artworks: [TVDBMediaArtwork] {
        data?.artworks ?? []
    }
}

private enum TVDBArtworkPayload: Decodable {
    case list([TVDBMediaArtwork])
    case grouped([TVDBMediaArtwork])

    var artworks: [TVDBMediaArtwork] {
        switch self {
        case .list(let artworks), .grouped(let artworks):
            artworks
        }
    }

    init(from decoder: Decoder) throws {
        if let artworks = try? [TVDBMediaArtwork](from: decoder) {
            self = .list(artworks)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let artworks = (try? container.decodeIfPresent([TVDBMediaArtwork].self, forKey: .artworks)) ?? []
        self = .grouped(artworks)
    }

    private enum CodingKeys: String, CodingKey {
        case artworks
    }
}

private struct TVDBMediaDetails: Decodable {
    let name: String?
    let title: String?
    let seriesName: String?
    let image: String?
    let poster: String?
    let posterURL: String?
    let imageURL: String?
    let firstAired: String?
    let yearValue: String?
    let released: String?
    let releaseDate: String?
    let averageRuntime: Int?
    let runtime: Int?
    let runtimeMinutes: Int?
    let status: TVDBSeriesStatus?
    let genres: [TVDBGenre]
    let overview: String?
    let description: String?
    let artworks: [TVDBMediaArtwork]
    let translations: TVDBTranslations?
    let characters: [TVDBCastMember]
    let cast: [TVDBCastMember]
    let people: [TVDBCastMember]

    enum CodingKeys: String, CodingKey {
        case name
        case title
        case seriesName
        case image
        case poster
        case posterURL = "poster_url"
        case imageURL = "image_url"
        case firstAired
        case yearValue = "year"
        case released
        case releaseDate
        case averageRuntime
        case runtime
        case runtimeMinutes
        case status
        case genres
        case overview
        case description
        case artworks
        case translations
        case characters
        case cast
        case people
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeFlexibleString(forKey: .name)
        title = try container.decodeFlexibleString(forKey: .title)
        seriesName = try container.decodeFlexibleString(forKey: .seriesName)
        image = try container.decodeFlexibleString(forKey: .image)
        poster = try container.decodeFlexibleString(forKey: .poster)
        posterURL = try container.decodeFlexibleString(forKey: .posterURL)
        imageURL = try container.decodeFlexibleString(forKey: .imageURL)
        firstAired = try container.decodeFlexibleString(forKey: .firstAired)
        yearValue = try container.decodeFlexibleString(forKey: .yearValue)
        released = try container.decodeFlexibleString(forKey: .released)
        releaseDate = try container.decodeFlexibleString(forKey: .releaseDate)
        averageRuntime = try container.decodeFlexibleInt(forKey: .averageRuntime)
        runtime = try container.decodeFlexibleInt(forKey: .runtime)
        runtimeMinutes = try container.decodeFlexibleInt(forKey: .runtimeMinutes)
        status = try? container.decodeIfPresent(TVDBSeriesStatus.self, forKey: .status)
        genres = (try? container.decodeIfPresent([TVDBGenre].self, forKey: .genres)) ?? []
        overview = try container.decodeFlexibleString(forKey: .overview)
        description = try container.decodeFlexibleString(forKey: .description)
        artworks = (try? container.decodeIfPresent([TVDBMediaArtwork].self, forKey: .artworks)) ?? []
        translations = try? container.decodeIfPresent(TVDBTranslations.self, forKey: .translations)
        characters = (try? container.decodeIfPresent([TVDBCastMember].self, forKey: .characters)) ?? []
        cast = (try? container.decodeIfPresent([TVDBCastMember].self, forKey: .cast)) ?? []
        people = (try? container.decodeIfPresent([TVDBCastMember].self, forKey: .people)) ?? []
    }

    var year: String? {
        [released, releaseDate, firstAired, yearValue]
            .compactMap { $0 }
            .compactMap { value in
                String(value.prefix(4).filter(\.isNumber))
            }
            .first { $0.count == 4 }
    }

    var episodeRuntime: Int? {
        [averageRuntime, runtime, runtimeMinutes]
            .compactMap { $0 }
            .first { $0 > 0 }
    }

    var localizedSeriesStatus: String? {
        guard let statusName = status?.name?.trimmingCharacters(in: .whitespacesAndNewlines), !statusName.isEmpty else {
            return nil
        }

        let normalized = statusName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        if normalized.contains("continuing") || normalized.contains("ongoing") || normalized.contains("returning") {
            return "En cours".streamoryLocalized
        }
        if normalized.contains("ended") || normalized.contains("finished") || normalized.contains("termine") {
            return "Terminée".streamoryLocalized
        }
        if normalized.contains("upcoming") || normalized.contains("in development") || normalized.contains("planned") || normalized.contains("a venir") {
            return "À venir".streamoryLocalized
        }
        return statusName
    }

    var genreNames: [String] {
        genres.compactMap { genre in
            let name = genre.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            return name?.isEmpty == false ? name : nil
        }
    }

    var castMembers: [TVDBCastMember] {
        let combined = characters + cast + people
        var seenIDs: Set<String> = []
        return combined.filter { member in
            guard !seenIDs.contains(member.id) else { return false }
            seenIDs.insert(member.id)
            return !member.actorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func localizedTitle(language: String) -> String? {
        translations?.localizedValue(fields: [.name, .title], language: language)
            ?? firstNonEmpty(name, title, seriesName)
    }

    func localizedOverview(language: String) -> String? {
        translations?.localizedValue(fields: [.overview, .description], language: language)
            ?? firstNonEmpty(overview, description)
    }

    func localizedImageURL(language: String, additionalArtworks: [TVDBMediaArtwork]) -> String? {
        TVDBMediaArtwork.preferredImageURL(in: additionalArtworks + artworks, language: language)
            ?? firstNonEmpty(imageURL, posterURL, poster, image)?.streamoryAbsoluteTVDBImageURL
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values.first { value in
            guard let value else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? nil
    }
}

private struct TVDBSeriesStatus: Decodable {
    let name: String?

    enum CodingKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        if let value = try? String(from: decoder) {
            name = value
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeFlexibleString(forKey: .name)
    }
}

private struct TVDBGenre: Decodable {
    let name: String?

    enum CodingKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        if let value = try? String(from: decoder) {
            name = value
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeFlexibleString(forKey: .name)
    }
}

private struct TVDBMediaArtwork: Decodable, Hashable {
    let image: String?
    let thumbnail: String?
    let url: String?
    let language: String?
    let languageCode: String?
    let iso6392: String?
    let type: String?
    let typeName: String?
    let artworkType: String?

    enum CodingKeys: String, CodingKey {
        case image
        case thumbnail
        case url
        case language
        case languageCode = "language_code"
        case iso6392 = "iso_639_2"
        case type
        case typeName
        case artworkType
    }

    var imageURL: String? {
        (image ?? thumbnail ?? url)?.streamoryAbsoluteTVDBImageURL
    }

    var normalizedLanguage: String {
        (language ?? languageCode ?? iso6392 ?? "").lowercased()
    }

    var isPoster: Bool {
        let normalizedType = [type, typeName, artworkType]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        return normalizedType.contains("poster") || normalizedType.contains("cover")
    }

    static func preferredImageURL(in artworks: [TVDBMediaArtwork], language: String) -> String? {
        let posters = artworks.filter { $0.isPoster && $0.imageURL != nil }
        let candidates = posters.isEmpty ? artworks.filter { $0.imageURL != nil } : posters
        guard !candidates.isEmpty else { return nil }

        return candidates.first { $0.normalizedLanguage.streamoryMatchesTVDBLanguage(language) }?.imageURL
            ?? candidates.first { $0.normalizedLanguage.streamoryMatchesTVDBLanguage("eng") }?.imageURL
            ?? candidates.first { $0.normalizedLanguage.isEmpty }?.imageURL
            ?? candidates.first?.imageURL
    }
}

private struct TVDBTranslations: Decodable {
    let entries: [TVDBTranslationEntry]

    init(from decoder: Decoder) throws {
        if let directEntries = try? [TVDBTranslationEntry](from: decoder) {
            entries = directEntries
            return
        }

        let container = try decoder.singleValueContainer()
        if let keyedEntries = try? container.decode([String: TVDBTranslationEntry].self) {
            entries = keyedEntries.map { key, entry in
                entry.withFallbackLanguage(key)
            }
            return
        }

        if let groupedEntries = try? container.decode([String: [TVDBTranslationEntry]].self) {
            entries = groupedEntries.flatMap { key, values in
                values.map { $0.withFallbackLanguage(key) }
            }
            return
        }

        entries = []
    }

    func localizedValue(fields: [TVDBTranslationField], language: String) -> String? {
        value(fields: fields, language: language) ?? value(fields: fields, language: "eng")
    }

    private func value(fields: [TVDBTranslationField], language: String) -> String? {
        guard let entry = entries.first(where: { translation in
            translation.languageCodes.contains { $0.streamoryMatchesTVDBLanguage(language) }
        }) else {
            return nil
        }

        for field in fields {
            if let value = entry.value(for: field), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }
}

private struct TVDBTranslationEntry: Decodable {
    let language: String?
    let languageCode: String?
    let iso6392: String?
    let name: String?
    let title: String?
    let overview: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case language
        case languageCode = "language_code"
        case iso6392 = "iso_639_2"
        case name
        case translatedName
        case title
        case translatedTitle
        case overview
        case translatedOverview
        case description
        case translatedDescription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        language = try container.decodeFlexibleString(forKey: .language)
        languageCode = try container.decodeFlexibleString(forKey: .languageCode)
        iso6392 = try container.decodeFlexibleString(forKey: .iso6392)
        name = try container.decodeFlexibleString(forKey: .name)
            ?? container.decodeFlexibleString(forKey: .translatedName)
        title = try container.decodeFlexibleString(forKey: .title)
            ?? container.decodeFlexibleString(forKey: .translatedTitle)
        overview = try container.decodeFlexibleString(forKey: .overview)
            ?? container.decodeFlexibleString(forKey: .translatedOverview)
        description = try container.decodeFlexibleString(forKey: .description)
            ?? container.decodeFlexibleString(forKey: .translatedDescription)
    }

    private init(language: String?, languageCode: String?, iso6392: String?, name: String?, title: String?, overview: String?, description: String?) {
        self.language = language
        self.languageCode = languageCode
        self.iso6392 = iso6392
        self.name = name
        self.title = title
        self.overview = overview
        self.description = description
    }

    var languageCodes: Set<String> {
        Set([language, languageCode, iso6392]
            .compactMap { $0?.lowercased() }
            .filter { !$0.isEmpty })
    }

    func withFallbackLanguage(_ fallbackLanguage: String) -> TVDBTranslationEntry {
        TVDBTranslationEntry(
            language: language ?? fallbackLanguage,
            languageCode: languageCode,
            iso6392: iso6392,
            name: name,
            title: title,
            overview: overview,
            description: description
        )
    }

    func value(for field: TVDBTranslationField) -> String? {
        switch field {
        case .name: name
        case .title: title
        case .overview: overview
        case .description: description
        }
    }
}

private enum TVDBTranslationField {
    case name
    case title
    case overview
    case description
}

private struct UserItemPayload: Codable {
    let userID: UUID
    let tvdbID: String
    let mediaType: String
    let title: String
    let imageURL: String?
    let year: String?
    let overview: String?
    let status: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case tvdbID = "tvdb_id"
        case mediaType = "media_type"
        case title
        case imageURL = "image_url"
        case year
        case overview
        case status
        case updatedAt = "updated_at"
    }

    init(item: MediaItem, userID: UUID, forcedStatus: WatchStatus? = nil) {
        self.userID = userID
        self.tvdbID = item.tvdbID
        self.mediaType = item.kind.rawValue
        self.title = item.title
        self.imageURL = item.imageURL
        self.year = item.year
        self.overview = item.overview
        self.status = (forcedStatus ?? item.status).rawValue
        self.updatedAt = Date()
    }
}


private struct StatusPayload: Codable {
    let status: String
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case status
        case updatedAt = "updated_at"
    }
}

private struct EpisodeWatchPayload: Codable {
    let userID: UUID
    let seriesTvdbID: String
    let seriesTitle: String
    let episodeTvdbID: String
    let seasonNumber: Int
    let episodeNumber: Int
    let episodeName: String
    let watchedAt: Date
    let watchedCount: Int
    let rewatchCount: Int
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case seriesTvdbID = "series_tvdb_id"
        case seriesTitle = "series_title"
        case episodeTvdbID = "episode_tvdb_id"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case episodeName = "episode_name"
        case watchedAt = "watched_at"
        case watchedCount = "watched_count"
        case rewatchCount = "rewatch_count"
        case updatedAt = "updated_at"
    }

    init(userID: UUID, seriesTvdbID: String, seriesTitle: String, episode: SeriesEpisode, watchedAt: Date, watchedCount: Int, rewatchCount: Int, updatedAt: Date) {
        self.userID = userID
        self.seriesTvdbID = seriesTvdbID
        self.seriesTitle = seriesTitle
        self.episodeTvdbID = episode.id
        self.seasonNumber = episode.seasonNumber
        self.episodeNumber = episode.episodeNumber
        self.episodeName = episode.title
        self.watchedAt = watchedAt
        self.watchedCount = watchedCount
        self.rewatchCount = rewatchCount
        self.updatedAt = updatedAt
    }
}

private struct ProfileSearchPayload: Codable {
    let candidate: String
}

private struct FriendRequestPayload: Codable {
    let targetUserID: UUID

    enum CodingKeys: String, CodingKey {
        case targetUserID = "target_user_id"
    }
}

private struct FriendWatchlistPayload: Codable {
    let targetUserID: UUID

    enum CodingKeys: String, CodingKey {
        case targetUserID = "target_user_id"
    }
}


private struct FriendPermissionPayload: Codable {
    let targetUserID: UUID
    let allowed: Bool

    enum CodingKeys: String, CodingKey {
        case targetUserID = "target_user_id"
        case allowed
    }
}


private struct UpdateUserPayload: Codable {
    let email: String?
    let password: String?
    let data: [String: String]
}


private struct DeleteAccountPayload: Codable {
    let password: String?

    enum CodingKeys: String, CodingKey {
        case password = "delete_password"
    }
}


private struct EmptyJSON: Codable {}
private struct EmptyBody: Codable {}
private struct EmptyResponse: Codable {}

enum StreamoryServiceError: LocalizedError {
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Réponse réseau invalide.".streamoryLocalized
        case .server(let message):
            message
        }
    }
}

extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url ?? self
    }
}

struct SeriesEpisode: Codable, Identifiable, Hashable {
    let id: String
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String
    let airDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case tvdbID = "tvdb_id"
        case seasonNumber
        case airedSeason
        case season
        case episodeNumber
        case airedEpisodeNumber
        case number
        case title
        case name
        case episodeName = "episode_name"
        case aired
        case firstAired
        case airDate
        case watchedAt = "watched_at"
        case storedID = "episode_tvdb_id"
        case storedSeasonNumber = "season_number"
        case storedEpisodeNumber = "episode_number"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try container.decodeFlexibleString(forKey: .id)
            ?? container.decodeFlexibleString(forKey: .tvdbID)
            ?? container.decodeFlexibleString(forKey: .storedID)
            ?? UUID().uuidString).onlyDigitsOrSelf
        seasonNumber = try container.decodeFlexibleInt(forKey: .seasonNumber)
            ?? container.decodeFlexibleInt(forKey: .airedSeason)
            ?? container.decodeFlexibleInt(forKey: .season)
            ?? container.decodeFlexibleInt(forKey: .storedSeasonNumber)
            ?? 0
        episodeNumber = try container.decodeFlexibleInt(forKey: .number)
            ?? container.decodeFlexibleInt(forKey: .episodeNumber)
            ?? container.decodeFlexibleInt(forKey: .airedEpisodeNumber)
            ?? container.decodeFlexibleInt(forKey: .storedEpisodeNumber)
            ?? 0
        title = try container.decodeFlexibleString(forKey: .name)
            ?? container.decodeFlexibleString(forKey: .title)
            ?? container.decodeFlexibleString(forKey: .episodeName)
            ?? "Episode sans titre".streamoryLocalized

        let rawDate = try container.decodeFlexibleString(forKey: .aired)
            ?? container.decodeFlexibleString(forKey: .firstAired)
            ?? container.decodeFlexibleString(forKey: .airDate)
            ?? container.decodeFlexibleString(forKey: .watchedAt)
        airDate = Self.dateFormatter.date(from: String(rawDate?.prefix(10) ?? ""))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(seasonNumber, forKey: .seasonNumber)
        try container.encode(episodeNumber, forKey: .episodeNumber)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(airDate.map(Self.dateFormatter.string(from:)), forKey: .airDate)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var isReleased: Bool {
        guard let airDate else { return true }
        return airDate <= Calendar.current.startOfDay(for: Date())
    }

    var displayNumber: String {
        seasonNumber == 0 ? "SP\(String(format: "%02d", episodeNumber))" : "E\(String(format: "%02d", episodeNumber))"
    }

    var formattedAirDate: String {
        guard let airDate else { return "Date inconnue".streamoryLocalized }
        return airDate.formatted(date: .abbreviated, time: .omitted)
    }
}

struct EpisodeWatchState: Codable, Hashable {
    let episodeID: String
    let seasonNumber: Int
    let episodeNumber: Int
    let watchCount: Int
    let rewatchCount: Int

    enum CodingKeys: String, CodingKey {
        case episodeID = "episode_tvdb_id"
        case seasonNumber = "season_number"
        case episodeNumber = "episode_number"
        case watchCount = "watched_count"
        case rewatchCount = "rewatch_count"
    }
}
