import SwiftUI
import GoogleMobileAds
import UIKit
import Foundation

struct SearchScreen: View {
    @ObservedObject var viewModel: StreamoryViewModel
    @State private var query = ""
    @AppStorage("hideAds") private var hideAds = false
    @State private var selectedResult: TVDBSearchResult?

    private var movieAndSeriesResults: [TVDBSearchResult] {
        viewModel.searchResults.filter { isMovieOrSeriesResult($0) }
    }

    private func isMovieOrSeriesResult(_ result: TVDBSearchResult) -> Bool {
        switch result.kind {
        case .movie, .series:
            return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !(viewModel.profile?.premiumStatut == true && hideAds) {
                    NativeAdCard()
                        .frame(height: 110)
                }
                if !movieAndSeriesResults.isEmpty {
                    VStack(spacing: 12) {
                        ForEach(movieAndSeriesResults) { result in
                            Button {
                                if viewModel.library.contains(where: { $0.kind == result.kind && $0.title == result.title }) {
                                    selectedResult = result
                                }
                            } label: {
                                SearchResultRow(result: result) {
                                    Task { await viewModel.addToWatchlist(result) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(18)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Explorer")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "The Bear, Dune, Severance...")
        .onSubmit(of: .search) {
            Task {
                await viewModel.searchTVDB(query: query)
                viewModel.searchResults.removeAll { !isMovieOrSeriesResult($0) }
            }
        }
        .onChange(of: query) {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.clearSearchResults()
            }
        }
        .navigationDestination(item: $selectedResult) { result in
            SearchResultExistingDetailRouter(result: result, viewModel: viewModel)
        }
    }
}

private struct SearchResultExistingDetailRouter: View {
    let result: TVDBSearchResult
    @ObservedObject var viewModel: StreamoryViewModel
    @State private var addedItem: MediaItem?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let addedItem {
                MediaDetailView(
                    item: addedItem,
                    viewModel: viewModel,
                    onStatusChange: { item, status in
                        Task { await viewModel.updateStatus(item, status) }
                    },
                    onDelete: { item in
                        Task { await viewModel.delete(item) }
                    }
                )
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                    Text(isLoading ? "Chargement…" : "Impossible d’ouvrir la fiche.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.background.ignoresSafeArea())
            }
        }
        .task {
            await openExistingDetail()
        }
    }

    private func openExistingDetail() async {
        if let existingItem = matchingLibraryItem() {
            await MainActor.run {
                addedItem = existingItem
                isLoading = false
            }
            return
        }

        await MainActor.run {
            addedItem = nil
            isLoading = false
        }
    }

    private func matchingLibraryItem() -> MediaItem? {
        viewModel.library.first { item in
            item.kind == result.kind && item.title == result.title
        }
    }
}

private struct NativeAdCard: UIViewRepresentable {
    private let adUnitID = "ca-app-pub-3940256099942544/3986624511"

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        let loadingLabel = UILabel()
        loadingLabel.text = "Annonce en chargement…".streamoryLocalized
        loadingLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        loadingLabel.textColor = .secondaryLabel
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false

        let placeholder = UIView()
        placeholder.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.45)
        placeholder.layer.cornerRadius = 18
        placeholder.clipsToBounds = true
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.addSubview(loadingLabel)
        container.addSubview(placeholder)

        NSLayoutConstraint.activate([
            placeholder.topAnchor.constraint(equalTo: container.topAnchor),
            placeholder.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            placeholder.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            placeholder.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            loadingLabel.centerXAnchor.constraint(equalTo: placeholder.centerXAnchor),
            loadingLabel.centerYAnchor.constraint(equalTo: placeholder.centerYAnchor)
        ])

        context.coordinator.loadAd(into: container, adUnitID: adUnitID)
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    final class Coordinator: NSObject, NativeAdLoaderDelegate, AdLoaderDelegate {
        private var adLoader: AdLoader?

        func loadAd(into container: UIView, adUnitID: String) {
            guard adLoader == nil else { return }

            guard let rootViewController = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })?
                .rootViewController else {
                return
            }

            let loader = AdLoader(
                adUnitID: adUnitID,
                rootViewController: rootViewController,
                adTypes: [.native],
                options: nil
            )
            loader.delegate = self
            adLoader = loader
            loader.load(Request())
            self.container = container
        }

        private weak var container: UIView?

        func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
            print("AdMob native ad failed:", error.localizedDescription)
        }

        func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
            guard let container else { return }

            container.subviews.forEach { $0.removeFromSuperview() }

            let adView = NativeAdView()
            adView.translatesAutoresizingMaskIntoConstraints = false
            adView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.65)
            adView.layer.cornerRadius = 18
            adView.clipsToBounds = true

            let titleLabel = UILabel()
            titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
            titleLabel.numberOfLines = 2
            titleLabel.text = nativeAd.headline

            let bodyLabel = UILabel()
            bodyLabel.font = .systemFont(ofSize: 13, weight: .regular)
            bodyLabel.textColor = .secondaryLabel
            bodyLabel.numberOfLines = 2
            bodyLabel.text = nativeAd.body

            let adBadge = UILabel()
            adBadge.text = "Annonce".streamoryLocalized
            adBadge.font = .systemFont(ofSize: 11, weight: .semibold)
            adBadge.textColor = .secondaryLabel

            let stack = UIStackView(arrangedSubviews: [adBadge, titleLabel, bodyLabel])
            stack.axis = .vertical
            stack.spacing = 4
            stack.translatesAutoresizingMaskIntoConstraints = false

            adView.addSubview(stack)
            container.addSubview(adView)

            NSLayoutConstraint.activate([
                adView.topAnchor.constraint(equalTo: container.topAnchor),
                adView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                adView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                adView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                adView.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),

                stack.topAnchor.constraint(equalTo: adView.topAnchor, constant: 14),
                stack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
                stack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
                stack.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -14)
            ])

            adView.headlineView = titleLabel
            adView.bodyView = bodyLabel
            adView.nativeAd = nativeAd
        }
    }
}
