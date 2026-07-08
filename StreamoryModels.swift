import Foundation
import SwiftUI

struct StreamorySession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let user: StreamoryUser
}

struct StreamoryUser: Codable, Equatable {
    let id: UUID
    let email: String?
    let metadata: [String: String]
    let identities: [StreamoryIdentity]

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case metadata = "user_metadata"
        case identities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        identities = try container.decodeIfPresent([StreamoryIdentity].self, forKey: .identities) ?? []
        if let decodedMetadata = try? container.decodeIfPresent([String: FlexibleMetadataValue].self, forKey: .metadata) {
            metadata = decodedMetadata.compactMapValues(\.stringValue)
        } else {
            metadata = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(identities, forKey: .identities)
    }
}

struct StreamoryIdentity: Codable, Equatable {
    let id: String
    let identityID: String
    let provider: String

    enum CodingKeys: String, CodingKey {
        case id
        case identityID = "identity_id"
        case provider
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        identityID = try container.decodeIfPresent(String.self, forKey: .identityID) ?? id
        provider = try container.decode(String.self, forKey: .provider)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(identityID, forKey: .identityID)
        try container.encode(provider, forKey: .provider)
    }
}

private enum FlexibleMetadataValue: Decodable {
    case string(String)
    case bool(Bool)
    case number(Double)
    case empty

    var stringValue: String? {
        switch self {
        case .string(let value): value
        case .bool(let value): String(value)
        case .number(let value): String(value)
        case .empty: nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .empty
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else {
            self = .empty
        }
    }
}

struct StreamoryProfile: Codable, Equatable {
    let userID: UUID
    let username: String
    let country: String?
    let premiumStatut: Bool?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case country
        case premiumStatut = "premium_statut"
    }

    init(userID: UUID, username: String, country: String?, premiumStatut: Bool? = false) {
        self.userID = userID
        self.username = username
        self.country = country
        self.premiumStatut = premiumStatut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(UUID.self, forKey: .userID)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? "Utilisateur".streamoryLocalized
        country = try container.decodeIfPresent(String.self, forKey: .country)
        premiumStatut = try container.decodeIfPresent(Bool.self, forKey: .premiumStatut) ?? false
    }
}

struct StreamoryFriend: Identifiable, Codable, Equatable, Hashable {
    let userID: UUID
    let username: String
    let country: String?

    var id: UUID { userID }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case country
    }

    init(userID: UUID, username: String, country: String?) {
        self.userID = userID
        self.username = username
        self.country = country
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(UUID.self, forKey: .userID)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? "Utilisateur"
        country = try container.decodeIfPresent(String.self, forKey: .country)
    }
}

struct StreamoryProfileSearchResult: Identifiable, Codable, Equatable, Hashable {
    let userID: UUID
    let username: String
    let country: String?
    let relationshipStatus: String?

    var id: UUID { userID }
    var isFriend: Bool { relationshipStatus == "accepted" }
    var isPending: Bool { relationshipStatus == "pending" }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case username
        case country
        case relationshipStatus = "relationship_status"
    }

    init(userID: UUID, username: String, country: String?, relationshipStatus: String?) {
        self.userID = userID
        self.username = username
        self.country = country
        self.relationshipStatus = relationshipStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(UUID.self, forKey: .userID)
        username = try container.decodeIfPresent(String.self, forKey: .username) ?? "Utilisateur"
        country = try container.decodeIfPresent(String.self, forKey: .country)
        relationshipStatus = try container.decodeIfPresent(String.self, forKey: .relationshipStatus)
    }
}

struct StreamoryAppAlert: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let title: String?
    let message: String
    let type: String
    let placement: String

    var displayTitle: String {
        guard let title, !title.isEmpty else { return "Streamory" }
        return title
    }
}

