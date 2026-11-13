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
    private struct Border: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path(rect)
            path.addRect(rect.insetBy(dx: 26, dy: 26))
            return path
        }
    }

    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var webBrowser: WebBrowserSettings
    @ObservedObject var webBrowserState: WebBrowserState
    @State private var isEditing = false
    @GestureState private var moveTranslation = CGSize.zero
    @GestureState private var resizeTranslation = CGSize.zero
    @GestureState private var resizeHandle = WebBrowserResizeHandle.bottomTrailing

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

    private func resizeHandle(at location: CGPoint, frame: CGRect) -> WebBrowserResizeHandle {
        WebBrowserResizeHandle.at(CGPoint(x: location.x - frame.minX, y: location.y - frame.minY),
                                  in: frame.size)
    }

    private func resizeGesture(frame: CGRect, size: CGSize) -> some Gesture {
        DragGesture(coordinateSpace: .named("webBrowserWindowLayout"))
            .updating($resizeHandle) { value, selected, _ in
                selected = resizeHandle(at: value.startLocation, frame: frame)
            }
            .updating($resizeTranslation) { value, translation, _ in
                translation = value.translation
            }
            .onEnded { value in
                save(frame: WebBrowserWindowLayout.resized(frame, by: value.translation, in: size,
                                                           handle: resizeHandle(at: value.startLocation,
                                                                                frame: frame)), in: size)
            }
    }

    private var adjustButton: some View {
        Button {
            isEditing = true
        } label: {
            if #available(iOS 26, *) {
                Image(systemName: "rectangle.dashed")
                    .foregroundStyle(.primary)
                    .frame(width: 12, height: 12)
                    .padding()
                    .glassEffect()
                    .padding(.trailing, 10)
            } else {
                Image(systemName: "rectangle.dashed")
                    .foregroundStyle(.primary)
                    .frame(width: 12, height: 12)
                    .padding()
                    .padding(.trailing, 10)
            }
        }
        .accessibilityLabel("Adjust browser")
    }

    private var expandButton: some View {
        Button {
            webBrowserState.isSmall = false
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
        .accessibilityLabel("Expand browser")
    }

    private func controls(frame: CGRect, size: CGSize) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(moveGesture(frame: frame, size: size))
            .accessibilityLabel("Move browser")
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.blue.opacity(0.35), lineWidth: 12)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(.blue, lineWidth: 2)
                    }
                    .allowsHitTesting(false)
            }
            .accessibilityAction(named: Text("Done")) { isEditing = false }
            .contextMenu {
                Button("Reset layout") {
                    webBrowser.smallWindow = nil
                    model.storeSettings()
                }
            }
    }

    private func resizeBorder(frame: CGRect, size: CGSize) -> some View {
        Border()
            .fill(.clear, style: FillStyle(eoFill: true))
            .contentShape(Border(), eoFill: true)
            .gesture(resizeGesture(frame: frame, size: size))
            .accessibilityLabel("Resize browser")
            .accessibilityAdjustableAction { direction in
                let delta = direction == .increment ? 20.0 : -20.0
                save(frame: WebBrowserWindowLayout.resized(frame,
                                                           by: CGSize(width: delta, height: delta),
                                                           in: size), in: size)
            }
    }

    var body: some View {
        GeometryReader { metrics in
            let bottomInset = 2 * (database.bigButtons ? segmentHeightBig : segmentHeight) + 10
            let frame = webBrowser.smallWindow?.frame(in: metrics.size)
                ?? WebBrowserWindowLayout.defaultFrame(in: metrics.size, bottomInset: bottomInset)
            let moved = WebBrowserWindowLayout.moved(frame, by: moveTranslation, in: metrics.size)
            let displayed = WebBrowserWindowLayout.resized(moved, by: resizeTranslation,
                                                           in: metrics.size, handle: resizeHandle)
            ZStack(alignment: .topLeading) {
                if isEditing {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { isEditing = false }
                }
                WebView(model: model)
                    .allowsHitTesting(!isEditing)
                    .frame(width: displayed.width, height: displayed.height)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        if isEditing {
                            controls(frame: frame, size: metrics.size)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !isEditing {
                            VStack(spacing: 0) {
                                adjustButton
                                expandButton
                            }
                        }
                    }
                    .accessibilityAction(named: Text("Adjust browser")) { isEditing = true }
                    .position(x: displayed.midX, y: displayed.midY)
                if isEditing {
                    resizeBorder(frame: frame, size: metrics.size)
                        .frame(width: displayed.width + 24, height: displayed.height + 24)
                        .position(x: displayed.midX, y: displayed.midY)
                }
            }
            .frame(width: metrics.size.width, height: metrics.size.height)
            .coordinateSpace(name: "webBrowserWindowLayout")
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
