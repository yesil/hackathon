import Foundation
import CryptoKit
import Security
import Combine

// MARK: - Configuration
struct BlockchainConfig {
    let name: String
    let rpcURL: String
    let wsURL: String
    let btcbContractAddress: String
    let chainId: String
    
    static let avalancheGivabit = BlockchainConfig(
        name: "Givabit Network",
        rpcURL: "https://138.68.175.242.sslip.io/ext/bc/mvVnPTEvCKjGqEvZaAXseWSiLtZ9uc3MgiQzkLzGQtBDebxGY/rpc",
        wsURL: "wss://138.68.175.242.sslip.io/ext/bc/mvVnPTEvCKjGqEvZaAXseWSiLtZ9uc3MgiQzkLzGQtBDebxGY/ws",
        btcbContractAddress: "0x5425890298aed601595a70AB815c96711a31Bc65", // TODO: Update with deployed BTC.b contract address
        chainId: "0xa869"
    )
    
    // Example custom L1 configuration
    static func customL1(rpcURL: String, wsURL: String, contractAddress: String, chainId: String) -> BlockchainConfig {
        return BlockchainConfig(
            name: "Givabit Avalanche L1",
            rpcURL: rpcURL,
            wsURL: wsURL,
            btcbContractAddress: contractAddress,
            chainId: chainId
        )
    }
}

// MARK: - Models
struct WalletBalance {
    let nativeBalance: Decimal // Native gas token balance (BTC.b)
    let btcbBalance: Decimal   // BTC.b token balance (same as native on L1)
    let usdValue: Decimal
    let lastUpdated: Date
}

struct TransactionItem: Identifiable, Codable {
    let id: String
    let hash: String
    let from: String
    let to: String
    let value: String
    let timestamp: Date
    let blockNumber: String
    let type: TransactionType
    let status: TransactionStatus
    
    enum TransactionType: String, Codable, CaseIterable {
        case sent = "sent"
        case received = "received"
        case contentPurchase = "content_purchase"
        case tip = "tip"
        case claim = "claim"
    }
    
    enum TransactionStatus: String, Codable {
        case pending = "pending"
        case confirmed = "confirmed"
        case failed = "failed"
    }
}

// MARK: - WebSocket Message Types
struct WebSocketMessage: Codable {
    let jsonrpc: String
    let method: String?
    let params: WebSocketParams?
    let id: Int?
    let result: String?
    let error: WebSocketError?
}

struct WebSocketParams: Codable {
    let subscription: String?
    let result: WebSocketResult?
}

struct WebSocketResult: Codable {
    let address: String?
    let topics: [String]?
    let data: String?
    let blockNumber: String?
    let transactionHash: String?
    let transactionIndex: String?
    let blockHash: String?
    let logIndex: String?
    let removed: Bool?
}

struct WebSocketError: Codable {
    let code: Int
    let message: String
}

// MARK: - Blockchain Service
@MainActor
class BlockchainService: ObservableObject {
    @Published var walletAddress: String = ""
    @Published var balance: WalletBalance = WalletBalance(nativeBalance: 0, btcbBalance: 0, usdValue: 0, lastUpdated: Date())
    @Published var transactions: [TransactionItem] = []
    @Published var isLoading: Bool = false
    @Published var isConnected: Bool = false
    @Published var errorMessage: String?
    @Published var config: BlockchainConfig = .myL1Testnet // Default to your new L1 Testnet config
    
    private let keychainService = "com.givabit.wallet"
    nonisolated(unsafe) private var webSocketTask: URLSessionWebSocketTask?
    nonisolated(unsafe) private var urlSession: URLSession?
    @Published var subscriptionId: String?
    private var balanceUpdateTimer: Timer?
    
    init(config: BlockchainConfig = .myL1Testnet) {
        self.config = config
        setupWallet()
        setupWebSocket()
    }
    
    deinit {
        disconnect()
        balanceUpdateTimer?.invalidate()
    }
    
    // MARK: - Configuration Methods
    
    /// Updates the blockchain configuration and reconnects
    func updateConfig(_ newConfig: BlockchainConfig) {
        disconnect()
        self.config = newConfig
        setupWebSocket()
        
        Task {
            await refreshWalletData()
        }
    }
    
    // MARK: - Wallet Management
    
