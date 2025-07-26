import SwiftUI
import WebKit

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
                    .padding(10)
            }
            .disabled(!model.getWebBrowser().canGoBack)
            Button {
                model.getWebBrowser().goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .padding(10)
            }
            .disabled(!model.getWebBrowser().canGoForward)
        }
    }
}

private struct RefreshHomeView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var webBrowser: WebBrowserSettings
    @Binding var showingBookmarks: Bool

    var body: some View {
        HStack {
            Button {
                model.getWebBrowser().reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .padding(10)
            }
            Button {
                showingBookmarks = true
            } label: {
                Image(systemName: "bookmark")
                    .padding(5)
            }
            Button {
                model.loadWebBrowserHome()
            } label: {
                Image(systemName: "house")
                    .padding(10)
            }
        }
    }
}

private struct BookmarksView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var webBrowser: WebBrowserSettings
    @Binding var showingBookmarks: Bool

    var body: some View {
        VStack {
            Form {
                Section {
                    List {
                        ForEach(webBrowser.bookmarks) { bookmark in
                            Button(bookmark.url) {
                                model.loadWebBrowserPage(url: bookmark.url)
                                showingBookmarks = false
                            }
                        }
                        .onDelete {
                            webBrowser.bookmarks.remove(atOffsets: $0)
                        }
                    }
                } header: {
                    Text("Bookmarks")
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: "a bookmark")
                }
                Section {
                    Button {
                        let bookmark = WebBrowserBookmarkSettings()
                        bookmark.url = model.webBrowserUrl
                        webBrowser.bookmarks.append(bookmark)
                    } label: {
                        HCenter {
                            Text("Create bookmark")
                        }
                    }
                }
            }
            HCenter {
                Text("Swipe down to close")
            }
        }
    }
}

struct WebBrowserView: View {
    @EnvironmentObject var model: Model
    @State var showingBookmarks = false

    var body: some View {
        VStack(spacing: 0) {
            if model.isPortrait() {
                VStack {
                    UrlView()
                    HStack {
                        NextPrevView()
                        Spacer()
                        RefreshHomeView(webBrowser: model.database.webBrowser, showingBookmarks: $showingBookmarks)
                    }
                }
                .padding(3)
            } else {
                HStack {
                    NextPrevView()
                    UrlView()
                    RefreshHomeView(webBrowser: model.database.webBrowser, showingBookmarks: $showingBookmarks)
                }
                .padding(3)
            }
            WebView()
                .sheet(isPresented: $showingBookmarks) {
                    BookmarksView(webBrowser: model.database.webBrowser, showingBookmarks: $showingBookmarks)
                }
        }
        .background(ignoresSafeAreaEdges: .bottom)
    }
}
