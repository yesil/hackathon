import SwiftUI

// MARK: - Request Data Model
struct CreateContentRequest: Codable {
    let url: String
    let title: String
    let priceInUSD_display: String // Keep as String as per your JSON example
    let priceInERC20: String
    let creatorAddress: String
}

// MARK: - NewContentView
struct NewContentView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var blockchainService: BlockchainService // Passed from parent

    @State private var projectTitle: String = ""
    @State private var priceInUSD_display: String = ""
    @State private var contentLink: String = ""
    
    @State private var selectedCurrency: String = "USD" // Assuming USD for now
    let currencies = ["USD"] // Extend if more currencies are supported by the backend

    @State private var isSubmitting: Bool = false
    @State private var submissionError: String? = nil
    @State private var submissionSuccess: Bool = false
    
    // Instantiate the ContentCreationService
    private let contentCreationService = ContentCreationService()

    var body: some View {
        NavigationView {
            ZStack {
                Color.givabitPurple.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("New project")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(Color.white)
                            .padding(.bottom, 10)

                        // Project Title
                        Text("Project title")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.givabitAccent.opacity(0.8))
                        
                        TextField("Enter project title", text: $projectTitle)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(12)
                            .background(Color.givabitLighterPurple.opacity(0.5))
                            .foregroundColor(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.givabitAccent.opacity(0.7), lineWidth: 1)
                            )

                        // Price of Content
                        priceOfContentSection

                        // Link to Content
                        Text("Link to content")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color.givabitAccent.opacity(0.8))
                        
                        TextField("https://...", text: $contentLink)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(12)
                            .background(Color.givabitLighterPurple.opacity(0.5))
                            .foregroundColor(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.givabitAccent.opacity(0.7), lineWidth: 1)
                            )
                        
                        Spacer(minLength: 30)

                        // Submit Button
                        Button(action: handleSubmit) {
                            Text("Apply & Next step")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color.givabitPurple)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.white)
                                .cornerRadius(25)
                        }
                        .disabled(isSubmitting) // Disable button while submitting
                        
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.top, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        if let error = submissionError {
                            Text("Error: \\(error)")
                                .foregroundColor(.red)
                                .padding(.top, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        
                        if submissionSuccess {
                             Text("Content created successfully!")
                                .foregroundColor(.green)
                                .padding(.top, 10)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                    }
                    .padding()
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(Color.givabitAccent)
                    }
                }
            }
        }
    }

    // Extracted Price of Content Section
    private var priceOfContentSection: some View {
        VStack(alignment: .leading, spacing: 5) { // Added a VStack for structure if needed, or just return the HStack
            Text("Price of content")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.givabitAccent.opacity(0.8))
            HStack(spacing: 10) {
                TextField("0.00", text: $priceInUSD_display)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.givabitLighterPurple.opacity(0.5))
                    .foregroundColor(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.givabitAccent.opacity(0.7), lineWidth: 1)
                    )

                Picker("Currency", selection: $selectedCurrency) {
                    ForEach(currencies, id: \.self) { currency in
                        Text(currency)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding(10)
                .frame(width: 100)
                .background(Color.givabitLighterPurple.opacity(0.5))
                .accentColor(Color.givabitAccent)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.givabitAccent.opacity(0.7), lineWidth: 1)
                )
            }
        }
    }

    private func handleSubmit() {
        // 1. Validate inputs
        guard !projectTitle.isEmpty, !priceInUSD_display.isEmpty, !contentLink.isEmpty else {
            submissionError = "All fields are required."
            return
        }
        guard let priceUSD = Decimal(string: priceInUSD_display), priceUSD > 0 else {
            submissionError = "Invalid price. Must be a number greater than 0."
            return
        }
        guard let url = URL(string: contentLink), UIApplication.shared.canOpenURL(url) else {
            submissionError = "Invalid content link URL."
            return
        }

        // 2. Get data from BlockchainService
        let creatorAddress = blockchainService.walletAddress
        guard !creatorAddress.isEmpty else {
            submissionError = "Creator wallet address not found. Please ensure your wallet is set up."
            return
        }
        guard let btcPriceUSD = blockchainService.currentBTCPriceUSD, btcPriceUSD > 0 else {
            submissionError = "Could not fetch current BTC price. Please try again later."
            // Potentially trigger a refresh of blockchainService price data here if desired
            return
        }

        // 3. Calculate priceInERC20
        // Assuming the ERC20 token has 18 decimals (standard for many, like BTC.b on EVM)
        let priceInSmallestUnit = (priceUSD / btcPriceUSD) * pow(10, 18) // Use Int 18 for exponent
        
        // Ensure it's a whole number string for the API
        // And use the full RoundingMode enum name
        let priceInERC20String = "\(priceInSmallestUnit.rounded(0, NSDecimalNumber.RoundingMode.plain))"


        // 4. Construct request data
        let requestData = CreateContentRequest(
            url: contentLink,
            title: projectTitle,
            priceInUSD_display: priceInUSD_display, // Keep original string input
            priceInERC20: priceInERC20String,
            creatorAddress: creatorAddress
        )
        
        print("Request Data Prepared: \\(requestData)")
        isSubmitting = true
        submissionError = nil
        submissionSuccess = false

        contentCreationService.createLink(requestData: requestData) { result in
            DispatchQueue.main.async {
                isSubmitting = false
                switch result {
                case .success:
                    submissionSuccess = true
                    print("Successfully submitted new content to server.")
                    // Optionally dismiss after a short delay or navigate
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        presentationMode.wrappedValue.dismiss()
                    }
                case .failure(let error):
                    print("Error submitting new content: \(error.localizedDescription)")
                    submissionError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Preview
struct NewContentView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock BlockchainService for the preview
        let mockBlockchainService = BlockchainService()
        // Set some mock data for previewing calculations
        mockBlockchainService.walletAddress = "0x1234567890abcdef1234567890abcdef12345678"
        mockBlockchainService.currentBTCPriceUSD = Decimal(string: "30000.00") // Example BTC price

        return NewContentView(blockchainService: mockBlockchainService)
            .preferredColorScheme(.dark)
    }
}

// Helper extension for Decimal rounding if not available
extension Decimal {
    func rounded(_ scale: Int, _ roundingMode: NSDecimalNumber.RoundingMode) -> Decimal {
        var roundedValue = Decimal()
        var value = self
        NSDecimalRound(&roundedValue, &value, scale, roundingMode)
        return roundedValue
    }
} 