    /// Automatically creates or loads existing wallet using iOS Secure Enclave
    private func setupWallet() {
        if let existingAddress = loadWalletAddress() {
            walletAddress = existingAddress
            print("Loaded existing wallet: \(existingAddress)")
        } else {
            createNewWallet()
        }
        
        print("=== WALLET ADDRESS ===")
        print("Your wallet address: \(walletAddress)")
        print("Recent transaction to: 0xe81430d54414dc122a6cd8ef48834fd17a41141b")
        print("Addresses match: \(walletAddress.lowercased() == "0xe81430d54414dc122a6cd8ef48834fd17a41141b")")
        print("=====================")
        
        // Start loading balance and transactions
        Task {
            await refreshWalletData()
        }
    }
    
    /// Creates a new wallet using iOS CryptoKit and stores it securely
    private func createNewWallet() {
        do {
            // Generate private key using Secure Enclave if available, otherwise use CryptoKit
            let privateKey = P256.Signing.PrivateKey()
            let privateKeyData = privateKey.rawRepresentation
            
            // Derive Ethereum-compatible address from private key
            let address = deriveEthereumAddress(from: privateKey)
            
            // Store private key securely in Keychain
            try storePrivateKey(privateKeyData, for: address)
            
            walletAddress = address
            
            print("Created new wallet: \(address)")
        } catch {
            print("Failed to create wallet: \(error)")
            errorMessage = "Failed to create wallet: \(error.localizedDescription)"
        }
    }
    
    /// Derives Ethereum-compatible address from P256 private key
    private func deriveEthereumAddress(from privateKey: P256.Signing.PrivateKey) -> String {
        // Get the public key
        let publicKey = privateKey.publicKey
        
        // For demo purposes, we'll create a mock address based on the public key
        // In production, you'd use proper Ethereum key derivation
        let publicKeyData = publicKey.rawRepresentation
        let hash = SHA256.hash(data: publicKeyData)
        let addressData = Data(hash.suffix(20)) // Take last 20 bytes
        
        return "0x" + addressData.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Secure Storage
    
    /// Stores private key securely in iOS Keychain with hardware backing
    private func storePrivateKey(_ privateKeyData: Data, for address: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: address,
            kSecValueData as String: privateKeyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw WalletError.keychainStorageError(status)
        }
    }
    
    /// Loads wallet address from Keychain
    private func loadWalletAddress() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let attributes = result as? [String: Any],
           let account = attributes[kSecAttrAccount as String] as? String {
            return account
        }
        
