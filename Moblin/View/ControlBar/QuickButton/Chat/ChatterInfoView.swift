import SwiftUI

struct ChatterInfo {
    var profilePic: String?
    var bio: String?
    var accountCreated: String?
    var role: String?
    var followingSince: String?
    var subscribedMonths: Int?
    var subscribedTier: String?
    var giftedSubs: Int?
    var followers: Int?
}

private func parseDate(_ dateString: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) {
        return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: dateString)
}

private func formatDate(_ dateString: String) -> String? {
    guard let date = parseDate(dateString) else {
        return nil
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "d MMM yyyy"
    return formatter.string(from: date)
}

private struct InfoRowView: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(LocalizedStringKey(label))
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
                .foregroundStyle(.white)
        }
        .padding(.vertical, 2)
    }
}

struct ChatterInfoView: View {
    let model: Model
    let post: ChatPost
    @Binding var showingChatterInfo: Bool
    @State private var chatterInfo: ChatterInfo?
    @State private var loading = true
    @State private var errorMessage: String?

    private func fetchInfo() {
        guard let user = post.user else {
            errorMessage = String(localized: "Failed to load chatter info")
            loading = false
            return
        }
        switch post.platform {
        case .kick:
            model.getKickChatterInfo(user: user) { info in
                DispatchQueue.main.async {
                    if let info {
                        chatterInfo = info
                    } else {
                        errorMessage = String(localized: "Failed to load chatter info")
                    }
                    loading = false
                }
            }
        default:
            errorMessage = String(localized: "Failed to load chatter info")
            loading = false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    showingChatterInfo = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                Spacer()
                Text("Chatter Info")
                    .bold()
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .hidden()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            if loading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let errorMessage {
                Spacer()
                Text(errorMessage)
                    .foregroundStyle(.gray)
                Spacer()
            } else if let info = chatterInfo {
                ScrollView {
                    VStack(spacing: 12) {
                        profileHeader(info: info)
                        infoRows(info: info)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                }
            }
        }
        .foregroundStyle(.white)
        .background(.black)
        .onAppear {
            fetchInfo()
        }
    }

    private func profileHeader(info: ChatterInfo) -> some View {
        HStack(spacing: 10) {
            if let profilePic = info.profilePic, let url = URL(string: profilePic) {
                CacheAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(.gray.opacity(0.3))
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(post.displayName(
                        nicknames: model.database.chat.nicknames,
                        displayStyle: model.database.chat.displayStyle
                    ))
                    .bold()
                    if let image = post.platform?.imageName() {
                        Image(image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 16)
                    }
                }
                HStack(spacing: 2) {
                    ForEach(post.userBadges, id: \.self) { url in
                        CacheAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } placeholder: {
                            EmptyView()
                        }
                        .frame(height: 18)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func infoRows(info: ChatterInfo) -> some View {
        VStack(spacing: 4) {
            if let accountCreated = info.accountCreated, let formatted = formatDate(accountCreated) {
                InfoRowView(label: "Account Created", value: formatted)
            }
            if let role = info.role {
                InfoRowView(label: "Role", value: role)
            }
            if let followingSince = info.followingSince, let formatted = formatDate(followingSince) {
                InfoRowView(label: "Followed", value: formatted)
            } else {
                InfoRowView(label: "Followed", value: String(localized: "No"))
            }
            if let months = info.subscribedMonths, months > 0 {
                InfoRowView(label: "Subscribed", value: "\(months) months")
            } else {
                InfoRowView(label: "Subscribed", value: String(localized: "No"))
            }
            if let giftedSubs = info.giftedSubs {
                InfoRowView(label: "Gifted Subs", value: "\(giftedSubs)")
            }
            if let followers = info.followers {
                InfoRowView(label: "Followers", value: "\(followers)")
            }
            if let bio = info.bio, !bio.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bio")
                        .foregroundStyle(.gray)
                    Text(bio)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }
        }
    }
}
