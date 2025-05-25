import SwiftUI

// MARK: - ContentCardView
struct ContentCardView: View {
    let link: LinkItem
    @ObservedObject var blockchainService: BlockchainService
    @State private var isShowingSocialPosts: Bool = false // State for toggling social posts
    @State private var twitterCopied: Bool = false // State for Twitter copy feedback
    @State private var instagramCopied: Bool = false // State for Instagram copy feedback

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
                withAnimation { // Add animation for a smoother toggle
                    isShowingSocialPosts.toggle()
                }
                print("See details for \(link.linkId) tapped. Social posts visible: \(isShowingSocialPosts)")
            }) {
                HStack { // Wrap in HStack to add a chevron icon
                    Text(isShowingSocialPosts ? "Hide details" : "See details")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: isShowingSocialPosts ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(Color.givabitAccent) 
                .padding(.vertical, 8)
                .padding(.leading)
            }

            // Display Social Posts if available and if toggled visible
            if isShowingSocialPosts, let socialPosts = link.socialPosts {
                VStack(alignment: .leading, spacing: 10) { // Increased spacing for tappable areas
                    if let twitterPost = socialPosts.twitter, !twitterPost.isEmpty {
                        Button(action: {
                            UIPasteboard.general.string = twitterPost
                            print("Copied Twitter post to clipboard: \(twitterPost)")
                            withAnimation {
                                self.twitterCopied = true
                                self.instagramCopied = false // Reset other if active
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    self.twitterCopied = false
                                }
                            }
                        }) {
                            HStack(alignment: .top) { 
                                Image(systemName: "at") 
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.givabitAccent.opacity(0.7))
                                    .padding(.top, 2) 
                                Text(twitterPost) 
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.givabitAccent.opacity(0.9))
                                    .lineLimit(3)
                                    // .textSelection(.enabled) // Removed in favor of tap-to-copy
                                Spacer() // Ensure button takes full width for easier tapping
                                Image(systemName: twitterCopied ? "checkmark.circle.fill" : "doc.on.doc") 
                                    .font(.system(size: twitterCopied ? 14 : 12, weight: twitterCopied ? .medium : .light))
                                    .foregroundColor(twitterCopied ? .green : Color.givabitAccent.opacity(0.6))
                            }
                        }
                        .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle to keep text color
                    }
                    if let instagramPost = socialPosts.instagram, !instagramPost.isEmpty {
                        Button(action: {
                            UIPasteboard.general.string = instagramPost
                            print("Copied Instagram post to clipboard: \(instagramPost)")
                            withAnimation {
                                self.instagramCopied = true
                                self.twitterCopied = false // Reset other if active
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    self.instagramCopied = false
                                }
                            }
                        }) {
                            HStack(alignment: .top) { 
                                Image(systemName: "camera.circle") 
                                    .font(.system(size: 14))
                                    .foregroundColor(Color.givabitAccent.opacity(0.7))
                                    .padding(.top, 2) 
                                Text(instagramPost) 
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.givabitAccent.opacity(0.9))
                                    .lineLimit(3)
                                    // .textSelection(.enabled) // Removed
                                Spacer() // Ensure button takes full width
                                Image(systemName: instagramCopied ? "checkmark.circle.fill" : "doc.on.doc") 
                                    .font(.system(size: instagramCopied ? 14 : 12, weight: instagramCopied ? .medium : .light))
                                    .foregroundColor(instagramCopied ? .green : Color.givabitAccent.opacity(0.6))
                            }
                        }
                        .buttonStyle(PlainButtonStyle()) // Use PlainButtonStyle
                    }
                }
                .padding(.horizontal)
                .padding(.top, 5)
                // Add padding to the bottom of the card if social posts are present, 
                // otherwise the main VStack's bottom padding will apply.
                .padding(.bottom, (socialPosts.twitter != nil || socialPosts.instagram != nil) ? 10 : 0)
            }
        }
        .padding(.bottom, 10) // This was the original overall bottom padding, may need adjustment if the above is added
        .background(Color.givabitLighterPurple.opacity(0.7)) // Match WalletView2 card background
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
    }
}
