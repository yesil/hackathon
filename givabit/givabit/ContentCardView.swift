import SwiftUI

// MARK: - ContentCardView
struct ContentCardView: View {
    let link: LinkItem

    // Helper to format date string to a more readable format
    private func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss" // Input format from API
        guard let date = dateFormatter.date(from: dateString) else {
            return dateString // Return original if parsing fails
        }
        dateFormatter.dateFormat = "dd MMM yyyy, HH:mm" // Desired output format
        return dateFormatter.string(from: date)
    }
    
    // Placeholder for fetching image based on URL or type
    private func getImageForLink(_ link: LinkItem) -> String {
        // Basic logic: if URL contains 'youtube', use youtube icon, etc.
        // This can be expanded with more sophisticated logic or a default image.
        if link.originalUrl.lowercased().contains("youtube.com") || link.originalUrl.lowercased().contains("youtu.be") {
            return "video.circle.fill" // SF Symbol for video
        } else if link.originalUrl.lowercased().contains("instagram.com") {
            return "photo.on.rectangle.angled" // SF Symbol for photo/social
        } else if link.originalUrl.lowercased().contains("twitter.com") || link.originalUrl.lowercased().contains("x.com") {
            return "bubble.left.and.bubble.right.fill" // SF Symbol for social/text
        }
        return "link.circle.fill" // Default SF Symbol for a link
    }
    
    private var earningsUSD: String {
        // Assuming priceInERC20 needs conversion. For now, placeholder.
        // This will require actual conversion logic based on ERC20 token price and amount.
        // The API provides priceInERC20, which needs to be interpreted.
        // For mockup purposes, let's display a static value or a transformation of priceInERC20.
        let mockUSDValue = (Double(link.priceInERC20) ?? 0) / 1_000_000_000_000_000_000 * 2000 // Example conversion
        return String(format: "$%.2f", mockUSDValue)
    }

    private var earningsBTC: String {
        // Placeholder for BTC earnings. Needs actual calculation.
        // Let's assume 1 USD = 0.000017 BTC for mockup
        let mockUSDValue = (Double(link.priceInERC20) ?? 0) / 1_000_000_000_000_000_000 * 2000
        let mockBTCValue = mockUSDValue * 0.000017 
        return String(format: "%.7f BTC", mockBTCValue)
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 15) {
                // Placeholder for Image - Using an SF Symbol for now
                Image(systemName: getImageForLink(link))
                    .font(.system(size: 40))
                    .foregroundColor(Color.givabitAccent)
                    .frame(width: 60, height: 60)
                    .background(Color.givabitPurple.opacity(0.5))
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(link.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.white)
                        .lineLimit(2) // Allow title to wrap to two lines

                    Text(formatDate(link.createdAt))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.givabitAccent.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(earningsUSD)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.white)
                    Text(earningsBTC)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.givabitAccent.opacity(0.8))
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // "Total earnings:" text - Mimicking the reference image
            Text("Total earnings:")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Color.givabitAccent.opacity(0.9))
                .padding(.leading) // Align with the image/icon start
                .padding(.top, 8) // Space from the content above

            // "See details" Button
            Button(action: {
                // TODO: Action for see details
                print("See details for \(link.linkId) tapped")
            }) {
                Text("See details")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.givabitAccent) // Use accent color for the button text
                    .padding(.vertical, 8)
                    .padding(.leading)
            }
        }
        .padding(.bottom, 10) // Add some padding at the bottom of the card
        .background(Color.givabitLighterPurple.opacity(0.7)) // Match WalletView2 card background
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}

// MARK: - Preview
struct ContentCardView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a sample LinkItem for previewing
        let sampleLink = LinkItem(
            linkId: "previewLinkId123",
            title: "FAKER FULL INTERVIEW - EXCLUSIVE",
            buyShortCode: "PREVIEW",
            accessShortCode: "PVWACC",
            originalUrl: "https://www.youtube.com/watch?v=example",
            priceInERC20: "1800000000000000000", // Represents 1.8 of the token (assuming 18 decimals)
            isActive: 1,
            createdAt: "2025-05-23 11:25:00",
            shareableBuyLink: "https://example.com/buy/PREVIEW",
            socialPosts: SocialPosts(twitter: "Twitter post", instagram: "Insta post")
        )

        ScrollView { // Added ScrollView for better preview context
            VStack(spacing: 20) {
                 ContentCardView(link: sampleLink)
                 ContentCardView(link: LinkItem(
                    linkId: "previewLinkId456",
                    title: "Another Great Content Item",
                    buyShortCode: "ANOTHER",
                    accessShortCode: "ANOACC",
                    originalUrl: "https://www.someotherlink.com/article/story",
                    priceInERC20: "2500000000000000000", // 2.5 tokens
                    isActive: 1,
                    createdAt: "2025-05-22 10:15:00",
                    shareableBuyLink: "https://example.com/buy/ANOTHER",
                    socialPosts: SocialPosts(twitter: "Another tweet", instagram: "Another picture")
                ))
            }
            .padding()
        }
        .background(Color.givabitPurple)
        .preferredColorScheme(.dark)
    }
} 