struct MediaItem: Identifiable, Codable, Hashable {
    var id: UUID
    var userID: UUID?
    var tvdbID: String
    var kind: MediaKind
    var title: String
    var imageURL: String?
    var year: String?
    var overview: String?
    var episodeRuntime: Int?
    var seriesStatus: String?
    var genres: [String]
    var localizedGenres: [String] {
        genres.map(\.streamoryLocalizedGenre)
    }
    var status: WatchStatus
    var notes: String?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case tvdbID = "tvdb_id"
        case kind = "media_type"
        case title
        case imageURL = "image_url"
        case year
        case overview
        case episodeRuntime = "episode_runtime"
        case seriesStatus = "series_status"
        case genres
        case status
        case notes
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        userID = try container.decodeIfPresent(UUID.self, forKey: .userID)
        tvdbID = try container.decodeFlexibleString(forKey: .tvdbID) ?? ""
        kind = try container.decodeIfPresent(MediaKind.self, forKey: .kind) ?? .series
        title = try container.decodeFlexibleString(forKey: .title) ?? "Sans titre".streamoryLocalized
        imageURL = try container.decodeFlexibleString(forKey: .imageURL)
        year = try container.decodeFlexibleString(forKey: .year)
        overview = try container.decodeFlexibleString(forKey: .overview)
        episodeRuntime = try container.decodeFlexibleInt(forKey: .episodeRuntime)
        seriesStatus = try container.decodeFlexibleString(forKey: .seriesStatus)
        genres = (try? container.decodeIfPresent([String].self, forKey: .genres)) ?? []
        status = try container.decodeIfPresent(WatchStatus.self, forKey: .status) ?? .watchlist
        notes = try container.decodeFlexibleString(forKey: .notes)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var subtitle: String {
        [kind.label, year, status.label]
            .compactMap { value in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: " · ")
    }

    var matchKey: String {
        "\(kind.rawValue):\(tvdbID.isEmpty ? title.streamoryMatchKey : tvdbID)"
    }

    init(
        id: UUID = UUID(),
        userID: UUID? = nil,
        tvdbID: String,
        kind: MediaKind,
        title: String,
        imageURL: String? = nil,
        year: String? = nil,
        overview: String? = nil,
        episodeRuntime: Int? = nil,
        seriesStatus: String? = nil,
        genres: [String] = [],
        status: WatchStatus = .watchlist,
        notes: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userID = userID
        self.tvdbID = tvdbID
        self.kind = kind
        self.title = title
        self.imageURL = imageURL
        self.year = year
        self.overview = overview
        self.episodeRuntime = episodeRuntime
        self.seriesStatus = seriesStatus
        self.genres = genres
        self.status = status
        self.notes = notes
        self.updatedAt = updatedAt
    }
}

struct TVDBSearchResult: Identifiable, Decodable, Hashable {
    let tvdbID: String
    let kind: MediaKind
    let title: String
    let imageURL: String?
    let year: String?
    let overview: String?
    private let artworks: [TVDBArtwork]

    var id: String { "\(kind.rawValue)-\(tvdbID)" }
    var subtitle: String { [kind.label, year].compactMap { $0 }.joined(separator: " · ") }

    enum CodingKeys: String, CodingKey {
        case id
        case tvdbID = "tvdb_id"
        case type
        case name
        case title
        case thumbnail
        case poster
        case image
        case imageURL = "image_url"
        case artworks
        case year
        case firstAirTime = "first_air_time"
        case releaseYear = "release_year"
        case overview
        case description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawID = try container.decodeFlexibleString(forKey: .tvdbID)
            ?? container.decodeFlexibleString(forKey: .id)
            ?? UUID().uuidString
        let rawType = (try? container.decode(String.self, forKey: .type)) ?? ""
        self.artworks = (try? container.decodeIfPresent([TVDBArtwork].self, forKey: .artworks)) ?? []
        let image = try container.decodeFlexibleString(forKey: .imageURL)
            ?? container.decodeFlexibleString(forKey: .thumbnail)
            ?? container.decodeFlexibleString(forKey: .poster)
            ?? container.decodeFlexibleString(forKey: .image)

        self.tvdbID = rawID.onlyDigitsOrSelf
        self.kind = MediaKind(rawValue: rawType.lowercased()) ?? .series
        self.title = (try container.decodeFlexibleString(forKey: .name)
            ?? container.decodeFlexibleString(forKey: .title)
            ?? "Sans titre".streamoryLocalized)
        self.imageURL = image?.streamoryAbsoluteTVDBImageURL
        self.year = try container.decodeFlexibleString(forKey: .year)
            ?? container.decodeFlexibleString(forKey: .releaseYear)
            ?? container.decodeFlexibleString(forKey: .firstAirTime)?.prefix(4).description
        self.overview = try container.decodeFlexibleString(forKey: .overview)
            ?? container.decodeFlexibleString(forKey: .description)
    }

    fileprivate init(tvdbID: String, kind: MediaKind, title: String, imageURL: String?, year: String?, overview: String?, artworks: [TVDBArtwork] = []) {
        self.tvdbID = tvdbID
        self.kind = kind
        self.title = title
        self.imageURL = imageURL
        self.year = year
        self.overview = overview
        self.artworks = artworks
    }

    func mediaItem(userID: UUID, status: WatchStatus = .watchlist) -> MediaItem {
        MediaItem(
            userID: userID,
            tvdbID: tvdbID,
            kind: kind,
            title: title,
            imageURL: imageURL,
            year: year,
            overview: overview,
            status: status,
            updatedAt: Date()
        )
    }

