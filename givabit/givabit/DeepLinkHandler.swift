import SwiftUI
import Combine

// Define a simple struct to hold deep link context
struct BuyLinkContext: Identifiable, Equatable {
    let id: String // shortCode will be the id
    let shortCode: String
    let priceInERC20: String? // Optional, as it might not always be available immediately
    // Add other relevant details if needed, e.g., original LinkItem title for quick display
}

class DeepLinkHandler: ObservableObject {
    // Published property to hold the context for a buy link
    @Published var pendingBuyContext: BuyLinkContext? = nil {
        didSet {
            // Log when pendingBuyContext changes
            if let context = pendingBuyContext {
                print("DeepLinkHandler: pendingBuyContext changed. New shortCode: \(context.shortCode), Price: \(context.priceInERC20 ?? "nil")")
            } else {
                print("DeepLinkHandler: pendingBuyContext changed to nil.")
            }
        }
    }

    // You could add more properties here for other types of deep links
    // e.g., @Published var pendingViewProfileId: String? = nil

    func handleBuyLink(shortCode: String, priceInERC20: String? = nil) {
        DispatchQueue.main.async {
            self.pendingBuyContext = BuyLinkContext(id: shortCode, shortCode: shortCode, priceInERC20: priceInERC20)
        }
    }

    func clearPendingBuyLink() {
        DispatchQueue.main.async {
            self.pendingBuyContext = nil
        }
    }
} 