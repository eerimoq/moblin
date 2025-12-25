import SwiftUI
import WebKit

private let smallBrowserSide = 250.0

struct WebView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> WKWebView {
        return model.getWebBrowser()
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

private struct UrlView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        TextField("Search with Google or enter address", text: $model.webBrowserUrl)
            .padding(5)
            .overlay(RoundedRectangle(cornerRadius: 5)
                .stroke(.secondary, lineWidth: 1))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit {
                model.webBrowserUrl = model.webBrowserUrl.trim()
                model.loadWebBrowserUrl()
            }
    }
}

private struct NextPrevView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        HStack {
            Button {
                model.getWebBrowser().goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .padding(7)
            }
            .disabled(!model.getWebBrowser().canGoBack)
            Button {
                model.getWebBrowser().goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .padding(7)
            }
            .disabled(!model.getWebBrowser().canGoForward)
        }
    }
}

private struct RefreshBookmarksView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var webBrowser: WebBrowserSettings
    @Binding var showingBookmarks: Bool
    @Binding var isSmall: Bool

    var body: some View {
        HStack {
            Button {
                model.getWebBrowser().reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .padding(7)
            }
            Button {
                showingBookmarks = true
            } label: {
                Image(systemName: "bookmark")
                    .padding(7)
            }
            Button {
                isSmall.toggle()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .padding(7)
            }
        }
    }
}

private struct BookmarksView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var webBrowser: WebBrowserSettings
    @Binding var presentingBookmarks: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    List {
                        ForEach(webBrowser.bookmarks) { bookmark in
                            HStack {
                                DraggableItemPrefixView()
                                Button {
                                    model.loadWebBrowserPage(url: bookmark.url)
                                    presentingBookmarks = false
                                } label: {
                                    Text(bookmark.url)
                                }
                            }
                        }
                        .onDelete {
                            webBrowser.bookmarks.remove(atOffsets: $0)
                        }
                        .onMove { froms, to in
                            webBrowser.bookmarks.move(fromOffsets: froms, toOffset: to)
                        }
                    }
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a bookmark"))
                }
                Section {
                    TextButtonView("Create bookmark") {
                        let bookmark = WebBrowserBookmarkSettings()
                        bookmark.url = model.webBrowserUrl
                        webBrowser.bookmarks.append(bookmark)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .toolbar {
                CloseToolbar(presenting: $presentingBookmarks)
            }
        }
    }
}

private struct WebBrowserSmallView: View {
    @ObservedObject var database: Database
    @ObservedObject var webBrowserState: WebBrowserState

    private func offset(metrics _: GeometryProxy) -> Double {
        if database.bigButtons {
            return -(2 * segmentHeightBig + 10)
        } else {
            return -(2 * segmentHeight + 10)
        }
    }

    private func mapSide(maximum: Double) -> Double {
        return min(maximum - 130, smallBrowserSide)
    }

    var body: some View {
        GeometryReader { metrics in
            ZStack {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        WebView()
                            .background(.clear)
                            .frame(maxWidth: mapSide(maximum: metrics.size.width),
                                   maxHeight: mapSide(maximum: metrics.size.height))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                            .padding([.trailing], 3)
                    }
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            webBrowserState.isSmall.toggle()
                        } label: {
                            if #available(iOS 26, *) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .foregroundStyle(.primary)
                                    .frame(width: 12, height: 12)
                                    .padding()
                                    .glassEffect()
                                    .padding([.trailing, .bottom], 10)
                            } else {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .foregroundStyle(.primary)
                                    .frame(width: 12, height: 12)
                                    .padding()
                                    .padding([.trailing, .bottom], 10)
                            }
                        }
                    }
                }
            }
            .offset(CGSize(width: 0, height: offset(metrics: metrics)))
        }
    }
}

private struct WebBrowserBigView: View {
    @ObservedObject var database: Database
    @ObservedObject var orientation: Orientation
    @ObservedObject var webBrowserState: WebBrowserState
    @State private var presentingBookmarks = false

    var body: some View {
        VStack(spacing: 0) {
            if orientation.isPortrait {
                VStack {
                    UrlView()
                    HStack {
                        NextPrevView()
                        Spacer()
                        RefreshBookmarksView(webBrowser: database.webBrowser,
                                             showingBookmarks: $presentingBookmarks,
                                             isSmall: $webBrowserState.isSmall)
                    }
                }
                .padding(3)
                .background(ignoresSafeAreaEdges: .bottom)
            } else {
                HStack {
                    NextPrevView()
                    UrlView()
                    RefreshBookmarksView(webBrowser: database.webBrowser,
                                         showingBookmarks: $presentingBookmarks,
                                         isSmall: $webBrowserState.isSmall)
                }
                .padding(3)
                .background(ignoresSafeAreaEdges: .bottom)
            }
            WebView()
                .sheet(isPresented: $presentingBookmarks) {
                    BookmarksView(webBrowser: database.webBrowser,
                                  presentingBookmarks: $presentingBookmarks)
                }
        }
        .background(.clear, ignoresSafeAreaEdges: .bottom)
    }
}

struct WebBrowserView: View {
    let database: Database
    let orientation: Orientation
    @ObservedObject var webBrowserState: WebBrowserState

    var body: some View {
        if webBrowserState.isSmall {
            WebBrowserSmallView(database: database, webBrowserState: webBrowserState)
        } else {
            WebBrowserBigView(database: database, orientation: orientation, webBrowserState: webBrowserState)
        }
    }
}
