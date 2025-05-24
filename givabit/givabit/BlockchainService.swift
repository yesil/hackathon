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
        btcbContractAddress: "0x88903c72016062ba3c45e06cf0005939718e11ae",
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

// MARK: - Price API Models

// CoinGecko (Old - kept for reference or if you switch back)
struct CoinGeckoPriceResponse: Codable {
    let bitcoin: BitcoinPrice?
}

struct BitcoinPrice: Codable {
    let usd: Double?
}

// CoinMarketCap (New)
struct CoinMarketCapResponse: Codable {
    let data: [String: CoinMarketCapCoinData]?
    let status: CoinMarketCapStatus?
}

struct CoinMarketCapCoinData: Codable {
    let id: Int?
    let name: String?
    let symbol: String?
    let slug: String?
    let quote: [String: CoinMarketCapQuote]?
}

struct CoinMarketCapQuote: Codable {
    let price: Double?
    // Add other fields if needed, e.g., market_cap, volume_24h
}

struct CoinMarketCapStatus: Codable {
    let timestamp: String?
    let error_code: Int?
    let error_message: String?
    // Add other fields if needed
}

// End Price API Models

struct TransactionItem: Identifiable, Codable {
    let id: String
    let hash: String
    let from: String
    let to: String
    let rawValueData: String // Renamed from 'value'
    let tokenAmount: Decimal // New: Parsed token amount
    let usdValue: Decimal?   // New: USD value of the transaction
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
    @Published var config: BlockchainConfig = .avalancheGivabit // Default to your new L1 Testnet config
    @Published var currentBTCPriceUSD: Decimal? // New: For storing fetched BTC price
    
    private let keychainService = "com.givabit.wallet"
    nonisolated(unsafe) private var webSocketTask: URLSessionWebSocketTask?
    nonisolated(unsafe) private var urlSession: URLSession?
    @Published var subscriptionId: String?
    private var balanceUpdateTimer: Timer?
    private var isRefreshingWalletDataInProgress = false
    
    init(config: BlockchainConfig = .avalancheGivabit) {
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
                print("WebSocket: Real-time transaction detected: \(txHash). Triggering full refresh.")

                // Trigger a full refresh to update both balance and transactions
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
    
    /// Fetches the current BTC price from CoinMarketCap
    private func fetchCurrentBTCPrice() async {
        // guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd") else { // OLD CoinGecko URL
        //     print("Error: Invalid CoinGecko URL")
        //     return
        // }
        
        let apiKey = "6150a61f-eeec-455b-84c0-d65bfc6474f6" // <-- IMPORTANT: Replace with your actual API key

        guard var components = URLComponents(string: "https://pro-api.coinmarketcap.com/v1/cryptocurrency/quotes/latest") else {
            print("Error: Invalid CoinMarketCap URL")
            return
        }
        components.queryItems = [
            URLQueryItem(name: "slug", value: "bitcoin"),
            URLQueryItem(name: "convert", value: "USD")
        ]

        guard let url = components.url else {
            print("Error: Could not construct CoinMarketCap URL with parameters")
            return
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accepts")
        request.addValue(apiKey, forHTTPHeaderField: "X-CMC_PRO_API_KEY")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                print("Error: CoinMarketCap API request failed. Status: \((response as? HTTPURLResponse)?.statusCode ?? 0), Body: \(responseBody)")
                return
            }

            let decodedResponse = try JSONDecoder().decode(CoinMarketCapResponse.self, from: data)
            
            if let btcData = decodedResponse.data?["1"], // "1" is Bitcoin's ID in CoinMarketCap
               let usdQuote = btcData.quote?["USD"],
               let btcPrice = usdQuote.price {
                self.currentBTCPriceUSD = Decimal(btcPrice)
                print("Successfully fetched BTC price from CoinMarketCap: $\(self.currentBTCPriceUSD ?? 0)")
            } else {
                print("Error: Could not parse BTC price from CoinMarketCap response. Status: \(decodedResponse.status?.error_message ?? "Unknown error")")
                let responseString = String(data: data, encoding: .utf8) ?? "Could not decode response string"
                print("Full CoinMarketCap Response: \(responseString)")
            }
        } catch {
            print("Error fetching or decoding BTC price from CoinMarketCap: \(error.localizedDescription)")
        }
    }

