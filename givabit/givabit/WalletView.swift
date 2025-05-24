import SwiftUI

// MARK: - Formatting Utilities
struct FormattingUtils {
    static func formatBtcB(_ amount: Decimal, maxFractionDigits: Int = 8, minFractionDigits: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.minimumFractionDigits = minFractionDigits
        return formatter.string(from: amount as NSDecimalNumber) ?? "0"
    }

    static func formatUsd(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // Or other preferred currency
        // USD typically has 2 fraction digits by default with .currency
        return formatter.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
    
    static func extractDecimalFromHex(_ hexString: String, decimals: Int) -> Decimal {
        let cleanedHex = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        var intValue: UInt64 = 0
        if !cleanedHex.isEmpty {
            let success = Scanner(string: cleanedHex).scanHexInt64(&intValue)
            if !success {
                print("Warning: Failed to parse hex value for amount: \\(hexString). Defaulting to 0.")
                intValue = 0
            }
        }
        return Decimal(intValue) / pow(10, decimals)
    }
}

struct WalletView: View {
    @StateObject private var blockchainService = BlockchainService()
    @State private var showingTransactionDetails = false
    @State private var selectedTransaction: TransactionItem?
    @State private var showingNetworkSettings = false
    @State private var showingSendView = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Network Status Card - Removed
                    // networkStatusCard
                    