    func preferringPoster(language: String) -> TVDBSearchResult {
        let preferredImage = TVDBArtwork.preferredImageURL(in: artworks, language: language) ?? imageURL
        return TVDBSearchResult(
            tvdbID: tvdbID,
            kind: kind,
            title: title,
            imageURL: preferredImage,
            year: year,
            overview: overview,
            artworks: artworks
        )
    }
}

fileprivate struct TVDBArtwork: Decodable, Hashable {
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

    static func preferredImageURL(in artworks: [TVDBArtwork], language: String) -> String? {
        let posters = artworks.filter { $0.isPoster && $0.imageURL != nil }
        let candidates = posters.isEmpty ? artworks.filter { $0.imageURL != nil } : posters
        guard !candidates.isEmpty else { return nil }

        return candidates.first { $0.normalizedLanguage.streamoryMatchesTVDBLanguage(language) }?.imageURL
            ?? candidates.first { $0.normalizedLanguage.streamoryMatchesTVDBLanguage("eng") }?.imageURL
            ?? candidates.first { $0.normalizedLanguage.isEmpty }?.imageURL
            ?? candidates.first?.imageURL
    }
}

struct TVDBCastMember: Identifiable, Decodable, Hashable {
    let id: String
    let actorName: String
    let roleName: String
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case peopleID = "people_id"
        case personID = "person_id"
        case seriesID = "series_id"
        case movieID = "movie_id"
        case name
        case actorName = "actor_name"
        case personName = "person_name"
        case peopleName = "people_name"
        case role
        case roleName = "role_name"
        case characterName = "character_name"
        case character
        case image
        case imageURL = "image_url"
        case personImgURL = "person_img_url"
        case peopleImgURL = "people_img_url"
        case sort
        case isFeatured = "is_featured"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedID = try container.decodeFlexibleString(forKey: .id)
            ?? container.decodeFlexibleString(forKey: .peopleID)
            ?? container.decodeFlexibleString(forKey: .personID)
            ?? UUID().uuidString
        id = decodedID

        actorName = try container.decodeFlexibleString(forKey: .actorName)
            ?? container.decodeFlexibleString(forKey: .personName)
            ?? container.decodeFlexibleString(forKey: .peopleName)
            ?? container.decodeFlexibleString(forKey: .name)
            ?? "Acteur inconnu".streamoryLocalized

        roleName = try container.decodeFlexibleString(forKey: .roleName)
            ?? container.decodeFlexibleString(forKey: .characterName)
            ?? container.decodeFlexibleString(forKey: .character)
            ?? container.decodeFlexibleString(forKey: .role)
            ?? ""

        imageURL = (try container.decodeFlexibleString(forKey: .imageURL)
            ?? container.decodeFlexibleString(forKey: .personImgURL)
            ?? container.decodeFlexibleString(forKey: .peopleImgURL)
            ?? container.decodeFlexibleString(forKey: .image))?.streamoryAbsoluteTVDBImageURL
    }

    var castMember: CastMember {
        CastMember(
            id: id,
            actorName: actorName,
            roleName: roleName,
            imageURL: imageURL
        )
    }
}

struct TVDBCastResponse: Decodable {
    let data: [TVDBCastMember]

    enum CodingKeys: String, CodingKey {
        case data
        case characters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let data = try? container.decodeIfPresent([TVDBCastMember].self, forKey: .data) {
            self.data = data
        } else if let characters = try? container.decodeIfPresent([TVDBCastMember].self, forKey: .characters) {
            self.data = characters
        } else {
            self.data = []
        }
    }
}

extension Array where Element == TVDBCastMember {
    var streamoryCastMembers: [CastMember] {
        map(\.castMember)
    }
}

enum MediaKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case movie
    case series

    var id: String { rawValue }

    var label: String {
        switch self {
        case .movie: "Film".streamoryLocalized
        case .series: "Série".streamoryLocalized
        }
    }

    var symbol: String {
        switch self {
        case .movie: "film.fill"
        case .series: "tv.fill"
        }
    }

    var gradient: [Color] {
        switch self {
        case .movie: [.red.opacity(0.85), .black, .indigo.opacity(0.65)]
        case .series: [.teal.opacity(0.78), .black, .purple.opacity(0.62)]
        }
    }
}

enum WatchStatus: String, CaseIterable, Identifiable, Codable, Hashable {
    case watchlist
    case watching
    case watched
    case stopped

    var id: String { rawValue }

