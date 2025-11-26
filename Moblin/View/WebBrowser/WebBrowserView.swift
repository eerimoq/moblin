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

private struct RefreshBookmarksView: View {
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
                    .padding(10)
            }
        }
    }
}

private struct BookmarksToolbar: ToolbarContent {
    @Binding var showingBookmarks: Bool

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingBookmarks = false
            } label: {
                Image(systemName: "xmark")
            }
        }
    }
}

private struct BookmarksView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var webBrowser: WebBrowserSettings
    @Binding var showingBookmarks: Bool

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
                                    showingBookmarks = false
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
                BookmarksToolbar(showingBookmarks: $showingBookmarks)
            }
        }
    }
}

struct WebBrowserView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var orientation: Orientation
    @State var showingBookmarks = false

    var body: some View {
        VStack(spacing: 0) {
            if orientation.isPortrait {
                VStack {
                    UrlView()
                    HStack {
                        NextPrevView()
                        Spacer()
                        RefreshBookmarksView(webBrowser: model.database.webBrowser, showingBookmarks: $showingBookmarks)
                    }
                }
                .padding(3)
            } else {
                HStack {
                    NextPrevView()
                    UrlView()
                    RefreshBookmarksView(webBrowser: model.database.webBrowser, showingBookmarks: $showingBookmarks)
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