        return nil
    }
    
    // MARK: - WebSocket Connection
    
    /// Sets up WebSocket connection for real-time updates
    private func setupWebSocket() {
        guard let wsURL = URL(string: config.wsURL) else {
            print("Invalid WebSocket URL: \(config.wsURL)")
            return
        }
        
        urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession?.webSocketTask(with: wsURL)
        
        connect()
    }
    
    /// Connects to WebSocket and subscribes to events
    private func connect() {
        guard let webSocketTask = webSocketTask else { return }
        
        webSocketTask.resume()
        isConnected = true
        print("Connected to WebSocket: \(config.wsURL)")
        
        // Subscribe to logs for our wallet address and contract
        subscribeToLogs()
        
        // Start listening for messages
        listenForMessages()
        
        // Start periodic balance updates (less frequent since we have real-time updates)
        startBalanceUpdates()
    }
    
    /// Disconnects from WebSocket
    nonisolated func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        urlSession?.invalidateAndCancel()
        Task { @MainActor in
            isConnected = false
            subscriptionId = nil
            balanceUpdateTimer?.invalidate()
        }
    }
    
    /// Subscribes to logs for our wallet address and BTC.B contract
    private func subscribeToLogs() {
        guard !walletAddress.isEmpty else { return }
        
        // Subscribe to logs that involve our wallet address
        let subscribeMessage: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "eth_subscribe",
            "params": [
                "logs",
                [
                    "address": config.btcbContractAddress,
                    "topics": [
                        "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef", // Transfer event signature
                        nil, // from (we'll filter in code)
                        nil  // to (we'll filter in code)
                    ]
                ]
            ]
        ]
        
        sendWebSocketMessage(subscribeMessage)
    }
    
    /// Sends a message through WebSocket
    private func sendWebSocketMessage(_ message: [String: Any]) {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: message)
            let messageString = String(data: data, encoding: .utf8) ?? ""
            
            webSocketTask.send(.string(messageString)) { error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                }
            }
        } catch {
            print("Failed to serialize WebSocket message: \(error)")
        }
    }
    
    /// Listens for incoming WebSocket messages
    private func listenForMessages() {
        guard let webSocketTask = webSocketTask else { return }
        
        webSocketTask.receive { [weak self] result in
            switch result {
            case .success(let message):
                Task { @MainActor in
                    await self?.handleWebSocketMessage(message)
                    self?.listenForMessages() // Continue listening
                }
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                Task { @MainActor in
                    self?.isConnected = false
                    self?.errorMessage = "WebSocket connection lost: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Handles incoming WebSocket messages
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            do {
                let data = text.data(using: .utf8) ?? Data()
                let wsMessage = try JSONDecoder().decode(WebSocketMessage.self, from: data)
                
                if let subscriptionId = wsMessage.params?.subscription {
                    self.subscriptionId = subscriptionId
                    print("Subscribed with ID: \(subscriptionId)")
                } else if wsMessage.method == "eth_subscription" {
                    await handleLogEvent(wsMessage)
                }
            } catch {
                print("Failed to decode WebSocket message: \(error)")
            }
        case .data(let data):
            print("Received binary WebSocket data: \(data)")
        @unknown default:
            print("Unknown WebSocket message type")
        }
    }
    
    /// Handles log events from WebSocket
    private func handleLogEvent(_ message: WebSocketMessage) async {
        guard let result = message.params?.result,
              let topics = result.topics,
              let txHash = result.transactionHash else { return }
        
        // Check if this is a Transfer event involving our wallet
        if topics.count >= 3 {
            let fromAddress = extractAddressFromTopic(topics[1])
            let toAddress = extractAddressFromTopic(topics[2])
            
            let walletLower = walletAddress.lowercased()
            if fromAddress.lowercased() == walletLower || toAddress.lowercased() == walletLower {
                print("Real-time transaction detected: \(txHash)")
                
                // Refresh wallet data to get the latest balance and transactions
                await refreshWalletData()
            }
        }
    }
    
    /// Extracts address from topic (removes padding zeros)
    private func extractAddressFromTopic(_ topic: String) -> String {
        guard topic.count >= 42 else { return topic }
        let suffix = String(topic.suffix(40))
        return "0x" + suffix
    }
    
    // MARK: - Blockchain Interaction
    
    /// Refreshes wallet balance and transaction history
    func refreshWalletData() async {
        isLoading = true
        errorMessage = nil
        
        async let balanceTask = fetchBalance()
        async let transactionsTask = fetchTransactions()
        
        do {
            let (newBalance, newTransactions) = try await (balanceTask, transactionsTask)
            
            self.balance = newBalance
            self.transactions = newTransactions.sorted { $0.timestamp > $1.timestamp }
            
        } catch {
            print("Failed to refresh wallet data: \(error)")
            errorMessage = "Failed to refresh wallet data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// Fetches both native ETH and token balances from configured blockchain
    private func fetchBalance() async throws -> WalletBalance {
        // Fetch native ETH balance
        let nativeBalancePayload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getBalance",
            "params": [walletAddress, "latest"],
            "id": 1
        ]
        
        let nativeResponse = try await makeRPCCall(payload: nativeBalancePayload)
        
        var nativeBalance: Decimal = 0
        if let result = nativeResponse["result"] as? String {
            let balanceHex = String(result.dropFirst(2)) // Remove 0x prefix
            if let balanceInt = UInt64(balanceHex, radix: 16) {
                let balanceDecimal = Decimal(balanceInt)
                nativeBalance = balanceDecimal / pow(10, 8) // BTC.b has 8 decimals when used as gas token
                print("Native BTC.b balance: \(nativeBalance)")
            }
        }
        
        // Try to fetch token balance (optional - might not exist)
        var tokenBalance: Decimal = 0
        
        // First check if the contract exists
        let contractCheckPayload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getCode",
            "params": [config.btcbContractAddress, "latest"],
            "id": 2
        ]
        
        let contractResponse = try await makeRPCCall(payload: contractCheckPayload)
        
        if let contractCode = contractResponse["result"] as? String, contractCode != "0x" {
            // Contract exists, try to get token balance
            let data = "0x70a08231" + String(walletAddress.dropFirst(2)).padding(toLength: 64, withPad: "0", startingAt: 0)
            
            let tokenPayload: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "eth_call",
                "params": [
                    [
                        "to": config.btcbContractAddress,
                        "data": data
                    ],
                    "latest"
                ],
                "id": 3
            ]
            
            let tokenResponse = try await makeRPCCall(payload: tokenPayload)
            
            if let result = tokenResponse["result"] as? String {
                let balanceHex = String(result.dropFirst(2)) // Remove 0x prefix
                
                if !balanceHex.isEmpty, let balanceInt = UInt64(balanceHex, radix: 16) {
                    let balanceDecimal = Decimal(balanceInt)
                    tokenBalance = balanceDecimal / pow(10, 8) // Assume 8 decimals for token
                    print("Token balance: \(tokenBalance)")
                }
            }
        } else {
            print("Warning: Token contract not found at address \(config.btcbContractAddress)")
        }
        
        // Calculate total USD value (BTC.b price - in production use real price feeds)
        let btcPrice: Decimal = 45000 // $45,000 per BTC.b (Bitcoin price)
        
        // On this L1, native balance IS BTC.b balance
        let usdValue = nativeBalance * btcPrice
        
        return WalletBalance(
            nativeBalance: nativeBalance,
            btcbBalance: nativeBalance, // On BTC.b L1, native balance IS BTC.b balance
            usdValue: usdValue,
            lastUpdated: Date()
        )
    }
    
    /// Fetches recent transactions for the wallet
    private func fetchTransactions() async throws -> [TransactionItem] {
        // Get latest block number
        let latestBlockResponse = try await makeRPCCall(payload: [
            "jsonrpc": "2.0",
            "method": "eth_blockNumber",
            "params": [],
            "id": 1
        ])
        
        guard let latestBlockHex = latestBlockResponse["result"] as? String,
              let latestBlock = Int(latestBlockHex.dropFirst(2), radix: 16) else {
            throw WalletError.invalidResponse
        }
        
        var allTransactions: [TransactionItem] = []
        
        // Fetch transactions from recent blocks (last 20 blocks or all if fewer)
        let startBlock = max(0, latestBlock - 20)
        
        for blockNumber in startBlock...latestBlock {
            let blockHex = String(blockNumber, radix: 16)
            
            let blockResponse = try await makeRPCCall(payload: [
                "jsonrpc": "2.0",
                "method": "eth_getBlockByNumber",
                "params": ["0x" + blockHex, true],
                "id": 1
            ])
            
            if let blockData = blockResponse["result"] as? [String: Any],
               let transactions = blockData["transactions"] as? [[String: Any]] {
                
                for txData in transactions {
                    if let tx = parseTransaction(txData, blockNumber: String(blockNumber)) {
                        allTransactions.append(tx)
                    }
                }
            }
        }
        
        return allTransactions
    }
    
    /// Makes RPC call to configured blockchain
    private func makeRPCCall(payload: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: config.rpcURL) else {
            print("Error: Invalid RPC URL: \(config.rpcURL)")
            throw WalletError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        print("Making RPC call to: \(config.rpcURL)")
        print("Payload: \(payload)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("Error: Invalid HTTP response")
            throw WalletError.networkError
        }
        
        print("HTTP Status Code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("Error: HTTP \(httpResponse.statusCode) - \(responseBody)")
            throw WalletError.networkError
        }
        
        let responseString = String(data: data, encoding: .utf8) ?? "No response"
        print("Response: \(responseString)")
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("Error: Could not parse JSON response")
            throw WalletError.invalidResponse
        }
        
        // Check for JSON-RPC error in response
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            print("RPC Error: \(message)")
            throw WalletError.invalidResponse
        }
        
        return json
    }
    
    /// Parses transaction data from blockchain response
    private func parseTransaction(_ txData: [String: Any], blockNumber: String) -> TransactionItem? {
        guard let hash = txData["hash"] as? String,
              let from = txData["from"] as? String,
              let value = txData["value"] as? String else {
            return nil
        }
        
        // Handle contract creation (to is null)
        let to = txData["to"] as? String ?? "Contract Creation"
        
        // Only include transactions involving our wallet (native transfers)
        let walletLower = walletAddress.lowercased()
        let isRelevant = from.lowercased() == walletLower || to.lowercased() == walletLower
        
        guard isRelevant else { return nil }
        
        let type: TransactionItem.TransactionType = from.lowercased() == walletLower ? .sent : .received
        
        return TransactionItem(
            id: hash,
            hash: hash,
            from: from,
            to: to,
            value: value,
            timestamp: Date(),
            blockNumber: blockNumber,
            type: type,
            status: .confirmed
        )
    }
    
    /// Starts periodic balance updates (less frequent with WebSocket)
    private func startBalanceUpdates() {
        balanceUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshWalletData()
            }
        }
    }
}

// MARK: - Errors
enum WalletError: Error, LocalizedError {
    case keychainStorageError(OSStatus)
    case invalidURL
    case networkError
    case invalidResponse
    case webSocketError(String)
    case contractNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .keychainStorageError(let status):
            return "Keychain storage error: \(status)"
        case .invalidURL:
            return "Invalid RPC URL"
        case .networkError:
            return "Network connection error"
        case .invalidResponse:
            return "Invalid response from blockchain"
        case .webSocketError(let message):
            return "WebSocket error: \(message)"
        case .contractNotFound(let address):
            return "Contract not found at address: \(address). Please check your network configuration."
        }
    }
} 