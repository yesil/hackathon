import SwiftUI

// MARK: - Placeholder Views for Content and Profile
struct ContentPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.givabitPurple.ignoresSafeArea()
            Text("Content Screen")
                .font(.largeTitle)
                .foregroundColor(Color.givabitAccent)
        }
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        ZStack {
            Color.givabitPurple.ignoresSafeArea()
            Text("Profile Screen")
                .font(.largeTitle)
                .foregroundColor(Color.givabitAccent)
        }
    }
}

// MARK: - WalletView2 (Main View from Mockup)
struct WalletView2: View {
    @StateObject private var blockchainService = BlockchainService()

    // State for the transaction tabs (Incoming/Outgoing)
    @State private var selectedTransactionType: TransactionFilterType = .incoming
    @State private var expandedTransactionIDs: Set<String> = [] // New state for expanded IDs
    
    // Computed property for filtered and sorted transaction indices
    private var displayedTransactionIndices: [Int] {
        sampleGroupedTransactions.indices
            .filter {
                let transaction = sampleGroupedTransactions[$0]
                return (transaction.isIncoming && selectedTransactionType == .incoming) ||
                       (!transaction.isIncoming && selectedTransactionType == .outgoing)
            }
            .sorted { // Sort by date, descending (most recent first)
                sampleGroupedTransactions[$0].date > sampleGroupedTransactions[$1].date
            }
    }
    
    // Sample data - reuse or adapt from WalletView or new mock data
    @State private var sampleGroupedTransactions: [GroupedTransaction] = [
        GroupedTransaction(
            id: "tx1_new",
            title: "FAKER FULL INTERVIEW - EXCLUSIVE",
            iconName: "smiley.fill", // Using SF symbol that resembles the emoji in mockup
            subDetails: [
                TransactionSubDetail(platformName: "Youtube", amountUSD: 10.01, amountBTCB: 0.0001),
                TransactionSubDetail(platformName: "Instagram", amountUSD: 8.03, amountBTCB: 0.00008),
                TransactionSubDetail(platformName: "Facebook", amountUSD: 4.01, amountBTCB: 0.00004),
                TransactionSubDetail(platformName: "X", amountUSD: 3.98, amountBTCB: 0.000039),
                TransactionSubDetail(platformName: "TikTok", amountUSD: 2.31, amountBTCB: 0.000023)
            ],
            totalUSD: 28.34,
            totalBTCB: 0.000282,
            isIncoming: true,
            date: Date().addingTimeInterval(-3600)
        ),
        GroupedTransaction(
            id: "tx2_new_outgoing",
            title: "Monthly Subscription: Pro Tier",
            iconName: "creditcard.fill",
            subDetails: [],
            totalUSD: 15.00,
            totalBTCB: 0.00015,
            isIncoming: false,
            date: Date().addingTimeInterval(-7200*2)
        )
    ]

    enum TransactionFilterType: String, CaseIterable, Identifiable {
        case incoming = "Incoming"
        case outgoing = "Outgoing"
        var id: String { self.rawValue }
    }