                    // Balance Card
                    balanceCard
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Recent Transactions
                    transactionsSection
                }
                .padding()
            }
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await blockchainService.refreshWalletData()
            }
        }
        .alert("Error", isPresented: .constant(blockchainService.errorMessage != nil)) {
            Button("OK") {
                blockchainService.errorMessage = nil
            }
        } message: {
            Text(blockchainService.errorMessage ?? "")
        }
        .sheet(item: $selectedTransaction) { transaction in
            TransactionDetailView(transaction: transaction)
        }
        .sheet(isPresented: $showingNetworkSettings) {
            NetworkSettingsView(blockchainService: blockchainService)
        }
        .sheet(isPresented: $showingSendView) {
            SendView(blockchainService: blockchainService)
        }
    }
    
    // MARK: - Network Status Card
    // private var networkStatusCard: some View {
    //     // ... existing network status card code ...
    // }
    
    // MARK: - Balance Card
    private var balanceCard: some View {
        VStack(spacing: 16) {
            // Main Balance
            VStack(spacing: 8) {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Display USD Value Prominently
                Text(FormattingUtils.formatUsd(blockchainService.balance.usdValue))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                // Display BTC.B Value Underneath
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(FormattingUtils.formatBtcB(blockchainService.balance.btcbBalance))
                        .font(.title2) // Adjusted font for BTC.B
                        .foregroundColor(.secondary) // Adjusted color for BTC.B
                    
                    Text("BTC.B")
                        .font(.title3) // Kept unit font or adjust as needed
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal, 4)
            
            HStack(spacing: 16) {
                QuickActionButton(
                    icon: "link",
                    title: "Pay Link",
                    action: {
                        // TODO: Implement payment link handling
                    }
                )
                
                QuickActionButton(
                    icon: "paperplane",
                    title: "Send",
                    action: {
                        showingSendView = true
                    }
                )
                
                QuickActionButton(
                    icon: "gear",
                    title: "Settings",
                    action: {
                        showingNetworkSettings = true
                    }
                )
            }
        }
    }
    
    // MARK: - Transactions Section
    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                
                Spacer()
                
                if blockchainService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 4)
            
            if blockchainService.transactions.isEmpty {
                EmptyTransactionsView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(blockchainService.transactions) { transaction in
                        TransactionRow(transaction: transaction)
                            .onTapGesture {
                                selectedTransaction = transaction
                            }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
}

// MARK: - Network Settings View
struct NetworkSettingsView: View {
    @ObservedObject var blockchainService: BlockchainService
    @Environment(\.dismiss) private var dismiss
    @State private var showingCustomConfig = false
    @State private var customRpcUrl = ""
    @State private var customWsUrl = ""
    @State private var customContractAddress = ""
    @State private var customChainId = ""
    @State private var customNetworkName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Network Status")) {
                    HStack {
                        Circle()
                            .fill(blockchainService.isConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text(blockchainService.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(blockchainService.isConnected ? .green : .red)
                        
                        Spacer()
                        
                        if blockchainService.isConnected {
                            Text("WebSocket Active")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Current Network")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(blockchainService.config.name)
                            .font(.headline)
                        
                        Text("RPC: \(blockchainService.config.rpcURL)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("WebSocket: \(blockchainService.config.wsURL)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Contract: \(blockchainService.config.btcbContractAddress)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // New Section for Copy Wallet Address
                Section(header: Text("Wallet")) {
                    Button(action: {
                        UIPasteboard.general.string = blockchainService.walletAddress
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy Wallet Address")
                        }
                        .foregroundColor(.blue) // Make it look like a typical action button
                    }
                }
                
                Section(header: Text("Available Networks")) {
                    Button(action: {
                        blockchainService.updateConfig(.avalancheGivabit)
                    }) {
                        NetworkRow(
                            name: "Givabit Network",
                            isSelected: blockchainService.config.name == BlockchainConfig.avalancheGivabit.name
                        )
                    }
                    
                    Button(action: {
                        showingCustomConfig = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                            Text("Add Custom L1")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Network Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingCustomConfig) {
            CustomNetworkView(
                networkName: $customNetworkName,
                rpcUrl: $customRpcUrl,
                wsUrl: $customWsUrl,
                contractAddress: $customContractAddress,
                chainId: $customChainId,
                onSave: { config in
                    blockchainService.updateConfig(config)
                    showingCustomConfig = false
                    dismiss()
                }
            )
        }
    }
}

// MARK: - Network Row
struct NetworkRow: View {
    let name: String
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.primary)
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Custom Network View
struct CustomNetworkView: View {
    @Binding var networkName: String
    @Binding var rpcUrl: String
    @Binding var wsUrl: String
    @Binding var contractAddress: String
    @Binding var chainId: String
    let onSave: (BlockchainConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Network Information")) {
                    TextField("Network Name", text: $networkName)
                    TextField("Chain ID (hex)", text: $chainId)
                        .textInputAutocapitalization(.never)
                }
                
                Section(header: Text("Endpoints")) {
                    TextField("RPC URL", text: $rpcUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    
                    TextField("WebSocket URL", text: $wsUrl)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                
                Section(header: Text("Token Contract")) {
                    TextField("BTC.B Contract Address", text: $contractAddress)
                        .textInputAutocapitalization(.never)
                }
                
                Section {
                    Button("Save Network") {
                        let config = BlockchainConfig.customL1(
                            rpcURL: rpcUrl,
                            wsURL: wsUrl,
                            contractAddress: contractAddress,
                            chainId: chainId
                        )
                        onSave(config)
                    }
                    .disabled(networkName.isEmpty || rpcUrl.isEmpty || wsUrl.isEmpty || contractAddress.isEmpty || chainId.isEmpty)
                }
            }
            .navigationTitle("Add Custom L1")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Pre-fill with example values
            if networkName.isEmpty {
                networkName = "Custom Avalanche L1"
                rpcUrl = "https://your-l1-rpc-url.com"
                wsUrl = "wss://your-l1-ws-url.com"
                contractAddress = "0x..."
                chainId = "0x..."
            }
        }
    }
}

// MARK: - Quick Action Button
struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: TransactionItem
    static let btcPrice: Decimal = 45000 // Placeholder for actual price feed

    private var btcbAmountDecimal: Decimal {
        // Assuming 18 decimals for transaction log values based on previous successful fixes
        return FormattingUtils.extractDecimalFromHex(transaction.value, decimals: 18)
    }

    private var transactionUsdValue: Decimal {
        return btcbAmountDecimal * Self.btcPrice
    }
    
    // New computed property to handle USD string formatting
    private var transactionDisplayUSDString: String {
        let sign = (transaction.type == .received || transaction.type == .claim) ? "+" : "-"
        let formattedUsd = FormattingUtils.formatUsd(abs(transactionUsdValue))
        let amountPart: String
        
        if formattedUsd.hasPrefix("$") {
            amountPart = String(formattedUsd.dropFirst())
        } else if formattedUsd.hasPrefix("-$") { // Should not happen with abs() but good for robustness
            amountPart = String(formattedUsd.dropFirst(2))
        }
        else {
            amountPart = formattedUsd
        }
        return "\(sign)\(amountPart) USD"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Transaction Type Icon
            Circle()
                .fill(iconBackgroundColor)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: iconName)
                        .foregroundColor(iconColor)
                        .font(.system(size: 16, weight: .medium))
                )
            
            // Transaction Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transactionTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Display USD value of the transaction using the new computed property
                    Text(transactionDisplayUSDString)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(amountColor)
                }
                
                HStack {
                    Text(transaction.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // StatusBadge removed as per request
                    // StatusBadge(status: transaction.status)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
        )
    }
    
    private var iconName: String {
        switch transaction.type {
        case .received:
            return "arrow.down.left"
        case .sent:
            return "arrow.up.right"
        case .contentPurchase:
            return "doc.text"
        case .tip:
            return "heart"
        case .claim:
            return "gift"
        }
    }
    
    private var iconColor: Color {
        switch transaction.type {
        case .received, .claim:
            return .green
        case .sent, .contentPurchase, .tip:
            return .orange
        }
    }
    
    private var iconBackgroundColor: Color {
        iconColor.opacity(0.2)
    }
    
    private var transactionTitle: String {
        switch transaction.type {
        case .received:
            return "Received"
        case .sent:
            return "Sent"
        case .contentPurchase:
            return "Content Purchase"
        case .tip:
            return "Tip Sent"
        case .claim:
            return "Claimed Tips"
        }
    }
    
    private var formattedAmount: String {
        // This computed property is no longer directly used in TransactionRow's body for main display
        // but can be kept if other parts might use it, or removed if fully replaced.
        // For now, let's assume it's not needed for the row's primary display.
        // The detail view will construct its own BTC.B string.
        let amountDecimal = FormattingUtils.extractDecimalFromHex(transaction.value, decimals: 18)
        let sign = (transaction.type == .received || transaction.type == .claim) ? "+" : "-"
        let amountStr = FormattingUtils.formatBtcB(amountDecimal)
        return "\\(sign)\\(amountStr) BTC.B"
    }
    
    private var amountColor: Color {
        switch transaction.type {
        case .received, .claim:
            return .green
        case .sent, .contentPurchase, .tip:
            return .red
        }
    }
}

// MARK: - Status Badge
struct StatusBadge: View {
    let status: TransactionItem.TransactionStatus
    
    var body: some View {
        Text(status.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .foregroundColor(textColor)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .confirmed:
            return .green.opacity(0.2)
        case .pending:
            return .orange.opacity(0.2)
        case .failed:
            return .red.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch status {
        case .confirmed:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
        }
    }
}

// MARK: - Empty Transactions View
struct EmptyTransactionsView: View {
    var body: some View {
        Group {
            VStack(spacing: 12) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                
                Text("No Transactions Yet")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Your transaction history will appear here once you start using your wallet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
            )
        }
    }
}

// MARK: - Transaction Detail View
struct TransactionDetailView: View {
    let transaction: TransactionItem
    @Environment(\.dismiss) private var dismiss
    static let btcPrice: Decimal = 45000 // Placeholder, ideally from a shared source

    private var btcbAmountDecimal: Decimal {
         // Assuming 18 decimals for transaction log values
        return FormattingUtils.extractDecimalFromHex(transaction.value, decimals: 18)
    }

    private var transactionUsdValue: Decimal { // For potential display in details
        return btcbAmountDecimal * Self.btcPrice
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Transaction Header
                    VStack(spacing: 12) {
                        Circle()
                            .fill(iconBackgroundColor)
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: iconName)
                                    .foregroundColor(iconColor)
                                    .font(.system(size: 24, weight: .medium))
                            )
                        
                        Text(transactionTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        // Display BTC.B amount in details as requested
                        Text(formattedBtcbAmountForDetail)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(amountColor)
                        
                        StatusBadge(status: transaction.status) // Kept status badge in detail view
                    }
                    .padding()
                    
                    // Transaction Details
                    VStack(spacing: 16) {
                        DetailRow(title: "Transaction Hash", value: transaction.hash, isCopyable: true)
                        // Optionally, show USD value here too
                        DetailRow(title: "Value (USD)", value: FormattingUtils.formatUsd(transactionUsdValue))
                        DetailRow(title: "From", value: transaction.from, isCopyable: true)
                        DetailRow(title: "To", value: transaction.to, isCopyable: true)
                        DetailRow(title: "Block Number", value: transaction.blockNumber)
                        DetailRow(title: "Date", value: transaction.timestamp.formatted())
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.regularMaterial)
                    )
                }
                .padding()
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var iconName: String {
        switch transaction.type {
        case .received: return "arrow.down.left"
        case .sent: return "arrow.up.right"
        case .contentPurchase: return "doc.text"
        case .tip: return "heart"
        case .claim: return "gift"
        }
    }
    
    private var iconColor: Color {
        switch transaction.type {
        case .received, .claim: return .green
        case .sent, .contentPurchase, .tip: return .orange
        }
    }
    
    private var iconBackgroundColor: Color {
        iconColor.opacity(0.2)
    }
    
    private var transactionTitle: String {
        switch transaction.type {
        case .received: return "Received"
        case .sent: return "Sent"
        case .contentPurchase: return "Content Purchase"
        case .tip: return "Tip Sent"
        case .claim: return "Claimed Tips"
        }
    }
    
    private var formattedAmount: String {
        // This is the original BTC.B formatter for details, let's rename to avoid confusion
        // and ensure it uses the new utility.
        // This property name `formattedAmount` is used in the original code for the main display in header.
        // Let's call it `formattedBtcbAmountForDetail`
        return "This should be replaced by formattedBtcbAmountForDetail"
    }

    private var formattedBtcbAmountForDetail: String {
        let sign = (transaction.type == .received || transaction.type == .claim) ? "+" : "-"
        // btcbAmountDecimal is already available
        let amountString = FormattingUtils.formatBtcB(btcbAmountDecimal)
        return "\(sign)\(amountString) BTC.B"
    }
    
    private var amountColor: Color {
        switch transaction.type {
        case .received, .claim:
            return .green
        case .sent, .contentPurchase, .tip:
            return .red
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let title: String
    let value: String
    let isCopyable: Bool
    
    init(title: String, value: String, isCopyable: Bool = false) {
        self.title = title
        self.value = value
        self.isCopyable = isCopyable
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Text(value)
                    .font(.system(.footnote, design: isCopyable ? .monospaced : .default))
                    .foregroundColor(.primary)
                    .lineLimit(nil)
                
                if isCopyable {
                    Button(action: {
                        UIPasteboard.general.string = value
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

// MARK: - Send View (New View) - Uncommented struct definition
struct SendView: View {
    @ObservedObject var blockchainService: BlockchainService
    @Environment(\.dismiss) private var dismiss

    @State private var recipientAddress: String = ""
    @State private var amountString: String = ""
    @State private var showingConfirmationAlert = false
    @State private var alertMessage: String = ""
    @State private var sendError: String? = nil

    private var amountDecimal: Decimal? {
        // Ensure a dot is used as the decimal separator for Decimal conversion
        let sanitizedAmountString = amountString.replacingOccurrences(of: ",", with: ".")
        return Decimal(string: sanitizedAmountString)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recipient")) {
                    TextField("Enter wallet address (e.g., 0x...)", text: $recipientAddress)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Amount")) {
                    HStack {
                        TextField("0.0", text: $amountString)
                            .keyboardType(.decimalPad)
                        Text("BTC.B")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Available Balance")) {
                    Text("\(FormattingUtils.formatBtcB(blockchainService.balance.btcbBalance)) BTC.B")
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Review Transaction") {
                        sendError = nil // Clear previous errors
                        guard !recipientAddress.isEmpty else {
                            sendError = "Recipient address cannot be empty."
                            return
                        }
                        // Basic address validation (starts with 0x, length)
                        guard recipientAddress.hasPrefix("0x") && recipientAddress.count == 42 else {
                             sendError = "Invalid recipient address format. It should start with '0x' and be 42 characters long."
                             return
                        }

                        guard let amount = amountDecimal, amount > 0 else {
                            sendError = "Please enter a valid positive amount."
                            return
                        }
                        
                        guard amount <= blockchainService.balance.btcbBalance else {
                            sendError = "Insufficient balance. You cannot send more than you have."
                            return
                        }

                        alertMessage = "You are about to send \(FormattingUtils.formatBtcB(amount)) BTC.B to:\n\(recipientAddress)\n\nThis action cannot be undone."
                        showingConfirmationAlert = true
                    }
                    .disabled(recipientAddress.isEmpty || amountDecimal == nil || amountDecimal ?? 0 <= 0)
                }

                if let error = sendError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Send BTC.B")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Confirm Transaction", isPresented: $showingConfirmationAlert) {
                Button("Confirm Send") {
                    // Placeholder for actual send logic
                    if let amount = amountDecimal {
                        print("Confirmed: Send \(amount) BTC.B to \(recipientAddress)")
                        // TODO: Integrate with blockchainService.sendToken(to: recipientAddress, amount: amount)
                        // After successful send (or mock success):
                        // blockchainService.refreshWalletData() // To update balance and transactions
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }
}

#Preview {
    WalletView()
} 
