//
//  givabitApp.swift
//  givabit
//
//  Created by Ilyas Türkben on 23.05.2025.
//

import SwiftUI

@main
struct givabitApp: App {
    @StateObject private var deepLinkHandler = DeepLinkHandler()
    // If you have a BlockchainService or other global state, initialize it here
    // For example:
    // @StateObject private var blockchainService = BlockchainService()

    var body: some Scene {
        WindowGroup {
            WalletView2()
                .environmentObject(deepLinkHandler)
                // If you were using blockchainService as an EnvironmentObject:
                // .environmentObject(blockchainService)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    print("!!! .onContinueUserActivity CLOSURE EXECUTED !!!")
                    print("Activity Type: \(userActivity.activityType)")
                    if let url = userActivity.webpageURL {
                        print("Webpage URL: \(url.absoluteString)")
                    }
                    // Call the original handler AFTER printing, to see if this basic print works first
                    // handleUserActivity(userActivity, deepLinkHandler: deepLinkHandler)
                }
        }
    }

    func handleUserActivity(_ userActivity: NSUserActivity, deepLinkHandler: DeepLinkHandler) {
        print("!!! GivabitApp: handleUserActivity CALLED - ActivityType: \(userActivity.activityType), WebpageURL: \(userActivity.webpageURL?.absoluteString ?? "nil") !!!")

        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let incomingURL = userActivity.webpageURL else {
            print("GivabitApp: handleUserActivity - Guard failed: Not a browsing web activity or no URL.")
            return
        }

        print("GivabitApp: Received Universal Link (after guard): \(incomingURL.absoluteString)")

        // --- Path Parsing Example for new structure ---
        let pathComponents = incomingURL.pathComponents
        print("GivabitApp: Parsed pathComponents: \(pathComponents)")

        if pathComponents.count > 2 && pathComponents[1] == "buy" {
            let shortCode = pathComponents[2]
            print("GivabitApp: Detected buy link with shortCode: '\(shortCode)'. Calling deepLinkHandler.")
            
            deepLinkHandler.handleBuyLink(shortCode: shortCode, priceInERC20: nil)
            print("GivabitApp: Called deepLinkHandler.handleBuyLink. Current pendingBuyContext ID: \(deepLinkHandler.pendingBuyContext?.id ?? "nil")")

        } else {
            print("GivabitApp: Universal Link received, but path does not match expected /buy/{shortCode} pattern: \(incomingURL.path)")
        }
    }
}

// Optional: Define a notification name if you choose to use NotificationCenter
// extension Notification.Name {
//    static let handleBuyLink = Notification.Name("handleBuyLinkNotification")
// }
