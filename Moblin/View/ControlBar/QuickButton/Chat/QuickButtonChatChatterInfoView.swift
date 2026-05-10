import SwiftUI

enum ChatterRole {
    case owner
    case staff
    case moderator
    case viewer

    func localized() -> String {
        switch self {
        case .owner:
            String(localized: "Owner")
        case .staff:
            String(localized: "Staff")
        case .moderator:
            String(localized: "Moderator")
        case .viewer:
            String(localized: "Viewer")
        }
    }
}

struct ChatterInfo {
    var profilePicture: String?
    var bio: String?
    var accountCreated: String?
    var role: ChatterRole
    var followingSince: String?
    var subscribedMonths: Int
    var giftedSubs: Int?
    var followers: Int?
}

private struct InfoRowView: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.gray)
            Spacer()
            Text(value)
        }
    }
}

struct QuickButtonChatChatterInfoView: View {
    let model: Model
    let post: ChatPost
    @Binding var presenting: Bool
    @State private var chatterInfo: ChatterInfo?
    @State private var loading = true
    @State private var errorMessage: String?

    private func setErrorMessage() {
        errorMessage = String(localized: "Failed to load chatter info")
    }

    private func fetchInfo() {
        guard let user = post.user else {
            setErrorMessage()
            loading = false
            return
        }
        switch post.platform {
        case .kick:
            model.getKickChatterInfo(user: user) { info in
                if let info {
                    chatterInfo = info
                } else {
                    setErrorMessage()
                }
                loading = false
            }
        default:
            setErrorMessage()
            loading = false
        }
    }

    private func profileHeader(info: ChatterInfo) -> some View {
        HStack(spacing: 10) {
            ChannelImageView(image: info.profilePicture)
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
        VStack(alignment: .leading, spacing: 4) {
            if let accountCreated = info.accountCreated, let formatted = formatDate(accountCreated) {
                InfoRowView(label: "Account created", value: formatted)
            }
            InfoRowView(label: "Role", value: info.role.localized())
            if let followingSince = info.followingSince, let formatted = formatDate(followingSince) {
                InfoRowView(label: "Followed", value: formatted)
            } else {
                InfoRowView(label: "Followed", value: String(localized: "No"))
            }
            if info.subscribedMonths > 0 {
                InfoRowView(label: "Subscribed", value: "\(info.subscribedMonths) months")
            } else {
                InfoRowView(label: "Subscribed", value: String(localized: "No"))
            }
            if let giftedSubs = info.giftedSubs {
                InfoRowView(label: "Gifted subs", value: "\(giftedSubs)")
            }
            if let followers = info.followers {
                InfoRowView(label: "Followers", value: "\(followers)")
            }
            if let bio = info.bio, !bio.isEmpty {
                Text("About")
                    .foregroundStyle(.gray)
                Text(bio)
                    .padding(.top, 4)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 1)
            ScrollView {
                ZStack {
                    if loading {
                        HCenter {
                            ProgressView()
                        }
                    } else if let errorMessage {
                        HCenter {
                            Text(errorMessage)
                                .foregroundStyle(.gray)
                        }
                    } else if let info = chatterInfo {
                        VStack {
                            profileHeader(info: info)
                            infoRows(info: info)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                    }
                    CloseButtonTopRightView {
                        presenting = false
                    }
                }
            }
            Color.clear.frame(height: 1)
        }
        .foregroundStyle(.white)
        .background(.black)
        .onAppear {
            fetchInfo()
        }
    }
}
