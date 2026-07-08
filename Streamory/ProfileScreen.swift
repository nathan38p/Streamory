import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct ProfileContentView: View {
    let username: String
    let country: String
    let friendButton: AnyView
    let settingsButton: (() -> Void)?
    let showsHeader: Bool
    let seriesItems: [MediaItem]
    let movieItems: [MediaItem]
    @ObservedObject var viewModel: StreamoryViewModel
    let onStatusChange: (MediaItem, WatchStatus) -> Void
    let onDelete: (MediaItem) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if showsHeader {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(username)
                                    .font(.title2.weight(.bold))
                                    .lineLimit(2)
                                Text(country.streamoryCountryFlag)
                                    .font(.title2)
                            }
                            HStack(spacing: 10) {
                                friendButton
                                Spacer()
                                if let settingsButton {
                                    Button(action: settingsButton) {
                                        Image(systemName: "gearshape.fill")
                                            .font(.title3)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .background(AppTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                ProfileCarousel(
                    title: "Séries".streamoryLocalized,
                    emptyTitle: "Aucune série suivie pour le moment.".streamoryLocalized,
                    items: seriesItems,
                    viewModel: viewModel,
                    onStatusChange: onStatusChange,
                    onDelete: onDelete
                )

                ProfileCarousel(
                    title: "Films".streamoryLocalized,
                    emptyTitle: "Aucun film ajouté pour le moment.".streamoryLocalized,
                    items: movieItems,
                    viewModel: viewModel,
                    onStatusChange: onStatusChange,
                    onDelete: onDelete
                )

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .refreshable {
            await viewModel.refreshAll()
        }
        .background(AppTheme.background.ignoresSafeArea())
    }
}

struct ProfileScreen: View {
    @ObservedObject var viewModel: StreamoryViewModel
    @Binding var showMateTab: Bool
    @State private var isShowingSettings = false

    private var username: String {
        viewModel.profile?.username
            ?? viewModel.session?.user.metadata["display_name"]
            ?? viewModel.session?.user.metadata["username"]
            ?? viewModel.session?.user.email
            ?? "Utilisateur"
    }

    private var titleUsername: String {
        guard let first = username.first else { return username }
        return first.uppercased() + String(username.dropFirst())
    }

    private var country: String {
        viewModel.profile?.country ?? viewModel.session?.user.metadata["country"] ?? "FR"
    }

    private var seriesItems: [MediaItem] {
        profileItems(kind: .series)
    }

    private var movieItems: [MediaItem] {
        profileItems(kind: .movie)
    }

    var body: some View {
        ProfileContentView(
            username: username,
            country: country,
            friendButton: AnyView(EmptyView()),
            settingsButton: nil,
            showsHeader: false,
            seriesItems: seriesItems,
            movieItems: movieItems,
            viewModel: viewModel,
            onStatusChange: { item, status in Task { await viewModel.updateStatus(item, status) } },
            onDelete: { item in Task { await viewModel.delete(item) } }
        )
        .sheet(isPresented: $isShowingSettings) {
            ProfileSettingsSheet(viewModel: viewModel, showMateTab: $showMateTab)
                .presentationDetents([.large])
        }
        .navigationTitle(titleUsername)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                }
                .accessibilityLabel("Réglages")
            }
        }
    }

    private func profileItems(kind: MediaKind) -> [MediaItem] {
        viewModel.library
            .filter { $0.kind == kind }
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }
}

