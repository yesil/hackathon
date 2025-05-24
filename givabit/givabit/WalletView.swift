import SwiftUI

struct WalletView: View {
    @StateObject private var blockchainService = BlockchainService()
    @State private var showingTransactionDetails = false
    @State private var selectedTransaction: TransactionItem?
    @State private var showingNetworkSettings = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Network Status Card
                    networkStatusCard
                    
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
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingNetworkSettings = true
                    }) {
                        Image(systemName: "globe")
                    }
                    
                    Button(action: {
                        Task {
                            await blockchainService.refreshWalletData()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(blockchainService.isLoading)
                }
            }
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
    }
    
    // MARK: - Network Status Card
    private var networkStatusCard: some View {
        HStack(spacing: 12) {
            // Connection Status Indicator
            Circle()
                .fill(blockchainService.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(blockchainService.config.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(blockchainService.isConnected ? "Real-time sync active" : "Disconnected")
                    .font(.caption)
                    .foregroundColor(blockchainService.isConnected ? .green : .red)
            }
            
            Spacer()
            
            if blockchainService.isConnected {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(blockchainService.isConnected ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Balance Card
    private var balanceCard: some View {
        VStack(spacing: 16) {
            // Main Balance
            VStack(spacing: 8) {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatBalance(blockchainService.balance.btcbBalance))
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("BTC.B")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Text(formatUSDValue(blockchainService.balance.usdValue))
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Wallet Address
            VStack(spacing: 8) {
                Text("Wallet Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(formatAddress(blockchainService.walletAddress))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Button(action: {
                        UIPasteboard.general.string = blockchainService.walletAddress
                    }) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Last Updated
            if blockchainService.balance.lastUpdated != Date(timeIntervalSince1970: 0) {
                Text("Updated \(blockchainService.balance.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
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
                    icon: "qrcode.viewfinder",
                    title: "Scan QR",
                    action: {
                        // TODO: Implement QR scanning
                    }
                )
                
                QuickActionButton(
                    icon: "link",
                    title: "Pay Link",
                    action: {
                        // TODO: Implement payment link handling
                    }
                )
                
                QuickActionButton(
                    icon: "square.and.arrow.up",
                    title: "Share",
                    action: {
                        shareWalletAddress()
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
    private func formatBalance(_ balance: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        return formatter.string(from: balance as NSDecimalNumber) ?? "0"
    }
    
    private func formatUSDValue(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }
    
    private func shareWalletAddress() {
        let activityVC = UIActivityViewController(
            activityItems: [blockchainService.walletAddress],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
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
                    
                    Text(formattedAmount)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(amountColor)
                }
                
                HStack {
                    Text(transaction.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    StatusBadge(status: transaction.status)
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
        let valueDecimal = Decimal(string: transaction.value) ?? 0
        let btcbAmount = valueDecimal / pow(10, 8) // Convert from wei to BTC.B
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 0
        
        let sign = (transaction.type == .received || transaction.type == .claim) ? "+" : "-"
        let amount = formatter.string(from: btcbAmount as NSDecimalNumber) ?? "0"
        
        return "\(sign)\(amount) BTC.B"
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

// MARK: - Transaction Detail View
struct TransactionDetailView: View {
    let transaction: TransactionItem
    @Environment(\.dismiss) private var dismiss
    
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
                        
                        Text(formattedAmount)
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(amountColor)
                        
                        StatusBadge(status: transaction.status)
                    }
                    .padding()
                    
                    // Transaction Details
                    VStack(spacing: 16) {
                        DetailRow(title: "Transaction Hash", value: transaction.hash, isCopyable: true)
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
    
    // Similar computed properties as TransactionRow
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
        let valueDecimal = Decimal(string: transaction.value) ?? 0
        let btcbAmount = valueDecimal / pow(10, 8)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        
        let sign = (transaction.type == .received || transaction.type == .claim) ? "+" : "-"
        let amount = formatter.string(from: btcbAmount as NSDecimalNumber) ?? "0"
        
        return "\(sign)\(amount) BTC.B"
    }
    
    private var amountColor: Color {
        switch transaction.type {
        case .received, .claim: return .green
        case .sent, .contentPurchase, .tip: return .red
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

#Preview {
    WalletView()
} 
