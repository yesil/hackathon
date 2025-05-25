import SwiftUI

// ContentInfoResponse struct is now removed from here, defined in LinkItemModels.swift

// MARK: - API Service for Content Details
class ContentDetailService: ObservableObject {
    @Published var buyLinkDetail: BuyLinkDetail? // Changed to BuyLinkDetail
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    func fetchDetails(for shortCode: String) {
        let endpointUrl = "https://givabit-server-krlus.ondigitalocean.app/buy/\(shortCode)" // Updated endpoint
        print("ContentDetailService: Attempting to fetch details from: \(endpointUrl)")
        
        self.isLoading = true
        self.errorMessage = nil

        guard let url = URL(string: endpointUrl) else {
            self.isLoading = false
            self.errorMessage = "Invalid API endpoint URL for buy link details."
            print(errorMessage!)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Failed to fetch buy link details: \(error.localizedDescription)"
                    print(self.errorMessage!)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    self.errorMessage = "Server error fetching buy link details (Status: \(statusCode))."
                    print(self.errorMessage!)
                    if let responseData = data, let responseString = String(data: responseData, encoding: .utf8) {
                        print("Error Response Body: \(responseString)")
                    }
                    return
                }

                guard let data = data else {
                    self.errorMessage = "No data received for buy link details."
                    print(self.errorMessage!)
                    return
                }
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON for /buy/ endpoint: \(jsonString)")
                }

                do {
                    let decoder = JSONDecoder()
                    self.buyLinkDetail = try decoder.decode(BuyLinkDetail.self, from: data) // Decode BuyLinkDetail
                    print("Successfully decoded buy link details for \(shortCode)")
                } catch let decodingError {
                    self.errorMessage = "Failed to decode buy link details: \(decodingError.localizedDescription)"
                    print("Detailed decoding error for BuyLinkDetail: \(decodingError)")
                    if let decodingError = decodingError as? DecodingError {
                        // Print specific details from DecodingError (add back the switch if needed)
                         print("DecodingError context: \(decodingError)")
                    }
                }
            }
        }.resume()
    }
}

// MARK: - BuyContentView
struct BuyContentView: View {
    @Environment(\.presentationMode) var presentationMode
    let buyContext: BuyLinkContext 
    
    @StateObject var detailService = ContentDetailService()
    @ObservedObject var blockchainService: BlockchainService 
    
    @State private var displayPriceUSD: Decimal? = nil
    @State private var displayPriceBTC: Decimal? = nil
    // priceInERC20ForPayment will come directly from detailService.buyLinkDetail.priceInERC20

