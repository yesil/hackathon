import SwiftUI

class ContentDetailService: ObservableObject {
    @Published var contentInfo: ContentInfoResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func fetchDetails(for shortCode: String) { // Removed blockchainService as it's not used for this specific fetch anymore
        let endpointUrl = "https://givabit-server-krlus.ondigitalocean.app/info/\(shortCode)"
        print("ContentDetailService: Attempting to fetch details from: \(endpointUrl)")
        
        self.isLoading = true
        self.errorMessage = nil

        guard let url = URL(string: endpointUrl) else {
            self.isLoading = false
            self.errorMessage = "Invalid API endpoint URL for content details."
            print(errorMessage!)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Failed to fetch content details: \(error.localizedDescription)"
                    print(self.errorMessage!)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    self.errorMessage = "Server error fetching content details (Status: \(statusCode))."
                    print(self.errorMessage!)
                    if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                        print("Error Response Body: \(responseString)")
                    }
                    return
                }

                guard let data = data else {
                    self.errorMessage = "No data received for content details."
                    print(self.errorMessage!)
                    return
                }
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON for /info/ endpoint: \(jsonString)")
                }

                do {
                    let decoder = JSONDecoder()
                    // No custom date decoding needed for this specific response structure
                    self.contentInfo = try decoder.decode(ContentInfoResponse.self, from: data)
                    print("Successfully decoded content info for \(shortCode)")
                } catch let decodingError as DecodingError {
                    self.errorMessage = "Failed to decode content details: \(decodingError.localizedDescription)"
                    print("Detailed decoding error: \(decodingError)")
                    // Add more detailed print(decodingError) as before if needed
                } catch {
                     self.errorMessage = "An unexpected error occurred while decoding content details: \(error.localizedDescription)"
                     print(self.errorMessage!)
                }
            }
        }.resume()
    }
}

// MARK: - BuyContentView
struct BuyContentView: View {
    @Environment(\.presentationMode) var presentationMode
    // The shortCode and initialPriceInERC20 will now likely come from a context object or be passed separately.
    // Let's assume a BuyLinkContext is passed or just the necessary fields.
    let buyContext: BuyLinkContext // Changed to accept BuyLinkContext
    
    @StateObject private var detailService = ContentDetailService()
    @ObservedObject var blockchainService: BlockchainService 
    
    @State private var displayPriceUSD: Decimal? = nil
    @State private var displayPriceBTC: Decimal? = nil
    // priceInERC20ForPayment will be derived from buyContext.priceInERC20 or a default/fetched value
    @State private var priceInERC20ForPayment: String? // Declare as @State

    // Initializer to handle the context
    init(buyContext: BuyLinkContext, blockchainService: BlockchainService) {
        self.buyContext = buyContext
        self.blockchainService = blockchainService
        // Initialize the State variable's wrapped value
        self._priceInERC20ForPayment = State(initialValue: buyContext.priceInERC20)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.givabitDarkPurple.ignoresSafeArea()
                
                if detailService.isLoading {
                    ProgressView().scaleEffect(1.5).tint(.white)
                } else if let contentInfo = detailService.contentInfo {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Givabit") 
                                .font(.system(size: 30, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 20)

                            VStack(alignment: .leading, spacing: 16) {
                                Text("Transaction")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(Color.givabitAccent.opacity(0.8))
                                    .padding(.horizontal)
                                
                                Text(contentInfo.title)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                // Placeholder for Image - Not in ContentInfoResponse
                                Rectangle()
                                    .fill(Color.givabitLighterPurple.opacity(0.3))
                                    .frame(height: 220)
                                    .overlay(Text("Image Placeholder").foregroundColor(Color.givabitAccent))
                                    .cornerRadius(0)
                                
                                Text(contentInfo.description)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(Color.givabitAccent.opacity(0.9))
                                    .lineSpacing(5)
                                    .padding(.horizontal)
                                
                                // Placeholder for Author - Not in ContentInfoResponse
                                HStack(spacing: 10) {
                                    Image(systemName: "person.circle.fill") // SF Symbol placeholder
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                        .foregroundColor(Color.givabitAccent)
                                    Text("by Unknown Author")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color.white)
                                }
                                .padding(.horizontal)
                                
                                Spacer(minLength: 20)
                                
                                // Price Section - Needs data source for price
                                HStack {
                                    Text("Price")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(Color.givabitAccent)
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        if let usd = displayPriceUSD {
                                            Text(FormattingUtils.formatUsd(usd))
                                                .font(.system(size: 28, weight: .bold))
                                                .foregroundColor(.white)
                                        } else {
                                            Text("$?.??")
                                                .font(.system(size: 28, weight: .bold))
                                                .foregroundColor(Color.white.opacity(0.7))
                                        }
                                        if let btc = displayPriceBTC {
                                            Text("\(FormattingUtils.formatBtcB(btc, maxFractionDigits: 7)) BTC")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color.givabitAccent.opacity(0.8))
                                        } else {
                                            Text("-.------- BTC")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color.givabitAccent.opacity(0.7))
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                                
                            }
                            .padding(.bottom, 20)
                            .background(Color.givabitPurple)
                            .cornerRadius(20)
                            .padding(.horizontal)
                            
                            Spacer(minLength: 30)

                            Button(action: {
                                // TODO: Implement payment approval using priceInERC20ForPayment
                                print("Approve payment tapped for \(buyContext.shortCode). ERC20 to pay: \(priceInERC20ForPayment ?? "N/A")")
                            }) {
                                Text("Approve payment")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color.givabitPurple)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(25)
                            }
                            .disabled(priceInERC20ForPayment == nil || detailService.contentInfo == nil)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 30)
                        }
                    }
                } else if let errorMessage = detailService.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    Text("Loading content details...")
                        .foregroundColor(Color.givabitAccent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                detailService.fetchDetails(for: buyContext.shortCode)
                setupPriceDetails(fromERC20String: priceInERC20ForPayment) // Use the potentially passed price
            }
        }
    }
    
    private func setupPriceDetails(fromERC20String priceERC20Str: String?) {
        guard let erc20String = priceERC20Str, 
              let priceInSmallestUnit = Decimal(string: erc20String), 
              let btcPriceUSD = blockchainService.currentBTCPriceUSD, btcPriceUSD > 0 else {
            
            print("Could not calculate USD/BTC price for display - priceInERC20 string missing/invalid or BTC price feed missing.")
            self.displayPriceUSD = nil
            self.displayPriceBTC = nil
            // If priceInERC20ForPayment was nil, it remains nil. Button should be disabled.
            // If it was non-nil but conversion failed, we might want to clear priceInERC20ForPayment or show error.
            // For now, just clear display prices.
            return
        }

        let tokenAmountInFull = priceInSmallestUnit / pow(10, 18) // Assuming 18 decimals
        self.displayPriceUSD = tokenAmountInFull * btcPriceUSD
        self.displayPriceBTC = tokenAmountInFull // Assuming ERC20 token is BTC.b or equivalent
        // priceInERC20ForPayment is already set from init or remains as passed.
    }
}

extension Color {
   static let givabitDarkPurple = Color(red: 30/255, green: 15/255, blue: 60/255)
} 