    var body: some View {
        TabView {
            NavigationView { // Each tab can have its own NavigationView if needed
                walletContent
                    .navigationBarHidden(true) // Hiding default nav bar as design is custom
            }
            .tabItem {
                Label("Wallet", image: "wallet")
            }
            .tag(0)

            UserContentView(blockchainService: blockchainService)
                .tabItem {
                    Label("Content", image: "content")
                }
                .tag(1)

            ProfilePlaceholderView()
                .tabItem {
                    Label("Profile", image: "profile")
                }
                .tag(2)
        }
        .accentColor(Color.givabitAccent) // Color for selected tab icon and text
        .onAppear {
            // Customize TabView appearance
            let newTabBarBackgroundColor = UIColor.white // White background

            UITabBar.appearance().barTintColor = newTabBarBackgroundColor
            UITabBar.appearance().backgroundColor = newTabBarBackgroundColor
            UITabBar.appearance().unselectedItemTintColor = UIColor(Color.givabitPurple) // Darker unselected icons
            
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = newTabBarBackgroundColor
            
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.givabitPurple.opacity(0.6))
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(Color.givabitPurple.opacity(0.7))]
            
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.givabitAccent)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor(Color.givabitAccent)]
            
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }

            // Customize SegmentedControl appearance
            let normalSegmentBGColor = UIColor(red: 100/255, green: 70/255, blue: 150/255, alpha: 1.0) // Custom lighter purple
            let normalSegmentBGImage = UIImage.image(withColor: normalSegmentBGColor, size: CGSize(width: 1, height: 1))

            let selectedSegmentSolidColor = UIColor(Color.givabitAccent)
            let selectedSegmentSolidBGImage = UIImage.image(withColor: selectedSegmentSolidColor, size: CGSize(width:1, height:1))

            UISegmentedControl.appearance().setBackgroundImage(normalSegmentBGImage, for: .normal, barMetrics: .default)
            UISegmentedControl.appearance().setBackgroundImage(selectedSegmentSolidBGImage, for: .selected, barMetrics: .default)
            
            let clearDivider = UIImage.image(withColor: .clear, size: CGSize(width: 1, height: 1))
            UISegmentedControl.appearance().setDividerImage(clearDivider, forLeftSegmentState: .normal, rightSegmentState: .normal, barMetrics: .default)
            UISegmentedControl.appearance().setDividerImage(clearDivider, forLeftSegmentState: .selected, rightSegmentState: .normal, barMetrics: .default)
            UISegmentedControl.appearance().setDividerImage(clearDivider, forLeftSegmentState: .normal, rightSegmentState: .selected, barMetrics: .default)

            let normalTextAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor(Color.givabitAccent), // Fully opaque accent text for normal
                .font: UIFont.systemFont(ofSize: 13, weight: .medium)
            ]
            let selectedTextAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor(Color.givabitPurple), 
                .font: UIFont.systemFont(ofSize: 13, weight: .bold)
            ]
            
            UISegmentedControl.appearance().setTitleTextAttributes(normalTextAttributes, for: .normal)
            UISegmentedControl.appearance().setTitleTextAttributes(selectedTextAttributes, for: .selected)
        }
    }

    var walletContent: some View {
        ZStack { // ZStack now respects safe areas by default
            Color.givabitPurple
                .ignoresSafeArea() // Extend color to fill screen

            ScrollView {
                VStack(spacing: 20) {
                    // Balance Display
                    balanceDisplay

                    // Quick Actions
                    quickActions

                    // Recent Transactions Section
                    recentTransactions
                }
                .padding(.horizontal) // Add horizontal padding to the main VStack
                .padding(.top, 20) // Add some top padding
            }
            .refreshable {
                await blockchainService.refreshWalletData()
            }
        }
    }

    var balanceDisplay: some View {
        VStack(spacing: 4) {
            Text("Current balance")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.givabitAccent.opacity(0.8))
            
            Text(FormattingUtils.formatUsd(blockchainService.balance.usdValue))
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(Color.white)
            
            Text("\(FormattingUtils.formatBtcB(blockchainService.balance.btcbBalance, maxFractionDigits: 7)) BTC")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Color.givabitAccent.opacity(0.7))
        }
        .padding(.vertical, 20)
    }

    var quickActions: some View {
        HStack(spacing: 15) {
            QuickActionWalletButton(imageName: "withdraw-1", title: "Withdraw credit", action: { /* TODO */ })
            QuickActionWalletButton(imageName: "add_credit", title: "Add credit", action: { /* TODO */ })
            QuickActionWalletButton(imageName: "more", title: "More", action: { /* TODO */ })
        }
        .padding(.horizontal) // Add padding if buttons seem too close to edge
    }

    var recentTransactions: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recent transactions")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color.white)
                .padding(.horizontal) // Align with overall padding

            transactionTypePicker

            if displayedTransactionIndices.isEmpty {
                Text("No \(selectedTransactionType.rawValue.lowercased()) transactions.")
                    .foregroundColor(Color.givabitAccent.opacity(0.7))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(displayedTransactionIndices, id: \.self) { index in
                        let transaction = sampleGroupedTransactions[index]
                        GroupedTransactionRowView(
                            transaction: transaction,
                            isCurrentlyExpanded: expandedTransactionIDs.contains(transaction.id),
                            action: { toggleExpansion(for: transaction.id) }
                        )
                    }
                }
                .padding(.horizontal) // Align with overall padding
            }
            
            // "See all past transactions" Button
            Button(action: {
                // TODO: Implement navigation to a full transaction history view
            }) {
                Text("See all past transactions")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.givabitAccent)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal) // Align with overall padding
            .padding(.top, 10)

        }
    }

    var transactionTypePicker: some View {
        HStack(spacing: 0) { // No spacing for a continuous segmented look
            ForEach(TransactionFilterType.allCases, id: \.self) { type in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { // Smooth transition
                        selectedTransactionType = type
                    }
                }) {
                    Text(type.rawValue)
                        .font(.system(size: 14, weight: .bold)) // Bold for both states
                        .frame(maxWidth: .infinity) // Distribute width equally
                        .padding(.vertical) // Let padding contribute to height
                        .foregroundColor(Color.white) // White text for both states
                        .background(
                            Group { // Use Group to conditionally apply different backgrounds
                                if selectedTransactionType == type {
                                    Image("button-bg")
                                        .resizable() // Make the image resizable
                                        // .scaledToFill() // Or .aspectRatio(contentMode: .fill) - choose what works best if slicing isn't perfect
                                } else {
                                    Color(red: 100/255, green: 70/255, blue: 150/255)
                                }
                            }
                        )
                }
            }
        }
        .frame(height: 57) // Set fixed height for the HStack
        .clipShape(RoundedRectangle(cornerRadius: 8)) // Apply rounding to the whole control
        .padding(.horizontal) // Keep the overall horizontal padding from before
    }

    // Helper function to toggle expansion state
    private func toggleExpansion(for transactionID: String) {
        withAnimation(.spring()) {
            if expandedTransactionIDs.contains(transactionID) {
                expandedTransactionIDs.remove(transactionID)
            } else {
                expandedTransactionIDs.insert(transactionID)
            }
        }
    }
}

