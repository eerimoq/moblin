import SwiftUI

struct UrlCopyView: View {
    let url: String
    var image: String?

    init(_ url: String, image: String? = nil) {
        self.url = url
        self.image = image
    }

    var body: some View {
        HStack {
            if let image {
                Image(systemName: image)
            }
            Text(url)
            Spacer()
            CopyToClipboardButtonView(text: url)
        }
    }
}

struct UrlsIpv4View: View {
    @ObservedObject var status: StatusOther
    let formatUrl: (String) -> String

    var body: some View {
        Section {
            ForEach(status.ipStatuses.filter { $0.ipType == .ipv4 }) { status in
                UrlCopyView(formatUrl(status.ipType.formatAddress(status.ip)),
                            image: urlImage(interfaceType: status.interfaceType))
            }
            UrlCopyView(formatUrl(personalHotspotLocalAddress), image: "personalhotspot")
        } header: {
            Text("IPv4")
        }
    }
}

struct UrlsIpv6View: View {
    @ObservedObject var status: StatusOther
    let formatUrl: (String) -> String

    var body: some View {
        Section {
            ForEach(status.ipStatuses.filter { $0.ipType == .ipv6 }) { status in
                UrlCopyView(
                    formatUrl(status.ipType.formatAddress(status.ip)),
                    image: urlImage(interfaceType: status.interfaceType)
                )
            }
        } header: {
            Text("IPv6")
        }
    }
}

struct UrlsView: View {
    @ObservedObject var status: StatusOther
    var title: String = .init(localized: "URLs")
    var showIPv6: Bool = true
    let formatUrl: (String) -> String

    var body: some View {
        NavigationLink {
            Form {
                UrlsIpv4View(status: status, formatUrl: formatUrl)
                if showIPv6 {
                    UrlsIpv6View(status: status, formatUrl: formatUrl)
                }
            }
            .navigationTitle(title)
        } label: {
            Text(title)
        }
    }
}
