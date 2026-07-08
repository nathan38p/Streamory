import AuthenticationServices
import CryptoKit
import Security
import SwiftUI
import UIKit

struct AuthScreen: View {
    @ObservedObject var viewModel: StreamoryViewModel
    @State private var isSignup = false
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var username = ""
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var country = SupportedCountries.defaultCode
    @State private var inlineAuthMessage: InlineAuthMessage?
    @State private var currentAppleNonce: String?
    @FocusState private var focusedField: AuthField?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.dismiss) private var dismiss

    private enum AuthField: Hashable {
        case email
        case password
        case passwordConfirmation
        case username
    }

    private struct InlineAuthMessage: Equatable {
        let text: String
        let isError: Bool
    }

    private var canSubmit: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        guard isSignup else { return true }
        return !username.isEmpty && password == passwordConfirmation && SupportedCountries.codes.contains(country)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            HStack(alignment: .center, spacing: 14) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Streamory")
                                        .font(.largeTitle.weight(.bold))
                                    Text("Suivi de films et séries")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 12)

                                AuthHeaderLogo()
                            }

                            VStack(spacing: 14) {
                                TextField("Email", text: Binding(
                                    get: { email },
                                    set: { email = $0.lowercased() }
                                ))
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .email)
                                .onSubmit {
                                    focusedField = isSignup ? .username : .password
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .onTapGesture { focusedField = .email }
                                .authFieldStyle()

                                if isSignup {
                                    TextField("Nom d’utilisateur", text: $username)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .submitLabel(.done)
                                        .focused($focusedField, equals: .username)
                                        .onSubmit { focusedField = .password }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture { focusedField = .username }
                                        .authFieldStyle()

                                    SecureField("Mot de passe", text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .submitLabel(.next)
                                        .focused($focusedField, equals: .password)
                                        .onSubmit {
                                            focusedField = .passwordConfirmation
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture { focusedField = .password }
                                        .authFieldStyle()

                                    SecureField("Confirmation du mot de passe", text: $passwordConfirmation)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .submitLabel(.next)
                                        .focused($focusedField, equals: .passwordConfirmation)
                                        .onSubmit { focusedField = .username }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture { focusedField = .passwordConfirmation }
                                        .authFieldStyle()

                                    HStack {
                                        Text("Date de naissance")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        DatePicker("", selection: $birthDate, displayedComponents: .date)
                                            .labelsHidden()
                                    }
                                    .authFieldStyle()

                                    HStack {
                                        Text("Pays")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Picker("Pays", selection: $country) {
                                            ForEach(SupportedCountries.codes, id: \.self) { country in
                                                Text(SupportedCountries.label(for: country)).tag(country)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.menu)
                                    }
                                    .authFieldStyle()
                                }

                                if !isSignup {
                                    SecureField("Mot de passe", text: $password)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled(true)
                                        .submitLabel(.go)
                                        .focused($focusedField, equals: .password)
                                        .onSubmit {
                                            submit()
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture { focusedField = .password }
                                        .authFieldStyle()
                                }

                                if !isSignup {
                                    Button("Mot de passe oublié ?") {
                                        focusedField = nil
                                        inlineAuthMessage = nil
                                        Task {
                                            await viewModel.resetPassword(email: email)

                                            if let message = consumeInlineAuthMessage(fallback: nil) {
                                                inlineAuthMessage = message
                                            } else {
                                                inlineAuthMessage = InlineAuthMessage(
                                                    text: "Si un compte existe avec cet email, un lien de réinitialisation a été envoyé.".streamoryLocalized,
                                                    isError: false
                                                )
                                            }
                                        }
                                    }
                                    .font(.footnote)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .disabled(viewModel.isLoading || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scrollDismissesKeyboard(.interactively)

                    VStack(spacing: 12) {
                        Group {
                            if let inlineAuthMessage {
                                Text(inlineAuthMessage.text)
                                    .font(.footnote)
                                    .foregroundStyle(inlineAuthMessage.isError ? .red : .green)
                                    .multilineTextAlignment(.center)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)

                        Button {
                            submit()
                        } label: {
                            Text(isSignup ? "Créer le compte" : "Se connecter")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AuthPrimaryButtonStyle())
                        .disabled(viewModel.isLoading || !canSubmit)

                        SignInWithAppleButton(isSignup ? .signUp : .signIn) { request in
                            let nonce = randomNonceString()
                            currentAppleNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                        } onCompletion: { result in
                            Task { await handleAppleSignIn(result) }
                        }
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .id("apple-sign-in-\(colorScheme == .dark ? "dark" : "light")-\(isSignup ? "signup" : "signin")")
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .disabled(viewModel.isLoading)

                        Button {
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                isSignup.toggle()
                            }
                            inlineAuthMessage = nil
                            focusedField = nil
                        } label: {
                            Text(isSignup ? "J’ai déjà un compte" : "Créer un compte")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AuthSecondaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.clear.contentShape(Rectangle()).onTapGesture {
                    focusedField = nil
                    #if canImport(UIKit)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                })
            }
            .background(AppTheme.background.ignoresSafeArea())
        }
    }

    private func submit() {
        guard canSubmit, !viewModel.isLoading else { return }
        focusedField = nil
        inlineAuthMessage = nil
        Task {
            if isSignup {
                await viewModel.signUp(email: email, password: password, username: username, birthDate: birthDate, country: country)
                if let message = consumeInlineAuthMessage(fallback: "Impossible de créer le compte.".streamoryLocalized) {
                    inlineAuthMessage = message
                }
            } else {
                await viewModel.signIn(email: email, password: password)
                if let message = consumeInlineAuthMessage(fallback: "Identifiants incorrects.".streamoryLocalized) {
                    inlineAuthMessage = message
                }
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        focusedField = nil
        inlineAuthMessage = nil

        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let authorizationCodeData = credential.authorizationCode,
                  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
                  let nonce = currentAppleNonce else {
                inlineAuthMessage = InlineAuthMessage(text: "Connexion Apple impossible.".streamoryLocalized, isError: true)
                return
            }

            let fullName = formattedAppleFullName(credential.fullName)
            await viewModel.signInWithApple(
                idToken: idToken,
                nonce: nonce,
                fullName: fullName,
                email: credential.email,
                country: nil
            )

            if let message = consumeInlineAuthMessage(fallback: nil) {
                inlineAuthMessage = message
                return
            }

            await viewModel.storeAppleAuthorizationCode(authorizationCode)

            if let message = consumeInlineAuthMessage(fallback: "Connexion Apple impossible.".streamoryLocalized) {
                inlineAuthMessage = message
            }
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .canceled {
                return
            }
            inlineAuthMessage = InlineAuthMessage(text: "Connexion Apple impossible.".streamoryLocalized, isError: true)
        }
    }

    private func consumeInlineAuthMessage(fallback: String?) -> InlineAuthMessage? {
        guard let rawMessage = viewModel.message else {
            guard let fallback else { return nil }
            return InlineAuthMessage(text: fallback, isError: true)
        }

        let mappedMessage = mapAuthErrorMessage(rawMessage)
        viewModel.message = nil
        return InlineAuthMessage(text: mappedMessage, isError: true)
    }

    private func mapAuthErrorMessage(_ rawMessage: String) -> String {
        let lowercasedMessage = rawMessage.lowercased()

        if lowercasedMessage.contains("invalid_credentials") || lowercasedMessage.contains("invalid login credentials") || lowercasedMessage.contains("code\":400") {
            return "Identifiants incorrects.".streamoryLocalized
        }

        if lowercasedMessage.contains("invalid format") || lowercasedMessage.contains("invalid email") || lowercasedMessage.contains("email address is invalid") {
            return "Adresse email invalide.".streamoryLocalized
        }

        if lowercasedMessage.contains("email already") || lowercasedMessage.contains("already registered") || lowercasedMessage.contains("user already registered") || lowercasedMessage.contains("already exists") && lowercasedMessage.contains("email") {
            return "Cette adresse email est déjà utilisée.".streamoryLocalized
        }

        if lowercasedMessage.contains("username") && (lowercasedMessage.contains("already exists") || lowercasedMessage.contains("already taken") || lowercasedMessage.contains("duplicate")) {
            return "Ce nom d’utilisateur est déjà pris.".streamoryLocalized
        }

        if lowercasedMessage.contains("password") && (lowercasedMessage.contains("weak") || lowercasedMessage.contains("short") || lowercasedMessage.contains("at least") || lowercasedMessage.contains("minimum")) {
            return "Mot de passe trop faible.".streamoryLocalized
        }

        if lowercasedMessage.contains("429") || lowercasedMessage.contains("for security purposes") || lowercasedMessage.contains("too many") || lowercasedMessage.contains("rate limit") {
            return "Demande trop récente. Nouvelle tentative possible dans quelques secondes.".streamoryLocalized
        }

        if lowercasedMessage.contains("network") || lowercasedMessage.contains("internet") || lowercasedMessage.contains("connection") || lowercasedMessage.contains("timed out") {
            return "Erreur de connexion. Connexion internet à vérifier.".streamoryLocalized
        }

        return "Une erreur est survenue. Nouvelle tentative possible dans quelques instants.".streamoryLocalized
    }
}

private struct AuthHeaderLogo: View {
    var body: some View {
        Image("AuthHeaderLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)
    }
}

private func formattedAppleFullName(_ components: PersonNameComponents?) -> String? {
    guard let components else { return nil }
    let formatter = PersonNameComponentsFormatter()
    let name = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
    return name.isEmpty ? nil : name
}

private func randomNonceString(length: Int = 32) -> String {
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

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.map { String(format: "%02x", $0) }.joined()
}

private struct AuthPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AuthSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 19, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.field)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct AuthFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .padding(.horizontal, 14)
            .background(AppTheme.field)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension View {
    func authFieldStyle() -> some View {
        modifier(AuthFieldStyle())
    }
}
