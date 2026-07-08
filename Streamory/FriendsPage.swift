import SwiftUI

struct FriendsSheet: View {
    @ObservedObject var viewModel: StreamoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Display name", text: $query)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { Task { await viewModel.searchProfiles(query: query) } }
                        Button {
                            Task { await viewModel.searchProfiles(query: query) }
                        } label: {
                            Image(systemName: "arrow.forward.circle.fill")
                                .font(.title3)
                        }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                    }
                    .frame(height: 48)
                    .padding(.horizontal, 14)
                    .background(AppTheme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if !viewModel.profileSearchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Résultats")
                                .font(.headline)
                            ForEach(viewModel.profileSearchResults) { user in
                                ProfileUserRow(
                                    user: user,
                                    viewModel: viewModel
                                ) {
                                    Task { await viewModel.sendFriendRequest(to: user) }
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Amis")
                            .font(.headline)
                        if viewModel.friends.isEmpty {
                            EmptyStateView(symbol: "person.2.slash", title: "Aucun ami", subtitle: "Cherche un utilisateur pour lui envoyer une demande.")
                        } else {
                            ForEach(viewModel.friends) { friend in
                                FriendRow(friend: friend, viewModel: viewModel)
                            }
                        }
                    }
                }
                .padding(18)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Amis")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}

struct FriendRow: View {
    let friend: StreamoryFriend
    let viewModel: StreamoryViewModel

    var body: some View {
        NavigationLink(
            destination: UserProfileScreen(
                user: StreamoryProfileSearchResult(
                    userID: friend.id,
                    username: friend.username,
                    country: friend.country,
                    relationshipStatus: "accepted"
                ),
                viewModel: viewModel
            )
        ) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(friend.username)
                        .font(.headline)
                    Text([friend.country?.streamoryCountryFlag, "Ami".streamoryLocalized].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(AppTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

struct ProfileUserRow: View {
    let user: StreamoryProfileSearchResult
    let viewModel: StreamoryViewModel
    let onAdd: () -> Void

    private var actionTitle: String {
        if user.isFriend { return "Déjà ami".streamoryLocalized }
        if user.isPending { return "Demande envoyée".streamoryLocalized }
        return "Ajouter".streamoryLocalized
    }

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(
                destination: UserProfileScreen(user: user, viewModel: viewModel)
            ) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.username)
                            .font(.headline)
                        Text([user.country?.streamoryCountryFlag, user.isFriend ? "Ami".streamoryLocalized : nil].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            Button(actionTitle, action: onAdd)
                .buttonStyle(.bordered)
                .disabled(user.isFriend || user.isPending)
        }
        .padding(14)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