struct ProfileSummaryView: View {
    let username: String
    let country: String
    let friendCount: Int
    let onShowFriends: () -> Void
    let onShowSettings: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(username)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                    Text(country.streamoryCountryFlag)
                        .font(.title2)
                }

                HStack(spacing: 10) {
                    Button(action: onShowFriends) {
                        Label(String(format: (friendCount > 1 ? "%lld amis" : "%lld ami").streamoryLocalized, friendCount), systemImage: "person.2.fill")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(action: onShowSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(AppTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ProfileCarousel: View {
    let title: String
    let emptyTitle: String
    let items: [MediaItem]
    @ObservedObject var viewModel: StreamoryViewModel
    let onStatusChange: (MediaItem, WatchStatus) -> Void
    let onDelete: (MediaItem) -> Void

    @State private var carouselWidth: CGFloat = 0

    private let posterSpacing: CGFloat = 10
    private let visiblePosterCount: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                ProfileMediaListScreen(title: title, items: items, viewModel: viewModel, onStatusChange: onStatusChange, onDelete: onDelete)
            } label: {
                HStack {
                    Text(title)
                        .font(.title2.weight(.bold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if items.isEmpty {
                EmptyStateView(symbol: "rectangle.stack.badge.plus", title: emptyTitle, subtitle: "Les affiches apparaîtront ici après ajout.".streamoryLocalized)
            } else {
                GeometryReader { proxy in
                    let posterWidth = calculatedPosterWidth(for: proxy.size.width)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: posterSpacing) {
                            ForEach(items) { item in
                                NavigationLink {
                                    MediaDetailView(item: item, viewModel: viewModel, onStatusChange: onStatusChange, onDelete: onDelete)
                                } label: {
                                    PosterImage(imageURL: item.imageURL, title: item.title, kind: item.kind)
                                        .aspectRatio(2 / 3, contentMode: .fit)
                                        .frame(width: posterWidth)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(alignment: .bottomTrailing) {
                                            Image(systemName: item.status.symbol)
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.white)
                                                .padding(5)
                                                .background(item.status.color.opacity(0.9))
                                                .clipShape(Circle())
                                                .padding(5)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .onAppear { carouselWidth = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        carouselWidth = newWidth
                    }
                }
                .frame(height: carouselHeight)
            }
        }
    }

    private var carouselHeight: CGFloat {
        calculatedPosterWidth(for: carouselWidth) * 1.5
    }

    private func calculatedPosterWidth(for availableWidth: CGFloat) -> CGFloat {
        let usableWidth = max(availableWidth, 1)
        return max((usableWidth - posterSpacing * (visiblePosterCount - 1)) / visiblePosterCount, 1)
    }
}

struct ProfileMediaListScreen: View {
    let title: String
    let items: [MediaItem]
    @ObservedObject var viewModel: StreamoryViewModel
    let onStatusChange: (MediaItem, WatchStatus) -> Void
    let onDelete: (MediaItem) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(items) { item in
                    NavigationLink {
                        MediaDetailView(item: item, viewModel: viewModel, onStatusChange: onStatusChange, onDelete: onDelete)
                    } label: {
                        PosterImage(imageURL: item.imageURL, title: item.title, kind: item.kind)
                            .aspectRatio(2 / 3, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: item.status.symbol)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .background(item.status.color.opacity(0.9))
                                    .clipShape(Circle())
                                    .padding(6)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle(title)
    }
}

struct ProfileSettingsSheet: View {
    @ObservedObject var viewModel: StreamoryViewModel
    @Binding var showMateTab: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedSection: ProfileSettingsSection = .account
    @State private var username = ""
    @State private var country = "FR"
    @State private var email = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var newPasswordConfirmation = ""
    @State private var currentAppleNonce: String?
    @State private var appleLinkMessage: String?
    @State private var appleLinkMessageIsError = false
    @State private var isShowingUnlinkAppleConfirmation = false
    @State private var isShowingDeleteAccountConfirmation = false
    @State private var deleteAccountPassword = ""
    @State private var deleteAccountConfirmation = ""
    @State private var deleteAccountMessage: String?
    @AppStorage("hideAds") private var hideAds = false
    @AppStorage("streamory-localized-titles") private var usesLocalizedTitles = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Affichage des réglages", selection: $selectedSection) {
                        ForEach(ProfileSettingsSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch selectedSection {
                case .account:
                    accountSettings
                case .appearance:
                    appearanceSettings
                case .other:
                    otherSettings
                }
            }
            .navigationTitle("Réglages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: fillForm)
            .confirmationDialog("Dissocier Apple ?", isPresented: $isShowingUnlinkAppleConfirmation, titleVisibility: .visible) {
                Button("Dissocier Apple", role: .destructive) {
                    Task { await unlinkAppleLogin() }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("La connexion avec Apple ne sera plus disponible tant qu’elle ne sera pas réactivée.")
            }
            .alert("Supprimer le compte ?", isPresented: $isShowingDeleteAccountConfirmation) {
                if viewModel.requiresPasswordForAccountDeletion {
                    SecureField("Mot de passe", text: $deleteAccountPassword)
                } else {
                    TextField("SUPPRIMER", text: $deleteAccountConfirmation)
                        .textInputAutocapitalization(.characters)
                }
                Button("Supprimer", role: .destructive) {
                    Task { await deleteAccount() }
                }
                Button("Annuler", role: .cancel) {
                    deleteAccountPassword = ""
                    deleteAccountConfirmation = ""
                }
            } message: {
                if viewModel.requiresPasswordForAccountDeletion {
                    Text("Cette action supprimera définitivement le compte Streamory et les données associées. Mot de passe requis pour confirmer.")
                } else {
                    Text("Cette action supprimera définitivement le compte Streamory et les données associées. Saisie de SUPPRIMER requise pour confirmer.")
                }
            }
        }
    }

    @ViewBuilder
    private var accountSettings: some View {
        Group {
            Section {
                TextField("Nom d’utilisateur", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Pays", selection: $country) {
                    ForEach(SupportedCountries.codes, id: \.self) { country in
                        Text(SupportedCountries.label(for: country)).tag(country)
                    }
                }
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
            } header: {
                Text("Profil")
            }

            Section {
                if requiresCurrentPasswordForPasswordChange {
                    SecureField("Ancien mot de passe", text: $currentPassword)
                } else {
                    Label("Aucun mot de passe créé", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
                SecureField("Nouveau mot de passe", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Confirmation du nouveau mot de passe", text: $newPasswordConfirmation)
                    .textContentType(.newPassword)
            } header: {
                Text("Mot de passe")
            } footer: {
                if !requiresCurrentPasswordForPasswordChange {
                    Text("Renseigne un nouveau mot de passe pour ajouter la connexion par email à ce compte.")
                }
            }

            Section {
                if isAppleLoginEnabled {
                    Label("Connexion Apple activée", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)

                    Button(role: .destructive) {
                        isShowingUnlinkAppleConfirmation = true
                    } label: {
                        Label("Dissocier Apple", systemImage: "link.badge.minus")
                    }
                    .disabled(viewModel.isLoading)
                } else {
                    SignInWithAppleButton(.continue) { request in
                        let nonce = profileSettingsRandomNonceString()
                        currentAppleNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = profileSettingsSHA256(nonce)
                    } onCompletion: { result in
                        Task { await linkAppleLogin(result) }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(viewModel.isLoading)
                }

                if let appleLinkMessage {
                    Text(appleLinkMessage)
                        .font(.footnote)
                        .foregroundStyle(appleLinkMessageIsError ? .red : .green)
                }
            } header: {
                Text("Connexion Apple")
            } footer: {
                Text(isAppleLoginEnabled ? "Dissociation Apple possible uniquement si une autre méthode de connexion est disponible." : "Apple peut être ajouté comme méthode de connexion au compte Streamory actuel.")
            }

            Section {
                Button(role: .destructive) {
                    deleteAccountPassword = ""
                    deleteAccountConfirmation = ""
                    deleteAccountMessage = nil
                    isShowingDeleteAccountConfirmation = true
                } label: {
                    Label("Supprimer le compte", systemImage: "trash")
                }
                .disabled(viewModel.isLoading)

                if let deleteAccountMessage {
                    Text(deleteAccountMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Suppression du compte")
            } footer: {
                Text("La suppression est définitive et supprime le compte Streamory ainsi que les données associées.")
            }

            Section {
                Button(role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.signOut()
                    }
                    dismiss()
                } label: {
                    Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } header: {
                Text("Déconnexion")
            }
        }
    }

    @ViewBuilder
    private var appearanceSettings: some View {
        Section {
            Toggle("Afficher les noms et titres dans la langue de l’appareil", isOn: $usesLocalizedTitles)
                .tint(.green)
                .onChange(of: usesLocalizedTitles) {
                    Task { await viewModel.refreshLocalizedMedia() }
                }
        } header: {
            Text("Langue")
        }

        Section {
            Toggle("Afficher l’onglet Mate", isOn: $showMateTab)
                .tint(.green)
        } header: {
            Text("Mate")
        }
    }

    @ViewBuilder
    private var otherSettings: some View {
        if viewModel.profile?.premiumStatut == true {
            Section {
                Toggle("Masquer les publicités", isOn: $hideAds)
                    .tint(.green)
            } header: {
                Text("Premium")
            } footer: {
                Text("Les annonces AdMob seront masquées dans l’application.")
            }
        }

        Section {
            Button {
            } label: {
                Label("Transfert depuis TV Time (À venir)", systemImage: "square.and.arrow.down")
            }
            .disabled(true)
        } header: {
            Text("TV Time")
        }

        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Metadata provided by TheTVDB. Please consider adding missing information or subscribing.")
                    .font(.subheadline)

                if let tvdbURL = URL(string: "https://www.thetvdb.com") {
                    Link(destination: tvdbURL) {
                        Label("Ajouter ou modifier les données sur TheTVDB", systemImage: "arrow.up.right.square")
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Crédits TheTVDB")
        }
    }

    private var normalizedUsername: String {
        username.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-" }
    }

    private var requiresCurrentPasswordForPasswordChange: Bool {
        viewModel.hasPasswordLogin
    }

    private var isChangingPassword: Bool {
        !currentPassword.isEmpty || !newPassword.isEmpty || !newPasswordConfirmation.isEmpty
    }

    private var isPasswordChangeValid: Bool {
        guard isChangingPassword else { return true }
        let hasRequiredCurrentPassword = !requiresCurrentPasswordForPasswordChange || !currentPassword.isEmpty
        return hasRequiredCurrentPassword && newPassword.count >= 6 && newPassword == newPasswordConfirmation
    }

    private var canSave: Bool {
        (3...28).contains(normalizedUsername.count)
            && email.contains("@")
            && isPasswordChangeValid
    }

    private var isAppleLoginEnabled: Bool {
        viewModel.session?.user.metadata["apple_login_enabled"] == "true"
    }

    private func fillForm() {
        username = viewModel.profile?.username
            ?? viewModel.session?.user.metadata["display_name"]
            ?? viewModel.session?.user.metadata["username"]
            ?? ""
        country = viewModel.profile?.country ?? viewModel.session?.user.metadata["country"] ?? SupportedCountries.defaultCode
        email = viewModel.session?.user.email ?? ""
    }

    private func save() {
        let cleanedUsername = String(normalizedUsername.prefix(28))
        username = cleanedUsername
        Task {
            await viewModel.updateProfile(
                username: cleanedUsername,
                country: country,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                currentPassword: requiresCurrentPasswordForPasswordChange ? currentPassword : "",
                newPassword: isChangingPassword ? newPassword : ""
            )

            dismiss()
        }
    }

    private func linkAppleLogin(_ result: Result<ASAuthorization, Error>) async {
        appleLinkMessage = nil
        appleLinkMessageIsError = false

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentAppleNonce else {
                appleLinkMessage = "Connexion Apple impossible.".streamoryLocalized
                appleLinkMessageIsError = true
                return
            }

            await viewModel.linkAppleLogin(
                idToken: idToken,
                nonce: nonce,
                fullName: profileSettingsFormattedAppleFullName(credential.fullName),
                email: credential.email
            )

            if let message = viewModel.message {
                appleLinkMessage = message
                appleLinkMessageIsError = !isAppleLoginEnabled
                viewModel.message = nil
            }
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
                return
            }
            appleLinkMessage = "Connexion Apple impossible.".streamoryLocalized
            appleLinkMessageIsError = true
        }
    }

    private func unlinkAppleLogin() async {
        appleLinkMessage = nil
        appleLinkMessageIsError = false
        await viewModel.unlinkAppleLogin()

        if let message = viewModel.message {
            appleLinkMessage = message
            appleLinkMessageIsError = isAppleLoginEnabled
            viewModel.message = nil
        }
    }

    private func deleteAccount() async {
        print("[DELETE ACCOUNT] ProfileSettingsSheet deleteAccount tapped")
        let requiresPassword = viewModel.requiresPasswordForAccountDeletion
        let password = deleteAccountPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let confirmation = deleteAccountConfirmation.trimmingCharacters(in: .whitespacesAndNewlines)
        deleteAccountPassword = ""
        deleteAccountConfirmation = ""
        deleteAccountMessage = nil

        guard requiresPassword ? !password.isEmpty : confirmation == "SUPPRIMER" else {
            deleteAccountMessage = requiresPassword ? "Mot de passe requis pour confirmer.".streamoryLocalized : "Saisie de SUPPRIMER requise pour confirmer la suppression.".streamoryLocalized
            return
        }

        print("[DELETE ACCOUNT] Calling viewModel.deleteAccount")
        await viewModel.deleteAccount(password: requiresPassword ? password : nil)
        if viewModel.session == nil {
            dismiss()
        } else if let message = viewModel.message {
            deleteAccountMessage = message
            viewModel.message = nil
        }
    }
}

private func profileSettingsFormattedAppleFullName(_ components: PersonNameComponents?) -> String? {
    guard let components else { return nil }
    let formatter = PersonNameComponentsFormatter()
    let name = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : name
}

private func profileSettingsRandomNonceString(length: Int = 32) -> String {
    precondition(length > 0)

    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length

    while remainingLength > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        guard status == errSecSuccess else {
            fatalError("Unable to generate nonce.")
        }

        for random in randoms where remainingLength > 0 {
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }
    }

    return result
}

private func profileSettingsSHA256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.map { String(format: "%02x", $0) }.joined()
}

enum ProfileSettingsSection: String, CaseIterable, Identifiable {
    case account
    case appearance
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .account:
            "Compte".streamoryLocalized
        case .appearance:
            "Apparence".streamoryLocalized
        case .other:
            "Autres".streamoryLocalized
        }
    }
}
