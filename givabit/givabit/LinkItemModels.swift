import Foundation // For UUID if still needed, or remove if id is from API

// MARK: - Shared Data Models for Link Items

struct LinkItem: Identifiable, Decodable {
    let id = UUID() // Using UUID for Identifiable conformance if API doesn't provide a stable Int/String ID for each item in lists.
                    // If `linkId` is guaranteed unique across all contexts, it could be `var id: String { linkId }`
    let linkId: String
    let title: String
    let buyShortCode: String
    let accessShortCode: String
    let originalUrl: String
    let priceInERC20: String
    let isActive: Int
    let createdAt: String // Will be decoded using the DateFormatter
    let shareableBuyLink: String
    let socialPosts: SocialPosts?
    // Add other fields if they come from the creator links list API
    // let description: String? // Example, if description can come from list
}

struct SocialPosts: Decodable {
    let twitter: String?
    let instagram: String?
}

// Response structure for the creator links list endpoint
struct CreatorLinksResponse: Decodable {
    let links: [LinkItem]
    // Add pagination here if the list endpoint supports it
    // struct Pagination: Decodable { let limit: Int, offset: Int, totalMatches: Int }
    // let pagination: Pagination?
}


// MARK: - Data Model for /info/{buyShortCode} API Response
struct ContentInfoResponse: Identifiable, Decodable {
    var id: String { buyShortCode } // Use buyShortCode as the unique ID for this item
    let buyShortCode: String
    let title: String
    let description: String
    // The following are NOT part of this specific API response as per user info:
    // - Main Image URL
    // - Author Name / Image URL
    // - priceInERC20 or other price details
    // These need to be sourced differently for the BuyContentView.
}

// If the /info endpoint returns a slightly different top-level structure, adjust here.
// For example, if it's not wrapped in an "ApiResponse" like the list endpoint was.
// Assuming for now the /info/{buyShortCode} endpoint directly returns a single LinkItem JSON object. 