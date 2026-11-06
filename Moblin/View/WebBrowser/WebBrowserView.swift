import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let model: Model

    func makeUIView(context _: Context) -> WKWebView {
        model.getWebBrowser()
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
    let model: Model
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
                            .contextMenuDeleteButton {
                                webBrowser.bookmarks.removeAll { $0.id == bookmark.id }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                CloseToolbar(presenting: $presentingBookmarks)
            }
        }
    }
}

private struct WebBrowserSmallView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var webBrowser: WebBrowserSettings
    @ObservedObject var webBrowserState: WebBrowserState
    @State private var isEditing = true
    @State private var hasShownHint = false
    @GestureState private var moveTranslation = CGSize.zero
    @GestureState private var resizeTranslation = CGSize.zero

    private func save(frame: CGRect, in size: CGSize) {
        webBrowser.smallWindow = WebBrowserWindowLayout(frame: frame, in: size)
        model.storeSettings()
    }

    private func moveGesture(frame: CGRect, size: CGSize) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .updating($moveTranslation) { value, translation, _ in
                translation = value.translation
            }
            .onEnded { value in
                save(frame: WebBrowserWindowLayout.moved(frame, by: value.translation, in: size), in: size)
            }
    }

    private func resizeGesture(frame: CGRect, size: CGSize) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .updating($resizeTranslation) { value, translation, _ in
                translation = value.translation
            }
            .onEnded { value in
                save(frame: WebBrowserWindowLayout.resized(frame, by: value.translation, in: size), in: size)
            }
    }

    private func finishEditing() {
        isEditing = false
        if !hasShownHint {
            hasShownHint = true
            model.makeToast(title: String(localized: "Hold the browser to adjust it"))
        }
    }

    private func controls(frame: CGRect, displayed: CGRect, size: CGSize) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .contentShape(Rectangle())
                .gesture(moveGesture(frame: frame, size: size))
                .accessibilityLabel("Move browser")
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.title2)
                        if displayed.width >= 200, displayed.height >= 160 {
                            Text("Drag to move")
                                .font(.headline)
                            Text("Drag the corner to resize")
                                .font(.caption)
                        }
                    }
                    .shadow(radius: 2)
                    .allowsHitTesting(false)
                }
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.white, lineWidth: 2)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            Menu {
                Button("Expand browser", systemImage: "arrow.up.left.and.arrow.down.right") {
                    webBrowserState.isSmall = false
                }
                Button("Reset layout", systemImage: "arrow.counterclockwise") {
                    webBrowser.smallWindow = nil
                    model.storeSettings()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
            }
            .accessibilityLabel("Browser options")
        }
        .overlay(alignment: .topTrailing) {
            Button(action: finishEditing) {
                Text("Done")
                    .font(.callout.bold())
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.title3.bold())
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
                .gesture(resizeGesture(frame: frame, size: size))
                .accessibilityLabel("Resize browser")
                .accessibilityAdjustableAction { direction in
                    let delta = direction == .increment ? 20.0 : -20.0
                    save(frame: WebBrowserWindowLayout.resized(frame,
                                                               by: CGSize(width: delta, height: delta),
                                                               in: size),
                         in: size)
                }
                .help("Drag the corner to resize")
        }
        .foregroundStyle(.white)
    }

    var body: some View {
        GeometryReader { metrics in
            let bottomInset = 2 * (database.bigButtons ? segmentHeightBig : segmentHeight) + 10
            let frame = webBrowser.smallWindow?.frame(in: metrics.size)
                ?? WebBrowserWindowLayout.defaultFrame(in: metrics.size, bottomInset: bottomInset)
            let moved = WebBrowserWindowLayout.moved(frame, by: moveTranslation, in: metrics.size)
            let displayed = WebBrowserWindowLayout.resized(moved, by: resizeTranslation, in: metrics.size)
            WebView(model: model)
                .allowsHitTesting(!isEditing)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6)
                        .onEnded { _ in isEditing = true },
                    including: isEditing ? .none : .all
                )
                .frame(width: displayed.width, height: displayed.height)
                .overlay {
                    if isEditing {
                        controls(frame: frame, displayed: displayed, size: metrics.size)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .accessibilityAction(named: Text("Adjust browser")) {
                    isEditing = true
                }
                .position(x: displayed.midX, y: displayed.midY)
        }
    }
}

private struct WebBrowserBigView: View {
    let model: Model
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
                        RefreshBookmarksView(model: model,
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
                    RefreshBookmarksView(model: model,
                                         showingBookmarks: $presentingBookmarks,
                                         isSmall: $webBrowserState.isSmall)
                }
                .padding(3)
                .background(ignoresSafeAreaEdges: .bottom)
            }
            WebView(model: model)
                .sheet(isPresented: $presentingBookmarks) {
                    BookmarksView(webBrowser: database.webBrowser,
                                  presentingBookmarks: $presentingBookmarks)
                }
        }
    }
}

struct WebBrowserView: View {
    let model: Model
    let database: Database
    let orientation: Orientation
    @ObservedObject var webBrowserState: WebBrowserState

    var body: some View {
        if webBrowserState.isSmall {
            WebBrowserSmallView(model: model,
                                database: database,
                                webBrowser: database.webBrowser,
                                webBrowserState: webBrowserState)
        } else {
            WebBrowserBigView(model: model,
                              database: database,
                              orientation: orientation,
                              webBrowserState: webBrowserState)
        }
    }
}
