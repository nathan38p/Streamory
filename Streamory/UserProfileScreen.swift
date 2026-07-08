import SwiftUI

struct UserProfileScreen: View {
    let user: StreamoryProfileSearchResult
    @ObservedObject var viewModel: StreamoryViewModel
    @State private var isShowingRemoveFriendDialog = false

    private var userLibrary: [MediaItem] {
        viewModel.friendLibraries[user.id] ?? []
    }

    private var seriesItems: [MediaItem] {
        profileItems(kind: .series)
    }

    private var movieItems: [MediaItem] {
        profileItems(kind: .movie)
    }

    var body: some View {
        ProfileContentView(
            username: user.username,
            country: user.country ?? "FR",
            friendButton: AnyView(friendButtonView),
            settingsButton: nil,
            showsHeader: true,
            seriesItems: seriesItems,
            movieItems: movieItems,
            viewModel: viewModel,
            onStatusChange: { _, _ in },
            onDelete: { _ in }
        )
        .confirmationDialog("Retirer cet ami ?", isPresented: $isShowingRemoveFriendDialog, titleVisibility: .visible) {
            Button("Retirer l’ami", role: .destructive) {
                Task { await viewModel.removeFriend(user) }
            }
            Button("Annuler", role: .cancel) { }
        }
        .task(id: user.id) {
            await viewModel.loadPublicLibrary(for: user)
        }
    }

    private func profileItems(kind: MediaKind) -> [MediaItem] {
        userLibrary
            .filter { $0.kind == kind }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }

    @ViewBuilder
    private var friendButtonView: some View {
        if user.isFriend {
            VStack(spacing: 12) {
                Button {
                    isShowingRemoveFriendDialog = true
                } label: {
                    Label("Ami", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)
            }
        } else if user.isPending {
            Button("Demande envoyée") {}
                .buttonStyle(.bordered)
                .disabled(true)
        } else {
            Button {
                Task { await viewModel.sendFriendRequest(to: user) }
            } label: {
                Label("Ajouter", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
