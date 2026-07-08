//
//  StreamoryApp.swift
//  Streamory
//
//  Created by Nathan Piaget on 02/07/2026.
//


import SwiftUI
import GoogleMobileAds
import AppTrackingTransparency
import UIKit

@main
struct StreamoryApp: App {

    init() {
        if #unavailable(iOS 14) {
            MobileAds.shared.start()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    static func requestTrackingAuthorizationIfNeeded() {
        if #available(iOS 14, *) {
            guard !UserDefaults.standard.bool(forKey: "streamory-did-request-att") else { return }
            guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
                Task { @MainActor in
                    await MobileAds.shared.start()
                }
                return
            }

            UserDefaults.standard.set(true, forKey: "streamory-did-request-att")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                ATTrackingManager.requestTrackingAuthorization { _ in
                    Task { @MainActor in
                        await MobileAds.shared.start()
                    }
                }
            }
        } else {
            MobileAds.shared.start()
        }
    }
}