    init(buyContext: BuyLinkContext, blockchainService: BlockchainService) {
        self.buyContext = buyContext
        self.blockchainService = blockchainService
        // No need to initialize priceInERC20ForPayment from buyContext here anymore,
        // as it will come from the fetched buyLinkDetail.
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.givabitDarkPurple.ignoresSafeArea()
                
                if detailService.isLoading {
                    ProgressView().scaleEffect(1.5).tint(.white)
                } else if let fetchedDetail = detailService.buyLinkDetail { // Use buyLinkDetail
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
                                
                                Text(fetchedDetail.title) // Use title from fetchedDetail
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                
                                // Use AsyncImage to load the remote placeholder image
                                AsyncImage(url: URL(string: "https://www.itchyboots.com/cache/2391db258d54401690375245e844a3b34ab301e7c78194bd32a4186255f51229/3344e925-b58f-4e05-b52d-a0f0a7fb5d94.jpg")) { phase in
                                    switch phase {
                                    case .empty: // While loading
                                        ZStack {
                                            Color.givabitLighterPurple.opacity(0.3)
                                            ProgressView().tint(Color.givabitAccent)
                                        }
                                    case .success(let image):
                                        image.resizable()
                                             .aspectRatio(contentMode: .fill)
                                    case .failure:
                                        ZStack { // Fallback if image fails to load
                                            Color.givabitLighterPurple.opacity(0.3)
                                            Image(systemName: "photo.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 50, height: 50)
                                                .foregroundColor(Color.givabitAccent.opacity(0.7))
                                            Text("Image not available")
                                                .font(.caption)
                                                .foregroundColor(Color.givabitAccent.opacity(0.7))
                                                .padding(.top, 60)
                                        }
                                    @unknown default:
                                        EmptyView()
                                    }
                                }
                                .frame(height: 220)
                                .clipped()
                                .cornerRadius(0) // No corner radius for full width image as per design
                                
                                // Description is NOT in BuyLinkDetail, use a placeholder or remove
                                Text("Description placeholder - API for /buy/ does not include description.")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundColor(Color.givabitAccent.opacity(0.9))
                                    .lineSpacing(5)
                                    .padding(.horizontal)
                                
                                HStack(spacing: 10) {
                                    Image(systemName: "person.circle.fill") 
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                        .foregroundColor(Color.givabitAccent)
                                    Text("by \(fetchedDetail.creatorAddress.prefix(10))...") // Display part of creatorAddress
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color.white)
                                }
                                .padding(.horizontal)
                                
                                Spacer(minLength: 20)
                                
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
                                        } else { Text("$?.??").font(.system(size: 28, weight: .bold)).foregroundColor(Color.white.opacity(0.7)) }
                                        if let btc = displayPriceBTC {
                                            Text("\(FormattingUtils.formatBtcB(btc, maxFractionDigits: 7)) BTC")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(Color.givabitAccent.opacity(0.8))
                                        } else { Text("-.------- BTC").font(.system(size: 14, weight: .medium)).foregroundColor(Color.givabitAccent.opacity(0.7)) }
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
                                print("Approve payment tapped for \(fetchedDetail.buyShortCode). ERC20 to pay: \(fetchedDetail.priceInERC20)")
                                // TODO: Implement payment using fetchedDetail.priceInERC20, fetchedDetail.paymentContractAddress, etc.
                            }) {
                                Text("Approve payment")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(Color.givabitPurple)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .cornerRadius(25)
                            }
                            .disabled(detailService.isLoading) // Disable while loading, or if priceInERC20 is invalid (add check)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 30)
                        }
                    }
                } else if let errorMessage = detailService.errorMessage {
                    Text("Error: \(errorMessage)")
                        .foregroundColor(.red).padding().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    Text("Loading...") // Simplified initial state before fetch or if error before loading state change
                        .foregroundColor(Color.givabitAccent).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                detailService.fetchDetails(for: buyContext.shortCode)
            }
            .onChange(of: detailService.buyLinkDetail) { newDetail in // React to fetched detail
                if let detail = newDetail {
                    setupPriceDetails(fromERC20String: detail.priceInERC20)
                } else {
                    // Clear prices if detail becomes nil (e.g., error after successful fetch)
                    displayPriceUSD = nil
                    displayPriceBTC = nil
                }
            }
        }
    }
    
    private func setupPriceDetails(fromERC20String priceERC20Str: String?) {
        guard let erc20String = priceERC20Str, 
              let priceInSmallestUnit = Decimal(string: erc20String), 
              let btcPriceUSD = blockchainService.currentBTCPriceUSD, btcPriceUSD > 0 else {
            print("BuyContentView: Could not calculate USD/BTC price - priceInERC20 string missing/invalid or BTC price feed missing.")
            self.displayPriceUSD = nil
            self.displayPriceBTC = nil
            return
        }
        let tokenAmountInFull = priceInSmallestUnit / pow(10, 18)
        self.displayPriceUSD = tokenAmountInFull * btcPriceUSD
        self.displayPriceBTC = tokenAmountInFull
        print("BuyContentView: Prices updated - USD: \(self.displayPriceUSD ?? 0), BTC: \(self.displayPriceBTC ?? 0)")
    }
}

// MARK: - Preview
struct BuyContentView_Previews: PreviewProvider {
    static var previews: some View {
        // 1. Mock BlockchainService
        let mockBlockchain = BlockchainService()
        // Provide a realistic BTC price for preview calculations
        mockBlockchain.currentBTCPriceUSD = Decimal(string: "60000.00") 

        // 2. Mock BuyLinkContext (passed to BuyContentView)
        // This priceInERC20 will be used by BuyContentView's onAppear -> setupPriceDetails
        let previewContext = BuyLinkContext(id: "vR79fTz", 
                                          shortCode: "vR79fTz", 
                                          priceInERC20: "15000000000000000") // e.g., 1.5 tokens

        // 3. Create BuyContentView with a ContentDetailService that has mock data
        let buyContentView: BuyContentView = {
            let view = BuyContentView(buyContext: previewContext, blockchainService: mockBlockchain)
            // Pre-populate the detailService within this specific view instance for the preview
            view.detailService.isLoading = false
            view.detailService.errorMessage = nil
            view.detailService.buyLinkDetail = BuyLinkDetail(
                linkId: "0x0dd8b40b0868db8588f0293da06397a12ce68f00316217a19489d2b061cf36fe",
                buyShortCode: "vR79fTz",
                title: "Epic Content Title for Preview",
                creatorAddress: "0xe81430d54414dc122a6cd8ef48834fd17a41141b",
                priceInERC20: "15000000000000000", // Should match context or be the source
                paymentContractAddress: "0x6a064800b5255d6a4732f28cb297ffa14e098bc1",
                isActiveOnDb: 1
            )
            return view
        }()

        return buyContentView
            .preferredColorScheme(.dark)
    }
}