// MARK: - Quick Action Button for WalletView2
struct QuickActionWalletButton: View {
    let imageName: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundColor(Color.givabitAccent)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.givabitAccent.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.givabitLighterPurple.opacity(0.7))
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview
struct WalletView2_Previews: PreviewProvider {
    static var previews: some View {
        WalletView2()
            .preferredColorScheme(.dark) // Match the app's theme
            // Re-use color definitions and formatting utilities if they are globally accessible
            // or copy them into this file / a shared utility file.
            // For preview to work, ensure `GroupedTransaction`, `TransactionSubDetail`, 
            // `FormattingUtils`, and color extensions are accessible.
    }
}

// NOTE: Ensure `GroupedTransaction`, `TransactionSubDetail`, `FormattingUtils`, 
// and color extensions (like `Color.givabitPurple`) are accessible to this file.
// If they are in `WalletView.swift` and not globally visible, you might need to:
// 1. Move them to a separate utility file.
// 2. Make their containing file part of the same target and ensure they have public/internal access.
// 3. For now, for simplicity, one might copy necessary structs/extensions here if needed for compilation.
// For the purpose of this generation, I am assuming they will be made accessible.

// It's also assumed that GroupedTransactionRowView is accessible.
// If not, it would need to be copied or moved.

// MARK: - Copied Dependencies from WalletView.swift (for WalletView2 functionality)

// Color Palette (Copied)
extension Color {
    static let givabitPurple = Color(red: 45/255, green: 25/255, blue: 85/255)
    static let givabitLighterPurple = Color(red: 80/255, green: 50/255, blue: 130/255)
    static let givabitAccent = Color(red: 220/255, green: 210/255, blue: 255/255)
    static let givabitGold = Color(red: 255/255, green: 215/255, blue: 0/255)
}

