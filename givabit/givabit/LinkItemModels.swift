import Foundation

// MARK: - Shared Data Models for Link Items

struct LinkItem: Identifiable, Decodable {
    let id = UUID() 
    let linkId: String
    let title: String
    let buyShortCode: String
    let accessShortCode: String
    let originalUrl: String
    let priceInERC20: String
    let isActive: Int
    let createdAt: String 
    let shareableBuyLink: String
    let socialPosts: SocialPosts?
}

struct SocialPosts: Decodable {
    let twitter: String?
    let instagram: String?
}

// Response structure for the creator links list endpoint
struct CreatorLinksResponse: Decodable {
    let links: [LinkItem]
}


// MARK: - Data Model for /buy/{buyShortCode} API Response
struct BuyLinkDetail: Identifiable, Decodable, Equatable {
    var id: String { linkId } // Use linkId as the unique ID
    let linkId: String
    let buyShortCode: String
    let title: String
    let creatorAddress: String
    let priceInERC20: String
    let paymentContractAddress: String
    let isActiveOnDb: Int
    // Note: Description is NOT part of this response structure.
} 