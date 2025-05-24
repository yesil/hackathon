import SwiftUI

// MARK: - Data Models for API Response
struct LinkItem: Identifiable, Decodable {
    let id = UUID() // Add identifiable conformance for ForEach
    let linkId: String
    let title: String
    let buyShortCode: String
    let accessShortCode: String
    let originalUrl: String
    let priceInERC20: String
    let isActive: Int
    let createdAt: String
    let shareableBuyLink: String
    let socialPosts: SocialPosts

    // CodingKeys to map JSON keys to struct properties if names differ (optional if they match)
    enum CodingKeys: String, CodingKey {
        case linkId, title, buyShortCode, accessShortCode, originalUrl, priceInERC20, isActive, createdAt, shareableBuyLink, socialPosts
    }
}

struct SocialPosts: Decodable {
    let twitter: String?
    let instagram: String?
}

// The PaginationInfo struct will be removed.

struct ApiResponse: Decodable {
    let links: [LinkItem]
    // The pagination property will be removed.
}

// MARK: - API Service (Placeholder)
class ContentAPIService: ObservableObject {
    @Published var links: [LinkItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let creatorWalletAddress: String
    private var endpointUrl: String {
        "https://givabit-server-krlus.ondigitalocean.app/givabitserver/links/creator/\(creatorWalletAddress)"
    }

    init(creatorWalletAddress: String) {
        self.creatorWalletAddress = creatorWalletAddress
    }

    func fetchContent() {
        guard let url = URL(string: endpointUrl) else {
            errorMessage = "Invalid URL"
            return
        }

        print("Fetching content from URL: \(endpointUrl)") // Log the URL

        isLoading = true
        errorMessage = nil

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    print("####################################################")
                    print("!!! NETWORK ERROR OCCURRED !!!")
                    print("Error: \(error)")
                    print("Localized Description: \(error.localizedDescription)")
                    print("####################################################")
                    self.errorMessage = "Failed to fetch data: \(error.localizedDescription)"
                    return
                }

                guard let data = data else {
                    print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
                    print("!!! NO DATA RECEIVED FROM SERVER !!!")
                    print("Response object (if any): \(String(describing: response))")
                    print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
                    self.errorMessage = "No data received"
                    return
                }

                // Log raw response before attempting to decode
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw JSON response received: \(jsonString)")
                } else {
                    print("Could not convert raw data to string for logging (before decoding attempt).")
                }

                do {
                    let decoder = JSONDecoder()
                    // It's good practice to set a date decoding strategy if your dates are in a consistent format
                    // For example, if createdAt is always "yyyy-MM-dd HH:mm:ss":
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    dateFormatter.locale = Locale(identifier: "en_US_POSIX") // Important for consistent parsing
                    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0) // Assuming UTC if not specified
                    decoder.dateDecodingStrategy = .formatted(dateFormatter)

                    let apiResponse = try decoder.decode(ApiResponse.self, from: data)
                    self.links = apiResponse.links

                    if apiResponse.links.isEmpty {
                        // Since pagination is removed, we just log that the list is empty.
                        print("API returned an empty list of links.")
                        // If you still want to log the raw JSON when links are empty, you can add it here:
                        // if let jsonString = String(data: data, encoding: .utf8) {
                        //     print("Raw JSON response (empty links): \(jsonString)")
                        // }
                    } else {
                        print("Successfully fetched and decoded \(apiResponse.links.count) link(s).")
                    }

                } catch let decodingError as DecodingError {
                    print("----------------------------------------------------")
                    print("!!! JSON DECODING ERROR CAUGHT !!!")
                    print("ErrorMessage to be set: Failed to decode JSON: \(decodingError.localizedDescription)")
                    print("Full Error Object: \(decodingError)") // This will print the standard description of the error
                    print("----------------------------------------------------")

                    self.errorMessage = "Failed to decode JSON: \(decodingError.localizedDescription)"
                    print("Breaking down error further:")
                    
                    // Print specific details from DecodingError
                    switch decodingError {
                    case .typeMismatch(let type, let context):
                        print("Type mismatch: \(type), Context: \(context.debugDescription), Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .valueNotFound(let type, let context):
                        print("Value not found: \(type), Context: \(context.debugDescription), Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .keyNotFound(let key, let context):
                        print("Key not found: \(key.stringValue), Context: \(context.debugDescription), Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    case .dataCorrupted(let context):
                        print("Data corrupted: Context: \(context.debugDescription), Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
                    @unknown default:
                        print("An unknown decoding error occurred.")
                    }

                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("Raw JSON response causing error: \(jsonString)")
                    } else {
                        print("Could not convert raw data to string for logging.")
                    }
                } catch {
                    print("****************************************************")
                    print("!!! GENERIC ERROR DURING DECODING CAUGHT !!!")
                    print("ErrorMessage to be set: An unexpected error occurred during decoding: \(error.localizedDescription)")
                    print("Full Error Object: \(error)")
                    print("****************************************************")
                    // Catch any other non-DecodingError types
                    self.errorMessage = "An unexpected error occurred during decoding: \(error.localizedDescription)"
                    print("Unexpected error during decoding: \(error)")
                }
            }
        }.resume()
    }
}