// Formatting Utilities (Copied)
struct FormattingUtils {
    static func formatBtcB(_ amount: Decimal, maxFractionDigits: Int = 8, minFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = minFractionDigits
        formatter.decimalSeparator = "," // As per mockup
        formatter.groupingSeparator = "." // As per mockup (though not shown for small BTC amounts)
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    static func formatUsd(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$" // Ensure $ is used
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    static func extractDecimalFromHex(_ hexString: String, decimals: Int) -> Decimal {
        let cleanedHex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        var intValue: UInt64 = 0
        if !cleanedHex.isEmpty {
            let success = Scanner(string: cleanedHex).scanHexInt64(&intValue)
            if !success {
                print("Warning: Failed to parse hex value for amount: \(hexString). Defaulting to 0.")
                intValue = 0
            }
        }
        return Decimal(intValue) / pow(10, decimals)
    }
}

// Data Structures for Grouped Transactions (Copied)
struct TransactionSubDetail: Identifiable, Hashable {
    let id = UUID()
    let platformName: String
    let amountUSD: Decimal
    let amountBTCB: Decimal
}

struct GroupedTransaction: Identifiable, Hashable {
    let id: String 
    let title: String 
    let iconName: String 
    var subDetails: [TransactionSubDetail]
    let totalUSD: Decimal
    let totalBTCB: Decimal
    let isIncoming: Bool 
    var date: Date 

    // Equatable conformance
    static func == (lhs: GroupedTransaction, rhs: GroupedTransaction) -> Bool {
        lhs.id == rhs.id
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Grouped Transaction Row View (Copied)
struct GroupedTransactionRowView: View {
    let transaction: GroupedTransaction
    let isCurrentlyExpanded: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header Part of the Row
            HStack {
                Image(systemName: transaction.iconName) 
                    .font(.system(size: 20))
                    .foregroundColor(Color.givabitAccent.opacity(0.8))
                    .frame(width: 30)

                Text(transaction.title) 
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.givabitAccent)
                    .lineLimit(1)

                Spacer()

                Image(systemName: isCurrentlyExpanded ? "chevron.up" : "chevron.down") 
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color.givabitAccent.opacity(0.7))
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 12)
            .contentShape(Rectangle()) 
            .onTapGesture {
                // User's print statement for debugging the action
                print("Tapped transaction: \(transaction.title), currently \(isCurrentlyExpanded ? "expanded" : "collapsed") - performing action")
                action() // Call the action closure passed from the parent
            }

            // Expandable Content
            if isCurrentlyExpanded { 
                VStack(spacing: 8) {
                    if !transaction.subDetails.isEmpty { 
                        ForEach(transaction.subDetails) { detail in 
                            HStack {
                                Text(detail.platformName)
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.givabitAccent.opacity(0.8))
                                Spacer()
                                Text(FormattingUtils.formatUsd(detail.amountUSD))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(Color.givabitAccent.opacity(0.9))
                            }
                        }
                        .padding(.horizontal, 12) 
                        .padding(.bottom, 5) 
                        
                         Divider().background(Color.givabitAccent.opacity(0.2))
                             .padding(.horizontal, 12)
                             .padding(.bottom, 8)
                    }

                    // Totals Section
                    HStack {
                        Spacer() 
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(transaction.isIncoming ? "+" : "-")\(FormattingUtils.formatUsd(transaction.totalUSD).dropFirst())")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(transaction.isIncoming ? .green : .red)

                            Text("\(transaction.isIncoming ? "+" : "-")\(FormattingUtils.formatBtcB(transaction.totalBTCB, maxFractionDigits: 6)) BTC")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.givabitAccent.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 15)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top))) 
            }
        }
        .background(Color.givabitLighterPurple.opacity(0.7)) 
        .cornerRadius(10)
    }
}

// Helper extension to create UIImage from UIColor (if not already available globally)
// This should ideally be in a common utility file.
extension UIImage {
    static func image(withColor color: UIColor, size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        color.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
} 