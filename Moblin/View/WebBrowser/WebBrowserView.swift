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

    var body: some View {
        HStack {
            Button {
                model.getWebBrowser().reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .padding(10)
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

struct WebBrowserView: View {
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
            } else {
                HStack {
                    NextPrevView()
                    UrlView()
                    RefreshHomeView()
                }
                .padding(3)
            }
            WebView()
        }
        .background(ignoresSafeAreaEdges: .bottom)
    }
}
