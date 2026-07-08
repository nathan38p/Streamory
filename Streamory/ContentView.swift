import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = StreamoryViewModel()

    var body: some View {
        ZStack {
            Group {
                if viewModel.session == nil {
                    AuthScreen(viewModel: viewModel)
                } else if viewModel.needsAppleProfileCompletion {
                    AppleProfileCompletionScreen(viewModel: viewModel)
                } else {
                    MainAppScreen(viewModel: viewModel)
                        .task {
                            StreamoryApp.requestTrackingAuthorizationIfNeeded()
                        }
                }
            }

            if viewModel.isRestoringSession {
                LaunchLoadingView()
            }
        }
        .id(viewModel.session?.user.id.uuidString ?? "signed-out")
        .alert(item: $viewModel.startupAlert) { alert in
            Alert(
                title: Text(alert.displayTitle),
                message: Text(alert.message),
                dismissButton: .default(Text("OK")) {
                    viewModel.dismissStartupAlert(alert)
                }
            )
        }
    }
}

private struct AppleProfileCompletionScreen: View {
    @ObservedObject var viewModel: StreamoryViewModel
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var country = SupportedCountries.defaultCode

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Finaliser l’inscription")
                        .font(.largeTitle.weight(.bold))
                    Text("Confirmation de la date de naissance et du pays requise pour continuer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    HStack {
                        Text("Date de naissance")
                            .foregroundStyle(.secondary)
                        Spacer()
                        DatePicker("Date de naissance", selection: $birthDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                    .appleCompletionFieldStyle()

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
                    .appleCompletionFieldStyle()
                }

                Spacer()

                if let message = viewModel.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    Task { await viewModel.completeAppleProfile(birthDate: birthDate, country: country) }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Continuer")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.isLoading || !SupportedCountries.codes.contains(country))

                Button("Se déconnecter") {
                    viewModel.signOut()
                }
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isLoading)
            }
            .padding(20)
            .background(AppTheme.background.ignoresSafeArea())
            .onAppear {
                if let currentCountry = viewModel.session?.user.metadata["country"], SupportedCountries.codes.contains(currentCountry) {
                    country = currentCountry
                }
            }
        }
    }
}

private struct AppleCompletionFieldStyle: ViewModifier {
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
    func appleCompletionFieldStyle() -> some View {
        modifier(AppleCompletionFieldStyle())
    }
}

private struct LaunchLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark ? .black : Color("AccentColor")
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .accessibilityLabel("Streamory")
        }
    }
}

#Preview {
    ContentView()
}
