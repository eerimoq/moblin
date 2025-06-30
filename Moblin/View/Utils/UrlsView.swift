import SwiftUI

struct UrlCopyView: View {
    let model: Model
    let url: String
    let image: String

    var body: some View {
        HStack {
            Image(systemName: image)
            Text(url)
            Spacer()
            Button {
                UIPasteboard.general.string = url
                model.makeToast(title: "URL copied to clipboard")
            } label: {
                Image(systemName: "doc.on.doc")
            }
        }
    }
}

struct UrlsIpv4View: View {
    let model: Model
    @ObservedObject var status: StatusOther
    let formatUrl: (String) -> String

    var body: some View {
        Section {
            ForEach(status.ipStatuses.filter { $0.ipType == .ipv4 }) { status in
                UrlCopyView(
                    model: model,
                    url: formatUrl(status.ipType.formatAddress(status.ip)),
                    image: urlImage(interfaceType: status.interfaceType)
                )
            }
            UrlCopyView(
                model: model,
                url: formatUrl(personalHotspotLocalAddress),
                image: "personalhotspot"
            )
        } header: {
            Text("IPv4")
        }
    }
}

struct UrlsIpv6View: View {
    let model: Model
    @ObservedObject var status: StatusOther
    let formatUrl: (String) -> String

    var body: some View {
        Section {
            ForEach(status.ipStatuses.filter { $0.ipType == .ipv6 }) { status in
                UrlCopyView(
                    model: model,
                    url: formatUrl(status.ipType.formatAddress(status.ip)),
                    image: urlImage(interfaceType: status.interfaceType)
                )
            }
        } header: {
            Text("IPv6")
        }
    }
}