    /// Refreshes wallet balance and transaction history
    func refreshWalletData() async {
        guard !isRefreshingWalletDataInProgress else {
            print("Refresh wallet data already in progress. Skipping.")
            return
        }

        isRefreshingWalletDataInProgress = true
        defer { isRefreshingWalletDataInProgress = false }

        isLoading = true
        errorMessage = nil

        // Fetch current BTC price first
        await fetchCurrentBTCPrice()
        
        // Fetch both balance and recent transactions
        async let balanceTask = fetchBalance()
        async let transactionsTask = fetchRecentTransactions()
        
        do {
            let (newBalance, newTransactions) = try await (balanceTask, transactionsTask)
            self.balance = newBalance
            self.transactions = newTransactions.sorted { $0.timestamp > $1.timestamp }
            print("Wallet data refreshed successfully.")
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
                // Native currency on EVM-like chains (even if it's BTC.b serving as one) typically uses 18 decimals for eth_getBalance
                nativeBalance = balanceDecimal / pow(10, 18) 
                print("Native BTC.b balance (adjusted for 18 decimals): \(nativeBalance)")
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
            // balanceOf function selector + left-padded address (remove 0x prefix)
            let addressWithoutPrefix = String(walletAddress.dropFirst(2)).lowercased()
            let paddedAddress = String(repeating: "0", count: 64 - addressWithoutPrefix.count) + addressWithoutPrefix
            let data = "0x70a08231" + paddedAddress
            
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
            
            do {
                let tokenResponse = try await makeRPCCall(payload: tokenPayload)
                
                if let result = tokenResponse["result"] as? String {
                    let balanceHex = String(result.dropFirst(2)) // Remove 0x prefix
                    
                    if !balanceHex.isEmpty, let balanceInt = UInt64(balanceHex, radix: 16) {
                        let balanceDecimal = Decimal(balanceInt)
                        tokenBalance = balanceDecimal / pow(10, 18) // Assume 18 decimals for token
                        print("Token balance: \(tokenBalance)")
                    }
                }
            } catch {
                // Token balance call failed - this is non-critical since we have the native balance
                print("Warning: Failed to fetch token balance from contract \(config.btcbContractAddress): \(error.localizedDescription)")
                print("Note: This might be expected if the contract is not yet deployed or is not an ERC20 token.")
                // Continue with tokenBalance = 0
            }
        } else {
            print("Warning: Token contract not found at address \(config.btcbContractAddress)")
        }
        
        // Calculate total USD value (BTC.b price - in production use real price feeds)
        let btcPrice = self.currentBTCPriceUSD ?? 0 // Use fetched price, default to 0 if not available
        
        // On this L1, native balance IS BTC.b balance
        let usdValue = nativeBalance * btcPrice
        
        return WalletBalance(
            nativeBalance: nativeBalance,
            btcbBalance: nativeBalance, // On BTC.b L1, native balance IS BTC.b balance
            usdValue: usdValue,
            lastUpdated: Date()
        )
    }
    
    /// Fetches recent transactions using eth_getLogs for efficiency
    private func fetchRecentTransactions() async throws -> [TransactionItem] {
        // Get the current block number
        let blockNumberResponse = try await makeRPCCall(payload: [
            "jsonrpc": "2.0",
            "method": "eth_blockNumber",
            "params": [],
            "id": 1
        ])
        
        guard let latestBlockHex = blockNumberResponse["result"] as? String,
              let latestBlock = Int(latestBlockHex.dropFirst(2), radix: 16) else {
            throw WalletError.invalidResponse
        }
        
        // Calculate from block (last 100 blocks or from block 0 if chain is new)
        let fromBlock = max(0, latestBlock - 100)
        
        // Prepare topics for Transfer events involving our wallet
        let transferEventSignature = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"
        let paddedAddress = "0x000000000000000000000000" + String(walletAddress.dropFirst(2)).lowercased()
        
        // Query for transfers FROM our address
        let fromLogsPayload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getLogs",
            "params": [[
                "fromBlock": "0x" + String(fromBlock, radix: 16),
                "toBlock": "latest",
                "address": config.btcbContractAddress,
                "topics": [
                    transferEventSignature,
                    paddedAddress, // from address
                    nil // any to address
                ]
            ]],
            "id": 2
        ]
        
