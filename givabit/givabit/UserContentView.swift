import SwiftUI

// LinkItem, SocialPosts, and ApiResponse (if it was only for links) are now in LinkItemModels.swift
// and should be removed from here.

// MARK: - API Service (for creator links list)
class ContentAPIService: ObservableObject {
    @Published var links: [LinkItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    private let creatorWalletAddress: String
    private var endpointUrl: String {
        "https://givabit-server-krlus.ondigitalocean.app/links/creator/\(creatorWalletAddress)"
    }

    init(creatorWalletAddress: String) {
        self.creatorWalletAddress = creatorWalletAddress
    }

    // Updated to be an async function
    func fetchContent() async throws {
        guard let url = URL(string: endpointUrl) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid URL"
            }
            throw ContentAPIError.invalidURL // Define this error type or use a generic one
        }

        print("Fetching content from URL: \(endpointUrl)")

        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }

        // Using try await with URLSession's async data method
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Log raw response before attempting to decode
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Raw JSON response received: \(jsonString)")
        } else {
            print("Could not convert raw data to string for logging (before decoding attempt).")
        }

        // Check response status code if needed, e.g., guard (response as? HTTPURLResponse)?.statusCode == 200 else { ... }
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("HTTP Error: Status code \(statusCode)")
            // Optionally capture more response details for the error
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Server error (status: \(statusCode))"
            }
            throw ContentAPIError.serverError(statusCode: statusCode) // Define this error
        }

        do {
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            decoder.dateDecodingStrategy = .formatted(dateFormatter)

            let apiResponse = try decoder.decode(CreatorLinksResponse.self, from: data)
            
            DispatchQueue.main.async {
                self.links = apiResponse.links
                self.isLoading = false
                if apiResponse.links.isEmpty {
                    print("API returned an empty list of links.")
                } else {
                    print("Successfully fetched and decoded \(apiResponse.links.count) link(s).")
                }
            }
        } catch let decodingError as DecodingError {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Failed to decode JSON: \(decodingError.localizedDescription)"
            }
            print("----------------------------------------------------")
            print("!!! JSON DECODING ERROR CAUGHT !!!")
            print("ErrorMessage to be set: Failed to decode JSON: \(decodingError.localizedDescription)")
            print("Full Error Object: \(decodingError)") 
            print("----------------------------------------------------")
            print("Breaking down error further:")
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
            throw decodingError // Re-throw the decoding error
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            }
            print("****************************************************")
            print("!!! GENERIC ERROR DURING DECODING OR OTHER UNHANDLED ERROR !!!")
            print("ErrorMessage to be set: An unexpected error occurred: \(error.localizedDescription)")
            print("Full Error Object: \(error)")
            print("****************************************************")
            throw error // Re-throw
        }
    }
}

// Define a simple error enum for ContentAPIService if not already present
enum ContentAPIError: Error, LocalizedError {
    case invalidURL
    case serverError(statusCode: Int)
    // Add other specific errors as needed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The API endpoint URL is invalid."
        case .serverError(let statusCode):
            return "The server returned an error (Status Code: \(statusCode))."
        }
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
    @State private var showingNewContentView = false // State to present NewContentView as a sheet
    
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
                            showingNewContentView = true // Set state to true to show the sheet
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
                                    ContentCardView(link: link, blockchainService: blockchainService)
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
                .refreshable {
                    print("Refresh triggered for My Past Contents")
                    do {
                        try await apiService.fetchContent()
                    } catch {
                        // The error should already be set on apiService.errorMessage by fetchContent
                        // You could add additional logging here if specific to the refresh action
                        print("Error during pull-to-refresh: \(error.localizedDescription)")
                    }
                }
                .navigationBarHidden(true)
            }
            .onAppear {
                // Ensure walletAddress is not empty before fetching
                if !blockchainService.walletAddress.isEmpty {
                    Task {
                        do {
                            try await apiService.fetchContent()
                        } catch {
                            // Error is already set on apiService.errorMessage by fetchContent itself
                            print("Error during onAppear fetchContent: \(error.localizedDescription)")
                        }
                    }
                } else {
                    apiService.errorMessage = "Wallet address not available. Content will be fetched when address is ready."
                    print("UserContentView: Wallet address is initially empty. Waiting for it to become available.")
                }
            }
            .onChange(of: blockchainService.walletAddress) { newWalletAddress in
                if !newWalletAddress.isEmpty && apiService.links.isEmpty && (apiService.errorMessage != nil || apiService.links.isEmpty) {
                    print("UserContentView: Wallet address became available (\(newWalletAddress)). Fetching content.")
                    Task {
                        do {
                            try await apiService.fetchContent()
                        } catch {
                            // Error is already set on apiService.errorMessage by fetchContent itself
                            print("Error during onChange fetchContent: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAllContents) {
                AllContentsView(links: apiService.links, blockchainService: blockchainService)
            }
            // Add sheet modifier for NewContentView
            .sheet(isPresented: $showingNewContentView) {
                NewContentView(blockchainService: blockchainService)
            }
        }
    }
}

// MARK: - Placeholder for All Contents View
struct AllContentsView: View {
    let links: [LinkItem]
    @ObservedObject var blockchainService: BlockchainService
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color.givabitPurple.ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 15) {
                        ForEach(links) { link in
                            ContentCardView(link: link, blockchainService: blockchainService)
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