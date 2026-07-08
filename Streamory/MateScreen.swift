import SwiftUI

struct MateScreen: View {
    @ObservedObject var viewModel: StreamoryViewModel
    @AppStorage("streamory-selected-mate-friend-id") private var selectedFriendIDString = ""
    @State private var selectedKind: MediaKind = .movie
    @State private var isShowingAddFriend = false
    @State private var sharedPermissionStatuses: [UUID: MateSharedPermissionStatus] = [:]

    private var selectedFriend: StreamoryFriend? {
        let id = activeFriendID
        return viewModel.friends.first { $0.id == id }
    }

    private var activeFriendID: UUID? {
        if let storedID = UUID(uuidString: selectedFriendIDString),
           viewModel.friends.contains(where: { $0.id == storedID }) {
            return storedID
        }
        return viewModel.friends.first?.id
    }

    private var matches: [MediaItem] {
        guard let selectedFriend else { return [] }
        if selectedKind == .series {
            return viewModel.mateSeriesMatches[selectedFriend.id] ?? []
        }

        let friendKeys = Set(
            (viewModel.friendWatchlists[selectedFriend.id] ?? [])
                .filter { $0.kind == selectedKind && $0.status == .watchlist }
                .map(\.matchKey)
        )
        return viewModel.library
            .filter { $0.kind == selectedKind && $0.status == .watchlist && friendKeys.contains($0.matchKey) }
            .sorted { $0.title < $1.title }
    }


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if viewModel.friends.isEmpty {
                    EmptyStateView(symbol: "person.2.slash", title: "Aucun ami", subtitle: "Des amis sont nécessaires pour activer les matchs.")
                } else {
                    Picker("Type", selection: $selectedKind) {
                        Text("Films").tag(MediaKind.movie)
                        Text("Séries").tag(MediaKind.series)
                    }
                    .pickerStyle(.segmented)

                    if let selectedFriend {
                        if let permissionStatus = sharedPermissionStatuses[selectedFriend.id], permissionStatus != .mutualAllowed {
                            MateSharedPermissionBanner(
                                friend: selectedFriend,
                                status: permissionStatus,
                                onAllow: {
                                    Task {
                                        await viewModel.setFriendCanAddPermissionByID(friendID: selectedFriend.id, allowed: true)
                                        await loadSharedPermissionStatus(for: selectedFriend)
                                    }
                                }
                            )
                        }

                        if matches.isEmpty {
                            EmptyStateView(
                                symbol: selectedKind == .movie ? "film" : "tv",
                                title: "Aucun match",
                                subtitle: ""
                            )
                        } else {
                            MatePosterGrid(items: matches, viewModel: viewModel)
                        }
                    }
                }
            }
            .padding(18)
            .onAppear {
                if selectedFriendIDString.isEmpty, let firstFriendID = viewModel.friends.first?.id {
                    selectedFriendIDString = firstFriendID.uuidString
                }
                if let selectedFriend {
                    Task { await loadMatches(for: selectedFriend) }
                }
                if let selectedFriend {
                    Task { await loadSharedPermissionStatus(for: selectedFriend) }
                }
            }
            .onChange(of: selectedKind) {
                if let selectedFriend {
                    Task { await loadMatches(for: selectedFriend) }
                }
                if let selectedFriend {
                    Task { await loadSharedPermissionStatus(for: selectedFriend) }
                }
            }
        }
        .refreshable {
            if let selectedFriend {
                await loadMatches(for: selectedFriend)
                await loadSharedPermissionStatus(for: selectedFriend)
            } else {
                await viewModel.refreshAll()
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Mate")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(viewModel.friends) { friend in
                        Button {
                            selectedFriendIDString = friend.id.uuidString
                            Task {
                                await loadMatches(for: friend)
                                await loadSharedPermissionStatus(for: friend)
                            }
                        } label: {
                            Label(friend.username, systemImage: activeFriendID == friend.id ? "checkmark" : "person.crop.circle")
                        }
                    }

                    if !viewModel.friends.isEmpty {
                        Divider()
                    }

                    Button {
                        isShowingAddFriend = true
                    } label: {
                        Label("Ajouter un ami", systemImage: "person.badge.plus")
                    }
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                }
                .accessibilityLabel("Choisir ou ajouter un ami")
            }
        }
        .sheet(isPresented: $isShowingAddFriend) {
            FriendsSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
    }

    private func loadMatches(for friend: StreamoryFriend) async {
        if selectedKind == .series {
            await viewModel.loadMateSeriesMatches(for: friend)
        } else {
            await viewModel.loadWatchlist(for: friend)
        }
    }

    private func loadSharedPermissionStatus(for friend: StreamoryFriend) async {
        async let ownPermission = viewModel.friendCanAddPermission(friendID: friend.id)
        async let mutualPermission = viewModel.mutualFriendCanAddPermission(friendID: friend.id)

        let ownAllowed = await ownPermission
        let mutualAllowed = await mutualPermission

        await MainActor.run {
            if mutualAllowed {
                sharedPermissionStatuses[friend.id] = .mutualAllowed
            } else if ownAllowed {
                sharedPermissionStatuses[friend.id] = .pendingFriend
            } else {
                sharedPermissionStatuses[friend.id] = .notAllowed
            }
        }
    }
}

private enum MateSharedPermissionStatus: Equatable {
    case notAllowed
    case pendingFriend
    case mutualAllowed
}

private struct MateSharedPermissionBanner: View {
    let friend: StreamoryFriend
    let status: MateSharedPermissionStatus
    let onAllow: () -> Void

    var body: some View {
        Group {
            switch status {
            case .notAllowed:
                Button(action: onAllow) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title3)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Autoriser les ajouts communs")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Autorisation donnée à \(friend.username) pour ajouter des films et séries dans les deux listes une fois l’accord mutuel activé.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

            case .pendingFriend:
                HStack(spacing: 12) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.title3)
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Autorisation en attente")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Accord enregistré. Activation des ajouts communs encore requise par \(friend.username).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            case .mutualAllowed:
                EmptyView()
            }
        }
    }
}

private struct MatePosterGrid: View {
    let items: [MediaItem]
    @ObservedObject var viewModel: StreamoryViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(items) { item in
                NavigationLink {
                    MediaDetailView(
                        item: item,
                        viewModel: viewModel,
                        onStatusChange: { item, status in
                            Task { await viewModel.updateStatus(item, status) }
                        },
                        onDelete: { item in
                            Task { await viewModel.delete(item) }
                        }
                    )
                } label: {
                    AsyncImage(url: posterURL(for: item)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.white.opacity(0.08))
                                Image(systemName: item.kind == .movie ? "film" : "tv")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                        case .empty:
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.white.opacity(0.08))
                                ProgressView()
                            }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    private func posterURL(for item: MediaItem) -> URL? {
        let possibleNames = ["poster", "posterPath", "posterURL", "image", "imageURL", "thumbnail", "thumbnailURL"]

        for child in Mirror(reflecting: item).children {
            guard let label = child.label, possibleNames.contains(label) else { continue }

            if let url = child.value as? URL {
                return url
            }

            if let string = child.value as? String, let url = URL(string: string) {
                return url
            }

            let optionalMirror = Mirror(reflecting: child.value)
            if optionalMirror.displayStyle == .optional,
               let wrapped = optionalMirror.children.first?.value {
                if let url = wrapped as? URL {
                    return url
                }

                if let string = wrapped as? String, let url = URL(string: string) {
                    return url
                }
            }
        }

        return nil
    }
}