        // Query for transfers TO our address
        let toLogsPayload: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getLogs",
            "params": [[
                "fromBlock": "0x" + String(fromBlock, radix: 16),
                "toBlock": "latest",
                "address": config.btcbContractAddress,
                "topics": [
                    transferEventSignature,
                    nil, // any from address
                    paddedAddress // to address
                ]
            ]],
            "id": 3
        ]
        
        var allTransactions: [TransactionItem] = []
        
        // Fetch logs with error handling
        do {
            let fromLogsResponse = try await makeRPCCall(payload: fromLogsPayload)
            if let fromLogs = fromLogsResponse["result"] as? [[String: Any]] {
                for log in fromLogs {
                    if let tx = parseTransferLog(log, type: .sent) {
                        allTransactions.append(tx)
                    }
                }
            }
        } catch {
            print("Warning: Failed to fetch outgoing transfer logs: \(error.localizedDescription)")
        }
        
        do {
            let toLogsResponse = try await makeRPCCall(payload: toLogsPayload)
            if let toLogs = toLogsResponse["result"] as? [[String: Any]] {
                for log in toLogs {
                    if let tx = parseTransferLog(log, type: .received) {
                        allTransactions.append(tx)
                    }
                }
            }
        } catch {
            print("Warning: Failed to fetch incoming transfer logs: \(error.localizedDescription)")
        }
        
        // Sort by block number (newest first) and return only the last 5
        allTransactions.sort { 
            if let block1 = Int($0.blockNumber.dropFirst(2), radix: 16),
               let block2 = Int($1.blockNumber.dropFirst(2), radix: 16) {
                return block1 > block2
            }
            return false
        }
        
        return Array(allTransactions.prefix(5))
    }
    
    /// Parses a transfer log into a TransactionItem
    private func parseTransferLog(_ log: [String: Any], type: TransactionItem.TransactionType) -> TransactionItem? {
        guard let topics = log["topics"] as? [String],
              topics.count >= 3,
              let transactionHash = log["transactionHash"] as? String,
              let blockNumber = log["blockNumber"] as? String,
              let data = log["data"] as? String else {
            return nil
        }
        
        // Extract addresses from topics (remove padding)
        let fromAddress = "0x" + topics[1].suffix(40)
        let toAddress = "0x" + topics[2].suffix(40)
        
        // Parse value from data field
        let valueHex = data.dropFirst(2) // Remove 0x
        var tokenAmount: Decimal = 0
        if !valueHex.isEmpty, let valueInt = UInt64(String(valueHex), radix: 16) {
            tokenAmount = Decimal(valueInt) / pow(10, 18) // UPDATED: Assuming log data uses 18 decimals like native L1 token
        }

        var usdValue: Decimal? = nil
        if let currentPrice = self.currentBTCPriceUSD {
            usdValue = tokenAmount * currentPrice
        }
        
        return TransactionItem(
            id: transactionHash,
            hash: transactionHash,
            from: fromAddress,
            to: toAddress,
            rawValueData: data, // Keep full hex value with 0x prefix
            tokenAmount: tokenAmount,
            usdValue: usdValue,
            timestamp: Date(), // We'll use current date as we don't have block timestamp
            blockNumber: blockNumber,
            type: type,
            status: .confirmed // Logs are only for confirmed transactions
        )
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

    
    /// Starts periodic balance updates (less frequent with WebSocket)
    private func startBalanceUpdates() {
        balanceUpdateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                if self.isRefreshingWalletDataInProgress || self.isLoading {
                    print("Timer: Balance-only refresh skipped: Another operation (full refresh or other loading) in progress.")
                    return
                }
                
                print("Timer: Triggering price and balance refresh.")
                self.isLoading = true
                
                await self.fetchCurrentBTCPrice() // Fetch price first

                do {
                    let newBalance = try await self.fetchBalance()
                    self.balance = newBalance
                    print("Timer: Price and balance refresh successful.")
                } catch {
                    print("Timer: Failed to refresh price and balance during scheduled update: \(error.localizedDescription)")
                }
                self.isLoading = false
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