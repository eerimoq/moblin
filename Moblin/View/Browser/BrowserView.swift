import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> WKWebView {
        return model.getBrowser()
    }

    func updateUIView(_: WKWebView, context _: Context) {}
}

private struct UrlView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        TextField("Search with Google or enter address", text: $model.browserUrl)
            .padding(5)
            .overlay(RoundedRectangle(cornerRadius: 5)
                .stroke(.secondary, lineWidth: 1))
            .textInputAutocapitalization(.never)
            .onSubmit {
                model.loadBrowserUrl()
            }
    }
}

private struct NextPrevView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        HStack {
            Button {
                model.getBrowser().goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .padding(10)
            }
            .disabled(!model.getBrowser().canGoBack)
            Button {
                model.getBrowser().goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .padding(10)
            }
            .disabled(!model.getBrowser().canGoForward)
        }
    }
}

private struct RefreshHomeView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        HStack {
            Button {
                model.getBrowser().reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .padding(10)
            }
            Button {
                model.loadBrowserHome()
            } label: {
                Image(systemName: "house")
                    .padding(10)
            }
        }
    }
}

struct BrowserView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(spacing: 0) {
            if model.stream.portrait! {
                VStack {
                    UrlView()
                    HStack {
                        NextPrevView()
                        Spacer()
                        RefreshHomeView()
                    }
                }
                .padding(3)
                .background(ignoresSafeAreaEdges: .bottom)
            } else {
                HStack {
                    NextPrevView()
                    UrlView()
                    RefreshHomeView()
                }
                .padding(3)
                .background(ignoresSafeAreaEdges: .bottom)
            }
            WebView()
        }
    }
}