// MARK: - UserContentView
struct UserContentView: View {
    // Option 1: If BlockchainService is an EnvironmentObject
    // @EnvironmentObject var blockchainService: BlockchainService 
    // For this change, let's assume it's passed in or available globally
    // For a more robust solution, an EnvironmentObject or passing as a parameter is better.
    // Let's modify it to take BlockchainService as a parameter for clarity

    @StateObject private var apiService: ContentAPIService
    @State private var showAllContents = false // To control navigation or sheet presentation
    
    // Store the blockchainService instance. Could be @ObservedObject if passed from parent.
    private var blockchainService: BlockchainService

    init(blockchainService: BlockchainService) {
        self.blockchainService = blockchainService
        // Initialize apiService with the wallet address from blockchainService
        _apiService = StateObject(wrappedValue: ContentAPIService(creatorWalletAddress: blockchainService.walletAddress))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.givabitPurple.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // New Content Button
                        Button(action: {
                            // TODO: Action for new content
                            print("New content button tapped")
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(Color.white) // Accent color for the icon
                                Text("New content")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color.white) // Accent text color
                            }
                            .padding(.vertical, 20)
                            .frame(maxWidth: .infinity)
                            .background(Color.givabitLighterPurple.opacity(0.8)) // Use a distinct background
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)


                        // My Past Contents Section
                        HStack {
                             Text("My past contents")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(Color.white)
                            Spacer()
                            Image(systemName: "chevron.up") // Example, can be dynamic
                                .foregroundColor(Color.givabitAccent)
                        }
                        .padding(.horizontal)
                        
                        if apiService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.givabitAccent))
                                .scaleEffect(1.5)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else if let errorMessage = apiService.errorMessage {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else if apiService.links.isEmpty {
                            Text("No content found.")
                                .foregroundColor(Color.givabitAccent.opacity(0.7))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            LazyVStack(spacing: 15) {
                                ForEach(apiService.links.prefix(3)) { link in // Display initial 3 items
                                    ContentCardView(link: link)
                                }
                            }
                            .padding(.horizontal)
                        }

                        // See All Past Contents Button
                        if apiService.links.count > 3 {
                            Button(action: {
                                // TODO: Navigate to a view showing all contents
                                showAllContents = true
                                print("See all past contents tapped")
                            }) {
                                Text("See all past contents")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color.givabitAccent)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)
                        }
                        Spacer() // Pushes content to the top
                    }
                }
                .navigationBarHidden(true)
            }
            .onAppear {
                // Ensure walletAddress is not empty before fetching
                if !blockchainService.walletAddress.isEmpty {
                    apiService.fetchContent()
                } else {
                    apiService.errorMessage = "Wallet address not available. Content will be fetched when address is ready."
                    print("UserContentView: Wallet address is initially empty. Waiting for it to become available.")
                }
            }
            .onChange(of: blockchainService.walletAddress) { newWalletAddress in
                if !newWalletAddress.isEmpty && apiService.links.isEmpty && (apiService.errorMessage != nil || apiService.links.isEmpty) {
                    print("UserContentView: Wallet address became available (\(newWalletAddress)). Fetching content.")
                    apiService.fetchContent()
                }
            }
            .sheet(isPresented: $showAllContents) {
                // TODO: Implement AllContentsView or similar
                // For now, just a placeholder
                AllContentsView(links: apiService.links)
            }
        }
    }
}

// MARK: - Placeholder for All Contents View
struct AllContentsView: View {
    let links: [LinkItem]
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color.givabitPurple.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(links) { link in
                            ContentCardView(link: link)
                        }
                    }
                    .padding()
                }
                .navigationTitle("All Contents")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .foregroundColor(Color.givabitAccent)
                    }
                }
            }
        }
    }
}


// MARK: - Preview
struct UserContentView_Previews: PreviewProvider {
    static var previews: some View {
        // For the preview to work, we need a mock BlockchainService instance
        let mockBlockchainService = BlockchainService() // Uses default config
        // You might want to set a dummy wallet address for preview if needed by ContentAPIService
        // mockBlockchainService.walletAddress = "0xPreviewWalletAddress"
        
        UserContentView(blockchainService: mockBlockchainService)
            .preferredColorScheme(.dark) // Match the app's theme
    }
} 