    var label: String {
        switch self {
        case .watchlist: "À voir".streamoryLocalized
        case .watching: "En cours".streamoryLocalized
        case .watched: "Vu".streamoryLocalized
        case .stopped: "Arrêtée".streamoryLocalized
        }
    }

    var shortLabel: String {
        switch self {
        case .watchlist: "À voir".streamoryLocalized
        case .watching: "Cours".streamoryLocalized
        case .watched: "Vu".streamoryLocalized
        case .stopped: "Arrêt".streamoryLocalized
        }
    }

    var symbol: String {
        switch self {
        case .watchlist: "bookmark.fill"
        case .watching: "play.fill"
        case .watched: "checkmark"
        case .stopped: "pause.fill"
        }
    }

    var color: Color {
        switch self {
        case .watchlist: .blue
        case .watching: .orange
        case .watched: .green
        case .stopped: .gray
        }
    }
}

extension String {
    var streamoryLocalized: String {
        NSLocalizedString(self, comment: "")
    }

    var streamoryLocalizedGenre: String {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        let translations: [String: String] = [
            "action": "Action",
            "adventure": "Aventure",
            "animation": "Animation",
            "anime": "Anime",
            "awards show": "Remise de prix",
            "children": "Jeunesse",
            "comedy": "Comédie",
            "crime": "Crime",
            "documentary": "Documentaire",
            "drama": "Drame",
            "family": "Famille",
            "fantasy": "Fantastique",
            "food": "Cuisine",
            "game show": "Jeu télévisé",
            "history": "Histoire",
            "home and garden": "Maison et jardin",
            "horror": "Horreur",
            "indie": "Indépendant",
            "martial arts": "Arts martiaux",
            "mini-series": "Mini-série",
            "miniseries": "Mini-série",
            "musical": "Comédie musicale",
            "mystery": "Mystère",
            "news": "Actualités",
            "podcast": "Podcast",
            "reality": "Téléréalité",
            "romance": "Romance",
            "science fiction": "Science-fiction",
            "soap": "Feuilleton",
            "sport": "Sport",
            "suspense": "Suspense",
            "talk show": "Talk-show",
            "thriller": "Thriller",
            "travel": "Voyage",
            "war": "Guerre",
            "western": "Western"
        ]

        return translations[normalized] ?? self
    }

    var streamoryMatchKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    var onlyDigitsOrSelf: String {
        let digits = filter(\.isNumber)
        return digits.isEmpty ? self : digits
    }

    var streamoryAbsoluteTVDBImageURL: String {
        if hasPrefix("http") { return self }
        return "https://artworks.thetvdb.com\(hasPrefix("/") ? "" : "/")\(self)"
    }

    var streamoryCountryFlag: String {
        uppercased()
            .filter { $0.isLetter }
            .prefix(2)
            .reduce("") { result, character in
                guard let scalar = character.unicodeScalars.first else { return result }
                return result + String(UnicodeScalar(127397 + scalar.value) ?? scalar)
            }
    }

    func streamoryMatchesTVDBLanguage(_ language: String) -> Bool {
        let ownAliases = Set(streamoryTVDBLanguageAliases)
        let targetAliases = Set(language.streamoryTVDBLanguageAliases)
        return !ownAliases.isDisjoint(with: targetAliases)
    }

    private var streamoryTVDBLanguageAliases: [String] {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
        let compact = normalized.filter { $0.isLetter }

        let aliases: [String: [String]] = [
            "fra": ["fra", "fre", "fr", "french", "francais"],
            "fre": ["fra", "fre", "fr", "french", "francais"],
            "fr": ["fra", "fre", "fr", "french", "francais"],
            "french": ["fra", "fre", "fr", "french", "francais"],
            "francais": ["fra", "fre", "fr", "french", "francais"],
            "eng": ["eng", "en", "english", "anglais"],
            "en": ["eng", "en", "english", "anglais"],
            "english": ["eng", "en", "english", "anglais"],
            "spa": ["spa", "es", "spanish", "espanol"],
            "es": ["spa", "es", "spanish", "espanol"],
            "ita": ["ita", "it", "italian", "italiano"],
            "it": ["ita", "it", "italian", "italiano"],
            "deu": ["deu", "ger", "de", "german", "deutsch", "allemand"],
            "ger": ["deu", "ger", "de", "german", "deutsch", "allemand"],
            "de": ["deu", "ger", "de", "german", "deutsch", "allemand"],
            "por": ["por", "pt", "portuguese", "portugues"],
            "pt": ["por", "pt", "portuguese", "portugues"]
        ]

        return aliases[compact] ?? [compact]
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleString(forKey key: Key) throws -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(Int(value)) }
        return nil
    }

    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Int(value) }
        return nil
    }
}
