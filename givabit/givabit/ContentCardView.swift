import SwiftUI

// MARK: - ContentCardView
struct ContentCardView: View {
    let link: LinkItem
    @ObservedObject var blockchainService: BlockchainService

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
    
    private var tokenAmountInFullUnits: Decimal {
        guard let priceInSmallestUnit = Decimal(string: link.priceInERC20) else {
            return 0
        }
        // Assuming priceInERC20 is in the smallest unit and the token has 18 decimals
        return priceInSmallestUnit / pow(10, 18)
    }

    private var earningsUSD: String {
        // TEMPORARY PREVIEW DEBUG: Return hardcoded string
        // return "$1.80"
        guard let btcPrice = blockchainService.currentBTCPriceUSD, btcPrice > 0 else {
            return "$?.??" // Price not available
        }
        let usdValue = tokenAmountInFullUnits * btcPrice
        return FormattingUtils.formatUsd(usdValue) // Use your existing formatting utility
    }

    private var earningsBTC: String {
        // TEMPORARY PREVIEW DEBUG: Return hardcoded string
        // return "0.0000304 BTC"
        let btcValue = tokenAmountInFullUnits
        return "\(FormattingUtils.formatBtcB(btcValue, maxFractionDigits: 7)) BTC" // Use your formatting utility
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
